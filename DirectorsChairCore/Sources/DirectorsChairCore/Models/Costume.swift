// DirectorsChairCore/Sources/DirectorsChairCore/Models/Costume.swift
//
// Simple costume model for project-level costumes (not character-specific)

import Foundation

/// Represents a costume in the project (project-level, not character-specific)
public struct Costume: Codable, Identifiable, Hashable {
    public var id: String { uuid }

    /// Stable identity, independent of name (legacy files get one on load).
    public var uuid: String
    public var name: String
    public var character: String?
    public var image: String?  // Relative path
    public var notes: String

    public init(
        uuid: String = UUID().uuidString,
        name: String,
        character: String? = nil,
        image: String? = nil,
        notes: String = ""
    ) {
        self.uuid = uuid
        self.name = name
        self.character = character
        self.image = image
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case character
        case image
        case notes
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        character = try container.decodeIfPresent(String.self, forKey: .character)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}
