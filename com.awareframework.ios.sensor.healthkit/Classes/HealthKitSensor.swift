//
//  HealthKitSensor.swift
//  com.aware.ios.sensor.core
//
//  Created by Yuuki Nishiyama on 2018/11/13.
//

import UIKit
import HealthKit
import SwiftyJSON
import com_awareframework_ios_sensor_core

public protocol HealthKitObserver {
    func onHealthKitAuthorizationStatusChanged(success:Bool, error:Error?)
    func onHeartRateDataChanged(data:[HealthKitHeartRateData])
}

public class HealthKitSensor: AwareSensor {
    
    public var healthStore : HKHealthStore?
    
    private var hrTimer:Timer?
    private var isInRecoveryLoopHR:Bool = false
    
    private var activityTimer:Timer?
    private var isInRecoveryLoopActivity:Bool = false
    
    private var sleepTimer:Timer?
    private var isInRecoveryLoopSleep:Bool = false
    
    private var standHourTimer:Timer?
    private var isInRecoveryLoopStandHour:Bool = false
    
    public var CONFIG = Config()
    
    public class Config:SensorConfig {
        public var fetchLimit                = 100
        public var interval:Int              = 15 // min
        public var statusHeartRate:Bool      = true
        public var statusSleepAnalysis:Bool  = true
        public var statusActivity:Bool       = true
        public var statusStandHour:Bool      = true
        
        public var sensorObserver:HealthKitObserver?
        public override init() {
            super.init()
            dbPath = "aware_healthkit"
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
            if let fetchLimit = config["fetchLimit"] as? Int {
                self.fetchLimit = fetchLimit
            }
            if let interval = config["interval"] as? Int {
                self.interval = interval
            }
            if config["statusHeartRate"] != nil {
                self.statusHeartRate = config["statusHeartRate"] as! Bool
                // print(config["statusHeartRate"])
            }
            if config["statusSleepAnalysis"] != nil {
                self.statusSleepAnalysis = config["statusSleepAnalysis"] as! Bool
                // print(config["statusSleepAnalysis"])
            }
            if config["statusStandHour"] != nil {
                self.statusStandHour = config["statusStandHour"] as! Bool
                // print( config["statusStandHour"] )
            }
            if config["statusActivity"] != nil {
                self.statusActivity = config["statusActivity"] as! Bool
                // print( config["statusActivity"] )
            }
        }
        
        public func apply(closure:(_ config: HealthKitSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    public override convenience init() {
        self.init(Config())
    }
    
    public init(_ config: Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        healthStore = HKHealthStore()
    }
    
    public override func start() {
        
        self.requestAuthorization()
        
        if hrTimer == nil {
            hrTimer = Timer.scheduledTimer(withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true, block: { timer in
                if !self.isInRecoveryLoopHR {
                    self.fetchHRData(self.lastHRSyncDate)
                }
            })
            hrTimer?.fire()
        }
        
        if activityTimer == nil {
            activityTimer = Timer.scheduledTimer(withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true, block: { timer in
                if !self.isInRecoveryLoopActivity {
                    // self.fetchHRData(self.lastHRSyncDate)
                    self.fetchActivityData()
                }
            })
            hrTimer?.fire()
        }
    }
    
    public override func stop() {
        if let t = hrTimer {
            t.invalidate()
            self.hrTimer = nil
        }
        
        if let t = activityTimer {
            t.invalidate()
            self.activityTimer = nil
        }
    }
    
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine {
            engine.startSync(HealthKitQuantityData.TABLE_NAME, DbSyncConfig().apply{config in
                config.debug = true
            })
        }
    }
}

extension Notification.Name {
    // TODO
}

extension HealthKitSensor {
    func fetchActivityData() {
        // TODO
    }
}

/**
 * extension for HR data
 */
extension HealthKitSensor {
    /// 心拍数を取得
    public func fetchHRData(_ start:Date) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            return
        }
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let datePredicate = HKQuery.predicateForSamples(withStart: lastHRSyncDate, end: nil, options: .strictEndDate )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate])
        
        let anchor = HKQueryAnchor.init(fromValue: lastHRAnchor) // Int(HKObjectQueryNoLimit)
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: predicate, anchor: anchor , limit:self.CONFIG.fetchLimit ) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            if let samples = sampleObjects as? [HKQuantitySample]{
                var data = Array<HealthKitHeartRateData>()
                for sample in samples {
                    let hr = HealthKitHeartRateData()
                    // device info
                    if let device = sample.device{
                        let json = JSON.init(device.toDictionary())
                        if let rawString = json.rawString() {
                            hr.device = rawString
                        }
                    }
                    hr.type      = sample.quantityType.description
                    hr.heartrate = sample.quantity.doubleValue(for: unit)
                    hr.unit      = unit.unitString
                    hr.startDate = Int64(sample.startDate.timeIntervalSince1970 * 1000)
                    hr.endDate   = Int64(sample.endDate.timeIntervalSince1970 * 1000)
                    if let meta = sample.metadata {
                        let json = JSON.init(meta)
                        if let rawString = json.rawString() {
                            hr.metadata = rawString
                        }
                    }
                    data.append(hr)
                }
                
                if(samples.count > 0){
                    if let last = samples.last {
                        self.lastHRSyncDate = last.endDate
                    }
                    
                    if let engine = self.dbEngine {
                        engine.save(data, HealthKitQuantityData.TABLE_NAME)
                    }
                    
                    if let observer = self.CONFIG.sensorObserver {
                        observer.onHeartRateDataChanged(data: data )
                    }
                    
                    self.lastHRAnchor = anchor.hashValue
                }
                
                if (samples.count == self.CONFIG.fetchLimit){
                    self.isInRecoveryLoopHR = true
                    self.fetchHRData(self.lastHRSyncDate)
                }else{
                    self.isInRecoveryLoopHR = false
                }
            }
        }
        self.healthStore?.execute(heartRateQuery)
    }
    
    
    public var lastHRAnchor:Int {
        get {
            return UserDefaults.standard.integer(forKey: "com.aware.ios.sensor.healthkit.key.last_hr_anchor")
        }
        set {
            UserDefaults.standard.set(newValue, forKey:"com.aware.ios.sensor.healthkit.key.last_hr_anchor")
        }
    }
    
    public var lastHRSyncDate:Date {
        get {
            if let date = UserDefaults.standard.object(forKey: "com.aware.ios.sensor.healthkit.key.last_sync_datetime") as? Date {
                return date
            }
            return Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey:"com.aware.ios.sensor.healthkit.key.last_sync_datetime")
            UserDefaults.standard.synchronize()
        }
    }
}

extension HKDevice {
    public func toDictionary() -> Dictionary<String,Any>{
        // name:Apple Watch, manufacturer:Apple, model:Watch, hardware:Watch2,4, software:5.1.1
        var dict = Dictionary<String,Any>()
        if let uwName = name { dict["name"] = uwName }
        if let uwManufacturer = manufacturer { dict["manufacturer"] = uwManufacturer }
        if let uwModel = model { dict["model"] = uwModel }
        if let uwHardware = hardwareVersion { dict["hardware"] = uwHardware }
        if let uwSoftware = softwareVersion { dict["software"] = uwSoftware }
        return dict
    }
}

/**
 heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
     // self.anchor = newAnchor!
     // self.updateHeartRate(samples)
 }
 */


/// Authorization
extension HealthKitSensor {
    
    public func requestAuthorization() {
        
        guard HKHealthStore.isHealthDataAvailable() == true else {
            return
        }
        
        var dataTypes = Set<HKSampleType>()
        
        if self.CONFIG.statusSleepAnalysis {
            for type in self.getSleepAnalysisHKType(){
                dataTypes.insert(type)
            }
        }
        
        if self.CONFIG.statusHeartRate {
            for type in self.getHeartRateHKType() {
                dataTypes.insert(type)
            }
        }
        
        if self.CONFIG.statusStandHour {
            for type in self.getAppleStandHourHKType() {
                dataTypes.insert(type)
            }
        }
        
        if self.CONFIG.statusActivity {
            for type in self.getActivityHKType() {
                dataTypes.insert(type)
            }
        }
        
        if let healthKit = self.healthStore {
            healthKit.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) -> Void in
                if let observer = self.CONFIG.sensorObserver {
                    observer.onHealthKitAuthorizationStatusChanged(success: success, error: error)
                }
            }
        }
    }
    
    private func getHeartRateHKType() -> Array<HKSampleType>{
        // heart rate
        if let heartRate = HKQuantityType.quantityType(forIdentifier:.heartRate) {
            return [heartRate]
        }
        return []
    }
    
    private func getSleepAnalysisHKType() -> Array<HKSampleType>{
        // sleep
        if let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis ) {
            return [sleepAnalysis]
        }
        return []
    }
    
    private func getAppleStandHourHKType() -> Array<HKSampleType>{
        if let appleStandHour = HKObjectType.categoryType(forIdentifier: .appleStandHour ) {
            return [appleStandHour]
        }
        return []
    }
    
    private func getActivityHKType() -> Array<HKSampleType>{
        
        var types = Array<HKSampleType>()
        // activity
        if let activeEnergyBurned = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned ) {
            types.append(activeEnergyBurned)
        }
        if let appleExerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.append(appleExerciseTime)
        }
        if let basalEnergyBurned = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.append(basalEnergyBurned)
        }
        if let distanceCycling  = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.append(distanceCycling)
        }
        if let distanceSwimming = HKQuantityType.quantityType(forIdentifier: .distanceSwimming){
            types.append(distanceSwimming)
        }
        if let distanceWheelchair = HKQuantityType.quantityType(forIdentifier: .distanceWheelchair) {
            types.append(distanceWheelchair)
        }
        if let distanceWalkingRunning = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.append(distanceWalkingRunning)
        }
        if let flightsClimbed = HKQuantityType.quantityType(forIdentifier: .flightsClimbed){
            types.append(flightsClimbed)
        }
        if let nikeFuel = HKQuantityType.quantityType(forIdentifier: .nikeFuel) {
            types.append(nikeFuel)
        }
        if let pushCount = HKQuantityType.quantityType(forIdentifier: .pushCount){
            types.append(pushCount)
        }
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.append(stepCount)
        }
        if let swimmingStrokeCount = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount) {
            types.append(swimmingStrokeCount)
        }
        if #available(iOS 11.0, *) {
            if let vo2Max = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
                types.append(vo2Max)
            }
        }
        return types
    }
}

