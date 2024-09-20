import Cocoa
import Testing
@testable import Waifu2x

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }

    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) throws {
        try pngData?.write(to: url, options: options)
    }
}

@Test func testModel() async throws {
    let bundle = Bundle.module
    let path = bundle.path(forResource: "white", ofType: "png")!
    let data = NSData(contentsOfFile: path)
    let image = NSImage(data: data! as Data)!
    let waifu2x = Waifu2x(model: Waifu2xModel.photo_noise2_scale2x)
    assert(waifu2x.run(image) != nil)
}

@Test func testAllModels() async throws {
    let bundle = Bundle.module
    let path = bundle.path(forResource: "white", ofType: "png")!
    let data = NSData(contentsOfFile: path)
    let image = NSImage(data: data! as Data)!
    for model in Waifu2xModel.allCases {
        print(model)
        let waifu2x = Waifu2x(model: model)
        assert(waifu2x.run(image) != nil)
    }
}

@Test func testAllModelsAsync() async throws {
    await withTaskGroup(of: Void.self) { group in
        for model in Waifu2xModel.allCases {
            group.addTask {
                let bundle = Bundle.module
                let path = bundle.path(forResource: "white", ofType: "png")!
                let data = NSData(contentsOfFile: path)
                let image = NSImage(data: data! as Data)!
                print(model)
                let waifu2x = Waifu2x(model: model)
                assert(waifu2x.run(image) != nil)
            }
        }
    }
}
