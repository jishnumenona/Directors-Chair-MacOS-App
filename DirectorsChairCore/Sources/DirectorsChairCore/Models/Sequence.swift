// DirectorsChairCore/Sources/DirectorsChairCore/Models/Sequence.swift
//
// Sequence (or act) model containing scenes

import Foundation

/// Represents a sequence (or act) in the story, containing a list of scenes
public struct Sequence: Codable, Identifiable, Hashable {
    public var id: String { name }

    public var name: String
    public var description: String?
    public var scenes: [Scene]
    public var location: String?  // Location name reference

    public init(
        name: String,
        description: String? = nil,
        scenes: [Scene] = [],
        location: String? = nil
    ) {
        self.name = name
        self.description = description
        self.scenes = scenes
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case scenes
        case location
    }
}
