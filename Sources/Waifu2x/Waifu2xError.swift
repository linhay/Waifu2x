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

    public var errorDescription: String? {
        switch self {
        case .getCGImageFailed: "Failed to get CGImage from NSImage"
        case .expandImageFailed: "Failed to expand image when image is too small"
        case .metalNotAvailable: "Metal not available on your device"
        }
    }
}
