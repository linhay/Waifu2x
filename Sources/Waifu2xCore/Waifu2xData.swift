//
//  Waifu2xData.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/1.
//  Copyright © 2025 vuhe. All rights reserved.
//

import CoreImage
import UniformTypeIdentifiers

public struct Waifu2xData: Sendable {
    public let cgImage: CGImage
    public let cgSize: CGSize
}

public extension Waifu2xData {
    func toJpeg(compressionQuality: CGFloat = 0.9) -> Data? {
        let type = UTType.jpeg.identifier as CFString
        guard let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, type, 1, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    func toPng() -> Data? {
        let type = UTType.png.identifier as CFString
        guard let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, type, 1, nil)
        else { return nil }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

#if os(macOS)
    import AppKit

    public extension Waifu2xData {
        var nsImage: NSImage {
            NSImage(cgImage: cgImage, size: cgSize)
        }
    }
#else
    import UIKit

    public extension Waifu2xData {
        var uiImage: UIImage {
            UIImage(cgImage: cgImage)
        }
    }
#endif
