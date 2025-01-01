//
//  Waifu2x.swift
//  waifu2x-mac
//
//  Created by xieyi on 2018/1/24.
//  Modify by vuhe on 2024/12/25.
//  Copyright © 2018年 xieyi. All rights reserved.
//

import CoreML

public struct Waifu2x {
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

    private let mlmodel: MLModel

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
        mlmodel = model.getMLModel()
        self.batchSize = batchSize
    }

    public func run(_ cgimg: CGImage) async throws -> Waifu2xData {
        let width = cgimg.width
        let height = cgimg.height
        var fullWidth = width
        var fullHeight = height
        var fullCG = cgimg

        // If image is too small, expand it
        if width < block_size || height < block_size {
            if width < block_size {
                fullWidth = block_size
            }
            if height < block_size {
                fullHeight = block_size
            }
            var bitmapInfo = cgimg.bitmapInfo.rawValue
            if bitmapInfo & CGBitmapInfo.alphaInfoMask.rawValue == CGImageAlphaInfo.first.rawValue {
                bitmapInfo = bitmapInfo & ~CGBitmapInfo.alphaInfoMask.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            } else if bitmapInfo & CGBitmapInfo.alphaInfoMask.rawValue == CGImageAlphaInfo.last.rawValue {
                bitmapInfo = bitmapInfo & ~CGBitmapInfo.alphaInfoMask.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            }
            let context = CGContext(
                data: nil, width: fullWidth, height: fullHeight,
                bitsPerComponent: cgimg.bitsPerComponent, bytesPerRow: cgimg.bytesPerRow / width * fullWidth,
                space: cgimg.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
            )
            let y = max(fullHeight - height, 0)
            context?.draw(cgimg, in: CGRect(x: 0, y: y, width: width, height: height))
            guard let contextCG = context?.makeImage()
            else { throw Waifu2xError.expandImageFailed }
            fullCG = contextCG
        }

        var hasalpha = cgimg.alphaInfo != CGImageAlphaInfo.none
        let channels = 4
        var alpha: [UInt8]!
        if hasalpha {
            alpha = cgimg.alpha()
            hasalpha = alpha?.contains(where: { $0 < 255 }) ?? false
        }
        #if DEBUG_MODE
            print("really with alpha: \(hasalpha)")
        #endif

        let out_width = width * out_scale
        let out_height = height * out_scale
        let out_fullWidth = fullWidth * out_scale
        let out_fullHeight = fullHeight * out_scale
        let out_block_size = block_size * out_scale
        let rects = fullCG.getCropRects(block_size)
        let bufferSize = out_block_size * out_block_size * 3
        let imgData = UnsafeMutablePointer<UInt8>.allocate(capacity: out_width * out_height * channels)
        defer { imgData.deallocate() }

        // Alpha channel support
        var alpha_task: (() async -> Void)?
        if hasalpha {
            alpha_task = {
                if self.out_scale > 1 {
                    alpha = alpha.scaleAlpha(width: width, height: height, scale: self.out_scale)
                }
                for y in 0 ..< out_height {
                    for x in 0 ..< out_width {
                        imgData[(y * out_width + x) * channels + 3] = alpha[y * out_width + x]
                    }
                }
            }
        }

        let expwidth = fullWidth + 2 * shrink_size
        let expheight = fullHeight + 2 * shrink_size
        let expanded = await fullCG.expand(shrink_size: shrink_size, clip_eta8: clip_eta8)
        let pipeline = PipelineTask(
            input: { rect in try await expanded.convertToML(
                x: Int(rect.origin.x), y: Int(rect.origin.y),
                blockSize: self.block_size + 2 * self.shrink_size,
                expwidth: expwidth, expheight: expheight
            ) },
            model: mlmodel,
            output: { index, array in
                let rect = rects[index]
                let origin_x = Int(rect.origin.x) * self.out_scale
                let origin_y = Int(rect.origin.y) * self.out_scale

                // 计算有效的复制区域
                let validHeight = min(out_block_size, out_fullHeight - origin_y)
                let validWidth = min(out_block_size, out_fullWidth - origin_x)
                guard validWidth > 0, validHeight > 0 else { return }

                // 获取源数据指针
                let dataPointer = array.dataPointer.assumingMemoryBound(to: Double.self)
                let uint8Buffer = dataPointer.covertToUInt8(bufferSize: bufferSize)
                defer { uint8Buffer.deallocate() }

                // 为每个通道批量处理数据
                for channel in 0 ..< 3 {
                    let channelOffset = channel * out_block_size * out_block_size
                    let channelData = uint8Buffer.advanced(by: channelOffset)

                    // 进行整行复制
                    for row in 0 ..< validHeight {
                        let srcRow = channelData.advanced(by: row * out_block_size)
                        let destRow = imgData.advanced(by: ((origin_y + row) * out_width + origin_x) * channels + channel)

                        // 使用 stride 来处理通道间隔
                        for i in 0 ..< validWidth {
                            destRow.advanced(by: i * channels).pointee = srcRow.advanced(by: i).pointee
                        }
                    }
                }
            }
        )

        try await withThrowingTaskGroup(of: Void.self) { it in
            it.addTask { await alpha_task?() }
            var idx = 0
            while idx < rects.count {
                let startIdx = idx
                let subRects = rects[idx ..< min(idx + batchSize, rects.count)]
                it.addTask { try await pipeline.run(idx: startIdx, rects: subRects) }
                idx += batchSize
            }
            try await it.waitForAll()
        }

        let cfbuffer = CFDataCreate(nil, imgData, out_width * out_height * channels)!
        let dataProvider = CGDataProvider(data: cfbuffer)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        if hasalpha {
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
