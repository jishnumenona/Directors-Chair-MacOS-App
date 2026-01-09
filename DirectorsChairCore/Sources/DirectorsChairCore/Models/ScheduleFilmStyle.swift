// DirectorsChairCore/Sources/DirectorsChairCore/Models/ScheduleFilmStyle.swift
//
// ScheduleItem and FilmStyle models

import Foundation

// MARK: - ScheduleItem

/// Represents a scheduled shoot for production planning
public struct ScheduleItem: Codable, Identifiable, Hashable {
    public var id: String

    // Link to Scene/Shot
    public var sceneId: String?
    public var sceneName: String
    public var sequenceName: String
    public var shotIds: [String]

    // Schedule Details
    public var shootDate: String?  // ISO date string (YYYY-MM-DD)
    public var timeSlot: String  // "Morning", "Afternoon", "Full Day", "Night"
    public var estimatedDurationHours: Double

    // Status
    public var status: String  // "Planned", "Confirmed", "In Progress", "Shot", "Complete", "Cancelled", "Postponed"

    // Location & Resources
    public var location: String
    public var locationAddress: String
    public var locationGps: String
    public var requiredActors: [String]
    public var requiredCrew: [String]
    public var requiredEquipment: [String]
    public var requiredProps: [String]

    // Production Notes
    public var productionNotes: String
    public var callTime: String?  // HH:MM format
    public var wrapTime: String?  // Estimated wrap time

    // Logistics
    public var weatherRequirements: String
    public var backupPlan: String
    public var specialRequirements: String

    // Budget & Tracking
    public var estimatedCost: Double
    public var actualCost: Double?
    public var completionPercentage: Int  // 0-100

    // Priority & Dependencies
    public var priority: Int  // 1 (highest) to 5 (lowest)
    public var dependsOn: [String]  // Other schedule item IDs

    // Metadata
    public var createdDate: String
    public var modifiedDate: String
    public var createdBy: String

    // Color Coding
    public var color: String?  // Custom color for calendar display

    public init(
        id: String = "sched_\(UUID().uuidString.prefix(12))",
        sceneId: String? = nil,
        sceneName: String = "",
        sequenceName: String = "",
        shotIds: [String] = [],
        shootDate: String? = nil,
        timeSlot: String = "Full Day",
        estimatedDurationHours: Double = 4.0,
        status: String = "Planned",
        location: String = "",
        locationAddress: String = "",
        locationGps: String = "",
        requiredActors: [String] = [],
        requiredCrew: [String] = [],
        requiredEquipment: [String] = [],
        requiredProps: [String] = [],
        productionNotes: String = "",
        callTime: String? = nil,
        wrapTime: String? = nil,
        weatherRequirements: String = "",
        backupPlan: String = "",
        specialRequirements: String = "",
        estimatedCost: Double = 0.0,
        actualCost: Double? = nil,
        completionPercentage: Int = 0,
        priority: Int = 3,
        dependsOn: [String] = [],
        createdDate: String = ISO8601DateFormatter().string(from: Date()),
        modifiedDate: String = ISO8601DateFormatter().string(from: Date()),
        createdBy: String = "",
        color: String? = nil
    ) {
        self.id = id
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.sequenceName = sequenceName
        self.shotIds = shotIds
        self.shootDate = shootDate
        self.timeSlot = timeSlot
        self.estimatedDurationHours = estimatedDurationHours
        self.status = status
        self.location = location
        self.locationAddress = locationAddress
        self.locationGps = locationGps
        self.requiredActors = requiredActors
        self.requiredCrew = requiredCrew
        self.requiredEquipment = requiredEquipment
        self.requiredProps = requiredProps
        self.productionNotes = productionNotes
        self.callTime = callTime
        self.wrapTime = wrapTime
        self.weatherRequirements = weatherRequirements
        self.backupPlan = backupPlan
        self.specialRequirements = specialRequirements
        self.estimatedCost = estimatedCost
        self.actualCost = actualCost
        self.completionPercentage = completionPercentage
        self.priority = priority
        self.dependsOn = dependsOn
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.createdBy = createdBy
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sceneId = "scene_id"
        case sceneName = "scene_name"
        case sequenceName = "sequence_name"
        case shotIds = "shot_ids"
        case shootDate = "shoot_date"
        case timeSlot = "time_slot"
        case estimatedDurationHours = "estimated_duration_hours"
        case status
        case location
        case locationAddress = "location_address"
        case locationGps = "location_gps"
        case requiredActors = "required_actors"
        case requiredCrew = "required_crew"
        case requiredEquipment = "required_equipment"
        case requiredProps = "required_props"
        case productionNotes = "production_notes"
        case callTime = "call_time"
        case wrapTime = "wrap_time"
        case weatherRequirements = "weather_requirements"
        case backupPlan = "backup_plan"
        case specialRequirements = "special_requirements"
        case estimatedCost = "estimated_cost"
        case actualCost = "actual_cost"
        case completionPercentage = "completion_percentage"
        case priority
        case dependsOn = "depends_on"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
        case createdBy = "created_by"
        case color
    }
}

// MARK: - FilmStyle

/// Represents the visual style and texture of a film project
public struct FilmStyle: Codable, Identifiable, Hashable {
    // Core Identity
    public var id: String
    public var name: String
    public var description: String
    public var isPreset: Bool

    // Visual Characteristics
    public var renderingStyle: String  // realistic, cartoon, anime, puppet, stop-motion, etc.
    public var textureQuality: String  // smooth, grainy, painterly, sketchy, pixelated, rough, soft
    public var colorPalette: [String]  // Hex codes like ["#FF5733", "#3498DB"]
    public var colorGrading: String  // neutral, cinematic, warm, cool, desaturated, vibrant, vintage, modern
    public var contrastLevel: String  // low, medium, high, dramatic

    // Technical Parameters
    public var filmGrain: Bool
    public var vignette: Bool
    public var lensDistortion: String  // none, subtle, pronounced
    public var chromaticAberration: Bool

    // AI Generation Hints
    public var aiStylePrompt: String  // Appended to all AI prompts
    public var negativePrompt: String  // Things to avoid

    // Reference
    public var referenceImages: [String]  // Relative paths

    // Metadata
    public var createdAt: Date?
    public var updatedAt: Date?
    public var author: String?

    public init(
        id: String = UUID().uuidString,
        name: String = "Untitled Style",
        description: String = "",
        isPreset: Bool = false,
        renderingStyle: String = "realistic",
        textureQuality: String = "smooth",
        colorPalette: [String] = [],
        colorGrading: String = "neutral",
        contrastLevel: String = "medium",
        filmGrain: Bool = false,
        vignette: Bool = false,
        lensDistortion: String = "none",
        chromaticAberration: Bool = false,
        aiStylePrompt: String = "",
        negativePrompt: String = "",
        referenceImages: [String] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        author: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isPreset = isPreset
        self.renderingStyle = renderingStyle
        self.textureQuality = textureQuality
        self.colorPalette = colorPalette
        self.colorGrading = colorGrading
        self.contrastLevel = contrastLevel
        self.filmGrain = filmGrain
        self.vignette = vignette
        self.lensDistortion = lensDistortion
        self.chromaticAberration = chromaticAberration
        self.aiStylePrompt = aiStylePrompt
        self.negativePrompt = negativePrompt
        self.referenceImages = referenceImages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.author = author
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isPreset = "is_preset"
        case renderingStyle = "rendering_style"
        case textureQuality = "texture_quality"
        case colorPalette = "color_palette"
        case colorGrading = "color_grading"
        case contrastLevel = "contrast_level"
        case filmGrain = "film_grain"
        case vignette
        case lensDistortion = "lens_distortion"
        case chromaticAberration = "chromatic_aberration"
        case aiStylePrompt = "ai_style_prompt"
        case negativePrompt = "negative_prompt"
        case referenceImages = "reference_images"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case author
    }
}
