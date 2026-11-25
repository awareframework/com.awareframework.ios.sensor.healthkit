import Foundation
import GRDB
import HealthKit
import com_awareframework_ios_core

extension HealthKitSensor {
    /// Local importer state, separate from the sensor data tables.
    public static let historyStorageTableNames: Set<String> = [
        "_aware_healthkit_checkpoints", "_aware_healthkit_imported_samples"
    ]
}

private enum HealthKitHistoryError: LocalizedError {
    case invalidAnchor, unchangedAnchor, invalidPage, staleCheckpoint

    var errorDescription: String? {
        switch self {
        case .invalidAnchor: return "HealthKit did not provide a valid query anchor."
        case .unchangedAnchor: return "HealthKit returned a page without advancing the query anchor."
        case .invalidPage: return "A HealthKit page could not be converted to database rows."
        case .staleCheckpoint: return "The HealthKit import checkpoint changed while the page was in flight."
        }
    }
}

struct HealthKitHistoryStore {
    struct Checkpoint {
        let start: Date
        let anchor: HKQueryAnchor?
        fileprivate let archivedAnchor: Data?
    }

    let database: DatabaseQueue

    func checkpoint(for stream: String, from fallback: Date) throws -> Checkpoint {
        try database.write { db in
            try createTables(in: db)
            guard let row = try Row.fetchOne(db, sql: """
                SELECT start, anchor FROM _aware_healthkit_checkpoints WHERE stream = ?
                """, arguments: [stream]) else {
                return Checkpoint(start: fallback, anchor: nil, archivedAnchor: nil)
            }
            let archivedAnchor: Data = row["anchor"]
            let start: Double = row["start"]
            guard let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: archivedAnchor) else {
                throw HealthKitHistoryError.invalidAnchor
            }
            return Checkpoint(start: Date(timeIntervalSince1970: start), anchor: anchor, archivedAnchor: archivedAnchor)
        }
    }

    func commit<Record: BaseDbModelSQLite>(stream: String, checkpoint: Checkpoint,
                                          anchor: HKQueryAnchor, rows: [(UUID, Record)]) throws -> [Record] {
        let archivedAnchor = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        return try database.write { db in
            try createTables(in: db)
            let currentAnchor = try Data.fetchOne(db, sql: """
                SELECT anchor FROM _aware_healthkit_checkpoints WHERE stream = ?
                """, arguments: [stream])
            guard currentAnchor == checkpoint.archivedAnchor else { throw HealthKitHistoryError.staleCheckpoint }

            var inserted: [Record] = []
            for (uuid, record) in rows {
                try db.execute(sql: """
                    INSERT OR IGNORE INTO _aware_healthkit_imported_samples (stream, uuid) VALUES (?, ?)
                    """, arguments: [stream, uuid.uuidString])
                if db.changesCount > 0 {
                    try record.insert(db)
                    inserted.append(record)
                }
            }
            // Commit the anchor together with the data and IDs, including pages containing deletions only.
            try db.execute(sql: """
                INSERT INTO _aware_healthkit_checkpoints (stream, start, anchor) VALUES (?, ?, ?)
                ON CONFLICT(stream) DO UPDATE SET start = excluded.start, anchor = excluded.anchor
                """, arguments: [stream, checkpoint.start.timeIntervalSince1970, archivedAnchor])
            return inserted
        }
    }

    func reset() throws {
        try database.write { db in
            try createTables(in: db)
            try db.execute(sql: "DELETE FROM _aware_healthkit_checkpoints")
        }
    }

    private func createTables(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS _aware_healthkit_checkpoints (
                stream TEXT PRIMARY KEY NOT NULL, start REAL NOT NULL, anchor BLOB NOT NULL
            ) WITHOUT ROWID;
            CREATE TABLE IF NOT EXISTS _aware_healthkit_imported_samples (
                stream TEXT NOT NULL, uuid TEXT NOT NULL, PRIMARY KEY (stream, uuid)
            ) WITHOUT ROWID;
            """)
    }
}

/// Each import stream has one outstanding page. A saved anchor keeps pagination independent of dates.
final class HealthKitHistoryImport {
    private struct Request {
        let id: UUID
        let store: HKHealthStore
        var query: HKQuery?
    }

    private let queue = DispatchQueue(label: "com.awareframework.ios.sensor.healthkit.import", qos: .utility)
    private let queueKey = DispatchSpecificKey<Bool>()
    private var requests: [String: Request] = [:]
    private var observerOnlyCheckpoints: [String: HealthKitHistoryStore.Checkpoint] = [:]
    private static let pagesPerFetch = 20

    init() {
        queue.setSpecific(key: queueKey, value: true)
    }

    func fetch<Sample: HKSample, Record: BaseDbModelSQLite>(
        store: HKHealthStore, database: DatabaseQueue?, stream: String, type: HKSampleType,
        from start: Date, pageSize: Int,
        transform: @escaping ([Sample], @escaping ([Record]?) -> Void) -> Void,
        didSave: @escaping ([Record], Date?) -> Void, onError: @escaping (Error) -> Void
    ) {
        queue.async {
            guard self.requests[stream] == nil else { return }
            let id = UUID()
            self.requests[stream] = Request(id: id, store: store)
            self.fetchPage(store: store, database: database.map(HealthKitHistoryStore.init(database:)), stream: stream,
                           id: id, type: type, start: start, limit: max(1, pageSize),
                           remaining: Self.pagesPerFetch, transform: transform, didSave: didSave, onError: onError)
        }
    }

    func cancel() {
        queue.async { self.cancelRequests() }
    }

    func reset(database: DatabaseQueue?) {
        let resetState = {
            self.cancelRequests()
            self.observerOnlyCheckpoints.removeAll()
            guard let database else { return }
            do {
                try HealthKitHistoryStore(database: database).reset()
            } catch {
                print("[AWARE::HealthKit] Could not reset the history checkpoint:", error)
            }
        }
        if DispatchQueue.getSpecific(key: queueKey) == true {
            resetState()
        } else {
            queue.sync(execute: resetState)
        }
    }

    private func cancelRequests() {
        for request in requests.values {
            if let query = request.query { request.store.stop(query) }
        }
        requests.removeAll()
    }

    private func finish(_ stream: String, error: Error? = nil, onError: (Error) -> Void) {
        requests.removeValue(forKey: stream)
        if let error { onError(error) }
    }

    private func fetchPage<Sample: HKSample, Record: BaseDbModelSQLite>(
        store: HKHealthStore, database: HealthKitHistoryStore?, stream: String, id: UUID,
        type: HKSampleType, start: Date, limit: Int, remaining: Int,
        transform: @escaping ([Sample], @escaping ([Record]?) -> Void) -> Void,
        didSave: @escaping ([Record], Date?) -> Void, onError: @escaping (Error) -> Void
    ) {
        let checkpoint: HealthKitHistoryStore.Checkpoint
        do {
            checkpoint = try database?.checkpoint(for: stream, from: start)
                ?? observerOnlyCheckpoints[stream]
                ?? HealthKitHistoryStore.Checkpoint(start: start, anchor: nil, archivedAnchor: nil)
        } catch {
            finish(stream, error: error, onError: onError)
            return
        }

        // Keep the initial date predicate fixed. The HealthKit anchor alone advances between pages.
        let predicate = HKQuery.predicateForSamples(withStart: checkpoint.start, end: nil, options: .strictEndDate)
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: checkpoint.anchor, limit: limit) {
            [weak self] _, samples, deleted, newAnchor, error in
            guard let self else { return }
            self.queue.async {
                guard self.requests[stream]?.id == id else { return }
                self.requests[stream]?.query = nil
                if let error {
                    self.finish(stream, error: error, onError: onError)
                    return
                }
                let count = (samples?.count ?? 0) + (deleted?.count ?? 0)
                guard let newAnchor else {
                    self.finish(stream, error: count == 0 ? nil : HealthKitHistoryError.invalidAnchor, onError: onError)
                    return
                }
                guard newAnchor != checkpoint.anchor else {
                    self.finish(stream, error: count == 0 ? nil : HealthKitHistoryError.unchangedAnchor, onError: onError)
                    return
                }
                guard let typedSamples = (samples ?? []) as? [Sample] else {
                    self.finish(stream, error: HealthKitHistoryError.invalidPage, onError: onError)
                    return
                }

                transform(typedSamples) { rows in
                    self.queue.async {
                        guard self.requests[stream]?.id == id else { return }
                        guard let rows, rows.count == typedSamples.count else {
                            self.finish(stream, error: HealthKitHistoryError.invalidPage, onError: onError)
                            return
                        }
                        do {
                            let inserted: [Record]
                            if let database {
                                inserted = try database.commit(stream: stream, checkpoint: checkpoint, anchor: newAnchor,
                                                               rows: Array(zip(typedSamples.map(\.uuid), rows)))
                            } else {
                                self.observerOnlyCheckpoints[stream] = HealthKitHistoryStore.Checkpoint(
                                    start: checkpoint.start, anchor: newAnchor, archivedAnchor: nil)
                                inserted = rows
                            }
                            didSave(inserted, typedSamples.map(\.endDate).max())
                            guard self.requests[stream]?.id == id else { return }
                            if count >= limit, remaining > 1 {
                                self.fetchPage(store: store, database: database, stream: stream, id: id, type: type,
                                               start: start, limit: limit, remaining: remaining - 1,
                                               transform: transform, didSave: didSave, onError: onError)
                            } else {
                                self.finish(stream, onError: onError)
                            }
                        } catch {
                            self.finish(stream, error: error, onError: onError)
                        }
                    }
                }
            }
        }
        requests[stream]?.query = query
        store.execute(query)
    }
}
