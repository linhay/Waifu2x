//
//  VImageUtils.swift
//  Waifu2x
//
//  Created by vuhe on 2024/12/31.
//

import Accelerate
import CoreGraphics
import CoreML

enum VImageUtils {
    /// 使用 vImage 将 RGB 格式转换为 MLMultiArray 所需的平面格式
    static func convertToMLMultiArray(rgbBuffer: [Float], width: Int, height: Int) throws -> MLMultiArray {
        let channelSize = width * height

        // 创建 MLMultiArray
        let shape: [NSNumber] = [3, NSNumber(value: height), NSNumber(value: width)]
        let array = try MLMultiArray(shape: shape, dataType: .float32)
        let arrayPtr = array.dataPointer.assumingMemoryBound(to: Float.self)

        // 直接复制数据到 MLMultiArray
        rgbBuffer.withUnsafeBufferPointer { buffer in
            // 分别复制 R、G、B 通道数据
            for channel in 0 ..< 3 {
                let sourceOffset = channel * channelSize
                let destOffset = channel * channelSize

                memcpy(
                    arrayPtr.advanced(by: destOffset),
                    buffer.baseAddress?.advanced(by: sourceOffset),
                    channelSize * MemoryLayout<Float>.size
                )
            }
        }

        return array
    }

    /// 使用 vImage 处理 alpha 通道缩放
    static func scaleAlphaChannel(alpha: [UInt8], width: Int, height: Int, scale: Int) throws -> [UInt8] {
        let newWidth = width * scale
        let newHeight = height * scale

        return alpha.withUnsafeBufferPointer { buffer in
            // 创建源缓冲区
            var sourceBuffer = vImage_Buffer(
                data: UnsafeMutableRawPointer(mutating: buffer.baseAddress!),
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: width
            )

            // 创建目标缓冲区
            let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: newWidth * newHeight)
            defer { destBuffer.deallocate() }

            var destBufferInfo = vImage_Buffer(
                data: destBuffer,
                height: vImagePixelCount(newHeight),
                width: vImagePixelCount(newWidth),
                rowBytes: newWidth
            )

            // 执行缩放
            let error = vImageScale_Planar8(&sourceBuffer, &destBufferInfo, nil, vImage_Flags(kvImageHighQualityResampling))

            guard error == kvImageNoError else {
                return alpha // 如果缩放失败，返回原始数据
            }

            return Array(UnsafeBufferPointer(start: destBuffer, count: newWidth * newHeight))
        }
    }
}
