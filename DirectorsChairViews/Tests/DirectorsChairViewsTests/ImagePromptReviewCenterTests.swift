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

    /// The ask lands on the main actor whenever the scheduler gets to it —
    /// under a full-suite backlog that can be late, so the wait is a real
    /// deadline that FAILS, never a fixed yield count that traps or wedges
    /// (this test hung two full verify runs on 2026-08-30).
    private func pendingReview(in center: ImagePromptReviewCenter,
                               seconds: Double = 5) async throws -> PendingImagePromptReview {
        let start = Date()
        while center.pending == nil {
            if Date().timeIntervalSince(start) > seconds {
                XCTFail("no review surfaced within \(seconds)s")
                throw XCTestError(.timeoutWhileWaiting)
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        return center.pending!
    }

    func testPresentsThenResumesWithTheDecision() async throws {
        UserDefaults.standard.set(true, forKey: key)
        let center = ImagePromptReviewCenter()
        let task = Task { await center.review(ImageGenerationRequest(prompt: "a road")) }
        let pending = try await pendingReview(in: center)
        var edited = pending.request
        edited.prompt = "a road at dusk"
        center.resolve(pending, with: edited)
        let out = await task.value
        XCTAssertEqual(out?.prompt, "a road at dusk")
        XCTAssertNil(center.pending)
    }

    func testCancelReturnsNilAndTheQueueAdvances() async throws {
        UserDefaults.standard.set(true, forKey: key)
        let center = ImagePromptReviewCenter()
        let first = Task { await center.review(ImageGenerationRequest(prompt: "one")) }
        let second = Task { await center.review(ImageGenerationRequest(prompt: "two")) }
        // The two asks land in EITHER order — cancel whichever surfaced
        // first, send the other, and assert the outcome as a set. Awaiting
        // a specific task's value between the resolves could face the wrong
        // order and wedge the whole suite (seen 2026-08-30).
        let a = try await pendingReview(in: center)
        center.resolve(a, with: nil)
        let b = try await pendingReview(in: center)
        XCTAssertNotEqual(a.request.prompt, b.request.prompt)
        center.resolve(b, with: b.request)
        let firstOut = await first.value
        let secondOut = await second.value
        let outcomes = [firstOut, secondOut]
        XCTAssertEqual(outcomes.compactMap { $0 }.count, 1, "exactly one sent: \(outcomes)")
        XCTAssertTrue(outcomes.contains(where: { $0 == nil }), "exactly one cancelled: \(outcomes)")
        XCTAssertNil(center.pending)
    }
}
