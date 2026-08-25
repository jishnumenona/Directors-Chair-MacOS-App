// DirectorsChairServicesTests/ModelChoiceTests.swift
//
// DC-0059: per-provider model choice, the local-model catalog, and
// on-device chat. Same honesty rules as the service catalog: no model is
// offered where the adapter would ignore it, defaults match the server's
// documented fallbacks, and the local chat transport converses without
// ever inventing a tool call.

import XCTest
@testable import DirectorsChairServices

final class ModelChoiceTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suite = "model-choice-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Model catalog honesty

    func testModelChoiceExistsOnlyWhereAdaptersHonorIt() {
        // Veo ignores request models (adapter-pinned) — no picker may
        // pretend otherwise; speech only ElevenLabs would honor.
        for wireId in ["google_veo"] {
            XCTAssertFalse(AIModelCatalog.hasChoice(for: .video, wireId: wireId))
        }
        XCTAssertFalse(AIModelCatalog.hasChoice(for: .speech, wireId: "google"))
        XCTAssertFalse(AIModelCatalog.hasChoice(for: .voiceReplies, wireId: "gemini"))
        // Text/chat/image server providers do offer choice.
        XCTAssertTrue(AIModelCatalog.hasChoice(for: .text, wireId: "google"))
        XCTAssertTrue(AIModelCatalog.hasChoice(for: .chat, wireId: "anthropic"))
        // The local model's choice lives in LocalModelCatalog, not here.
        XCTAssertFalse(AIModelCatalog.hasChoice(for: .text, wireId: "device"))
    }

    func testEveryModelListStartsWithServerDefault() {
        for function in AIFunction.allCases {
            for option in AIProviderCatalog.options(for: function) {
                let models = AIModelCatalog.options(for: function, wireId: option.wireId)
                if let first = models.first {
                    XCTAssertEqual(first, .serverDefault,
                                   "\(function.rawValue)/\(option.wireId)")
                }
            }
        }
    }

    // MARK: - Model resolution

    func testModelIdFollowsTheSelectedServiceAndCustomPassesThrough() {
        let defaults = freshDefaults()
        let selection = AIProviderSelection(defaults: defaults)

        // Nothing stored → nil → the request omits the field.
        XCTAssertNil(selection.modelId(for: .text))

        // The model rides the (function, service) pair: a Gemini model
        // stored while DeepSeek is selected must NOT leak onto DeepSeek.
        defaults.set("gemini-2.5-pro", forKey: AIProviderSelection.modelKey(
            function: .text, wireId: "google"))
        XCTAssertEqual(selection.modelId(for: .text), "gemini-2.5-pro")
        defaults.set("deepseek", forKey: AIFunction.text.preferenceKey)
        XCTAssertNil(selection.modelId(for: .text))

        // Custom ids pass through verbatim (power users own the risk).
        defaults.set("deepseek-reasoner-preview-42", forKey:
            AIProviderSelection.modelKey(function: .text, wireId: "deepseek"))
        XCTAssertEqual(selection.modelId(for: .text), "deepseek-reasoner-preview-42")
    }

    // MARK: - Local model catalog

    func testLocalModelCatalogSelectionDegradesSafely() {
        let defaults = freshDefaults()
        XCTAssertEqual(LocalModelCatalog.selected(in: defaults).id,
                       MLXInsightEngine.defaultModelId, "default = the proven 3B")
        defaults.set("mlx-community/Qwen2.5-7B-Instruct-4bit",
                     forKey: LocalModelCatalog.preferenceKey)
        XCTAssertEqual(LocalModelCatalog.selected(in: defaults).displayName,
                       "Qwen 2.5 7B (best quality)")
        defaults.set("no-such/model", forKey: LocalModelCatalog.preferenceKey)
        XCTAssertEqual(LocalModelCatalog.selected(in: defaults).id,
                       MLXInsightEngine.defaultModelId, "unknown id degrades")
    }

    func testEngineFollowsTheLocalModelChoicePerModelMarkers() async throws {
        let defaults = freshDefaults()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-choice-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = MLXInsightEngine(storageRoot: root, modelDefaults: defaults)

        #if arch(arm64)
        // 3B marker on disk, 3B selected → ready.
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent(
            ".ready-mlx-community_Qwen2.5-3B-Instruct-4bit"))
        var state = await engine.availability()
        XCTAssertEqual(state, .ready)
        XCTAssertTrue(engine.isModelDownloaded(MLXInsightEngine.defaultModelId))

        // Switch to the 7B → ITS weights aren't there → needs ITS download.
        defaults.set("mlx-community/Qwen2.5-7B-Instruct-4bit",
                     forKey: LocalModelCatalog.preferenceKey)
        state = await engine.availability()
        XCTAssertEqual(state, .needsDownload(expectedBytes: 4_400_000_000))
        XCTAssertFalse(engine.isModelDownloaded("mlx-community/Qwen2.5-7B-Instruct-4bit"))
        #endif
    }

    // MARK: - On-device chat

    func testLocalChatTransportConversesAndNeverEmitsToolCalls() async throws {
        final class Recorder: OnDeviceTextResponding, @unchecked Sendable {
            var prompts: [String] = []
            var systems: [String?] = []
            func respond(prompt: String, systemPrompt: String?,
                         maxTokens: Int, temperature: Double) async throws -> String {
                prompts.append(prompt); systems.append(systemPrompt)
                return "A local answer."
            }
        }
        let recorder = Recorder()
        let transport = LocalChatTransport(engine: recorder)
        let request = ChatRequestBody(messages: [
            .system("Catalog and rules."),
            .user("What's scene 2 about?"),
        ])

        var events: [ChatStreamEvent] = []
        for try await event in transport.stream(request) { events.append(event) }

        XCTAssertEqual(events, [.delta("A local answer."),
                                .done(finishReason: "stop", model: "on-device")])
        // The flattened prompt carries the conversation, role-tagged…
        let prompt = try XCTUnwrap(recorder.prompts.first)
        XCTAssertTrue(prompt.contains("Context: Catalog and rules."))
        XCTAssertTrue(prompt.contains("User: What's scene 2 about?"))
        XCTAssertTrue(prompt.hasSuffix("Assistant:"))
        // …and the conversation-only limitation rides the REAL system slot,
        // verbatim — identity, not phrasing, so rewording the note (as
        // DC-0060's refusal fix did) can never silently strand this test.
        XCTAssertEqual(try XCTUnwrap(recorder.systems.first),
                       LocalChatTransport.conversationOnlyNote)
    }

    func testLocalChatTransportRefusalBecomesAReadableErrorEvent() async throws {
        final class Refuser: OnDeviceTextResponding, @unchecked Sendable {
            func respond(prompt: String, systemPrompt: String?,
                         maxTokens: Int, temperature: Double) async throws -> String {
                throw InsightEngineError.notReady(.needsDownload(expectedBytes: 1))
            }
        }
        let transport = LocalChatTransport(engine: Refuser())
        var events: [ChatStreamEvent] = []
        for try await event in transport.stream(
            ChatRequestBody(messages: [.user("hi")])) { events.append(event) }

        guard case .error(let message)? = events.first else {
            return XCTFail("expected a readable error event, got \(events)")
        }
        XCTAssertTrue(message.contains("isn't ready"), message)
    }

    func testFlattenTrimsFromTheFrontUnderTheBudget() {
        let long = String(repeating: "x", count: 9_000)
        let messages: [ChatMessage] = [
            .system(long), .user(long), .user("the newest question")]
        let flattened = LocalChatTransport.flatten(messages)
        XCTAssertLessThanOrEqual(flattened.count,
                                 LocalChatTransport.historyCharacterBudget + 50)
        XCTAssertTrue(flattened.contains("the newest question"),
                      "the newest turns must survive the trim")
        XCTAssertTrue(flattened.hasPrefix("(earlier conversation trimmed)"))
    }
}
