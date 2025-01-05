// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Waifu2x",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "Waifu2x", targets: ["Waifu2x"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0")),
    ],
    targets: [
        .target(
            name: "Waifu2x",
            dependencies: ["ZIPFoundation"],
            resources: [.process("models")]
        ),
        .testTarget(
            name: "Waifu2xTests",
            dependencies: ["Waifu2x"],
            resources: [.copy("white.png")]
        ),
    ]
)
