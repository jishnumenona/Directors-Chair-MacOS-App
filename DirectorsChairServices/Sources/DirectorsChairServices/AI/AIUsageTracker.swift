//
//  AIUsageTracker.swift
//  DirectorsChairServices
//
//  Tracks AI API usage costs per-project, persisted across relaunches
//

import Foundation

// MARK: - AI Usage Record

/// A single AI usage event
public struct AIUsageRecord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: UsageType
    public let provider: String
    public let model: String
    public let promptTokens: Int
    public let completionTokens: Int
    public let imageCount: Int
    public let costUSD: Double

    public enum UsageType: String, Codable, Sendable {
        case text
        case image
        case video
    }

    public let videoDurationSeconds: Double

    public init(
        type: UsageType,
        provider: String,
        model: String,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        imageCount: Int = 0,
        costUSD: Double = 0,
        videoDurationSeconds: Double = 0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.provider = provider
        self.model = model
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.imageCount = imageCount
        self.costUSD = costUSD
        self.videoDurationSeconds = videoDurationSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(UsageType.self, forKey: .type)
        provider = try container.decode(String.self, forKey: .provider)
        model = try container.decode(String.self, forKey: .model)
        promptTokens = try container.decode(Int.self, forKey: .promptTokens)
        completionTokens = try container.decode(Int.self, forKey: .completionTokens)
        imageCount = try container.decode(Int.self, forKey: .imageCount)
        costUSD = try container.decode(Double.self, forKey: .costUSD)
        videoDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .videoDurationSeconds) ?? 0
    }
}

// MARK: - AI Usage Stats

/// Aggregated usage statistics
public struct AIUsageStats: Codable, Sendable {
    public var totalPromptTokens: Int = 0
    public var totalCompletionTokens: Int = 0
    public var totalImages: Int = 0
    public var totalTextCalls: Int = 0
    public var totalImageCalls: Int = 0
    public var totalVideos: Int = 0
    public var totalVideoCalls: Int = 0
    public var totalVideoSeconds: Double = 0

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalPromptTokens = try container.decodeIfPresent(Int.self, forKey: .totalPromptTokens) ?? 0
        totalCompletionTokens = try container.decodeIfPresent(Int.self, forKey: .totalCompletionTokens) ?? 0
        totalImages = try container.decodeIfPresent(Int.self, forKey: .totalImages) ?? 0
        totalTextCalls = try container.decodeIfPresent(Int.self, forKey: .totalTextCalls) ?? 0
        totalImageCalls = try container.decodeIfPresent(Int.self, forKey: .totalImageCalls) ?? 0
        totalVideos = try container.decodeIfPresent(Int.self, forKey: .totalVideos) ?? 0
        totalVideoCalls = try container.decodeIfPresent(Int.self, forKey: .totalVideoCalls) ?? 0
        totalVideoSeconds = try container.decodeIfPresent(Double.self, forKey: .totalVideoSeconds) ?? 0
    }

    /// Cost per token (Google Gemini 2.5 Flash — ai.google.dev/gemini-api/docs/pricing)
    private static let textInputCostPerToken: Double = 0.0000003    // $0.30 / 1M tokens
    private static let textOutputCostPerToken: Double = 0.0000025   // $2.50 / 1M tokens
    private static let imageCostPerImage: Double = 0.04             // Imagen standard $0.04/image
    private static let videoCostPerSecond: Double = 0.02            // Proxy-mediated rate (not direct Veo API)

    public var textInputCostUSD: Double {
        Double(totalPromptTokens) * Self.textInputCostPerToken
    }

    public var textOutputCostUSD: Double {
        Double(totalCompletionTokens) * Self.textOutputCostPerToken
    }

    public var imageCostUSD: Double {
        Double(totalImages) * Self.imageCostPerImage
    }

    public var videoCostUSD: Double {
        totalVideoSeconds * Self.videoCostPerSecond
    }

    public var totalCostUSD: Double {
        textInputCostUSD + textOutputCostUSD + imageCostUSD + videoCostUSD
    }

    public var totalCalls: Int {
        totalTextCalls + totalImageCalls + totalVideoCalls
    }

    public mutating func addTextUsage(promptTokens: Int, completionTokens: Int) {
        totalPromptTokens += promptTokens
        totalCompletionTokens += completionTokens
        totalTextCalls += 1
    }

    public mutating func addImageUsage(imageCount: Int) {
        totalImages += imageCount
        totalImageCalls += 1
    }

    public mutating func addVideoUsage(durationSeconds: Double) {
        totalVideos += 1
        totalVideoCalls += 1
        totalVideoSeconds += durationSeconds
    }

    /// Cost for a specific text call
    public static func textCallCost(promptTokens: Int, completionTokens: Int) -> Double {
        Double(promptTokens) * textInputCostPerToken + Double(completionTokens) * textOutputCostPerToken
    }

    /// Cost for a specific image call
    public static func imageCallCost(imageCount: Int) -> Double {
        Double(imageCount) * imageCostPerImage
    }

    /// Cost for a specific video call (proxy-mediated flat rate)
    public static func videoCallCost(durationSeconds: Double, quality: String = "High") -> Double {
        return durationSeconds * videoCostPerSecond
    }
}

// MARK: - Persisted Project Usage

/// Full per-project usage data that gets saved to disk
struct ProjectUsageData: Codable {
    var projectStats: AIUsageStats = AIUsageStats()
    var records: [AIUsageRecord] = []
}

// MARK: - AI Usage Tracker

/// Singleton that tracks AI API usage per-project, persisted to disk
@MainActor
public final class AIUsageTracker: ObservableObject {

    public static let shared = AIUsageTracker()

    // MARK: - Published Properties

    /// Stats for current session only (resets on app relaunch)
    @Published public var sessionStats = AIUsageStats()

    /// Stats for the active project (persisted across relaunches)
    @Published public var projectStats = AIUsageStats()

    /// Kept for backward compatibility — returns projectStats
    public var lifetimeStats: AIUsageStats {
        get { projectStats }
        set { projectStats = newValue }
    }

    /// Recent usage records for this project (persisted)
    @Published public var recentRecords: [AIUsageRecord] = []

    // MARK: - State

    private var currentProjectName: String = ""
    private let usageDirectory: URL

    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        usageDirectory = appSupport.appendingPathComponent("DirectorsChair/ai_usage")
        try? FileManager.default.createDirectory(at: usageDirectory, withIntermediateDirectories: true)

        // Migrate any existing UserDefaults lifetime stats to "default" project
        migrateFromUserDefaults()
    }

    // MARK: - Project Switching

    /// Set the active project. Saves current project's data and loads the new project's data.
    public func setProjectName(_ name: String) {
        let sanitized = sanitize(name)
        guard sanitized != currentProjectName else { return }

        // Save current project before switching
        if !currentProjectName.isEmpty {
            saveProjectData()
        }

        currentProjectName = sanitized
        sessionStats = AIUsageStats()
        loadProjectData()
    }

    // MARK: - Recording

    public func recordTextUsage(provider: String, model: String, promptTokens: Int, completionTokens: Int) {
        let cost = AIUsageStats.textCallCost(promptTokens: promptTokens, completionTokens: completionTokens)

        let record = AIUsageRecord(
            type: .text,
            provider: provider,
            model: model,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            costUSD: cost
        )

        sessionStats.addTextUsage(promptTokens: promptTokens, completionTokens: completionTokens)
        projectStats.addTextUsage(promptTokens: promptTokens, completionTokens: completionTokens)

        appendRecord(record)
        saveProjectData()
    }

    public func recordImageUsage(provider: String, model: String, imageCount: Int) {
        let cost = AIUsageStats.imageCallCost(imageCount: imageCount)

        let record = AIUsageRecord(
            type: .image,
            provider: provider,
            model: model,
            imageCount: imageCount,
            costUSD: cost
        )

        sessionStats.addImageUsage(imageCount: imageCount)
        projectStats.addImageUsage(imageCount: imageCount)

        appendRecord(record)
        saveProjectData()
    }

    public func recordVideoUsage(provider: String, model: String, durationSeconds: Double, quality: String) {
        let cost = AIUsageStats.videoCallCost(durationSeconds: durationSeconds, quality: quality)

        let record = AIUsageRecord(
            type: .video,
            provider: provider,
            model: model,
            costUSD: cost,
            videoDurationSeconds: durationSeconds
        )

        sessionStats.addVideoUsage(durationSeconds: durationSeconds)
        projectStats.addVideoUsage(durationSeconds: durationSeconds)

        appendRecord(record)
        saveProjectData()
    }

    // MARK: - Reset

    public func resetSession() {
        sessionStats = AIUsageStats()
    }

    public func resetLifetime() {
        projectStats = AIUsageStats()
        recentRecords = []
        saveProjectData()
    }

    // MARK: - Persistence (per-project JSON files)

    private func appendRecord(_ record: AIUsageRecord) {
        recentRecords.append(record)
        if recentRecords.count > 100 {
            recentRecords.removeFirst(recentRecords.count - 100)
        }
    }

    private func projectFilePath() -> URL {
        let filename = currentProjectName.isEmpty ? "_default" : currentProjectName
        return usageDirectory.appendingPathComponent("\(filename).json")
    }

    private func saveProjectData() {
        let data = ProjectUsageData(
            projectStats: projectStats,
            records: recentRecords
        )
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: projectFilePath())
        }
    }

    private func loadProjectData() {
        let path = projectFilePath()
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let decoded = try? JSONDecoder().decode(ProjectUsageData.self, from: data) else {
            projectStats = AIUsageStats()
            recentRecords = []
            return
        }
        projectStats = decoded.projectStats
        recentRecords = decoded.records
    }

    // MARK: - Migration from UserDefaults

    private func migrateFromUserDefaults() {
        let key = "AIUsageTracker.lifetimeStats"
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(AIUsageStats.self, from: data) else { return }

        // Only migrate if there's actual usage and no default file yet
        guard stats.totalCalls > 0 else { return }
        let defaultPath = usageDirectory.appendingPathComponent("_default.json")
        guard !FileManager.default.fileExists(atPath: defaultPath.path) else { return }

        let migrated = ProjectUsageData(projectStats: stats, records: [])
        if let encoded = try? JSONEncoder().encode(migrated) {
            try? encoded.write(to: defaultPath)
        }

        // Remove old key
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
