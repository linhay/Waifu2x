# Waifu2x

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS-lightgrey.svg)](https://github.com/vuhe/Waifu2x)
[![](https://img.shields.io/github/license/vuhe/Waifu2x.svg)](https://github.com/vuhe/Waifu2x/blob/main/LICENSE)

> 此库仅支持原项目开源的 SRCNN 模型进行图片处理，不会支持其他模型和功能；
> 如果只是想使用 app 或其他模型，请参见原作者发布的全平台应用 [waifu2x](https://apps.apple.com/us/app/waifu2x/id1286485858)

使用 Core ML 将 Waifu2x 移植到 apple 平台，并作为库发布。

项目大部分代码基于 [waifu2x-mac](https://github.com/imxieyi/waifu2x-mac)，
删除了和 UI 相关的部分并添加 `Package.swift` 用于库引用。

**使用前请先测试，作者不会对软件崩溃和设备损坏负责**

## 系统要求

> 仅在 macOS 15 上构建通过，其他平台未测试

- macOS 12+
- iOS 15+
- tvOS 15+
- watchOS 8+
- visionOS 1+

**构建需要 Xcode 15+**

## 输入输出

输入为 `CGImage`，可以使用图片数据的 `Data` 作为输入。这可以支持 Swift 6 的 `Sendable`。

输入 RGB 图像可以正常工作。其他图像应在处理之前转换为 RGB，否则输出破损图像。

使用 `vImage` 缩放 Alpha 通道。它通过使用 CPU 的矢量处理器来优化图像处理，如果没有矢量处理器，vImage 会使用下一个最佳可用选项。

输出数据为 `Waifu2xData`，含有 `CGImage` 和 `CGSize`，并添加了扩展可以转换为 `NSImage` 或 `UIImage`，
也可以直接导出格式为 `jpeg` 或 `png` 的 `Data` 数据

如果处理中发生错误，会抛出异常 `Waifu2xError`

## 项目差异

原项目的部分代码不适合作为库使用，并根据原作者的建议提升了性能：

- 改用更底层的 `CGImage` 作为输入输出，移除平台相关的特定代码
- 使用 `vImage` 和 `vDSP` 转换数据格式，移除 Metal 部分
- 使用 `MLBatch` 加速推理
- 删除所有全局变量，使用超分需要创建 Waifu2x 实例
- Waifu2x 实例方法更改为并发方法，以支持并发调用
- 如果需要在 GCD 环境中使用，可以用 DispatchGroup 达到原先的效果，参见 `Tests/Waifu2xTests/Waifu2xTests.swift` 中的 `testGCD` 示例

## 开源许可

原项目使用 MIT 协议开源，查看[原项目许可](https://github.com/imxieyi/waifu2x-mac/blob/master/README.md)了解全部信息

此库使用 BSD 3-Clause 协议开源，查看 `LICENSE` 文件了解全部信息，并在合理范围内使用

目前为止，`vImage` 的改进可能存在优化空间，使用可能存在问题，欢迎各类 PR
