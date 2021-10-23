//
//  HealthKitHeartRateData.swift
//  com.aware.ios.sensor.core
//
//  Created by Yuuki Nishiyama on 2018/11/14.
//

import UIKit
import com_awareframework_ios_sensor_core

public class HealthKitQuantityData: AwareObject {
    public static let TABLE_NAME = "healthKitQuantityData"
    
    @objc dynamic public var quantity:String = ""  // e.g., 60
    @objc dynamic public var device:String   = "" // JSON format
    @objc dynamic public var startDate:Int64 = 0
    @objc dynamic public var endDate:Int64   = 0
    @objc dynamic public var metadata:String = ""   // HKMetadataKeyHeartRateMotionContext
    @objc dynamic public var type:String     = ""  // HKQuantityTypeIdentifier

    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["quantity"]  = quantity
        dict["device"]    = device
        dict["startDate"] = startDate
        dict["endDate"]   = endDate
        dict["metadata"]  = metadata
        dict["type"]      = type
        return dict
    }
}
