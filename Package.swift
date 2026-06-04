// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.healthkit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.healthkit",
            targets: [
                "com.awareframework.ios.sensor.healthkit"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.1.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.3.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.2"),
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.healthkit",
            dependencies: [
                .product(
                    name: "com.awareframework.ios.core", package: "com.awareframework.ios.core",
                    condition: .when(platforms: [.iOS])),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
            ],
            path: "Sources/com.awareframework.ios.sensor.healthkit"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.healthkitTests",
            dependencies: [
                .target(name: "com.awareframework.ios.sensor.healthkit")
            ],
            path: "Tests/com.awareframework.ios.sensor.healthkitTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
