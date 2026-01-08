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
}
