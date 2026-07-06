// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DirectorsChairCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DirectorsChairCore",
            targets: ["DirectorsChairCore"]),
    ],
    targets: [
        .target(
            name: "DirectorsChairCore",
            dependencies: [],
            // WS2.7: enforce complete strict-concurrency checking so any future
            // data-race / Sendable regression surfaces as a build warning.
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "DirectorsChairCoreTests",
            dependencies: ["DirectorsChairCore"]),
    ]
)
