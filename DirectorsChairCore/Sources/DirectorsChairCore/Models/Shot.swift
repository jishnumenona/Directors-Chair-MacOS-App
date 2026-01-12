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
        styleOverride: String? = nil
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
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        shotId = try container.decodeIfPresent(Int.self, forKey: .shotId) ?? 0
        itemChronology = try container.decodeIfPresent(Int.self, forKey: .itemChronology) ?? 0
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Planning"
        cameraAngle = try container.decodeIfPresent(String.self, forKey: .cameraAngle) ?? "Medium"
        lensMm = try container.decodeIfPresent(Int.self, forKey: .lensMm) ?? 50
        aperture = try container.decodeIfPresent(String.self, forKey: .aperture) ?? "f/2.8"
        shotType = try container.decodeIfPresent(String.self, forKey: .shotType) ?? "Standard"
        movement = try container.decodeIfPresent(String.self, forKey: .movement) ?? "Static"
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        styleOverride = try container.decodeIfPresent(String.self, forKey: .styleOverride)
    }
}
