//
//  ImageMerger.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/4.
//  Copyright © 2025 vuhe. All rights reserved.
//

import Accelerate
import CoreML

actor ImageMerger {
    private let width, height, blockSize, shrinkSize, outScale, channels: Int

    // Separate RGBA channels for parallel processing
    private var rChannel: [UInt8]
    private var gChannel: [UInt8]
    private var bChannel: [UInt8]
    private var aChannel: [UInt8]

    init(width: Int, height: Int, model: Waifu2xModelInfo, channels: Int) {
        let outWidth = width * model.outScale
        let outHeight = height * model.outScale
        self.width = width
        self.height = height
        blockSize = model.blockSize
        shrinkSize = if model.shrinkAfterHandled { model.shrinkSize * model.outScale } else { 0 }
        outScale = model.outScale
        self.channels = channels

        let size = outWidth * outHeight
        rChannel = [UInt8](repeating: 0, count: size)
        gChannel = [UInt8](repeating: 0, count: size)
        bChannel = [UInt8](repeating: 0, count: size)
        // Initialize alpha channel with 255 (fully opaque) by default
        aChannel = [UInt8](repeating: 255, count: size)
    }

    func mergeAlpha(alpha: [UInt8]) {
        aChannel = alpha
    }

    func mergeRGB(_ rect: CGRect, _ array: MLMultiArray) throws {
        let outWidth = width * outScale
        let outHeight = height * outScale
        let outBlockSize = blockSize * outScale
        let originX = Int(rect.origin.x) * outScale
        let originY = Int(rect.origin.y) * outScale

        // Calculate the effective replication area
        let validHeight = min(outBlockSize, outHeight - originY)
        let validWidth = min(outBlockSize, outWidth - originX)
        guard validWidth > 0, validHeight > 0 else { return }

        let bufferSize = outBlockSize * outBlockSize * 3
        array.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
            let arrayAddress = ptr.baseAddress!

            var scale: Float = 255.0
            vDSP_vsmul(arrayAddress, 1, &scale, arrayAddress, 1, vDSP_Length(bufferSize))
            // Use vDSP to clip values to valid range
            var minValue: Float = 0.0
            var maxValue: Float = 255.0
            vDSP_vclip(arrayAddress, 1, &minValue, &maxValue, arrayAddress, 1, vDSP_Length(bufferSize))

            // Process each RGB channel
            let srcBlockSize = outBlockSize + 2 * shrinkSize
            let channelOffset = srcBlockSize * srcBlockSize
            rChannel.withUnsafeMutableBufferPointer { channel in
                for row in 0 ..< validHeight {
                    let srcRowStart = channelOffset * 0 + (row + shrinkSize) * srcBlockSize + shrinkSize
                    let destRowStart = (originY + row) * outWidth + originX
                    vDSP_vfixu8(
                        arrayAddress.advanced(by: srcRowStart), 1,
                        channel.baseAddress!.advanced(by: destRowStart), 1,
                        vDSP_Length(validWidth)
                    )
                }
            }
            gChannel.withUnsafeMutableBufferPointer { channel in
                for row in 0 ..< validHeight {
                    let srcRowStart = channelOffset * 1 + (row + shrinkSize) * srcBlockSize + shrinkSize
                    let destRowStart = (originY + row) * outWidth + originX
                    vDSP_vfixu8(
                        arrayAddress.advanced(by: srcRowStart), 1,
                        channel.baseAddress!.advanced(by: destRowStart), 1,
                        vDSP_Length(validWidth)
                    )
                }
            }
            bChannel.withUnsafeMutableBufferPointer { channel in
                for row in 0 ..< validHeight {
                    let srcRowStart = channelOffset * 2 + (row + shrinkSize) * srcBlockSize + shrinkSize
                    let destRowStart = (originY + row) * outWidth + originX
                    vDSP_vfixu8(
                        arrayAddress.advanced(by: srcRowStart), 1,
                        channel.baseAddress!.advanced(by: destRowStart), 1,
                        vDSP_Length(validWidth)
                    )
                }
            }
        }
    }

    // Create final image data with all channels combined
    func freezeImage() throws -> CFData {
        let outWidth = width * outScale
        let outHeight = height * outScale

        // Create destination buffer for interleaved format
        var destPixels = [UInt8](repeating: 0, count: outWidth * outHeight * 4)
        try withUnsafeMutableBufferPointer(&rChannel, &gChannel, &bChannel, &aChannel, &destPixels) { r, g, b, a, dest in
            var rImageBuffer = vImage_Buffer(
                data: r.baseAddress, height: vImagePixelCount(outHeight),
                width: vImagePixelCount(outWidth), rowBytes: outWidth
            )
            var gImageBuffer = vImage_Buffer(
                data: g.baseAddress, height: vImagePixelCount(outHeight),
                width: vImagePixelCount(outWidth), rowBytes: outWidth
            )
            var bImageBuffer = vImage_Buffer(
                data: b.baseAddress, height: vImagePixelCount(outHeight),
                width: vImagePixelCount(outWidth), rowBytes: outWidth
            )
            var aImageBuffer = vImage_Buffer(
                data: a.baseAddress, height: vImagePixelCount(outHeight),
                width: vImagePixelCount(outWidth), rowBytes: outWidth
            )
            var destImageBuffer = vImage_Buffer(
                data: dest.baseAddress, height: vImagePixelCount(outHeight),
                width: vImagePixelCount(outWidth), rowBytes: outWidth * 4
            )
            // Convert from planar to interleaved format using vImage
            let error = vImageConvert_Planar8toARGB8888(
                &rImageBuffer, &gImageBuffer, &bImageBuffer, &aImageBuffer,
                &destImageBuffer, vImage_Flags(kvImageNoFlags)
            )
            guard error == kvImageNoError else { throw Waifu2xError.createImageFailed("vImage merge fail") }
        }

        return Data(destPixels) as CFData
    }
}
