//
//  Waifu2xModel.swift
//  Waifu2x
//
//  Modify by vuhe on 2025/1/5.
//  Copyright © 2025 vuhe. All rights reserved.
//

import CoreML

public protocol Waifu2xModelInfo: Sendable {
    var name: String { get }

    var inputShape: [Int] { get }
    var shrinkSize: Int { get }

    var outScale: Int { get }
    // for input:  block size = blockSize + shrinkSize * 2
    // for output: block size = blockSize * outScale
    var blockSize: Int { get }

    var mainModel: MLModel { get }
    var mainInputName: String { get }
    var mainOutputName: String { get }
}
