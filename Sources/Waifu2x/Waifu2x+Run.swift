//
//  Waifu2x+Run.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/1.
//  Copyright © 2025 vuhe. All rights reserved.
//

import CoreImage

public extension Waifu2x {
    init(model: Waifu2xModel, batchSize: Int = 10) {
        self.init(model.model, batchSize: batchSize)
    }

    func run(_ data: Data) async throws -> Waifu2xData {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgimg = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else { throw Waifu2xError.getCGImageFailed }
        return try await run(cgimg)
    }

    /// Processing method applicable to GCD.
    ///
    /// This method will block the thread. Do not call it in the Task context.
    func runAndWait(_ data: Data) throws -> Waifu2xData {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgimg = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else { throw Waifu2xError.getCGImageFailed }
        return try runAndWait(cgimg)
    }

    /// Processing method applicable to GCD.
    ///
    /// This method will block the thread. Do not call it in the Task context.
    func runAndWait(_ image: CGImage) throws -> Waifu2xData {
        var result: Result<Waifu2xData, any Error> = .failure(Waifu2xError.blockRunFailed)
        let group = DispatchGroup()
        group.enter()
        Task {
            do {
                result = try await .success(run(image))
            } catch {
                result = .failure(error)
            }
            group.leave()
        }
        group.wait()
        return try result.get()
    }
}

// MARK: - 加载自定义模型

import CoreML
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

public extension Waifu2x {
    static func loadCustom(wifmFile: URL, batchSize: Int = 10) async throws -> Waifu2x {
        // 解压整个文件到临时目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.unzipItem(at: wifmFile, to: tempDir)

        // 读取并解析 manifest.json
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Waifu2xModelManifest.self, from: manifestData)
        let name = manifest.name
        let inputShape = manifest.inputShape.map { NSNumber(value: $0) }
        let shrinkSize = manifest.shrinkSize
        let outScale = manifest.scale
        let blockSize = try manifest.outputBlockSize

        // 验证版本和类型
        guard manifest.version == 1
        else { throw Waifu2xError.loadModelFailed("unsupported \(manifest.version) wifm version") }
        guard let mainModelInfo = manifest.subModels["main"]
        else { throw Waifu2xError.loadModelFailed("manifest missing main model") }

        // 加载模型
        let mainModelURL = tempDir.appendingPathComponent(mainModelInfo.file)
        let compiledMainModelURL = try await MLModel.compileModel(at: mainModelURL)
        let mainModel = try MLModel(contentsOf: compiledMainModelURL)
        let mainInputName = mainModelInfo.inputName
        let mainOutputName = mainModelInfo.outputName

        let model = Waifu2xModelInfo(
            name: name, dataType: .interleaved, inputShape: inputShape,
            shrinkSize: shrinkSize, outScale: outScale, blockSize: blockSize,
            mainModel: mainModel, mainInputName: mainInputName, mainOutputName: mainOutputName
        )
        return Waifu2x(model, batchSize: batchSize)
    }
}
