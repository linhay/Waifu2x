//
//  Waifu2xError.swift
//  Waifu2x
//
//  Created by vuhe on 2024/9/25.
//  Copyright © 2024 vuhe. All rights reserved.
//

import Foundation

public enum Waifu2xError: LocalizedError {
    case blockRunFailed
    case getCGImageFailed
    case expandImageFailed
    case vImageScalingFailed
    case coreMLError(String)

    public var errorDescription: String? {
        switch self {
        case .blockRunFailed: "Fail to run when block the thread"
        case .getCGImageFailed: "Failed to get CGImage from Data"
        case .expandImageFailed: "Failed to expand image when image is too small"
        case .vImageScalingFailed: "Failed to scale alpha channel using vImage"
        case let .coreMLError(desc): "Core ML error: \(desc)"
        }
    }
}
