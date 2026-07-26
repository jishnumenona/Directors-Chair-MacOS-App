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

    public init(maxModelCalls: Int = 8, provider: String? = nil,
                model: String? = nil, maxTokens: Int = 4000,
                temperature: Double = 0.7, projectId: String? = nil) {
        self.maxModelCalls = maxModelCalls
        self.provider = provider
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.projectId = projectId
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
}

// MARK: - Events

/// What the UI renders while a turn runs.
public enum EngineEvent: Sendable, Equatable {
    case assistantText(String)                       // streamed fragment
    case toolStarted(name: String)
    case toolFinished(name: String, summary: String)
    case turnPlan(TurnPlan)
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

    public init(transport: any ChatTransporting, registry: ActionRegistry,
                configuration: EngineConfiguration = EngineConfiguration()) {
        self.transport = transport
        self.registry = registry
        self.configuration = configuration
    }

    /// Runs one turn. `history` is the prior conversation (system prompt +
    /// past user/assistant messages); `userMessage` is this turn's input.
    public func runTurn(history: [ChatMessage], userMessage: ChatMessage,
                        turnId: String = UUID().uuidString.lowercased())
    -> AsyncStream<EngineEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.loop(history: history, userMessage: userMessage,
                                turnId: turnId, continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func loop(history: [ChatMessage], userMessage: ChatMessage,
                      turnId: String,
                      continuation: AsyncStream<EngineEvent>.Continuation) async {
        var messages = history + [userMessage]
        var fullText = ""
        var planItems: [ProposedActionItem] = []
        var modelCalls = 0

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
                messages: messages,
                tools: registry.toolDefinitions,
                provider: configuration.provider,
                model: configuration.model,
                maxTokens: configuration.maxTokens,
                temperature: configuration.temperature,
                stream: true,
                projectId: configuration.projectId,
                turnId: turnId)

            var callText = ""
            var toolCalls: [AssistantToolCall] = []
            do {
                for try await event in transport.stream(request) {
                    switch event {
                    case .delta(let text):
                        callText += text
                        continuation.yield(.assistantText(text))
                    case .toolCall(let call):
                        toolCalls.append(call)
                    case .error(let message):
                        if !planItems.isEmpty {
                            continuation.yield(.turnPlan(TurnPlan(items: planItems)))
                        }
                        continuation.yield(.failed(message: message))
                        return
                    case .usage, .done:
                        break
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
                return #"{"status": "proposed", "note": "queued for user approval — do not call this tool again for the same change; continue or finish your reply"}"#
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
