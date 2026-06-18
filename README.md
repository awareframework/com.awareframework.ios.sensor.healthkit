# AWARE: HealthKit
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

## Requirements
iOS 13 or later

## Installation
You can integrate this framework into your project via Swift Package Manager (SwiftPM).

### SwiftPM
1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...`

2. Find the package using the manager
    * Select `Search Package URL` and type `git@github.com:awareframework/com.awareframework.ios.sensor.healthkit.git`

3. Import the package into your target.

4. com_aware_ios_sensor_healthkit  library into your source code.
```swift
import com_awareframework_ios_sensor_healthkit
```
5. Turn on HealthKit capbility on Xcode


## Example Usage
```swift
let sensor = HealthKitSensor.init(HealthKitSensor.Config().apply { config in
    config.debug = true
    config.sampleIntervalSeconds = 900
    config.sensorObserver = Observer()
    config.statusHeartRate = true
    config.statusAllQuantityTypes = true
    config.statusAllCategoryTypes = true
    config.statusElectrocardiogram = true
    config.statusWorkout = true
    config.statusActivitySummary = true
    config.statusAudiogram = true
})
sensor.start()
```

To collect only specific sensors, set one or more selection lists. When any selection list is non-empty, the package only requests and collects the selected sensors.

```swift
let sensor = HealthKitSensor.init(HealthKitSensor.Config().apply { config in
    config.debug = true
    config.sensorObserver = Observer()

    // Special sensors
    config.selectedSensors = [
        "activity",
        "vitals",
        "sleep",
        "electrocardiogram",
        "workout"
    ]

    // Arbitrary HKQuantityTypeIdentifier raw values
    config.selectedQuantityTypeIdentifiers = [
        HKQuantityTypeIdentifier.stepCount.rawValue,
        HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue,
        HKQuantityTypeIdentifier.restingHeartRate.rawValue,
    ]

    // Arbitrary HKCategoryTypeIdentifier raw values
    config.selectedCategoryTypeIdentifiers = [
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
        HKCategoryTypeIdentifier.appleStandHour.rawValue,
    ]
})
sensor.start()
```

```swift
class Observer:HealthKitObserver {
    func onHealthKitAuthorizationStatusChanged(success: Bool, error: Error?) {
        // Your code here..
    }

    func onHeartRateDataChanged(data: [HealthKitHeartRateData]) {
        // Your code here..
    }

    func onQuantityDataChanged(data: [HealthKitQuantityData]) {
        // Resting / walking heart rate, HRV, activity, body, nutrition, vitals
    }

    func onCategoryDataChanged(data: [HealthKitCategoryData]) {
        // Sleep analysis and other category events
    }

    func onElectrocardiogramDataChanged(data: [HealthKitElectrocardiogramData]) {
        // ECG summary and waveform samples
    }

    func onWorkoutDataChanged(data: [HealthKitWorkoutData]) {
        // Workout samples
    }

    func onActivitySummaryDataChanged(data: [HealthKitActivitySummaryData]) {
        // Daily Activity Rings summaries
    }

    func onAudiogramDataChanged(data: [HealthKitAudiogramData]) {
        // Audiogram sensitivity points
    }
}
```

## Supported HealthKit data

The package now reads these HealthKit sample families:

- Priority sensors: sleep analysis, heart rate variability (SDNN), resting heart rate, walking heart rate average, electrocardiogram
- Additional object types: workouts, activity summaries, audiograms
- Activity quantities: steps, walking/running/cycling/swimming distance, exercise time, energy burned, flights climbed, strokes, push count, VO2 max
- Body and vital quantities: body mass, BMI, body fat, lean body mass, waist circumference, blood pressure, blood glucose, oxygen saturation, respiratory rate, body temperature, lung function, falls, electrodermal activity, audio exposure
- Nutrition quantities: energy, macros, water, caffeine, vitamins, minerals
- Category events: apple stand hour, mindfulness, irregular/high/low heart-rate events, cycle tracking events, toothbrushing

The new object-type toggles are `statusWorkout`, `statusActivitySummary`, and `statusAudiogram`.

If you want to collect only a subset of sensors, use these selection properties:

- `selectedSensors`: high-level categories and special sensors such as `activity`, `body`, `vitals`, `nutrition`, `categoryEvents`, `heart`, `heartRate`, `sleep`, `sleepAnalysis`, `appleStandHour`, `electrocardiogram`, `ecg`, `workout`, `activitySummary`, `audiogram`
- `selectedQuantityTypeIdentifiers`: explicit `HKQuantityTypeIdentifier` raw values to read
- `selectedCategoryTypeIdentifiers`: explicit `HKCategoryTypeIdentifier` raw values to read

When any of the selection properties above is non-empty, the selection acts as an allowlist and only the selected sensors are authorized and collected.

### Selectable sensor candidates

You can use the following candidates as a starting point when configuring `selectedSensors`, `selectedQuantityTypeIdentifiers`, and `selectedCategoryTypeIdentifiers`.

#### `selectedSensors` candidates

- Common quantity categories: `activity`, `body`, `vitals`, `nutrition`
- Common category groups: `categoryEvents`
- Heart and cardiac: `heart`, `heartRate`, `electrocardiogram`, `ecg`
- Sleep and standing: `sleep`, `sleepAnalysis`, `appleStandHour`
- Activity and workout objects: `workout`, `activitySummary`
- Hearing objects: `audiogram`

The category-style keys above are independent top-level selectors. For example, `activity` collects activity-related quantity types, `body` collects body composition metrics, `vitals` collects vital signs and related measurements, `nutrition` collects dietary quantities, and `categoryEvents` collects general HealthKit category events.

#### Common `selectedQuantityTypeIdentifiers` candidates

- `HKQuantityTypeIdentifier.stepCount`
- `HKQuantityTypeIdentifier.distanceWalkingRunning`
- `HKQuantityTypeIdentifier.distanceCycling`
- `HKQuantityTypeIdentifier.distanceSwimming`
- `HKQuantityTypeIdentifier.activeEnergyBurned`
- `HKQuantityTypeIdentifier.appleExerciseTime`
- `HKQuantityTypeIdentifier.flightsClimbed`
- `HKQuantityTypeIdentifier.vo2Max`
- `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`
- `HKQuantityTypeIdentifier.restingHeartRate`
- `HKQuantityTypeIdentifier.walkingHeartRateAverage`
- `HKQuantityTypeIdentifier.bodyMass`
- `HKQuantityTypeIdentifier.bodyMassIndex`
- `HKQuantityTypeIdentifier.bodyFatPercentage`
- `HKQuantityTypeIdentifier.leanBodyMass`
- `HKQuantityTypeIdentifier.waistCircumference`
- `HKQuantityTypeIdentifier.bloodPressureSystolic`
- `HKQuantityTypeIdentifier.bloodPressureDiastolic`
- `HKQuantityTypeIdentifier.bloodGlucose`
- `HKQuantityTypeIdentifier.oxygenSaturation`
- `HKQuantityTypeIdentifier.respiratoryRate`
- `HKQuantityTypeIdentifier.bodyTemperature`
- `HKQuantityTypeIdentifier.environmentalAudioExposure`
- `HKQuantityTypeIdentifier.headphoneAudioExposure`
- `HKQuantityTypeIdentifier.dietaryEnergyConsumed`
- `HKQuantityTypeIdentifier.dietaryWater`
- `HKQuantityTypeIdentifier.dietaryCaffeine`
- `HKQuantityTypeIdentifier.dietaryProtein`

#### Common `selectedCategoryTypeIdentifiers` candidates

- `HKCategoryTypeIdentifier.sleepAnalysis`
- `HKCategoryTypeIdentifier.appleStandHour`
- `HKCategoryTypeIdentifier.mindfulSession`
- `HKCategoryTypeIdentifier.highHeartRateEvent`
- `HKCategoryTypeIdentifier.lowHeartRateEvent`
- `HKCategoryTypeIdentifier.irregularHeartRhythmEvent`
- `HKCategoryTypeIdentifier.toothbrushingEvent`
- `HKCategoryTypeIdentifier.menstrualFlow`
- `HKCategoryTypeIdentifier.intermenstrualBleeding`
- `HKCategoryTypeIdentifier.sexualActivity`
- `HKCategoryTypeIdentifier.ovulationTestResult`
- `HKCategoryTypeIdentifier.cervicalMucusQuality`

### Latest identifier references

Apple can add or deprecate identifiers in new iOS releases. For the latest list, refer to the official documentation:

- `HKQuantityTypeIdentifier`: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier
- `HKCategoryTypeIdentifier`: https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier
- `HKObjectType`: https://developer.apple.com/documentation/healthkit/hkobjecttype

If you need a specific HealthKit identifier that is not enabled by default, add its raw value through `additionalQuantityTypeIdentifiers` or `additionalCategoryTypeIdentifiers`.

## Author

Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## License

Copyright (c) 2021 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
