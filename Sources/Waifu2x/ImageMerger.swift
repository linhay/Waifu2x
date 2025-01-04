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

    init(width: Int, height: Int, block_size: Int, out_scale: Int, channels: Int) {
        let out_width = width * out_scale
        let out_height = height * out_scale
        self.width = width
        self.height = height
        self.block_size = block_size
        self.out_scale = out_scale
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

        // Normalize the model output data to UInt8
        let bufferSize = out_block_size * out_block_size * 3
        let uint8Array = array.covertToUInt8(bufferSize: bufferSize)

        // Process each RGB channel
        uint8Array.withUnsafeBufferPointer { buffer in
            rChannel.withUnsafeMutableBufferPointer { channel in
                let channelOffset = 0 * out_block_size * out_block_size
                // Copy each row of the block
                for row in 0 ..< validHeight {
                    let srcRowStart = channelOffset + row * out_block_size
                    let destRowStart = (origin_y + row) * out_width + origin_x
                    // Continuous memory copy for better performance
                    memcpy(
                        channel.baseAddress!.advanced(by: destRowStart),
                        buffer.baseAddress!.advanced(by: srcRowStart),
                        validWidth
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
                    memcpy(
                        channel.baseAddress!.advanced(by: destRowStart),
                        buffer.baseAddress!.advanced(by: srcRowStart),
                        validWidth
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
                    memcpy(
                        channel.baseAddress!.advanced(by: destRowStart),
                        buffer.baseAddress!.advanced(by: srcRowStart),
                        validWidth
                    )
                }
            }
        }
    }

    // Create final image data with all channels combined
    func freezeImage() -> CFData {
        let out_width = width * out_scale
        let out_height = height * out_scale

        // Create destination buffer for interleaved format
        var destPixels = [UInt8](repeating: 0, count: out_width * out_height * 4)
        destPixels.copyFromRGBA(
            r: &rChannel, g: &gChannel, b: &bChannel, a: &aChannel,
            width: out_width, height: out_height
        )

        return Data(destPixels) as CFData
    }
}
