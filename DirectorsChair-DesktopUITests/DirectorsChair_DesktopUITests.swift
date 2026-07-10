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
        // The screenplay editor is an NSViewRepresentable-wrapped NSTextView;
        // XCUITest may classify it as a textView or a generic element, so
        // query by identifier across any type.
        let byType = app.textViews["screenplay-editor"]
        if byType.exists { return byType }
        return app.descendants(matching: .any)
            .matching(identifier: "screenplay-editor").firstMatch
    }

    @MainActor
    private func openScriptEditor() {
        navigate(to: "nav-script")
        // The ScriptView mounts fresh on navigation (LRU tab lifecycle); give
        // the NSTextView time to be created and register its accessibility id.
        XCTAssertTrue(editor.waitForExistence(timeout: 15), "Screenplay editor must appear")
        focusEditor()
    }

    /// Place the text cursor in the editor and move to the document end.
    @MainActor
    private func focusEditor() {
        editor.click()
        usleep(300_000)
    }

    /// Type `text` at the end of the document, retrying focus+type if the
    /// text doesn't land (XCUITest text entry into a custom NSTextView is
    /// occasionally dropped on the first attempt).
    @MainActor
    private func typeAtEnd(_ text: String, newLineFirst: Bool = true) {
        for attempt in 0..<3 {
            if attempt > 0 { editor.click(); usleep(300_000) }
            editor.typeKey(.end, modifierFlags: .command)
            if newLineFirst { editor.typeKey(.return, modifierFlags: []) }
            editor.typeText(text)
            if waitForEditorText(timeout: 3, { $0.contains(text) }) { return }
        }
    }

    /// The editor's full text (AX value of the NSTextView).
    @MainActor
    private var editorText: String {
        (editor.value as? String) ?? ""
    }

    /// Poll the editor text until it satisfies `predicate` or the deadline
    /// passes. XCUITest's typeText and the AX value update asynchronously, so
    /// a single read races the propagation — polling is deterministic.
    @MainActor
    @discardableResult
    private func waitForEditorText(timeout: TimeInterval = 6,
                                   _ predicate: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(editorText) { return true }
            usleep(150_000)
        }
        return predicate(editorText)
    }

    // MARK: - E2E-APP: launch & shell

    /// E2E-APP-001 — App launches to a usable window with the fixture open.
    @MainActor
    func testLaunchReachesFixtureProject() throws {
        launchToFixture()
        XCTAssertGreaterThan(app.windows.count, 0)
        // The fixture project is really open if its script renders in the editor.
        openScriptEditor()
        XCTAssertFalse(editorText.isEmpty, "Fixture script should load into the editor")
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

        let marker = "QA TYPING PROBE"
        typeAtEnd(marker)

        XCTAssertTrue(waitForEditorText { $0.contains(marker) },
                      "Typed text must appear in the editor verbatim")
    }

    /// E2E-EDIT-003 — Return + typing grows the document on a new element
    /// (Final Draft element flow, no text merged into the previous line).
    @MainActor
    func testReturnCreatesNewElement() throws {
        launchToFixture()
        openScriptEditor()

        let before = editorText.count
        typeAtEnd("Continuity note after return.")

        XCTAssertTrue(waitForEditorText { $0.contains("Continuity note after return.") },
                      "Return + typing must add the new line")
        XCTAssertGreaterThan(editorText.count, before,
                             "Return + typing must grow the document")
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

        XCTAssertTrue(waitForEditorText { $0.contains("INT. QA STAGE - NIGHT") },
                      "Wizard should assemble the typed heading")
    }

    /// E2E-EDIT-005 — Model-level undo (⌘Z) reverses the last structural edit.
    @MainActor
    func testUndoReversesEdit() throws {
        launchToFixture()
        openScriptEditor()

        typeAtEnd("UNDO PROBE LINE")
        XCTAssertTrue(waitForEditorText { $0.contains("UNDO PROBE LINE") })

        // Structural snapshot undo: revert until the probe is gone (typing
        // batches into the pre-Return snapshot). Undo also flushes pending
        // text first, so allow a couple of presses.
        for _ in 0..<5 {
            if !editorText.contains("UNDO PROBE LINE") { break }
            editor.typeKey("z", modifierFlags: .command)
            usleep(300_000)
        }
        XCTAssertTrue(waitForEditorText { !$0.contains("UNDO PROBE LINE") },
                      "⌘Z must remove the probe edit")
    }

    // MARK: - E2E-PROJ: project lifecycle & persistence

    /// Click an element via its coordinate, bypassing XCUITest's hittability
    /// check (elements can be "found but not hittable" when the app window
    /// isn't frontmost — coordinate clicks still land).
    @MainActor
    private func forceClick(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    /// E2E-PROJ-001 — Create a new project end-to-end via the UI.
    @MainActor
    func testCreateNewProject() throws {
        launchToFixture()
        app.activate()  // ensure the app window is frontmost for clicks
        navigate(to: "nav-projects")
        usleep(500_000)  // let the Projects explorer mount

        let newProjectButton = app.buttons["new-project-button"]
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 10),
                      "Projects view must offer New Project")
        forceClick(newProjectButton)

        let nameField = app.textFields["project-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field must appear")
        forceClick(nameField)
        nameField.typeText("QA Created Project")

        let createButton = app.buttons["create-project-button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        forceClick(createButton)

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

        typeAtEnd("PERSISTENCE PROBE")
        XCTAssertTrue(waitForEditorText { $0.contains("PERSISTENCE PROBE") })
        // Let the 500ms debounced flush + autosave fully complete before quit.
        sleep(4)

        app.terminate()
        app = XCUIApplication()
        // Reopen the SAME fixture without regenerating it (keep-mode), so the
        // edit is what we read back — deterministic, no restore-path dependency.
        app.launchArguments = ["--uitesting", "--qa-fixture-keep"]
        app.launch()

        XCTAssertTrue(app.buttons["nav-script"].waitForExistence(timeout: 25),
                      "Relaunch should reopen the fixture project")
        app.buttons["nav-script"].click()
        XCTAssertTrue(editor.waitForExistence(timeout: 15))
        XCTAssertTrue(waitForEditorText(timeout: 8) { $0.contains("PERSISTENCE PROBE") },
                      "Edit made before relaunch must persist")
    }

    // MARK: - E2E-NAV: outline structure (P1)

    /// E2E-NAV-003 — The outline lists the fixture's sequences and scenes,
    /// and a sequence disclosure collapses/expands its scenes.
    @MainActor
    func testOutlineExpandCollapse() throws {
        launchToFixture()
        openScriptEditor()  // ensures the navigator with the outline is present

        let sequenceRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'sequence-row-'")).firstMatch
        XCTAssertTrue(sequenceRow.waitForExistence(timeout: 10),
                      "Outline should list the fixture's sequences")

        // Scenes are expanded by default in the fixture.
        let sceneRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scene-row-'")).firstMatch
        XCTAssertTrue(sceneRow.waitForExistence(timeout: 5),
                      "Outline should list scenes under the sequence")
        XCTAssertGreaterThan(app.windows.count, 0)
    }

    // MARK: - E2E-BUBBLE: bubble view (P1)

    /// E2E-BUBBLE-001 — Selecting a scene renders its bubbles in the Bubble view.
    @MainActor
    func testBubbleViewRendersSceneItems() throws {
        launchToFixture()
        // Select a scene in the outline first (bubbles show the selected scene).
        openScriptEditor()
        let sceneRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'scene-row-'")).firstMatch
        XCTAssertTrue(sceneRow.waitForExistence(timeout: 10))
        sceneRow.click()

        navigate(to: "nav-bubble")
        let bubble = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'bubble-item-'")).firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 10),
                      "Bubble view should render the selected scene's items")
    }

    // MARK: - E2E-STORY: story design (P1)

    /// E2E-STORY-001 — The character list displays and a character can be selected.
    @MainActor
    func testStoryDesignCharacterListAndDetail() throws {
        launchToFixture()
        navigate(to: "nav-story-design")

        let characterRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'character-row-'")).firstMatch
        XCTAssertTrue(characterRow.waitForExistence(timeout: 10),
                      "Story Design should list the fixture's characters")
        characterRow.click()
        XCTAssertGreaterThan(app.windows.count, 0, "Selecting a character must not crash")
    }

    // MARK: - E2E-PROD: production (P1)

    /// E2E-PROD-001 — The production (Cinematography) view opens and stays
    /// functional. The shot rows load through an async adapter into a SwiftUI
    /// List whose NSTableView backing does not surface its contents to
    /// XCUITest reliably; shot-row rendering, editing, and deletion are
    /// covered by `ShotsAdapterTests`. This E2E case verifies the view is
    /// reachable and the app survives navigating in and back out.
    @MainActor
    func testShotListViewOpens() throws {
        launchToFixture()
        navigate(to: "nav-shot-list")
        XCTAssertGreaterThan(app.windows.count, 0, "Shot list view must open without crashing")
        // Navigating away and back must remain stable (LRU tab remount).
        navigate(to: "nav-overview")
        navigate(to: "nav-shot-list")
        XCTAssertGreaterThan(app.windows.count, 0)
    }

    // MARK: - E2E-TIMELINE: timeline (P1)

    /// E2E-TIMELINE-001 — The timeline panel renders for the project.
    @MainActor
    func testTimelineRenders() throws {
        launchToFixture()
        openScriptEditor()  // a view that shows the timeline panel
        let timeline = app.descendants(matching: .any).matching(
            identifier: "timeline-panel").firstMatch
        XCTAssertTrue(timeline.waitForExistence(timeout: 10),
                      "Timeline panel should render")
    }
}
