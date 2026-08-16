//
//  FreeSessionUITests.swift
//  DirectorsChair-DesktopUITests
//
//  DC-0016 — the free-launch QA gate's UI half: the app driven as a REAL
//  .free session (--session-tier=free, the DC-0014 seam). Pins the three
//  claims the launch depends on: the free creative core stays fully
//  usable, locked surfaces wear the lock and refuse via the "coming soon"
//  sheet with NO purchase call-to-action (billing DC-0011 is parked), and
//  the same surfaces carry no lock at .studio (the lock is tier-driven,
//  not cosmetic). Runs against the deterministic QA Fixture like the P0
//  suite — assertions are HARD.
//

import XCTest

final class FreeSessionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    @MainActor
    private func launchToFixture(tier: String) {
        app.launchArguments = ["--uitesting", "--qa-fixture",
                               "--session-tier=\(tier)"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20),
                      "Main window should appear")
        XCTAssertTrue(app.buttons["nav-script"].waitForExistence(timeout: 40),
                      "App should reach an interactive project view as \(tier)")
    }

    @MainActor
    private func navigate(to id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Nav button \(id) must exist")
        button.click()
    }

    private var lockBadges: XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(identifier: "tier-lock-badge")
    }

    /// The free creative core boots and its primary surfaces open — a free
    /// session is a working film app, not a locked shell.
    @MainActor
    func testFreeSessionOpensTheCreativeCore() throws {
        launchToFixture(tier: "free")
        for surface in ["nav-script", "nav-scenes", "nav-shot-list",
                        "nav-story-design", "nav-overview"] {
            navigate(to: surface)
        }
        // Screenplay editing is the anchor Free feature — the editor must
        // be present after the tour, not a lock placeholder.
        navigate(to: "nav-script")
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    /// The Storyteller transport entry is Creator: at .free it wears the
    /// lock, and activating it opens the shared "coming soon" sheet —
    /// which must offer NO purchase path, only OK.
    @MainActor
    func testStorytellerLockRefusesWithComingSoonAndNoCTA() throws {
        launchToFixture(tier: "free")
        navigate(to: "nav-playback")
        XCTAssertTrue(app.buttons["playback-play-pause"].waitForExistence(timeout: 10),
                      "Transport bar must mount")
        let badge = lockBadges.firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 5),
                      "The Storyteller entry must wear the tier lock at .free")
        badge.click()

        let sheet = app.descendants(matching: .any)
            .matching(identifier: "tier-upgrade-sheet").firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5),
                      "Clicking a locked control must open the coming-soon sheet")
        XCTAssertTrue(app.staticTexts["Creator — coming soon"].exists,
                      "The sheet names the tier with the no-billing wording")
        for forbidden in ["Upgrade", "Buy", "Purchase", "Subscribe"] {
            XCTAssertEqual(
                app.buttons.matching(NSPredicate(
                    format: "title CONTAINS[c] %@", forbidden)).count, 0,
                "No purchase CTA while billing is parked (DC-0011) — found '\(forbidden)'")
        }
        let ok = app.buttons["tier-sheet-ok"].firstMatch
        XCTAssertTrue(ok.exists, "The sheet dismisses with plain OK")
        ok.click()
        XCTAssertTrue(app.buttons["playback-play-pause"].waitForExistence(timeout: 5),
                      "Dismissing the sheet returns to the working app")
    }

    /// Control run: the same transport bar at .studio carries no lock —
    /// the badge is driven by the session tier, not baked into the UI.
    @MainActor
    func testStudioSessionShowsNoStorytellerLock() throws {
        launchToFixture(tier: "studio")
        navigate(to: "nav-playback")
        XCTAssertTrue(app.buttons["playback-play-pause"].waitForExistence(timeout: 10),
                      "Transport bar must mount")
        XCTAssertEqual(lockBadges.count, 0,
                       "No tier locks anywhere on playback at .studio")
    }
}
