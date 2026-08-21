// DirectorsChairServices/Insights/InsightEngine.swift
//
// The engine seam for on-device AI insights (DC-0055). The pure half
// (families, context builders, prompts) lives in DirectorsChairCore;
// this protocol is the boundary every inference backend implements —
// today the bundled open-weights MLX engine, later Apple's
// FoundationModels when toolchains reach macOS 26. UI and callers only
// ever see this protocol, so swapping or adding engines touches nothing
// above it.

import Foundation
import DirectorsChairCore

// MARK: - Availability

/// Why insights can or cannot run right now. Order matters to the UI:
/// every state renders as a clear explanation, never a broken surface
/// (Product-Versions §3.7 note).
public enum InsightAvailability: Equatable, Sendable {
    /// Ready — the model is on disk and the hardware can run it.
    case ready
    /// The model must be fetched once (size in bytes, for the consent UI —
    /// a ~2GB download is never started silently).
    case needsDownload(expectedBytes: Int64)
    /// A download is in flight (0...1).
    case downloading(progress: Double)
    /// This machine cannot run the engine (e.g. Intel Mac). The string is
    /// user-facing.
    case unavailable(reason: String)
}

// MARK: - Errors

public enum InsightEngineError: Error, Equatable, Sendable {
    case notReady(InsightAvailability)
    case downloadFailed(String)
    case inferenceFailed(String)
    case cancelled
}

// MARK: - Engine protocol

/// One on-device inference backend. Implementations must be safe to call
/// from the main actor; long work happens inside the async calls.
public protocol InsightEngine: AnyObject, Sendable {
    /// Current state — cheap to read, safe to poll.
    func availability() async -> InsightAvailability

    /// Fetch whatever the engine needs (model weights). Progress lands in
    /// `availability()`. A no-op when already ready.
    func prepare() async throws

    /// Run one insight: the family supplies its pinned instructions, the
    /// caller supplies the compact project context (built by
    /// InsightContextBuilder — the engine never sees a raw Project).
    func insight(for family: InsightFamily, context: String) async throws -> String
}

// MARK: - Test double

/// Deterministic engine for tests and previews: scripted availability and
/// responses, recorded calls.
public final class ScriptedInsightEngine: InsightEngine, @unchecked Sendable {
    private let lock = NSLock()
    private var _availability: InsightAvailability
    private var responses: [InsightFamily: Result<String, InsightEngineError>]
    public private(set) var preparations = 0
    public private(set) var requests: [(family: InsightFamily, context: String)] = []

    public init(availability: InsightAvailability = .ready,
                responses: [InsightFamily: Result<String, InsightEngineError>] = [:]) {
        self._availability = availability
        self.responses = responses
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    public func setAvailability(_ value: InsightAvailability) {
        withLock { _availability = value }
    }

    public func availability() async -> InsightAvailability {
        withLock { _availability }
    }

    public func prepare() async throws {
        withLock {
            preparations += 1
            _availability = .ready
        }
    }

    public func insight(for family: InsightFamily, context: String) async throws -> String {
        let (scripted, state) = withLock { () -> (Result<String, InsightEngineError>?, InsightAvailability) in
            requests.append((family, context))
            return (responses[family], _availability)
        }
        guard state == .ready else { throw InsightEngineError.notReady(state) }
        switch scripted {
        case .success(let text): return text
        case .failure(let error): throw error
        case nil: return "scripted insight for \(family.rawValue)"
        }
    }
}
