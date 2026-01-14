// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DirectorsChairExports",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DirectorsChairExports",
            targets: ["DirectorsChairExports"]
        ),
    ],
    dependencies: [
        .package(path: "../DirectorsChairCore")
    ],
    targets: [
        .target(
            name: "DirectorsChairExports",
            dependencies: ["DirectorsChairCore"]
        ),
        .testTarget(
            name: "DirectorsChairExportsTests",
            dependencies: ["DirectorsChairExports"]
        ),
    ]
)
