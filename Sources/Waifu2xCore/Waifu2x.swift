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

import CoreGraphics

public struct Waifu2x: Sendable {
    private let model: Waifu2xModelInfo
    private let batchSize: Int

    public init(_ model: Waifu2xModelInfo, batchSize: Int = 10) {
        self.model = model
        self.batchSize = batchSize
    }

    public func run(_ image: CGImage) async throws -> Waifu2xData {
        let width = image.width
        let height = image.height
        let outScale = model.outScale
        let channels = 4 // Higher versions only allow the creation of 4 channels
        let imageMerger = ImageMerger(width: width, height: height, model: model, channels: channels)

        // Alpha channel support
        let alphaTask = Task {
            guard var alpha = try image.alpha() else { return false }
            #if DEBUG_MODE
                print("image really with alpha")
            #endif
            if outScale > 1 {
                alpha = try alpha.scaleAlpha(width: width, height: height, scale: outScale)
            }
            await imageMerger.mergeAlpha(alpha: alpha)
            return true
        }

        // If image is too small, that will expand it
        let preExpandImage = try image.preExpand(model.blockSize)
        let pipeline = try PipelineTask(
            input: InputTask(ExpandedImage(preExpandImage, model), inputName: model.mainInputName),
            model: ModelTask(model),
            output: imageMerger, outputName: model.mainOutputName
        )

        try await withThrowingTaskGroup(of: Void.self) { it in
            let rects = preExpandImage.getCropRects(model.blockSize)
            for i in stride(from: 0, to: rects.count, by: batchSize) {
                let end = min(i + batchSize, rects.count)
                it.addTask { try await pipeline.run(rects: Array(rects[i ..< end])) }
            }
            try await it.waitForAll()
        }
        let hasAlpha = try await alphaTask.value

        let outWidth = width * outScale
        let outHeight = height * outScale
        let cfbuffer = try await imageMerger.freezeImage()
        guard let dataProvider = CGDataProvider(data: cfbuffer)
        else { throw Waifu2xError.createImageFailed("new CGDataProvider, but return nil") }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        if hasAlpha {
            bitmapInfo |= CGImageAlphaInfo.last.rawValue
        } else {
            bitmapInfo |= CGImageAlphaInfo.noneSkipLast.rawValue
        }
        guard let cgImage = CGImage(
            width: outWidth, height: outHeight, bitsPerComponent: 8, bitsPerPixel: 8 * channels,
            bytesPerRow: outWidth * channels, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: dataProvider, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent
        ) else { throw Waifu2xError.createImageFailed("CGImage return nil") }
        return Waifu2xData(cgImage: cgImage, cgSize: CGSize(width: outWidth, height: outHeight))
    }
}
