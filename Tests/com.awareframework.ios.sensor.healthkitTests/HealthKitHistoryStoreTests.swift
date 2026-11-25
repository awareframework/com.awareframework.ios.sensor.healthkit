import GRDB
import HealthKit
import XCTest

@testable import com_awareframework_ios_sensor_healthkit

final class HealthKitHistoryStoreTests: XCTestCase {
    private let stream = "quantity.stepCount"
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testSameEndDateAcrossPagesPreservesDistinctSamples() throws {
        let database = try makeDatabase()
        let store = HealthKitHistoryStore(database: database)
        let first = try store.checkpoint(for: stream, from: start)
        XCTAssertNil(first.anchor)
        let firstAnchor = HKQueryAnchor(fromValue: 1)
        let secondAnchor = HKQueryAnchor(fromValue: 2)

        let firstPage = try store.commit(
            stream: stream, checkpoint: first, anchor: firstAnchor,
            rows: [(sampleID(1), quantity("18"))])
        XCTAssertEqual(firstPage.map(\.quantity), ["18"])

        let reopened = HealthKitHistoryStore(database: database)
        let next = try reopened.checkpoint(for: stream, from: start.addingTimeInterval(600))
        XCTAssertEqual(next.start, start, "The predicate's migration boundary stays fixed between pages")
        XCTAssertEqual(next.anchor, firstAnchor)

        let secondPage = try reopened.commit(
            stream: stream, checkpoint: next, anchor: secondAnchor,
            rows: [(sampleID(2), quantity("22"))])
        XCTAssertEqual(secondPage.map(\.quantity), ["22"])

        let saved = try readRows(database)
        XCTAssertEqual(Set(saved.map(\.quantity)), ["18", "22"])
        XCTAssertEqual(Set(saved.map(\.endDate)).count, 1)
        XCTAssertEqual(try reopened.checkpoint(for: stream, from: start).anchor, secondAnchor)
    }

    func testRepeatedSampleIsIgnoredEvenAfterCheckpointReset() throws {
        let database = try makeDatabase()
        let store = HealthKitHistoryStore(database: database)
        let first = try store.checkpoint(for: stream, from: start)
        let sample = (sampleID(1), quantity("18"))

        let inserted = try store.commit(
            stream: stream, checkpoint: first, anchor: HKQueryAnchor(fromValue: 1),
            rows: [sample, sample])
        XCTAssertEqual(inserted.count, 1)

        try store.reset()
        let newStart = start.addingTimeInterval(-60)
        let reset = try store.checkpoint(for: stream, from: newStart)
        XCTAssertNil(reset.anchor)
        XCTAssertEqual(reset.start, newStart)

        let resetAnchor = HKQueryAnchor(fromValue: 2)
        let replayed = try store.commit(
            stream: stream, checkpoint: reset, anchor: resetAnchor, rows: [sample])
        XCTAssertTrue(replayed.isEmpty)
        XCTAssertEqual(try readRows(database).count, 1)
        XCTAssertEqual(try store.checkpoint(for: stream, from: start).anchor, resetAnchor)
    }

    func testStreamsTrackAnchorAndSampleIdentityIndependently() throws {
        let database = try makeDatabase()
        let store = HealthKitHistoryStore(database: database)
        let other = "heartRate"
        let one = HKQueryAnchor(fromValue: 1)
        let two = HKQueryAnchor(fromValue: 2)
        let sample = (sampleID(1), quantity("18"))
        let first = try store.checkpoint(for: stream, from: start)
        _ = try store.commit(stream: stream, checkpoint: first, anchor: one, rows: [sample])

        let second = try store.checkpoint(for: other, from: start)
        XCTAssertNil(second.anchor)
        let inserted = try store.commit(stream: other, checkpoint: second, anchor: two, rows: [sample])

        XCTAssertEqual(inserted.count, 1)
        XCTAssertEqual(try store.checkpoint(for: stream, from: start).anchor, one)
        XCTAssertEqual(try store.checkpoint(for: other, from: start).anchor, two)
    }

    func testFailedInsertRollsBackRowsAndCheckpointAndAllowsRetry() throws {
        let database = try makeDatabase()
        let store = HealthKitHistoryStore(database: database)
        let firstAnchor = HKQueryAnchor(fromValue: 1)
        let secondAnchor = HKQueryAnchor(fromValue: 2)
        let first = try store.checkpoint(for: stream, from: start)
        _ = try store.commit(
            stream: stream, checkpoint: first, anchor: firstAnchor,
            rows: [(sampleID(1), quantity("18"))])

        try database.write { db in
            try db.execute(sql: """
                CREATE TRIGGER reject_bad_quantity BEFORE INSERT ON ios_healthkit_quantity
                WHEN NEW.quantity = 'reject'
                BEGIN SELECT RAISE(ABORT, 'test write failure'); END
                """)
        }

        let next = try store.checkpoint(for: stream, from: start)
        XCTAssertThrowsError(try store.commit(
            stream: stream, checkpoint: next, anchor: secondAnchor,
            rows: [(sampleID(2), quantity("22")), (sampleID(3), quantity("reject"))]))
        XCTAssertEqual(try readRows(database).map(\.quantity), ["18"])
        XCTAssertEqual(try store.checkpoint(for: stream, from: start).anchor, firstAnchor)

        let retried = try store.commit(
            stream: stream, checkpoint: next, anchor: secondAnchor,
            rows: [(sampleID(2), quantity("22")), (sampleID(3), quantity("27"))])
        XCTAssertEqual(retried.map(\.quantity), ["22", "27"])
        XCTAssertEqual(try readRows(database).count, 3)
        XCTAssertEqual(try store.checkpoint(for: stream, from: start).anchor, secondAnchor)
    }

    func testPageWithoutRowsStillPersistsItsAnchor() throws {
        let database = try makeDatabase()
        let store = HealthKitHistoryStore(database: database)
        let first = try store.checkpoint(for: stream, from: start)
        let anchor = HKQueryAnchor(fromValue: 5)

        let rows: [HealthKitQuantityData] = try store.commit(
            stream: stream, checkpoint: first, anchor: anchor, rows: [])

        XCTAssertTrue(rows.isEmpty)
        XCTAssertTrue(try readRows(database).isEmpty)
        XCTAssertEqual(try store.checkpoint(for: stream, from: start).anchor, anchor)
    }

    private func makeDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        try HealthKitQuantityData.createTable(queue: database)
        return database
    }

    private func sampleID(_ suffix: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, suffix))
    }

    private func quantity(_ value: String) -> HealthKitQuantityData {
        let timestamp = Int64(start.addingTimeInterval(60).timeIntervalSince1970 * 1_000)
        var row = HealthKitQuantityData(timestamp: timestamp, label: "test")
        row.deviceId = "test-device"
        row.type = HKQuantityTypeIdentifier.stepCount.rawValue
        row.startDate = timestamp - 60_000
        row.endDate = timestamp
        row.quantity = value
        return row
    }

    private func readRows(_ database: DatabaseQueue) throws -> [HealthKitQuantityData] {
        try database.read { try HealthKitQuantityData.fetchAll($0) }
    }
}
