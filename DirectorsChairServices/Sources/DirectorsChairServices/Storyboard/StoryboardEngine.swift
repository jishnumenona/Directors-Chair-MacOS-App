// DirectorsChairServices/Storyboard/StoryboardEngine.swift
//
// The engine seam for on-device storyboard frames (DC-0062/DC-0063):
// sketch-style scene/shot visualizations generated locally by a bundled
// open image model, mirroring the InsightEngine discipline — UI and
// callers only ever see this protocol, availability states explain
// themselves, and a multi-gigabyte download only ever starts from an
// explicit consent button (Product-Versions v1.8 §3.7).

import Foundation
import DirectorsChairCore

// MARK: - Model identity

/// The bundled storyboard model. One model by owner decision (2026-08-25):
/// a single "Storyboard" download, not a picker.
public struct StoryboardModel: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let approxBytes: Int64
    public let detail: String

    /// Z-Image Turbo, pre-quantized 4-bit for MLX (Apache-2.0). Size is
    /// the repo total measured via the HF API on 2026-08-25 — shown in
    /// the consent UI, so it must stay honest.
    public static let zImageTurbo = StoryboardModel(
        id: "filipstrand/Z-Image-Turbo-mflux-4bit",
        displayName: "Z-Image Turbo",
        approxBytes: 5_916_000_000,
        detail: "6B open image model (Apache-2.0) — draws ink-sketch storyboard frames on this Mac")
}

// MARK: - Visual style & purpose (DC-0066)

/// The look the owner chooses for every on-device drawing (Settings →
/// Storyboard Model). Two looks by owner decision 2026-08-25: a pencil
/// & ink sketch, or a comic-book panel. Raw values are the stored
/// preference — stable, never rename.
public enum VisualStyle: String, CaseIterable, Sendable {
    case sketch
    case comic

    public var displayName: String {
        switch self {
        case .sketch: return "Sketch"
        case .comic: return "Comic"
        }
    }

    public var detail: String {
        switch self {
        case .sketch: return "Pencil & ink linework on white paper — the classic storyboard look"
        case .comic: return "Bold inks, flat printed colour and halftone — costume and character ideas in colour"
        }
    }
}

/// What the drawing is FOR. Each purpose has its own subject lead and a
/// default framing so a costume comes out as a full-figure design sheet
/// and a scene as an establishing view — not the same generic picture.
public enum VisualPurpose: String, Sendable {
    case shot
    case scene
    case character
    case costume
    case location
    case moodboard
}

/// The clean, provider-neutral description of a picture: plain language
/// about WHAT is in it (no "cinematic film still", no lens jargon, no
/// negatives) plus optional framing direction. Cloud providers keep
/// their photoreal prompts; the on-device engine draws from this.
public struct VisualBrief: Equatable, Sendable {
    public var purpose: VisualPurpose
    public var subject: String
    public var framing: String?

    public init(purpose: VisualPurpose, subject: String, framing: String? = nil) {
        self.purpose = purpose
        self.subject = subject
        self.framing = framing
    }
}

// MARK: - Frame request

/// One storyboard frame ask. The subject is plain scene/shot language —
/// the visual style is applied by StoryboardPromptStyler, never by
/// callers, so every frame in a project speaks the same line language.
public struct StoryboardFrameSpec: Equatable, Sendable {
    public var subject: String
    public var notes: String?
    public var width: Int
    public var height: Int
    public var seed: UInt64?
    public var purpose: VisualPurpose
    /// nil = the owner's Settings choice at generation time.
    public var style: VisualStyle?

    /// 16:9 default (768×432, both multiples of 16 for the latent grid) —
    /// storyboard frames are film frames, not squares.
    public init(subject: String, notes: String? = nil,
                width: Int = 768, height: Int = 432, seed: UInt64? = nil,
                purpose: VisualPurpose = .shot, style: VisualStyle? = nil) {
        self.subject = subject
        self.notes = notes
        self.width = width
        self.height = height
        self.seed = seed
        self.purpose = purpose
        self.style = style
    }

    public init(brief: VisualBrief, width: Int = 768, height: Int = 432,
                seed: UInt64? = nil, style: VisualStyle? = nil) {
        self.init(subject: brief.subject, notes: brief.framing,
                  width: width, height: height, seed: seed,
                  purpose: brief.purpose, style: style)
    }
}

// MARK: - Errors

public enum StoryboardEngineError: Error, Equatable, Sendable {
    case notReady(InsightAvailability)
    /// The download preflight refused: filling a nearly-full disk with a
    /// ~5.5GB model breaks Macs worse than a missing feature does (found
    /// the hard way on the dev machine at 8GB free, 2026-08-24).
    case insufficientDisk(neededBytes: Int64, freeBytes: Int64)
    case downloadFailed(String)
    case generationFailed(String)
    case cancelled

    /// One user-facing wording for every generation surface (grid, scene
    /// strip) — states explain themselves, never a broken surface. The
    /// preferences pane keeps its own richer download wording.
    public var userMessage: String {
        switch self {
        case .notReady(.unavailable(let reason)):
            return reason
        case .notReady:
            return "The Storyboard model isn't downloaded yet — get it in Settings → AI Services (5.5 GB, runs on this Mac, free)."
        case .insufficientDisk(let needed, let free):
            let fmt = { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
            return "Not enough disk space: needs \(fmt(needed)) free, this Mac has \(fmt(free))."
        case .downloadFailed(let reason):
            return "Model download failed — \(reason)"
        case .generationFailed(let reason):
            return reason
        case .cancelled:
            return "Sketch cancelled."
        }
    }
}

// MARK: - Engine protocol

/// One on-device storyboard backend. Reuses InsightAvailability so the
/// consent/progress UI pattern carries over unchanged.
public protocol StoryboardEngine: AnyObject, Sendable {
    /// Current state — cheap to read, safe to poll.
    func availability() async -> InsightAvailability

    /// Fetch the model weights after consent. Progress lands in
    /// `availability()`. A no-op when already ready. Throws
    /// `StoryboardEngineError.insufficientDisk` before writing a byte
    /// when the volume can't hold the model plus headroom.
    func prepare() async throws

    /// Render one frame as PNG data in the locked storyboard style.
    func generateFrame(_ spec: StoryboardFrameSpec) async throws -> Data
}

// MARK: - Inference-core seam

/// What the storyboard engine needs from the actual image pipeline
/// (DC-0065) — a seam so unit tests never touch MLX (its metallib only
/// exists inside app bundles; SPM test runners abort on it), and so the
/// download/consent machinery ships and is testable independently of
/// the diffusion core.
public protocol OnDeviceImageGenerating: Sendable {
    /// `prompt` is the fully-styled text; `weightsDirectory` is where the
    /// engine's snapshot lives on disk. Returns encoded PNG bytes.
    func renderFrame(prompt: String, width: Int, height: Int,
                     seed: UInt64?, weightsDirectory: URL) async throws -> Data
}

// MARK: - Test double

/// Deterministic engine for tests and previews: scripted availability,
/// scripted frames, recorded specs.
public final class ScriptedStoryboardEngine: StoryboardEngine, @unchecked Sendable {
    private let lock = NSLock()
    private var _availability: InsightAvailability
    private var result: Result<Data, StoryboardEngineError>
    public private(set) var preparations = 0
    public private(set) var requests: [StoryboardFrameSpec] = []

    public init(availability: InsightAvailability = .ready,
                result: Result<Data, StoryboardEngineError> = .success(Data([0x89, 0x50, 0x4E, 0x47]))) {
        self._availability = availability
        self.result = result
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

    public func generateFrame(_ spec: StoryboardFrameSpec) async throws -> Data {
        let (state, scripted) = withLock { () -> (InsightAvailability, Result<Data, StoryboardEngineError>) in
            requests.append(spec)
            return (_availability, result)
        }
        guard state == .ready else { throw StoryboardEngineError.notReady(state) }
        return try scripted.get()
    }
}
