import XCTest
import com_awareframework_ios_sensor_healthkit

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testConfig(){
        let fetchLimit                = 150
        let interval:Int              = 10 // min
        let statusHeartRate:Bool      = false
        let statusSleepAnalysis:Bool  = false
        let statusActivity:Bool       = false
        let statusStandHour:Bool      = false
        let config:Dictionary<String,Any>
                     = ["fetchLimit": fetchLimit,
                      "interval": interval,
                      "statusHeartRate": statusHeartRate,
                      "statusSleepAnalysis": statusSleepAnalysis,
                      "statusActivity":statusActivity,
                      "statusStandHour":statusStandHour]
        
        // defualt
        var sensor = HealthKitSensor.init()
        XCTAssertEqual(sensor.CONFIG.fetchLimit, 100)
        XCTAssertEqual(sensor.CONFIG.interval, 15)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, true)
        XCTAssertEqual(sensor.CONFIG.statusSleepAnalysis, true)
        XCTAssertEqual(sensor.CONFIG.statusActivity, true)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, true)
        
        // apply
        sensor = HealthKitSensor.init(HealthKitSensor.Config().apply{config in
            config.fetchLimit = fetchLimit
            config.interval = interval
            config.statusStandHour = statusStandHour
            config.statusActivity = statusActivity
            config.statusHeartRate = statusHeartRate
            config.statusSleepAnalysis = statusSleepAnalysis
        })
        XCTAssertEqual(sensor.CONFIG.fetchLimit, fetchLimit)
        XCTAssertEqual(sensor.CONFIG.interval, interval)
        XCTAssertEqual(sensor.CONFIG.statusHeartRate, statusHeartRate)
        XCTAssertEqual(sensor.CONFIG.statusSleepAnalysis, statusSleepAnalysis)
        XCTAssertEqual(sensor.CONFIG.statusActivity, statusActivity)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, statusStandHour)
        
        // set
        sensor = HealthKitSensor()
        sensor.CONFIG.set(config: config)
        XCTAssertEqual(sensor.CONFIG.fetchLimit, fetchLimit)
        XCTAssertEqual(sensor.CONFIG.interval, interval)
        XCTAssertEqual(sensor.CONFIG.statusHeartRate, statusHeartRate)
        XCTAssertEqual(sensor.CONFIG.statusSleepAnalysis, statusSleepAnalysis)
        XCTAssertEqual(sensor.CONFIG.statusActivity, statusActivity)
        XCTAssertEqual(sensor.CONFIG.statusStandHour, statusStandHour)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
