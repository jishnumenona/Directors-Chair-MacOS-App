// DirectorsChairCore/Sources/DirectorsChairCore/Models/Location.swift
//
// Filming location with world-building attributes

import Foundation

/// Represents a filming location with comprehensive world-building attributes
public struct Location: Codable, Identifiable, Hashable, Sendable {
    public var id: String { uuid }

    // MARK: - Core Identity
    /// Stable identity, independent of name. Renaming no longer re-identifies
    /// the location for SwiftUI, selection, or sync. Legacy files without a
    /// uuid get one on first load.
    public var uuid: String
    public var name: String
    public var description: String
    public var notes: String  // Additional notes about the location

    // MARK: - Hierarchy & Organization
    public var parentLocation: String?  // Parent location name (e.g., "Paris" for "Eiffel Tower")
    public var locationType: String  // "indoor", "outdoor", "mixed"
    public var tags: [String]  // urban, nature, historical, modern, etc.

    // MARK: - Geographic Information
    public var address: String  // Physical address
    public var gpsCoordinates: String  // GPS coordinates (latitude, longitude)

    // MARK: - Images
    public var images: [String]  // List of image paths relative to project
    public var primaryImage: String?  // Main background image (must be in images list)
    public var referenceImages: [String]  // Mood/style reference images

    // MARK: - Floor Plan
    public var floorPlanData: [String: String]?  // Floor plan layout
    public var floorPlanImage: String?  // Path to floor plan image
    public var dimensions: [String: Double]?  // width, length, height in meters

    // MARK: - Virtual Cinematography
    public var cinemaSceneData: [String: String]?  // 3D scene configuration
    public var cinemaBackgroundImage: String?  // Path to 360° environment image
    public var cinemaReferenceImage: String?  // Selected gallery image for AI 3D generation
    public var cinemaFloorPlanImage: String?  // Generated floor plan
    public var cinemaEnvironmentVariations: [[String: String]]  // Saved AI-generated 3D environments

    // MARK: - Style & Atmosphere
    public var styleAttributes: [String: String]  // Texture, mood, color palette, architectural style
    public var cinematographyDefaults: [String: String]  // Preferred camera angles, lighting

    // MARK: - Legacy Support
    public var attributes: [String: String]  // Custom attributes (time_of_day, weather, mood, etc.)

    public init(
        uuid: String = UUID().uuidString,
        name: String,
        description: String = "",
        notes: String = "",
        parentLocation: String? = nil,
        locationType: String = "mixed",
        tags: [String] = [],
        address: String = "",
        gpsCoordinates: String = "",
        images: [String] = [],
        primaryImage: String? = nil,
        referenceImages: [String] = [],
        floorPlanData: [String: String]? = nil,
        floorPlanImage: String? = nil,
        dimensions: [String: Double]? = nil,
        cinemaSceneData: [String: String]? = nil,
        cinemaBackgroundImage: String? = nil,
        cinemaReferenceImage: String? = nil,
        cinemaFloorPlanImage: String? = nil,
        cinemaEnvironmentVariations: [[String: String]] = [],
        styleAttributes: [String: String] = [:],
        cinematographyDefaults: [String: String] = [:],
        attributes: [String: String] = [:]
    ) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.notes = notes
        self.parentLocation = parentLocation
        self.locationType = locationType
        self.tags = tags
        self.address = address
        self.gpsCoordinates = gpsCoordinates
        self.images = images
        self.primaryImage = primaryImage
        self.referenceImages = referenceImages
        self.floorPlanData = floorPlanData
        self.floorPlanImage = floorPlanImage
        self.dimensions = dimensions
        self.cinemaSceneData = cinemaSceneData
        self.cinemaBackgroundImage = cinemaBackgroundImage
        self.cinemaReferenceImage = cinemaReferenceImage
        self.cinemaFloorPlanImage = cinemaFloorPlanImage
        self.cinemaEnvironmentVariations = cinemaEnvironmentVariations
        self.styleAttributes = styleAttributes
        self.cinematographyDefaults = cinematographyDefaults
        self.attributes = attributes
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case description
        case notes
        case parentLocation = "parent_location"
        case locationType = "location_type"
        case tags
        case address
        case gpsCoordinates = "gps_coordinates"
        case images
        case primaryImage = "primary_image"
        case referenceImages = "reference_images"
        case floorPlanData = "floor_plan_data"
        case floorPlanImage = "floor_plan_image"
        case dimensions
        case cinemaSceneData = "cinema_scene_data"
        case cinemaBackgroundImage = "cinema_background_image"
        case cinemaReferenceImage = "cinema_reference_image"
        case cinemaFloorPlanImage = "cinema_floor_plan_image"
        case cinemaEnvironmentVariations = "cinema_environment_variations"
        case styleAttributes = "style_attributes"
        case cinematographyDefaults = "cinematography_defaults"
        case attributes
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Core identity
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""

        // Hierarchy & Organization
        parentLocation = try container.decodeIfPresent(String.self, forKey: .parentLocation)
        locationType = try container.decodeIfPresent(String.self, forKey: .locationType) ?? "mixed"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        // Geographic Information
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        gpsCoordinates = try container.decodeIfPresent(String.self, forKey: .gpsCoordinates) ?? ""

        // Images
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        primaryImage = try container.decodeIfPresent(String.self, forKey: .primaryImage)
        referenceImages = try container.decodeIfPresent([String].self, forKey: .referenceImages) ?? []

        // Floor Plan
        floorPlanData = try container.decodeIfPresent([String: String].self, forKey: .floorPlanData)
        floorPlanImage = try container.decodeIfPresent(String.self, forKey: .floorPlanImage)
        dimensions = try container.decodeIfPresent([String: Double].self, forKey: .dimensions)

        // Virtual Cinematography
        cinemaSceneData = try container.decodeIfPresent([String: String].self, forKey: .cinemaSceneData)
        cinemaBackgroundImage = try container.decodeIfPresent(String.self, forKey: .cinemaBackgroundImage)
        cinemaReferenceImage = try container.decodeIfPresent(String.self, forKey: .cinemaReferenceImage)
        cinemaFloorPlanImage = try container.decodeIfPresent(String.self, forKey: .cinemaFloorPlanImage)
        cinemaEnvironmentVariations = try container.decodeIfPresent([[String: String]].self, forKey: .cinemaEnvironmentVariations) ?? []

        // Style & Atmosphere
        styleAttributes = try container.decodeIfPresent([String: String].self, forKey: .styleAttributes) ?? [:]
        cinematographyDefaults = try container.decodeIfPresent([String: String].self, forKey: .cinematographyDefaults) ?? [:]

        // Legacy Support
        attributes = try container.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
    }
}
