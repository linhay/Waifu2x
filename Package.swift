// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Waifu2x",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Waifu2x", targets: ["Waifu2x"]),
    ],
    targets: [
        .target(
            name: "Waifu2x",
            resources: [.process("models")]
        ),
        .testTarget(
            name: "Waifu2xTests",
            dependencies: ["Waifu2x"],
            resources: [.copy("white.png")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
