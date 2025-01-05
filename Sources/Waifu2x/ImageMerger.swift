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
    private let width, height, block_size, out_scale, channels: Int

    // Separate RGBA channels for parallel processing
    private var rChannel: [UInt8]
    private var gChannel: [UInt8]
    private var bChannel: [UInt8]
    private var aChannel: [UInt8]

    init(width: Int, height: Int, model: Waifu2xModelInfo, channels: Int) {
        let out_width = width * model.outScale
        let out_height = height * model.outScale
        self.width = width
        self.height = height
        block_size = model.blockSize
        out_scale = model.outScale
        self.channels = channels

        let size = out_width * out_height
        rChannel = [UInt8](repeating: 0, count: size)
        gChannel = [UInt8](repeating: 0, count: size)
        bChannel = [UInt8](repeating: 0, count: size)
        // Initialize alpha channel with 255 (fully opaque) by default
        aChannel = [UInt8](repeating: 255, count: size)
    }

    func mergeAlpha(alpha: [UInt8]) {
        aChannel = alpha
    }

    func mergeRGB(_ rect: CGRect, _ array: MLMultiArray) {
        let out_width = width * out_scale
        let out_height = height * out_scale
        let out_block_size = block_size * out_scale
        let origin_x = Int(rect.origin.x) * out_scale
        let origin_y = Int(rect.origin.y) * out_scale

        // Calculate the effective replication area
        let validHeight = min(out_block_size, out_height - origin_y)
        let validWidth = min(out_block_size, out_width - origin_x)
        guard validWidth > 0, validHeight > 0 else { return }

        let bufferSize = out_block_size * out_block_size * 3
        array.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
            let arrayAddress = ptr.baseAddress!

            var scale: Float = 255.0
            vDSP_vsmul(arrayAddress, 1, &scale, arrayAddress, 1, vDSP_Length(bufferSize))
            // Use vDSP to clip values to valid range
            var minValue: Float = 0.0
            var maxValue: Float = 255.0
            vDSP_vclip(arrayAddress, 1, &minValue, &maxValue, arrayAddress, 1, vDSP_Length(bufferSize))

            // Process each RGB channel
            rChannel.withUnsafeMutableBufferPointer { channel in
                let channelOffset = 0 * out_block_size * out_block_size
                // Copy each row of the block
                for row in 0 ..< validHeight {
                    let srcRowStart = channelOffset + row * out_block_size
                    let destRowStart = (origin_y + row) * out_width + origin_x
                    // Continuous memory copy for better performance
                    vDSP_vfixu8(
                        arrayAddress.advanced(by: srcRowStart), 1,
                        channel.baseAddress!.advanced(by: destRowStart), 1,
                        vDSP_Length(validWidth)
                    )
                }
            }
            gChannel.withUnsafeMutableBufferPointer { channel in
                let channelOffset = 1 * out_block_size * out_block_size
                // Copy each row of the block
                for row in 0 ..< validHeight {
                    let srcRowStart = channelOffset + row * out_block_size
                    let destRowStart = (origin_y + row) * out_width + origin_x
                    // Continuous memory copy for better performance
                    vDSP_vfixu8(
                        arrayAddress.advanced(by: srcRowStart), 1,
                        channel.baseAddress!.advanced(by: destRowStart), 1,
                        vDSP_Length(validWidth)
                    )
                }
            }
            bChannel.withUnsafeMutableBufferPointer { channel in
                let channelOffset = 2 * out_block_size * out_block_size
                // Copy each row of the block
                for row in 0 ..< validHeight {
                    let srcRowStart = channelOffset + row * out_block_size
                    let destRowStart = (origin_y + row) * out_width + origin_x
                    // Continuous memory copy for better performance
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
        let out_width = width * out_scale
        let out_height = height * out_scale

        // Create destination buffer for interleaved format
        var destPixels = [UInt8](repeating: 0, count: out_width * out_height * 4)
        try withUnsafeMutableBufferPointer(&rChannel, &gChannel, &bChannel, &aChannel, &destPixels) { r, g, b, a, dest in
            var rImageBuffer = vImage_Buffer(
                data: r.baseAddress, height: vImagePixelCount(out_height),
                width: vImagePixelCount(out_width), rowBytes: out_width
            )
            var gImageBuffer = vImage_Buffer(
                data: g.baseAddress, height: vImagePixelCount(out_height),
                width: vImagePixelCount(out_width), rowBytes: out_width
            )
            var bImageBuffer = vImage_Buffer(
                data: b.baseAddress, height: vImagePixelCount(out_height),
                width: vImagePixelCount(out_width), rowBytes: out_width
            )
            var aImageBuffer = vImage_Buffer(
                data: a.baseAddress, height: vImagePixelCount(out_height),
                width: vImagePixelCount(out_width), rowBytes: out_width
            )
            var destImageBuffer = vImage_Buffer(
                data: dest.baseAddress, height: vImagePixelCount(out_height),
                width: vImagePixelCount(out_width), rowBytes: out_width * 4
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
