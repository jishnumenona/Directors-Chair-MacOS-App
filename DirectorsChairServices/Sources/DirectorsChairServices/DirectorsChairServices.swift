// DirectorsChairServices
// AI, TTS, Git, and background services for DirectorsChair application
//
// Phase 2: Services Layer
// Owner: Agent 3 (Characters & AI)

import Foundation
@_exported import DirectorsChairCore

/// Version information for DirectorsChairServices module
public struct DirectorsChairServicesVersion {
    public static let version = "1.0.0"
    public static let build = "2026.01.12"
    public static let phase = "Phase 2 - Services Layer"
}

/// Initialize all services
public func initializeServices() {
    // Services are lazily initialized via their shared instances
    // This function can be used for any setup that needs to happen at app launch
}

/// Get the shared AI service client
public func getAIServiceClient() -> AIServiceClient {
    return AIServiceClient.shared
}

/// Get the shared background task manager
public func getBackgroundTaskManager() -> BackgroundTaskManager {
    return BackgroundTaskManager.shared
}
