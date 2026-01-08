// DirectorsChairCore/Sources/DirectorsChairCore/Models/Dialogue.swift
//
// Dialogue line model with audio support

import Foundation

/// Represents a single dialogue line in a scene
public struct Dialogue: Codable, Identifiable, Hashable {
    public var id: String { "\(chronologyNumber)-\(character)-\(globalChronologyNumber)" }

    public var character: String  // Name of character speaking
    public var text: String  // Dialogue text content
    public var tags: [String]  // Tone, emotion, or note tags
    public var costumes: [String]  // Costume pieces for this dialogue
    public var effects: [String]  // Special effects cues
    public var chronologyNumber: Int  // Order in scene
    public var globalChronologyNumber: Int  // Global order across project
    public var audioFilePath: String?  // Path to TTS or audio file
    public var manualDuration: Double?  // User-specified duration override (seconds)

    public init(
        character: String,
        text: String,
        tags: [String] = [],
        costumes: [String] = [],
        effects: [String] = [],
        chronologyNumber: Int = 0,
        globalChronologyNumber: Int = 0,
        audioFilePath: String? = nil,
        manualDuration: Double? = nil
    ) {
        self.character = character
        self.text = text
        self.tags = tags
        self.costumes = costumes
        self.effects = effects
        self.chronologyNumber = chronologyNumber
        self.globalChronologyNumber = globalChronologyNumber
        self.audioFilePath = audioFilePath
        self.manualDuration = manualDuration
    }

    enum CodingKeys: String, CodingKey {
        case character
        case text
        case tags
        case costumes
        case effects
        case chronologyNumber = "chronology_number"
        case globalChronologyNumber = "global_chronology_number"
        case audioFilePath = "audio_file_path"
        case manualDuration = "manual_duration"
    }
}
