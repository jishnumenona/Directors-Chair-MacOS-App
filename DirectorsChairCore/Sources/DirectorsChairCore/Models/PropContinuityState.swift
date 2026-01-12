// DirectorsChairCore/Sources/DirectorsChairCore/Models/PropContinuityState.swift
//
// Prop continuity state tracking across scenes

import Foundation

/// Represents the state/condition of a prop at a specific point in production
public struct PropContinuityState: Codable, Identifiable, Hashable {
    public var id: String
    public var sceneName: String  // Which scene this state applies to
    public var condition: String  // "Pristine", "Aged", "Damaged", "Destroyed", "Hero", "Stunt"
    public var description: String  // Detailed description of state
    public var referencePhotos: [String]  // Photo paths
    public var notes: String
    public var createdDate: String

    public init(
        id: String = "cont_\(UUID().uuidString.prefix(12))",
        sceneName: String = "",
        condition: String = "Pristine",
        description: String = "",
        referencePhotos: [String] = [],
        notes: String = "",
        createdDate: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.sceneName = sceneName
        self.condition = condition
        self.description = description
        self.referencePhotos = referencePhotos
        self.notes = notes
        self.createdDate = createdDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sceneName = "scene_name"
        case condition
        case description
        case referencePhotos = "reference_photos"
        case notes
        case createdDate = "created_date"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "cont_\(UUID().uuidString.prefix(12))"
        sceneName = try container.decodeIfPresent(String.self, forKey: .sceneName) ?? ""
        condition = try container.decodeIfPresent(String.self, forKey: .condition) ?? "Pristine"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        referencePhotos = try container.decodeIfPresent([String].self, forKey: .referencePhotos) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdDate = try container.decodeIfPresent(String.self, forKey: .createdDate) ?? ISO8601DateFormatter().string(from: Date())
    }
}
