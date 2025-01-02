//
//  Background.swift
//  Waifu2x
//
//  Created by vuhe on 2024/9/25.
//  Copyright © 2024 vuhe. All rights reserved.
//

import CoreML

/// Model Prediction Input Type
private final class Waifu2xInput: MLFeatureProvider {
    private let input: MLMultiArray
    var featureNames: Set<String> { ["input"] }

    init(_ input: MLMultiArray) {
        self.input = input
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "input" { MLFeatureValue(multiArray: input) }
        else { nil }
    }
}

actor InputTask {
    private let expanded: [Float]
    private let blockSize, expwidth, expheight: Int

    init(expanded: [Float], blockSize: Int, expwidth: Int, expheight: Int) {
        self.expanded = expanded
        self.blockSize = blockSize
        self.expwidth = expwidth
        self.expheight = expheight
    }

    fileprivate func handleInput(rects: [CGRect]) throws -> MLArrayBatchProvider {
        let batch = try rects.map { rect in
            let input = try expanded.convertToML(
                x: Int(rect.origin.x), y: Int(rect.origin.y),
                blockSize: blockSize, expwidth: expwidth, expheight: expheight
            )
            return Waifu2xInput(input)
        }
        return MLArrayBatchProvider(array: batch)
    }
}

actor ModelTask {
    private let model: MLModel

    init(_ model: Waifu2xModel) {
        self.model = model.getMLModel()
    }

    fileprivate func predictions(batch: MLArrayBatchProvider) throws -> any MLBatchProvider {
        do {
            return try model.predictions(fromBatch: batch)
        } catch {
            throw Waifu2xError.coreMLError(error.localizedDescription)
        }
    }
}

actor OutputTask {
    private var image: [UInt8]
    private let width, height, block_size, out_scale, channels: Int

    init(width: Int, height: Int, block_size: Int, out_scale: Int, channels: Int) {
        let out_width = width * out_scale
        let out_height = height * out_scale
        image = [UInt8](repeating: 0, count: out_width * out_height * channels)
        self.width = width
        self.height = height
        self.block_size = block_size
        self.out_scale = out_scale
        self.channels = channels
    }

    func mergeAlpha(alpha: [UInt8]) {
        let out_width = width * out_scale
        let out_height = height * out_scale
        for y in 0 ..< out_height {
            for x in 0 ..< out_width {
                image[(y * out_width + x) * channels + 3] = alpha[y * out_width + x]
            }
        }
    }

    fileprivate func mergeRGB(_ rect: CGRect, _ array: MLMultiArray) {
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
        for channel in 0 ..< 3 {
            let channelOffset = channel * out_block_size * out_block_size

            // Copy each row of the block
            for row in 0 ..< validHeight {
                let srcRowStart = channelOffset + row * out_block_size
                let destRowStart = ((origin_y + row) * out_width + origin_x) * channels + channel

                // Copy pixels with channel stride
                for i in 0 ..< validWidth {
                    image[destRowStart + (i * channels)] = uint8Array[srcRowStart + i]
                }
            }
        }
    }

    func freezeImage() -> CFData {
        Data(image) as CFData
    }
}

struct PipelineTask: Sendable {
    let input: InputTask
    let model: ModelTask
    let output: OutputTask

    func run(rects: [CGRect]) async throws {
        let batch = try await input.handleInput(rects: rects)
        let outs = try await model.predictions(batch: batch)
        for i in 0 ..< outs.count {
            let out = outs.features(at: i)
            let result = out.featureValue(for: "conv7")!.multiArrayValue!
            await output.mergeRGB(rects[i], result)
        }
    }
}
