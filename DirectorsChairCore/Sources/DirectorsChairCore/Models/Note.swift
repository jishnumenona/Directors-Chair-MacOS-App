// DirectorsChairCore/Sources/DirectorsChairCore/Models/Note.swift
//
// Production note/annotation model

import Foundation

/// Represents a note/annotation in a scene (metadata, not part of story flow)
public struct Note: Codable, Identifiable, Hashable, Sendable {
    public var id: String { uuid }

    public var uuid: String  // Unique identifier
    public var content: String  // Note content (text, URL, or file path)
    public var noteType: String  // "text", "image", "link", "youtube"
    public var chronologyNumber: Int  // Order in scene
    public var title: String  // Optional title for the note
    public var metadata: [String: String]  // Additional metadata (e.g., YouTube video info)
    public var parentDialogueId: String?  // ID of parent dialogue if connected as sub-bubble

    public init(
        uuid: String = UUID().uuidString,
        content: String = "",
        noteType: String = "text",
        chronologyNumber: Int = 0,
        title: String = "",
        metadata: [String: String] = [:],
        parentDialogueId: String? = nil
    ) {
        self.uuid = uuid
        self.content = content
        self.noteType = noteType
        self.chronologyNumber = chronologyNumber
        self.title = title
        self.metadata = metadata
        self.parentDialogueId = parentDialogueId
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case content
        case noteType = "note_type"
        case chronologyNumber = "chronology_number"
        case title
        case metadata
        case parentDialogueId = "parent_dialogue_id"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generate UUID if not present
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString

        // Provide defaults for all fields
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        noteType = try container.decodeIfPresent(String.self, forKey: .noteType) ?? "text"
        chronologyNumber = try container.decodeIfPresent(Int.self, forKey: .chronologyNumber) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]

        // Parent dialogue connection
        parentDialogueId = try container.decodeIfPresent(String.self, forKey: .parentDialogueId)
    }
}
