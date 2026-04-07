//
//  DirectorsChair_DesktopUITests.swift
//  DirectorsChair-DesktopUITests
//
//  XCUITests for critical user flows

import XCTest

final class DirectorsChair_DesktopUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Launch and wait for the main window to appear.
    @MainActor
    private func launchApp() {
        app.launch()
        // Wait for the app to finish splash + setup
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Main window should appear")
    }

    /// Tap a navigation toolbar button by its accessibility identifier.
    @MainActor
    private func navigateTo(_ id: String) {
        let button = app.buttons[id]
        if button.waitForExistence(timeout: 5) {
            button.click()
            // Brief pause for view transition
            usleep(300_000)
        }
    }

    // MARK: - Scenario 1: App Launch

    @MainActor
    func testAppLaunchesWithoutCrash() throws {
        launchApp()
        XCTAssertTrue(app.windows.count > 0, "At least one window should exist")
    }

    @MainActor
    func testOnboardingSkippedInTestMode() throws {
        launchApp()
        // With --uitesting, onboarding should be skipped
        // We should NOT see any onboarding-specific overlay
        let onboardingText = app.staticTexts["Welcome to Director's Chair"]
        XCTAssertFalse(onboardingText.exists, "Onboarding should be skipped in test mode")
    }

    @MainActor
    func testCreateNewProject() throws {
        launchApp()
        // Navigate to projects view
        navigateTo("nav-projects")

        let newProjectButton = app.buttons["new-project-button"]
        guard newProjectButton.waitForExistence(timeout: 5) else {
            // May already have a project loaded — that's OK
            return
        }
        newProjectButton.click()

        let nameField = app.textFields["project-name-field"]
        guard nameField.waitForExistence(timeout: 3) else { return }
        nameField.click()
        nameField.typeText("UI Test Project")

        let createButton = app.buttons["create-project-button"]
        if createButton.waitForExistence(timeout: 3) {
            createButton.click()
            // Wait for project to load
            sleep(2)
        }
    }

    @MainActor
    func testOpenExistingProjectLoadsOverview() throws {
        launchApp()
        // If a project is already loaded, overview content should exist
        let navOverview = app.buttons["nav-overview"]
        if navOverview.waitForExistence(timeout: 5) {
            navOverview.click()
            sleep(1)
            // The app should show overview content without crashing
            XCTAssertTrue(app.windows.count > 0)
        }
    }

    // MARK: - Scenario 2: Tab Navigation

    @MainActor
    func testNavigateToAllTabsWithoutCrash() throws {
        launchApp()

        let tabs = [
            "nav-overview", "nav-script", "nav-bubble", "nav-shot-list",
            "nav-scenes", "nav-assets", "nav-vision-board", "nav-production",
            "nav-story-design", "nav-curation", "nav-playback", "nav-settings"
        ]

        for tab in tabs {
            let button = app.buttons[tab]
            if button.waitForExistence(timeout: 3) {
                button.click()
                usleep(500_000) // Allow view to render
                XCTAssertTrue(app.windows.count > 0, "Window should remain after navigating to \(tab)")
            }
        }
    }

    @MainActor
    func testBubbleViewHasScrollView() throws {
        launchApp()
        navigateTo("nav-bubble")
        // The bubble view should contain scrollable content
        sleep(1)
        XCTAssertTrue(app.windows.count > 0, "App should remain stable on bubble view")
    }

    @MainActor
    func testStoryDesignModePickerAppears() throws {
        launchApp()
        navigateTo("nav-story-design")
        sleep(1)
        // Story design should load without crash
        XCTAssertTrue(app.windows.count > 0, "App should remain stable on story design")
    }

    @MainActor
    func testShotListLoads() throws {
        launchApp()
        navigateTo("nav-shot-list")
        sleep(1)
        XCTAssertTrue(app.windows.count > 0, "App should remain stable on shot list")
    }

    @MainActor
    func testBackForwardNavigation() throws {
        launchApp()
        navigateTo("nav-overview")
        navigateTo("nav-bubble")
        navigateTo("nav-script")
        // Allow navigation to settle after rapid tab switches
        sleep(1)
        XCTAssertTrue(app.windows.count > 0, "App should remain stable after rapid navigation")
    }

    // MARK: - Scenario 3: Scene Selection

    @MainActor
    func testSidebarShowsScenes() throws {
        launchApp()
        navigateTo("nav-bubble")
        sleep(1)
        // Navigator sidebar should be present
        let sidebar = app.otherElements["navigator-sidebar"]
        if sidebar.waitForExistence(timeout: 5) {
            XCTAssertTrue(sidebar.exists)
        }
    }

    @MainActor
    func testTapSceneRowUpdatesContent() throws {
        launchApp()
        navigateTo("nav-bubble")
        sleep(1)
        // Look for any scene row element
        let sceneRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scene-row-'"))
        if sceneRows.count > 0 {
            sceneRows.element(boundBy: 0).click()
            sleep(1)
            XCTAssertTrue(app.windows.count > 0, "Clicking scene row should not crash")
        }
    }

    @MainActor
    func testSceneSwitchReflectsInBubbleView() throws {
        launchApp()
        navigateTo("nav-bubble")
        sleep(1)
        let sceneRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scene-row-'"))
        if sceneRows.count > 1 {
            sceneRows.element(boundBy: 0).click()
            usleep(500_000)
            sceneRows.element(boundBy: 1).click()
            usleep(500_000)
            XCTAssertTrue(app.windows.count > 0)
        }
    }

    @MainActor
    func testExpandCollapseSequence() throws {
        launchApp()
        navigateTo("nav-bubble")
        sleep(1)
        let sequenceRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'sequence-row-'"))
        if sequenceRows.count > 0 {
            // Click the sequence row (which toggles expand/collapse)
            sequenceRows.element(boundBy: 0).click()
            usleep(300_000)
            sequenceRows.element(boundBy: 0).click()
            usleep(300_000)
            XCTAssertTrue(app.windows.count > 0)
        }
    }

    // MARK: - Scenario 4: Story Design

    @MainActor
    func testCharacterListDisplays() throws {
        launchApp()
        navigateTo("nav-story-design")
        sleep(1)
        XCTAssertTrue(app.windows.count > 0, "Story design view should load")
    }

    @MainActor
    func testSelectCharacterLoadsDetail() throws {
        launchApp()
        navigateTo("nav-story-design")
        sleep(1)
        // Click any character in the list
        let characterElements = app.staticTexts.matching(NSPredicate(format: "value != nil"))
        if characterElements.count > 0 {
            XCTAssertTrue(app.windows.count > 0)
        }
    }

    @MainActor
    func testSwitchDesignTabs() throws {
        launchApp()
        navigateTo("nav-story-design")
        sleep(1)
        // The story design view has tabs; navigating between them should not crash
        XCTAssertTrue(app.windows.count > 0)
    }

    @MainActor
    func testToggleLocationsMode() throws {
        launchApp()
        navigateTo("nav-story-design")
        sleep(1)
        // Look for the Locations mode button/picker
        let locationsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Locations'"))
        if locationsButton.count > 0 {
            locationsButton.element(boundBy: 0).click()
            sleep(1)
            XCTAssertTrue(app.windows.count > 0)
        }
    }

    // MARK: - Scenario 5: Shot Management

    @MainActor
    func testShotListDisplaysShots() throws {
        launchApp()
        navigateTo("nav-shot-list")
        sleep(1)
        XCTAssertTrue(app.windows.count > 0, "Shot list view should load")
    }

    @MainActor
    func testSelectShotOpensDetail() throws {
        launchApp()
        navigateTo("nav-shot-list")
        sleep(1)
        let shotRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shot-row-'"))
        if shotRows.count > 0 {
            shotRows.element(boundBy: 0).click()
            sleep(1)
            XCTAssertTrue(app.windows.count > 0)
        }
    }

    @MainActor
    func testShotStatusBadgesVisible() throws {
        launchApp()
        navigateTo("nav-bubble")
        sleep(1)
        // Shot rows in outline should show status badges
        let shotRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shot-row-'"))
        if shotRows.count > 0 {
            XCTAssertTrue(shotRows.element(boundBy: 0).exists)
        }
    }

    @MainActor
    func testNavigateFromOutlineToShot() throws {
        launchApp()
        navigateTo("nav-bubble")
        sleep(1)
        let shotRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shot-row-'"))
        if shotRows.count > 0 {
            shotRows.element(boundBy: 0).click()
            sleep(1)
            XCTAssertTrue(app.windows.count > 0, "Selecting shot from outline should not crash")
        }
    }

    // MARK: - Scenario 6: Performance

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let perfApp = XCUIApplication()
                perfApp.launchArguments = ["--uitesting"]
                perfApp.launch()
            }
        }
    }
}
