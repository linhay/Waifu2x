//
//  CGImage+Crop.swift
//  Waifu2x
//
//  Created by xieyi on 2020/3/7.
//  Copyright © 2020 xieyi. All rights reserved.
//
//  Modify by vuhe on 2024/12/25.
//  Copyright © 2024 vuhe. All rights reserved.
//

import CoreGraphics

extension CGImage {
    func getCropRects(_ blockSize: Int) -> [CGRect] {
        let numW = width / blockSize
        let numH = height / blockSize
        let exW = width % blockSize
        let exH = height % blockSize
        var rects: [CGRect] = []
        for i in 0 ..< numW {
            for j in 0 ..< numH {
                let x = i * blockSize
                let y = j * blockSize
                let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)
                rects.append(rect)
            }
        }
        if exW > 0 {
            let x = width - blockSize
            for i in 0 ..< numH {
                let y = i * blockSize
                let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)
                rects.append(rect)
            }
        }
        if exH > 0 {
            let y = height - blockSize
            for i in 0 ..< numW {
                let x = i * blockSize
                let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)
                rects.append(rect)
            }
        }
        if exW > 0, exH > 0 {
            let x = width - blockSize
            let y = height - blockSize
            let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)
            rects.append(rect)
        }
        return rects
    }
}
