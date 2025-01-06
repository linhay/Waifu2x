//
//  Models.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/6.
//  Copyright © 2025 vuhe. All rights reserved.
//

import CoreML
import Waifu2xCore
import ZIPFoundation

// manifest.json 的结构
private struct Waifu2xModelManifest: Decodable {
    let version: Int
    let name: String
    let type: ModelType
    let subModels: [String: ModelInfo]
    let dataFormat: DataFormat
    let inputShape: [Int]
    let shrinkSize: Int
    let scale: Int
    let alphaMode: AlphaMode

    var outputBlockSize: Int {
        get throws {
            guard (dataFormat == .chw && inputShape.count == 3) ||
                (dataFormat == .nchw && inputShape.count == 4)
            else { throw Waifu2xError.loadModelFailed("dataFormat and inputShape unmatch") }
            guard inputShape[inputShape.count - 2] == inputShape[inputShape.count - 1]
            else { throw Waifu2xError.loadModelFailed("inputShape width and height must be equal") }
            guard inputShape[inputShape.count - 3] == 3
            else { throw Waifu2xError.loadModelFailed("only supported RGB input model") }
            if dataFormat == .nchw {
                guard inputShape[0] == 1
                else { throw Waifu2xError.loadModelFailed("only supported 1 batch input model") }
            }
            return inputShape.last! - shrinkSize * 2
        }
    }

    enum ModelType: String, Decodable {
        case coreml
    }

    enum DataFormat: String, Codable {
        case nchw
        case chw
    }

    enum AlphaMode: String, Codable {
        case sameAsMain
        case separateModel
    }

    struct ModelInfo: Decodable {
        let file: String
        let inputName: String
        let outputName: String
    }
}

public struct WifmModel: Waifu2xModelInfo, @unchecked Sendable {
    public let name: String
    public let inputShape: [Int]
    public let shrinkSize, outScale, blockSize: Int
    public let mainModel: MLModel
    public let mainInputName, mainOutputName: String

    init(file: URL) async throws {
        // 解压整个文件到临时目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.unzipItem(at: file, to: tempDir)

        // 读取并解析 manifest.json
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Waifu2xModelManifest.self, from: manifestData)
        name = manifest.name
        inputShape = manifest.inputShape
        shrinkSize = manifest.shrinkSize
        outScale = manifest.scale
        blockSize = try manifest.outputBlockSize

        // 验证版本和类型
        guard manifest.version == 1
        else { throw Waifu2xError.loadModelFailed("unsupported \(manifest.version) wifm version") }
        guard let mainModelInfo = manifest.subModels["main"]
        else { throw Waifu2xError.loadModelFailed("manifest missing main model") }

        // 加载模型
        let mainModelURL = tempDir.appendingPathComponent(mainModelInfo.file)
        let compiledMainModelURL = try await MLModel.compileModel(at: mainModelURL)
        mainModel = try MLModel(contentsOf: compiledMainModelURL)
        mainInputName = mainModelInfo.inputName
        mainOutputName = mainModelInfo.outputName
    }
}

public extension Waifu2x {
    init(wifm file: URL, batchSize: Int = 10) async throws {
        try await self.init(WifmModel(file: file), batchSize: batchSize)
    }
}
