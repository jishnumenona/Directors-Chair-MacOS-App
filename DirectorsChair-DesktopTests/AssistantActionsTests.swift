// DirectorsChair-DesktopTests/AssistantActionsTests.swift
//
// AI Assistant program, Phase A2.5: the first real AssistantActions —
// validate previews (real old values, hard errors on missing entities),
// execute through the live app seams, navigation coverage, and the
// TurnPlan apply/undo path on the view model. Supersedes the A0-era
// AIChatAssistantTests, which drove the deleted regex-tag path.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var coordinator: AppCoordinator!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        projectVM = ProjectViewModel(project: Self.makeFixtureProject())
        coordinator = AppCoordinator()
        registry = AssistantActionFactory.makeRegistry(
            projectViewModel: projectVM, coordinator: coordinator)
    }

    override func tearDown() {
        projectVM = nil
        coordinator = nil
        registry = nil
        super.tearDown()
    }

    private static func makeFixtureProject() -> Project {
        var project = Project(name: "Fixture Film")
        project.genre = "Drama"
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

    private func args(_ json: String) -> Data {
        Data(json.utf8)
    }

    private func action(_ name: String) -> any AssistantAction {
        guard let action = registry.action(named: name) else {
            XCTFail("action \(name) not registered")
            fatalError()
        }
        return action
    }

    // MARK: - Factory

    func testFactoryRegistersTheFullCatalog() {
        XCTAssertEqual(registry.count, 48)   // + creative 6 + world 4 + script 3 + generation 7
        for name in ["web_search", "navigate", "update_character_trait",
                     "update_character_bio", "update_scene_description",
                     "update_dialogue", "update_project_metadata",
                     "add_relationship"] {
            XCTAssertNotNil(registry.action(named: name), name)
        }
        // every definition carries an object schema for the gateway
        for definition in registry.toolDefinitions {
            XCTAssertNotNil(definition.parameters.objectValue, definition.name)
        }
    }

    // MARK: - Mutating actions: validate previews + execute

    func testUpdateDialogueValidatePreviewsOldValueAndExecuteApplies() async throws {
        let dialogue = action("update_dialogue")
        let payload = args(#"{"scene": "Opening", "index": 1, "text": "Rewritten"}"#)

        let plan = try dialogue.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.first?.oldValue, "Second line")
        XCTAssertEqual(plan.previews.first?.newValue, "Rewritten")

        _ = try await dialogue.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].dialogues[1].text,
                       "Rewritten")
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].dialogues[0].text,
                       "First line")
        XCTAssertTrue(projectVM.isDirty)
    }

    func testUpdateDialogueOutOfRangeThrowsInsteadOfNoOp() {
        let dialogue = action("update_dialogue")
        XCTAssertThrowsError(try dialogue.validate(argumentsData:
            args(#"{"scene": "Opening", "index": 9, "text": "X"}"#))) { error in
            XCTAssertTrue("\(error)".contains("out of range"))
        }
    }

    func testUnknownCharacterThrowsWithKnownNames() {
        let trait = action("update_character_trait")
        XCTAssertThrowsError(try trait.validate(argumentsData:
            args(#"{"character": "Nobody", "trait": "Creativity", "value": 80}"#))) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("not found"))
            XCTAssertTrue(message.contains("Mara"), "error should list known names")
        }
    }

    func testUpdateCharacterTraitExecutes() async throws {
        let trait = action("update_character_trait")
        let payload = args(#"{"character": "Mara", "trait": "Creativity", "value": 91}"#)
        _ = try trait.validate(argumentsData: payload)
        _ = try await trait.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.characters[0].traits["Creativity"], 91)
    }

    func testUpdateCharacterBioAndRelationshipExecute() async throws {
        let bio = action("update_character_bio")
        _ = try await bio.execute(argumentsData:
            args(#"{"character": "Mara", "field": "occupation", "value": "Physicist"}"#))
        XCTAssertEqual(projectVM.project.characters[0].occupation, "Physicist")

        let relationship = action("add_relationship")
        let payload = args(#"{"character": "Mara", "target": "Ilya", "relationship": "Ally"}"#)
        let plan = try relationship.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.first?.oldValue, "none")
        _ = try await relationship.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.characters[0].relationships?["Ilya"], "Ally")
    }

    func testUpdateSceneDescriptionAndMetadataExecute() async throws {
        let scene = action("update_scene_description")
        _ = try await scene.execute(argumentsData:
            args(#"{"scene": "Opening", "text": "Night. Rain."}"#))
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].description,
                       "Night. Rain.")

        let metadata = action("update_project_metadata")
        let payload = args(#"{"field": "genre", "value": "Noir"}"#)
        let plan = try metadata.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.first?.oldValue, "Drama")
        _ = try await metadata.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.genre, "Noir")
    }

    // MARK: - Navigation

    func testNavigateOpensViewsSelectsEntitiesAndProductionTab() async throws {
        let navigate = action("navigate")
        _ = try await navigate.execute(argumentsData: args(
            #"{"view": "production", "production_tab": "gantt"}"#))
        XCTAssertEqual(coordinator.selectedView, .production)
        XCTAssertEqual(coordinator.selectedProductionTab, "Gantt")

        _ = try await navigate.execute(argumentsData: args(
            #"{"view": "shotList", "shot": 12}"#))
        XCTAssertEqual(coordinator.selectedShot?.shotId, 12)

        let outcome = try await navigate.execute(argumentsData: args(
            #"{"view": "scenes", "sequence": "Act 1"}"#))
        XCTAssertEqual(coordinator.selectedSequence?.name, "Act 1")
        XCTAssertTrue(outcome.userSummary.contains("Act 1"))
    }

    func testNavigateUnknownViewThrows() {
        let navigate = action("navigate")
        XCTAssertThrowsError(try navigate.validate(argumentsData:
            args(#"{"view": "wormhole"}"#)))
    }

    // MARK: - TurnPlan apply + whole-turn undo on the view model (AD5)

    func testApplyTurnPlanAppliesSelectedItemsAndUndoRestores() async throws {
        let viewModel = AIChatViewModel()
        viewModel.projectViewModel = projectVM
        viewModel.coordinator = coordinator
        defer {
            for conversation in viewModel.conversations {
                viewModel.deleteConversation(conversation)
            }
        }

        let planItem = ProposedActionItem(
            id: "call_1", actionName: "update_scene_description",
            plan: ActionPlan(summary: "Rewrite Opening"),
            argumentsData: args(#"{"scene": "Opening", "text": "Night. Rain."}"#))
        let skippedItem = ProposedActionItem(
            id: "call_2", actionName: "update_project_metadata",
            plan: ActionPlan(summary: "Set genre"),
            argumentsData: args(#"{"field": "genre", "value": "Noir"}"#))
        viewModel.turnPlan = TurnPlan(items: [planItem, skippedItem])

        viewModel.applyTurnPlan(selectedIds: ["call_1"])   // selective apply
        try await Task.sleep(nanoseconds: 100_000_000)      // let the apply Task run

        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].description,
                       "Night. Rain.")
        XCTAssertEqual(projectVM.project.genre, "Drama",
                       "unselected proposals must not apply")
        XCTAssertNil(viewModel.turnPlan)
        XCTAssertTrue(viewModel.canUndoAssistantChanges)

        viewModel.undoAssistantChanges()
        XCTAssertEqual(projectVM.project.sequences[0].scenes[0].description,
                       "Old description", "undo restores the whole-turn snapshot")
        XCTAssertFalse(viewModel.canUndoAssistantChanges)
    }
}
