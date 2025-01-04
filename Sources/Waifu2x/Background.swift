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
    private let expanded: ExpandedImage

    init(_ expanded: ExpandedImage) {
        self.expanded = expanded
    }

    fileprivate func handleInput(rects: [CGRect]) throws -> MLArrayBatchProvider {
        let batch = try rects.map { try Waifu2xInput(expanded.convertToML(rect: $0)) }
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

struct PipelineTask: Sendable {
    let input: InputTask
    let model: ModelTask
    let output: ImageMerger

    func run(rects: [CGRect]) async throws {
        let batch = try await input.handleInput(rects: rects)
        let outs = try await model.predictions(batch: batch)
        for i in 0 ..< outs.count {
            let out = outs.features(at: i)
            // The model ensures that this is not nil
            let result = out.featureValue(for: "conv7")!.multiArrayValue!
            await output.mergeRGB(rects[i], result)
        }
    }
}
