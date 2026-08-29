// DirectorsChairServices/AI/AIProviderSelection.swift
//
// Per-function AI service choice (DC-0056). Three pieces, one file:
//
//  AIFunction        — the app's AI FUNCTIONS (what the user is doing),
//                      as opposed to providers (who does it).
//  AIProviderCatalog — the honest truth table: which services can do each
//                      function ON THIS CLIENT's wire, and which gateway
//                      /health key tells us the server can actually serve
//                      them. Nothing dead is listed (the old preferences
//                      pane still offered Sora/Kling — providers the wire
//                      dropped in July 2026).
//  AIProviderSelection — the ONE place a generation call asks "which
//                      provider?". Reads the same UserDefaults keys the
//                      preferences pane writes, falls back to the shipped
//                      default, and refuses to return a service that
//                      cannot do the function (a stale stored value from
//                      an older build degrades to the default, silently
//                      and safely).

import Foundation

// MARK: - Functions

/// One AI-powered thing the user does in the app. Raw values are the
/// UserDefaults suffix — stable, never rename.
public enum AIFunction: String, CaseIterable, Identifiable, Sendable {
    case chat = "chat"                 // the assistant's agent loop
    case text = "text"                 // one-shot text generation
    case image = "image"               // stills: shots, characters, locations…
    case video = "video"               // Veo shot clips
    case speech = "speech"             // dialogue voices (TTS)
    case voiceReplies = "voiceReplies" // the assistant speaking its replies

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chat: return "AI Assistant (chat)"
        case .text: return "Text Generation"
        case .image: return "Image Generation"
        case .video: return "Video Generation"
        case .speech: return "Dialogue Voices"
        case .voiceReplies: return "Voice Replies"
        }
    }

    public var systemImage: String {
        switch self {
        case .chat: return "sparkles"
        case .text: return "text.bubble"
        case .image: return "photo"
        case .video: return "film"
        case .speech: return "waveform"
        case .voiceReplies: return "speaker.wave.2"
        }
    }

    /// The preferences key this function's choice lives under. chat/text/
    /// image/video/voiceReplies predate this file — their keys are frozen
    /// (existing users keep their choices); speech is new with DC-0056.
    public var preferenceKey: String {
        switch self {
        case .chat: return "pref.ai.chatProvider"
        case .text: return "pref.ai.textProvider"
        case .image: return "pref.ai.imageProvider"
        case .video: return "pref.ai.videoProvider"
        case .speech: return "pref.ai.speechProvider"
        case .voiceReplies: return "pref.ai.voiceReplyEngine"
        }
    }
}

// MARK: - Catalog

/// One selectable service for a function.
public struct AIServiceOption: Equatable, Identifiable, Sendable {
    /// The wire id sent to the gateway (or "device" for on-device engines).
    public let wireId: String
    public let displayName: String
    /// The gateway /health `providers` key that must be true for this
    /// option to work — nil for on-device options, which need no server.
    public let healthKey: String?
    /// DC-0057: true when the option runs on the bundled local model —
    /// available only while the DC-0055 engine reports READY (weights on
    /// disk, Apple Silicon). Distinct from plain on-device options like
    /// system TTS, which are always available.
    public let requiresLocalModel: Bool
    /// DC-0065: true when the option runs on the STORYBOARD image model —
    /// gated on that engine being able to actually draw (weights on disk
    /// AND the diffusion core present), the same never-assume-fine rule.
    public let requiresStoryboardModel: Bool

    public var id: String { wireId }

    public init(wireId: String, displayName: String, healthKey: String?,
                requiresLocalModel: Bool = false,
                requiresStoryboardModel: Bool = false) {
        self.wireId = wireId
        self.displayName = displayName
        self.healthKey = healthKey
        self.requiresLocalModel = requiresLocalModel
        self.requiresStoryboardModel = requiresStoryboardModel
    }
}

public enum AIProviderCatalog {

    /// The services that can genuinely do each function on this client's
    /// wire. This list IS the preferences UI — adding a provider here is
    /// the whole client-side story once the gateway serves it.
    public static func options(for function: AIFunction) -> [AIServiceOption] {
        switch function {
        case .chat:
            return [
                AIServiceOption(wireId: "google", displayName: "Google Gemini", healthKey: "google"),
                AIServiceOption(wireId: "anthropic", displayName: "Anthropic Claude", healthKey: "anthropic"),
                AIServiceOption(wireId: "deepseek", displayName: "DeepSeek", healthKey: "deepseek"),
                // DC-0059: conversation-only on-device chat — the local
                // model answers questions but cannot run project actions
                // (a 3B model can't drive the tool-call loop honestly).
                AIServiceOption(wireId: "device", displayName: "On-device (chat only)",
                                healthKey: nil, requiresLocalModel: true),
            ]
        case .text:
            return [
                AIServiceOption(wireId: "google", displayName: "Google Gemini", healthKey: "google"),
                AIServiceOption(wireId: "deepseek", displayName: "DeepSeek", healthKey: "deepseek"),
                AIServiceOption(wireId: "openai", displayName: "OpenAI", healthKey: "openai"),
                AIServiceOption(wireId: "anthropic", displayName: "Anthropic Claude", healthKey: "anthropic"),
                // DC-0057: the bundled local model (DC-0055's engine)
                // serves one-shot text — free, offline, selectable only
                // while its weights are actually on disk.
                AIServiceOption(wireId: "device", displayName: "On-device (local model)",
                                healthKey: nil, requiresLocalModel: true),
            ]
        case .image:
            return [
                AIServiceOption(wireId: "google_imagen", displayName: "Google Imagen", healthKey: "google"),
                AIServiceOption(wireId: "stability", displayName: "Stability AI", healthKey: "stability"),
                // DC-0065: the downloaded Storyboard model serves image
                // generation as ink-sketch frames — free and offline, and
                // deliberately sketch-only (Product-Versions v1.8 §3.7).
                AIServiceOption(wireId: "device", displayName: "On-device",
                                healthKey: nil, requiresStoryboardModel: true),
            ]
        case .video:
            // Veo is the only provider the wire can address (server spec
            // §19 decision) — the old Sora/Kling chips were dead options.
            return [
                AIServiceOption(wireId: "google_veo", displayName: "Google Veo", healthKey: "google_veo"),
            ]
        case .speech:
            return [
                AIServiceOption(wireId: "google", displayName: "Google Gemini", healthKey: "google"),
                AIServiceOption(wireId: "elevenlabs", displayName: "ElevenLabs", healthKey: "elevenlabs"),
            ]
        case .voiceReplies:
            return [
                AIServiceOption(wireId: "gemini", displayName: "Gemini (~1¢/reply)", healthKey: "google"),
                AIServiceOption(wireId: "device", displayName: "On-device (free)", healthKey: nil),
            ]
        }
    }

    /// The shipped default — always the FIRST catalog entry, so the
    /// default can never be a service the function doesn't offer.
    public static func defaultOption(for function: AIFunction) -> AIServiceOption {
        options(for: function)[0]
    }
}

// MARK: - Selection

/// The single resolution point between "the user picked services in
/// preferences" and "this call needs a provider". Reads the pane's
/// UserDefaults keys directly, so package call sites need no app types.
public final class AIProviderSelection: @unchecked Sendable {

    public static let shared = AIProviderSelection()

    let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The chosen wire id for a function — the stored choice when it is
    /// one of the function's real options, else the shipped default (a
    /// stale value from an older build must degrade safely, never reach
    /// the wire).
    public func wireId(for function: AIFunction) -> String {
        let stored = defaults.string(forKey: function.preferenceKey)
        let options = AIProviderCatalog.options(for: function)
        if let stored, options.contains(where: { $0.wireId == stored }) {
            return stored
        }
        return AIProviderCatalog.defaultOption(for: function).wireId
    }

    /// The same choice as a typed AIProvider for AIServiceClient requests.
    /// (voiceReplies' "device"/"gemini" ids are engine names, not wire
    /// providers — callers there use `wireId(for:)` directly.)
    public func provider(for function: AIFunction) -> AIProvider {
        AIProvider(rawValue: wireId(for: function))
            ?? AIProvider(rawValue: AIProviderCatalog.defaultOption(for: function).wireId)
            ?? .google
    }
}

// MARK: - Model choice (DC-0059)

/// One selectable model within a provider. `id` is the wire value the
/// gateway forwards verbatim to the provider ("" = the server's default —
/// the request omits the field entirely).
public struct AIModelOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    public static let serverDefault = AIModelOption(id: "", displayName: "Server default")
}

public enum AIModelCatalog {

    /// Models a provider genuinely accepts for a function, verified against
    /// the gateway adapters (every list starts with Server default — the
    /// adapter's own documented fallback). Functions absent here have no
    /// client model choice: VIDEO because the Veo adapter ignores request
    /// models (adapter-pinned), speech because only ElevenLabs would honor
    /// it. The local "device" service has its own catalog below.
    public static func options(for function: AIFunction,
                               wireId: String) -> [AIModelOption] {
        guard function == .text || function == .chat || function == .image else {
            return []
        }
        switch wireId {
        case "google" where function != .image:
            return [.serverDefault,
                    AIModelOption(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash (server default)"),
                    AIModelOption(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro")]
        case "deepseek":
            return [.serverDefault,
                    AIModelOption(id: "deepseek-chat", displayName: "DeepSeek Chat (server default)"),
                    AIModelOption(id: "deepseek-reasoner", displayName: "DeepSeek Reasoner")]
        case "openai":
            return [.serverDefault,
                    AIModelOption(id: "gpt-4o", displayName: "GPT-4o (server default)"),
                    AIModelOption(id: "gpt-4o-mini", displayName: "GPT-4o mini")]
        case "anthropic":
            return [.serverDefault,
                    AIModelOption(id: "claude-sonnet-5", displayName: "Claude Sonnet 5 (server default)"),
                    AIModelOption(id: "claude-opus-5", displayName: "Claude Opus 5"),
                    AIModelOption(id: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5")]
        case "google_imagen":
            return [.serverDefault,
                    AIModelOption(id: "gemini-2.5-flash-image", displayName: "Gemini 2.5 Flash Image (server default)"),
                    // DC-0090: the Gemini 3 image models honour the size class
                    // (2K/4K), so Full HD previews come out sharp instead of
                    // upscaled from 1344×768.
                    AIModelOption(id: "gemini-3.1-flash-image", displayName: "Gemini 3.1 Flash Image (true 2K/4K)"),
                    AIModelOption(id: "gemini-3-pro-image-preview", displayName: "Gemini 3 Pro Image (highest quality)")]
        case "stability":
            return [.serverDefault]
        default:
            return []
        }
    }

    /// Whether the pane should render a model picker for this pairing.
    public static func hasChoice(for function: AIFunction, wireId: String) -> Bool {
        options(for: function, wireId: wireId).count > 1
    }
}

/// The curated LOCAL models (DC-0059): one family, three sizes, all
/// ungated mlx-community 4-bit conversions — the 3B is the proven
/// original. Bigger sizes are for Macs with the memory to enjoy them.
public struct LocalModelOption: Equatable, Identifiable, Sendable {
    public let id: String            // Hugging Face repo id
    public let displayName: String
    public let approxBytes: Int64
    public let detail: String

    public init(id: String, displayName: String, approxBytes: Int64, detail: String) {
        self.id = id
        self.displayName = displayName
        self.approxBytes = approxBytes
        self.detail = detail
    }
}

public enum LocalModelCatalog {
    public static let options: [LocalModelOption] = [
        LocalModelOption(id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                         displayName: "Qwen 2.5 3B (balanced)",
                         approxBytes: 1_900_000_000,
                         detail: "The default — good quality, comfortable on 8GB Macs"),
        LocalModelOption(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                         displayName: "Qwen 2.5 1.5B (fast)",
                         approxBytes: 1_000_000_000,
                         detail: "Snappiest, lighter answers"),
        LocalModelOption(id: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                         displayName: "Qwen 2.5 7B (best quality)",
                         approxBytes: 4_400_000_000,
                         detail: "Needs a 16GB+ Mac"),
    ]

    public static let preferenceKey = "pref.ai.localModel"

    public static var selected: LocalModelOption {
        selected(in: .standard)
    }

    /// The stored choice, degraded to the default when the stored id is
    /// unknown (same fail-safe rule as provider selection).
    public static func selected(in defaults: UserDefaults) -> LocalModelOption {
        let stored = defaults.string(forKey: preferenceKey)
        return options.first { $0.id == stored } ?? options[0]
    }
}

extension AIProviderSelection {

    /// The chosen model for the function's CURRENT service, nil when the
    /// user left "Server default" (the request then omits the field and
    /// the adapter's documented fallback applies). Unknown stored values
    /// pass through deliberately — Custom entries are power-user wire ids.
    public func modelId(for function: AIFunction) -> String? {
        let stored = defaults.string(forKey: Self.modelKey(
            function: function, wireId: wireId(for: function)))
        guard let stored, !stored.isEmpty else { return nil }
        return stored
    }

    public static func modelKey(function: AIFunction, wireId: String) -> String {
        "pref.ai.model.\(function.rawValue).\(wireId)"
    }
}

// MARK: - Server availability

/// What the gateway can actually serve right now — the /health `providers`
/// map (spec §8.2: an adapter registers only when its key is configured).
public struct AIProviderHealth: Equatable, Sendable {
    public let providers: [String: Bool]
    public let checkedAt: Date

    public init(providers: [String: Bool], checkedAt: Date) {
        self.providers = providers
        self.checkedAt = checkedAt
    }

    /// nil healthKey = on-device = always available.
    public func isAvailable(_ option: AIServiceOption) -> Bool {
        guard let key = option.healthKey else { return true }
        return providers[key] ?? false
    }
}

/// Fetches the availability map. One call, tolerant decode: a degraded
/// gateway (503) still reports its providers, so preferences stay honest
/// even mid-incident.
public struct AIProviderHealthClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = ServiceEnvironment.aiProxyURL,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetch() async -> AIProviderHealth? {
        let url = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, _) = try? await session.data(for: request),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let providers = object["providers"] as? [String: Bool] else {
            return nil
        }
        return AIProviderHealth(providers: providers, checkedAt: Date())
    }
}

// MARK: - On-device visual style (DC-0066)

extension AIProviderSelection {

    /// UserDefaults key for the on-device look — stable, never rename.
    public static let visualStyleKey = "pref.ai.onDeviceVisualStyle"
    /// DC-0093: show every image prompt for review before it is sent.
    public static let reviewImagePromptsKey = "pref.ai.reviewImagePrompts"

    /// The look every on-device drawing uses (Settings → Storyboard
    /// Model). Unknown stored values degrade to Sketch, the classic
    /// storyboard look — the same fail-safe rule as provider selection.
    public var visualStyle: VisualStyle {
        get {
            VisualStyle(rawValue: defaults.string(forKey: Self.visualStyleKey) ?? "") ?? .sketch
        }
        set {
            defaults.set(newValue.rawValue, forKey: Self.visualStyleKey)
        }
    }
}
