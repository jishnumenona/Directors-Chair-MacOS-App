// DirectorsChair-DesktopTests/AIChatAssistantTests.swift
//
// AI Assistant program, Phase A0 (plan: Docs/architecture/AI-Assistant-
// Architecture.html in directorschair-server).
//   A0.1 — multiple modification proposals queue and apply sequentially;
//          update_dialogue (scene+index addressing) and add_relationship are
//          advertised and apply end-to-end.
//   A0.2 — the navigate tool covers every AppView, production sub-tabs, and
//          sequence/location/shot selection.
// Tests drive the real parse-and-dispatch path (handleAIResponse) with no
// network round-trip.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class AIChatAssistantTests: XCTestCase {

    private var viewModel: AIChatViewModel!
    private var projectVM: ProjectViewModel!
    private var coordinator: AppCoordinator!

    override func setUp() {
        super.setUp()
        viewModel = AIChatViewModel()
        projectVM = ProjectViewModel(project: Self.makeFixtureProject())
        coordinator = AppCoordinator()
        viewModel.projectViewModel = projectVM
        viewModel.coordinator = coordinator
    }

    override func tearDown() {
        // Remove the on-disk conversation this test's view model created.
        for conversation in viewModel.conversations {
            viewModel.deleteConversation(conversation)
        }
        viewModel = nil
        projectVM = nil
        coordinator = nil
        super.tearDown()
    }

    private static func makeFixtureProject() -> Project {
        var project = Project(name: "Fixture Film")
        let scene = Scene(
            name: "Opening",
            description: "Old description",
            dialogues: [
                Dialogue(character: "Mara", text: "First line"),
                Dialogue(character: "Ilya", text: "Second line"),
            ],
            shots: [Shot(shotId: 12, description: "Wide establishing")]
        )
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        project.characters = [Character(name: "Mara"), Character(name: "Ilya")]
        return project
    }

    // MARK: - ChatToolParser

    func testParserExtractsMultipleToolsAndCleansDisplayText() {
        let response = """
        I'll make both changes.
        [TOOL:modify_project]{"type": "update_project_metadata", "field": "genre", "value": "Noir", "reason": "tone"}[/TOOL]
        [TOOL:modify_project]{"type": "update_scene_description", "scene": "Opening", "text": "New", "reason": "clarity"}[/TOOL]
        Done.
        """
        let parsed = ChatToolParser.parse(response)
        XCTAssertEqual(parsed.tools.count, 2)
        XCTAssertEqual(parsed.tools[0].parameters["field"] as? String, "genre")
        XCTAssertEqual(parsed.tools[1].parameters["scene"] as? String, "Opening")
        XCTAssertFalse(parsed.displayText.contains("[TOOL:"))
        XCTAssertTrue(parsed.displayText.contains("I'll make both changes."))
    }

    // MARK: - A0.1: modification queue

    func testMultipleModificationsQueueAndApplySequentially() async {
        let response = """
        [TOOL:modify_project]{"type": "update_project_metadata", "field": "genre", "value": "Noir", "reason": "r"}[/TOOL]
        [TOOL:modify_project]{"type": "update_scene_description", "scene": "Opening", "text": "Night. Rain.", "reason": "r"}[/TOOL]
        """
        await viewModel.handleAIResponse(response, originalQuery: "restyle it")

        XCTAssertEqual(viewModel.pendingModifications.count, 2,
                       "both proposals must survive in the queue — no overwrite")
        XCTAssertEqual(viewModel.pendingModification?.type, "update_project_metadata")

        viewModel.applyModification()
        XCTAssertEqual(projectVM.project.genre, "Noir")
        XCTAssertEqual(viewModel.pendingModifications.count, 1,
                       "the next proposal becomes the presented card")
        XCTAssertEqual(viewModel.pendingModification?.type, "update_scene_description")

        viewModel.applyModification()
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].description, "Night. Rain.")
        XCTAssertTrue(viewModel.pendingModifications.isEmpty)
    }

    func testRejectDropsOnlyTheHeadOfTheQueue() async {
        let response = """
        [TOOL:modify_project]{"type": "update_project_metadata", "field": "genre", "value": "Noir", "reason": "r"}[/TOOL]
        [TOOL:modify_project]{"type": "update_project_metadata", "field": "status", "value": "Locked", "reason": "r"}[/TOOL]
        """
        await viewModel.handleAIResponse(response, originalQuery: "q")
        viewModel.rejectModification()

        XCTAssertNotEqual(projectVM.project.genre, "Noir", "declined edits must not apply")
        XCTAssertEqual(viewModel.pendingModifications.count, 1)
        viewModel.applyModification()
        XCTAssertEqual(projectVM.project.status, "Locked")
    }

    func testQueueClearsWhenStartingANewConversation() async {
        let response = """
        [TOOL:modify_project]{"type": "update_project_metadata", "field": "genre", "value": "Noir", "reason": "r"}[/TOOL]
        """
        await viewModel.handleAIResponse(response, originalQuery: "q")
        XCTAssertFalse(viewModel.pendingModifications.isEmpty)
        viewModel.startNewConversation()
        XCTAssertTrue(viewModel.pendingModifications.isEmpty,
                      "stale proposals must not leak into a new conversation")
    }

    // MARK: - A0.1: newly advertised edit types apply end-to-end

    func testUpdateDialogueBySceneAndIndexApplies() async {
        let response = """
        [TOOL:modify_project]{"type": "update_dialogue", "scene": "Opening", "index": 1, "text": "Rewritten line", "reason": "pacing"}[/TOOL]
        """
        await viewModel.handleAIResponse(response, originalQuery: "punch up Ilya's line")

        XCTAssertEqual(viewModel.pendingModification?.oldValue, "Second line",
                       "the review card must show the real current text")
        viewModel.applyModification()
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].dialogues[1].text,
                       "Rewritten line")
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].dialogues[0].text,
                       "First line", "other dialogues stay untouched")
    }

    func testUpdateDialogueWithOutOfRangeIndexIsANoOp() async {
        let response = """
        [TOOL:modify_project]{"type": "update_dialogue", "scene": "Opening", "index": 9, "text": "X", "reason": "r"}[/TOOL]
        """
        await viewModel.handleAIResponse(response, originalQuery: "q")
        viewModel.applyModification()
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].dialogues.map(\.text),
                       ["First line", "Second line"])
    }

    func testAddRelationshipApplies() async {
        let response = """
        [TOOL:modify_project]{"type": "add_relationship", "character": "Mara", "target": "Ilya", "relationship": "Reluctant ally", "reason": "arc"}[/TOOL]
        """
        await viewModel.handleAIResponse(response, originalQuery: "link them")
        viewModel.applyModification()
        XCTAssertEqual(projectVM.project.characters[0].relationships?["Ilya"],
                       "Reluctant ally")
    }

    // MARK: - A0.2: navigate coverage

    func testNavigateReachesNewViewsAndProductionTab() async {
        let response = """
        [TOOL:navigate]{"view": "production", "production_tab": "gantt"}[/TOOL]
        """
        await viewModel.handleAIResponse(response, originalQuery: "open the gantt")
        XCTAssertEqual(coordinator.selectedView, .production)
        XCTAssertEqual(coordinator.selectedProductionTab, "Gantt")

        await viewModel.handleAIResponse(
            "[TOOL:navigate]{\"view\": \"curation\"}[/TOOL]", originalQuery: "q")
        XCTAssertEqual(coordinator.selectedView, .curation)
    }

    func testNavigateSelectsSequenceAndShot() async {
        await viewModel.handleAIResponse(
            "[TOOL:navigate]{\"view\": \"scenes\", \"sequence\": \"Act 1\"}[/TOOL]",
            originalQuery: "q")
        XCTAssertEqual(coordinator.selectedSequence?.name, "Act 1")

        await viewModel.handleAIResponse(
            "[TOOL:navigate]{\"view\": \"shotList\", \"shot\": 12}[/TOOL]",
            originalQuery: "q")
        XCTAssertEqual(coordinator.selectedShot?.shotId, 12)
    }

    func testNavigateWithUnknownEntityStillSwitchesView() async {
        await viewModel.handleAIResponse(
            "[TOOL:navigate]{\"view\": \"shotList\", \"shot\": 999}[/TOOL]",
            originalQuery: "q")
        XCTAssertEqual(coordinator.selectedView, .shotList,
                       "an unresolvable selector must not block the view switch")
    }

    // MARK: - System prompt advertises the full surface

    func testSystemPromptAdvertisesAllToolsAndViews() {
        let prompt = viewModel.buildSystemPrompt(query: "")
        for expected in ["update_character_trait", "update_character_bio",
                         "update_scene_description", "update_dialogue",
                         "update_project_metadata", "add_relationship",
                         "curation", "playback", "production_tab"] {
            XCTAssertTrue(prompt.contains(expected),
                          "system prompt must advertise \(expected)")
        }
    }

    // MARK: - Context builder exposes dialogue indices

    func testSceneContextListsDialogueIndices() {
        let context = AIChatContext(
            currentView: .scenes,
            selectedScene: projectVM.project.sequences[0].scenes[0])
        let text = ProjectContextBuilder.buildContext(
            project: projectVM.project, context: context, query: "dialogue")
        XCTAssertTrue(text.contains("[0] Mara:"),
                      "dialogue indices are the assistant's edit handles")
        XCTAssertTrue(text.contains("[1] Ilya:"))
    }
}
