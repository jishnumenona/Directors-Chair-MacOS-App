// DirectorsChairServices/Assistant/AssistantEngine.swift
//
// AssistantKit (Phase A2.3): the client-side agentic loop (server plan AD3 —
// tools execute in the app; the gateway only relays definitions and calls).
//
// One `runTurn` = one user request. The engine streams the model's reply,
// executes read-only tools immediately and feeds their results back, and
// accumulates mutating/spending proposals into a TurnPlan that the UI
// presents for approval (AD5 — the engine itself NEVER applies a mutation).
// The loop re-sends until the model finishes without tool calls or the local
// call budget is reached; the gateway independently enforces the same budget
// per turn_id (AD7 — defense in depth).

import Foundation

// MARK: - Configuration

public struct EngineConfiguration: Sendable {
    /// Local mirror of the gateway's per-turn call cap.
    public var maxModelCalls: Int
    public var provider: String?
    public var model: String?
    public var maxTokens: Int
    public var temperature: Double
    public var projectId: String?
    /// The session's product tier — the engine advertises only the actions
    /// whose `minimumTier` this tier satisfies (Product-Versions §5.2).
    /// Defaults to `.studio` (fail-open, structure-now rule): an unwired
    /// caller sees the full catalog, exactly today's behavior.
    public var sessionTier: ProductTier

    public init(maxModelCalls: Int = 8, provider: String? = nil,
                model: String? = nil, maxTokens: Int = 4000,
                temperature: Double = 0.7, projectId: String? = nil,
                sessionTier: ProductTier = .studio) {
        self.maxModelCalls = maxModelCalls
        self.provider = provider
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.projectId = projectId
        self.sessionTier = sessionTier
    }
}

// MARK: - Server-side threads (A6.2)

/// Conversation-scoped thread state the caller carries between turns.
/// `established` means a gateway has already acked persistence for this
/// thread, so the engine may send only NEW messages and let the server
/// prepend the stored transcript. Until then every call carries full
/// history — a gateway without thread support just ignores `id`, and the
/// protocol degrades to the classic one instead of losing context.
public struct ThreadContext: Sendable, Equatable {
    public var id: String
    public var established: Bool

    public init(id: String, established: Bool = false) {
        self.id = id
        self.established = established
    }
}

// MARK: - Turn plan

/// One approved-later proposal: a validated mutating/spending tool call.
public struct ProposedActionItem: Sendable, Equatable, Identifiable {
    public var id: String                 // the tool-call id
    public var actionName: String
    public var plan: ActionPlan
    public var argumentsData: Data

    public init(id: String, actionName: String, plan: ActionPlan,
                argumentsData: Data) {
        self.id = id
        self.actionName = actionName
        self.plan = plan
        self.argumentsData = argumentsData
    }
}

public struct TurnPlan: Sendable, Equatable {
    public var items: [ProposedActionItem]
    public init(items: [ProposedActionItem]) { self.items = items }

    /// Total estimated spend across the plan (A5.5 batch budget surface).
    public var totalEstimatedCost: Double {
        items.reduce(0) { $0 + $1.plan.estimatedCost }
    }
}

// MARK: - Events

/// What the UI renders while a turn runs.
public enum EngineEvent: Sendable, Equatable {
    case assistantText(String)                       // streamed fragment
    case toolStarted(name: String)
    case toolFinished(name: String, summary: String)
    case turnPlan(TurnPlan)
    /// A6.2: the gateway acked thread persistence for the first time —
    /// the caller should mark the conversation's ThreadContext established.
    case threadEstablished
    /// Token usage reported by the gateway for one model call — the caller
    /// records it (AI Usage accounting tab).
    case usageReported(promptTokens: Int, completionTokens: Int)
    /// Terminal: the full assistant text and the transcript (including tool
    /// results) the caller persists as conversation history.
    case finished(fullText: String, transcript: [ChatMessage])
    case failed(message: String)
}

// MARK: - Engine

public actor AssistantEngine {
    private let transport: any ChatTransporting
    private let registry: ActionRegistry
    private let configuration: EngineConfiguration
    /// The catalog advertised to the model: the registry's definitions
    /// filtered by the session tier (registry itself stays unfiltered —
    /// tiering is one predicate at the advertisement seam, §5.2). At the
    /// default `.studio` tier this is the full catalog, byte-identical to
    /// the pre-tiering behavior.
    private let advertisedTools: [ToolDefinition]

    public init(transport: any ChatTransporting, registry: ActionRegistry,
                configuration: EngineConfiguration = EngineConfiguration()) {
        self.transport = transport
        self.registry = registry
        self.configuration = configuration
        self.advertisedTools = registry.toolDefinitions.filter { definition in
            guard let action = registry.action(named: definition.name) else {
                return false
            }
            return action.minimumTier <= configuration.sessionTier
        }
    }

    /// Runs one turn. `history` is the prior conversation (system prompt +
    /// past user/assistant messages); `userMessage` is this turn's input.
    /// `thread` opts into server-side threads (A6.2): once established, the
    /// wire carries only the system prompt + messages the server hasn't
    /// stored yet.
    public func runTurn(history: [ChatMessage], userMessage: ChatMessage,
                        turnId: String = UUID().uuidString.lowercased(),
                        thread: ThreadContext? = nil)
    -> AsyncStream<EngineEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.loop(history: history, userMessage: userMessage,
                                turnId: turnId, thread: thread,
                                continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func loop(history: [ChatMessage], userMessage: ChatMessage,
                      turnId: String, thread: ThreadContext?,
                      continuation: AsyncStream<EngineEvent>.Continuation) async {
        var messages = history + [userMessage]
        // Thread mode: what the server hasn't persisted yet. Each acked
        // model call clears it (the server stored these + its own reply).
        var unsent: [ChatMessage] = [userMessage]
        var established = thread?.established ?? false
        let systemMessages = history.filter { $0.role == .system }
        var fullText = ""
        var planItems: [ProposedActionItem] = []
        var modelCalls = 0
        var emptyRetries = 0

        func finish() {
            if !planItems.isEmpty {
                continuation.yield(.turnPlan(TurnPlan(items: planItems)))
            }
            continuation.yield(.finished(fullText: fullText, transcript: messages))
        }

        while true {
            guard modelCalls < configuration.maxModelCalls else {
                fullText += fullText.isEmpty ? "" : "\n"
                fullText += "(Stopped: this request reached the per-turn tool budget.)"
                finish()
                return
            }
            modelCalls += 1

            let request = ChatRequestBody(
                messages: established ? systemMessages + unsent : messages,
                tools: advertisedTools,
                provider: configuration.provider,
                model: configuration.model,
                maxTokens: configuration.maxTokens,
                temperature: configuration.temperature,
                stream: true,
                projectId: configuration.projectId,
                turnId: turnId,
                threadId: thread?.id)

            var callText = ""
            var toolCalls: [AssistantToolCall] = []
            var finishReason: String?
            var ackedThisCall = false
            do {
                for try await event in transport.stream(request) {
                    switch event {
                    case .delta(let text):
                        callText += text
                        continuation.yield(.assistantText(text))
                    case .toolCall(let call):
                        toolCalls.append(call)
                    case .threadAck(let id):
                        ackedThisCall = (id == thread?.id)
                    case .error(let message):
                        if !planItems.isEmpty {
                            continuation.yield(.turnPlan(TurnPlan(items: planItems)))
                        }
                        continuation.yield(.failed(message: message))
                        return
                    case .done(let reason, _):
                        finishReason = reason
                    case .usage(let usage):
                        continuation.yield(.usageReported(
                            promptTokens: usage.promptTokens,
                            completionTokens: usage.completionTokens))
                    }
                    try Task.checkCancellation()
                }
            } catch is CancellationError {
                return
            } catch {
                if !planItems.isEmpty {
                    continuation.yield(.turnPlan(TurnPlan(items: planItems)))
                }
                continuation.yield(.failed(
                    message: (error as? LocalizedError)?.errorDescription
                        ?? "The assistant request failed."))
                return
            }

            // Thread bookkeeping: an ack means the server persisted this
            // call's fresh messages plus its reply — nothing is "unsent"
            // any more. No ack while established means the server lost
            // thread support mid-conversation (downgrade); fall back to
            // full-history sends for the rest of the turn.
            if ackedThisCall {
                unsent.removeAll()
                if !established {
                    established = true
                    continuation.yield(.threadEstablished)
                }
            } else if established {
                established = false
            }

            // An empty model call (no text, no tool calls) is a provider
            // anomaly — Gemini's malformed-function-call mode, safety trims.
            // Retry once silently; a second empty response surfaces the
            // finish reason instead of an empty turn.
            if callText.isEmpty && toolCalls.isEmpty {
                if emptyRetries < 2 {
                    emptyRetries += 1
                    // Identical bytes reproduce the degeneracy — mutate the
                    // request instead: a synthetic nudge exchange reliably
                    // snaps the model out of empty-generation mode
                    // (verified 4/4 at worst-case payload, 2026-07-30).
                    messages.append(.assistant(" "))
                    messages.append(.user([.text(
                        "(You returned an empty reply. Answer now — call "
                        + "the right tool if one applies, otherwise reply "
                        + "in text.)")]))
                    unsent.append(.assistant(" "))
                    unsent.append(messages[messages.count - 1])
                    continue
                }
                if !planItems.isEmpty {
                    continuation.yield(.turnPlan(TurnPlan(items: planItems)))
                }
                continuation.yield(.failed(message:
                    "The model returned an empty response"
                    + (finishReason.map { " (\($0))" } ?? "")
                    + " — please try again."))
                return
            }

            fullText += callText
            messages.append(.assistant(callText, toolCalls:
                toolCalls.isEmpty ? nil : toolCalls))

            guard !toolCalls.isEmpty else {
                finish()
                return
            }

            for call in toolCalls {
                let result = await handle(call: call, planItems: &planItems,
                                          continuation: continuation)
                messages.append(.toolResult(callId: call.id, result))
                unsent.append(.toolResult(callId: call.id, result))
            }
            // Loop: the model sees the tool results and continues the turn.
        }
    }

    /// Executes or proposes one tool call; returns the tool-result payload
    /// fed back to the model.
    private func handle(call: AssistantToolCall,
                        planItems: inout [ProposedActionItem],
                        continuation: AsyncStream<EngineEvent>.Continuation) async -> String {
        guard let action = registry.action(named: call.name) else {
            return #"{"error": "unknown tool '\#(call.name)' — use only the provided tools"}"#
        }
        // Defense in depth beside the advertisement filter: a call to an
        // above-tier tool (hallucinated name — it was never advertised)
        // must not execute. UX gating only; the server enforces spend.
        guard action.minimumTier <= configuration.sessionTier else {
            return #"{"error": "tool '\#(call.name)' is not included in this account's plan — use only the provided tools"}"#
        }
        let argumentsData: Data
        do {
            argumentsData = try call.arguments.encodedData()
        } catch {
            return #"{"error": "arguments were not valid JSON"}"#
        }

        continuation.yield(.toolStarted(name: call.name))
        do {
            let plan = try await action.validate(argumentsData: argumentsData)
            switch action.risk {
            case .readOnly:
                let outcome = try await action.execute(argumentsData: argumentsData)
                continuation.yield(.toolFinished(name: call.name,
                                                 summary: outcome.userSummary))
                return outcome.resultForModel
            case .mutating, .spending:
                planItems.append(ProposedActionItem(
                    id: call.id, actionName: call.name, plan: plan,
                    argumentsData: argumentsData))
                continuation.yield(.toolFinished(name: call.name,
                                                 summary: "Proposed: \(plan.summary)"))
                // Validator findings (AD6) go back to the model so it can
                // reconsider or surface them to the user.
                var proposal: [String: Any] = [
                    "status": "proposed",
                    "note": "queued for user approval — do not call this tool again for the same change; continue or finish your reply",
                ]
                if !plan.warnings.isEmpty { proposal["warnings"] = plan.warnings }
                let data = try? JSONSerialization.data(withJSONObject: proposal,
                                                       options: [.sortedKeys])
                return data.flatMap { String(data: $0, encoding: .utf8) }
                    ?? #"{"status": "proposed"}"#
            }
        } catch {
            let message = (error as? ActionError)?.message
                ?? (error as? LocalizedError)?.errorDescription
                ?? "action failed"
            continuation.yield(.toolFinished(name: call.name,
                                             summary: "Failed: \(message)"))
            let escaped = message
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return #"{"error": "\#(escaped)"}"#
        }
    }
}
