// DirectorsChairServices/Storyboard/LocalImageEngine.swift
//
// The on-device image backend (DC-0063 manager, DC-0068 FLUX.2 klein):
// owns the consent-gated weight download, disk preflight, ready state,
// and the look/purpose prompt layer — and delegates actual diffusion to
// the injected OnDeviceImageGenerating core, which only exists inside
// app bundles (MLX metallib rule). Mirrors MLXInsightEngine:
// weights live under Application Support so cache purges don't cost the
// user a 5.5GB re-download; a ready marker is written only after a
// COMPLETE snapshot; availability checks the marker FIRST (the DC-0060
// stuck-progress lesson).

import Foundation
import DirectorsChairCore
#if arch(arm64)
import Hub
#endif

public final class LocalImageEngine: StoryboardEngine, @unchecked Sendable {

    /// One engine per app (ShortcutStore.shared precedent) — state is a
    /// download in flight plus markers, never per-view.
    public static let shared = LocalImageEngine()

    /// The single bundled model (owner decision 2026-08-25 — no picker).
    public static let model = StoryboardModel.fluxKlein4B

    /// The diffusion core (DC-0068): the native MLX klein pipeline by
    /// default on Apple Silicon — construction touches no MLX state, so
    /// SPM test runners stay safe (the metallib rule) and tests swap in
    /// scripted cores freely. nil (non-arm64) keeps generateFrame failing
    /// with an honest message instead of a broken surface.
    nonisolated(unsafe) public static var core: (any OnDeviceImageGenerating)? = {
        #if arch(arm64)
        return KleinCore()
        #else
        return nil
        #endif
    }()

    /// Free space the preflight insists on BEYOND the model itself —
    /// downloading 5.5GB onto a nearly-full disk trades a feature for a
    /// broken Mac (dev machine at 8GB free, 2026-08-24).
    public static let downloadHeadroomBytes: Int64 = 2_000_000_000

    /// Purposes whose drawing must hold no people; a figure in one is
    /// redrawn on the next seed, up to `peopleRedrawAttempts` renders.
    public static func redrawsOnPeople(_ purpose: VisualPurpose) -> Bool {
        purpose == .location || purpose == .prop
    }
    public static let peopleRedrawAttempts = 3
    /// The figure detector (Apple Vision); a seam so tests can script it.
    nonisolated(unsafe) public static var peopleDetector: @Sendable (Data) -> Bool = {
        HumanPresence.detected(in: $0)
    }

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

    /// Whether the engine can actually DRAW right now — availability
    /// downgraded while the diffusion core (DC-0065) is absent. The
    /// provider chips gate on this, never on the download alone: a
    /// selectable option that cannot render is a broken surface.
    public func generationAvailability() async -> InsightAvailability {
        let state = await availability()
        if case .ready = state, Self.core == nil {
            return .unavailable(reason:
                "The sketch engine is still being built — the model is downloaded and ready for it.")
        }
        return state
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
            retireReplacedModels()
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

    /// Removes the weights and marker of the model this build replaced
    /// (Z-Image Turbo, 5.5GB) once the current model is on disk — never
    /// before, so a failed download can't leave the user with nothing.
    func retireReplacedModels() {
        let fm = FileManager.default
        let retiredId = StoryboardModel.retiredZImageTurboId
        let retiredMarker = storageRoot.appendingPathComponent(
            ".ready-\(retiredId.replacingOccurrences(of: "/", with: "_"))")
        let retiredWeights = storageRoot
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(retiredId, isDirectory: true)
        try? fm.removeItem(at: retiredMarker)
        try? fm.removeItem(at: retiredWeights)
        // The org folder, if now empty.
        let org = retiredWeights.deletingLastPathComponent()
        if let left = try? fm.contentsOfDirectory(atPath: org.path), left.isEmpty {
            try? fm.removeItem(at: org)
        }
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
        // The look: the spec's explicit choice, else the owner's Settings
        // choice at this moment (DC-0066) — never a hardcoded style.
        let style = spec.style ?? AIProviderSelection.shared.visualStyle
        // Story purposes are drawn from what the camera SEES, not from the
        // action line (prose becomes lettering; see VisualBriefWriter).
        var drawn = spec
        if [.shot, .scene, .moodboard].contains(spec.purpose) {
            drawn.subject = await VisualBriefWriter.visualDescription(of: spec.subject)
        }
        // A continuity edit of an ink drawing must stay ink (DC-0071).
        let monochromeReference = spec.references.first.map { StoryboardSubjects.isNearMonochrome($0) } ?? false
        let prompt = StoryboardPromptStyler.prompt(drawn, style: style, referenceIsMonochrome: monochromeReference)
        if ProcessInfo.processInfo.environment["DC_KLEIN_PROMPTTRACE"] == "1" {
            print("[KleinPrompt] rewritten=\(drawn.subject != spec.subject)\n\(prompt)")
        }
        do {
            // A place or an object that gained a figure is redrawn on the
            // next seed (DC-0071): the model puts people where it expects
            // them — a chef in a kitchen, a walker on a path — and the
            // prompt alone does not stop it every time.
            let redrawOnPeople = Self.redrawsOnPeople(spec.purpose)
            let attempts = redrawOnPeople ? Self.peopleRedrawAttempts : 1
            let baseSeed = spec.seed ?? (redrawOnPeople ? UInt64.random(in: 0..<1_000_000) : nil)
            var frame = Data()
            for attempt in 0..<attempts {
                let seed = baseSeed.map { $0 &+ UInt64(attempt) }
                // A declared activity keeps App Nap off the render (DC-0071).
                frame = try await LocalModelActivity.perform("Drawing on the local image model") {
                    try await core.render(
                        OnDeviceRenderRequest(prompt: prompt, width: spec.width, height: spec.height,
                                              seed: seed, references: spec.references,
                                              editRegions: spec.editRegions),
                        weightsDirectory: weightsDirectory)
                }
                guard redrawOnPeople, attempt + 1 < attempts, Self.peopleDetector(frame) else { break }
                if ProcessInfo.processInfo.environment["DC_KLEIN_PROMPTTRACE"] == "1" {
                    print("[KleinPrompt] a figure in the \(spec.purpose.rawValue) drawing — redrawing on the next seed")
                }
            }
            return frame
        } catch let error as StoryboardEngineError {
            throw error
        } catch {
            throw StoryboardEngineError.generationFailed(String(describing: error))
        }
    }
}
