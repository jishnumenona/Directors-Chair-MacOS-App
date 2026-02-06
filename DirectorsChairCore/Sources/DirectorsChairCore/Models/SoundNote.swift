// DirectorsChairCore/Sources/DirectorsChairCore/Models/SoundNote.swift
//
// Sound note model for background sounds, music, and effects

import Foundation

/// Represents a sound note in a scene (background sounds, music, SFX)
public struct SoundNote: Codable, Identifiable, Hashable {
    public var id: String { uuid }

    public var uuid: String  // Unique identifier
    public var description: String  // Text description of the sound
    public var soundType: String  // "ambient", "music", "effects", "dialogue_sfx"
    public var chronologyNumber: Int  // Order in scene
    public var audioFilePath: String?  // Path to audio file
    public var volume: Int  // 0-100
    public var loop: Bool  // Whether sound should loop
    public var fadeInDuration: Double  // Fade in duration (seconds)
    public var fadeOutDuration: Double  // Fade out duration (seconds)
    public var startTime: Double?  // Start time in scene (seconds)
    public var endTime: Double?  // End time in scene (seconds)
    public var tags: [String]  // Tags for categorization
    public var referenceUrl: String?  // Reference URL (e.g., YouTube)
    public var timestampStart: String?  // Start timestamp (e.g., "01:23")
    public var timestampEnd: String?  // End timestamp
    public var parentDialogueId: String?  // ID of parent dialogue if connected as sub-bubble
    public var manualStartTime: Double?  // User-specified timeline position override (seconds)

    public init(
        uuid: String = UUID().uuidString,
        description: String = "",
        soundType: String = "ambient",
        chronologyNumber: Int = 0,
        audioFilePath: String? = nil,
        volume: Int = 100,
        loop: Bool = false,
        fadeInDuration: Double = 0.0,
        fadeOutDuration: Double = 0.0,
        startTime: Double? = nil,
        endTime: Double? = nil,
        tags: [String] = [],
        referenceUrl: String? = nil,
        timestampStart: String? = nil,
        timestampEnd: String? = nil,
        parentDialogueId: String? = nil,
        manualStartTime: Double? = nil
    ) {
        self.uuid = uuid
        self.description = description
        self.soundType = soundType
        self.chronologyNumber = chronologyNumber
        self.audioFilePath = audioFilePath
        self.volume = max(0, min(100, volume))  // Clamp 0-100
        self.loop = loop
        self.fadeInDuration = max(0.0, fadeInDuration)
        self.fadeOutDuration = max(0.0, fadeOutDuration)
        self.startTime = startTime
        self.endTime = endTime
        self.tags = tags
        self.referenceUrl = referenceUrl
        self.timestampStart = timestampStart
        self.timestampEnd = timestampEnd
        self.parentDialogueId = parentDialogueId
        self.manualStartTime = manualStartTime
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case description
        case soundType = "sound_type"
        case chronologyNumber = "chronology_number"
        case audioFilePath = "audio_file_path"
        case volume
        case loop
        case fadeInDuration = "fade_in_duration"
        case fadeOutDuration = "fade_out_duration"
        case startTime = "start_time"
        case endTime = "end_time"
        case tags
        case referenceUrl = "reference_url"
        case timestampStart = "timestamp_start"
        case timestampEnd = "timestamp_end"
        case parentDialogueId = "parent_dialogue_id"
        case manualStartTime = "manual_start_time"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generate UUID if not present
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString

        // Required fields with defaults
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        soundType = try container.decodeIfPresent(String.self, forKey: .soundType) ?? "ambient"
        chronologyNumber = try container.decodeIfPresent(Int.self, forKey: .chronologyNumber) ?? 0

        let vol = try container.decodeIfPresent(Int.self, forKey: .volume) ?? 100
        volume = max(0, min(100, vol))  // Clamp 0-100

        loop = try container.decodeIfPresent(Bool.self, forKey: .loop) ?? false

        let fadeIn = try container.decodeIfPresent(Double.self, forKey: .fadeInDuration) ?? 0.0
        fadeInDuration = max(0.0, fadeIn)

        let fadeOut = try container.decodeIfPresent(Double.self, forKey: .fadeOutDuration) ?? 0.0
        fadeOutDuration = max(0.0, fadeOut)

        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        // Optional fields
        audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)
        startTime = try container.decodeIfPresent(Double.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Double.self, forKey: .endTime)
        referenceUrl = try container.decodeIfPresent(String.self, forKey: .referenceUrl)
        timestampStart = try container.decodeIfPresent(String.self, forKey: .timestampStart)
        timestampEnd = try container.decodeIfPresent(String.self, forKey: .timestampEnd)

        // Parent dialogue connection
        parentDialogueId = try container.decodeIfPresent(String.self, forKey: .parentDialogueId)
        manualStartTime = try container.decodeIfPresent(Double.self, forKey: .manualStartTime)
    }
}
