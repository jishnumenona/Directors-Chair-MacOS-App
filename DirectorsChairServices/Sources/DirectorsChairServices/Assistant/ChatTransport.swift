// DirectorsChairServices/Assistant/ChatTransport.swift
//
// AssistantKit (Phase A2.1): the SSE transport for the gateway's
// POST /generate/chat. `SSEEventParser` is a pure line accumulator
// (unit-tested without a network); `GatewayChatTransport` streams via
// URLSession.bytes with Bearer auth and one automatic refresh on 401,
// mirroring AIServiceClient's token conventions.

import Foundation

// MARK: - Errors

public enum ChatTransportError: LocalizedError, Equatable {
    case unauthorized
    case rateLimited
    case turnBudgetExhausted
    case quotaExceeded
    case http(status: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Sign in to use the assistant."
        case .rateLimited: return "Slow down a moment — rate limit reached."
        case .turnBudgetExhausted:
            return "This request hit the per-turn budget. Ask again to continue."
        case .quotaExceeded: return "AI quota reached for now."
        case .http(let status, let message):
            return "Assistant request failed (\(status)): \(message)"
        case .invalidResponse: return "Assistant service returned an unexpected response."
        }
    }

    /// Maps a non-200 gateway status + body to the typed error, keying off
    /// the gateway's contract markers ("turn budget", "quota").
    static func from(status: Int, body: String) -> ChatTransportError {
        switch status {
        case 401: return .unauthorized
        case 429 where body.contains("turn budget"): return .turnBudgetExhausted
        case 429 where body.contains("quota"): return .quotaExceeded
        case 429: return .rateLimited
        default: return .http(status: status, message: String(body.prefix(200)))
        }
    }
}

// MARK: - SSE parsing (pure)

/// Accumulates raw SSE lines into decoded `ChatStreamEvent`s. SSE frames are
/// `event: <name>` + `data: <json>` pairs terminated by a blank line;
/// comments (`:`) and unknown events are ignored.
public struct SSEEventParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []

    public init() {}

    public mutating func feed(line: String) -> ChatStreamEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            defer { eventName = nil; dataLines = [] }
            return decodeCurrent()
        }
        if trimmed.hasPrefix(":") { return nil }              // SSE comment/keepalive
        if trimmed.hasPrefix("event:") {
            // A new frame is starting. If a complete frame is pending, flush
            // it now — some line readers (URLSession's AsyncLineSequence)
            // drop the blank separator lines, so frame starts must also act
            // as frame boundaries.
            let pending = decodeCurrent()
            dataLines = []          // never let a stale frame pollute the next
            eventName = trimmed.dropFirst("event:".count)
                .trimmingCharacters(in: .whitespaces)
            return pending
        } else if trimmed.hasPrefix("data:") {
            dataLines.append(String(trimmed.dropFirst("data:".count))
                .trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Flush a trailing frame that wasn't newline-terminated.
    public mutating func finish() -> ChatStreamEvent? {
        defer { eventName = nil; dataLines = [] }
        return decodeCurrent()
    }

    private func decodeCurrent() -> ChatStreamEvent? {
        guard let name = eventName, !dataLines.isEmpty,
              let data = dataLines.joined(separator: "\n").data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        switch name {
        case "message.delta":
            struct Delta: Decodable { let text: String }
            return (try? decoder.decode(Delta.self, from: data))
                .map { .delta($0.text) }
        case "tool_call":
            return (try? decoder.decode(AssistantToolCall.self, from: data))
                .map { .toolCall($0) }
        case "usage":
            return (try? decoder.decode(ChatUsage.self, from: data))
                .map { .usage($0) }
        case "done":
            struct Done: Decodable {
                let finishReason: String
                let model: String?
                enum CodingKeys: String, CodingKey {
                    case finishReason = "finish_reason"
                    case model
                }
            }
            return (try? decoder.decode(Done.self, from: data))
                .map { .done(finishReason: $0.finishReason, model: $0.model) }
        case "error":
            struct Failure: Decodable { let error: String }
            return (try? decoder.decode(Failure.self, from: data))
                .map { .error($0.error) }
        default:
            return nil
        }
    }
}

// MARK: - Transport

public protocol ChatTransporting: Sendable {
    /// Opens the request and yields decoded stream events until `done`,
    /// `error`, stream end, or cancellation.
    func stream(_ request: ChatRequestBody) -> AsyncThrowingStream<ChatStreamEvent, Error>
}

/// The production transport: URLSession SSE against the gateway.
public final class GatewayChatTransport: ChatTransporting, @unchecked Sendable {
    private let endpoint: URL
    private let session: URLSession
    /// Mirrors AIServiceClient's token conventions, but async so callers can
    /// hop to the main actor for auth state (AuthManager is @MainActor).
    public var tokenProvider: (@Sendable () async -> String?)?
    public var tokenRefresher: (@Sendable () async -> String?)?

    public init(endpoint: URL = ServiceEnvironment.aiProxyURL
                    .appendingPathComponent("generate/chat"),
                session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func stream(_ request: ChatRequestBody) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.run(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(_ request: ChatRequestBody,
                     continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation) async throws {
        var attempt = try makeURLRequest(request, token: await tokenProvider?())
        var (bytes, response) = try await session.bytes(for: attempt)
        var status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 401, let refresher = tokenRefresher,
           let fresh = await refresher() {
            attempt = try makeURLRequest(request, token: fresh)
            (bytes, response) = try await session.bytes(for: attempt)
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
        }
        guard status == 200 else {
            var body = ""
            for try await line in bytes.lines { body += line }
            throw ChatTransportError.from(status: status, body: body)
        }

        // NOTE: URLSession's `bytes.lines` DROPS blank lines — and a blank
        // line is the SSE frame terminator. Split bytes manually so empty
        // lines survive (the parser also flushes on new `event:` lines as
        // a second line of defense).
        var parser = SSEEventParser()
        var lineBuffer = Data()
        func deliver(_ line: String) -> Bool {   // returns false to stop
            guard let event = parser.feed(line: line) else { return true }
            continuation.yield(event)
            if case .done = event { return false }
            if case .error = event { return false }
            return true
        }
        for try await byte in bytes {
            if byte == UInt8(ascii: "\n") {
                var line = String(decoding: lineBuffer, as: UTF8.self)
                lineBuffer.removeAll(keepingCapacity: true)
                if line.hasSuffix("\r") { line.removeLast() }
                WireDebugLog.append(line)
                if !deliver(line) { return }
            } else {
                lineBuffer.append(byte)
            }
            try Task.checkCancellation()
        }
        if !lineBuffer.isEmpty {
            _ = deliver(String(decoding: lineBuffer, as: UTF8.self))
        }
        if let event = parser.finish() {
            continuation.yield(event)
        }
    }

    private func makeURLRequest(_ body: ChatRequestBody,
                                token: String?) throws -> URLRequest {
        WireDebugLog.append("MAKE-REQUEST enter")
        if let encoded = try? JSONEncoder().encode(body) {
            WireDebugLog.append("REQUEST " +
                String(decoding: encoded, as: UTF8.self))
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 180
        return request
    }
}


/// Flag-gated raw SSE capture for diagnosing provider anomalies the
/// normalized event stream masks (empty candidates, blocked prompts).
/// Enable: defaults write com.directorschair.DirectorsChair-Desktop
/// assistant.wireDebug -bool true — writes assistant-wire.log under
/// Application Support/DirectorsChair.
enum WireDebugLog {
    #if DEBUG
    private static let enabled = true   // debug builds always capture
    #else
    private static let enabled =
        UserDefaults.standard.bool(forKey: "assistant.wireDebug")
    #endif
    private static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("DirectorsChair")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("assistant-wire.log")
    }()

    static func append(_ line: String) {
        guard enabled, !line.isEmpty else { return }
        let stamped = "\(Date().ISO8601Format()) \(line)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(stamped.utf8))
            try? handle.close()
        } else {
            try? Data(stamped.utf8).write(to: url)
        }
    }
}
