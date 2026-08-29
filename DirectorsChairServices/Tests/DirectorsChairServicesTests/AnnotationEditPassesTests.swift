import XCTest
@testable import DirectorsChairCore
@testable import DirectorsChairServices

/// DC-0075: on-device, several pins are several passes — each pin's circle
/// with that pin's instruction alone, chained through the previous pass's
/// picture — so every change lands where it was marked.
final class AnnotationEditPassesTests: XCTestCase {
    private let source = Data("source".utf8)
    private var engine: ScriptedStoryboardEngine!
    private var previous: (any StoryboardEngine)!

    override func setUp() {
        super.setUp()
        engine = ScriptedStoryboardEngine()
        previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = engine
    }

    override func tearDown() {
        AIServiceClient.onDeviceImageEngine = previous
        super.tearDown()
    }

    func testEachPinBecomesItsOwnPassChainedThroughThePreviousPicture() async throws {
        let first = Data("after-1".utf8), second = Data("after-2".utf8)
        engine.queueResults([first, second])
        let edit = AnnotationEdit(source: source, pins: [
            AnnotationPin(x: 0.7, y: 0.6, text: "a brass lantern on the table", number: 2, radius: 0.3),
            AnnotationPin(x: 0.43, y: 0.15, text: "remove the speech bubble", number: 1),
        ], context: "scene preview", originalPrompt: "Cinematic film still, porch at dusk")

        let result = try await AIServiceClient.shared.editImage(edit, provider: .onDevice)

        XCTAssertEqual(result, second, "the last pass's picture is the result")
        XCTAssertEqual(engine.requests.count, 2, "one pass per pin")
        let pass1 = engine.requests[0], pass2 = engine.requests[1]
        XCTAssertEqual(pass1.references, [source]); XCTAssertEqual(pass2.references, [first], "each pass repaints the previous pass's picture")
        XCTAssertEqual(pass1.editRegions, [EditRegion(x: 0.43, y: 0.15)], "pin 1 first, its circle alone")
        XCTAssertEqual(pass2.editRegions, [EditRegion(x: 0.7, y: 0.6, radius: 0.3)])
        XCTAssertEqual(pass1.subject, "1. remove the speech bubble")
        XCTAssertEqual(pass2.subject, "2. a brass lantern on the table")
        XCTAssertEqual(pass1.purpose, .edit); XCTAssertEqual(pass2.purpose, .edit)
        XCTAssertFalse(pass1.subject.contains("Original prompt"), "the on-device passes never see the cloud context")
    }

    func testASinglePinIsStillASingleRequest() async throws {
        engine.queueResults([Data("after".utf8)])
        let edit = AnnotationEdit(source: source, pins: [AnnotationPin(x: 0.5, y: 0.5, text: "wider hat", number: 1)], context: "keyframe")
        let result = try await AIServiceClient.shared.editImage(edit, provider: .onDevice)
        XCTAssertEqual(result, Data("after".utf8))
        XCTAssertEqual(engine.requests.count, 1)
        XCTAssertEqual(engine.requests[0].references, [source])
    }

    func testAFailedPassStopsTheChain() async {
        engine.queueResults([Data("after-1".utf8)])
        engine.setAvailability(.needsDownload(expectedBytes: 1))
        let edit = AnnotationEdit(source: source, pins: [
            AnnotationPin(x: 0.2, y: 0.2, text: "a", number: 1), AnnotationPin(x: 0.8, y: 0.8, text: "b", number: 2)], context: "image")
        do {
            _ = try await AIServiceClient.shared.editImage(edit, provider: .onDevice)
            XCTFail("an unavailable engine must fail the edit")
        } catch {
            XCTAssertEqual(engine.requests.count, 1, "no second pass after a failure")
        }
    }
}
