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
}
