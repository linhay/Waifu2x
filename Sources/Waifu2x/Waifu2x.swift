//
//  Waifu2x.swift
//  Waifu2x
//
//  Created by xieyi on 2018/1/24.
//  Copyright © 2018 xieyi. All rights reserved.
//
//  Modify by vuhe on 2024/12/25.
//  Copyright © 2024 vuhe. All rights reserved.
//

import CoreML

public struct Waifu2x: Sendable {
    /// The output block size.
    /// It is dependent on the model.
    /// Do not modify it until you are sure your model has a different number.
    private let block_size: Int

    private let out_scale: Int

    /// The difference between output and input block size
    private let shrink_size = 7

    /// Do not exactly know its function
    /// However it can on average improve PSNR by 0.09
    /// https://github.com/nagadomi/waifu2x/commit/797b45ae23665a1c5e3c481c018e48e6f0d0e383
    private let clip_eta8 = Float(0.00196)

    private let model: Waifu2xModel

    private let batchSize: Int

    public init(model: Waifu2xModel, batchSize: Int = 10) {
        switch model {
        case .anime_noise0, .anime_noise1, .anime_noise2, .anime_noise3, .photo_noise0, .photo_noise1, .photo_noise2, .photo_noise3:
            block_size = 128
            out_scale = 1
        default:
            block_size = 142
            out_scale = 2
        }
        self.model = model
        self.batchSize = batchSize
    }

    public func run(_ image: CGImage) async throws -> Waifu2xData {
        let width = image.width
        let height = image.height
        let channels = 4 // Higher versions only allow the creation of 4 channels
        let outputTask = OutputTask(
            width: width, height: height, block_size: block_size, out_scale: out_scale, channels: channels
        )

        // Alpha channel support
        let alpha = image.alpha()
        #if DEBUG_MODE
            print("really with alpha: \(alpha != nil)")
        #endif
        let alpha_task: (() async throws -> Void)? = if let alphaArray = alpha { {
            var alphaChannel = alphaArray
            if out_scale > 1 {
                alphaChannel = try alphaArray.scaleAlpha(width: width, height: height, scale: out_scale)
            }
            await outputTask.mergeAlpha(alpha: alphaChannel)
        } } else { nil }

        // If image is too small, that will expand it
        let preExpandImage = try image.preExpand(block_size: block_size)
        let pipeline = PipelineTask(
            input: InputTask(
                expanded: preExpandImage.expand(shrink_size: shrink_size, clip_eta8: clip_eta8),
                blockSize: block_size + 2 * shrink_size,
                expwidth: preExpandImage.width + 2 * shrink_size,
                expheight: preExpandImage.height + 2 * shrink_size
            ),
            model: ModelTask(model),
            output: outputTask
        )

        try await withThrowingTaskGroup(of: Void.self) { it in
            it.addTask { try await alpha_task?() }

            let rects = preExpandImage.getCropRects(block_size)
            for i in stride(from: 0, to: rects.count, by: batchSize) {
                let end = min(i + batchSize, rects.count)
                it.addTask { try await pipeline.run(rects: Array(rects[i ..< end])) }
            }
            try await it.waitForAll()
        }

        let out_width = width * out_scale
        let out_height = height * out_scale
        let cfbuffer = await outputTask.freezeImage()
        let dataProvider = CGDataProvider(data: cfbuffer)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        if alpha != nil {
            bitmapInfo |= CGImageAlphaInfo.last.rawValue
        } else {
            bitmapInfo |= CGImageAlphaInfo.noneSkipLast.rawValue
        }
        let cgImage = CGImage(
            width: out_width, height: out_height, bitsPerComponent: 8, bitsPerPixel: 8 * channels,
            bytesPerRow: out_width * channels, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: dataProvider, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent
        )
        return Waifu2xData(cgImage: cgImage!, cgSize: CGSize(width: out_width, height: out_height))
    }
}
