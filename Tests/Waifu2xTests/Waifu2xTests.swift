//
//  Waifu2xTests.swift
//  Waifu2x
//
//  Created by vuhe on 2024/9/25.
//  Copyright © 2024 vuhe. All rights reserved.
//

import Cocoa
import Testing

#if DEBUG
    @testable import Waifu2x
#else
    import Waifu2x
#endif

@Test func testModel() async throws {
    let monitor = PerformanceMonitor()
    _ = try! await monitor.measure {
        let url = Bundle.module.url(forResource: "white", withExtension: "png")!
        let waifu2x = Waifu2x(model: .anime_noise3_scale2x)
        return try await waifu2x.run(Data(contentsOf: url))
    }
}

@Test func testAllModels() async throws {
    await withTaskGroup(of: Void.self) { group in
        let url = Bundle.module.url(forResource: "white", withExtension: "png")!
        for model in Waifu2xModel.allCases {
            group.addTask {
                let startTime = CFAbsoluteTimeGetCurrent()
                let waifu2x = Waifu2x(model: model)
                _ = try! await waifu2x.run(Data(contentsOf: url))
                let endTime = CFAbsoluteTimeGetCurrent()
                print("\(model) handled \(endTime - startTime) sec")
            }
        }
    }
}

@Test func testGCD() throws {
    let url = Bundle.module.url(forResource: "white", withExtension: "png")!
    let waifu2x = Waifu2x(model: .photo_noise2_scale2x)
    _ = try! waifu2x.runAndWait(Data(contentsOf: url))
}

@Test func testOptimalBatchSize() throws {
    // Load test image
    let url = Bundle.module.url(forResource: "white", withExtension: "png")!
    let imageData = try Data(contentsOf: url)

    // First phase: Find the rough range by doubling batch size
    var batchSize = 1
    var lastTime = Double.infinity
    var times: [(size: Int, time: Double)] = []

    print("\n=== Phase 1: Finding Range ===")
    while true {
        let startTime = DispatchTime.now()
        let waifu2x = Waifu2x(model: .anime_noise3_scale2x, batchSize: batchSize)
        _ = try waifu2x.runAndWait(imageData)
        let timeInMs = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000

        times.append((batchSize, timeInMs))
        print("Batch size \(batchSize): \(timeInMs.rounded(to: 2))ms")

        // If time increases significantly (>10%), we've found our upper bound
        if timeInMs > lastTime * 1.1, times.count > 2 {
            break
        }

        lastTime = timeInMs
        batchSize *= 2
    }

    // Find the range for fine-tuning
    let sortedTimes = times.sorted { $0.time < $1.time }
    let bestRoughSize = sortedTimes[0].size
    let lowerBound = bestRoughSize / 2
    let upperBound = bestRoughSize * 2

    // Second phase: Fine-tune within the range
    print("\n=== Phase 2: Fine-tuning ===")
    var refinedTimes: [(size: Int, time: Double)] = []
    let step = max(1, (upperBound - lowerBound) / 10)

    for size in stride(from: lowerBound, through: upperBound, by: step) {
        let startTime = DispatchTime.now()
        let waifu2x = Waifu2x(model: .anime_noise3_scale2x, batchSize: size)
        _ = try waifu2x.runAndWait(imageData)
        let timeInMs = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000

        refinedTimes.append((size, timeInMs))
        print("Batch size \(size): \(timeInMs.rounded(to: 2))ms")
    }

    // Find the optimal batch size
    let optimal = refinedTimes.min { $0.time < $1.time }!
    print("\n=== Result ===")
    print("Optimal batch size: \(optimal.size)")
    print("Processing time: \(optimal.time.rounded(to: 2))ms")
}
