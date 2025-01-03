//
//  CGImage+Alpha.swift
//  Waifu2x
//
//  Created by vuhe on 2024/12/31.
//  Copyright © 2024 vuhe. All rights reserved.
//

import CoreGraphics

extension CGImage {
    // For images with more than 8 bits per component, extracting alpha only produces incomplete image
    private func alphaTyped<T>(bits: Int, zero: T) -> [T] {
        var data = [T](repeating: zero, count: width * height * 4)
        data.withUnsafeMutableBufferPointer { buffer in
            let alphaOnly = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: bits, bytesPerRow: width * 4 * bits / 8,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            alphaOnly?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return data
    }

    private func alphaNonTyped(_ data: inout [UInt8]) {
        data.withUnsafeMutableBufferPointer { buffer in
            let alphaOnly = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
            )
            alphaOnly?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func alphaUInt8Array() throws -> [UInt8] {
        #if DEBUG_MODE
            print("Bits per component: \(bitsPerComponent)")
        #endif

        var data = [UInt8](repeating: 0, count: width * height)
        switch bitsPerComponent {
        case 8:
            alphaNonTyped(&data)
        case 16:
            let typed = alphaTyped(bits: 16, zero: 0)
            for i in 0 ..< data.count {
                data[i] = UInt8(typed[i * 4 + 3] >> 8)
            }
        case 32:
            let typed = alphaTyped(bits: 32, zero: 0)
            for i in 0 ..< data.count {
                data[i] = UInt8(typed[i * 4 + 3] >> 24)
            }
        default:
            throw Waifu2xError.unsupportedAlphaBits(bitsPerComponent)
        }
        return data
    }
}
