// DirectorsChairCore/Sources/DirectorsChairCore/Models/Action.swift
//
// Scene action/stage direction model

import Foundation

/// Represents a scene action or stage direction (not spoken dialogue)
public struct Action: Codable, Identifiable, Hashable {
    public var id: String { "\(chronologyNumber)-action-\(globalChronologyNumber)" }

    public var description: String  // Action description text
    public var tags: [String]  // Mood, timing, or note tags
    public var costumes: [String]  // Costume pieces for this action
    public var effects: [String]  // Special effects cues
    public var color: String  // Custom background color (empty = theme default)
    public var textColor: String  // Custom text color (empty = theme default)
    public var chronologyNumber: Int  // Order in scene
    public var globalChronologyNumber: Int  // Global order across project
    public var characters: [String]  // Characters involved in this action

    public init(
        description: String,
        tags: [String] = [],
        costumes: [String] = [],
        effects: [String] = [],
        color: String = "",
        textColor: String = "",
        chronologyNumber: Int = 0,
        globalChronologyNumber: Int = 0,
        characters: [String] = []
    ) {
        self.description = description
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
        case description
        case tags
        case costumes
        case effects
        case color
        case textColor = "text_color"
        case chronologyNumber = "chronology_number"
        case globalChronologyNumber = "global_chronology_number"
        case characters
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
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
    }
}
