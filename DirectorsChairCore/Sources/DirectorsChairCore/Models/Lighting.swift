// DirectorsChairCore/Sources/DirectorsChairCore/Models/Lighting.swift
//
// Lighting definition model

import Foundation

/// Represents a lighting setup/definition
public struct Lighting: Codable, Identifiable, Hashable {
    public var id: String { name }

    public var name: String
    public var type: String  // e.g., "Spot", "Flood", "Key", "Fill", "Back"
    public var color: String  // Hex color code
    public var intensity: Double  // 0.0 to 1.0
    public var position: String  // e.g., "Front", "Back", "Side"
    public var notes: String

    public init(
        name: String,
        type: String = "Spot",
        color: String = "#ffffff",
        intensity: Double = 1.0,
        position: String = "Front",
        notes: String = ""
    ) {
        self.name = name
        self.type = type
        self.color = color
        self.intensity = intensity
        self.position = position
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case color
        case intensity
        case position
        case notes
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "Spot"
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#ffffff"
        intensity = try container.decodeIfPresent(Double.self, forKey: .intensity) ?? 1.0
        position = try container.decodeIfPresent(String.self, forKey: .position) ?? "Front"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}
