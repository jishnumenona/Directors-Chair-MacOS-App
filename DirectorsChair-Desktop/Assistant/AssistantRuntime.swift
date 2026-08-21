//
//  AssistantRuntime.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A2.5: the app-scoped home of the assistant's
//  transport — configured once at startup with the same auth session the
//  AIServiceClient uses, shared by every chat turn.
//

import Foundation
import DirectorsChairServices
import DirectorsChairViews

@MainActor
final class AssistantRuntime {
    static let shared = AssistantRuntime()

    /// The SSE transport for the gateway's /generate/chat.
    let transport = GatewayChatTransport()

    /// The app-scoped video-job coordinator (owned by CentralViewStack,
    /// registered on appear) — lets assistant actions submit shot videos
    /// through the SAME lifecycle the Cinematography view uses.
    weak var videoJobs: VideoJobCoordinator?

    /// The session source for the engine's tier-filtered catalog
    /// (Product-Versions §5.2). Weak like videoJobs; before configure()
    /// runs, makeEngine falls back to `.free` (fail-closed).
    private weak var authManager: AuthManager?

    /// Mirrors the app's AIServiceClient token wiring (single 401 refresh);
    /// AuthManager is @MainActor, so both closures hop for its state.
    func configure(authManager: AuthManager) {
        self.authManager = authManager
        transport.tokenProvider = { [weak authManager] in
            await MainActor.run { authManager?.currentAccessToken }
        }
        transport.tokenRefresher = { [weak authManager] in
            guard let authManager else { return nil }
            try? await authManager.forceRefreshToken()
            return await MainActor.run { authManager.currentAccessToken }
        }
    }

    /// A6.5 routing table: the chat-capable providers — the gateway's
    /// three, plus DC-0059's on-device conversation-only mode. Anything
    /// else stored in preferences falls back to the default.
    static let chatProviders: Set<String> = ["google", "anthropic", "deepseek", "device"]

    /// Resolves the assistant's engine configuration from Preferences —
    /// the wired half of the AI Services pickers (A6.5 + DC-0059: the
    /// per-provider MODEL choice rides along; "device" carries no model
    /// field — the local engine follows the local-model preference).
    static func routedConfiguration() -> EngineConfiguration {
        let stored = UserDefaults.standard.string(forKey: PrefKey.aiChatProvider)
            ?? "google"
        let provider = chatProviders.contains(stored) ? stored : "google"
        var temperature = UserDefaults.standard.object(forKey: PrefKey.aiTemperature)
            .flatMap { $0 as? Double } ?? 0.7
        temperature = min(max(temperature, 0), 1)
        let model = provider == "device"
            ? nil : AIProviderSelection.shared.modelId(for: .chat)
        return EngineConfiguration(provider: provider, model: model,
                                   temperature: temperature)
    }

    /// A fresh engine per turn: the registry is rebuilt so its weak seams
    /// track the live view models, and configuration follows the routing
    /// table (Preferences → provider/temperature) plus the session tier
    /// (the engine advertises only the actions the tier includes).
    /// DC-0059: "device" chats through the local model — conversation
    /// only (the transport states the limitation to model and user).
    /// Static and pure so the owner-reported "says Gemini, which model
    /// actually answered?" class of doubt has a test, not a guess.
    static func chooseTransport(provider: String?,
                                gateway: any ChatTransporting) -> any ChatTransporting {
        provider == "device" ? LocalChatTransport() : gateway
    }

    func makeEngine(registry: ActionRegistry) -> AssistantEngine {
        var configuration = Self.routedConfiguration()
        configuration.sessionTier = authManager?.tier ?? .free  // fail-closed
        return AssistantEngine(
            transport: Self.chooseTransport(provider: configuration.provider,
                                            gateway: transport),
            registry: registry,
            configuration: configuration)
    }
}
