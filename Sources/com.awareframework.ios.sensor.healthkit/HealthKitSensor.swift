//
//  HealthKitSensor.swift
//  com.aware.ios.sensor.core
//
//  Created by Yuuki Nishiyama on 2018/11/13.
//

import Foundation
import GRDB
import HealthKit
import SwiftyJSON
import UIKit
import com_awareframework_ios_core

public protocol HealthKitObserver {

    func onHealthKitAuthorizationStatusChanged(success: Bool, error: Error?)
    func onHeartRateDataChanged(data: [HealthKitHeartRateData])
    func onQuantityDataChanged(data: [HealthKitQuantityData])
    func onCategoryDataChanged(data: [HealthKitCategoryData])
    func onElectrocardiogramDataChanged(data: [HealthKitElectrocardiogramData])
    func onWorkoutDataChanged(data: [HealthKitWorkoutData])
    func onActivitySummaryDataChanged(data: [HealthKitActivitySummaryData])
    func onAudiogramDataChanged(data: [HealthKitAudiogramData])
}

extension HealthKitObserver {
    public func onQuantityDataChanged(data: [HealthKitQuantityData]) {}
    public func onCategoryDataChanged(data: [HealthKitCategoryData]) {}
    public func onElectrocardiogramDataChanged(data: [HealthKitElectrocardiogramData]) {}
    public func onWorkoutDataChanged(data: [HealthKitWorkoutData]) {}
    public func onActivitySummaryDataChanged(data: [HealthKitActivitySummaryData]) {}
    public func onAudiogramDataChanged(data: [HealthKitAudiogramData]) {}
}

extension HealthKitSensor {
    public static let ACTION_AWARE_HEALTHKIT = "com.awareframework.ios.sensor.healthkit"
    public static let ACTION_AWARE_HEALTHKIT_START =
        "com.awareframework.ios.sensor.healthkit.ACTION_AWARE_HEALTHKIT_START"
    public static let ACTION_AWARE_HEALTHKIT_STOP =
        "com.awareframework.ios.sensor.healthkit.ACTION_AWARE_HEALTHKIT_STOP"
    public static let ACTION_AWARE_HEALTHKIT_SYNC =
        "com.awareframework.ios.sensor.healthkit.ACTION_AWARE_HEALTHKIT_SYNC"
    public static let ACTION_AWARE_HEALTHKIT_SYNC_COMPLETION =
        "com.awareframework.ios.sensor.healthkit.ACTION_AWARE_HEALTHKIT_SYNC_COMPLETION"
    public static let ACTION_AWARE_HEALTHKIT_SET_LABEL =
        "com.awareframework.ios.sensor.healthkit.ACTION_AWARE_HEALTHKIT_SET_LABEL"

    public static let EXTRA_LABEL = "label"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
}

public class HealthKitSensor: AwareSensor {

    public var healthStore: HKHealthStore?
    private var screenBrightnessObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var lastObservedScreenOnState: Bool = UIScreen.main.brightness > 0

    private var hrTimer: Timer?
    private var isInRecoveryLoopHR: Bool = false

    private var activityTimer: Timer?
    private var isInRecoveryLoopActivity: Bool = false

    private var sleepTimer: Timer?
    private var isInRecoveryLoopSleep: Bool = false

    private var standHourTimer: Timer?
    private var isInRecoveryLoopStandHour: Bool = false

    private var electrocardiogramTimer: Timer?
    private var supplementalTimer: Timer?

    public var CONFIG = Config()

    public class Config: SensorConfig {
        public var fetchLimit = 100
        public var interval: Int = 15  // min
        public var statusHeartRate: Bool = true
        public var statusSleepAnalysis: Bool = true
        public var statusActivity: Bool = true
        public var statusStandHour: Bool = true
        public var statusAllQuantityTypes: Bool = true
        public var statusAllCategoryTypes: Bool = true
        public var statusElectrocardiogram: Bool = true
        public var statusWorkout: Bool = true
        public var statusActivitySummary: Bool = true
        public var statusAudiogram: Bool = true
        public var dataStartDate: Date =
            Calendar.current.date(byAdding: .day, value: -7, to: Date())
            ?? Date(timeIntervalSinceNow: -7 * 24 * 60 * 60)
        public var selectedSensors: [String] = []
        public var selectedQuantityTypeIdentifiers: [String] = []
        public var selectedCategoryTypeIdentifiers: [String] = []
        public var additionalQuantityTypeIdentifiers: [String] = []
        public var additionalCategoryTypeIdentifiers: [String] = []

        public var sensorObserver: HealthKitObserver?
        public override init() {
            super.init()
            dbPath = "aware_health_kit"
        }

        public override func set(config: [String: Any]) {
            super.set(config: config)
            if let fetchLimit = config["fetchLimit"] as? Int {
                self.fetchLimit = fetchLimit
            }
            if let interval = config["interval"] as? Int {
                self.interval = interval
            }
            if let dataStartDate = config["dataStartDate"] as? Date {
                self.dataStartDate = dataStartDate
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
            if config["statusAllQuantityTypes"] != nil {
                self.statusAllQuantityTypes = config["statusAllQuantityTypes"] as! Bool
            }
            if config["statusAllCategoryTypes"] != nil {
                self.statusAllCategoryTypes = config["statusAllCategoryTypes"] as! Bool
            }
            if config["statusElectrocardiogram"] != nil {
                self.statusElectrocardiogram = config["statusElectrocardiogram"] as! Bool
            }
            if config["statusWorkout"] != nil {
                self.statusWorkout = config["statusWorkout"] as! Bool
            }
            if config["statusActivitySummary"] != nil {
                self.statusActivitySummary = config["statusActivitySummary"] as! Bool
            }
            if config["statusAudiogram"] != nil {
                self.statusAudiogram = config["statusAudiogram"] as! Bool
            }
            if let sensors = config["selectedSensors"] as? [String] {
                self.selectedSensors = sensors
            }
            if let identifiers = config["selectedQuantityTypeIdentifiers"] as? [String] {
                self.selectedQuantityTypeIdentifiers = identifiers
            }
            if let identifiers = config["selectedCategoryTypeIdentifiers"] as? [String] {
                self.selectedCategoryTypeIdentifiers = identifiers
            }
            if let identifiers = config["additionalQuantityTypeIdentifiers"] as? [String] {
                self.additionalQuantityTypeIdentifiers = identifiers
            }
            if let identifiers = config["additionalCategoryTypeIdentifiers"] as? [String] {
                self.additionalCategoryTypeIdentifiers = identifiers
            }
        }

        public func apply(closure: (_ config: HealthKitSensor.Config) -> Void) -> Self {
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
        super.syncConfig = DbSyncConfig().apply(closure: { syncConfig in
            syncConfig.serverType = config.serverType
            syncConfig.debug = config.debug
            syncConfig.batchSize = 1000
            syncConfig.dispatchQueue = DispatchQueue(
                label: "com.awareframework.ios.sensor.healthkit.sync.queue")
            syncConfig.completionHandler = { status, error in
                var userInfo: [String: Any] = [HealthKitSensor.EXTRA_STATUS: status]
                if let error = error {
                    userInfo[HealthKitSensor.EXTRA_ERROR] = error
                }
                self.notificationCenter.post(
                    name: .actionAwareHealthKitSyncCompletion,
                    object: self,
                    userInfo: userInfo)
            }
        })
        healthStore = HKHealthStore()
        initializeTables()
    }

    public override func start() {
        self.notificationCenter.post(name: .actionAwareHealthKitStart, object: self)
        self.requestAuthorization()
        self.startScreenSensorIfNeeded()

        if hrTimer == nil {
            hrTimer = Timer.scheduledTimer(
                withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true,
                block: { timer in
                    if !self.isInRecoveryLoopHR {
                        self.fetchHRData(self.lastHRSyncDate)
                    }
                })
        }

        if activityTimer == nil {
            activityTimer = Timer.scheduledTimer(
                withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true,
                block: { _ in
                    if !self.isInRecoveryLoopActivity {
                        self.fetchActivityData()
                    }
                })
        }

        if sleepTimer == nil {
            sleepTimer = Timer.scheduledTimer(
                withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true,
                block: { _ in
                    if !self.isInRecoveryLoopSleep {
                        self.fetchCategoryData()
                    }
                })
        }

        if standHourTimer == nil {
            standHourTimer = Timer.scheduledTimer(
                withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true,
                block: { _ in
                    if !self.isInRecoveryLoopStandHour {
                        self.fetchStandHourData()
                    }
                })
        }

        if electrocardiogramTimer == nil {
            electrocardiogramTimer = Timer.scheduledTimer(
                withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true,
                block: { _ in
                    self.fetchElectrocardiogramData(self.lastElectrocardiogramSyncDate)
                })
        }

        if supplementalTimer == nil {
            supplementalTimer = Timer.scheduledTimer(
                withTimeInterval: Double(self.CONFIG.interval) * 60.0, repeats: true,
                block: { _ in
                    self.fetchSupplementalHealthData()
                })
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

        if let t = sleepTimer {
            t.invalidate()
            self.sleepTimer = nil
        }

        if let t = standHourTimer {
            t.invalidate()
            self.standHourTimer = nil
        }

        if let t = electrocardiogramTimer {
            t.invalidate()
            self.electrocardiogramTimer = nil
        }

        if let t = supplementalTimer {
            t.invalidate()
            self.supplementalTimer = nil
        }

        self.stopScreenObservation()

        self.notificationCenter.post(name: .actionAwareHealthKitStop, object: self)
    }

    public override func sync(force: Bool = false) {
        guard let syncConfig = super.syncConfig else {
            return
        }

        self.notificationCenter.post(name: .actionAwareHealthKitSync, object: self)

        let tables = self.syncableTableNames()
        guard tables.isEmpty == false else {
            syncConfig.completionHandler?(true, nil)
            return
        }

        self.startSequentialSync(
            for: tables,
            syncConfig: syncConfig,
            currentIndex: 0,
            hasFailure: false,
            lastError: nil)
    }

    public override func set(label: String) {
        self.CONFIG.label = label
        self.notificationCenter.post(
            name: .actionAwareHealthKitSetLabel,
            object: self,
            userInfo: [HealthKitSensor.EXTRA_LABEL: label])
    }
}

extension Notification.Name {
    public static let actionAwareHealthKit = Notification.Name(
        HealthKitSensor.ACTION_AWARE_HEALTHKIT)
    public static let actionAwareHealthKitStart = Notification.Name(
        HealthKitSensor.ACTION_AWARE_HEALTHKIT_START)
    public static let actionAwareHealthKitStop = Notification.Name(
        HealthKitSensor.ACTION_AWARE_HEALTHKIT_STOP)
    public static let actionAwareHealthKitSync = Notification.Name(
        HealthKitSensor.ACTION_AWARE_HEALTHKIT_SYNC)
    public static let actionAwareHealthKitSyncCompletion = Notification.Name(
        HealthKitSensor.ACTION_AWARE_HEALTHKIT_SYNC_COMPLETION)
    public static let actionAwareHealthKitSetLabel = Notification.Name(
        HealthKitSensor.ACTION_AWARE_HEALTHKIT_SET_LABEL)
}

extension HealthKitSensor {
    private func stopScreenObservation() {
        if let observer = self.screenBrightnessObserver {
            self.notificationCenter.removeObserver(observer)
            self.screenBrightnessObserver = nil
        }

        if let observer = self.appDidBecomeActiveObserver {
            self.notificationCenter.removeObserver(observer)
            self.appDidBecomeActiveObserver = nil
        }
    }

    private func startScreenSensorIfNeeded() {
        guard self.screenBrightnessObserver == nil, self.appDidBecomeActiveObserver == nil else {
            return
        }

        self.lastObservedScreenOnState = UIScreen.main.brightness > 0

        self.screenBrightnessObserver = self.notificationCenter.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenStateChange()
        }

        self.appDidBecomeActiveObserver = self.notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenOnEvent(force: true)
        }
    }

    private func handleScreenStateChange() {
        let isScreenOn = UIScreen.main.brightness > 0
        if isScreenOn && self.lastObservedScreenOnState == false {
            self.handleScreenOnEvent(force: false)
        }
        self.lastObservedScreenOnState = isScreenOn
    }

    private func handleScreenOnEvent(force: Bool) {
        if force || UIScreen.main.brightness > 0 {
            self.lastObservedScreenOnState = true
            self.fetchAllEnabledData()
        }
    }

    private func fetchAllEnabledData() {
        if !self.isInRecoveryLoopHR {
            self.fetchHRData(self.lastHRSyncDate)
        }

        if !self.isInRecoveryLoopActivity {
            self.fetchActivityData()
        }

        if !self.isInRecoveryLoopSleep {
            self.fetchCategoryData()
        }

        if !self.isInRecoveryLoopStandHour {
            self.fetchStandHourData()
        }

        self.fetchElectrocardiogramData(self.lastElectrocardiogramSyncDate)
        self.fetchSupplementalHealthData()
    }

    private func syncableTableNames() -> [String] {
        return [
            HealthKitHeartRateData.databaseTableName,
            HealthKitQuantityData.databaseTableName,
            HealthKitCategoryData.databaseTableName,
            HealthKitElectrocardiogramData.databaseTableName,
            HealthKitWorkoutData.databaseTableName,
            HealthKitActivitySummaryData.databaseTableName,
            HealthKitAudiogramData.databaseTableName,
        ]
    }

    private func makeSyncConfig(
        from baseConfig: DbSyncConfig,
        completionHandler: DbSyncCompletionHandler?
    ) -> DbSyncConfig {
        let syncConfig = DbSyncConfig()
        syncConfig.removeAfterSync = baseConfig.removeAfterSync
        syncConfig.batchSize = baseConfig.batchSize
        syncConfig.markAsSynced = baseConfig.markAsSynced
        syncConfig.skipSyncedData = baseConfig.skipSyncedData
        syncConfig.keepLastData = baseConfig.keepLastData
        syncConfig.deviceId = baseConfig.deviceId
        syncConfig.debug = baseConfig.debug
        syncConfig.debugLevel = baseConfig.debugLevel
        syncConfig.progressHandler = baseConfig.progressHandler
        syncConfig.dispatchQueue = baseConfig.dispatchQueue
        syncConfig.backgroundSession = baseConfig.backgroundSession
        syncConfig.compactDataFormat = baseConfig.compactDataFormat
        syncConfig.serverType = baseConfig.serverType
        syncConfig.test = baseConfig.test
        syncConfig.completionHandler = completionHandler
        return syncConfig
    }

    private func makeSyncEngine(for tableName: String) -> Engine? {
        return Engine.Builder()
            .setPath(self.CONFIG.dbPath)
            .setType(self.CONFIG.dbType)
            .setHost(self.CONFIG.dbHost)
            .setEncryptionKey(self.CONFIG.dbEncryptionKey)
            .setTableName(tableName)
            .build()
    }

    private func startSequentialSync(
        for tables: [String],
        syncConfig: DbSyncConfig,
        currentIndex: Int,
        hasFailure: Bool,
        lastError: Error?
    ) {
        if currentIndex >= tables.count {
            syncConfig.completionHandler?(hasFailure == false, lastError)
            return
        }

        let tableName = tables[currentIndex]
        guard let engine = self.makeSyncEngine(for: tableName) else {
            self.startSequentialSync(
                for: tables,
                syncConfig: syncConfig,
                currentIndex: currentIndex + 1,
                hasFailure: true,
                lastError: lastError)
            return
        }

        let perTableConfig = self.makeSyncConfig(from: syncConfig) { status, error in
            self.startSequentialSync(
                for: tables,
                syncConfig: syncConfig,
                currentIndex: currentIndex + 1,
                hasFailure: hasFailure || status == false,
                lastError: error ?? lastError)
        }

        engine.startSync(perTableConfig)
    }

    func fetchSupplementalHealthData() {
        if self.shouldCollectWorkout() {
            self.fetchWorkoutData(self.lastWorkoutSyncDate)
        }
        if self.shouldCollectAudiogram() {
            self.fetchAudiogramData(self.lastAudiogramSyncDate)
        }
        if self.shouldCollectActivitySummary() {
            self.fetchActivitySummaryData(self.lastActivitySummarySyncDate)
        }
    }

    func fetchActivityData() {
        var types = [HKQuantityType]()

        if self.hasExplicitSensorSelection() {
            types.append(contentsOf: self.getSelectedQuantityHKType())
        } else {
            if self.CONFIG.statusActivity {
                types.append(
                    contentsOf: self.getActivityHKType().compactMap { $0 as? HKQuantityType })
            }

            if self.CONFIG.statusHeartRate {
                types.append(contentsOf: self.getAdvancedHeartRateHKType())
            }

            if self.CONFIG.statusAllQuantityTypes {
                types.append(contentsOf: self.getGeneralQuantityHKType())
            }
        }

        let uniqueTypes = self.uniqueQuantityTypes(types)
        if uniqueTypes.isEmpty == false {
            self.fetchQuantityData(types: uniqueTypes)
        }
    }

    func fetchCategoryData() {
        var types = [HKCategoryType]()

        if self.hasExplicitSensorSelection() {
            types.append(contentsOf: self.getSelectedCategoryHKType())
        } else {
            if self.CONFIG.statusSleepAnalysis {
                types.append(
                    contentsOf: self.getSleepAnalysisHKType().compactMap { $0 as? HKCategoryType })
            }

            if self.CONFIG.statusAllCategoryTypes {
                types.append(contentsOf: self.getGeneralCategoryHKType())
            }
        }

        let uniqueTypes = self.uniqueCategoryTypes(types)
        if uniqueTypes.isEmpty == false {
            self.fetchCategoryData(types: uniqueTypes)
        }
    }

    func fetchStandHourData() {
        guard self.shouldCollectStandHour() else {
            return
        }

        let types = self.getAppleStandHourHKType().compactMap { $0 as? HKCategoryType }
        if types.isEmpty == false {
            self.fetchCategoryData(types: types)
        }
    }
}

/// extension for HR data
extension HealthKitSensor {
    /// 心拍数を取得
    public func fetchHRData(_ start: Date) {
        guard self.shouldCollectHeartRate() else {
            self.isInRecoveryLoopHR = false
            return
        }
        guard
            let quantityType = HKObjectType.quantityType(
                forIdentifier: HKQuantityTypeIdentifier.heartRate)
        else {
            return
        }
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let datePredicate = HKQuery.predicateForSamples(
            withStart: start, end: nil, options: .strictEndDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate])

        let heartRateQuery = HKAnchoredObjectQuery(
            type: quantityType, predicate: predicate, anchor: nil, limit: self.CONFIG.fetchLimit
        ) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            if let error {
                if self.CONFIG.debug {
                    print(HealthKitSensor.ACTION_AWARE_HEALTHKIT, "heart rate fetch failed: \(error)")
                }
                self.isInRecoveryLoopHR = false
                return
            }
            
            if let samples = sampleObjects as? [HKQuantitySample] {
                var data = [HealthKitHeartRateData]()
                for sample in samples {
                    var hr = HealthKitHeartRateData(
                        timestamp: Int64(sample.endDate.timeIntervalSince1970 * 1000),
                        label: self.CONFIG.label)
                    // device info
                    if let device = sample.device {
                        let json = JSON.init(device.toDictionary())
                        if let rawString = json.rawString() {
                            hr.device = rawString
                        }
                    }
                    hr.type = sample.quantityType.description
                    hr.heartrate = sample.quantity.doubleValue(for: unit)
                    hr.unit = unit.unitString
                    hr.startDate = Int64(sample.startDate.timeIntervalSince1970 * 1000)
                    hr.endDate = Int64(sample.endDate.timeIntervalSince1970 * 1000)
                    hr.label = self.CONFIG.label
                    if let meta = sample.metadata {
                        let json = JSON.init(meta)
                        if let rawString = json.rawString() {
                            hr.metadata = rawString
                        }
                    }
                    data.append(hr)
                }

                if samples.count > 0 {
                    if let last = samples.last {
                        self.lastHRSyncDate = last.endDate
                    }

                    self.saveModels(data)

                    if let observer = self.CONFIG.sensorObserver {
                        observer.onHeartRateDataChanged(data: data)
                    }
                }

                if samples.count == self.CONFIG.fetchLimit {
                    self.isInRecoveryLoopHR = true
                    self.fetchHRData(self.lastHRSyncDate)
                } else {
                    self.isInRecoveryLoopHR = false
                }
            }
        }
        self.healthStore?.execute(heartRateQuery)
    }

    public func fetchQuantityData(types: [HKQuantityType]) {
        for quantityType in types {
            self.fetchQuantityData(
                type: quantityType, start: self.lastQuantitySyncDate(for: quantityType.identifier))
        }
    }

    public func fetchQuantityData(type: HKQuantityType, start: Date) {
        let datePredicate = HKQuery.predicateForSamples(
            withStart: start, end: nil, options: .strictEndDate)
        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        ]
        let query = HKSampleQuery(
            sampleType: type, predicate: datePredicate, limit: self.CONFIG.fetchLimit,
            sortDescriptors: sortDescriptors
        ) { [weak self] _, samples, error in
            guard let self = self else {
                return
            }

            if error != nil {
                self.isInRecoveryLoopActivity = false
                return
            }

            guard let quantitySamples = samples as? [HKQuantitySample],
                quantitySamples.isEmpty == false
            else {
                self.isInRecoveryLoopActivity = false
                return
            }

            let data = quantitySamples.map { sample -> HealthKitQuantityData in
                var quantity = HealthKitQuantityData(
                    timestamp: Int64(sample.endDate.timeIntervalSince1970 * 1000),
                    label: self.CONFIG.label)
                quantity.quantity = sample.quantity.description
                quantity.unit = self.extractUnit(from: sample.quantity.description)
                quantity.type = sample.quantityType.identifier
                quantity.startDate = Int64(sample.startDate.timeIntervalSince1970 * 1000)
                quantity.endDate = Int64(sample.endDate.timeIntervalSince1970 * 1000)
                quantity.device = self.jsonString(from: sample.device?.toDictionary())
                quantity.metadata = self.jsonString(from: sample.metadata)
                return quantity
            }

            self.saveModels(data)
            self.CONFIG.sensorObserver?.onQuantityDataChanged(data: data)

            if let last = quantitySamples.last {
                self.setLastQuantitySyncDate(last.endDate, for: type.identifier)
            }

            if quantitySamples.count == self.CONFIG.fetchLimit {
                self.isInRecoveryLoopActivity = true
                self.fetchQuantityData(
                    type: type, start: self.lastQuantitySyncDate(for: type.identifier))
            } else {
                self.isInRecoveryLoopActivity = false
            }
        }

        self.healthStore?.execute(query)
    }

    public func fetchCategoryData(types: [HKCategoryType]) {
        for categoryType in types {
            self.fetchCategoryData(
                type: categoryType, start: self.lastCategorySyncDate(for: categoryType.identifier))
        }
    }

    public func fetchCategoryData(type: HKCategoryType, start: Date) {
        let datePredicate = HKQuery.predicateForSamples(
            withStart: start, end: nil, options: .strictEndDate)
        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        ]
        let query = HKSampleQuery(
            sampleType: type, predicate: datePredicate, limit: self.CONFIG.fetchLimit,
            sortDescriptors: sortDescriptors
        ) { [weak self] _, samples, error in
            guard let self = self else {
                return
            }

            if error != nil {
                self.isInRecoveryLoopSleep = false
                return
            }

            guard let categorySamples = samples as? [HKCategorySample],
                categorySamples.isEmpty == false
            else {
                self.isInRecoveryLoopSleep = false
                self.isInRecoveryLoopStandHour = false
                return
            }

            let data = categorySamples.map { sample -> HealthKitCategoryData in
                var category = HealthKitCategoryData(
                    timestamp: Int64(sample.endDate.timeIntervalSince1970 * 1000),
                    label: self.CONFIG.label)
                category.category = sample.value
                category.type = sample.categoryType.identifier
                category.startDate = Int64(sample.startDate.timeIntervalSince1970 * 1000)
                category.endDate = Int64(sample.endDate.timeIntervalSince1970 * 1000)
                category.device = self.jsonString(from: sample.device?.toDictionary())
                category.metadata = self.jsonString(from: sample.metadata)
                return category
            }

            self.saveModels(data)
            self.CONFIG.sensorObserver?.onCategoryDataChanged(data: data)

            if let last = categorySamples.last {
                self.setLastCategorySyncDate(last.endDate, for: type.identifier)
            }

            let isStandHourType =
                type.identifier == HKCategoryTypeIdentifier.appleStandHour.rawValue
            if categorySamples.count == self.CONFIG.fetchLimit {
                if isStandHourType {
                    self.isInRecoveryLoopStandHour = true
                } else {
                    self.isInRecoveryLoopSleep = true
                }
                self.fetchCategoryData(
                    type: type, start: self.lastCategorySyncDate(for: type.identifier))
            } else if isStandHourType {
                self.isInRecoveryLoopStandHour = false
            } else {
                self.isInRecoveryLoopSleep = false
            }
        }

        self.healthStore?.execute(query)
    }

    public func fetchElectrocardiogramData(_ start: Date) {
        guard self.CONFIG.statusElectrocardiogram else {
            return
        }

        if #available(iOS 14.0, *) {
            let type = HKElectrocardiogramType.electrocardiogramType()
            let datePredicate = HKQuery.predicateForSamples(
                withStart: start, end: nil, options: .strictEndDate)
            let sortDescriptors = [
                NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            ]
            let query = HKSampleQuery(
                sampleType: type, predicate: datePredicate, limit: self.CONFIG.fetchLimit,
                sortDescriptors: sortDescriptors
            ) { [weak self] _, samples, error in
                guard let self = self else {
                    return
                }

                if error != nil {
                    return
                }

                guard let electrocardiograms = samples as? [HKElectrocardiogram],
                    electrocardiograms.isEmpty == false
                else {
                    return
                }

                let group = DispatchGroup()
                var savedData = [HealthKitElectrocardiogramData]()

                for electrocardiogram in electrocardiograms {
                    group.enter()
                    self.loadElectrocardiogramSample(electrocardiogram) { data in
                        if let data = data {
                            savedData.append(data)
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if savedData.isEmpty == false {
                        self.saveModels(savedData)
                        self.CONFIG.sensorObserver?.onElectrocardiogramDataChanged(data: savedData)
                    }

                    if let last = electrocardiograms.last {
                        self.lastElectrocardiogramSyncDate = last.endDate
                    }

                    if electrocardiograms.count == self.CONFIG.fetchLimit {
                        self.fetchElectrocardiogramData(self.lastElectrocardiogramSyncDate)
                    }
                }
            }

            self.healthStore?.execute(query)
        }
    }

    public func fetchWorkoutData(_ start: Date) {
        guard self.shouldCollectWorkout() else {
            return
        }

        let sampleType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: nil, options: .strictEndDate)
        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        ]
        let query = HKSampleQuery(
            sampleType: sampleType, predicate: predicate, limit: self.CONFIG.fetchLimit,
            sortDescriptors: sortDescriptors
        ) { [weak self] _, samples, error in
            guard let self = self else {
                return
            }
            guard error == nil, let workouts = samples as? [HKWorkout], workouts.isEmpty == false
            else {
                return
            }

            let data = workouts.map { workout -> HealthKitWorkoutData in
                var record = HealthKitWorkoutData(
                    timestamp: Int64(workout.endDate.timeIntervalSince1970 * 1000),
                    label: self.CONFIG.label)
                record.workoutActivityType = Int(workout.workoutActivityType.rawValue)
                record.duration = workout.duration
                record.totalEnergyBurned = workout.totalEnergyBurned?.description ?? ""
                record.totalDistance = workout.totalDistance?.description ?? ""
                record.device = self.jsonString(from: workout.device?.toDictionary())
                record.startDate = Int64(workout.startDate.timeIntervalSince1970 * 1000)
                record.endDate = Int64(workout.endDate.timeIntervalSince1970 * 1000)
                record.metadata = self.jsonString(from: workout.metadata)
                return record
            }

            self.saveModels(data)
            self.CONFIG.sensorObserver?.onWorkoutDataChanged(data: data)

            if let last = workouts.last {
                self.lastWorkoutSyncDate = last.endDate
            }

            if workouts.count == self.CONFIG.fetchLimit {
                self.fetchWorkoutData(self.lastWorkoutSyncDate)
            }
        }

        self.healthStore?.execute(query)
    }

    public func fetchAudiogramData(_ start: Date) {
        guard self.shouldCollectAudiogram() else {
            return
        }

        if #available(iOS 13.0, *) {
            let sampleType = HKObjectType.audiogramSampleType()
            let predicate = HKQuery.predicateForSamples(
                withStart: start, end: nil, options: .strictEndDate)
            let sortDescriptors = [
                NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            ]
            let query = HKSampleQuery(
                sampleType: sampleType, predicate: predicate, limit: self.CONFIG.fetchLimit,
                sortDescriptors: sortDescriptors
            ) { [weak self] _, samples, error in
                guard let self = self else {
                    return
                }
                guard error == nil, let audiograms = samples as? [HKAudiogramSample],
                    audiograms.isEmpty == false
                else {
                    return
                }

                let hertz = HKUnit.hertz()
                let dbhl = HKUnit.decibelHearingLevel()
                let data = audiograms.map { sample -> HealthKitAudiogramData in
                    var record = HealthKitAudiogramData(
                        timestamp: Int64(sample.endDate.timeIntervalSince1970 * 1000),
                        label: self.CONFIG.label)
                    let points = sample.sensitivityPoints.map { point -> [String: Double?] in
                        [
                            "frequency": point.frequency.doubleValue(for: hertz),
                            "leftEarSensitivity": point.leftEarSensitivity?.doubleValue(for: dbhl),
                            "rightEarSensitivity": point.rightEarSensitivity?.doubleValue(
                                for: dbhl),
                        ]
                    }
                    record.sensitivityPoints = self.jsonString(fromOptionalDoubleArray: points)
                    record.device = self.jsonString(from: sample.device?.toDictionary())
                    record.startDate = Int64(sample.startDate.timeIntervalSince1970 * 1000)
                    record.endDate = Int64(sample.endDate.timeIntervalSince1970 * 1000)
                    record.metadata = self.jsonString(from: sample.metadata)
                    return record
                }

                self.saveModels(data)
                self.CONFIG.sensorObserver?.onAudiogramDataChanged(data: data)

                if let last = audiograms.last {
                    self.lastAudiogramSyncDate = last.endDate
                }

                if audiograms.count == self.CONFIG.fetchLimit {
                    self.fetchAudiogramData(self.lastAudiogramSyncDate)
                }
            }

            self.healthStore?.execute(query)
        }
    }

    public func fetchActivitySummaryData(_ start: Date) {
        guard self.shouldCollectActivitySummary() else {
            return
        }

        let calendar = Calendar.current
        let query = HKActivitySummaryQuery(predicate: nil) {
            [weak self] _, summaries, error in
            guard let self = self else {
                return
            }
            guard error == nil, let summaries, summaries.isEmpty == false else {
                return
            }

            let filteredSummaries = summaries.filter { summary in
                let components = summary.dateComponents(for: calendar)
                guard let date = calendar.date(from: components) else {
                    return false
                }
                return date >= start
            }

            guard filteredSummaries.isEmpty == false else {
                return
            }

            let data = filteredSummaries.map { summary -> HealthKitActivitySummaryData in
                let components = summary.dateComponents(for: calendar)
                let summaryDate = String(
                    format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0,
                    components.day ?? 0)
                let timestamp = Int64(
                    (calendar.date(from: components) ?? Date()).timeIntervalSince1970 * 1000)
                var record = HealthKitActivitySummaryData(
                    timestamp: timestamp, label: self.CONFIG.label)
                record.summaryDate = summaryDate
                record.activeEnergyBurned = summary.activeEnergyBurned.description
                record.activeEnergyBurnedGoal = summary.activeEnergyBurnedGoal.description
                if #available(iOS 14.0, *) {
                    record.appleMoveTime = summary.appleMoveTime.description
                    record.appleMoveTimeGoal = summary.appleMoveTimeGoal.description
                    record.activityMoveMode = summary.activityMoveMode.rawValue
                }
                record.appleExerciseTime = summary.appleExerciseTime.description
                if #available(iOS 16.0, *) {
                    record.exerciseTimeGoal =
                        summary.exerciseTimeGoal?.description
                        ?? summary.appleExerciseTimeGoal.description
                    record.standHoursGoal =
                        summary.standHoursGoal?.description
                        ?? summary.appleStandHoursGoal.description
                } else {
                    record.exerciseTimeGoal = summary.appleExerciseTimeGoal.description
                    record.standHoursGoal = summary.appleStandHoursGoal.description
                }
                record.appleStandHours = summary.appleStandHours.description
                if #available(iOS 18.0, *) {
                    record.isPaused = summary.isPaused
                }
                return record
            }

            self.saveModels(data)
            self.CONFIG.sensorObserver?.onActivitySummaryDataChanged(data: data)

            if let last = filteredSummaries.last {
                let lastComponents = last.dateComponents(for: calendar)
                if let lastDate = calendar.date(from: lastComponents) {
                    self.lastActivitySummarySyncDate = lastDate
                }
            }
        }

        self.healthStore?.execute(query)
    }

    @available(iOS 14.0, *)
    private func loadElectrocardiogramSample(
        _ electrocardiogram: HKElectrocardiogram,
        completion: @escaping (HealthKitElectrocardiogramData?) -> Void
    ) {
        var result = HealthKitElectrocardiogramData(
            timestamp: Int64(electrocardiogram.endDate.timeIntervalSince1970 * 1000),
            label: self.CONFIG.label)
        result.classification = self.stringValue(of: electrocardiogram.classification)
        result.symptomsStatus = self.stringValue(of: electrocardiogram.symptomsStatus)
        result.averageHeartRate =
            electrocardiogram.averageHeartRate?.doubleValue(
                for: HKUnit.count().unitDivided(by: HKUnit.minute())) ?? 0
        result.samplingFrequency =
            electrocardiogram.samplingFrequency?.doubleValue(for: HKUnit.hertz()) ?? 0
        result.numberOfVoltageMeasurements = electrocardiogram.numberOfVoltageMeasurements
        result.startDate = Int64(electrocardiogram.startDate.timeIntervalSince1970 * 1000)
        result.endDate = Int64(electrocardiogram.endDate.timeIntervalSince1970 * 1000)
        result.device = self.jsonString(from: electrocardiogram.device?.toDictionary())
        result.metadata = self.jsonString(from: electrocardiogram.metadata)

        var measurements = [[String: Double]]()
        let query = HKElectrocardiogramQuery(electrocardiogram) { _, state in
            switch state {
            case .measurement(let measurement):
                if let quantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                    measurements.append([
                        "timeSinceSampleStart": measurement.timeSinceSampleStart,
                        "voltage": quantity.doubleValue(for: HKUnit.voltUnit(with: .milli)),
                    ])
                }
            case .done:
                result.measurements = self.jsonString(from: measurements)
                completion(result)
            case .error:
                completion(result)
            @unknown default:
                completion(result)
            }
        }

        self.healthStore?.execute(query)
    }

    public var lastHRAnchor: Int {
        get {
            return UserDefaults.standard.integer(
                forKey: "com.aware.ios.sensor.healthkit.key.last_hr_anchor")
        }
        set {
            UserDefaults.standard.set(
                newValue, forKey: "com.aware.ios.sensor.healthkit.key.last_hr_anchor")
        }
    }

    public var lastHRSyncDate: Date {
        get {
            if let date = UserDefaults.standard.object(
                forKey: "com.aware.ios.sensor.healthkit.key.last_sync_datetime") as? Date
            {
                return date
            }
            return self.CONFIG.dataStartDate
        }
        set {
            UserDefaults.standard.set(
                newValue, forKey: "com.aware.ios.sensor.healthkit.key.last_sync_datetime")
            UserDefaults.standard.synchronize()
        }
    }

    public var lastElectrocardiogramSyncDate: Date {
        get {
            if let date = UserDefaults.standard.object(
                forKey: "com.aware.ios.sensor.healthkit.key.last_electrocardiogram_sync_datetime")
                as? Date
            {
                return date
            }
            return self.CONFIG.dataStartDate
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: "com.aware.ios.sensor.healthkit.key.last_electrocardiogram_sync_datetime")
            UserDefaults.standard.synchronize()
        }
    }

    private func lastQuantitySyncDate(for identifier: String) -> Date {
        if let date = UserDefaults.standard.object(
            forKey: self.syncKey(prefix: "quantity", identifier: identifier)) as? Date
        {
            return date
        }
        return self.CONFIG.dataStartDate
    }

    private func setLastQuantitySyncDate(_ date: Date, for identifier: String) {
        UserDefaults.standard.set(
            date, forKey: self.syncKey(prefix: "quantity", identifier: identifier))
        UserDefaults.standard.synchronize()
    }

    private func lastCategorySyncDate(for identifier: String) -> Date {
        if let date = UserDefaults.standard.object(
            forKey: self.syncKey(prefix: "category", identifier: identifier)) as? Date
        {
            return date
        }
        return self.CONFIG.dataStartDate
    }

    private func setLastCategorySyncDate(_ date: Date, for identifier: String) {
        UserDefaults.standard.set(
            date, forKey: self.syncKey(prefix: "category", identifier: identifier))
        UserDefaults.standard.synchronize()
    }

    private func syncKey(prefix: String, identifier: String) -> String {
        return "com.aware.ios.sensor.healthkit.key.\(prefix).\(identifier)"
    }

    public var lastWorkoutSyncDate: Date {
        get {
            if let date = UserDefaults.standard.object(
                forKey: "com.aware.ios.sensor.healthkit.key.last_workout_sync_datetime") as? Date
            {
                return date
            }
            return self.CONFIG.dataStartDate
        }
        set {
            UserDefaults.standard.set(
                newValue, forKey: "com.aware.ios.sensor.healthkit.key.last_workout_sync_datetime")
            UserDefaults.standard.synchronize()
        }
    }

    public var lastAudiogramSyncDate: Date {
        get {
            if let date = UserDefaults.standard.object(
                forKey: "com.aware.ios.sensor.healthkit.key.last_audiogram_sync_datetime") as? Date
            {
                return date
            }
            return self.CONFIG.dataStartDate
        }
        set {
            UserDefaults.standard.set(
                newValue, forKey: "com.aware.ios.sensor.healthkit.key.last_audiogram_sync_datetime")
            UserDefaults.standard.synchronize()
        }
    }

    public var lastActivitySummarySyncDate: Date {
        get {
            if let date = UserDefaults.standard.object(
                forKey: "com.aware.ios.sensor.healthkit.key.last_activity_summary_sync_datetime")
                as? Date
            {
                return date
            }
            return self.CONFIG.dataStartDate
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: "com.aware.ios.sensor.healthkit.key.last_activity_summary_sync_datetime")
            UserDefaults.standard.synchronize()
        }
    }

    public func resetSyncDates() {
        let defaults = UserDefaults.standard
        let keyPrefix = "com.aware.ios.sensor.healthkit.key."
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(keyPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()
    }
}

extension HKDevice {
    public func toDictionary() -> [String: Any] {
        // name:Apple Watch, manufacturer:Apple, model:Watch, hardware:Watch2,4, software:5.1.1
        var dict = [String: Any]()
        if let uwName = name { dict["name"] = uwName }
        if let uwManufacturer = manufacturer { dict["manufacturer"] = uwManufacturer }
        if let uwModel = model { dict["model"] = uwModel }
        if let uwHardware = hardwareVersion { dict["hardware"] = uwHardware }
        if let uwSoftware = softwareVersion { dict["software"] = uwSoftware }
        return dict
    }
}

extension HealthKitSensor {
    private func hasExplicitSensorSelection() -> Bool {
        return self.CONFIG.selectedSensors.isEmpty == false
            || self.CONFIG.selectedQuantityTypeIdentifiers.isEmpty == false
            || self.CONFIG.selectedCategoryTypeIdentifiers.isEmpty == false
    }

    private func normalizedSelectedSensors() -> Set<String> {
        return Set(
            self.CONFIG.selectedSensors.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }.filter { $0.isEmpty == false })
    }

    private func selectedQuantityIdentifierSet() -> Set<String> {
        return Set(self.CONFIG.selectedQuantityTypeIdentifiers)
    }

    private func selectedCategoryIdentifierSet() -> Set<String> {
        return Set(self.CONFIG.selectedCategoryTypeIdentifiers)
    }

    private func hasSelectedSensorAlias(_ aliases: [String]) -> Bool {
        let selectedSensors = self.normalizedSelectedSensors()
        return aliases.contains { selectedSensors.contains($0) }
    }

    private func shouldCollectHeartRate() -> Bool {
        if self.hasExplicitSensorSelection() {
            return self.hasSelectedSensorAlias(["heartrate", "heart", "cardiac"])
                || self.selectedQuantityIdentifierSet().contains(
                    HKQuantityTypeIdentifier.heartRate.rawValue)
        }
        return self.CONFIG.statusHeartRate
    }

    private func shouldCollectSleepAnalysis() -> Bool {
        if self.hasExplicitSensorSelection() {
            return self.hasSelectedSensorAlias(["sleepanalysis", "sleep"])
                || self.selectedCategoryIdentifierSet().contains(
                    HKCategoryTypeIdentifier.sleepAnalysis.rawValue)
        }
        return self.CONFIG.statusSleepAnalysis
    }

    private func shouldCollectStandHour() -> Bool {
        if self.hasExplicitSensorSelection() {
            return self.hasSelectedSensorAlias(["applestandhour", "stand", "standing"])
                || self.selectedCategoryIdentifierSet().contains(
                    HKCategoryTypeIdentifier.appleStandHour.rawValue)
        }
        return self.CONFIG.statusStandHour
    }

    private func shouldCollectElectrocardiogram() -> Bool {
        if self.hasExplicitSensorSelection() {
            return self.hasSelectedSensorAlias(["electrocardiogram", "ecg", "cardiac"])
        }
        return self.CONFIG.statusElectrocardiogram
    }

    private func shouldCollectWorkout() -> Bool {
        if self.hasExplicitSensorSelection() {
            return self.hasSelectedSensorAlias(["workout", "activity"])
        }
        return self.CONFIG.statusWorkout
    }

    private func shouldCollectActivitySummary() -> Bool {
        if self.hasExplicitSensorSelection() {
            return self.hasSelectedSensorAlias(["activitysummary", "activity"])
        }
        return self.CONFIG.statusActivitySummary
    }

    private func shouldCollectAudiogram() -> Bool {
        if self.hasExplicitSensorSelection() {
            return self.hasSelectedSensorAlias(["audiogram", "hearing"])
        }
        return self.CONFIG.statusAudiogram
    }

    private func activityQuantityTypeIdentifiers() -> [HKQuantityTypeIdentifier] {
        return [
            .activeEnergyBurned, .appleExerciseTime, .basalEnergyBurned, .distanceCycling,
            .distanceSwimming, .distanceWheelchair, .distanceWalkingRunning, .flightsClimbed,
            .nikeFuel, .pushCount, .stepCount, .swimmingStrokeCount, .vo2Max,
        ]
    }

    private func bodyQuantityTypeIdentifiers() -> [HKQuantityTypeIdentifier] {
        return [
            .bodyMassIndex, .bodyFatPercentage, .height, .bodyMass, .leanBodyMass,
            .waistCircumference,
        ]
    }

    private func vitalQuantityTypeIdentifiers() -> [HKQuantityTypeIdentifier] {
        var identifiers: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN, .restingHeartRate, .walkingHeartRateAverage,
            .oxygenSaturation, .bloodGlucose, .bloodPressureSystolic, .bloodPressureDiastolic,
            .bodyTemperature, .respiratoryRate, .forcedVitalCapacity,
            .forcedExpiratoryVolume1, .peakExpiratoryFlowRate, .inhalerUsage,
            .insulinDelivery, .numberOfTimesFallen, .electrodermalActivity,
            .environmentalAudioExposure, .uvExposure,
        ]

        if #available(iOS 14.0, *) {
            identifiers.append(.headphoneAudioExposure)
        }
        return identifiers
    }

    private func nutritionQuantityTypeIdentifiers() -> [HKQuantityTypeIdentifier] {
        return [
            .dietaryEnergyConsumed, .dietaryCarbohydrates, .dietaryProtein, .dietaryFatTotal,
            .dietaryFatPolyunsaturated, .dietaryFatMonounsaturated, .dietaryFatSaturated,
            .dietaryCholesterol, .dietarySodium, .dietaryFiber, .dietarySugar, .dietaryWater,
            .dietaryCaffeine, .dietaryVitaminA, .dietaryVitaminB6, .dietaryVitaminB12,
            .dietaryVitaminC, .dietaryVitaminD, .dietaryVitaminE, .dietaryVitaminK,
            .dietaryCalcium, .dietaryIron, .dietaryThiamin, .dietaryRiboflavin,
            .dietaryNiacin, .dietaryFolate, .dietaryBiotin, .dietaryPantothenicAcid,
            .dietaryPhosphorus, .dietaryIodine, .dietaryMagnesium, .dietaryZinc,
            .dietarySelenium, .dietaryCopper, .dietaryManganese, .dietaryChromium,
            .dietaryMolybdenum, .dietaryChloride, .dietaryPotassium,
        ]
    }

    private func categoryEventTypeIdentifiers() -> [HKCategoryTypeIdentifier] {
        return [
            .mindfulSession, .highHeartRateEvent, .lowHeartRateEvent, .irregularHeartRhythmEvent,
            .toothbrushingEvent, .cervicalMucusQuality, .ovulationTestResult, .menstrualFlow,
            .intermenstrualBleeding, .sexualActivity,
        ]
    }

    private func getAdvancedHeartRateHKType() -> [HKQuantityType] {
        return self.uniqueQuantityTypes(
            self.vitalQuantityTypeIdentifiers().prefix(3).compactMap {
                HKQuantityType.quantityType(forIdentifier: $0)
            })
    }

    private func getGeneralQuantityHKType() -> [HKQuantityType] {
        var identifiers = self.bodyQuantityTypeIdentifiers()
        identifiers.append(contentsOf: self.activityQuantityTypeIdentifiers())
        identifiers.append(
            contentsOf: self.vitalQuantityTypeIdentifiers().filter {
                $0 != .heartRateVariabilitySDNN && $0 != .restingHeartRate
                    && $0 != .walkingHeartRateAverage
            })
        identifiers.append(contentsOf: self.nutritionQuantityTypeIdentifiers())

        let additionalIdentifiers = self.CONFIG.additionalQuantityTypeIdentifiers.compactMap {
            HKQuantityTypeIdentifier(rawValue: $0)
        }
        identifiers.append(contentsOf: additionalIdentifiers)
        return self.uniqueQuantityTypes(
            identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    private func getGeneralCategoryHKType() -> [HKCategoryType] {
        var identifiers = self.categoryEventTypeIdentifiers()

        let additionalIdentifiers = self.CONFIG.additionalCategoryTypeIdentifiers.compactMap {
            HKCategoryTypeIdentifier(rawValue: $0)
        }
        identifiers.append(contentsOf: additionalIdentifiers)
        return self.uniqueCategoryTypes(
            identifiers.compactMap { HKCategoryType.categoryType(forIdentifier: $0) })
    }

    private func getSelectedQuantityHKType() -> [HKQuantityType] {
        var selectedIdentifiers = self.CONFIG.selectedQuantityTypeIdentifiers.filter {
            $0 != HKQuantityTypeIdentifier.heartRate.rawValue
        }

        if self.hasSelectedSensorAlias(["activity"]) {
            selectedIdentifiers.append(
                contentsOf: self.activityQuantityTypeIdentifiers().map { $0.rawValue })
        }
        if self.hasSelectedSensorAlias(["body"]) {
            selectedIdentifiers.append(
                contentsOf: self.bodyQuantityTypeIdentifiers().map { $0.rawValue })
        }
        if self.hasSelectedSensorAlias(["vitals", "vital"]) {
            selectedIdentifiers.append(
                contentsOf: self.vitalQuantityTypeIdentifiers().map { $0.rawValue })
        }
        if self.hasSelectedSensorAlias(["nutrition", "dietary", "diet"]) {
            selectedIdentifiers.append(
                contentsOf: self.nutritionQuantityTypeIdentifiers().map { $0.rawValue })
        }
        if self.hasSelectedSensorAlias(["heart", "cardiac"]) {
            selectedIdentifiers.append(
                contentsOf: self.getAdvancedHeartRateHKType().map { $0.identifier })
        }

        return self.uniqueQuantityTypes(
            selectedIdentifiers.compactMap {
                HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: $0))
            })
    }

    private func getSelectedCategoryHKType() -> [HKCategoryType] {
        let excludedIdentifiers = Set([
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            HKCategoryTypeIdentifier.appleStandHour.rawValue,
        ])
        var selectedIdentifiers = self.CONFIG.selectedCategoryTypeIdentifiers.filter {
            excludedIdentifiers.contains($0) == false
        }

        if self.hasSelectedSensorAlias(["categoryevents", "categoryevent", "events"]) {
            selectedIdentifiers.append(
                contentsOf: self.categoryEventTypeIdentifiers().map { $0.rawValue })
        }

        return self.uniqueCategoryTypes(
            selectedIdentifiers.compactMap {
                HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: $0))
            })
    }

    private func uniqueQuantityTypes(_ types: [HKQuantityType]) -> [HKQuantityType] {
        var seen = Set<String>()
        return types.filter { seen.insert($0.identifier).inserted }
    }

    private func uniqueCategoryTypes(_ types: [HKCategoryType]) -> [HKCategoryType] {
        var seen = Set<String>()
        return types.filter { seen.insert($0.identifier).inserted }
    }

    private func jsonString(from dictionary: [String: Any]?) -> String {
        guard let dictionary = dictionary else {
            return ""
        }

        let json = JSON(dictionary)
        return json.rawString() ?? ""
    }

    private func jsonString(from array: [[String: Double]]) -> String {
        let json = JSON(array)
        return json.rawString() ?? ""
    }

    private func jsonString(fromOptionalDoubleArray array: [[String: Double?]]) -> String {
        let json = JSON(array)
        return json.rawString() ?? ""
    }

    private func extractUnit(from quantityDescription: String) -> String {
        let parts = quantityDescription.split(
            separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            return ""
        }
        return String(parts[1])
    }

    private func stringValue<T>(of value: T) -> String {
        return String(describing: value)
    }

    private func initializeTables() {
        guard let queue = (self.dbEngine as? SQLiteEngine)?.getSQLiteInstance() else {
            return
        }

        do {
            try HealthKitHeartRateData.createTable(queue: queue)
            try HealthKitQuantityData.createTable(queue: queue)
            try HealthKitCategoryData.createTable(queue: queue)
            try HealthKitElectrocardiogramData.createTable(queue: queue)
            try HealthKitWorkoutData.createTable(queue: queue)
            try HealthKitActivitySummaryData.createTable(queue: queue)
            try HealthKitAudiogramData.createTable(queue: queue)
        } catch {
            if self.CONFIG.debug {
                print(error)
            }
        }
    }

    private func saveModels<T: BaseDbModelSQLite>(_ models: [T]) {
        guard let engine = self.dbEngine as? SQLiteEngine else {
            return
        }
        engine.save(models)
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

    func resolvedReadTypes() -> Set<HKObjectType> {

        var dataTypes = Set<HKObjectType>()

        if self.shouldCollectSleepAnalysis() {
            for type in self.getSleepAnalysisHKType() {
                dataTypes.insert(type)
            }
        }

        if self.shouldCollectHeartRate() {
            for type in self.getHeartRateHKType() {
                dataTypes.insert(type)
            }
        }

        if self.shouldCollectStandHour() {
            for type in self.getAppleStandHourHKType() {
                dataTypes.insert(type)
            }
        }

        if self.hasExplicitSensorSelection() {
            for type in self.getSelectedQuantityHKType() {
                dataTypes.insert(type)
            }
            for type in self.getSelectedCategoryHKType() {
                dataTypes.insert(type)
            }
        } else {
            if self.CONFIG.statusActivity {
                for type in self.getActivityHKType() {
                    dataTypes.insert(type)
                }
            }

            if self.CONFIG.statusAllQuantityTypes {
                for type in self.getGeneralQuantityHKType() {
                    dataTypes.insert(type)
                }
            }

            if self.CONFIG.statusAllCategoryTypes {
                for type in self.getGeneralCategoryHKType() {
                    dataTypes.insert(type)
                }
            }
        }

        if self.shouldCollectElectrocardiogram() {
            for type in self.getElectrocardiogramHKType() {
                dataTypes.insert(type)
            }
        }

        if self.shouldCollectWorkout() {
            for type in self.getWorkoutHKType() {
                dataTypes.insert(type)
            }
        }

        if self.shouldCollectAudiogram() {
            for type in self.getAudiogramHKType() {
                dataTypes.insert(type)
            }
        }

        if self.shouldCollectActivitySummary() {
            for type in self.getActivitySummaryHKType() {
                dataTypes.insert(type)
            }
        }

        return dataTypes
    }

    func resolvedReadTypeIdentifiers() -> Set<String> {
        return Set(self.resolvedReadTypes().map { $0.identifier })
    }

    public func requestAuthorization() {

        guard HKHealthStore.isHealthDataAvailable() == true else {
            return
        }

        let dataTypes = self.resolvedReadTypes()

        if let healthKit = self.healthStore {
            healthKit.requestAuthorization(toShare: nil, read: dataTypes) {
                (success, error) -> Void in
                if let observer = self.CONFIG.sensorObserver {
                    observer.onHealthKitAuthorizationStatusChanged(success: success, error: error)
                }
                if success {
                    self.fetchAllEnabledData()
                }
            }
        }
    }

    private func getHeartRateHKType() -> [HKSampleType] {
        // heart rate
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            return [heartRate]
        }
        return []
    }

    private func getSleepAnalysisHKType() -> [HKSampleType] {
        // sleep
        if let sleepAnalysis: HKCategoryType = HKObjectType.categoryType(
            forIdentifier: .sleepAnalysis)
        {
            return [sleepAnalysis]
        }
        return []
    }

    private func getAppleStandHourHKType() -> [HKSampleType] {
        if let appleStandHour = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            return [appleStandHour]
        }
        return []
    }

    private func getActivityHKType() -> [HKSampleType] {

        var types = [HKSampleType]()
        // activity
        if let activeEnergyBurned = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        {
            types.append(activeEnergyBurned)
        }
        if let appleExerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.append(appleExerciseTime)
        }
        if let basalEnergyBurned = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.append(basalEnergyBurned)
        }
        if let distanceCycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.append(distanceCycling)
        }
        if let distanceSwimming = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            types.append(distanceSwimming)
        }
        if let distanceWheelchair = HKQuantityType.quantityType(forIdentifier: .distanceWheelchair)
        {
            types.append(distanceWheelchair)
        }
        if let distanceWalkingRunning = HKQuantityType.quantityType(
            forIdentifier: .distanceWalkingRunning)
        {
            types.append(distanceWalkingRunning)
        }
        if let flightsClimbed = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            types.append(flightsClimbed)
        }
        if let nikeFuel = HKQuantityType.quantityType(forIdentifier: .nikeFuel) {
            types.append(nikeFuel)
        }
        if let pushCount = HKQuantityType.quantityType(forIdentifier: .pushCount) {
            types.append(pushCount)
        }
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.append(stepCount)
        }
        if let swimmingStrokeCount = HKQuantityType.quantityType(
            forIdentifier: .swimmingStrokeCount)
        {
            types.append(swimmingStrokeCount)
        }
        if #available(iOS 11.0, *) {
            if let vo2Max = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
                types.append(vo2Max)
            }
        }
        return types
    }

    private func getElectrocardiogramHKType() -> [HKSampleType] {
        if #available(iOS 14.0, *) {
            return [HKObjectType.electrocardiogramType()]
        }
        return []
    }

    private func getWorkoutHKType() -> [HKObjectType] {
        [HKObjectType.workoutType()]
    }

    private func getAudiogramHKType() -> [HKObjectType] {
        if #available(iOS 13.0, *) {
            return [HKObjectType.audiogramSampleType()]
        }
        return []
    }

    private func getActivitySummaryHKType() -> [HKObjectType] {
        if #available(iOS 9.3, *) {
            return [HKObjectType.activitySummaryType()]
        }
        return []
    }
}
