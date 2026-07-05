// DirectorsChairCore/Sources/DirectorsChairCore/Models/Dialogue.swift
//
// Dialogue line model with audio support

import Foundation

/// Represents a single dialogue line in a scene
public struct Dialogue: Codable, Identifiable, Hashable, Sendable {
    public var id: String { uuid }

    public var uuid: String  // Unique identifier
    public var character: String  // Name of character speaking
    public var text: String  // Dialogue text content
    public var tags: [String]  // Tone, emotion, or note tags
    public var costumes: [String]  // Costume pieces for this dialogue
    public var effects: [String]  // Special effects cues
    public var chronologyNumber: Int  // Order in scene
    public var globalChronologyNumber: Int  // Global order across project
    public var audioFilePath: String?  // Path to TTS or audio file
    public var manualDuration: Double?  // User-specified duration override (seconds)
    public var manualStartTime: Double?  // User-specified timeline position override (seconds)

    public init(
        uuid: String = UUID().uuidString,
        character: String,
        text: String,
        tags: [String] = [],
        costumes: [String] = [],
        effects: [String] = [],
        chronologyNumber: Int = 0,
        globalChronologyNumber: Int = 0,
        audioFilePath: String? = nil,
        manualDuration: Double? = nil,
        manualStartTime: Double? = nil
    ) {
        self.uuid = uuid
        self.character = character
        self.text = text
        self.tags = tags
        self.costumes = costumes
        self.effects = effects
        self.chronologyNumber = chronologyNumber
        self.globalChronologyNumber = globalChronologyNumber
        self.audioFilePath = audioFilePath
        self.manualDuration = manualDuration
        self.manualStartTime = manualStartTime
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case character
        case text
        case tags
        case costumes
        case effects
        case chronologyNumber = "chronology_number"
        case globalChronologyNumber = "global_chronology_number"
        case audioFilePath = "audio_file_path"
        case manualDuration = "manual_duration"
        case manualStartTime = "manual_start_time"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generate UUID if not present
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString

        // Required fields
        character = try container.decodeIfPresent(String.self, forKey: .character) ?? ""
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        chronologyNumber = try container.decodeIfPresent(Int.self, forKey: .chronologyNumber) ?? 0
        globalChronologyNumber = try container.decodeIfPresent(Int.self, forKey: .globalChronologyNumber) ?? 0

        // Optional arrays - provide empty defaults
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        costumes = try container.decodeIfPresent([String].self, forKey: .costumes) ?? []
        effects = try container.decodeIfPresent([String].self, forKey: .effects) ?? []

        // Optional fields
        audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)
        manualDuration = try container.decodeIfPresent(Double.self, forKey: .manualDuration)
        manualStartTime = try container.decodeIfPresent(Double.self, forKey: .manualStartTime)
    }
}
