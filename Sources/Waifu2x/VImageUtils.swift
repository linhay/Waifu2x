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
    static func convertToMLMultiArray(
        expanded: [Float], x: Int, y: Int,
        blockSize: Int, expwidth: Int, expheight: Int
    ) async throws -> MLMultiArray {
        let channelSize = blockSize * blockSize

        // 创建 MLMultiArray
        let shape: [NSNumber] = [3, NSNumber(value: blockSize), NSNumber(value: blockSize)]
        let array = try MLMultiArray(shape: shape, dataType: .float32)
        let arrayPtr = array.dataPointer.assumingMemoryBound(to: Float.self)

        await withTaskGroup(of: Void.self) { group in
            // 为每个通道处理数据
            for channel in 0 ..< 3 {
                group.addTask {
                    let channelOffset = channel * expwidth * expheight
                    let destBaseOffset = channel * channelSize

                    // 处理每一行的数据
                    for row in 0 ..< blockSize {
                        let srcOffset = channelOffset + (y + row) * expwidth + x
                        let destOffset = destBaseOffset + row * blockSize

                        // 使用 vDSP 进行优化的内存复制
                        expanded.withUnsafeBufferPointer { buffer in
                            let src = UnsafePointer(buffer.baseAddress!.advanced(by: srcOffset))
                            let dest = UnsafeMutablePointer(arrayPtr.advanced(by: destOffset))

                            // 复制当前行的数据
                            vDSP_mmov(src, dest, vDSP_Length(blockSize), 1, 1, 1)
                        }
                    }
                }
            }
        }

        return array
    }

    /// 使用 vImage 处理 alpha 通道缩放
    static func scaleAlphaChannel(alpha: [UInt8], width: Int, height: Int, scale: Int) throws -> [UInt8] {
        let newWidth = width * scale
        let newHeight = height * scale

        return try alpha.withUnsafeBufferPointer { buffer in
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
            guard error == kvImageNoError else { throw Waifu2xError.vImageScalingFailed }

            return Array(UnsafeBufferPointer(start: destBuffer, count: newWidth * newHeight))
        }
    }
}
