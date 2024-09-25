//
//  Background.swift
//  Waifu2x
//
//  Created by vuhe on 2024/9/25.
//

import CoreML

struct AlphaTask {
    private static let queue = DispatchQueue(label: "top.vuhe.waifu-alpha", attributes: .concurrent)
    private let group = DispatchGroup()

    func run(_ task: @escaping () -> Void) {
        Self.queue.async(group: group, execute: task)
    }

    func wait() {
        group.wait()
    }
}

class InputTask {
    private static let queue = DispatchQueue(label: "top.vuhe.waifu-input", attributes: .concurrent)
    private let nextTask: ModelTask
    private let handle: (CGRect) -> MLMultiArray

    init(_ nextTask: ModelTask, handle: @escaping (CGRect) -> MLMultiArray) {
        self.nextTask = nextTask
        self.handle = handle
    }

    func run(idx: Int, rect: CGRect) {
        Self.queue.async {
            let array = self.handle(rect)
            self.nextTask.run(idx: idx, array)
        }
    }
}

// MARK: - waifu2x model handle

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

class ModelTask: MLBatchProvider {
    private static let queue = DispatchQueue(label: "top.vuhe.waifu-model")
    /// Output task
    private let nextTask: OutputTask
    /// Batch handle model
    private let model: MLModel
    /// Need handle item total
    private let total: Int
    /// Handled item total
    private var inputCount = 0
    /// Save input as batch
    private var inputMap: [Int: MLMultiArray] = [:]

    var count: Int { total }

    init(_ nextTask: OutputTask, total: Int, model: MLModel) {
        self.nextTask = nextTask
        self.total = total
        self.model = model
    }

    fileprivate func run(idx: Int, _ array: MLMultiArray) {
        Self.queue.async {
            self.inputMap[idx] = array
            self.inputCount += 1
            if self.inputCount >= self.total {
                autoreleasepool {
                    let output = try! self.model.predictions(fromBatch: self)
                    self.inputMap = [:]
                    for i in 0 ..< self.total {
                        let result = output.features(at: i).featureValue(for: "conv7")!.multiArrayValue!
                        self.nextTask.run(idx: i, result)
                    }
                }
            }
        }
    }

    func features(at index: Int) -> any MLFeatureProvider {
        Waifu2xInput(input: inputMap[index]!)
    }
}

// MARK: - output stage

class OutputTask {
    private static let queue = DispatchQueue(label: "top.vuhe.waifu-output", attributes: .concurrent)
    /// Make sure only one thread visit var value
    private let work_sem = DispatchSemaphore(value: 1)
    /// Used to wait for operations to complete
    private let wait_sem = DispatchSemaphore(value: 0)
    /// handle func
    private let handle: (Int, MLMultiArray) -> Void
    /// Need handle item total
    private let total: Int
    /// Handled item total
    private var count = 0

    init(total: Int, handle: @escaping (Int, MLMultiArray) -> Void) {
        self.handle = handle
        self.total = total
    }

    fileprivate func run(idx: Int, _ array: MLMultiArray) {
        Self.queue.async {
            self.handle(idx, array)
            self.work_sem.wait()
            self.count += 1
            if self.count >= self.total { self.wait_sem.signal() }
            self.work_sem.signal()
        }
    }

    func wait() { wait_sem.wait() }
}
