// DirectorsChairServices/Insights/LocalChatTransport.swift
//
// On-device assistant chat (DC-0059): the local model behind the SAME
// ChatTransporting seam the gateway transport implements, so the
// assistant engine, overlay, and history all work unchanged. One honest
// limitation, stated to both the model and the user: the local 3B-class
// model cannot drive the tool-call loop, so on-device chat CONVERSES —
// it never proposes or executes project actions. Tool definitions in
// the request are deliberately not advertised to the model.

import Foundation

public final class LocalChatTransport: ChatTransporting, @unchecked Sendable {

    /// Pinned system framing for conversation-only mode.
    static let conversationOnlyNote = """
    You are DirectorsChair's assistant running entirely on this Mac — \
    private, free, and offline. In on-device mode you can discuss the \
    project and answer questions, but you cannot run project actions or \
    tools. When asked to change something, briefly explain how to do it \
    in the app instead of pretending to do it.
    """

    /// The flattened conversation the small model reads — history beyond
    /// this is dropped from the FRONT (the newest turns matter most).
    static let historyCharacterBudget = 12_000

    private let engine: any OnDeviceTextResponding

    public init(engine: any OnDeviceTextResponding = MLXInsightEngine.shared) {
        self.engine = engine
    }

    public func stream(_ request: ChatRequestBody) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [engine] in
                do {
                    let prompt = Self.flatten(request.messages)
                    let text = try await engine.respond(
                        prompt: prompt,
                        systemPrompt: Self.conversationOnlyNote,
                        maxTokens: request.maxTokens,
                        temperature: request.temperature)
                    continuation.yield(.delta(text))
                    continuation.yield(.done(finishReason: "stop", model: "on-device"))
                } catch {
                    // The engine's refusals are already user-worded; the
                    // wire's .error event is how the overlay shows them.
                    let message: String
                    if case InsightEngineError.notReady(let state) = error,
                       case .unavailable(let reason) = state {
                        message = reason
                    } else if case InsightEngineError.notReady = error {
                        message = "The on-device model isn't ready — download it from Settings → AI Services or any project's Overview."
                    } else {
                        message = "The on-device model couldn't answer — try again, or switch to a server provider in Settings → AI Services."
                    }
                    continuation.yield(.error(message))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Role-tagged transcript, tool roles skipped (there are no tools in
    /// this mode), trimmed from the front to the history budget so a long
    /// session never overflows the small model's window.
    static func flatten(_ messages: [ChatMessage]) -> String {
        var lines: [String] = []
        for message in messages {
            let text = message.textContent
            guard !text.isEmpty else { continue }
            switch message.role {
            case .system: lines.append("Context: \(text)")
            case .user: lines.append("User: \(text)")
            case .assistant: lines.append("Assistant: \(text)")
            default: continue
            }
        }
        lines.append("Assistant:")
        var joined = lines.joined(separator: "\n\n")
        if joined.count > historyCharacterBudget {
            joined = "(earlier conversation trimmed)\n…" +
                String(joined.suffix(historyCharacterBudget))
        }
        return joined
    }
}
