//
//  AccelerateUtils.swift
//  Waifu2x
//
//  Created by vuhe on 2024/12/31.
//  Copyright © 2024 vuhe. All rights reserved.
//

import Accelerate
import CoreML

typealias VImagePointer<T> = UnsafeMutableBufferPointer<T>

func withUnsafeMutableBufferPointer<T1, T2, T3, T4, T5>(
    _ a: inout [T1], _ b: inout [T2], _ c: inout [T3], _ d: inout [T4], _ e: inout [T5],
    invoke: @escaping (
        VImagePointer<T1>, VImagePointer<T2>, VImagePointer<T3>, VImagePointer<T4>, VImagePointer<T5>
    ) throws -> Void
) throws {
    try a.withUnsafeMutableBufferPointer { aBuffer in
        try b.withUnsafeMutableBufferPointer { bBuffer in
            try c.withUnsafeMutableBufferPointer { cBuffer in
                try d.withUnsafeMutableBufferPointer { dBuffer in
                    try e.withUnsafeMutableBufferPointer { eBuffer in
                        try invoke(aBuffer, bBuffer, cBuffer, dBuffer, eBuffer)
                    }
                }
            }
        }
    }
}

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

    func alpha() throws -> [UInt8]? {
        guard alphaInfo != CGImageAlphaInfo.none else { return nil }
        var array = try alphaUInt8Array()
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

extension [UInt8] {
    /// Using vImage to handle alpha channel scaling
    func scaleAlpha(width: Int, height: Int, scale: Int) throws -> [UInt8] {
        let newWidth = width * scale
        let newHeight = height * scale

        return try withUnsafeBufferPointer { buffer in
            // Create source buffer
            var sourceBuffer = vImage_Buffer(
                data: UnsafeMutableRawPointer(mutating: buffer.baseAddress),
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: width
            )

            // Create destination buffer
            var dest = [UInt8](repeating: 0, count: newWidth * newHeight)
            try dest.withUnsafeMutableBufferPointer { destBuffer in
                var destBufferInfo = vImage_Buffer(
                    data: destBuffer.baseAddress,
                    height: vImagePixelCount(newHeight),
                    width: vImagePixelCount(newWidth),
                    rowBytes: newWidth
                )

                // Perform scaling
                let error = vImageScale_Planar8(&sourceBuffer, &destBufferInfo, nil, vImage_Flags(kvImageHighQualityResampling))
                guard error == kvImageNoError else { throw Waifu2xError.vImageScalingFailed }
            }

            return dest
        }
    }
}
