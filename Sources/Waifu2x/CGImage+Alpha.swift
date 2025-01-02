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
    private func alphaTyped<T>(bits: Int, zero: T) -> UnsafeMutablePointer<T> {
        let width = width
        let height = height
        let data = UnsafeMutablePointer<T>.allocate(capacity: width * height * 4)
        data.initialize(repeating: zero, count: width * height)
        let alphaOnly = CGContext(
            data: data, width: width, height: height,
            bitsPerComponent: bits, bytesPerRow: width * 4 * bits / 8,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        alphaOnly?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    private func alphaNonTyped(_ datap: UnsafeMutableRawPointer) {
        let width = width
        let height = height
        let alphaOnly = CGContext(
            data: datap, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        )
        alphaOnly?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func alphaUInt8Array() -> [UInt8] {
        let width = width
        let height = height
        let bits = bitsPerComponent
        #if DEBUG_MODE
            print("Bits per component: \(bits)")
        #endif

        var data = [UInt8](repeating: 0, count: width * height)
        if bits == 8 {
            alphaNonTyped(&data)
        } else if bits == 16 {
            let typed: UnsafeMutablePointer<UInt16> = alphaTyped(bits: 16, zero: 0)
            for i in 0 ..< data.count {
                data[i] = UInt8(typed[i * 4 + 3] >> 8)
            }
            typed.deallocate()
        } else if bits == 32 {
            let typed: UnsafeMutablePointer<UInt32> = alphaTyped(bits: 32, zero: 0)
            for i in 0 ..< data.count {
                data[i] = UInt8(typed[i * 4 + 3] >> 24)
            }
            typed.deallocate()
        }
        return data
    }
}
