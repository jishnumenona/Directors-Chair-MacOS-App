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
}
