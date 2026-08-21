// DirectorsChairServices/Insights/MLXInsightEngine.swift
//
// The bundled-open-model backend for on-device insights (DC-0055): a
// 4-bit 3B-class instruct model run locally through MLX on Apple
// Silicon. Weights are fetched ONCE from the Hugging Face hub into
// Application Support after explicit user consent (the ~2GB download is
// surfaced in the UI, never started silently), then everything runs
// offline. When toolchains reach macOS 26 an Apple FoundationModels
// engine joins behind the same InsightEngine protocol.

import Foundation
import DirectorsChairCore
#if arch(arm64)
import Hub
import MLXLLM
import MLXLMCommon
#endif

/// What AIServiceClient needs from an on-device text engine (DC-0057) —
/// a seam so unit tests never load real MLX (its metallib only exists
/// inside app bundles; SPM test runners abort on it).
public protocol OnDeviceTextResponding: Sendable {
    func respond(prompt: String, systemPrompt: String?,
                 maxTokens: Int, temperature: Double) async throws -> String
}

public final class MLXInsightEngine: InsightEngine, OnDeviceTextResponding, @unchecked Sendable {

    /// One engine per app — the loaded model is ~2GB of unified memory,
    /// so it must never be instantiated per view (ShortcutStore.shared
    /// precedent; also keeps the audit harness free of new required
    /// environment objects).
    public static let shared = MLXInsightEngine()

    /// The model this build ships against. 4-bit Qwen 2.5 3B Instruct:
    /// strong small-model quality, ~1.8GB on disk, comfortable on 8GB
    /// Apple Silicon.
    public static let modelId = "mlx-community/Qwen2.5-3B-Instruct-4bit"
    public static let expectedDownloadBytes: Int64 = 1_900_000_000

    private let lock = NSLock()
    private var progress: Double?
    private let storageRoot: URL

    #if arch(arm64)
    private var container: ModelContainer?
    #endif

    /// Weights live under Application Support so they survive cache
    /// purges — a 2GB re-download for a cleaned cache is user-hostile.
    public init(storageRoot: URL? = nil) {
        self.storageRoot = storageRoot ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DirectorsChair/InsightModels", isDirectory: true)
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    /// The marker written after a COMPLETE download — presence of a
    /// partial hub directory must never read as ready.
    private var readyMarker: URL {
        storageRoot.appendingPathComponent(".ready-\(Self.modelId.replacingOccurrences(of: "/", with: "_"))")
    }

    // MARK: - InsightEngine

    public func availability() async -> InsightAvailability {
        #if arch(arm64)
        if let progress = withLock({ progress }) {
            return .downloading(progress: progress)
        }
        if FileManager.default.fileExists(atPath: readyMarker.path) {
            return .ready
        }
        return .needsDownload(expectedBytes: Self.expectedDownloadBytes)
        #else
        return .unavailable(reason: "On-device insights need an Apple Silicon Mac.")
        #endif
    }

    public func prepare() async throws {
        #if arch(arm64)
        if case .ready = await availability() { return }
        withLock { progress = 0 }
        defer { withLock { progress = nil } }
        do {
            _ = try await loadedContainer()
            try FileManager.default.createDirectory(
                at: storageRoot, withIntermediateDirectories: true)
            try Data().write(to: readyMarker)
        } catch {
            throw InsightEngineError.downloadFailed(String(describing: error))
        }
        #else
        throw InsightEngineError.notReady(
            .unavailable(reason: "On-device insights need an Apple Silicon Mac."))
        #endif
    }

    public func insight(for family: InsightFamily, context: String) async throws -> String {
        try await respond(prompt: family.instructions + "\n\nPROJECT DATA:\n" + context,
                          systemPrompt: nil, maxTokens: 700, temperature: 0.6)
    }

    /// Raw single-turn completion (DC-0057): the same loaded model serves
    /// text generation when the user picks "On-device" in preferences.
    /// Refuses (never downloads) when the model isn't ready — a 2GB fetch
    /// only ever starts from the consent button.
    public func respond(prompt: String, systemPrompt: String?,
                        maxTokens: Int, temperature: Double) async throws -> String {
        #if arch(arm64)
        let state = await availability()
        guard case .ready = state else { throw InsightEngineError.notReady(state) }
        do {
            let container = try await loadedContainer()
            let full = systemPrompt.map { $0 + "\n\n" + prompt } ?? prompt
            // 3B-model ceiling: past ~2000 tokens of output the small model
            // rambles; server providers handle the long-form asks.
            let cap = max(64, min(maxTokens, 2000))
            return try await container.perform { modelContext in
                let input = try await modelContext.processor.prepare(
                    input: UserInput(prompt: full))
                let result = try MLXLMCommon.generate(
                    input: input,
                    parameters: GenerateParameters(temperature: Float(temperature)),
                    context: modelContext
                ) { tokens in
                    tokens.count >= cap ? .stop : .more
                }
                return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch let error as InsightEngineError {
            throw error
        } catch {
            throw InsightEngineError.inferenceFailed(String(describing: error))
        }
        #else
        throw InsightEngineError.notReady(
            .unavailable(reason: "On-device insights need an Apple Silicon Mac."))
        #endif
    }

    // MARK: - Loading

    #if arch(arm64)
    private func loadedContainer() async throws -> ModelContainer {
        if let container = withLock({ container }) { return container }
        let hub = HubApi(downloadBase: storageRoot)
        let configuration = ModelConfiguration(id: Self.modelId)
        let loaded = try await LLMModelFactory.shared.loadContainer(
            hub: hub, configuration: configuration
        ) { [weak self] downloadProgress in
            self?.withLock {
                self?.progress = downloadProgress.fractionCompleted
            }
        }
        withLock { container = loaded }
        return loaded
    }
    #endif
}
