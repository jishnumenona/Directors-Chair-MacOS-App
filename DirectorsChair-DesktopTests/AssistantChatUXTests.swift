// DirectorsChair-DesktopTests/AssistantChatUXTests.swift
//
// Assistant chat UX round 2 (owner live-drive requests): voice-input merge
// semantics (the hardware-free half of SpeechDictationController) and
// conversation continuity — the widget resumes the latest conversation
// instead of opening blank.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class AssistantChatUXTests: XCTestCase {

    // MARK: - Dictation merge semantics

    func testMergedInputPreservesTypedPrefixAndReplacesPartials() {
        // Nothing typed: transcript is the field.
        XCTAssertEqual(SpeechDictationController.mergedInput(
            typedPrefix: "", transcript: "schedule the finale"),
            "schedule the finale")
        // Typed prefix joined with exactly one space.
        XCTAssertEqual(SpeechDictationController.mergedInput(
            typedPrefix: "Please", transcript: "add a scene"),
            "Please add a scene")
        XCTAssertEqual(SpeechDictationController.mergedInput(
            typedPrefix: "Please ", transcript: "add a scene"),
            "Please add a scene")
        // Empty transcript leaves the typed text untouched.
        XCTAssertEqual(SpeechDictationController.mergedInput(
            typedPrefix: "Draft", transcript: ""), "Draft")
        // Cumulative partials REPLACE: merging a longer partial over the
        // same prefix must not duplicate the earlier words.
        let first = SpeechDictationController.mergedInput(
            typedPrefix: "", transcript: "generate all")
        let second = SpeechDictationController.mergedInput(
            typedPrefix: "", transcript: "generate all images for Alexander")
        XCTAssertEqual(first, "generate all")
        XCTAssertEqual(second, "generate all images for Alexander")
    }

    func testDictationControllerStartsIdleWithNoTranscript() {
        let controller = SpeechDictationController()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(controller.isRecording)
        XCTAssertEqual(controller.transcript, "")
        XCTAssertNil(controller.problemMessage)
    }

    // MARK: - Bare ⌘-tap detection (hands-free dictation toggle)

    func testBareCommandTapFiresOnlyForCleanPressAndRelease() {
        var detector = BareModifierTapDetector()

        // Clean tap: down → up fires.
        XCTAssertFalse(detector.handle(.modifierDown))
        XCTAssertTrue(detector.handle(.modifierUp))

        // A shortcut chord (⌘C): down → key interrupt → up must NOT fire.
        XCTAssertFalse(detector.handle(.modifierDown))
        XCTAssertFalse(detector.handle(.interrupted))
        XCTAssertFalse(detector.handle(.modifierUp))

        // Another modifier joining (⌘⇧) cancels the tap too.
        XCTAssertFalse(detector.handle(.modifierDown))
        XCTAssertFalse(detector.handle(.interrupted))
        XCTAssertFalse(detector.handle(.modifierUp))

        // A release with no prior press never fires.
        XCTAssertFalse(detector.handle(.modifierUp))

        // The detector re-arms: consecutive clean taps each fire.
        XCTAssertFalse(detector.handle(.modifierDown))
        XCTAssertTrue(detector.handle(.modifierUp))
        XCTAssertFalse(detector.handle(.modifierDown))
        XCTAssertTrue(detector.handle(.modifierUp))
    }

    // MARK: - Conversation continuity

    func testViewModelResumesTheLatestConversationOnInit() throws {
        // Seed a persisted conversation the way the VM saves them.
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DirectorsChair/chat_history")
        try FileManager.default.createDirectory(at: dir,
                                                withIntermediateDirectories: true)
        var conversation = ChatConversation(title: "Continuity check")
        conversation.messages = [
            ChatMessage(role: .user, content: "remember me"),
            ChatMessage(role: .assistant, content: "of course"),
        ]
        conversation.updatedAt = Date()
        let file = dir.appendingPathComponent("\(conversation.id.uuidString).json")
        try JSONEncoder().encode(conversation).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let viewModel = AIChatViewModel()

        XCTAssertEqual(viewModel.messages.map(\.content).suffix(2),
                       ["remember me", "of course"],
                       "a fresh widget must resume the latest conversation")

        // The welcome message never injects into resumed history.
        viewModel.addWelcomeMessageIfNeeded()
        XCTAssertFalse(viewModel.messages.contains {
            $0.content.contains("Welcome to Director's Chair")
        })
    }

    // MARK: - A6.1: compact project index (context tiers retired)

    func testProjectIndexIsSmallAndContentFree() {
        var project = Project(name: "Big Film")
        project.genre = "Epic"
        // A big project: 40 scenes with long dialogue that must NOT leak in.
        let secret = "SECRET-DIALOGUE-CONTENT-THAT-MUST-NOT-APPEAR"
        var scenes: [Scene] = []
        for i in 1...40 {
            scenes.append(Scene(
                name: "Scene \(i)", description: String(repeating: "desc ", count: 200),
                dialogues: (1...10).map { _ in
                    Dialogue(character: "Mara", text: secret + String(repeating: "x", count: 500))
                }))
        }
        project.sequences = [Sequence(name: "Act 1", scenes: scenes)]
        project.characters = [Character(name: "Mara"), Character(name: "Ilya")]
        project.scheduleItems = [ScheduleItem(sceneName: "Scene 1",
                                              shootDate: "2026-08-01")]

        let index = ProjectContextBuilder.buildContext(project: project,
                                                       context: nil)

        XCTAssertFalse(index.contains(secret), "dialogue content must never leak")
        XCTAssertFalse(index.contains("desc desc"), "descriptions must never leak")
        XCTAssertTrue(index.contains("Scene 40 (10d/0sh)"), "scene names + counts present")
        XCTAssertTrue(index.contains("Characters: Mara, Ilya"))
        XCTAssertTrue(index.contains("1 schedule items"))
        XCTAssertLessThan(index.count, 4_000,
                          "the index stays small even for large projects (was ~25k-token dumps)")
        XCTAssertTrue(index.contains("fetch content with the read tools"))
    }

    // MARK: - A6.3: proactive checks (opt-in, deterministic, zero-cost)

    func testProactiveChecksFlagConflictsOnceWhenEnabled() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: PrefKey.assistantProactiveChecks)
        defer {
            if let previous { defaults.set(previous, forKey: PrefKey.assistantProactiveChecks) }
            else { defaults.removeObject(forKey: PrefKey.assistantProactiveChecks) }
        }

        var project = Project(name: "Fixture Film")
        project.scheduleItems = [
            ScheduleItem(sceneName: "Opening", shootDate: "2026-08-01",
                         timeSlot: "Morning", status: "Planned",
                         location: "Stage 4", requiredActors: ["Ada Vale"]),
            ScheduleItem(sceneName: "Finale", shootDate: "2026-08-01",
                         timeSlot: "Morning", status: "Planned",
                         location: "Rooftop", requiredActors: ["Ada Vale"]),
        ]
        let pvm = ProjectViewModel(project: project)

        // Off (default): silent.
        defaults.set(false, forKey: PrefKey.assistantProactiveChecks)
        let quiet = AIChatViewModel()
        quiet.projectViewModel = pvm
        let quietBefore = quiet.messages.count
        quiet.runProactiveChecksIfEnabled()
        XCTAssertEqual(quiet.messages.count, quietBefore, "opt-in means silent by default")

        // On: exactly one heads-up, and only once per open.
        defaults.set(true, forKey: PrefKey.assistantProactiveChecks)
        let vocal = AIChatViewModel()
        vocal.projectViewModel = pvm
        let before = vocal.messages.count
        vocal.runProactiveChecksIfEnabled()
        vocal.runProactiveChecksIfEnabled()
        let added = vocal.messages.suffix(from: before).map(\.content)
        XCTAssertEqual(added.count, 1, "one heads-up per open, never repeated")
        XCTAssertTrue(added[0].contains("schedule conflict"), added[0])
    }

    // MARK: - A6.5: routing table (Preferences → engine configuration)

    func testRoutedConfigurationValidatesProviderAndClampsTemperature() {
        let defaults = UserDefaults.standard
        let prevProvider = defaults.object(forKey: PrefKey.aiChatProvider)
        let prevTemp = defaults.object(forKey: PrefKey.aiTemperature)
        defer {
            defaults.removeObject(forKey: PrefKey.aiChatProvider)
            defaults.removeObject(forKey: PrefKey.aiTemperature)
            if let prevProvider { defaults.set(prevProvider, forKey: PrefKey.aiChatProvider) }
            if let prevTemp { defaults.set(prevTemp, forKey: PrefKey.aiTemperature) }
        }

        // Defaults: google, 0.7.
        defaults.removeObject(forKey: PrefKey.aiChatProvider)
        defaults.removeObject(forKey: PrefKey.aiTemperature)
        var config = AssistantRuntime.routedConfiguration()
        XCTAssertEqual(config.provider, "google")
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.001)

        // A valid choice routes through.
        defaults.set("anthropic", forKey: PrefKey.aiChatProvider)
        defaults.set(0.3, forKey: PrefKey.aiTemperature)
        config = AssistantRuntime.routedConfiguration()
        XCTAssertEqual(config.provider, "anthropic")
        XCTAssertEqual(config.temperature, 0.3, accuracy: 0.001)

        // Junk falls back safely; temperature clamps.
        defaults.set("skynet", forKey: PrefKey.aiChatProvider)
        defaults.set(9.0, forKey: PrefKey.aiTemperature)
        config = AssistantRuntime.routedConfiguration()
        XCTAssertEqual(config.provider, "google", "unknown provider → default")
        XCTAssertEqual(config.temperature, 1.0, "temperature clamped to 0…1")
    }

    // MARK: - Reply provenance (local vs third-party AI)

    func testProviderDisplayNamesFollowRoutingTable() {
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: PrefKey.aiChatProvider) }

        defaults.set("anthropic", forKey: PrefKey.aiChatProvider)
        XCTAssertEqual(AIChatViewModel.routedProviderDisplayName(), "Claude")
        defaults.set("deepseek", forKey: PrefKey.aiChatProvider)
        XCTAssertEqual(AIChatViewModel.routedProviderDisplayName(), "DeepSeek")
        defaults.set("google", forKey: PrefKey.aiChatProvider)
        XCTAssertEqual(AIChatViewModel.routedProviderDisplayName(), "Gemini")
    }

    func testChatMessageDecodesLegacyJSONWithoutProvenanceFields() throws {
        // A message persisted before source/entityRefs existed.
        let legacy = """
        {"id":"\(UUID().uuidString)","role":"assistant",
         "content":"old reply","timestamp":712345678.0}
        """
        let message = try JSONDecoder().decode(ChatMessage.self,
                                               from: Data(legacy.utf8))
        XCTAssertNil(message.source)
        XCTAssertNil(message.entityRefs)

        // And the new fields round-trip.
        let tagged = ChatMessage(
            role: .assistant, content: "hi",
            source: .cloud(provider: "Gemini"),
            entityRefs: [.init(kind: "character", name: "Maya",
                               imagePath: "assets/characters/maya.png")])
        let decoded = try JSONDecoder().decode(
            ChatMessage.self, from: JSONEncoder().encode(tagged))
        XCTAssertEqual(decoded.source, .cloud(provider: "Gemini"))
        XCTAssertEqual(decoded.entityRefs?.first?.name, "Maya")
    }

    // MARK: - Referenced-entity thumbnails

    /// The chat VM holds its project weakly — return both so tests keep
    /// the project alive.
    @MainActor
    private func makeEntityRefViewModel() -> (AIChatViewModel, ProjectViewModel) {
        var project = Project(name: "Refs")
        var maya = Character(name: "Maya")
        maya.baseImage = "assets/characters/Maya/base.png"
        var rob = Character(name: "Rob")
        rob.avatar = "assets/characters/Rob/avatar.png"
        let uninked = Character(name: "Extra")   // no artwork
        project.characters = [maya, rob, uninked]
        var rooftop = Location(name: "Rooftop")
        rooftop.primaryImage = "assets/locations/Rooftop/primary.png"
        project.locations = [rooftop]
        var opening = Scene(name: "Opening", description: "")
        opening.sceneOverviewImage = "assets/scenes/Opening/overview.png"
        project.sequences = [Sequence(name: "Act 1", scenes: [opening])]

        let viewModel = AIChatViewModel()
        let projectVM = ProjectViewModel(project: project)
        viewModel.projectViewModel = projectVM
        return (viewModel, projectVM)
    }

    func testEntityRefsMatchWholeWordsInFirstOccurrenceOrder() {
        let (viewModel, projectVM) = makeEntityRefViewModel()
        _ = projectVM  // retained for the weak seam

        let refs = viewModel.entityRefs(
            in: "Shoot the Rooftop scene with Maya at dusk.")
        XCTAssertEqual(refs?.map(\.name), ["Rooftop", "Maya"],
                       "first-occurrence order")
        XCTAssertEqual(refs?.map(\.kind), ["location", "character"])

        // Word boundaries: "Robert" must not surface Rob's thumbnail.
        XCTAssertNil(viewModel.entityRefs(in: "Ask Robert about the crane."))

        // Case-insensitive; entities without artwork never match.
        let shouted = viewModel.entityRefs(in: "MAYA enters. Extra follows.")
        XCTAssertEqual(shouted?.map(\.name), ["Maya"])

        // Mentions repeated across the reply dedupe to one chip.
        let repeated = viewModel.entityRefs(
            in: "Maya looks up. Maya runs. Maya, again, on the Rooftop.")
        XCTAssertEqual(repeated?.map(\.name), ["Maya", "Rooftop"])

        XCTAssertNil(viewModel.entityRefs(in: "Nothing relevant here."))
    }

    func testEntityRefsIncludeScenesAndCapAtFour() {
        let (viewModel, projectVM) = makeEntityRefViewModel()

        let refs = viewModel.entityRefs(in: "Review the Opening scene.")
        XCTAssertEqual(refs?.first?.kind, "scene")
        XCTAssertEqual(refs?.first?.imagePath,
                       "assets/scenes/Opening/overview.png")

        projectVM.project.characters = (1...6).map { index in
            var character = Character(name: "Crewman\(index)")
            character.avatar = "assets/characters/c\(index).png"
            return character
        }
        let many = viewModel.entityRefs(
            in: "Crewman1 Crewman2 Crewman3 Crewman4 Crewman5 Crewman6")
        XCTAssertEqual(many?.count, 4, "capped so the strip stays compact")
    }
}
