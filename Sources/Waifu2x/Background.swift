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
    private let inputName: String
    private let input: MLMultiArray
    let featureNames: Set<String>

    init(_ input: MLMultiArray, _ inputName: String) {
        self.input = input
        self.inputName = inputName
        featureNames = [inputName]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == inputName { MLFeatureValue(multiArray: input) }
        else { nil }
    }
}

actor InputTask {
    private let expanded: ExpandedImage
    private let inputName: String

    init(_ expanded: ExpandedImage, inputName: String) {
        self.expanded = expanded
        self.inputName = inputName
    }

    fileprivate func handleInput(rects: [CGRect]) throws -> MLArrayBatchProvider {
        let batch = try rects.map { try Waifu2xInput(expanded.convertToML(rect: $0), inputName) }
        return MLArrayBatchProvider(array: batch)
    }
}

actor ModelTask {
    private let model: MLModel

    init(_ model: Waifu2xModelInfo) {
        self.model = model.mainModel
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
    let outputName: String

    func run(rects: [CGRect]) async throws {
        let batch = try await input.handleInput(rects: rects)
        let outs = try await model.predictions(batch: batch)
        for i in 0 ..< outs.count {
            let out = outs.features(at: i)
            guard let result = out.featureValue(for: outputName)?.multiArrayValue
            else { throw Waifu2xError.coreMLError("main model outputName is incorrect") }
            await output.mergeRGB(rects[i], result)
        }
    }
}
