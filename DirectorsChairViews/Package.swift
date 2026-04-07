// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DirectorsChairViews",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DirectorsChairViews",
            targets: ["DirectorsChairViews"]),
    ],
    dependencies: [
        .package(path: "../DirectorsChairCore"),
        .package(path: "../DirectorsChairServices"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.17.6"),
    ],
    targets: [
        .target(
            name: "DirectorsChairViews",
            dependencies: ["DirectorsChairCore", "DirectorsChairServices"]),
        .testTarget(
            name: "DirectorsChairViewsTests",
            dependencies: [
                "DirectorsChairViews",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]),
    ]
)