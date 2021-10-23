# AWARE: HealthKit 

[![CI Status](https://img.shields.io/travis/tetujin/com.awareframework.ios.sensor.healthkit.svg?style=flat)](https://travis-ci.org/tetujin/com.awareframework.ios.sensor.healthkit)
[![Version](https://img.shields.io/cocoapods/v/com.awareframework.ios.sensor.healthkit.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.healthkit)
[![License](https://img.shields.io/cocoapods/l/com.awareframework.ios.sensor.healthkit.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.healthkit)
[![Platform](https://img.shields.io/cocoapods/p/com.awareframework.ios.sensor.healthkit.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.healthkit)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

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

Yuuki Nishiyama, yuukin@iis.u-tokyo.ac.jp

## License

Copyright (c) 2021 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

