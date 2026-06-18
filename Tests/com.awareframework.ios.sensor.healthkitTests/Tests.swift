import HealthKit
import XCTest

@testable import com_awareframework_ios_sensor_healthkit

class Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    func testConfig() {
        let fetchLimit = 150
        let sampleIntervalSeconds: Int = 10
        let statusHeartRate: Bool = false
        let statusSleepAnalysis: Bool = false
        let statusActivity: Bool = false
        let statusStandHour: Bool = false
        let config: [String: Any] = [
            "fetchLimit": fetchLimit,
            "sampleIntervalSeconds": sampleIntervalSeconds,
            "statusHeartRate": statusHeartRate,
            "statusSleepAnalysis": statusSleepAnalysis,
            "statusActivity": statusActivity,
            "statusStandHour": statusStandHour,
        ]

        // defualt
        var sensor = HealthKitSensor.init()
        XCTAssertEqual(sensor.CONFIG.fetchLimit, 100)
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, 900)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, true)
        XCTAssertEqual(sensor.CONFIG.statusSleepAnalysis, true)
        XCTAssertEqual(sensor.CONFIG.statusActivity, true)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, true)

        // apply
        sensor = HealthKitSensor.init(
            HealthKitSensor.Config().apply { config in
                config.fetchLimit = fetchLimit
                config.sampleIntervalSeconds = sampleIntervalSeconds
                config.statusStandHour = statusStandHour
                config.statusActivity = statusActivity
                config.statusHeartRate = statusHeartRate
                config.statusSleepAnalysis = statusSleepAnalysis
            })
        XCTAssertEqual(sensor.CONFIG.fetchLimit, fetchLimit)
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, sampleIntervalSeconds)
        XCTAssertEqual(sensor.CONFIG.statusHeartRate, statusHeartRate)
        XCTAssertEqual(sensor.CONFIG.statusSleepAnalysis, statusSleepAnalysis)
        XCTAssertEqual(sensor.CONFIG.statusActivity, statusActivity)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, statusStandHour)

        // set
        sensor = HealthKitSensor()
        sensor.CONFIG.set(config: config)
        XCTAssertEqual(sensor.CONFIG.fetchLimit, fetchLimit)
        XCTAssertEqual(sensor.CONFIG.sampleIntervalSeconds, sampleIntervalSeconds)
        XCTAssertEqual(sensor.CONFIG.statusHeartRate, statusHeartRate)
        XCTAssertEqual(sensor.CONFIG.statusSleepAnalysis, statusSleepAnalysis)
        XCTAssertEqual(sensor.CONFIG.statusActivity, statusActivity)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, statusStandHour)
    }

    func testResolvedReadTypeIdentifiersForGroupedSelection() {
        let sensor = HealthKitSensor.init(
            HealthKitSensor.Config().apply { config in
                config.selectedSensors = ["activity", "vitals", "sleep", "workout"]
            })

        let identifiers = sensor.resolvedReadTypeIdentifiers()

        XCTAssertTrue(identifiers.contains(HKQuantityTypeIdentifier.stepCount.rawValue))
        XCTAssertTrue(identifiers.contains(HKQuantityTypeIdentifier.activeEnergyBurned.rawValue))
        XCTAssertTrue(identifiers.contains(HKQuantityTypeIdentifier.restingHeartRate.rawValue))
        XCTAssertTrue(identifiers.contains(HKCategoryTypeIdentifier.sleepAnalysis.rawValue))
        XCTAssertTrue(identifiers.contains(HKObjectType.workoutType().identifier))
        XCTAssertFalse(identifiers.contains(HKQuantityTypeIdentifier.bodyMass.rawValue))
        XCTAssertFalse(identifiers.contains(HKCategoryTypeIdentifier.mindfulSession.rawValue))
    }

    func testResolvedReadTypeIdentifiersForExplicitIdentifiersOnly() {
        let sensor = HealthKitSensor.init(
            HealthKitSensor.Config().apply { config in
                config.selectedQuantityTypeIdentifiers = [
                    HKQuantityTypeIdentifier.bodyMass.rawValue,
                    HKQuantityTypeIdentifier.stepCount.rawValue,
                ]
                config.selectedCategoryTypeIdentifiers = [
                    HKCategoryTypeIdentifier.mindfulSession.rawValue
                ]
            })

        let identifiers = sensor.resolvedReadTypeIdentifiers()

        XCTAssertTrue(identifiers.contains(HKQuantityTypeIdentifier.bodyMass.rawValue))
        XCTAssertTrue(identifiers.contains(HKQuantityTypeIdentifier.stepCount.rawValue))
        XCTAssertTrue(identifiers.contains(HKCategoryTypeIdentifier.mindfulSession.rawValue))
        XCTAssertFalse(identifiers.contains(HKQuantityTypeIdentifier.bloodGlucose.rawValue))
        XCTAssertFalse(identifiers.contains(HKObjectType.workoutType().identifier))
    }

    func testResolvedReadTypeIdentifiersForSpecialSensors() {
        let sensor = HealthKitSensor.init(
            HealthKitSensor.Config().apply { config in
                config.selectedSensors = ["electrocardiogram", "activitySummary", "audiogram"]
            })

        let identifiers = sensor.resolvedReadTypeIdentifiers()

        if #available(iOS 14.0, *) {
            XCTAssertTrue(identifiers.contains(HKObjectType.electrocardiogramType().identifier))
        }
        XCTAssertTrue(identifiers.contains(HKObjectType.activitySummaryType().identifier))
        if #available(iOS 13.0, *) {
            XCTAssertTrue(identifiers.contains(HKObjectType.audiogramSampleType().identifier))
        }
        XCTAssertFalse(identifiers.contains(HKQuantityTypeIdentifier.stepCount.rawValue))
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
