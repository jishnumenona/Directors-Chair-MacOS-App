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
        .package(path: "../DirectorsChairCore"),
        // On-device insights (DC-0055): MLX runs the bundled open-weights
        // model on Apple Silicon. The examples repo publishes the LLM
        // loading/generation libraries as products.
        .package(url: "https://github.com/ml-explore/mlx-swift-examples",
                 from: "2.21.0"),
    ],
    targets: [
        .target(
            name: "DirectorsChairServices",
            dependencies: [
                "DirectorsChairCore",
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
            ]
        ),
        .testTarget(
            name: "DirectorsChairServicesTests",
            dependencies: ["DirectorsChairServices"]
        ),
    ]
)
