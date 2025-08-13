// swift-tools-version: 6.0
// Package.swift - GestureControlPro

import PackageDescription

let package = Package(
    name: "GestureControlPro",
    platforms: [
        .macOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .executable(
            name: "GestureControlPro",
            targets: ["GestureControlPro"]
        ),
        .library(
            name: "GestureControlKit",
            targets: ["GestureControlKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.15.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.4"),
        .package(url: "https://github.com/XanderXu/HandVector.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "GestureControlPro",
            dependencies: [
                "GestureControlKit",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                "HandVector"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .target(
            name: "GestureControlKit",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                "HandVector"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GestureControlProTests",
            dependencies: ["GestureControlPro", "GestureControlKit"]
        )
    ]
)

