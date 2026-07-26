// DirectorsChairServicesTests/AssistantEngineTests.swift
//
// AssistantKit Phase A2.3: the agentic loop against a scripted transport —
// read-only auto-execution with tool-result round-trips, TurnPlan
// accumulation for mutating proposals, unknown-tool recovery, the local
// call budget, and transport-failure surfacing. No network anywhere.

import XCTest
@testable import DirectorsChairServices

// MARK: - Scripted transport

private final class ScriptedTransport: ChatTransporting, @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [[ChatStreamEvent]]
    /// Thrown once the scripted responses are exhausted (deterministically
    /// emulates e.g. the gateway's 429 turn-budget cut mid-loop).
    private let whenExhausted: Error?
    private(set) var requests: [ChatRequestBody] = []

    init(scripts: [[ChatStreamEvent]], whenExhausted: Error? = nil) {
        self.scripts = scripts
        self.whenExhausted = whenExhausted
    }

    func stream(_ request: ChatRequestBody) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        lock.lock()
        requests.append(request)
        let script = scripts.isEmpty ? nil : scripts.removeFirst()
        lock.unlock()
        return AsyncThrowingStream { continuation in
            guard let script else {
                continuation.finish(throwing: self.whenExhausted
                    ?? ChatTransportError.invalidResponse)
                return
            }
            for event in script { continuation.yield(event) }
            continuation.finish()
        }
    }
}

// MARK: - Fake actions

private final class ReadAction: AssistantAction, @unchecked Sendable {
    let name = "get_scene"
    let summary = "Read a scene"
    let parameterSchema = JSONValue.object(["type": .string("object")])
    let risk = ActionRisk.readOnly
    private(set) var receivedArguments: [String] = []

    func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "read the scene")
    }

    func execute(argumentsData: Data) async throws -> ActionOutcome {
        receivedArguments.append(String(data: argumentsData, encoding: .utf8) ?? "")
        return ActionOutcome(resultForModel: #"{"description": "Night. Rain."}"#,
                             userSummary: "Read Opening")
    }
}

private struct MutatingAction: AssistantAction {
    let name = "update_scene"
    let summary = "Edit a scene description"
    let parameterSchema = JSONValue.object(["type": .string("object")])
    let risk = ActionRisk.mutating

    func validate(argumentsData: Data) throws -> ActionPlan {
        ActionPlan(summary: "Update Opening's description",
                   previews: [ActionPreview(title: "Description",
                                            oldValue: "Old", newValue: "New")])
    }

    func execute(argumentsData: Data) async throws -> ActionOutcome {
        XCTFail("mutating actions must never execute inside the loop")
        return ActionOutcome(resultForModel: "{}", userSummary: "")
    }
}

private struct FailingAction: AssistantAction {
    let name = "broken_tool"
    let summary = "Always fails validation"
    let parameterSchema = JSONValue.object(["type": .string("object")])
    let risk = ActionRisk.readOnly

    func validate(argumentsData: Data) throws -> ActionPlan {
        throw ActionError("scene 'Nowhere' does not exist")
    }

    func execute(argumentsData: Data) async throws -> ActionOutcome {
        ActionOutcome(resultForModel: "{}", userSummary: "")
    }
}

// MARK: - Helpers

private func call(_ id: String, _ name: String,
                  _ args: [String: JSONValue] = [:]) -> ChatStreamEvent {
    .toolCall(AssistantToolCall(id: id, name: name, arguments: .object(args)))
}

private func collect(_ engine: AssistantEngine,
                     user: String = "hello") async -> [EngineEvent] {
    var events: [EngineEvent] = []
    for await event in await engine.runTurn(history: [.system("sys")],
                                            userMessage: .user(user)) {
        events.append(event)
    }
    return events
}

// MARK: - Tests

final class AssistantEngineTests: XCTestCase {

    func testPlainTextTurnStreamsAndFinishes() async throws {
        let transport = ScriptedTransport(scripts: [[
            .delta("Hello "), .delta("director."),
            .done(finishReason: "stop", model: "m")]])
        let engine = AssistantEngine(transport: transport, registry: ActionRegistry())

        let events = await collect(engine)

        XCTAssertEqual(events.first, .assistantText("Hello "))
        guard case .finished(let text, let transcript) = events.last else {
            return XCTFail("expected finished")
        }
        XCTAssertEqual(text, "Hello director.")
        // transcript = system + user + assistant
        XCTAssertEqual(transcript.map(\.role), [.system, .user, .assistant])
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].turnId?.isEmpty, false)
    }

    func testReadOnlyToolExecutesAndRoundTripsResult() async throws {
        let transport = ScriptedTransport(scripts: [
            [.delta("Let me check."),
             call("call_1", "get_scene", ["name": .string("Opening")]),
             .done(finishReason: "tool_calls", model: "m")],
            [.delta("It is night and raining."),
             .done(finishReason: "stop", model: "m")],
        ])
        let read = ReadAction()
        var registry = ActionRegistry()
        try registry.register(read)
        let engine = AssistantEngine(transport: transport, registry: registry)

        let events = await collect(engine)

        XCTAssertTrue(events.contains(.toolStarted(name: "get_scene")))
        XCTAssertTrue(events.contains(.toolFinished(name: "get_scene",
                                                    summary: "Read Opening")))
        XCTAssertEqual(read.receivedArguments, [#"{"name":"Opening"}"#])
        // the second model call carried the assistant tool_call + tool result
        XCTAssertEqual(transport.requests.count, 2)
        let second = transport.requests[1].messages
        XCTAssertEqual(second[2].role, .assistant)
        XCTAssertEqual(second[2].toolCalls?.first?.name, "get_scene")
        XCTAssertEqual(second[3].role, .tool)
        XCTAssertEqual(second[3].toolCallId, "call_1")
        XCTAssertTrue(second[3].textContent.contains("Night. Rain."))
        // both calls share one turn id (the gateway budget key)
        XCTAssertEqual(transport.requests[0].turnId, transport.requests[1].turnId)
        guard case .finished(let text, _)? = events.last else {
            return XCTFail("expected finished")
        }
        XCTAssertEqual(text, "Let me check.It is night and raining.")
    }

    func testMutatingToolBecomesTurnPlanNotExecution() async throws {
        let transport = ScriptedTransport(scripts: [
            [call("call_9", "update_scene", ["text": .string("New")]),
             .done(finishReason: "tool_calls", model: "m")],
            [.delta("Proposed the edit for your review."),
             .done(finishReason: "stop", model: "m")],
        ])
        var registry = ActionRegistry()
        try registry.register(MutatingAction())
        let engine = AssistantEngine(transport: transport, registry: registry)

        let events = await collect(engine)

        guard let planEvent = events.first(where: {
            if case .turnPlan = $0 { return true } ; return false
        }), case .turnPlan(let plan) = planEvent else {
            return XCTFail("expected a TurnPlan")
        }
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.items[0].actionName, "update_scene")
        XCTAssertEqual(plan.items[0].plan.previews[0].newValue, "New")
        // the model was told it's queued, not applied
        let toolResult = transport.requests[1].messages.last {
            $0.role == .tool
        }
        XCTAssertTrue(toolResult?.textContent.contains("proposed") == true)
    }

    func testUnknownToolFeedsErrorBackAndLoopContinues() async throws {
        let transport = ScriptedTransport(scripts: [
            [call("call_2", "not_a_tool"),
             .done(finishReason: "tool_calls", model: "m")],
            [.delta("Understood."), .done(finishReason: "stop", model: "m")],
        ])
        let engine = AssistantEngine(transport: transport, registry: ActionRegistry())

        let events = await collect(engine)

        let toolResult = transport.requests[1].messages.last { $0.role == .tool }
        XCTAssertTrue(toolResult?.textContent.contains("unknown tool") == true)
        guard case .finished = events.last else {
            return XCTFail("loop should continue to a normal finish")
        }
    }

    func testValidationFailureIsReportedToModelAndUser() async throws {
        let transport = ScriptedTransport(scripts: [
            [call("call_3", "broken_tool"),
             .done(finishReason: "tool_calls", model: "m")],
            [.delta("I could not find that scene."),
             .done(finishReason: "stop", model: "m")],
        ])
        var registry = ActionRegistry()
        try registry.register(FailingAction())
        let engine = AssistantEngine(transport: transport, registry: registry)

        let events = await collect(engine)

        XCTAssertTrue(events.contains(.toolFinished(
            name: "broken_tool", summary: "Failed: scene 'Nowhere' does not exist")))
        let toolResult = transport.requests[1].messages.last { $0.role == .tool }
        XCTAssertTrue(toolResult?.textContent.contains("does not exist") == true)
    }

    func testCallBudgetStopsRunawayLoop() async throws {
        // Every scripted response demands another tool call — more scripts
        // than the budget allows, so only the cap can stop the loop.
        let toolLoop: [ChatStreamEvent] =
            [call("c", "get_scene"), .done(finishReason: "tool_calls", model: "m")]
        let transport = ScriptedTransport(
            scripts: Array(repeating: toolLoop, count: 5))
        var registry = ActionRegistry()
        try registry.register(ReadAction())
        let engine = AssistantEngine(
            transport: transport, registry: registry,
            configuration: EngineConfiguration(maxModelCalls: 3))

        let events = await collect(engine)

        XCTAssertEqual(transport.requests.count, 3, "hard local cap")
        guard case .finished(let text, _)? = events.last else {
            return XCTFail("expected finished")
        }
        XCTAssertTrue(text.contains("per-turn tool budget"))
    }

    func testTransportFailureFlushesPlanThenFails() async throws {
        // One scripted response proposes an edit; the follow-up call hits the
        // (deterministic) gateway turn-budget failure.
        let transport = ScriptedTransport(
            scripts: [
                [call("call_4", "update_scene", ["text": .string("New")]),
                 .done(finishReason: "tool_calls", model: "m")],
            ],
            whenExhausted: ChatTransportError.turnBudgetExhausted)
        var registry = ActionRegistry()
        try registry.register(MutatingAction())
        let engine = AssistantEngine(transport: transport, registry: registry)

        let events = await collect(engine)

        let kinds = events.map(kind)
        XCTAssertTrue(kinds.contains("turnPlan"),
                      "an accumulated proposal must not be lost on failure")
        XCTAssertEqual(kinds.last, "failed")
        guard case .failed(let message)? = events.last else {
            return XCTFail("expected failed")
        }
        XCTAssertTrue(message.contains("per-turn budget"))
    }

    private func kind(_ event: EngineEvent) -> String {
        switch event {
        case .assistantText: return "text"
        case .toolStarted: return "toolStarted"
        case .toolFinished: return "toolFinished"
        case .turnPlan: return "turnPlan"
        case .finished: return "finished"
        case .failed: return "failed"
        }
    }
}
