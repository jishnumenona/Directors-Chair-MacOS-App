// DirectorsChairCore/Sources/DirectorsChairCore/Models/Narration.swift
//
// Narration/voice-over model

import Foundation

/// Represents a narration element (voice-over, not tied to a character)
public struct Narration: Codable, Identifiable, Hashable {
    public var id: String { uuid }

    public var uuid: String  // Unique identifier
    public var text: String  // Narration text content
    public var tags: [String]  // Mood, timing, or note tags
    public var costumes: [String]  // Costume pieces for this narration
    public var effects: [String]  // Special effects cues
    public var color: String  // Custom background color (empty = theme default)
    public var textColor: String  // Custom text color (empty = theme default)
    public var chronologyNumber: Int  // Order in scene
    public var globalChronologyNumber: Int  // Global order across project
    public var characters: [String]  // Characters involved in this narration
    public var parentDialogueId: String?  // ID of parent dialogue if connected as sub-bubble
    public var manualStartTime: Double?  // User-specified timeline position override (seconds)

    public init(
        uuid: String = UUID().uuidString,
        text: String,
        tags: [String] = [],
        costumes: [String] = [],
        effects: [String] = [],
        color: String = "",
        textColor: String = "",
        chronologyNumber: Int = 0,
        globalChronologyNumber: Int = 0,
        characters: [String] = [],
        parentDialogueId: String? = nil,
        manualStartTime: Double? = nil
    ) {
        self.uuid = uuid
        self.text = text
        self.tags = tags
        self.costumes = costumes
        self.effects = effects
        self.color = color
        self.textColor = textColor
        self.chronologyNumber = chronologyNumber
        self.globalChronologyNumber = globalChronologyNumber
        self.characters = characters
        self.parentDialogueId = parentDialogueId
        self.manualStartTime = manualStartTime
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case text
        case tags
        case costumes
        case effects
        case color
        case textColor = "text_color"
        case chronologyNumber = "chronology_number"
        case globalChronologyNumber = "global_chronology_number"
        case characters
        case parentDialogueId = "parent_dialogue_id"
        case manualStartTime = "manual_start_time"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generate UUID if not present
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString

        // Required fields
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        chronologyNumber = try container.decodeIfPresent(Int.self, forKey: .chronologyNumber) ?? 0
        globalChronologyNumber = try container.decodeIfPresent(Int.self, forKey: .globalChronologyNumber) ?? 0

        // Optional arrays - provide empty defaults
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        costumes = try container.decodeIfPresent([String].self, forKey: .costumes) ?? []
        effects = try container.decodeIfPresent([String].self, forKey: .effects) ?? []
        characters = try container.decodeIfPresent([String].self, forKey: .characters) ?? []

        // Optional strings - provide empty defaults
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? ""
        textColor = try container.decodeIfPresent(String.self, forKey: .textColor) ?? ""

        // Parent dialogue connection
        parentDialogueId = try container.decodeIfPresent(String.self, forKey: .parentDialogueId)
        manualStartTime = try container.decodeIfPresent(Double.self, forKey: .manualStartTime)
    }
}
