// DirectorsChair-DesktopTests/AssistantScriptActionsTests.swift
//
// AI Assistant program, Phase A4.2 completion: action lines, narration,
// and dialogue reordering by the [n] indices.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantScriptActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        var project = Project(name: "Fixture Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "d", dialogues: [
                Dialogue(character: "Mara", text: "First"),
                Dialogue(character: "Ilya", text: "Second"),
                Dialogue(character: "Mara", text: "Third"),
            ]),
        ])]
        projectVM = ProjectViewModel(project: project)
        registry = AssistantActionFactory.makeRegistry(
            projectViewModel: projectVM, coordinator: nil)
    }

    override func tearDown() {
        projectVM = nil
        registry = nil
        super.tearDown()
    }

    private func action(_ name: String) -> any AssistantAction {
        registry.action(named: name)!
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    func testAddSceneActionAndNarration() async throws {
        _ = try await action("add_scene_action").execute(argumentsData: args(
            #"{"scene": "Opening", "text": "Rain hammers the skylight."}"#))
        _ = try await action("add_narration").execute(argumentsData: args(
            #"{"scene": "Opening", "text": "It began, as always, with rain."}"#))
        let scene = projectVM.project.sequences[0].scenes[0]
        XCTAssertEqual(scene.actions.last?.description, "Rain hammers the skylight.")
        XCTAssertEqual(scene.narrations.last?.text, "It began, as always, with rain.")
        XCTAssertTrue(projectVM.isDirty)

        XCTAssertThrowsError(try action("add_scene_action").validate(
            argumentsData: args(#"{"scene": "Nowhere", "text": "x"}"#)))
    }

    func testMoveDialogueReordersByIndex() async throws {
        let move = action("move_dialogue")
        let payload = args(#"{"scene": "Opening", "from_index": 2, "to_index": 0}"#)
        let plan = try move.validate(argumentsData: payload)
        XCTAssertTrue(plan.summary.contains("[2] → [0]"))

        _ = try await move.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].dialogues.map(\.text),
                       ["Third", "First", "Second"])

        XCTAssertThrowsError(try move.validate(argumentsData: args(
            #"{"scene": "Opening", "from_index": 0, "to_index": 9}"#)))
        XCTAssertThrowsError(try move.validate(argumentsData: args(
            #"{"scene": "Opening", "from_index": 1, "to_index": 1}"#)))
    }
}
