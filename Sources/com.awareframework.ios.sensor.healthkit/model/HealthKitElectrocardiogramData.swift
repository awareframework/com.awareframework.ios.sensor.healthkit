//
//  HealthKitElectrocardiogramData.swift
//  com.aware.ios.sensor.core
//

import Foundation
import GRDB
import com_awareframework_ios_core

public struct HealthKitElectrocardiogramData: BaseDbModelSQLite {
    public static let databaseTableName = "healthKitElectrocardiogramData"
    public static let TABLE_NAME = databaseTableName

    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String

    public var classification: String = ""
    public var symptomsStatus: String = ""
    public var averageHeartRate: Double = 0
    public var samplingFrequency: Double = 0
    public var numberOfVoltageMeasurements: Int = 0
    public var measurements: String = ""
    public var device: String = ""
    public var startDate: Int64 = 0
    public var endDate: Int64 = 0
    public var metadata: String = ""
    public var type: String = "electrocardiogram"

    public init(timestamp: Int64, label: String) {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.classification = dict["classification"] as? String ?? ""
        self.symptomsStatus = dict["symptomsStatus"] as? String ?? ""
        self.averageHeartRate = dict["averageHeartRate"] as? Double ?? 0
        self.samplingFrequency = dict["samplingFrequency"] as? Double ?? 0
        self.numberOfVoltageMeasurements = dict["numberOfVoltageMeasurements"] as? Int ?? 0
        self.measurements = dict["measurements"] as? String ?? ""
        self.device = dict["device"] as? String ?? ""
        self.startDate = dict["startDate"] as? Int64 ?? 0
        self.endDate = dict["endDate"] as? Int64 ?? 0
        self.metadata = dict["metadata"] as? String ?? ""
        self.type = dict["type"] as? String ?? "electrocardiogram"
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": self.id ?? -1,
            "timestamp": self.timestamp,
            "deviceId": self.deviceId,
            "label": self.label,
            "classification": self.classification,
            "symptomsStatus": self.symptomsStatus,
            "averageHeartRate": self.averageHeartRate,
            "samplingFrequency": self.samplingFrequency,
            "numberOfVoltageMeasurements": self.numberOfVoltageMeasurements,
            "measurements": self.measurements,
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
                t.column("classification", .text)
                t.column("symptomsStatus", .text)
                t.column("averageHeartRate", .double).notNull()
                t.column("samplingFrequency", .double).notNull()
                t.column("numberOfVoltageMeasurements", .integer).notNull()
                t.column("measurements", .text)
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
