// DirectorsChairServicesTests/AssistantKitTests.swift
//
// AssistantKit Phase A2.1/A2.2: the neutral wire contract (golden request
// encoding against the gateway A1 schema), the pure SSE parser, the action
// registry, and the generic turn snapshot.

import XCTest
@testable import DirectorsChairServices

final class AssistantKitTests: XCTestCase {

    // MARK: - Request encoding (golden vs the gateway contract)

    func testChatRequestEncodesGatewayWireShape() throws {
        let request = ChatRequestBody(
            messages: [
                .system("Be helpful."),
                .user("Open the scene"),
                .assistant("", toolCalls: [AssistantToolCall(
                    id: "call_1", name: "get_scene",
                    arguments: .object(["name": .string("Opening")]))]),
                .toolResult(callId: "call_1", #"{"description": "Night."}"#),
            ],
            tools: [ToolDefinition(
                name: "get_scene", description: "Read a scene",
                parameters: .object(["type": .string("object")]))],
            provider: "google", maxTokens: 500, temperature: 0.2,
            stream: true, turnId: "turn-1")

        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(request)) as! [String: Any]

        XCTAssertEqual(json["tool_choice"] as? String, "auto")
        XCTAssertEqual(json["max_tokens"] as? Int, 500)
        XCTAssertEqual(json["turn_id"] as? String, "turn-1")
        XCTAssertEqual(json["stream"] as? Bool, true)

        let messages = json["messages"] as! [[String: Any]]
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        let assistant = messages[2]
        let toolCalls = assistant["tool_calls"] as! [[String: Any]]
        XCTAssertEqual(toolCalls[0]["id"] as? String, "call_1")
        XCTAssertEqual((toolCalls[0]["arguments"] as! [String: Any])["name"] as? String,
                       "Opening")
        let toolMessage = messages[3]
        XCTAssertEqual(toolMessage["role"] as? String, "tool")
        XCTAssertEqual(toolMessage["tool_call_id"] as? String, "call_1")

        let tools = json["tools"] as! [[String: Any]]
        XCTAssertEqual(tools[0]["name"] as? String, "get_scene")
    }

    func testImageContentPartUsesSnakeCaseMimeType() throws {
        let message = ChatMessage.user([.image(base64: "QUJD", mimeType: "image/jpeg")])
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(message)) as! [String: Any]
        let part = (json["content"] as! [[String: Any]])[0]
        XCTAssertEqual(part["type"] as? String, "image")
        XCTAssertEqual(part["mime_type"] as? String, "image/jpeg")
        XCTAssertEqual(part["data"] as? String, "QUJD")
    }

    func testJSONValueRoundTrip() throws {
        let value = JSONValue.object([
            "name": .string("Opening"), "index": .number(2),
            "flag": .bool(true), "list": .array([.string("a"), .null])])
        let data = try value.encodedData()
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    // MARK: - SSE parser

    private func drain(_ text: String) -> [ChatStreamEvent] {
        var parser = SSEEventParser()
        var events: [ChatStreamEvent] = []
        for line in text.components(separatedBy: "\n") {
            if let event = parser.feed(line: line) { events.append(event) }
        }
        if let last = parser.finish() { events.append(last) }
        return events
    }

    func testParserDecodesFullEventSequence() {
        let stream = """
        event: message.delta
        data: {"text": "Think"}

        event: message.delta
        data: {"text": "ing…"}

        event: tool_call
        data: {"id": "call_0", "name": "get_scene", "arguments": {"name": "Opening"}}

        event: usage
        data: {"prompt_tokens": 11, "completion_tokens": 7, "total_tokens": 18}

        event: done
        data: {"finish_reason": "tool_calls", "model": "gemini-2.5-flash"}

        """
        let events = drain(stream)
        XCTAssertEqual(events.count, 5)
        XCTAssertEqual(events[0], .delta("Think"))
        XCTAssertEqual(events[1], .delta("ing…"))
        guard case .toolCall(let call) = events[2] else {
            return XCTFail("expected tool_call")
        }
        XCTAssertEqual(call.name, "get_scene")
        XCTAssertEqual(call.arguments.objectValue?["name"]?.stringValue, "Opening")
        XCTAssertEqual(events[4], .done(finishReason: "tool_calls",
                                        model: "gemini-2.5-flash"))
    }

    func testParserIgnoresKeepalivesAndUnknownEvents() {
        let stream = """
        : keepalive

        event: mystery
        data: {"x": 1}

        event: error
        data: {"error": "quota"}

        """
        let events = drain(stream)
        XCTAssertEqual(events, [.error("quota")])
    }

    func testParserDecodesStreamWithBlankSeparatorsDropped() {
        // Regression (live bug 2026-07-26): URLSession's AsyncLineSequence
        // DROPS blank lines — the SSE frame terminators. The parser must
        // treat each new `event:` line as the previous frame's boundary.
        var parser = SSEEventParser()
        var events: [ChatStreamEvent] = []
        for line in [
            "event: message.delta", #"data: {"text": "Hel"}"#,
            "event: message.delta", #"data: {"text": "lo"}"#,
            "event: usage", #"data: {"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3}"#,
            "event: done", #"data: {"finish_reason": "stop", "model": "m"}"#,
        ] {
            if let event = parser.feed(line: line) { events.append(event) }
        }
        if let last = parser.finish() { events.append(last) }
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0], .delta("Hel"))
        XCTAssertEqual(events[1], .delta("lo"))
        XCTAssertEqual(events[3], .done(finishReason: "stop", model: "m"))
    }

    func testParserFlushesUnterminatedTrailingFrame() {
        var parser = SSEEventParser()
        XCTAssertNil(parser.feed(line: "event: done"))
        XCTAssertNil(parser.feed(line: #"data: {"finish_reason": "stop", "model": null}"#))
        XCTAssertEqual(parser.finish(), .done(finishReason: "stop", model: nil))
    }

    // MARK: - Transport error mapping

    func testTransportErrorMapping() {
        XCTAssertEqual(ChatTransportError.from(status: 401, body: ""), .unauthorized)
        XCTAssertEqual(ChatTransportError.from(
            status: 429, body: #"{"error": "… (turn budget)"}"#), .turnBudgetExhausted)
        XCTAssertEqual(ChatTransportError.from(
            status: 429, body: #"{"error": "Daily text generation quota exceeded (quota)"}"#),
            .quotaExceeded)
        XCTAssertEqual(ChatTransportError.from(status: 429, body: "slow down"),
                       .rateLimited)
    }

    // MARK: - Registry

    private struct StubAction: AssistantAction {
        var name: String
        var summary: String { "stub" }
        var parameterSchema: JSONValue { .object(["type": .string("object")]) }
        var risk: ActionRisk { .readOnly }
        func validate(argumentsData: Data) throws -> ActionPlan {
            ActionPlan(summary: "ok")
        }
        func execute(argumentsData: Data) async throws -> ActionOutcome {
            ActionOutcome(resultForModel: "{}", userSummary: "did stub")
        }
    }

    func testRegistryRegistersAndExposesDefinitionsInOrder() throws {
        var registry = ActionRegistry()
        try registry.register(StubAction(name: "b_tool"))
        try registry.register(StubAction(name: "a_tool"))
        XCTAssertEqual(registry.count, 2)
        XCTAssertEqual(registry.toolDefinitions.map(\.name), ["b_tool", "a_tool"])
        XCTAssertNotNil(registry.action(named: "a_tool"))
        XCTAssertNil(registry.action(named: "missing"))
    }

    func testRegistryRejectsDuplicatesAndBadNames() throws {
        var registry = ActionRegistry()
        try registry.register(StubAction(name: "tool"))
        XCTAssertThrowsError(try registry.register(StubAction(name: "tool")))
        XCTAssertThrowsError(try registry.register(StubAction(name: "bad name!")))
        XCTAssertThrowsError(try registry.register(StubAction(name: "")))
    }

    // MARK: - Turn snapshot undo

    func testTurnSnapshotRestoresCapturedState() async {
        struct State: Sendable, Equatable { var value: Int }
        final class Holder: @unchecked Sendable { var state = State(value: 1) }
        let holder = Holder()

        let snapshot = TurnSnapshot(state: holder.state) { restored in
            holder.state = restored
        }
        holder.state = State(value: 99)                 // "the assistant applied edits"
        await MainActor.run { snapshot.restore() }      // one-tap undo
        XCTAssertEqual(holder.state, State(value: 1))
    }
}
