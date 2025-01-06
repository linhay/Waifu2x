//
//  Waifu2xModel.swift
//  Waifu2x
//
//  Created by xieyi on 2017/11/5.
//  Copyright © 2017 xieyi. All rights reserved.
//
//  Modify by vuhe on 2024/12/25.
//  Copyright © 2024 vuhe. All rights reserved.
//

import CoreML

public enum Waifu2xModelDataType: Sendable {
    case planar, interleaved
}

public protocol Waifu2xModelInfo: Sendable {
    var name: String { get }
    var dataType: Waifu2xModelDataType { get }
    var inputShape: [Int] { get }
    // for input:  block size = blockSize + shrinkSize * 2
    // for output: block size = blockSize * outScale
    var shrinkSize: Int { get }
    var outScale: Int { get }
    var blockSize: Int { get }
    var mainModel: MLModel { get }
    var mainInputName: String { get }
    var mainOutputName: String { get }
}
