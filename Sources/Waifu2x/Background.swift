//
//  Background.swift
//  Waifu2x
//
//  Created by vuhe on 2024/9/25.
//

import CoreML

/// Model Prediction Input Type
private final class Waifu2xInput: MLFeatureProvider {
    let idx: Int
    let input: MLMultiArray
    var featureNames: Set<String> { ["input"] }

    init(idx: Int, input: MLMultiArray) {
        self.idx = idx
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

    func run(idx: Int, rects: ArraySlice<CGRect>) async {
        let batch = await withTaskGroup(of: Waifu2xInput.self, returning: MLArrayBatchProvider.self) { it in
            for (i, rect) in rects.enumerated() {
                let inputOrder = i
                it.addTask { Waifu2xInput(idx: inputOrder, input: input(rect)) }
            }
            var inputs: [Waifu2xInput] = []
            for await input in it {
                inputs.append(input)
            }
            inputs.sort { $0.idx < $1.idx }
            return MLArrayBatchProvider(array: inputs)
        }
        let outs = try! model.predictions(fromBatch: batch)

        for i in 0 ..< outs.count {
            let out = outs.features(at: i)
            let result = out.featureValue(for: "conv7")!.multiArrayValue!
            output(idx + i, result)
        }
    }
}
