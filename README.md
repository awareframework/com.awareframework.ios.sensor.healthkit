# AWARE: HealthKit 

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements
iOS 13 or later


## Installation
You can integrate this framework into your project via Swift Package Manager (SwiftPM) or CocoaPods.

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

### CocoaPods

com.aware.ios.sensor.healthkit is available through [CocoaPods](https://cocoapods.org). 

1. To install it, simply add the following line to your Podfile:
```ruby
pod 'com.awareframework.ios.sensor.healthkit'
```

2. com_aware_ios_sensor_healthkit  library into your source code.
```swift
import com_awareframework_ios_sensor_healthkit
```

3. Turn on HealthKit capbility on Xcode

4. Add `NSHealthShareUsageDescription` into Info.plist

## Example usage
```swift
let sensor = HealthKitSensor.init(HealthKitSensor.Config().apply{config in
    config.debug = true
    config.sensorObserver = Observer()
    config.isHeartRateFetch = true
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
}
```

## Author

Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## License

Copyright (c) 2021 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

