// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DirectorsChairServices",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DirectorsChairServices",
            targets: ["DirectorsChairServices"]),
    ],
    targets: [
        .target(
            name: "DirectorsChairServices",
            dependencies: []),
        .testTarget(
            name: "DirectorsChairServicesTests",
            dependencies: ["DirectorsChairServices"]),
    ]
)
