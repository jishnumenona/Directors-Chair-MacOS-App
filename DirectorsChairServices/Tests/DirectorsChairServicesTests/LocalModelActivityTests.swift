import XCTest
@testable import DirectorsChairServices

/// The App Nap guard around local-model jobs (DC-0071): the body runs
/// inside a declared user-initiated activity and its result and errors
/// pass through unchanged.
final class LocalModelActivityTests: XCTestCase {
    struct Boom: Error {}

    func testPerformReturnsTheBodyValue() async throws {
        let value = await LocalModelActivity.perform("test") { 42 }
        XCTAssertEqual(value, 42)
    }

    func testPerformRethrowsTheBodyError() async {
        do {
            _ = try await LocalModelActivity.perform("test") { () throws -> Int in throw Boom() }
            XCTFail("expected the body's error")
        } catch {
            XCTAssertTrue(error is Boom)
        }
    }

    func testActivityOptionsKeepAppNapOffAndTheMachineAwake() {
        XCTAssertTrue(LocalModelActivity.options.contains(.userInitiated), "user-initiated is what stands App Nap down")
        XCTAssertTrue(LocalModelActivity.options.contains(.idleSystemSleepDisabled))
        XCTAssertFalse(LocalModelActivity.options.contains(.idleDisplaySleepDisabled), "a render must not keep the display lit")
    }
}
