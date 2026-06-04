//
//  HealthKitHeartRateData.swift
//  com.aware.ios.sensor.core
//

import Foundation
import GRDB
import com_awareframework_ios_core

public struct HealthKitHeartRateData: BaseDbModelSQLite {
    public static let databaseTableName = "healthKitHeartRateData"
    public static let TABLE_NAME = databaseTableName

    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String

    public var heartrate: Double = 0
    public var unit: String = ""
    public var device: String = ""
    public var startDate: Int64 = 0
    public var endDate: Int64 = 0
    public var metadata: String = ""
    public var type: String = ""

    public init(timestamp: Int64, label: String) {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.heartrate = dict["heartrate"] as? Double ?? 0
        self.unit = dict["unit"] as? String ?? ""
        self.device = dict["device"] as? String ?? ""
        self.startDate = dict["startDate"] as? Int64 ?? 0
        self.endDate = dict["endDate"] as? Int64 ?? 0
        self.metadata = dict["metadata"] as? String ?? ""
        self.type = dict["type"] as? String ?? ""
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": self.id ?? -1,
            "timestamp": self.timestamp,
            "deviceId": self.deviceId,
            "label": self.label,
            "heartrate": self.heartrate,
            "unit": self.unit,
            "device": self.device,
            "startDate": self.startDate,
            "endDate": self.endDate,
            "metadata": self.metadata,
            "type": self.type,
        ]
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("label", .text)
                t.column("heartrate", .double).notNull()
                t.column("unit", .text)
                t.column("device", .text)
                t.column("startDate", .integer).notNull()
                t.column("endDate", .integer).notNull()
                t.column("metadata", .text)
                t.column("type", .text)
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
            }
        }
    }
}
