//
//  VImageUtils.swift
//  Waifu2x
//
//  Created by vuhe on 2024/12/31.
//

import Accelerate
import CoreML

extension [Float] {
    /// 使用 vImage 将 RGB 格式转换为 MLMultiArray 所需的平面格式
    func convertToML(x: Int, y: Int, blockSize: Int, expwidth: Int, expheight: Int) async throws -> MLMultiArray {
        let channelSize = blockSize * blockSize

        // 创建 MLMultiArray
        let shape: [NSNumber] = [3, NSNumber(value: blockSize), NSNumber(value: blockSize)]
        let array = try Result { try MLMultiArray(shape: shape, dataType: .float32) }
            .mapError { Waifu2xError.coreMLError($0.localizedDescription) }
            .get()
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
                        withUnsafeBufferPointer { buffer in
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
}

extension [UInt8] {
    /// 使用 vImage 处理 alpha 通道缩放
    func scaleAlpha(width: Int, height: Int, scale: Int) -> [UInt8] {
        let newWidth = width * scale
        let newHeight = height * scale

        do {
            return try withUnsafeBufferPointer { buffer in
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
        } catch {
            // 如果 vImage 处理失败,回退到原来的 CPU 缩放方法
            #if DEBUG_MODE
                print("use vImage scale fail, back to bicubic")
            #endif
            let bicubic = Bicubic(image: self, channels: 1, width: width, height: height)
            return bicubic.resize(scale: Float(scale))
        }
    }
}

extension UnsafeMutablePointer<Double> {
    /// 使用 vImage 处理模型输出
    func covertToUInt8(bufferSize: Int) -> UnsafeMutablePointer<UInt8> {
        // 创建临时缓冲区用于存储归一化后的数据
        let tempBuffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer { tempBuffer.deallocate() }

        // 使用 vDSP 进行批量归一化操作
        vDSP_vdpsp(self, 1, tempBuffer, 1, vDSP_Length(bufferSize))
        var scale: Float = 255.0
        vDSP_vsmul(tempBuffer, 1, &scale, tempBuffer, 1, vDSP_Length(bufferSize))

        // 使用 vDSP 进行范围裁剪
        var minValue: Float = 0.0
        var maxValue: Float = 255.0
        vDSP_vclip(tempBuffer, 1, &minValue, &maxValue, tempBuffer, 1, vDSP_Length(bufferSize))

        // 创建一个临时的 UInt8 缓冲区
        let uint8Buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        // 批量转换为 UInt8
        vDSP_vfix8(tempBuffer, 1, uint8Buffer, 1, vDSP_Length(bufferSize))

        return uint8Buffer
    }
}
