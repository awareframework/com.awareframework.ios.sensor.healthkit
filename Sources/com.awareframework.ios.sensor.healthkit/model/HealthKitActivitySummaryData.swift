//
//  HealthKitActivitySummaryData.swift
//  com.aware.ios.sensor.core
//

import Foundation
import GRDB
import com_awareframework_ios_core

public struct HealthKitActivitySummaryData: BaseDbModelSQLite {
    public static let databaseTableName = "healthKitActivitySummaryData"
    public static let TABLE_NAME = databaseTableName

    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String

    public var summaryDate: String = ""
    public var activeEnergyBurned: String = ""
    public var activeEnergyBurnedGoal: String = ""
    public var appleMoveTime: String = ""
    public var appleMoveTimeGoal: String = ""
    public var appleExerciseTime: String = ""
    public var exerciseTimeGoal: String = ""
    public var appleStandHours: String = ""
    public var standHoursGoal: String = ""
    public var activityMoveMode: Int = 0
    public var isPaused: Bool = false

    public init(timestamp: Int64, label: String) {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.summaryDate = dict["summaryDate"] as? String ?? ""
        self.activeEnergyBurned = dict["activeEnergyBurned"] as? String ?? ""
        self.activeEnergyBurnedGoal = dict["activeEnergyBurnedGoal"] as? String ?? ""
        self.appleMoveTime = dict["appleMoveTime"] as? String ?? ""
        self.appleMoveTimeGoal = dict["appleMoveTimeGoal"] as? String ?? ""
        self.appleExerciseTime = dict["appleExerciseTime"] as? String ?? ""
        self.exerciseTimeGoal = dict["exerciseTimeGoal"] as? String ?? ""
        self.appleStandHours = dict["appleStandHours"] as? String ?? ""
        self.standHoursGoal = dict["standHoursGoal"] as? String ?? ""
        self.activityMoveMode = dict["activityMoveMode"] as? Int ?? 0
        self.isPaused = dict["isPaused"] as? Bool ?? false
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": self.id ?? -1,
            "timestamp": self.timestamp,
            "deviceId": self.deviceId,
            "label": self.label,
            "summaryDate": self.summaryDate,
            "activeEnergyBurned": self.activeEnergyBurned,
            "activeEnergyBurnedGoal": self.activeEnergyBurnedGoal,
            "appleMoveTime": self.appleMoveTime,
            "appleMoveTimeGoal": self.appleMoveTimeGoal,
            "appleExerciseTime": self.appleExerciseTime,
            "exerciseTimeGoal": self.exerciseTimeGoal,
            "appleStandHours": self.appleStandHours,
            "standHoursGoal": self.standHoursGoal,
            "activityMoveMode": self.activityMoveMode,
            "isPaused": self.isPaused,
        ]
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("label", .text)
                t.column("summaryDate", .text).notNull()
                t.column("activeEnergyBurned", .text)
                t.column("activeEnergyBurnedGoal", .text)
                t.column("appleMoveTime", .text)
                t.column("appleMoveTimeGoal", .text)
                t.column("appleExerciseTime", .text)
                t.column("exerciseTimeGoal", .text)
                t.column("appleStandHours", .text)
                t.column("standHoursGoal", .text)
                t.column("activityMoveMode", .integer).notNull()
                t.column("isPaused", .boolean).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
            }
        }
    }
}
