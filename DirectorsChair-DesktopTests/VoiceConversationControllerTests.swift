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

    func testVoicePickerPrefersPremiumThenExactLanguage() {
        typealias V = (id: String, language: String, qualityRank: Int)
        let voices: [V] = [
            ("compact-us", "en-US", 0),
            ("enhanced-gb", "en-GB", 1),
            ("premium-gb", "en-GB", 2),
            ("premium-us", "en-US", 2),
            ("premium-fr", "fr-FR", 2),
        ]
        XCTAssertEqual(VoiceConversationController.pickVoiceIdentifier(
            voices: voices, language: "en-US"), "premium-us",
            "highest quality, exact language wins")
        XCTAssertEqual(VoiceConversationController.pickVoiceIdentifier(
            voices: voices.filter { $0.id != "premium-us" }, language: "en-US"),
            "premium-gb", "same primary language beats lower quality")
        XCTAssertEqual(VoiceConversationController.pickVoiceIdentifier(
            voices: [("compact-us", "en-US", 0)], language: "en-US"),
            "compact-us", "compact still beats nothing")
        XCTAssertNil(VoiceConversationController.pickVoiceIdentifier(
            voices: [("premium-fr", "fr-FR", 2)], language: "en-US"))
    }

    func testStudioEngineFallsBackToDeviceOnFailure() async throws {
        let (controller, _, _) = makeController()
        var deviceSpoke: [String] = []
        var studioCalls = 0
        controller.speakText = { deviceSpoke.append($0) }
        controller.synthesizeStudioAudio = { _ in
            studioCalls += 1
            throw URLError(.notConnectedToInternet)
        }
        controller.studioEnabled = { true }
        controller.activate()

        controller.speakReply("Hello there")
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(studioCalls, 1)
        XCTAssertEqual(deviceSpoke, ["Hello there"],
                       "offline degrades to the on-device voice")
        XCTAssertEqual(controller.phase, .speaking)
    }

    func testDevicePreferenceSkipsStudioEntirely() {
        let (controller, _, _) = makeController()
        var deviceSpoke: [String] = []
        var studioCalls = 0
        controller.speakText = { deviceSpoke.append($0) }
        controller.synthesizeStudioAudio = { _ in studioCalls += 1; return Data() }
        controller.studioEnabled = { false }
        controller.activate()

        controller.speakReply("Local only")

        XCTAssertEqual(studioCalls, 0, "the free path never touches the network")
        XCTAssertEqual(deviceSpoke, ["Local only"])
    }

    func testSpokenCapCutsLongRepliesAtSentenceBoundary() {
        let short = "Just a short reply."
        XCTAssertEqual(VoiceConversationController.spokenCap(short), short)

        let sentence = "This is a sentence. "
        let long = String(repeating: sentence, count: 80)   // 1,600 chars
        let capped = VoiceConversationController.spokenCap(long)
        XCTAssertTrue(capped.hasSuffix("The rest is in the chat."))
        XCTAssertLessThan(capped.count, 1_100)
        XCTAssertTrue(capped.contains("This is a sentence."))
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
