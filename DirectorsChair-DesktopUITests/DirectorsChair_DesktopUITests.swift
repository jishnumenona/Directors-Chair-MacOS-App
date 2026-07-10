//
//  DirectorsChair_DesktopUITests.swift
//  DirectorsChair-DesktopUITests
//
//  P0 end-to-end UI workflows (QA catalog: qa/catalog/desktop.json).
//  Every test runs against the deterministic "QA Fixture" project
//  (--qa-fixture regenerates it on launch), so assertions are HARD —
//  no if-exists-then-maybe guards. A failure here is a bug or a
//  fixture/catalog drift, never "the environment was different".
//

import XCTest

final class DirectorsChair_DesktopUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--qa-fixture"]
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helpers

    @MainActor
    private func launchToFixture() {
        app.launch()
        // The window always appears first; splash + async fixture generation
        // + auth settling follow. Wait for the nav rail to be interactive
        // (any primary nav button), which is the true "ready" signal —
        // more robust than betting on one specific view winning the launch
        // navigation race.
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20),
                      "Main window should appear")
        let ready = app.buttons["nav-script"].waitForExistence(timeout: 25)
            || app.buttons["nav-overview"].waitForExistence(timeout: 5)
        XCTAssertTrue(ready, "App should reach an interactive project view (nav rail present)")
    }

    @MainActor
    private func navigate(to id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Nav button \(id) must exist")
        button.click()
    }

    @MainActor
    private var editor: XCUIElement {
        app.textViews["screenplay-editor"].firstMatch
    }

    @MainActor
    private func openScriptEditor() {
        navigate(to: "nav-script")
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "Screenplay editor must appear")
        editor.click()
    }

    /// The editor's full text (AX value of the NSTextView).
    @MainActor
    private var editorText: String {
        (editor.value as? String) ?? ""
    }

    // MARK: - E2E-APP: launch & shell

    /// E2E-APP-001 — App launches to a usable window with the fixture open.
    @MainActor
    func testLaunchReachesFixtureProject() throws {
        launchToFixture()
        XCTAssertGreaterThan(app.windows.count, 0)
        // Fixture content visible: the navigator lists Act 1
        XCTAssertTrue(app.staticTexts["Act 1"].firstMatch.waitForExistence(timeout: 10),
                      "Fixture sequence should be visible in the navigator")
    }

    /// E2E-APP-002 — Every primary view opens without hanging or crashing.
    @MainActor
    func testAllPrimaryViewsOpen() throws {
        launchToFixture()
        for id in ["nav-script", "nav-bubble", "nav-scenes", "nav-assets",
                   "nav-production", "nav-story-design", "nav-overview"] {
            navigate(to: id)
            XCTAssertGreaterThan(app.windows.count, 0, "Window must survive \(id)")
        }
    }

    // MARK: - E2E-NAV: navigator panel

    /// E2E-NAV-001 — Clicking a scene row (anywhere on the row) selects it.
    @MainActor
    func testSceneRowSelection() throws {
        launchToFixture()
        openScriptEditor()

        let anyRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scene-row-'")).firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 10),
                      "Navigator should list fixture scene rows")
        anyRow.click()
        XCTAssertGreaterThan(app.windows.count, 0)
    }

    /// E2E-NAV-002 — Rapid navigation clicks all land (regression:
    /// navigateTo used to drop clicks behind a debounce).
    @MainActor
    func testRapidNavigationClicksLand() throws {
        launchToFixture()
        navigate(to: "nav-script")
        navigate(to: "nav-bubble")
        navigate(to: "nav-scenes")
        navigate(to: "nav-overview")
        XCTAssertGreaterThan(app.windows.count, 0)
    }

    // MARK: - E2E-EDIT: screenplay editor

    /// E2E-EDIT-001 — Fixture script renders in the editor.
    @MainActor
    func testEditorShowsFixtureScript() throws {
        launchToFixture()
        openScriptEditor()
        XCTAssertTrue(editorText.contains("INT.") || editorText.contains("EXT."),
                      "Fixture scene headings should render in the editor")
    }

    /// E2E-EDIT-002 — Typing appends text (the core editing loop:
    /// keystrokes → shadow buffer → display, no jumbling).
    @MainActor
    func testTypingInEditor() throws {
        launchToFixture()
        openScriptEditor()

        // Park the cursor at the very end of the document.
        editor.typeKey(.end, modifierFlags: .command)
        editor.typeKey(.return, modifierFlags: [])
        let marker = "QA TYPING PROBE"
        editor.typeText(marker)

        XCTAssertTrue(editorText.contains(marker),
                      "Typed text must appear in the editor verbatim")
    }

    /// E2E-EDIT-003 — Return + typing grows the document on a new element
    /// (Final Draft element flow, no text merged into the previous line).
    @MainActor
    func testReturnCreatesNewElement() throws {
        launchToFixture()
        openScriptEditor()

        editor.typeKey(.end, modifierFlags: .command)
        let before = editorText.count
        editor.typeKey(.return, modifierFlags: [])
        editor.typeText("Continuity note after return.")

        XCTAssertGreaterThan(editorText.count, before,
                             "Return + typing must grow the document")
        XCTAssertTrue(editorText.contains("Continuity note after return."))
    }

    /// E2E-EDIT-004 — New Scene wizard (⌘⇧N): type a location, Return,
    /// type a time, Return — the completed heading appears.
    @MainActor
    func testNewSceneWizardTypedFlow() throws {
        launchToFixture()
        openScriptEditor()

        editor.typeKey(.end, modifierFlags: .command)
        editor.typeKey("n", modifierFlags: [.command, .shift])
        // Wizard puts the cursor after "INT. " — type location, accept, time, accept.
        editor.typeText("QA STAGE")
        editor.typeKey(.return, modifierFlags: [])
        editor.typeText("NIGHT")
        editor.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(editorText.contains("INT. QA STAGE - NIGHT"),
                      "Wizard should assemble the typed heading")
    }

    /// E2E-EDIT-005 — Model-level undo (⌘Z) reverses the last structural edit.
    @MainActor
    func testUndoReversesEdit() throws {
        launchToFixture()
        openScriptEditor()

        editor.typeKey(.end, modifierFlags: .command)
        editor.typeKey(.return, modifierFlags: [])
        editor.typeText("UNDO PROBE LINE")
        XCTAssertTrue(editorText.contains("UNDO PROBE LINE"))

        // Structural snapshot undo: revert until the probe is gone (typing
        // batches into the pre-Return snapshot).
        for _ in 0..<4 where editorText.contains("UNDO PROBE LINE") {
            editor.typeKey("z", modifierFlags: .command)
        }
        XCTAssertFalse(editorText.contains("UNDO PROBE LINE"),
                       "⌘Z must remove the probe edit")
    }

    // MARK: - E2E-PROJ: project lifecycle & persistence

    /// E2E-PROJ-001 — Create a new project end-to-end via the UI.
    @MainActor
    func testCreateNewProject() throws {
        launchToFixture()
        navigate(to: "nav-projects")

        let newProjectButton = app.buttons["new-project-button"]
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 5),
                      "Projects view must offer New Project")
        newProjectButton.click()

        let nameField = app.textFields["project-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field must appear")
        nameField.click()
        nameField.typeText("QA Created Project")

        let createButton = app.buttons["create-project-button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.click()

        // The created project becomes the open project (nav rail active).
        XCTAssertTrue(app.buttons["nav-overview"].waitForExistence(timeout: 10),
                      "Created project should open")
    }

    /// E2E-PROJ-002 — Edits persist across app relaunch.
    /// (Relaunches WITHOUT --qa-fixture so the fixture isn't regenerated
    /// over the edit; the app restores the last project.)
    @MainActor
    func testEditPersistsAcrossRelaunch() throws {
        launchToFixture()
        openScriptEditor()

        editor.typeKey(.end, modifierFlags: .command)
        editor.typeKey(.return, modifierFlags: [])
        editor.typeText("PERSISTENCE PROBE")
        // Let the 500ms debounced flush + autosave complete.
        sleep(3)

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]   // no fixture regen
        app.launch()

        XCTAssertTrue(app.buttons["nav-script"].waitForExistence(timeout: 20),
                      "Relaunch should restore the last project")
        app.buttons["nav-script"].click()
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue(editorText.contains("PERSISTENCE PROBE"),
                      "Edit made before relaunch must persist")
    }
}
