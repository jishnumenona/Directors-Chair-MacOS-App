// DirectorsChair-DesktopTests/AssistantCreativeActionsTests.swift
//
// AI Assistant program, Phase A4 slice 1: story-structure creation actions
// — collision rejection, insert positions, auto shot numbering, canonical
// statuses, and the unknown-character dialogue warning.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantCreativeActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        var project = Project(name: "Fixture Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "d",
                  dialogues: [Dialogue(character: "Mara", text: "Line one")],
                  shots: [Shot(shotId: 7, description: "Wide")]),
            Scene(name: "Finale", description: "d2"),
        ])]
        project.characters = [Character(name: "Mara")]
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

    func testAddSequenceAndDuplicateRejection() async throws {
        let add = action("add_sequence")
        _ = try await add.execute(argumentsData: args(#"{"name": "Act 2"}"#))
        XCTAssertEqual(projectVM.project.sequences.count, 2)
        XCTAssertThrowsError(try add.validate(argumentsData: args(#"{"name": "act 1"}"#)))
    }

    func testAddSceneInsertsAfterAndRejectsCollisions() async throws {
        let add = action("add_scene")
        let payload = args(#"""
        {"name": "Chase", "sequence": "Act 1", "after": "Opening",
         "time_of_day": "Night", "description": "Rooftops."}
        """#)
        _ = try await add.execute(argumentsData: payload)
        let scenes = projectVM.project.sequences[0].scenes
        XCTAssertEqual(scenes.map(\.name), ["Opening", "Chase", "Finale"])
        XCTAssertEqual(scenes[1].timeOfDay, "Night")

        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "Finale", "sequence": "Act 1"}"#)), "duplicate scene name")
        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "X", "sequence": "Act 9"}"#)), "unknown sequence")
    }

    func testUpdateSceneFieldsCanonicalizesStatus() async throws {
        let update = action("update_scene_fields")
        let payload = args(#"{"scene": "Opening", "status": "shooting", "weather": "Rain"}"#)
        let plan = try update.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.count, 2)

        _ = try await update.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].productionStatus,
                       "Shooting")
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].weather, "Rain")
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"scene": "Opening", "status": "Wrapped"}"#)))
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"scene": "Opening"}"#)), "no fields = error")
    }

    func testAddDialogueInsertsAtIndexAndWarnsOnUnknownCharacter() async throws {
        let add = action("add_dialogue")
        let payload = args(#"{"scene": "Opening", "character": "Stranger", "text": "Who's there?", "at_index": 0}"#)
        let plan = try add.validate(argumentsData: payload)
        XCTAssertEqual(plan.warnings.count, 1)

        _ = try await add.execute(argumentsData: payload)
        let dialogues = projectVM.project.sequences[0].scenes[0].dialogues
        XCTAssertEqual(dialogues.map(\.character), ["Stranger", "Mara"])
        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"scene": "Opening", "character": "Mara", "text": "x", "at_index": 9}"#)))
    }

    func testAddShotAutoNumbersAcrossTheProject() async throws {
        let add = action("add_shot")
        let plan = try add.validate(argumentsData: args(
            #"{"scene": "Finale", "description": "Crane down"}"#))
        XCTAssertTrue(plan.summary.contains("#8"), "max shotId 7 → next is 8")

        _ = try await add.execute(argumentsData: args(
            #"{"scene": "Finale", "description": "Crane down", "shot_type": "Wide", "camera_angle": "High"}"#))
        let shot = projectVM.project.sequences[0].scenes[1].shots[0]
        XCTAssertEqual(shot.shotId, 8)
        XCTAssertEqual(shot.shotType, "Wide")
        XCTAssertEqual(shot.cameraAngle, "High")
    }

    func testAddCharacterSetsFieldsAndRejectsDuplicates() async throws {
        let add = action("add_character")
        _ = try await add.execute(argumentsData: args(
            #"{"name": "Ilya", "occupation": "Pilot", "goal": "Fly home"}"#))
        let character = projectVM.project.characters.last
        XCTAssertEqual(character?.occupation, "Pilot")
        XCTAssertEqual(character?.primaryGoal, "Fly home")
        XCTAssertThrowsError(try add.validate(argumentsData: args(#"{"name": "mara"}"#)))
    }
}
