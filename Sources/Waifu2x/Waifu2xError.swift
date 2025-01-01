//
//  Waifu2xError.swift
//  Waifu2x
//
//  Created by vuhe on 2024/9/25.
//

import Foundation

public enum Waifu2xError: LocalizedError {
    case getCGImageFailed
    case expandImageFailed
    case metalNotAvailable
    case vImageConversionFailed
    case vImageScalingFailed
    case coreMLError(String)

    public var errorDescription: String? {
        switch self {
        case .getCGImageFailed: "Failed to get CGImage from NSImage"
        case .expandImageFailed: "Failed to expand image when image is too small"
        case .metalNotAvailable: "Metal not available on your device"
        case .vImageConversionFailed: "Failed to convert image format using vImage"
        case .vImageScalingFailed: "Failed to scale alpha channel using vImage"
        case let .coreMLError(desc): "Core ML error: \(desc)"
        }
    }
}
