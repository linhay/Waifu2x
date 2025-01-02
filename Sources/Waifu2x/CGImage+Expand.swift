//
//  CGImage+Expand.swift
//  Waifu2x
//
//  Created by xieyi on 2017/9/14.
//  Copyright © 2017 xieyi. All rights reserved.
//
//  Modify by vuhe on 2024/12/25.
//  Copyright © 2024 vuhe. All rights reserved.
//

import CoreImage

extension CGImage {
    /// Expand the original image by shrink_size and store rgb in float array.
    /// The model will shrink the input image by 7 px.
    ///
    /// - Returns: Float array of rgb values
    func expand(shrink_size: Int, clip_eta8: Float) async -> [Float] {
        let rect = NSRect(origin: .zero, size: CGSize(width: width, height: height))

        // Redraw image in 32-bit RGBA
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        data.initialize(repeating: 0, count: width * height * 4)
        defer { data.deallocate() }
        let context = CGContext(
            data: data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 4 * width,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
        )
        context?.draw(self, in: rect)

        let width = width
        let height = height
        let exwidth = width + 2 * shrink_size
        let exheight = height + 2 * shrink_size
        let expandedSize = exwidth * exheight

        // Create the result array
        let resultPtr = UnsafeMutablePointer<Float>.allocate(capacity: 3 * expandedSize)
        resultPtr.initialize(repeating: 0, count: 3 * expandedSize)
        defer { resultPtr.deallocate() }

        await withTaskGroup(of: Void.self) { it in
            it.addTask {
                // http://www.jianshu.com/p/516f01fed6e4
                for y in 0 ..< height {
                    for x in 0 ..< width {
                        let xx = x + shrink_size
                        let yy = y + shrink_size
                        let pixel = (width * y + x) * 4
                        let r = data[pixel]
                        let g = data[pixel + 1]
                        let b = data[pixel + 2]
                        // !!! rgb values are from 0 to 1
                        // https://github.com/chungexcy/waifu2x-new/blob/master/image_test.py
                        let fr = Float(r) / 255 + clip_eta8
                        let fg = Float(g) / 255 + clip_eta8
                        let fb = Float(b) / 255 + clip_eta8

                        resultPtr[yy * exwidth + xx] = fr
                        resultPtr[yy * exwidth + xx + exwidth * exheight] = fg
                        resultPtr[yy * exwidth + xx + exwidth * exheight * 2] = fb
                    }
                }
            }
            it.addTask {
                // Top-left corner
                let pixel = 0
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                for y in 0 ..< shrink_size {
                    for x in 0 ..< shrink_size {
                        resultPtr[y * exwidth + x] = fr
                        resultPtr[y * exwidth + x + exwidth * exheight] = fg
                        resultPtr[y * exwidth + x + exwidth * exheight * 2] = fb
                    }
                }
            }
            it.addTask {
                // Top-right corner
                let pixel = (width - 1) * 4
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                for y in 0 ..< shrink_size {
                    for x in width + shrink_size ..< width + 2 * shrink_size {
                        resultPtr[y * exwidth + x] = fr
                        resultPtr[y * exwidth + x + exwidth * exheight] = fg
                        resultPtr[y * exwidth + x + exwidth * exheight * 2] = fb
                    }
                }
            }
            it.addTask {
                // Bottom-left corner
                let pixel = (width * (height - 1)) * 4
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                for y in height + shrink_size ..< height + 2 * shrink_size {
                    for x in 0 ..< shrink_size {
                        resultPtr[y * exwidth + x] = fr
                        resultPtr[y * exwidth + x + exwidth * exheight] = fg
                        resultPtr[y * exwidth + x + exwidth * exheight * 2] = fb
                    }
                }
            }
            it.addTask {
                // Bottom-right corner
                let pixel = (width * (height - 1) + (width - 1)) * 4
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                for y in height + shrink_size ..< height + 2 * shrink_size {
                    for x in width + shrink_size ..< width + 2 * shrink_size {
                        resultPtr[y * exwidth + x] = fr
                        resultPtr[y * exwidth + x + exwidth * exheight] = fg
                        resultPtr[y * exwidth + x + exwidth * exheight * 2] = fb
                    }
                }
            }
            // Top & bottom bar
            for xIdx in 0 ..< width {
                let x = xIdx
                it.addTask {
                    let pixel = x * 4
                    let r = data[pixel]
                    let g = data[pixel + 1]
                    let b = data[pixel + 2]
                    let fr = Float(r) / 255
                    let fg = Float(g) / 255
                    let fb = Float(b) / 255
                    let xx = x + shrink_size
                    for y in 0 ..< shrink_size {
                        resultPtr[y * exwidth + xx] = fr
                        resultPtr[y * exwidth + xx + exwidth * exheight] = fg
                        resultPtr[y * exwidth + xx + exwidth * exheight * 2] = fb
                    }
                }
                it.addTask {
                    let pixel = (width * (height - 1) + x) * 4
                    let r = data[pixel]
                    let g = data[pixel + 1]
                    let b = data[pixel + 2]
                    let fr = Float(r) / 255
                    let fg = Float(g) / 255
                    let fb = Float(b) / 255
                    let xx = x + shrink_size
                    for y in height + shrink_size ..< height + 2 * shrink_size {
                        resultPtr[y * exwidth + xx] = fr
                        resultPtr[y * exwidth + xx + exwidth * exheight] = fg
                        resultPtr[y * exwidth + xx + exwidth * exheight * 2] = fb
                    }
                }
            }
            // Left & right bar
            for yIdx in 0 ..< height {
                let y = yIdx
                it.addTask {
                    let pixel = (width * y) * 4
                    let r = data[pixel]
                    let g = data[pixel + 1]
                    let b = data[pixel + 2]
                    let fr = Float(r) / 255
                    let fg = Float(g) / 255
                    let fb = Float(b) / 255
                    let yy = y + shrink_size
                    for x in 0 ..< shrink_size {
                        resultPtr[yy * exwidth + x] = fr
                        resultPtr[yy * exwidth + x + exwidth * exheight] = fg
                        resultPtr[yy * exwidth + x + exwidth * exheight * 2] = fb
                    }
                }
                it.addTask {
                    let pixel = (width * y + (width - 1)) * 4
                    let r = data[pixel]
                    let g = data[pixel + 1]
                    let b = data[pixel + 2]
                    let fr = Float(r) / 255
                    let fg = Float(g) / 255
                    let fb = Float(b) / 255
                    let yy = y + shrink_size
                    for x in width + shrink_size ..< width + 2 * shrink_size {
                        resultPtr[yy * exwidth + x] = fr
                        resultPtr[yy * exwidth + x + exwidth * exheight] = fg
                        resultPtr[yy * exwidth + x + exwidth * exheight * 2] = fb
                    }
                }
            }
        }

        // Convert the result back to an array
        return Array(UnsafeBufferPointer(start: resultPtr, count: 3 * expandedSize))
    }
}
