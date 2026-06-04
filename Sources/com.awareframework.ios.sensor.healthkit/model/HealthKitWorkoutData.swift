//
//  HealthKitWorkoutData.swift
//  com.aware.ios.sensor.core
//

import Foundation
import GRDB
import com_awareframework_ios_core

public struct HealthKitWorkoutData: BaseDbModelSQLite {
    public static let databaseTableName = "healthKitWorkoutData"
    public static let TABLE_NAME = databaseTableName

    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String

    public var workoutActivityType: Int = 0
    public var duration: Double = 0
    public var totalEnergyBurned: String = ""
    public var totalDistance: String = ""
    public var device: String = ""
    public var startDate: Int64 = 0
    public var endDate: Int64 = 0
    public var metadata: String = ""

    public init(timestamp: Int64, label: String) {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.workoutActivityType = dict["workoutActivityType"] as? Int ?? 0
        self.duration = dict["duration"] as? Double ?? 0
        self.totalEnergyBurned = dict["totalEnergyBurned"] as? String ?? ""
        self.totalDistance = dict["totalDistance"] as? String ?? ""
        self.device = dict["device"] as? String ?? ""
        self.startDate = dict["startDate"] as? Int64 ?? 0
        self.endDate = dict["endDate"] as? Int64 ?? 0
        self.metadata = dict["metadata"] as? String ?? ""
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": self.id ?? -1,
            "timestamp": self.timestamp,
            "deviceId": self.deviceId,
            "label": self.label,
            "workoutActivityType": self.workoutActivityType,
            "duration": self.duration,
            "totalEnergyBurned": self.totalEnergyBurned,
            "totalDistance": self.totalDistance,
            "device": self.device,
            "startDate": self.startDate,
            "endDate": self.endDate,
            "metadata": self.metadata,
        ]
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("label", .text)
                t.column("workoutActivityType", .integer).notNull()
                t.column("duration", .double).notNull()
                t.column("totalEnergyBurned", .text)
                t.column("totalDistance", .text)
                t.column("device", .text)
                t.column("startDate", .integer).notNull()
                t.column("endDate", .integer).notNull()
                t.column("metadata", .text)
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
            }
        }
    }
}
