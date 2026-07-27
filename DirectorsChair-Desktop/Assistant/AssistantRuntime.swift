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

    /// Mirrors the app's AIServiceClient token wiring (single 401 refresh);
    /// AuthManager is @MainActor, so both closures hop for its state.
    func configure(authManager: AuthManager) {
        transport.tokenProvider = { [weak authManager] in
            await MainActor.run { authManager?.currentAccessToken }
        }
        transport.tokenRefresher = { [weak authManager] in
            guard let authManager else { return nil }
            try? await authManager.forceRefreshToken()
            return await MainActor.run { authManager.currentAccessToken }
        }
    }

    /// A fresh engine per turn: the registry is rebuilt so its weak seams
    /// track the live view models, and configuration stays current.
    func makeEngine(registry: ActionRegistry) -> AssistantEngine {
        AssistantEngine(
            transport: transport,
            registry: registry,
            configuration: EngineConfiguration(provider: "google"))
    }
}
