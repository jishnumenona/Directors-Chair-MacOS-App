// DC-0093: the prompt-review gate.
import XCTest
import DirectorsChairServices
@testable import DirectorsChairViews

@MainActor
final class ImagePromptReviewCenterTests: XCTestCase {
    private let key = AIProviderSelection.reviewImagePromptsKey

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func testPassesRequestsThroughUntouchedWhenTheSettingIsOff() async {
        UserDefaults.standard.set(false, forKey: key)
        let center = ImagePromptReviewCenter()
        let request = ImageGenerationRequest(prompt: "a road")
        let out = await center.review(request)
        XCTAssertEqual(out?.prompt, "a road")
        XCTAssertNil(center.pending)
    }

    func testPresentsThenResumesWithTheDecision() async {
        UserDefaults.standard.set(true, forKey: key)
        let center = ImagePromptReviewCenter()
        let task = Task { await center.review(ImageGenerationRequest(prompt: "a road")) }
        // The ask lands on the main actor; give it a turn.
        for _ in 0..<50 where center.pending == nil { await Task.yield() }
        let pending = try! XCTUnwrap(center.pending)
        var edited = pending.request
        edited.prompt = "a road at dusk"
        center.resolve(pending, with: edited)
        let out = await task.value
        XCTAssertEqual(out?.prompt, "a road at dusk")
        XCTAssertNil(center.pending)
    }

    func testCancelReturnsNilAndTheQueueAdvances() async {
        UserDefaults.standard.set(true, forKey: key)
        let center = ImagePromptReviewCenter()
        let first = Task { await center.review(ImageGenerationRequest(prompt: "one")) }
        let second = Task { await center.review(ImageGenerationRequest(prompt: "two")) }
        for _ in 0..<50 where center.pending == nil { await Task.yield() }
        let a = try! XCTUnwrap(center.pending)
        center.resolve(a, with: nil)
        let firstOut = await first.value
        XCTAssertNil(firstOut)
        for _ in 0..<50 where center.pending == nil { await Task.yield() }
        let b = try! XCTUnwrap(center.pending)
        XCTAssertNotEqual(a.request.prompt, b.request.prompt)
        center.resolve(b, with: b.request)
        let secondOut = await second.value
        XCTAssertNotNil(secondOut)
    }
}
