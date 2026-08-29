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
        XCTAssertEqual(registry.count, 54)   // + creative 6 + world 4 + script 3 + generation 7 + pipeline 4 + app-help 1 + storyteller 1
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

    // MARK: - Tier assignments (Product-Versions §3.7)

    func testSpendingGenerationActionsAreCreatorTier() {
        // The matrix's generation + assistant-production spending actions.
        let creatorActions = [
            "generate_character_images", "generate_scene_image",
            "generate_location_images",
            "generate_shot_video", "generate_dialogue_audio",
            "generate_missing_images", "write_character_biography",
            "calibrate_character_traits", "analyze_timeline", "add_expense",
        ]
        for name in creatorActions {
            XCTAssertEqual(action(name).minimumTier, .creator, name)
        }

        // The deliberate Free exceptions, both metered server-side:
        // screenplay import is the critical first-run path (§3.1 footnote
        // 1), and vision-card images are Free's generation taste (§3.4,
        // owner decision 2026-08-12).
        XCTAssertEqual(action("import_screenplay").minimumTier, .free)
        XCTAssertEqual(action("generate_vision_board_image").minimumTier, .free)
        // Storyteller entry is Creator (§3.6) — positioning, not spend
        // protection; the cost sheet and generation actions gate spend.
        XCTAssertEqual(action("start_storyteller").minimumTier, .creator)

        // Consistency: every OTHER spending action must be Creator — a new
        // spending action lands here (with a matrix row) or fails the build.
        let freeSpenders = ["import_screenplay", "generate_vision_board_image"]
        for definition in registry.toolDefinitions {
            guard let act = registry.action(named: definition.name),
                  act.risk == .spending, !freeSpenders.contains(act.name) else {
                continue
            }
            XCTAssertEqual(act.minimumTier, .creator,
                           "\(act.name): spending actions are Creator+ (§3.7)")
        }
    }

    func testProductionMutationsAreCreatorTier() {
        // §3.7 "Production actions": schedule, budget, Gantt, cast/crew,
        // and equipment MUTATIONS are Creator+ — the Production view locks
        // at Free, so the assistant path must not mutate what the UI
        // cannot reach. Reads stay Free (the read/navigate row is ✓).
        let productionMutations = [
            "schedule_scene", "update_schedule_item", "remove_schedule_item",
            "add_gantt_task", "update_gantt_task", "remove_gantt_task",
            "add_cast_member", "add_crew_member", "add_equipment_item",
            "add_budget_category", "update_budget_category",
        ]
        for name in productionMutations {
            XCTAssertEqual(action(name).minimumTier, .creator, name)
        }
        for name in ["get_schedule", "get_schedule_conflicts", "get_gantt",
                     "get_people", "get_equipment", "get_budget_summary"] {
            XCTAssertEqual(action(name).minimumTier, .free,
                           "\(name): production reads stay Free (§3.7)")
        }
    }

    func testStudioSessionAdvertisesTheFullCatalogGoldenPath() {
        // At .studio the tier filter passes the ENTIRE catalog; the
        // DEFAULT session tier is .free (fail-closed since the free
        // launch), so the full catalog only appears when the runtime
        // injects a real Studio claim.
        XCTAssertEqual(EngineConfiguration().sessionTier, .free)
        let advertised = registry.toolDefinitions.filter { definition in
            guard let act = registry.action(named: definition.name) else {
                return false
            }
            return act.minimumTier <= ProductTier.studio
        }
        XCTAssertEqual(advertised.map(\.name),
                       registry.toolDefinitions.map(\.name))
        XCTAssertEqual(advertised.count, 54)
    }

    // MARK: - Storyteller (navigation-class, never spends by itself)

    func testStartStorytellerIsReadOnlyAndFlagsCoordinator() async throws {
        let storyteller = action("start_storyteller")
        XCTAssertEqual(storyteller.risk, .readOnly)
        _ = try storyteller.validate(argumentsData: args("{}"))

        XCTAssertFalse(coordinator.shouldOpenStoryteller)
        let outcome = try await storyteller.execute(argumentsData: args("{}"))
        XCTAssertEqual(coordinator.selectedView, .playback)
        XCTAssertTrue(coordinator.shouldOpenStoryteller,
                      "PlaybackView.onAppear consumes this flag")
        XCTAssertTrue(outcome.resultForModel.contains("confirmed by the user"),
                      "the model is told the cost sheet still gates generation")
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

    /// DC-0078: any spelling of a facet lands on its canonical key; a name
    /// outside the vocabulary is refused with the list, so a character
    /// never grows a 26th trait.
    func testUpdateCharacterTraitNormalisesSpellingAndRefusesUnknownTraits() async throws {
        let trait = action("update_character_trait")
        for (spelling, facet) in [("creativity", "Creativity"), ("open mindedness", "Open-mindedness"),
                                  ("SELF_DISCIPLINE", "Self-discipline")] {
            let payload = args(#"{"character": "Mara", "trait": "\#(spelling)", "value": 64}"#)
            let plan = try trait.validate(argumentsData: payload)
            XCTAssertTrue(plan.summary.contains(facet), plan.summary)
            _ = try await trait.execute(argumentsData: payload)
            XCTAssertEqual(projectVM.project.characters[0].traits[facet], 64)
            XCTAssertNil(projectVM.project.characters[0].traits[spelling == facet ? "" : spelling])
        }
        XCTAssertEqual(projectVM.project.characters[0].traits.count, 25)

        XCTAssertThrowsError(try trait.validate(argumentsData:
            args(#"{"character": "Mara", "trait": "swagger", "value": 80}"#))) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("trait must be one of"), message)
            XCTAssertTrue(message.contains("Open-mindedness"), "the refusal lists the vocabulary")
        }
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


// MARK: - AI preferences wiring (DC-0056)

/// The AI Services pane writes preferences through PrefKey; generation
/// call sites read them through AIFunction.preferenceKey via
/// AIProviderSelection. If the two vocabularies drift, a choice in the
/// pane silently stops applying — this class makes that drift a red test.
/// (Lives in this file, not its own: the synchronized-group gotcha from
/// DC-0038 — a brand-new test file under the app targets may silently
/// never join the bundle.)
final class AIPreferencesWiringTests: XCTestCase {

    func testPaneKeysAndResolutionKeysAgree() {
        XCTAssertEqual(PrefKey.aiChatProvider, AIFunction.chat.preferenceKey)
        XCTAssertEqual(PrefKey.aiTextProvider, AIFunction.text.preferenceKey)
        XCTAssertEqual(PrefKey.aiImageProvider, AIFunction.image.preferenceKey)
        XCTAssertEqual(PrefKey.aiVideoProvider, AIFunction.video.preferenceKey)
        XCTAssertEqual(PrefKey.aiSpeechProvider, AIFunction.speech.preferenceKey)
        XCTAssertEqual(PrefKey.voiceReplyEngine, AIFunction.voiceReplies.preferenceKey)
    }

    func testShippedDefaultsMatchTheCatalogDefaults() {
        XCTAssertEqual(AIProviderCatalog.defaultOption(for: .chat).wireId, "google")
        XCTAssertEqual(AIProviderCatalog.defaultOption(for: .text).wireId, "google")
        XCTAssertEqual(AIProviderCatalog.defaultOption(for: .image).wireId, "google_imagen")
        XCTAssertEqual(AIProviderCatalog.defaultOption(for: .video).wireId, "google_veo")
        XCTAssertEqual(AIProviderCatalog.defaultOption(for: .speech).wireId, "google")
        XCTAssertEqual(AIProviderCatalog.defaultOption(for: .voiceReplies).wireId, "gemini")
    }
}


// MARK: - On-device chat routing (DC-0059 fix)

/// Owner-reported: with AI Chat set to the local model, replies wore a
/// "Gemini" badge — the display map defaulted unknowns to Gemini, and
/// there was no test proving which transport a stored choice yields.
/// Both are pinned here.
final class OnDeviceChatRoutingTests: XCTestCase {

    @MainActor
    func testStoredDeviceChoiceRoutesToTheLocalTransport() {
        let gateway = GatewayChatTransport()
        XCTAssertTrue(AssistantRuntime.chooseTransport(
            provider: "device", gateway: gateway) is LocalChatTransport)
        // Every server provider keeps the gateway transport.
        for provider in ["google", "anthropic", "deepseek", nil] {
            XCTAssertTrue(AssistantRuntime.chooseTransport(
                provider: provider, gateway: gateway) is GatewayChatTransport,
                String(describing: provider))
        }
    }

    @MainActor
    func testRoutedConfigurationHonorsDeviceAndFallsBackOnGarbage() {
        let saved = UserDefaults.standard.string(forKey: PrefKey.aiChatProvider)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: PrefKey.aiChatProvider) }
            else { UserDefaults.standard.removeObject(forKey: PrefKey.aiChatProvider) }
        }
        UserDefaults.standard.set("device", forKey: PrefKey.aiChatProvider)
        XCTAssertEqual(AssistantRuntime.routedConfiguration().provider, "device")
        UserDefaults.standard.set("sora", forKey: PrefKey.aiChatProvider)
        XCTAssertEqual(AssistantRuntime.routedConfiguration().provider, "google")
    }

    @MainActor
    func testReplyProvenanceNamesTheDeviceHonestly() {
        let saved = UserDefaults.standard.string(forKey: PrefKey.aiChatProvider)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: PrefKey.aiChatProvider) }
            else { UserDefaults.standard.removeObject(forKey: PrefKey.aiChatProvider) }
        }
        UserDefaults.standard.set("device", forKey: PrefKey.aiChatProvider)
        XCTAssertEqual(AIChatViewModel.routedProviderDisplayName(), "On-device")
        XCTAssertEqual(AIChatViewModel.routedReplySource(), .onDeviceModel)
        UserDefaults.standard.set("google", forKey: PrefKey.aiChatProvider)
        XCTAssertEqual(AIChatViewModel.routedReplySource(),
                       .cloud(provider: "Gemini"))
    }
}

// MARK: - Storyboard model wiring (DC-0063)

/// The prefs pane's storyboard-model card runs on ServiceHealthModel's
/// pure pieces — worded errors and the engine's displayed identity. If
/// these drift, the consent UI lies about sizes or swallows the disk
/// refusal.
final class StoryboardPrefsWiringTests: XCTestCase {

    func testDiskRefusalWordsBothNumbersAsGuidance() {
        let text = ServiceHealthModel.storyboardErrorText(
            .insufficientDisk(neededBytes: 7_916_000_000, freeBytes: 8_000_000_000))
        XCTAssertTrue(text.contains("7.92 GB"), text)
        XCTAssertTrue(text.contains("8 GB"), text)
        XCTAssertTrue(text.lowercased().contains("free up space"), text)
    }

    func testDownloadFailureCarriesTheReason() {
        let text = ServiceHealthModel.storyboardErrorText(
            .downloadFailed("offline"))
        XCTAssertTrue(text.contains("offline"))
    }

    func testStoryboardModelIdentityMatchesTheConsentContract() {
        // The size shown in the consent button is the engine's approxBytes —
        // measured 5.51GB via the HF API (DC-0063). If the model constant
        // changes, the Product-Versions §3.7 copy must move with it.
        XCTAssertEqual(LocalImageEngine.model.id,
                       "Runpod/FLUX.2-klein-4B-mflux-4bit")
        XCTAssertEqual(LocalImageEngine.model.approxBytes, 4_620_000_000)
        XCTAssertTrue(LocalImageEngine.model.detail.contains("Apache-2.0"))
    }
}
