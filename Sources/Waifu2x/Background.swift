//
//  Background.swift
//  Waifu2x
//
//  Created by vuhe on 2024/9/25.
//

import CoreML

/// Model Prediction Input Type
private final class Waifu2xInput: MLFeatureProvider {
    let input: MLMultiArray
    var featureNames: Set<String> { ["input"] }

    init(input: MLMultiArray) {
        self.input = input
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        return if featureName == "input" { MLFeatureValue(multiArray: input) }
        else { nil }
    }
}

struct PipelineTask {
    let input: (CGRect) -> MLMultiArray
    let model: MLModel
    let output: (Int, MLMultiArray) -> Void

    func run(idx: Int, rects: ArraySlice<CGRect>) {
        let inputs = rects.map { Waifu2xInput(input: input($0)) }
        let batch = MLArrayBatchProvider(array: inputs)
        let outs = try! model.predictions(fromBatch: batch)

        for i in 0 ..< outs.count {
            let out = outs.features(at: i)
            let result = out.featureValue(for: "conv7")!.multiArrayValue!
            output(idx + i, result)
        }
    }
}
