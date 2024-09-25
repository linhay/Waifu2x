# Waifu2x

> 此库仅支持 macOS(AppKit) 平台，
> 如果需要 iOS(UIKit) 平台库，请参见原作者的 [waifu2x-ios](https://github.com/imxieyi/waifu2x-ios)；
> 如果只是想使用 app，请参见原作者发布的全平台应用 [waifu2x](https://apps.apple.com/us/app/waifu2x/id1286485858)

使用 Core ML 和 Metal 将 Waifu2x 移植到 macOS，并作为库发布。

项目大部分代码基于 [waifu2x-mac](https://github.com/imxieyi/waifu2x-mac)，
删除了和 UI 相关的部分并添加 `Package.swift` 用于库引用。

## 项目差异

原项目的部分代码不适合作为库使用，因此做了以下调整：

- 删除所有全局变量，使用超分需要创建 Waifu2x 实例
- Waifu2x 实例方法更改为并发方法，以支持并发调用
- 如果需要在 GCD 环境中使用，可以用 DispatchGroup 达到原先的效果，参见 `Tests/Waifu2xTests/Waifu2xTests.swift` 中的 `testGCD` 示例

## 开源许可

原项目使用 MIT 协议开源，查看[原项目许可](https://github.com/imxieyi/waifu2x-mac/blob/master/README.md)了解全部信息

此库使用 LGPL 协议开源，查看 `LICENSE` 文件了解全部信息，并在合理范围内使用
