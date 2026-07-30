// DirectorsChair-DesktopTests/VoiceConversationControllerTests.swift
//
// Hands-free conversation loop: the phase machine (listen → commit →
// think → speak → listen) via injected seams — no audio hardware.

import XCTest
@testable import DirectorsChair_Desktop

@MainActor
final class VoiceConversationControllerTests: XCTestCase {

    private func makeController() -> (VoiceConversationController,
                                      sent: () -> [String],
                                      listens: () -> Int) {
        let controller = VoiceConversationController()
        controller.silenceWindow = 0.05
        var sent: [String] = []
        var listens = 0
        controller.startListening = { listens += 1 }
        controller.stopListening = {}
        controller.sendUtterance = { sent.append($0) }
        controller.speakText = { _ in }   // swallow real speech
        return (controller, { sent }, { listens })
    }

    func testSilenceCommitsUtteranceOnce() async throws {
        let (controller, sent, _) = makeController()
        controller.activate()
        XCTAssertEqual(controller.phase, .listening)

        controller.transcriptChanged("add a")
        controller.transcriptChanged("add a scene")   // still talking
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(sent(), ["add a scene"], "stable transcript commits")
        XCTAssertEqual(controller.phase, .thinking)

        // Late transcript noise after commit is ignored.
        controller.transcriptChanged("add a scene please")
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(sent().count, 1)
    }

    func testEmptyTranscriptNeverCommits() async throws {
        let (controller, sent, _) = makeController()
        controller.activate()
        controller.transcriptChanged("   ")
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(sent(), [])
        XCTAssertEqual(controller.phase, .listening)
    }

    func testReplySpeaksThenResumesListening() {
        let (controller, _, listens) = makeController()
        controller.activate()
        XCTAssertEqual(listens(), 1)

        controller.speakReply("**Done!** Added the scene.")
        XCTAssertEqual(controller.phase, .speaking)

        controller.speechDidEnd()
        XCTAssertEqual(controller.phase, .listening)
        XCTAssertEqual(listens(), 2, "loop resumes after speech")

        // Deactivation stops the loop cold.
        controller.deactivate()
        controller.speechDidEnd()
        XCTAssertEqual(controller.phase, .idle)
        XCTAssertEqual(listens(), 2)
    }

    func testSpeakableTextStripsMarkdown() {
        XCTAssertEqual(VoiceConversationController.speakableText(
            from: "**Bold** and *italic* with `code`"),
            "Bold and italic with code")
        XCTAssertEqual(VoiceConversationController.speakableText(
            from: "## Heading\n- bullet one\n- bullet two"),
            "Heading\nbullet one\nbullet two")
        XCTAssertEqual(VoiceConversationController.speakableText(
            from: "See [the scene](dc://scene/1) for details"),
            "See the scene for details")
        XCTAssertEqual(VoiceConversationController.speakableText(from: "  "), "")
    }
}
