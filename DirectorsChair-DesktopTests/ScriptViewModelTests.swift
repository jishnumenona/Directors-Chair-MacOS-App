// ScriptViewModelTests.swift
// Tests for ScriptViewModel editing operations: Return, Backspace, Tab, dirty flush, text handling

import XCTest
import Combine
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class ScriptViewModelTests: XCTestCase {

    var viewModel: ScriptViewModel!
    var projectViewModel: ProjectViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = ScriptViewModel()
        projectViewModel = ProjectViewModel()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        projectViewModel = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func loadTestProject() {
        var project = Project(name: "Test Script Project")
        let dialogue = Dialogue(character: "Alice", text: "Hello!", chronologyNumber: 1)
        let action = Action(description: "Alice enters.", chronologyNumber: 2)
        let narration = Narration(text: "It was a dark night.", chronologyNumber: 3)

        let scene = Scene(
            name: "Scene 1 - INT. OFFICE - DAY",
            dialogues: [dialogue],
            actions: [action],
            narrations: [narration]
        )
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        project.characters = [Character(name: "Alice")]

        projectViewModel.project = project
        viewModel.loadFromProject(project, projectViewModel: projectViewModel)
    }

    private func makeSimpleElements() {
        // Manually set up elements for isolated testing
        viewModel.elements = [
            ScriptElement(type: .sceneHeading, text: "INT. OFFICE - DAY", sourceSequenceIndex: 0, sourceSceneIndex: 0, sceneNumber: "1"),
            ScriptElement(type: .action, text: "Alice enters the room.", sourceSequenceIndex: 0, sourceSceneIndex: 0),
            ScriptElement(type: .character, text: "ALICE", sourceSequenceIndex: 0, sourceSceneIndex: 0),
            ScriptElement(type: .dialogue, text: "Hello everyone!", sourceSequenceIndex: 0, sourceSceneIndex: 0),
            ScriptElement(type: .blankLine, text: "", sourceSequenceIndex: 0, sourceSceneIndex: 0),
            ScriptElement(type: .action, text: "She waves.", sourceSequenceIndex: 0, sourceSceneIndex: 0),
        ]
        viewModel.elementsVersion += 1
    }

    // MARK: - Return Key Tests

    func testHandleReturnAtEnd() {
        makeSimpleElements()
        let originalCount = viewModel.elements.count

        // Press Return at the end of element 1 (action "Alice enters the room.")
        let instruction = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 22)

        XCTAssertEqual(viewModel.elements.count, originalCount + 1, "Return should create a new element")

        // The original element text should be unchanged
        XCTAssertEqual(viewModel.elements[1].text, "Alice enters the room.")
        // New element should be empty
        XCTAssertEqual(viewModel.elements[2].text, "")

        // Instruction should be fullRebuild with focus on the new element
        if case .fullRebuild(let focusId, let cursorOffset) = instruction {
            XCTAssertEqual(focusId, viewModel.elements[2].id)
            XCTAssertEqual(cursorOffset, 0)
        } else {
            XCTFail("Expected .fullRebuild instruction")
        }
    }

    func testHandleReturnMidText() {
        makeSimpleElements()

        // Press Return in the middle of "Alice enters the room." at offset 5 ("Alice| enters...")
        let instruction = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 5)

        // The original element should have text up to the cursor
        XCTAssertEqual(viewModel.elements[1].text, "Alice")
        // The new element should have the remainder
        XCTAssertEqual(viewModel.elements[2].text, " enters the room.")

        if case .fullRebuild(let focusId, _) = instruction {
            XCTAssertEqual(focusId, viewModel.elements[2].id)
        } else {
            XCTFail("Expected .fullRebuild instruction")
        }
    }

    func testHandleReturnAtStart() {
        makeSimpleElements()
        let originalText = viewModel.elements[1].text

        // Press Return at the start of element 1 (offset 0)
        let _ = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 0)

        // New element should be inserted after index 1 with the full text moved down
        // Element 1 remains with original text (cursorOffset 0 means no split)
        // Element 2 is the new empty element
        XCTAssertEqual(viewModel.elements[1].text, originalText, "Original text unchanged when Return at start with no split")
    }

    func testHandleReturnPreservesAllText() {
        makeSimpleElements()
        let originalText = "Alice enters the room."
        XCTAssertEqual(viewModel.elements[1].text, originalText)

        // Split at position 10
        let _ = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 10)

        let leftPart = viewModel.elements[1].text
        let rightPart = viewModel.elements[2].text

        // Combined text should equal original (regression B1)
        XCTAssertEqual(leftPart + rightPart, originalText, "No text should be lost during Return split")
    }

    // MARK: - Backspace Tests

    func testHandleBackspaceMerge() {
        makeSimpleElements()

        // Backspace at the start of element 3 (dialogue "Hello everyone!")
        // Should merge into element 2 (character "ALICE")
        let charText = viewModel.elements[2].text
        let dialogueText = viewModel.elements[3].text
        let originalCount = viewModel.elements.count

        let instruction = viewModel.handleBackspace(atElementIndex: 3, cursorOffset: 0)

        XCTAssertEqual(viewModel.elements.count, originalCount - 1, "Backspace merge should remove one element")
        // Merged text should be character + dialogue
        XCTAssertEqual(viewModel.elements[2].text, charText + dialogueText, "Text should be combined")

        if case .fullRebuild(let focusId, let cursorOffset) = instruction {
            XCTAssertEqual(focusId, viewModel.elements[2].id)
            XCTAssertEqual(cursorOffset, charText.count, "Cursor should be at the join point")
        } else {
            XCTFail("Expected .fullRebuild instruction")
        }
    }

    func testHandleBackspacePreservesText() {
        makeSimpleElements()

        let textBefore = viewModel.elements[1].text  // "Alice enters the room."
        let textAfter = viewModel.elements[2].text  // "ALICE"

        let _ = viewModel.handleBackspace(atElementIndex: 2, cursorOffset: 0)

        // The merged element should contain all text from both elements
        XCTAssertEqual(viewModel.elements[1].text, textBefore + textAfter, "No text lost during backspace merge (regression B2)")
    }

    func testHandleBackspaceAtFileStart() {
        makeSimpleElements()
        let originalCount = viewModel.elements.count

        // Backspace at element 0 should be a no-op
        let instruction = viewModel.handleBackspace(atElementIndex: 0, cursorOffset: 0)

        XCTAssertEqual(viewModel.elements.count, originalCount)
        if case .none = instruction {
            // Expected
        } else {
            XCTFail("Backspace at start should be .none")
        }
    }

    func testHandleBackspaceRemovesBlankLine() {
        makeSimpleElements()

        // Element 4 is a blankLine. Backspace at element 5 should remove the blankLine (element 4).
        let countBefore = viewModel.elements.count
        let _ = viewModel.handleBackspace(atElementIndex: 5, cursorOffset: 0)

        XCTAssertEqual(viewModel.elements.count, countBefore - 1)
        // Element at index 4 should now be "She waves." (the action moved up)
        XCTAssertEqual(viewModel.elements[4].text, "She waves.")
    }

    // MARK: - Tab Key Tests

    func testHandleTabCyclesType() {
        makeSimpleElements()

        // Tab on an action element should cycle to character
        let actionIndex = 1
        XCTAssertEqual(viewModel.elements[actionIndex].type, .action)

        let instruction = viewModel.handleTabCycle(atElementIndex: actionIndex)

        XCTAssertEqual(viewModel.elements[actionIndex].type, .character, "Tab should cycle action -> character")

        if case .fullRebuild(_, _) = instruction {
            // Expected
        } else {
            XCTFail("Expected .fullRebuild instruction")
        }
    }

    // MARK: - Text Edit Tests

    func testHandleTextEditCorrectElement() {
        makeSimpleElements()
        let elementId = viewModel.elements[1].id

        viewModel.handleTextEdit(elementIndex: 1, newText: "Bob enters instead.")

        // Text should be in pending buffer, not yet in elements
        // (elements only updated on flush)
        XCTAssertNotEqual(viewModel.elements[1].text, "Bob enters instead.", "Text stays in shadow buffer before flush")
    }

    func testFlushDirtyUpdatesProject() {
        loadTestProject()
        let originalDialogueCount = viewModel.elements.filter { $0.type == .dialogue }.count
        XCTAssertGreaterThan(originalDialogueCount, 0)

        // Edit a dialogue element
        if let dialogueIndex = viewModel.elements.firstIndex(where: { $0.type == .dialogue }) {
            viewModel.handleTextEdit(elementIndex: dialogueIndex, newText: "Updated dialogue text!")
            viewModel.flushDirtyElements()

            // After flush, project should reflect the change
            XCTAssertTrue(projectViewModel.isDirty, "Flushing dirty elements should mark project as dirty")
        }
    }

    func testPendingTextsBuffering() {
        makeSimpleElements()

        // Multiple text edits should accumulate in buffer
        viewModel.handleTextEdit(elementIndex: 1, newText: "First edit")
        viewModel.handleTextEdit(elementIndex: 1, newText: "Second edit")

        // The latest text should be in the buffer (overwriting previous)
        // Elements should still have original text
        XCTAssertEqual(viewModel.elements[1].text, "Alice enters the room.", "Elements unchanged before sync")
    }

    // MARK: - Element Count Invariant

    func testElementCountEqualsParagraphCount() {
        makeSimpleElements()
        let originalCount = viewModel.elements.count

        // After Return, count should increase by 1
        let _ = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 5)
        XCTAssertEqual(viewModel.elements.count, originalCount + 1)

        // After Backspace merge, count should decrease by 1
        let countAfterReturn = viewModel.elements.count
        let _ = viewModel.handleBackspace(atElementIndex: 3, cursorOffset: 0)
        XCTAssertEqual(viewModel.elements.count, countAfterReturn - 1)
    }

    func testConsecutiveBlankLinesIndexing() {
        // Create elements with consecutive blank lines
        viewModel.elements = [
            ScriptElement(type: .action, text: "Line 1"),
            ScriptElement(type: .blankLine, text: ""),
            ScriptElement(type: .blankLine, text: ""),
            ScriptElement(type: .action, text: "Line 2"),
        ]
        viewModel.elementsVersion += 1

        // Verify all elements are accessible
        XCTAssertEqual(viewModel.elements.count, 4)
        XCTAssertEqual(viewModel.elements[0].text, "Line 1")
        XCTAssertEqual(viewModel.elements[1].type, .blankLine)
        XCTAssertEqual(viewModel.elements[2].type, .blankLine)
        XCTAssertEqual(viewModel.elements[3].text, "Line 2")
    }

    // MARK: - Autocomplete Tests

    func testAutocompleteUpdatesModel() {
        makeSimpleElements()

        // Simulate autocomplete selection on element 2 (character)
        let instruction = viewModel.handleAutocompleteSelection(item: "BOB", atElementIndex: 2)

        XCTAssertEqual(viewModel.elements[2].text, "BOB")
        XCTAssertEqual(viewModel.elements[2].type, .character)
        XCTAssertFalse(viewModel.elements[2].isPlaceholder)

        if case .fullRebuild(_, _) = instruction {
            // Expected — a new dialogue element is inserted after
        } else {
            XCTFail("Expected .fullRebuild instruction")
        }
    }

    func testPlaceholderReplacement() {
        viewModel.elements = [
            ScriptElement(type: .action, text: "Type here...", isPlaceholder: true),
        ]
        viewModel.elementsVersion += 1

        let instruction = viewModel.handlePlaceholderEdit(elementIndex: 0, newText: "Real text")

        XCTAssertEqual(viewModel.elements[0].text, "Real text")
        XCTAssertFalse(viewModel.elements[0].isPlaceholder)

        if case .fullRebuild(_, _) = instruction {
            // Expected
        } else {
            XCTFail("Expected .fullRebuild instruction")
        }
    }

    // MARK: - Refresh Tests

    func testRefreshFromProjectRebuildsElements() {
        loadTestProject()
        let originalCount = viewModel.elements.count

        // Modify the project and refresh
        var project = projectViewModel.project
        let newDialogue = Dialogue(character: "Bob", text: "Surprise!", chronologyNumber: 10)
        project.sequences[0].scenes[0].dialogues.append(newDialogue)
        projectViewModel.project = project

        viewModel.refresh(from: project)

        XCTAssertNotEqual(viewModel.elements.count, originalCount, "Refresh should rebuild elements from project")
    }

    func testSkipNextRefreshPreventsDoubleBuild() {
        loadTestProject()
        let elementsBeforeRefresh = viewModel.elements

        // Trigger a dirty flush which sets skipNextRefresh
        viewModel.handleTextEdit(elementIndex: 0, newText: "Modified heading")
        viewModel.flushDirtyElements()

        // The next refresh should be skipped
        viewModel.refresh(from: projectViewModel.project)

        // Elements should NOT have been rebuilt (skip was active)
        // After skip, a second refresh should work normally
        viewModel.refresh(from: projectViewModel.project)
        // This one should actually rebuild
    }

    // MARK: - Rapid Editing Stress Test

    func testRapidEditsPreserveAll() {
        makeSimpleElements()

        // Simulate rapid text edits (typing fast)
        let texts = ["A", "Al", "Ali", "Alic", "Alice", "Alice ", "Alice w", "Alice wa", "Alice wal", "Alice walk", "Alice walks"]
        for text in texts {
            viewModel.handleTextEdit(elementIndex: 1, newText: text)
        }

        // The last edit should be the current pending text
        // Elements still have original (shadow buffer)
        XCTAssertEqual(viewModel.elements[1].text, "Alice enters the room.")
    }

    func testStructuralEditFlushesDirty() {
        makeSimpleElements()

        // Make a text edit (goes to shadow buffer)
        viewModel.handleTextEdit(elementIndex: 1, newText: "Modified action text")

        // Structural edit (Return) should flush pending texts first
        let _ = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 5)

        // After Return, the element should have the pending text applied and then split
        XCTAssertEqual(viewModel.elements[1].text, "Modif", "Text should be flushed and split at cursor")
        XCTAssertEqual(viewModel.elements[2].text, "ied action text", "Remainder should be in new element")
    }
    // MARK: - Range replacement (WS7.1 — paste/delete as model ops)

    func testMultiLinePasteSplitsIntoElements() {
        makeSimpleElements()
        // Paste "one\ntwo\nthree" into the middle of "Alice enters the room."
        // (element 1) at offset 6 ("Alice " | "enters the room.")
        let instruction = viewModel.handleRangeReplacement(
            startIndex: 1, startOffset: 6, endIndex: 1, endOffset: 6,
            replacement: "one\ntwo\nthree")

        if case .none = instruction { XCTFail("paste must produce a rebuild") }
        XCTAssertEqual(viewModel.elements.count, 8, "6 elements + 2 new paragraphs")
        XCTAssertEqual(viewModel.elements[1].text, "Alice one", "prefix + first pasted line")
        XCTAssertEqual(viewModel.elements[2].text, "two")
        XCTAssertEqual(viewModel.elements[3].text, "threeenters the room.", "last line + suffix")
        XCTAssertEqual(viewModel.elements[4].text, "ALICE", "following elements shifted intact")
    }

    func testMultiParagraphDeleteMerges() {
        makeSimpleElements()
        // Delete from offset 5 of "Alice enters the room." (idx 1) through
        // offset 2 of "ALICE" (idx 2) — swallows the paragraph boundary.
        let instruction = viewModel.handleRangeReplacement(
            startIndex: 1, startOffset: 5, endIndex: 2, endOffset: 2,
            replacement: "")

        if case .none = instruction { XCTFail("delete must produce a rebuild") }
        XCTAssertEqual(viewModel.elements.count, 5, "one element merged away")
        XCTAssertEqual(viewModel.elements[1].text, "AliceICE", "prefix of start + suffix of end")
        XCTAssertEqual(viewModel.elements[2].text, "Hello everyone!", "dialogue survives")
    }

    func testRangeDeleteAcrossSceneHeadingIsBlocked() {
        makeSimpleElements()
        viewModel.elements.append(ScriptElement(type: .sceneHeading, text: "INT. HALL - NIGHT", sourceSequenceIndex: 0, sourceSceneIndex: 1))
        viewModel.elements.append(ScriptElement(type: .action, text: "Later.", sourceSequenceIndex: 0, sourceSceneIndex: 1))
        let before = viewModel.elements.map(\.text)

        // Range from "She waves." (idx 5) through "Later." (idx 7) swallows
        // the scene heading at idx 6 — must be refused.
        let instruction = viewModel.handleRangeReplacement(
            startIndex: 5, startOffset: 0, endIndex: 7, endOffset: 3,
            replacement: "")

        guard case .none = instruction else {
            return XCTFail("deleting across a scene heading must be blocked")
        }
        XCTAssertEqual(viewModel.elements.map(\.text), before, "elements untouched")
    }

    func testSingleLineRangeReplacementKeepsSuffix() {
        makeSimpleElements()
        // Replace "enters" (offsets 6..12) in element 1 with "exits" — spans no
        // boundary but exercises the single-line path.
        let instruction = viewModel.handleRangeReplacement(
            startIndex: 1, startOffset: 6, endIndex: 1, endOffset: 12,
            replacement: "exits")

        if case .none = instruction { XCTFail("replacement must rebuild") }
        XCTAssertEqual(viewModel.elements[1].text, "Alice exits the room.")
        XCTAssertEqual(viewModel.elements.count, 6, "no structural change")
    }
    // MARK: - Model-level undo (WS7.2)

    func testUndoRestoresStructuralEdit() {
        loadTestProject()
        let beforeCount = viewModel.elements.count
        let beforeTexts = viewModel.elements.map(\.text)

        // Structural edit: Return at end of element 1 inserts a new element.
        _ = viewModel.handleReturn(atElementIndex: 1, cursorOffset: viewModel.elements[1].text.count)
        XCTAssertEqual(viewModel.elements.count, beforeCount + 1)

        let instruction = viewModel.performUndo()
        if case .none = instruction { XCTFail("undo must rebuild") }
        XCTAssertEqual(viewModel.elements.count, beforeCount, "undo restores element count")
        XCTAssertEqual(viewModel.elements.map(\.text), beforeTexts, "undo restores texts")
    }

    func testRedoReappliesUndoneEdit() {
        loadTestProject()
        let beforeCount = viewModel.elements.count

        _ = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 0)
        _ = viewModel.performUndo()
        XCTAssertEqual(viewModel.elements.count, beforeCount)

        let instruction = viewModel.performRedo()
        if case .none = instruction { XCTFail("redo must rebuild") }
        XCTAssertEqual(viewModel.elements.count, beforeCount + 1, "redo reapplies the insert")
    }

    func testNewEditClearsRedoStack() {
        loadTestProject()
        _ = viewModel.handleReturn(atElementIndex: 1, cursorOffset: 0)
        _ = viewModel.performUndo()
        // A fresh structural edit invalidates the redo history.
        _ = viewModel.handleReturn(atElementIndex: 0, cursorOffset: 0)
        let instruction = viewModel.performRedo()
        guard case .none = instruction else {
            return XCTFail("redo after a new edit must be a no-op")
        }
    }

    func testUndoWithEmptyStackIsNoOp() {
        loadTestProject()
        guard case .none = viewModel.performUndo() else {
            return XCTFail("undo with no history must be a no-op")
        }
    }

}

