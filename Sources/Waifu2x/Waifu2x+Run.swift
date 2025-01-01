//
//  Waifu2x+Run.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/1.
//

import CoreImage

public extension Waifu2x {
    func run(_ data: Data) async throws -> Waifu2xData {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgimg = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else { throw Waifu2xError.getCGImageFailed }
        return try await run(cgimg)
    }
}
