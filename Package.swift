// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Waifu2x",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "Waifu2x", targets: ["Waifu2x"]),
    ],
    targets: [
        .target(name: "Waifu2x"),
        .testTarget(
            name: "Waifu2xTests",
            dependencies: ["Waifu2x"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
