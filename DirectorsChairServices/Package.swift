// swift-tools-version: 5.9
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
            targets: ["DirectorsChairServices"]
        ),
    ],
    dependencies: [
        .package(path: "../DirectorsChairCore")
    ],
    targets: [
        .target(
            name: "DirectorsChairServices",
            dependencies: ["DirectorsChairCore"]
        ),
        .testTarget(
            name: "DirectorsChairServicesTests",
            dependencies: ["DirectorsChairServices"]
        ),
    ]
)
