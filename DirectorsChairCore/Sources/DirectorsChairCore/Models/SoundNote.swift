// DirectorsChairCore/Sources/DirectorsChairCore/Models/SoundNote.swift
//
// Sound note model for background sounds, music, and effects

import Foundation

/// Represents a sound note in a scene (background sounds, music, SFX)
public struct SoundNote: Codable, Identifiable, Hashable {
    public var id: String { "\(chronologyNumber)-sound" }

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

    public init(
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
        timestampEnd: String? = nil
    ) {
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
    }

    enum CodingKeys: String, CodingKey {
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
    }
}
