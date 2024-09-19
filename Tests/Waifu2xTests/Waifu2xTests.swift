import Testing
import Cocoa
@testable import Waifu2x

@Test func testAllModels() async throws {
    let bundle = Bundle.module
    let path = bundle.path(forResource: "white", ofType: "png")!
    let data = NSData(contentsOfFile: path)
    let image = NSImage(data: data! as Data)!
    for model in Model.all {
        print(model)
        assert(Waifu2x.run(image, model: model) != nil)
    }
}
