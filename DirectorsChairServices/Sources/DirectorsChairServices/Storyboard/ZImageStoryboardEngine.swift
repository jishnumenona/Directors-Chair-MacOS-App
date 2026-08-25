// DirectorsChairServices/Storyboard/ZImageStoryboardEngine.swift
//
// The Z-Image Turbo backend for on-device storyboard frames (DC-0063):
// owns the consent-gated weight download, disk preflight, ready state,
// and the locked style layer — and delegates actual diffusion to the
// injected OnDeviceImageGenerating core (DC-0065), which only exists
// inside app bundles (MLX metallib rule). Mirrors MLXInsightEngine:
// weights live under Application Support so cache purges don't cost the
// user a 5.5GB re-download; a ready marker is written only after a
// COMPLETE snapshot; availability checks the marker FIRST (the DC-0060
// stuck-progress lesson).

import Foundation
import DirectorsChairCore
#if arch(arm64)
import Hub
#endif

public final class ZImageStoryboardEngine: StoryboardEngine, @unchecked Sendable {

    /// One engine per app (ShortcutStore.shared precedent) — state is a
    /// download in flight plus markers, never per-view.
    public static let shared = ZImageStoryboardEngine()

    /// The single bundled model (owner decision 2026-08-25 — no picker).
    public static let model = StoryboardModel.zImageTurbo

    /// The diffusion core, injected by the app target at launch (DC-0065).
    /// nil in SPM test runners and in builds where the core hasn't landed
    /// — generateFrame then fails with an honest message instead of a
    /// broken surface.
    nonisolated(unsafe) public static var core: (any OnDeviceImageGenerating)?

    /// Free space the preflight insists on BEYOND the model itself —
    /// downloading 5.5GB onto a nearly-full disk trades a feature for a
    /// broken Mac (dev machine at 8GB free, 2026-08-24).
    public static let downloadHeadroomBytes: Int64 = 2_000_000_000

    private let lock = NSLock()
    private var progress: Double?
    private let storageRoot: URL

    public init(storageRoot: URL? = nil) {
        self.storageRoot = storageRoot ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DirectorsChair/ImageModels", isDirectory: true)
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    // MARK: - Disk state

    private var readyMarker: URL {
        storageRoot.appendingPathComponent(
            ".ready-\(Self.model.id.replacingOccurrences(of: "/", with: "_"))")
    }

    public func isModelDownloaded() -> Bool {
        FileManager.default.fileExists(atPath: readyMarker.path)
    }

    /// Where the snapshot lives once downloaded — the Hub convention
    /// (downloadBase/models/<repo id>), encoded in exactly one place; the
    /// DC-0065 core validates the layout when it loads.
    public var weightsDirectory: URL {
        storageRoot
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(Self.model.id, isDirectory: true)
    }

    // MARK: - Disk preflight

    /// Pure decision, unit-testable without faking a volume.
    public static func validateDiskSpace(freeBytes: Int64, modelBytes: Int64,
                                         headroom: Int64 = downloadHeadroomBytes)
        -> StoryboardEngineError? {
        let needed = modelBytes + headroom
        return freeBytes >= needed
            ? nil
            : .insufficientDisk(neededBytes: needed, freeBytes: freeBytes)
    }

    /// Available capacity on the volume that will hold the weights,
    /// walking up from storageRoot to the nearest existing ancestor
    /// (fresh installs haven't created the directory yet).
    public func freeDiskBytes() -> Int64 {
        var probe = storageRoot
        while !FileManager.default.fileExists(atPath: probe.path),
              probe.pathComponents.count > 1 {
            probe.deleteLastPathComponent()
        }
        let values = try? probe.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    // MARK: - StoryboardEngine

    public func availability() async -> InsightAvailability {
        #if arch(arm64)
        // Marker first: completed weights are READY even while a local
        // (re)validation drives the same Progress object (DC-0060 lesson).
        if isModelDownloaded() { return .ready }
        if let progress = withLock({ progress }) {
            return .downloading(progress: progress)
        }
        return .needsDownload(expectedBytes: Self.model.approxBytes)
        #else
        return .unavailable(reason: "On-device storyboard frames need an Apple Silicon Mac.")
        #endif
    }

    public func prepare() async throws {
        #if arch(arm64)
        if case .ready = await availability() { return }
        if let refusal = Self.validateDiskSpace(freeBytes: freeDiskBytes(),
                                                modelBytes: Self.model.approxBytes) {
            throw refusal
        }
        withLock { progress = 0 }
        defer { withLock { progress = nil } }
        do {
            let hub = HubApi(downloadBase: storageRoot)
            _ = try await hub.snapshot(
                from: Self.model.id,
                matching: ["*"]
            ) { [weak self] downloadProgress in
                self?.withLock {
                    self?.progress = downloadProgress.fractionCompleted
                }
            }
            try FileManager.default.createDirectory(
                at: storageRoot, withIntermediateDirectories: true)
            try Data().write(to: readyMarker)
        } catch let error as StoryboardEngineError {
            throw error
        } catch {
            throw StoryboardEngineError.downloadFailed(String(describing: error))
        }
        #else
        throw StoryboardEngineError.notReady(
            .unavailable(reason: "On-device storyboard frames need an Apple Silicon Mac."))
        #endif
    }

    public func generateFrame(_ spec: StoryboardFrameSpec) async throws -> Data {
        let state = await availability()
        guard case .ready = state else {
            throw StoryboardEngineError.notReady(state)
        }
        guard let core = Self.core else {
            throw StoryboardEngineError.generationFailed(
                "The storyboard engine core isn't part of this build yet — the model is downloaded and ready for it.")
        }
        let prompt = StoryboardPromptStyler.prompt(subject: spec.subject,
                                                   notes: spec.notes)
        do {
            return try await core.renderFrame(prompt: prompt,
                                              width: spec.width,
                                              height: spec.height,
                                              seed: spec.seed,
                                              weightsDirectory: weightsDirectory)
        } catch let error as StoryboardEngineError {
            throw error
        } catch {
            throw StoryboardEngineError.generationFailed(String(describing: error))
        }
    }
}
