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

class ModelTask {
    private static let queue = DispatchQueue(label: "top.vuhe.waifu-model", attributes: .concurrent)
    /// Make sure only one thread visit var value
    private let work_sem = DispatchSemaphore(value: 1)
    /// Output task
    private let nextTask: OutputTask
    /// batch handle model
    private let model: MLModel

    init(_ nextTask: OutputTask, model: MLModel) {
        self.nextTask = nextTask
        self.model = model
    }

    fileprivate func run(idx: Int, _ array: MLMultiArray) {
        Self.queue.async {
            let output = try! self.model.prediction(input: array)
            self.work_sem.wait()
            self.nextTask.run(idx: idx, output)
            self.work_sem.signal()
        }
    }
}

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
