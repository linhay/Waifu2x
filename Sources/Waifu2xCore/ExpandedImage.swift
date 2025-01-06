//
//  ExpandedImage.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/4.
//  Copyright © 2025 vuhe. All rights reserved.
//

import Accelerate
import CoreImage
import CoreML

private extension [Float] {
    mutating func expandChannel(width: Int, height: Int, shrink_size: Int) -> [Float] {
        let exwidth = width + 2 * shrink_size
        let exheight = height + 2 * shrink_size

        // 1. 创建扩展尺寸的结果数组
        var result = [Float](repeating: 0, count: exwidth * exheight)

        // 2. 填充边界
        // 2.1 填充上下边界（使用vDSP_mmov复制整行）
        let firstRow = self[..<width]
        let lastRow = self[(width * (height - 1))...]

        // 上边界：复制第一行
        for y in 0 ..< shrink_size {
            firstRow.withUnsafeBufferPointer { buffer in
                vDSP_mmov(buffer.baseAddress!, &result[y * exwidth + shrink_size], vDSP_Length(width), 1, 1, 1)
            }
        }

        // 下边界：复制最后一行
        for y in (height + shrink_size) ..< exheight {
            lastRow.withUnsafeBufferPointer { buffer in
                vDSP_mmov(buffer.baseAddress!, &result[y * exwidth + shrink_size], vDSP_Length(width), 1, 1, 1)
            }
        }

        // 2.2 填充左右边界
        for y in 0 ..< height {
            let left = self[y * width]
            let right = self[y * width + width - 1]
            let destY = y + shrink_size

            // 左边界
            vDSP_vfill([left], &result[destY * exwidth], 1, vDSP_Length(shrink_size))

            // 右边界
            vDSP_vfill([right], &result[destY * exwidth + width + shrink_size], 1, vDSP_Length(shrink_size))
        }

        // 2.3 填充四个角
        let topLeft = self[0]
        let topRight = self[width - 1]
        let bottomLeft = self[(height - 1) * width]
        let bottomRight = self[width * height - 1]

        // 左上角
        for y in 0 ..< shrink_size {
            vDSP_vfill([topLeft], &result[y * exwidth], 1, vDSP_Length(shrink_size))
        }

        // 右上角
        for y in 0 ..< shrink_size {
            vDSP_vfill([topRight], &result[y * exwidth + width + shrink_size], 1, vDSP_Length(shrink_size))
        }

        // 左下角
        for y in (height + shrink_size) ..< exheight {
            vDSP_vfill([bottomLeft], &result[y * exwidth], 1, vDSP_Length(shrink_size))
        }

        // 右下角
        for y in (height + shrink_size) ..< exheight {
            vDSP_vfill([bottomRight], &result[y * exwidth + width + shrink_size], 1, vDSP_Length(shrink_size))
        }

        // 3. 复制原图数据到中心位置并添加增益
        withUnsafeMutableBufferPointer { tempPtr in
            result.withUnsafeMutableBufferPointer { resultPtr in
                // Do not exactly know its function
                // However it can on average improve PSNR by 0.09
                // https://github.com/nagadomi/waifu2x/commit/797b45ae23665a1c5e3c481c018e48e6f0d0e383
                var clipEta8 = Float(0.00196)
                vDSP_vsadd(tempPtr.baseAddress!, 1, &clipEta8, tempPtr.baseAddress!, 1, vDSP_Length(width * height))

                vDSP_mmov(
                    tempPtr.baseAddress!,
                    resultPtr.baseAddress!.advanced(by: shrink_size * exwidth + shrink_size),
                    vDSP_Length(width),
                    vDSP_Length(height),
                    vDSP_Length(width),
                    vDSP_Length(exwidth)
                )
            }
        }

        return result
    }
}

struct ExpandedImage: Sendable {
    private let r, g, b: [Float]
    private let inputBlockSize, expWidth: Int // for input
    private let shape: [NSNumber]
    private let dataType: Waifu2xModelDataType

    /// Expand the original image by shrink_size and store rgb in float array.
    /// The model will shrink the input image by 7 px.
    init(_ image: CGImage, _ model: Waifu2xModelInfo) throws {
        let width = image.width
        let height = image.height
        let rect = CGRect(origin: .zero, size: CGSize(width: width, height: height))

        // Redraw image in 32-bit RGBA
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 4 * width,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
            )
            context?.draw(image, in: rect)
        }

        // 创建浮点通道数组
        var rChannel = [Float](repeating: 0, count: width * height)
        var gChannel = [Float](repeating: 0, count: width * height)
        var bChannel = [Float](repeating: 0, count: width * height)
        var aChannel = [Float](repeating: 0, count: width * height)

        try withUnsafeMutableBufferPointer(&data, &rChannel, &gChannel, &bChannel, &aChannel) { src, r, g, b, a in
            let vImageHeight = vImagePixelCount(height)
            let vImageWidth = vImagePixelCount(width)
            let destRowBytes = width * MemoryLayout<Float>.stride

            // 设置 vImage buffer
            var sourceBuffer = vImage_Buffer(data: src.baseAddress, height: vImageHeight, width: vImageWidth, rowBytes: width * 4)
            var rBuffer = vImage_Buffer(data: r.baseAddress, height: vImageHeight, width: vImageWidth, rowBytes: destRowBytes)
            var gBuffer = vImage_Buffer(data: g.baseAddress, height: vImageHeight, width: vImageWidth, rowBytes: destRowBytes)
            var bBuffer = vImage_Buffer(data: b.baseAddress, height: vImageHeight, width: vImageWidth, rowBytes: destRowBytes)
            var aBuffer = vImage_Buffer(data: a.baseAddress, height: vImageHeight, width: vImageWidth, rowBytes: destRowBytes)

            // 设置转换范围
            var maxFloat: [Float] = [1.0, 1.0, 1.0, 1.0] // ARGB 每个通道的最大值
            var minFloat: [Float] = [0.0, 0.0, 0.0, 0.0] // ARGB 每个通道的最小值

            // 转换为浮点数格式
            let error = vImageConvert_ARGB8888toPlanarF(
                &sourceBuffer, &rBuffer, &gBuffer, &bBuffer, &aBuffer,
                &maxFloat, &minFloat, vImage_Flags(kvImageNoFlags)
            )
            guard error == kvImageNoError else { throw Waifu2xError.expandImageFailed }
        }

        // 处理每个通道
        r = rChannel.expandChannel(width: width, height: height, shrink_size: model.shrinkSize)
        g = gChannel.expandChannel(width: width, height: height, shrink_size: model.shrinkSize)
        b = bChannel.expandChannel(width: width, height: height, shrink_size: model.shrinkSize)
        inputBlockSize = model.blockSize + 2 * model.shrinkSize
        expWidth = width + 2 * model.shrinkSize
        shape = model.inputShape.map { NSNumber(value: $0) }
        dataType = model.inputDataType
    }

    func convertToML(rect: CGRect) throws -> MLMultiArray {
        switch dataType {
        case .planar: try convertToPlanarML(rect)
        case .interleaved: try convertToInterleavedML(rect)
        }
    }

    /// Use vDSP to copy the RGB channel to the planar format required by the waifu2x model
    private func convertToPlanarML(_ rect: CGRect) throws -> MLMultiArray {
        let x = Int(rect.origin.x)
        let y = Int(rect.origin.y)
        let channelSize = inputBlockSize * inputBlockSize

        // Create MLMultiArray with shape [channels, height, width]
        let array = try Result { try MLMultiArray(shape: shape, dataType: .float32) }
            .mapError { Waifu2xError.coreMLError($0.localizedDescription) }
            .get()

        // Get data for all three channels
        let channels = [r, g, b]

        // Process each RGB channel concurrently
        for channel in 0 ..< 3 {
            array.withUnsafeMutableBufferPointer(ofType: Float.self) { arrayPtr, _ in
                channels[channel].withUnsafeBufferPointer { channelPtr in
                    let srcOffset = y * expWidth + x
                    let destOffset = channel * channelSize

                    vDSP_mmov(
                        channelPtr.baseAddress!.advanced(by: srcOffset),
                        arrayPtr.baseAddress!.advanced(by: destOffset),
                        vDSP_Length(inputBlockSize), // Number of elements to copy per row
                        vDSP_Length(inputBlockSize), // Number of rows to copy
                        vDSP_Length(expWidth), // Source stride
                        vDSP_Length(inputBlockSize) // Destination stride
                    )
                }
            }
        }

        return array
    }

    /// Use vImage to convert the RGB format to the interleaved format required by the custom model
    private func convertToInterleavedML(_ rect: CGRect) throws -> MLMultiArray {
        let x = Int(rect.origin.x)
        let y = Int(rect.origin.y)
        let channelSize = inputBlockSize * inputBlockSize

        // Create MLMultiArray with shape [channels, height, width]
        let array = try Result { try MLMultiArray(shape: shape, dataType: .float32) }
            .mapError { Waifu2xError.coreMLError($0.localizedDescription) }
            .get()

        // Create block buffer
        var rBuffer = [Float](repeating: 0, count: channelSize)
        var gBuffer = [Float](repeating: 0, count: channelSize)
        var bBuffer = [Float](repeating: 0, count: channelSize)

        // Process each RGB channel concurrently
        let srcOffset = y * expWidth + x
        rBuffer.withUnsafeMutableBufferPointer { arrayPtr in
            r.withUnsafeBufferPointer { channelPtr in
                vDSP_mmov(
                    channelPtr.baseAddress!.advanced(by: srcOffset),
                    arrayPtr.baseAddress!,
                    vDSP_Length(inputBlockSize), // Number of elements to copy per row
                    vDSP_Length(inputBlockSize), // Number of rows to copy
                    vDSP_Length(expWidth), // Source stride
                    vDSP_Length(inputBlockSize) // Destination stride
                )
            }
        }
        gBuffer.withUnsafeMutableBufferPointer { arrayPtr in
            g.withUnsafeBufferPointer { channelPtr in
                vDSP_mmov(
                    channelPtr.baseAddress!.advanced(by: srcOffset),
                    arrayPtr.baseAddress!,
                    vDSP_Length(inputBlockSize), // Number of elements to copy per row
                    vDSP_Length(inputBlockSize), // Number of rows to copy
                    vDSP_Length(expWidth), // Source stride
                    vDSP_Length(inputBlockSize) // Destination stride
                )
            }
        }
        bBuffer.withUnsafeMutableBufferPointer { arrayPtr in
            b.withUnsafeBufferPointer { channelPtr in
                vDSP_mmov(
                    channelPtr.baseAddress!.advanced(by: srcOffset),
                    arrayPtr.baseAddress!,
                    vDSP_Length(inputBlockSize), // Number of elements to copy per row
                    vDSP_Length(inputBlockSize), // Number of rows to copy
                    vDSP_Length(expWidth), // Source stride
                    vDSP_Length(inputBlockSize) // Destination stride
                )
            }
        }
        print("\(rBuffer[0]),\(gBuffer[0]),\(bBuffer[0])")

        // convert planar to RGB
        try array.withUnsafeMutableBufferPointer(ofType: Float.self) { dest, _ in
            try withUnsafeMutableBufferPointer(&rBuffer, &gBuffer, &bBuffer) { r, g, b in
                let vBlockSize = vImagePixelCount(inputBlockSize)
                let blockRowBytes = inputBlockSize * MemoryLayout<Float>.stride

                // 设置 vImage buffer
                var rBuffer = vImage_Buffer(data: r.baseAddress, height: vBlockSize, width: vBlockSize, rowBytes: blockRowBytes)
                var gBuffer = vImage_Buffer(data: g.baseAddress, height: vBlockSize, width: vBlockSize, rowBytes: blockRowBytes)
                var bBuffer = vImage_Buffer(data: b.baseAddress, height: vBlockSize, width: vBlockSize, rowBytes: blockRowBytes)
                var destBuffer = vImage_Buffer(data: dest.baseAddress, height: vBlockSize, width: vBlockSize, rowBytes: blockRowBytes * 3)

                // 交错为 RGB 格式
                let error = vImageConvert_PlanarFtoRGBFFF(&rBuffer, &gBuffer, &bBuffer, &destBuffer, vImage_Flags(kvImageNoFlags))
                guard error == kvImageNoError else { throw Waifu2xError.expandImageFailed }
            }
        }

        return array
    }
}
