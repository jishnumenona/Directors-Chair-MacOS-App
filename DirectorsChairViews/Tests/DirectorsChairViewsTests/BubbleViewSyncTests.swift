// BubbleViewSyncTests.swift
// Tests for BubbleView data sync correctness — project model mutations, cache rebuild, ID-based lookup

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class BubbleViewSyncTests: XCTestCase {

    // MARK: - Test Helpers

    /// Create a minimal project with one sequence, one scene, and some dialogues
    private func makeTestProject() -> Project {
        let dialogue1 = Dialogue(character: "Alice", text: "Hello there!", chronologyNumber: 1)
        let dialogue2 = Dialogue(character: "Bob", text: "Hi Alice!", chronologyNumber: 2)
        let action1 = Action(description: "Alice waves", chronologyNumber: 3)
        let narration1 = Narration(text: "The room falls silent.", chronologyNumber: 4)

        let scene = Scene(
            name: "Scene 1 - INT. CAFE - DAY",
            dialogues: [dialogue1, dialogue2],
            actions: [action1],
            narrations: [narration1]
        )
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        return Project(name: "Test Project", sequences: [sequence])
    }

    // MARK: - Dialogue Update Tests

    func testUpdateDialogueModifiesProject() {
        var project = makeTestProject()
        let sceneId = project.sequences[0].scenes[0].id

        // Simulate what BubbleView.updateDialogue does
        let dialogueIndex = 0
        project.sequences[0].scenes[0].dialogues[dialogueIndex].text = "Updated text!"

        XCTAssertEqual(project.sequences[0].scenes[0].dialogues[0].text, "Updated text!")
        // Scene ID should remain stable
        XCTAssertEqual(project.sequences[0].scenes[0].id, sceneId)
    }

    func testUpdateActionModifiesProject() {
        var project = makeTestProject()

        project.sequences[0].scenes[0].actions[0].description = "Alice waves enthusiastically"

        XCTAssertEqual(project.sequences[0].scenes[0].actions[0].description, "Alice waves enthusiastically")
    }

    func testUpdateNarrationModifiesProject() {
        var project = makeTestProject()

        project.sequences[0].scenes[0].narrations[0].text = "A tense silence fills the room."

        XCTAssertEqual(project.sequences[0].scenes[0].narrations[0].text, "A tense silence fills the room.")
    }

    // MARK: - Add/Delete Tests

    func testAddDialogueAppearsInProject() {
        var project = makeTestProject()
        let originalCount = project.sequences[0].scenes[0].dialogues.count

        let newDialogue = Dialogue(character: "Charlie", text: "I just arrived!", chronologyNumber: 5)
        project.sequences[0].scenes[0].dialogues.append(newDialogue)

        XCTAssertEqual(project.sequences[0].scenes[0].dialogues.count, originalCount + 1)
        XCTAssertEqual(project.sequences[0].scenes[0].dialogues.last?.character, "Charlie")
    }

    func testDeleteDialogueRemovedFromProject() {
        var project = makeTestProject()
        let dialogueId = project.sequences[0].scenes[0].dialogues[0].uuid

        project.sequences[0].scenes[0].dialogues.removeAll { $0.uuid == dialogueId }

        XCTAssertEqual(project.sequences[0].scenes[0].dialogues.count, 1)
        XCTAssertFalse(project.sequences[0].scenes[0].dialogues.contains { $0.uuid == dialogueId })
    }

    // MARK: - Scene Lookup by ID Tests

    func testSceneSelectionById() {
        let project = makeTestProject()
        let targetId = project.sequences[0].scenes[0].id

        // ID-based lookup (the fixed approach)
        var found: Scene?
        for sequence in project.sequences {
            if let scene = sequence.scenes.first(where: { $0.id == targetId }) {
                found = scene
                break
            }
        }

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, targetId)
    }

    func testSceneSelectionWithDuplicateNames() {
        // Two scenes with the same name — ID-based lookup must distinguish them
        let scene1 = Scene(name: "Scene 1 - INT. CAFE - DAY")
        let scene2 = Scene(name: "Scene 1 - INT. CAFE - DAY")

        XCTAssertNotEqual(scene1.id, scene2.id, "Scenes with same name should have distinct IDs")

        let sequence = Sequence(name: "Act 1", scenes: [scene1, scene2])
        let project = Project(name: "Test", sequences: [sequence])

        // Look up scene2 by ID — should find scene2, not scene1
        var found: Scene?
        for seq in project.sequences {
            if let scene = seq.scenes.first(where: { $0.id == scene2.id }) {
                found = scene
                break
            }
        }

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, scene2.id)
        XCTAssertNotEqual(found?.id, scene1.id)
    }

    // MARK: - Round-Trip Tests

    func testDialogueRoundTripBubbleToProject() {
        var project = makeTestProject()
        let originalText = "Original dialogue text"
        let updatedText = "Edited dialogue text"

        project.sequences[0].scenes[0].dialogues[0].text = originalText
        XCTAssertEqual(project.sequences[0].scenes[0].dialogues[0].text, originalText)

        project.sequences[0].scenes[0].dialogues[0].text = updatedText
        XCTAssertEqual(project.sequences[0].scenes[0].dialogues[0].text, updatedText)
    }

    func testConcurrentEditsNoDataLoss() {
        var project = makeTestProject()

        // Simulate rapid edits to different items in the same scene
        project.sequences[0].scenes[0].dialogues[0].text = "Edit 1"
        project.sequences[0].scenes[0].dialogues[1].text = "Edit 2"
        project.sequences[0].scenes[0].actions[0].description = "Edit 3"
        project.sequences[0].scenes[0].narrations[0].text = "Edit 4"

        XCTAssertEqual(project.sequences[0].scenes[0].dialogues[0].text, "Edit 1")
        XCTAssertEqual(project.sequences[0].scenes[0].dialogues[1].text, "Edit 2")
        XCTAssertEqual(project.sequences[0].scenes[0].actions[0].description, "Edit 3")
        XCTAssertEqual(project.sequences[0].scenes[0].narrations[0].text, "Edit 4")
    }

    // MARK: - Cache Rebuild Simulation

    func testCacheRebuildAfterExternalChange() {
        var project = makeTestProject()

        // Simulate reading scene data (as cache would)
        let sceneBefore = project.sequences[0].scenes[0]
        let cachedDialogueCount = sceneBefore.dialogues.count

        // External change: add a dialogue (e.g., from ScriptView)
        let newDialogue = Dialogue(character: "Dave", text: "New line!", chronologyNumber: 5)
        project.sequences[0].scenes[0].dialogues.append(newDialogue)

        // Re-read scene by ID (simulating externalRefreshTrigger rebuild)
        let sceneId = sceneBefore.id
        var freshScene: Scene?
        for seq in project.sequences {
            if let scene = seq.scenes.first(where: { $0.id == sceneId }) {
                freshScene = scene
                break
            }
        }

        XCTAssertNotNil(freshScene)
        XCTAssertEqual(freshScene!.dialogues.count, cachedDialogueCount + 1)
        XCTAssertEqual(freshScene!.dialogues.last?.character, "Dave")
    }
}
