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
    mutating func expandChannel(width: Int, height: Int, shrink_size: Int, clipEta8: Float) -> [Float] {
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
                var clip = clipEta8
                vDSP_vsadd(tempPtr.baseAddress!, 1, &clip, tempPtr.baseAddress!, 1, vDSP_Length(width * height))
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
    let r, g, b: [Float]
    let blockSize, expWidth: Int // for input

    /// Expand the original image by shrink_size and store rgb in float array.
    /// The model will shrink the input image by 7 px.
    init(image: CGImage, blockSize: Int, shrinkSize: Int, clipEta8: Float) throws {
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
        r = rChannel.expandChannel(width: width, height: height, shrink_size: shrinkSize, clipEta8: clipEta8)
        g = gChannel.expandChannel(width: width, height: height, shrink_size: shrinkSize, clipEta8: clipEta8)
        b = bChannel.expandChannel(width: width, height: height, shrink_size: shrinkSize, clipEta8: clipEta8)
        self.blockSize = blockSize + 2 * shrinkSize
        expWidth = width + 2 * shrinkSize
    }

    /// Use vImage to convert the RGB format to the planar format required by the waifu2x model
    func convertToML(rect: CGRect) throws -> MLMultiArray {
        let x = Int(rect.origin.x)
        let y = Int(rect.origin.y)
        let channelSize = blockSize * blockSize

        // Create MLMultiArray with shape [channels, height, width]
        let shape: [NSNumber] = [3, NSNumber(value: blockSize), NSNumber(value: blockSize)]
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
                        vDSP_Length(blockSize), // Number of elements to copy per row
                        vDSP_Length(blockSize), // Number of rows to copy
                        vDSP_Length(expWidth), // Source stride
                        vDSP_Length(blockSize) // Destination stride
                    )
                }
            }
        }

        return array
    }
}
