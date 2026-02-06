// DirectorsChairCore/Sources/DirectorsChairCore/Models/Shot.swift
//
// Shot model for cinematography planning (PLACEHOLDER - to be fully implemented)

import Foundation

/// Represents a planned camera shot for a scene (cinematography)
/// Note: This is a placeholder. Full implementation with all 579 lines of Python reference pending.
public struct Shot: Codable, Identifiable, Hashable {
    public var id: String { "\(shotId)" }

    public var shotId: Int  // Unique shot ID across project
    public var itemChronology: Int  // Links to dialogue/action/narration chronology
    public var description: String
    public var status: String  // "Planning", "Ready", "Shooting", "Shot", "Approved"
    public var cameraAngle: String
    public var lensMm: Int?
    public var aperture: String
    public var shotType: String
    public var movement: String
    public var duration: Double?
    public var styleOverride: String?  // FilmStyle ID override
    public var referenceMedia: [ReferenceMedia]  // Reference images and videos
    public var previewImage: String?  // AI-generated shot preview image path
    public var linkedDialogueIds: [String]  // IDs of dialogues connected to this shot
    public var linkedActionIds: [String]  // IDs of actions connected to this shot
    public var linkedNarrationIds: [String]  // IDs of narrations connected to this shot
    public var timelinePosition: Double?  // User-specified timeline position override (seconds)

    public init(
        shotId: Int,
        itemChronology: Int = 0,
        description: String = "",
        status: String = "Planning",
        cameraAngle: String = "Medium",
        lensMm: Int? = 50,
        aperture: String = "f/2.8",
        shotType: String = "Standard",
        movement: String = "Static",
        duration: Double? = nil,
        styleOverride: String? = nil,
        referenceMedia: [ReferenceMedia] = [],
        previewImage: String? = nil,
        linkedDialogueIds: [String] = [],
        linkedActionIds: [String] = [],
        linkedNarrationIds: [String] = [],
        timelinePosition: Double? = nil
    ) {
        self.shotId = shotId
        self.itemChronology = itemChronology
        self.description = description
        self.status = status
        self.cameraAngle = cameraAngle
        self.lensMm = lensMm
        self.aperture = aperture
        self.shotType = shotType
        self.movement = movement
        self.duration = duration
        self.styleOverride = styleOverride
        self.referenceMedia = referenceMedia
        self.previewImage = previewImage
        self.linkedDialogueIds = linkedDialogueIds
        self.linkedActionIds = linkedActionIds
        self.linkedNarrationIds = linkedNarrationIds
        self.timelinePosition = timelinePosition
    }

    enum CodingKeys: String, CodingKey {
        case shotId = "shot_id"
        case itemChronology = "item_chronology"
        case description
        case status
        case cameraAngle = "camera_angle"
        case lensMm = "lens_mm"
        case aperture
        case shotType = "shot_type"
        case movement
        case duration
        case styleOverride = "style_override"
        case referenceMedia = "reference_media"
        case previewImage = "preview_image"
        case linkedDialogueIds = "linked_dialogue_ids"
        case linkedActionIds = "linked_action_ids"
        case linkedNarrationIds = "linked_narration_ids"
        case timelinePosition = "timeline_position"
    }

    enum AlternativeCodingKeys: String, CodingKey {
        case lens
        case name
        case notes
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let altContainer = try? decoder.container(keyedBy: AlternativeCodingKeys.self)

        // shotId: generate from name if missing
        if let id = try? container.decode(Int.self, forKey: .shotId) {
            shotId = id
        } else if let name = try? altContainer?.decode(String.self, forKey: .name) {
            // Generate a simple numeric ID from the name
            shotId = abs(name.hashValue % 10000)
        } else {
            shotId = 0
        }

        itemChronology = try container.decodeIfPresent(Int.self, forKey: .itemChronology) ?? 0

        // description: use 'description' or 'notes' field
        if let desc = try? container.decode(String.self, forKey: .description), !desc.isEmpty {
            description = desc
        } else if let notes = try? altContainer?.decode(String.self, forKey: .notes) {
            description = notes
        } else {
            description = ""
        }

        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Planning"
        cameraAngle = try container.decodeIfPresent(String.self, forKey: .cameraAngle) ?? "Medium"

        // lensMm: handle both lens_mm (Int) and lens (String like "50mm")
        if let mm = try? container.decode(Int.self, forKey: .lensMm) {
            lensMm = mm
        } else if let lensString = try? altContainer?.decode(String.self, forKey: .lens) {
            // Parse "50mm" -> 50
            let cleaned = lensString.replacingOccurrences(of: "mm", with: "").trimmingCharacters(in: .whitespaces)
            lensMm = Int(cleaned) ?? 50
        } else {
            lensMm = 50
        }

        aperture = try container.decodeIfPresent(String.self, forKey: .aperture) ?? "f/2.8"
        shotType = try container.decodeIfPresent(String.self, forKey: .shotType) ?? "Standard"
        movement = try container.decodeIfPresent(String.self, forKey: .movement) ?? "Static"

        // Handle duration as either Double or String (e.g., "3s")
        if let durationDouble = try? container.decode(Double.self, forKey: .duration) {
            duration = durationDouble
        } else if let durationString = try? container.decode(String.self, forKey: .duration) {
            // Parse duration string like "3s", "5s", etc.
            let cleaned = durationString.replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespaces)
            duration = Double(cleaned)
        } else {
            duration = nil
        }

        styleOverride = try container.decodeIfPresent(String.self, forKey: .styleOverride)
        referenceMedia = try container.decodeIfPresent([ReferenceMedia].self, forKey: .referenceMedia) ?? []
        previewImage = try container.decodeIfPresent(String.self, forKey: .previewImage)
        linkedDialogueIds = try container.decodeIfPresent([String].self, forKey: .linkedDialogueIds) ?? []
        linkedActionIds = try container.decodeIfPresent([String].self, forKey: .linkedActionIds) ?? []
        linkedNarrationIds = try container.decodeIfPresent([String].self, forKey: .linkedNarrationIds) ?? []
        timelinePosition = try container.decodeIfPresent(Double.self, forKey: .timelinePosition)
    }
}

// MARK: - Reference Media

/// Represents a reference image or video for a shot
public struct ReferenceMedia: Codable, Identifiable, Hashable {
    public var id: String
    public var type: MediaType
    public var path: String  // Relative path within project
    public var caption: String
    public var timestamp: Date

    public init(
        id: String = UUID().uuidString,
        type: MediaType,
        path: String,
        caption: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.path = path
        self.caption = caption
        self.timestamp = timestamp
    }

    public enum MediaType: String, Codable, Hashable {
        case image
        case video
    }
}
