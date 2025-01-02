import Cocoa
import Testing
@testable import Waifu2x

@Test func testModel() async throws {
    let bundle = Bundle.module
    let path = bundle.path(forResource: "white", ofType: "png")!
    let data = NSData(contentsOfFile: path)
    let waifu2x = Waifu2x(model: Waifu2xModel.anime_noise3_scale2x)
    let startTime = CFAbsoluteTimeGetCurrent()
    _ = try! await waifu2x.run(data! as Data)
    let endTime = CFAbsoluteTimeGetCurrent()
    print("waifu2x handled \(endTime - startTime) sec")
}

@Test func testAllModels() async throws {
    await withTaskGroup(of: Void.self) { group in
        for model in Waifu2xModel.allCases {
            group.addTask {
                print(model)
                let bundle = Bundle.module
                let path = bundle.path(forResource: "white", ofType: "png")!
                let data = NSData(contentsOfFile: path)
                let waifu2x = Waifu2x(model: model)
                _ = try! await waifu2x.run(data! as Data)
            }
        }
    }
}

@Test func testGCD() throws {
    let group = DispatchGroup()
    group.enter()
    Task {
        let bundle = Bundle.module
        let path = bundle.path(forResource: "white", ofType: "png")!
        let data = NSData(contentsOfFile: path)
        let waifu2x = Waifu2x(model: Waifu2xModel.photo_noise2_scale2x)
        _ = try! await waifu2x.run(data! as Data)
        group.leave()
    }
    group.wait()
}
