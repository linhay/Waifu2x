import Cocoa
import Testing

#if DEBUG
    @testable import Waifu2x
#else
    import Waifu2x
#endif

@Test func testModel() async throws {
    let url = Bundle.module.url(forResource: "white", withExtension: "png")!
    let waifu2x = Waifu2x(model: Waifu2xModel.anime_noise3_scale2x)
    let startTime = CFAbsoluteTimeGetCurrent()
    let output = try! await waifu2x.run(Data(contentsOf: url))
    let endTime = CFAbsoluteTimeGetCurrent()
    print("waifu2x handled \(endTime - startTime) sec")
}

@Test func testAllModels() async throws {
    await withTaskGroup(of: Void.self) { group in
        let url = Bundle.module.url(forResource: "white", withExtension: "png")!
        for model in Waifu2xModel.allCases {
            group.addTask {
                let startTime = CFAbsoluteTimeGetCurrent()
                let waifu2x = Waifu2x(model: model)
                _ = try! await waifu2x.run(Data(contentsOf: url))
                let endTime = CFAbsoluteTimeGetCurrent()
                print("\(model) handled \(endTime - startTime) sec")
            }
        }
    }
}

@Test func testGCD() throws {
    let group = DispatchGroup()
    group.enter()
    Task {
        let url = Bundle.module.url(forResource: "white", withExtension: "png")!
        let waifu2x = Waifu2x(model: Waifu2xModel.photo_noise2_scale2x)
        _ = try! await waifu2x.run(Data(contentsOf: url))
        group.leave()
    }
    group.wait()
}
