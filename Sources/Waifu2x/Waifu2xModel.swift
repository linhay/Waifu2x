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

struct Waifu2xModelInfo {
    let name: String
    let inputShape: [NSNumber]
    // for input:  block size = blockSize + shrinkSize * 2
    // for output: block size = blockSize * outScale
    let shrinkSize, outScale, blockSize: Int
    let mainModel: MLModel
    let mainInputName, mainOutputName: String
}

// MARK: - SRCNN model

public enum Waifu2xModel: String, CaseIterable, Sendable {
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

extension Waifu2xModel {
    var model: Waifu2xModelInfo {
        let scale2x = switch self {
        case .anime_noise0, .anime_noise1, .anime_noise2, .anime_noise3, .photo_noise0, .photo_noise1, .photo_noise2, .photo_noise3: false
        default: true
        }
        let inputShape = if scale2x { [3, 156, 156] } else { [3, 142, 142] }
        let outScale = if scale2x { 2 } else { 1 }
        let blockSize = if scale2x { 142 } else { 128 }
        let assetPath = Bundle.module.url(forResource: rawValue, withExtension: "mlmodelc")
        // Loading embedded models should not result in errors
        let mainModel = try! MLModel(contentsOf: assetPath!)
        return Waifu2xModelInfo(
            name: rawValue, inputShape: inputShape.map { NSNumber(value: $0) },
            shrinkSize: 7, outScale: outScale, blockSize: blockSize,
            mainModel: mainModel, mainInputName: "input", mainOutputName: "conv7"
        )
    }
}
