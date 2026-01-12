// DirectorsChairCore/Sources/DirectorsChairCore/Models/Note.swift
//
// Production note/annotation model

import Foundation

/// Represents a note/annotation in a scene (metadata, not part of story flow)
public struct Note: Codable, Identifiable, Hashable {
    public var id: String { "\(chronologyNumber)-note" }

    public var content: String  // Note content (text, URL, or file path)
    public var noteType: String  // "text", "image", "link", "youtube"
    public var chronologyNumber: Int  // Order in scene
    public var title: String  // Optional title for the note
    public var metadata: [String: String]  // Additional metadata (e.g., YouTube video info)

    public init(
        content: String = "",
        noteType: String = "text",
        chronologyNumber: Int = 0,
        title: String = "",
        metadata: [String: String] = [:]
    ) {
        self.content = content
        self.noteType = noteType
        self.chronologyNumber = chronologyNumber
        self.title = title
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case content
        case noteType = "note_type"
        case chronologyNumber = "chronology_number"
        case title
        case metadata
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Provide defaults for all fields
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        noteType = try container.decodeIfPresent(String.self, forKey: .noteType) ?? "text"
        chronologyNumber = try container.decodeIfPresent(Int.self, forKey: .chronologyNumber) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}
