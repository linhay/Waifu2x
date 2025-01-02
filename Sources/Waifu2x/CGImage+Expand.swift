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
    func expand(shrink_size: Int, clip_eta8: Float) -> [Float] {
        let width = width
        let height = height
        let rect = CGRect(origin: .zero, size: CGSize(width: width, height: height))

        // Redraw image in 32-bit RGBA
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 4 * width,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
            )
            context?.draw(self, in: rect)
        }

        let exwidth = width + 2 * shrink_size
        let exheight = height + 2 * shrink_size
        let expandedSize = exwidth * exheight
        var result = [Float](repeating: 0, count: 3 * expandedSize)

        var xx, yy, pixel: Int
        var r, g, b: UInt8
        var fr, fg, fb: Float

        // http://www.jianshu.com/p/516f01fed6e4
        for y in 0 ..< height {
            for x in 0 ..< width {
                xx = x + shrink_size
                yy = y + shrink_size
                pixel = (width * y + x) * 4
                r = data[pixel]
                g = data[pixel + 1]
                b = data[pixel + 2]
                // !!! rgb values are from 0 to 1
                // https://github.com/chungexcy/waifu2x-new/blob/master/image_test.py
                fr = Float(r) / 255 + clip_eta8
                fg = Float(g) / 255 + clip_eta8
                fb = Float(b) / 255 + clip_eta8

                result[yy * exwidth + xx] = fr
                result[yy * exwidth + xx + exwidth * exheight] = fg
                result[yy * exwidth + xx + exwidth * exheight * 2] = fb
            }
        }

        // Top-left corner
        pixel = 0
        r = data[pixel]
        g = data[pixel + 1]
        b = data[pixel + 2]
        fr = Float(r) / 255
        fg = Float(g) / 255
        fb = Float(b) / 255
        for y in 0 ..< shrink_size {
            for x in 0 ..< shrink_size {
                result[y * exwidth + x] = fr
                result[y * exwidth + x + exwidth * exheight] = fg
                result[y * exwidth + x + exwidth * exheight * 2] = fb
            }
        }

        // Top-right corner
        pixel = (width - 1) * 4
        r = data[pixel]
        g = data[pixel + 1]
        b = data[pixel + 2]
        fr = Float(r) / 255
        fg = Float(g) / 255
        fb = Float(b) / 255
        for y in 0 ..< shrink_size {
            for x in width + shrink_size ..< width + 2 * shrink_size {
                result[y * exwidth + x] = fr
                result[y * exwidth + x + exwidth * exheight] = fg
                result[y * exwidth + x + exwidth * exheight * 2] = fb
            }
        }

        // Bottom-left corner
        pixel = (width * (height - 1)) * 4
        r = data[pixel]
        g = data[pixel + 1]
        b = data[pixel + 2]
        fr = Float(r) / 255
        fg = Float(g) / 255
        fb = Float(b) / 255
        for y in height + shrink_size ..< height + 2 * shrink_size {
            for x in 0 ..< shrink_size {
                result[y * exwidth + x] = fr
                result[y * exwidth + x + exwidth * exheight] = fg
                result[y * exwidth + x + exwidth * exheight * 2] = fb
            }
        }

        // Bottom-right corner
        pixel = (width * (height - 1) + (width - 1)) * 4
        r = data[pixel]
        g = data[pixel + 1]
        b = data[pixel + 2]
        fr = Float(r) / 255
        fg = Float(g) / 255
        fb = Float(b) / 255
        for y in height + shrink_size ..< height + 2 * shrink_size {
            for x in width + shrink_size ..< width + 2 * shrink_size {
                result[y * exwidth + x] = fr
                result[y * exwidth + x + exwidth * exheight] = fg
                result[y * exwidth + x + exwidth * exheight * 2] = fb
            }
        }

        // Top & bottom bar
        for x in 0 ..< width {
            pixel = x * 4
            r = data[pixel]
            g = data[pixel + 1]
            b = data[pixel + 2]
            fr = Float(r) / 255
            fg = Float(g) / 255
            fb = Float(b) / 255
            xx = x + shrink_size
            for y in 0 ..< shrink_size {
                result[y * exwidth + xx] = fr
                result[y * exwidth + xx + exwidth * exheight] = fg
                result[y * exwidth + xx + exwidth * exheight * 2] = fb
            }

            pixel = (width * (height - 1) + x) * 4
            r = data[pixel]
            g = data[pixel + 1]
            b = data[pixel + 2]
            fr = Float(r) / 255
            fg = Float(g) / 255
            fb = Float(b) / 255
            xx = x + shrink_size
            for y in height + shrink_size ..< height + 2 * shrink_size {
                result[y * exwidth + xx] = fr
                result[y * exwidth + xx + exwidth * exheight] = fg
                result[y * exwidth + xx + exwidth * exheight * 2] = fb
            }
        }

        // Left & right bar
        for y in 0 ..< height {
            pixel = (width * y) * 4
            r = data[pixel]
            g = data[pixel + 1]
            b = data[pixel + 2]
            fr = Float(r) / 255
            fg = Float(g) / 255
            fb = Float(b) / 255
            yy = y + shrink_size
            for x in 0 ..< shrink_size {
                result[yy * exwidth + x] = fr
                result[yy * exwidth + x + exwidth * exheight] = fg
                result[yy * exwidth + x + exwidth * exheight * 2] = fb
            }

            pixel = (width * y + (width - 1)) * 4
            r = data[pixel]
            g = data[pixel + 1]
            b = data[pixel + 2]
            fr = Float(r) / 255
            fg = Float(g) / 255
            fb = Float(b) / 255
            yy = y + shrink_size
            for x in width + shrink_size ..< width + 2 * shrink_size {
                result[yy * exwidth + x] = fr
                result[yy * exwidth + x + exwidth * exheight] = fg
                result[yy * exwidth + x + exwidth * exheight * 2] = fb
            }
        }

        return result
    }
}
