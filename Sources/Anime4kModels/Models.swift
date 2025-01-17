//
//  Models.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/7.
//  Copyright © 2025 vuhe. All rights reserved.
//

import CoreML
import Waifu2xCore

public enum Anime4kModel: String, CaseIterable, Sendable {
    // models
    case model_restore_l
    case model_restore_m
    case model_restore_s
    case model_restore_ul
    case model_restore_vl
    case model_restore_soft_l
    case model_restore_soft_m
    case model_restore_soft_s
    case model_restore_soft_ul
    case model_restore_soft_vl
    case model_sr_denoise_l
    case model_sr_denoise_m
    case model_sr_denoise_s
    case model_sr_denoise_ul
    case model_sr_denoise_vl
    case model_sr_l
    case model_sr_m
    case model_sr_s
    case model_sr_ul
    case model_sr_vl
    case model_sr_l_gan
    case model_sr_m_gan
    case model_sr_s_gan
    case model_sr_ul_gan
    case model_sr_vl_gan
    case model_sr_uul_gan

    // presets 2x
    case perset2x_a_fast
    case perset2x_a_hq
    case perset2x_b_fast
    case perset2x_b_hq
    case perset2x_c_fast
    case perset2x_c_hq
    case perset2x_a_a_fast
    case perset2x_a_a_hq
    case perset2x_b_b_fast
    case perset2x_b_b_hq
    case perset2x_c_a_fast
    case perset2x_c_a_hq

    // presets 4x
    case perset4x_a_fast
    case perset4x_a_hq
    case perset4x_b_fast
    case perset4x_b_hq
    case perset4x_c_fast
    case perset4x_c_hq
    case perset4x_a_a_fast
    case perset4x_a_a_hq
    case perset4x_b_b_fast
    case perset4x_b_b_hq
    case perset4x_c_a_fast
    case perset4x_c_a_hq
}

extension Anime4kModel: Waifu2xModelInfo {
    public var name: String {
        switch self {
        case .model_restore_l: "Anime4K: Restore CNN L"
        case .model_restore_m: "Anime4K: Restore CNN M"
        case .model_restore_s: "Anime4K: Restore CNN S"
        case .model_restore_ul: "Anime4K: Restore CNN UL"
        case .model_restore_vl: "Anime4K: Restore CNN VL"
        case .model_restore_soft_l: "Anime4K: Restore CNN Soft L"
        case .model_restore_soft_m: "Anime4K: Restore CNN Soft M"
        case .model_restore_soft_s: "Anime4K: Restore CNN Soft S"
        case .model_restore_soft_ul: "Anime4K: Restore CNN Soft UL"
        case .model_restore_soft_vl: "Anime4K: Restore CNN Soft VL"
        case .model_sr_denoise_l: "Anime4K: Upscale Denoise CNN L"
        case .model_sr_denoise_m: "Anime4K: Upscale Denoise CNN M"
        case .model_sr_denoise_s: "Anime4K: Upscale Denoise CNN S"
        case .model_sr_denoise_ul: "Anime4K: Upscale Denoise CNN UL"
        case .model_sr_denoise_vl: "Anime4K: Upscale Denoise CNN VL"
        case .model_sr_l: "Anime4K: Upscale CNN L"
        case .model_sr_m: "Anime4K: Upscale CNN M"
        case .model_sr_s: "Anime4K: Upscale CNN S"
        case .model_sr_ul: "Anime4K: Upscale CNN UL"
        case .model_sr_vl: "Anime4K: Upscale CNN VL"
        case .model_sr_l_gan: "Anime4K: Upscale GAN L"
        case .model_sr_m_gan: "Anime4K: Upscale GAN M"
        case .model_sr_s_gan: "Anime4K: Upscale GAN S"
        case .model_sr_ul_gan: "Anime4K: Upscale GAN UL"
        case .model_sr_vl_gan: "Anime4K: Upscale GAN UL"
        case .model_sr_uul_gan: "Anime4K: Upscale GAN UUL"
        case .perset2x_a_fast: "Anime4K: Mode A (Fast) 2x"
        case .perset2x_a_hq: "Anime4K: Mode A (HQ) 2x"
        case .perset2x_b_fast: "Anime4K: Mode B (Fast) 2x"
        case .perset2x_b_hq: "Anime4K: Mode B (HQ) 2x"
        case .perset2x_c_fast: "Anime4K: Mode C (Fast) 2x"
        case .perset2x_c_hq: "Anime4K: Mode C (HQ) 2x"
        case .perset2x_a_a_fast: "Anime4K: Mode A+A (Fast) 2x"
        case .perset2x_a_a_hq: "Anime4K: Mode A+A (HQ) 2x"
        case .perset2x_b_b_fast: "Anime4K: Mode B+B (Fast) 2x"
        case .perset2x_b_b_hq: "Anime4K: Mode B+B (HQ) 2x"
        case .perset2x_c_a_fast: "Anime4K: Mode C+A (Fast) 2x"
        case .perset2x_c_a_hq: "Anime4K: Mode C+A (HQ) 2x"
        case .perset4x_a_fast: "Anime4K: Mode A (Fast) 4x"
        case .perset4x_a_hq: "Anime4K: Mode A (HQ) 4x"
        case .perset4x_b_fast: "Anime4K: Mode B (Fast) 4x"
        case .perset4x_b_hq: "Anime4K: Mode B (HQ) 4x"
        case .perset4x_c_fast: "Anime4K: Mode C (Fast) 4x"
        case .perset4x_c_hq: "Anime4K: Mode C (HQ) 4x"
        case .perset4x_a_a_fast: "Anime4K: Mode A+A (Fast) 4x"
        case .perset4x_a_a_hq: "Anime4K: Mode A+A (HQ) 4x"
        case .perset4x_b_b_fast: "Anime4K: Mode B+B (Fast) 4x"
        case .perset4x_b_b_hq: "Anime4K: Mode B+B (HQ) 4x"
        case .perset4x_c_a_fast: "Anime4K: Mode C+A (Fast) 4x"
        case .perset4x_c_a_hq: "Anime4K: Mode C+A (HQ) 4x"
        }
    }

    public var outScale: Int {
        switch self {
        case .model_restore_l, .model_restore_m, .model_restore_s, .model_restore_ul, .model_restore_vl,
             .model_restore_soft_l, .model_restore_soft_m, .model_restore_soft_s, .model_restore_soft_ul, .model_restore_soft_vl:
            1
        case .model_sr_denoise_l, .model_sr_denoise_m, .model_sr_denoise_s, .model_sr_denoise_ul, .model_sr_denoise_vl,
             .model_sr_l, .model_sr_m, .model_sr_s, .model_sr_ul, .model_sr_vl, .model_sr_m_gan, .model_sr_s_gan,
             .perset2x_a_fast, .perset2x_a_hq, .perset2x_b_fast, .perset2x_b_hq, .perset2x_c_fast, .perset2x_c_hq,
             .perset2x_a_a_fast, .perset2x_a_a_hq, .perset2x_b_b_fast, .perset2x_b_b_hq, .perset2x_c_a_fast, .perset2x_c_a_hq:
            2
        case .model_sr_l_gan, .model_sr_vl_gan:
            3
        case .model_sr_ul_gan, .model_sr_uul_gan,
             .perset4x_a_fast, .perset4x_a_hq, .perset4x_b_fast, .perset4x_b_hq, .perset4x_c_fast, .perset4x_c_hq,
             .perset4x_a_a_fast, .perset4x_a_a_hq, .perset4x_b_b_fast, .perset4x_b_b_hq, .perset4x_c_a_fast, .perset4x_c_a_hq:
            4
        }
    }

    public var inputShape: [Int] { [1, 3, 128, 128] }
    public var shrinkSize: Int { 10 }
    public var blockSize: Int { 108 }
    public var shrinkAfterHandled: Bool { true }
    public var mainInputName: String { "input_MAIN" }
    public var mainOutputName: String { "Identity" }
    public var mainModel: MLModel {
        let assetPath = Bundle.module.url(forResource: rawValue, withExtension: "mlmodelc")
        // Loading embedded models should not result in errors
        return try! MLModel(contentsOf: assetPath!)
    }
}

public extension Waifu2x {
    init(anime4k model: Anime4kModel, batchSize: Int = 10) {
        self.init(model, batchSize: batchSize)
    }
}
