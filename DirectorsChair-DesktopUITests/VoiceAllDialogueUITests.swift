// DirectorsChair-DesktopUITests/VoiceAllDialogueUITests.swift
//
// DC-0081: the Playback transport's "Voice all dialogue" control in the
// real app — the popover shows what would be voiced and what it costs
// before anything runs, and a free session meets the Creator lock. The
// run itself is never started here: it would spend on the speech
// provider; DialogueVoicingTests covers the batch through a stub.

import XCTest

final class VoiceAllDialogueUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    @MainActor
    private func launchToPlayback(tier: String) {
        app.launchArguments = ["--uitesting", "--qa-fixture", "--session-tier=\(tier)"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20), "Main window should appear")
        XCTAssertTrue(app.buttons["nav-script"].waitForExistence(timeout: 40),
                      "App should reach an interactive project view as \(tier)")
        let nav = app.buttons["nav-playback"]
        XCTAssertTrue(nav.waitForExistence(timeout: 5), "Playback nav must exist")
        nav.click()
        XCTAssertTrue(app.buttons["playback-play-pause"].waitForExistence(timeout: 10), "Transport bar must mount")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    /// Studio session: the popover states the plan — lines, voices, the
    /// estimate — and offers a Start sized to the plan; the filter toggle
    /// re-plans. Nothing is started.
    @MainActor
    func testPopoverStatesThePlanBeforeAnythingRuns() throws {
        launchToPlayback(tier: "studio")
        let button = element("playback-voice-all")
        XCTAssertTrue(button.waitForExistence(timeout: 5), "The voice-all control is on the transport")
        button.click()

        XCTAssertTrue(element("voice-all-title").waitForExistence(timeout: 5), "The popover opens")
        let summary = element("voice-all-summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "The fixture has unvoiced dialogue to plan")
        let text = summary.value as? String ?? summary.label
        XCTAssertTrue(Self.matches(text, #"^\d+ lines? · \d+ characters? · "#),
                      "The summary names lines and voices — got: \(text)")

        let start = element("voice-all-start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isEnabled, "A plan with lines can start")
        let title = start.title.isEmpty ? start.label : start.title
        XCTAssertTrue(Self.matches(title, #"^Voice \d+ lines?$"#), "Start is sized to the plan — got: \(title)")

        // Regenerating everything plans at least as many lines.
        let before = Int(text.components(separatedBy: " ").first ?? "") ?? 0
        let toggle = element("voice-all-only-unvoiced")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()
        let after = element("voice-all-summary")
        XCTAssertTrue(after.waitForExistence(timeout: 5))
        let afterText = after.value as? String ?? after.label
        let afterCount = Int(afterText.components(separatedBy: " ").first ?? "") ?? -1
        XCTAssertGreaterThanOrEqual(afterCount, before, "regenerating includes every line — got: \(afterText)")

        // Never start: that would spend on the speech provider.
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["playback-play-pause"].waitForExistence(timeout: 5),
                      "Dismissing the popover returns to the working app")
        XCTAssertFalse(element("voice-all-cancel").exists, "no run was started")
    }

    /// Free session: the control wears the Creator lock and a click opens
    /// the coming-soon sheet instead of the popover.
    @MainActor
    func testFreeSessionMeetsTheCreatorLock() throws {
        launchToPlayback(tier: "free")
        let button = element("playback-voice-all")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        // A mouse click, not an accessibility press: the locked control is
        // not hit-testable (a press is a no-op), and the click lands on the
        // gate's catch overlay the way a real pointer does.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertFalse(element("voice-all-title").waitForExistence(timeout: 2),
                       "the popover never opens below tier")
        XCTAssertTrue(element("tier-upgrade-sheet").waitForExistence(timeout: 5),
                      "A locked control opens the coming-soon sheet")
        XCTAssertTrue(app.staticTexts["Creator — coming soon"].exists)
        app.typeKey(.return, modifierFlags: [])   // the sheet's default OK
        XCTAssertTrue(app.buttons["playback-play-pause"].waitForExistence(timeout: 5))
    }
}
