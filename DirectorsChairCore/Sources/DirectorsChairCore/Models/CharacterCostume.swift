// DirectorsChairCore/Sources/DirectorsChairCore/Models/CharacterCostume.swift
//
// Character costume with multi-angle images

import Foundation

/// Represents a single costume for a character with multi-angle images
public struct CharacterCostume: Codable, Identifiable, Hashable {
    public var id: String { name }

    public var name: String  // Costume name (e.g., "Business Suit", "Casual Wear")
    public var description: String  // Detailed description/prompt for AI generation

    // Multi-angle costume images
    public var imageFront: String?
    public var imageThreeQuarterLeft: String?
    public var imageThreeQuarterRight: String?
    public var imageProfile: String?

    // Metadata
    public var transformationPrompt: String?  // Prompt used for generation
    public var createdAt: Date?

    public init(
        name: String,
        description: String = "",
        imageFront: String? = nil,
        imageThreeQuarterLeft: String? = nil,
        imageThreeQuarterRight: String? = nil,
        imageProfile: String? = nil,
        transformationPrompt: String? = nil,
        createdAt: Date? = nil
    ) {
        self.name = name
        self.description = description
        self.imageFront = imageFront
        self.imageThreeQuarterLeft = imageThreeQuarterLeft
        self.imageThreeQuarterRight = imageThreeQuarterRight
        self.imageProfile = imageProfile
        self.transformationPrompt = transformationPrompt
        self.createdAt = createdAt ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case imageFront = "image_front"
        case imageThreeQuarterLeft = "image_three_quarter_left"
        case imageThreeQuarterRight = "image_three_quarter_right"
        case imageProfile = "image_profile"
        case transformationPrompt = "transformation_prompt"
        case createdAt = "created_at"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        imageFront = try container.decodeIfPresent(String.self, forKey: .imageFront)
        imageThreeQuarterLeft = try container.decodeIfPresent(String.self, forKey: .imageThreeQuarterLeft)
        imageThreeQuarterRight = try container.decodeIfPresent(String.self, forKey: .imageThreeQuarterRight)
        imageProfile = try container.decodeIfPresent(String.self, forKey: .imageProfile)
        transformationPrompt = try container.decodeIfPresent(String.self, forKey: .transformationPrompt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}
