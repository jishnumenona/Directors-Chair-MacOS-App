// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DirectorsChairProduction",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DirectorsChairProduction",
            targets: ["DirectorsChairProduction"]),
    ],
    dependencies: [
        .package(path: "../DirectorsChairCore"),
    ],
    targets: [
        .target(
            name: "DirectorsChairProduction",
            dependencies: ["DirectorsChairCore"]),
        .testTarget(
            name: "DirectorsChairProductionTests",
            dependencies: ["DirectorsChairProduction"]),
    ]
)
