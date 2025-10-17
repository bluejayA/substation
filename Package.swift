// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "substation",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OSClient", targets: ["OSClient"]),
        .library(name: "SwiftNCurses", targets: ["SwiftNCurses"]),
        .library(name: "CrossPlatformTimer", targets: ["CrossPlatformTimer"]),
        .library(name: "MemoryKit", targets: ["MemoryKit"]),
        .executable(name: "substation", targets: ["Substation"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "MemoryKit",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .target(
            name: "CrossPlatformTimer",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .target(
            name: "OSClient",
            dependencies: [
                "CrossPlatformTimer",
                "MemoryKit",
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .systemLibrary(
            name: "CNCurses",
            path: "Sources/CNCurses"
        ),
        .target(
            name: "SwiftNCurses",
            dependencies: ["CNCurses", "CrossPlatformTimer", "MemoryKit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "Substation",
            dependencies: [
                "OSClient",
                "SwiftNCurses",
                "CrossPlatformTimer",
                "MemoryKit",
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "OSClientTests",
            dependencies: ["OSClient"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "TUITests",
            dependencies: ["Substation"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "SubstationTests",
            dependencies: ["Substation", "OSClient", "SwiftNCurses"],
            exclude: ["TestFramework.swift", "TestRunner.swift"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        )
    ]
)
