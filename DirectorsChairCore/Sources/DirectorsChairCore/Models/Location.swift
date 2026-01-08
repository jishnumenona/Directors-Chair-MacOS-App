// DirectorsChairCore/Sources/DirectorsChairCore/Models/Location.swift
//
// Filming location with world-building attributes

import Foundation

/// Represents a filming location with comprehensive world-building attributes
public struct Location: Codable, Identifiable, Hashable {
    public var id: String { name }

    // MARK: - Core Identity
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
}
