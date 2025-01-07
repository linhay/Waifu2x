# Waifu2x

[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS-lightgrey.svg)](https://github.com/vuhe/Waifu2x)
[![](https://img.shields.io/github/license/vuhe/Waifu2x.svg)](https://github.com/vuhe/Waifu2x/blob/main/LICENSE)

> 如果只是想使用 app，请参见原作者发布的全平台应用 [waifu2x](https://apps.apple.com/us/app/waifu2x/id1286485858)

使用 Core ML 将 Waifu2x 移植到 apple 平台，并作为库发布。

项目大部分代码基于 [waifu2x-mac](https://github.com/imxieyi/waifu2x-mac)，
删除了和 UI 相关的部分并添加 `Package.swift` 用于库引用。

**使用前请先测试，作者不会对软件崩溃和设备损坏负责**

## 系统要求

> 仅在 macOS 15 上构建通过，其他平台未测试

- macOS 13+
- iOS 16+
- tvOS 16+
- watchOS 9+
- visionOS 1+

**构建需要 Xcode 15+**

## 依赖库

此项包含 4 个可供使用的库，每个库含有的包不同：

- Waifu2x: 包含 Waifu2xCore 和 Waifu2xModels 模块，其中 Waifu2xCore 模块为处理代码，Waifu2xModels 模块为内嵌 srcnn 模型
- Waifu2xCore: 仅含有 Waifu2xCore 模块，如果不想使用预置模型可以仅引入此模块用于减少打包体积
- Anime4kModels: 包含 Anime4K 的预置模型
- WifmModels: 支持导入由[转换器](https://github.com/imxieyi/waifu2x-ios-model-converter)生成的模型

预置模型（Waifu2x、Anime4k）会在引入后随最终项目编译为可执行模型，由 WifmModels 导入的模型会在运行时执行编译

如果需要减少运行时编译，可以使用预置模型或将模型文件作为内嵌资源进入 xcode，在打包时会执行预编译

## 使用说明

### CoreML batch 大小

默认值为 10，即 `waifu2x.run(Data(...), batchSize: 10)`，如果有需要可以在运行时调整

通常只要确保 batch 推理的时间大于输入输出时间，就能保证效率最佳，大部分情况下不需要更改

### waifu2x srcnn 模型

要使用内置的 srcnn 模型，需要引入 Waifu2x 库

```swift
import Waifu2xCore // 引入模型处理器
import Waifu2xModels // 引入Waifu2x模型
let waifu2x = Waifu2x(srcnn: .anime_noise3_scale2x) // 创建处理器
let output = try await waifu2x.run(Data(contentsOf: url)) // 读取 data 数据
let jpegData: Data? = output.toJpeg() // 将生成的图片转为 jpeg
```

此模型使用枚举创建处理器，开销很小

### Anime4K 模型

如果使用内置 Anime4K 模型需要将引入的包更换为 Anime4kModels

```swift
...
//import Waifu2xModels
import Anime4kModels // 更换为 Anime4K 内置模型
let waifu2x = Waifu2x(anime4k: .perset2x_a_a_fast) // 创建处理器
...
```

此模型使用枚举创建处理器，开销很小

### 外部 Wifm 模型

如果想使用 Wifm 模型，需要将引入的包更换为 WifmModels，同时注意要处理异常

```swift
...
//import Waifu2xModels
import WifmModels
let wifmURL: URL = URL(...) // 需要提供 wifm 文件路径
let waifu2x = try await Waifu2x(wifm: wifmURL) // 直接从外置模型中加载，此方法会编译模型
...
```

**外部模型加载完模型后会保存在处理器中，重复加载会导致重复编译模型，可能会造成严重的性能开销**

### 自定义模型

如果想使用自定义模型，那么仅需要引入 Waifu2xCore 即可，但是需要实现 `Waifu2xModelInfo` 协议

```swift
...
//import Waifu2xModels
struct ExampleModel: Waifu2xModelInfo {...} // 实现协议
let waifu2x = Waifu2x(ExampleModel()) // 按配置生成处理器
...
```

对于 Waifu2xModelInfo 中参数的说明：

- name: 用于区别，但不会对处理产生影响
- inputShape: 模型输入的 shape，仅能处理 3 通道 RGB，应该为 nchw 或 chw，即 [1, 3, H, W] 或 [3, H, W]；其中 H（高度）和 W（宽度）必须相等
- shrinkSize: 在输入图像的所有4个边上收缩的大小（不稳定区域）
- outScale: 模型的输出放大倍数
- blockSize: 块大小，通常是 inputShape 的 (H - 2 × shrinkSize)
- shrinkAfterHandled: 如果模型输出不会收缩 shrinkSize 区域，需要设置为 true 来裁切
- mainModel: 处理 RGB 通道的 CoreML 模型
- mainInputName: 处理 RGB 模型输入的名称
- mainOutputName: 处理 RGB 模型输出的名称

*输入和输出统一使用 flaot32 平面格式 RGB，如果模型输入和输出有出入，需要调整模型以匹配*

**此模型会保存在处理器中，需要自行评估重复加载的性能开销**

## 输入输出

输入为 `CGImage`，可以使用图片数据的 `Data` 作为输入。这可以支持 Swift 6 的 `Sendable`。

如果输入使用 `NSImage` 或 `UIImage` 可以通过转换获得 `CGImage`：

```swift
// for NSImage
let image: NSImage = ...
guard let cgimg = image.representations[0].cgImage(forProposedRect: nil, context: nil, hints: nil) 
else { print("fail to get CGImage from NSImage") }
// for UIImage
let image: UIImage = ...
guard let cgimage = image.cgImage
else { print("fail to get CGImage from UIImage") }
```

使用 `vImage` 缩放 Alpha 通道。它通过使用 CPU 的矢量处理器来优化图像处理，此库限制的系统所在平台均有矢量处理器。

输出数据为 `Waifu2xData`，含有 `CGImage` 和 `CGSize`，并添加了扩展可以转换为 `NSImage` 或 `UIImage`，
也可以直接导出格式为 `jpeg` 或 `png` 的 `Data` 数据

如果处理中发生错误，会抛出异常 `Waifu2xError`

## 项目差异

原项目的部分代码不适合作为库使用，并根据原作者的建议提升了性能：

- 改用更底层的 `CGImage` 作为输入输出，移除平台相关的特定代码
- 使用 `vImage` 和 `vDSP` 转换数据格式，移除 Metal 部分
- 使用 `MLBatch` 加速推理
- 删除所有全局变量，使用超分需要创建 Waifu2x 实例
- Waifu2x 实例方法更改为并发方法，以支持输入、推理、输出的并发调度
- 如果需要在 GCD 环境中使用，可以用 DispatchGroup 达到原先的效果，参见 `Tests/Waifu2xTests/Waifu2xTests.swift` 中的 `testGCD` 示例

## 开源许可

原项目使用 MIT 协议开源，查看[原项目许可](https://github.com/imxieyi/waifu2x-mac/blob/master/README.md)了解全部信息

[waifu2x srcnn 模型](https://github.com/nagadomi/waifu2x)使用 MIT 协议开源

[Anime4K 模型](https://github.com/bloc97/Anime4K)使用 MIT 协议开源

此库代码使用 BSD 3-Clause 协议开源，查看 `LICENSE` 文件了解全部信息，并在合理范围内使用

目前为止，`vImage` 的改进可能存在优化空间，使用可能存在问题，欢迎各类 PR
