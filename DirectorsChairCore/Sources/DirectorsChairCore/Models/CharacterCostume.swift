// DirectorsChairCore/Sources/DirectorsChairCore/Models/CharacterCostume.swift
//
// Character costume with multi-angle images and industry-standard breakdown fields

import Foundation

/// Represents a single costume for a character with multi-angle images
public struct CharacterCostume: Codable, Identifiable, Hashable {
    public var id: String { costumeId }

    public var costumeId: String
    public var name: String
    public var description: String

    // Multi-angle costume images
    public var imageFront: String?
    public var imageThreeQuarterLeft: String?
    public var imageThreeQuarterRight: String?
    public var imageProfile: String?
    public var imageBack: String?
    public var imageFullBody: String?

    // Classification
    public var era: String?
    public var styleCategory: String?

    // Color Palette (hex strings)
    public var colorPalette: [String]?

    // Garment Breakdown
    public var garmentTop: String?
    public var garmentBottom: String?
    public var footwear: String?
    public var outerwear: String?
    public var headwear: String?
    public var accessories: [String]?

    // Materials
    public var primaryFabric: String?

    // Production
    public var status: String?  // Concept, Sourcing, Fitting, Ready, Retired
    public var sceneIds: [String]?
    public var changeNumber: Int?
    public var scriptDay: String?
    public var sfxRequirements: String?
    public var directorNotes: String?

    // Metadata
    public var transformationPrompt: String?
    public var createdAt: Date?

    public init(
        costumeId: String = UUID().uuidString,
        name: String,
        description: String = "",
        imageFront: String? = nil,
        imageThreeQuarterLeft: String? = nil,
        imageThreeQuarterRight: String? = nil,
        imageProfile: String? = nil,
        imageBack: String? = nil,
        imageFullBody: String? = nil,
        era: String? = nil,
        styleCategory: String? = nil,
        colorPalette: [String]? = nil,
        garmentTop: String? = nil,
        garmentBottom: String? = nil,
        footwear: String? = nil,
        outerwear: String? = nil,
        headwear: String? = nil,
        accessories: [String]? = nil,
        primaryFabric: String? = nil,
        status: String? = "Concept",
        sceneIds: [String]? = nil,
        changeNumber: Int? = nil,
        scriptDay: String? = nil,
        sfxRequirements: String? = nil,
        directorNotes: String? = nil,
        transformationPrompt: String? = nil,
        createdAt: Date? = nil
    ) {
        self.costumeId = costumeId
        self.name = name
        self.description = description
        self.imageFront = imageFront
        self.imageThreeQuarterLeft = imageThreeQuarterLeft
        self.imageThreeQuarterRight = imageThreeQuarterRight
        self.imageProfile = imageProfile
        self.imageBack = imageBack
        self.imageFullBody = imageFullBody
        self.era = era
        self.styleCategory = styleCategory
        self.colorPalette = colorPalette
        self.garmentTop = garmentTop
        self.garmentBottom = garmentBottom
        self.footwear = footwear
        self.outerwear = outerwear
        self.headwear = headwear
        self.accessories = accessories
        self.primaryFabric = primaryFabric
        self.status = status
        self.sceneIds = sceneIds
        self.changeNumber = changeNumber
        self.scriptDay = scriptDay
        self.sfxRequirements = sfxRequirements
        self.directorNotes = directorNotes
        self.transformationPrompt = transformationPrompt
        self.createdAt = createdAt ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case costumeId = "costume_id"
        case name
        case description
        case imageFront = "image_front"
        case imageThreeQuarterLeft = "image_three_quarter_left"
        case imageThreeQuarterRight = "image_three_quarter_right"
        case imageProfile = "image_profile"
        case imageBack = "image_back"
        case imageFullBody = "image_full_body"
        case era
        case styleCategory = "style_category"
        case colorPalette = "color_palette"
        case garmentTop = "garment_top"
        case garmentBottom = "garment_bottom"
        case footwear
        case outerwear
        case headwear
        case accessories
        case primaryFabric = "primary_fabric"
        case status
        case sceneIds = "scene_ids"
        case changeNumber = "change_number"
        case scriptDay = "script_day"
        case sfxRequirements = "sfx_requirements"
        case directorNotes = "director_notes"
        case transformationPrompt = "transformation_prompt"
        case createdAt = "created_at"
    }

    // MARK: - Custom Decoder (Backward Compatible)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Backward compatibility: generate costumeId from name if missing
        if let id = try container.decodeIfPresent(String.self, forKey: .costumeId) {
            costumeId = id
        } else {
            let decodedName = try container.decode(String.self, forKey: .name)
            costumeId = decodedName.replacingOccurrences(of: " ", with: "_").lowercased() + "_" + UUID().uuidString.prefix(8)
        }

        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        imageFront = try container.decodeIfPresent(String.self, forKey: .imageFront)
        imageThreeQuarterLeft = try container.decodeIfPresent(String.self, forKey: .imageThreeQuarterLeft)
        imageThreeQuarterRight = try container.decodeIfPresent(String.self, forKey: .imageThreeQuarterRight)
        imageProfile = try container.decodeIfPresent(String.self, forKey: .imageProfile)
        imageBack = try container.decodeIfPresent(String.self, forKey: .imageBack)
        imageFullBody = try container.decodeIfPresent(String.self, forKey: .imageFullBody)
        era = try container.decodeIfPresent(String.self, forKey: .era)
        styleCategory = try container.decodeIfPresent(String.self, forKey: .styleCategory)
        colorPalette = try container.decodeIfPresent([String].self, forKey: .colorPalette)
        garmentTop = try container.decodeIfPresent(String.self, forKey: .garmentTop)
        garmentBottom = try container.decodeIfPresent(String.self, forKey: .garmentBottom)
        footwear = try container.decodeIfPresent(String.self, forKey: .footwear)
        outerwear = try container.decodeIfPresent(String.self, forKey: .outerwear)
        headwear = try container.decodeIfPresent(String.self, forKey: .headwear)
        accessories = try container.decodeIfPresent([String].self, forKey: .accessories)
        primaryFabric = try container.decodeIfPresent(String.self, forKey: .primaryFabric)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        sceneIds = try container.decodeIfPresent([String].self, forKey: .sceneIds)
        changeNumber = try container.decodeIfPresent(Int.self, forKey: .changeNumber)
        scriptDay = try container.decodeIfPresent(String.self, forKey: .scriptDay)
        sfxRequirements = try container.decodeIfPresent(String.self, forKey: .sfxRequirements)
        directorNotes = try container.decodeIfPresent(String.self, forKey: .directorNotes)
        transformationPrompt = try container.decodeIfPresent(String.self, forKey: .transformationPrompt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}
