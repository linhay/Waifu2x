//
//  Models.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/6.
//  Copyright © 2025 vuhe. All rights reserved.
//

import CoreML
import Waifu2xCore

// MARK: - waifu2x SRCNN

public enum Waifu2xSrcnnModel: String, CaseIterable, Sendable {
    case anime_noise0 = "anime_noise0_model"
    case anime_noise1 = "anime_noise1_model"
    case anime_noise2 = "anime_noise2_model"
    case anime_noise3 = "anime_noise3_model"
    case anime_scale2x = "up_anime_scale2x_model"
    case anime_noise0_scale2x = "up_anime_noise0_scale2x_model"
    case anime_noise1_scale2x = "up_anime_noise1_scale2x_model"
    case anime_noise2_scale2x = "up_anime_noise2_scale2x_model"
    case anime_noise3_scale2x = "up_anime_noise3_scale2x_model"
    case photo_noise0 = "photo_noise0_model"
    case photo_noise1 = "photo_noise1_model"
    case photo_noise2 = "photo_noise2_model"
    case photo_noise3 = "photo_noise3_model"
    case photo_scale2x = "up_photo_scale2x_model"
    case photo_noise0_scale2x = "up_photo_noise0_scale2x_model"
    case photo_noise1_scale2x = "up_photo_noise1_scale2x_model"
    case photo_noise2_scale2x = "up_photo_noise2_scale2x_model"
    case photo_noise3_scale2x = "up_photo_noise3_scale2x_model"
}

private extension Waifu2xSrcnnModel {
    var scale2x: Bool {
        switch self {
        case .anime_noise0, .anime_noise1, .anime_noise2, .anime_noise3, .photo_noise0, .photo_noise1, .photo_noise2, .photo_noise3: false
        default: true
        }
    }
}

extension Waifu2xSrcnnModel: Waifu2xModelInfo {
    public var name: String { rawValue }
    public var inputShape: [Int] { if scale2x { [3, 156, 156] } else { [3, 142, 142] } }
    public var shrinkSize: Int { 7 }
    public var outScale: Int { if scale2x { 2 } else { 1 } }
    public var blockSize: Int { if scale2x { 142 } else { 128 } }
    public var shrinkAfterHandled: Bool { false }

    public var mainModel: MLModel {
        let assetPath = Bundle.module.url(forResource: rawValue, withExtension: "mlmodelc")
        // Loading embedded models should not result in errors
        return try! MLModel(contentsOf: assetPath!)
    }

    public var mainInputName: String { "input" }
    public var mainOutputName: String { "conv7" }
}

public extension Waifu2x {
    init(srcnn model: Waifu2xSrcnnModel, batchSize: Int = 10) {
        self.init(model, batchSize: batchSize)
    }
}
