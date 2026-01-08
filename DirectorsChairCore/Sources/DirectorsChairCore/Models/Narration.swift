// DirectorsChairCore/Sources/DirectorsChairCore/Models/Narration.swift
//
// Narration/voice-over model

import Foundation

/// Represents a narration element (voice-over, not tied to a character)
public struct Narration: Codable, Identifiable, Hashable {
    public var id: String { "\(chronologyNumber)-narration-\(globalChronologyNumber)" }

    public var text: String  // Narration text content
    public var tags: [String]  // Mood, timing, or note tags
    public var costumes: [String]  // Costume pieces for this narration
    public var effects: [String]  // Special effects cues
    public var color: String  // Custom background color (empty = theme default)
    public var textColor: String  // Custom text color (empty = theme default)
    public var chronologyNumber: Int  // Order in scene
    public var globalChronologyNumber: Int  // Global order across project
    public var characters: [String]  // Characters involved in this narration

    public init(
        text: String,
        tags: [String] = [],
        costumes: [String] = [],
        effects: [String] = [],
        color: String = "",
        textColor: String = "",
        chronologyNumber: Int = 0,
        globalChronologyNumber: Int = 0,
        characters: [String] = []
    ) {
        self.text = text
        self.tags = tags
        self.costumes = costumes
        self.effects = effects
        self.color = color
        self.textColor = textColor
        self.chronologyNumber = chronologyNumber
        self.globalChronologyNumber = globalChronologyNumber
        self.characters = characters
    }

    enum CodingKeys: String, CodingKey {
        case text
        case tags
        case costumes
        case effects
        case color
        case textColor = "text_color"
        case chronologyNumber = "chronology_number"
        case globalChronologyNumber = "global_chronology_number"
        case characters
    }
}
