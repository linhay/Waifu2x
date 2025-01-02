//
//  AccelerateUtils.swift
//  Waifu2x
//
//  Created by vuhe on 2024/12/31.
//  Copyright © 2024 vuhe. All rights reserved.
//

import Accelerate
import CoreML

extension CGImage {
    /// Expand the image to a size larger than block_size
    func preExpand(block_size: Int) throws -> CGImage {
        // Check if expansion is needed
        guard width < block_size || height < block_size else { return self }

        var fullWidth = width
        var fullHeight = height

        if width < block_size {
            fullWidth = block_size
        }
        if height < block_size {
            fullHeight = block_size
        }
        var bitmapInfo = bitmapInfo.rawValue
        if bitmapInfo & CGBitmapInfo.alphaInfoMask.rawValue == CGImageAlphaInfo.first.rawValue {
            bitmapInfo = bitmapInfo & ~CGBitmapInfo.alphaInfoMask.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        } else if bitmapInfo & CGBitmapInfo.alphaInfoMask.rawValue == CGImageAlphaInfo.last.rawValue {
            bitmapInfo = bitmapInfo & ~CGBitmapInfo.alphaInfoMask.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        }
        let context = CGContext(
            data: nil, width: fullWidth, height: fullHeight,
            bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow / width * fullWidth,
            space: colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
        )
        let y = max(fullHeight - height, 0)
        context?.draw(self, in: CGRect(x: 0, y: y, width: width, height: height))
        guard let contextCG = context?.makeImage()
        else { throw Waifu2xError.expandImageFailed }
        return contextCG
    }

    func alpha() -> [UInt8]? {
        guard alphaInfo != CGImageAlphaInfo.none else { return nil }
        var array = alphaUInt8Array()
        var floatAlpha = [Float](repeating: 0, count: array.count)
        // Check if it really has alpha
        var minValue: Float = 1.0
        var minIndex: vDSP_Length = 0
        vDSP_vfltu8(&array, 1, &floatAlpha, 1, vDSP_Length(array.count))
        vDSP_minvi(&floatAlpha, 1, &minValue, &minIndex, vDSP_Length(array.count))
        guard minValue < 255.0 else { return nil }
        return array
    }
}

extension [Float] {
    /// Use vImage to convert the RGB format to the planar format required by the waifu2x model
    func convertToML(x: Int, y: Int, blockSize: Int, expwidth: Int, expheight: Int) throws -> MLMultiArray {
        let channelSize = blockSize * blockSize

        // Create MLMultiArray with shape [channels, height, width]
        let shape: [NSNumber] = [3, NSNumber(value: blockSize), NSNumber(value: blockSize)]
        let array = try Result { try MLMultiArray(shape: shape, dataType: .float32) }
            .mapError { Waifu2xError.coreMLError($0.localizedDescription) }
            .get()
        let arrayPtr = array.dataPointer.assumingMemoryBound(to: Float.self)

        // Process each RGB channel concurrently
        for channel in 0 ..< 3 {
            let channelOffset = channel * expwidth * expheight
            let destBaseOffset = channel * channelSize

            // Copy each row of the block
            for row in 0 ..< blockSize {
                let srcOffset = channelOffset + (y + row) * expwidth + x
                let destOffset = destBaseOffset + row * blockSize

                // Use vDSP for optimized memory copy
                withUnsafeBufferPointer { buffer in
                    let src = UnsafePointer(buffer.baseAddress!.advanced(by: srcOffset))
                    let dest = UnsafeMutablePointer(arrayPtr.advanced(by: destOffset))

                    // Copy the current row data
                    vDSP_mmov(src, dest, vDSP_Length(blockSize), 1, 1, 1)
                }
            }
        }

        return array
    }
}

extension [UInt8] {
    /// Using vImage to handle alpha channel scaling
    func scaleAlpha(width: Int, height: Int, scale: Int) throws -> [UInt8] {
        let newWidth = width * scale
        let newHeight = height * scale

        return try withUnsafeBufferPointer { buffer in
            // Create source buffer
            var sourceBuffer = vImage_Buffer(
                data: UnsafeMutableRawPointer(mutating: buffer.baseAddress!),
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: width
            )

            // Create destination buffer
            let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: newWidth * newHeight)
            defer { destBuffer.deallocate() }

            var destBufferInfo = vImage_Buffer(
                data: destBuffer,
                height: vImagePixelCount(newHeight),
                width: vImagePixelCount(newWidth),
                rowBytes: newWidth
            )

            // Perform scaling
            let error = vImageScale_Planar8(&sourceBuffer, &destBufferInfo, nil, vImage_Flags(kvImageHighQualityResampling))
            guard error == kvImageNoError else { throw Waifu2xError.vImageScalingFailed }

            return Array(UnsafeBufferPointer(start: destBuffer, count: newWidth * newHeight))
        }
    }
}

extension MLMultiArray {
    /// Use vImage to convert the model output to UInt8
    func covertToUInt8(bufferSize: Int) -> [UInt8] {
        let dataPointer = dataPointer.assumingMemoryBound(to: Double.self)

        // Create a temporary buffer for normalized data
        let tempBuffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer { tempBuffer.deallocate() }

        // Use vDSP for batch conversion from Double to Float and normalize
        vDSP_vdpsp(dataPointer, 1, tempBuffer, 1, vDSP_Length(bufferSize))
        var scale: Float = 255.0
        vDSP_vsmul(tempBuffer, 1, &scale, tempBuffer, 1, vDSP_Length(bufferSize))

        // Use vDSP to clip values to valid range
        var minValue: Float = 0.0
        var maxValue: Float = 255.0
        vDSP_vclip(tempBuffer, 1, &minValue, &maxValue, tempBuffer, 1, vDSP_Length(bufferSize))

        // Convert Float to UInt8 in batch
        var result = [UInt8](repeating: 0, count: bufferSize)
        result.withUnsafeMutableBufferPointer { buffer in
            vDSP_vfix8(tempBuffer, 1, buffer.baseAddress!, 1, vDSP_Length(bufferSize))
        }

        return result
    }
}
