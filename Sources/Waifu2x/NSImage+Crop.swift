//
//  NSImage+Crop.swift
//  waifu2x-ios
//
//  Created by xieyi on 2017/9/14.
//  Copyright © 2017年 xieyi. All rights reserved.
//

import AppKit
import Foundation

public extension NSImage {
    func crop(rects: [CGRect]) -> [NSImage] {
        var result: [NSImage] = []
        for rect in rects {
            result.append(crop(rect: rect))
        }
        return result
    }

    func crop(rect _: CGRect) -> NSImage {
        var rect = NSRect(origin: .zero, size: size)
        let cgimg = cgImage(forProposedRect: &rect, context: nil, hints: nil)?.cropping(to: rect)
        return NSImage(cgImage: cgimg!, size: rect.size)
    }
}
