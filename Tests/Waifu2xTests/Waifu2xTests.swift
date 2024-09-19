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

@Test func testAllModels() async throws {
    let bundle = Bundle.module
    let path = bundle.path(forResource: "white", ofType: "png")!
    let data = NSData(contentsOfFile: path)
    let image = NSImage(data: data! as Data)!
    for model in Model.allCases {
        print(model)
        let waifu2x = Waifu2x(model: model)
        assert(waifu2x.run(image) != nil)
    }
}
