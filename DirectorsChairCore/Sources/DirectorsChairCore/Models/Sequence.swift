// DirectorsChairCore/Sources/DirectorsChairCore/Models/Sequence.swift
//
// Sequence (or act) model containing scenes

import Foundation

/// Represents a sequence (or act) in the story, containing a list of scenes
public struct Sequence: Codable, Identifiable, Hashable, Sendable {
    public var id: String { uuid }

    public var uuid: String
    public var name: String
    public var description: String?
    public var scenes: [Scene]
    public var location: String?  // Location name reference

    public init(
        uuid: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        scenes: [Scene] = [],
        location: String? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.scenes = scenes
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case description
        case scenes
        case location
    }

    // MARK: - Custom Decoder (migration support)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        scenes = try container.decodeIfPresent([Scene].self, forKey: .scenes) ?? []
        location = try container.decodeIfPresent(String.self, forKey: .location)
    }
}
