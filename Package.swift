// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Waifu2x",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "Waifu2x", targets: ["Waifu2xCore", "Waifu2xModels"]),
        .library(name: "Waifu2xCore", targets: ["Waifu2xCore"]),
        .library(name: "WifmModels", targets: ["WifmModels"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0")),
    ],
    targets: [
        .target(
            name: "Waifu2xCore"
        ),
        .target(
            name: "Waifu2xModels",
            dependencies: ["Waifu2xCore"],
            sources: ["Models.swift"],
            resources: [.process("srcnn")]
        ),
        .target(
            name: "WifmModels",
            dependencies: ["Waifu2xCore", "ZIPFoundation"]
        ),
        .testTarget(
            name: "Waifu2xTests",
            dependencies: ["Waifu2xCore", "Waifu2xModels", "WifmModels"],
            resources: [.copy("white.png")]
        ),
    ]
)
