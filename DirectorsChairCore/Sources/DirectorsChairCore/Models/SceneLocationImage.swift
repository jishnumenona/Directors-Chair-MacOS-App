// DirectorsChairCore/Sources/DirectorsChairCore/Models/SceneLocationImage.swift
//
// AI-generated location concept art for scenes

import Foundation

/// Represents an AI-generated location image for a scene with cinematography parameters
public struct SceneLocationImage: Codable, Identifiable, Hashable {
    // MARK: - Identification
    public var id: String
    public var sceneId: String  // Link to parent scene
    public var imagePath: String  // Relative path from project base

    // MARK: - Location Context
    public var locationName: String
    public var locationType: String  // e.g., "Courtroom", "Prison Cell"
    public var indoorOutdoor: String  // "Indoor" or "Outdoor"
    public var description: String  // AI-extracted location description

    // MARK: - Cinematography Parameters
    public var cameraAngle: String  // "Wide", "Medium", "Close-Up", etc.
    public var lensMm: Int?  // 14, 24, 35, 50, 85, 100, 135, 200
    public var aperture: String  // "f/1.4", "f/2.8", etc.
    public var timeOfDay: String  // "Day", "Night", "Golden Hour", etc.
    public var weather: String  // "Clear", "Overcast", "Rain", etc.
    public var lightingStyle: String  // "Natural", "Studio", "Dramatic", etc.
    public var colorTemperature: String  // "3200K Tungsten", "5600K Daylight"
    public var aspectRatio: String  // "16:9", "2.39:1", etc.
    public var colorGrading: String  // "Neutral", "Warm", "Cool", etc.
    public var depthOfField: String  // "Shallow", "Medium", "Deep"

    // MARK: - Generation Details
    public var fullPrompt: String  // Complete prompt sent to AI
    public var negativePrompt: String  // Negative prompt
    public var modelUsed: String  // AI model identifier
    public var generationTimestamp: String

    // MARK: - User Notes
    public var userNotes: String
    public var isFavorite: Bool

    // MARK: - Metadata
    public var fileSizeBytes: Int
    public var imageWidth: Int
    public var imageHeight: Int
    public var createdDate: String

    public init(
        id: String = "scene_loc_img_\(UUID().uuidString.prefix(12))",
        sceneId: String = "",
        imagePath: String = "",
        locationName: String = "",
        locationType: String = "",
        indoorOutdoor: String = "Indoor",
        description: String = "",
        cameraAngle: String = "Medium",
        lensMm: Int? = 35,
        aperture: String = "f/2.8",
        timeOfDay: String = "Day",
        weather: String = "Clear",
        lightingStyle: String = "Natural",
        colorTemperature: String = "5600K Daylight",
        aspectRatio: String = "16:9",
        colorGrading: String = "Cinematic",
        depthOfField: String = "Medium",
        fullPrompt: String = "",
        negativePrompt: String = "",
        modelUsed: String = "imagen-3.0-generate-002",
        generationTimestamp: String = ISO8601DateFormatter().string(from: Date()),
        userNotes: String = "",
        isFavorite: Bool = false,
        fileSizeBytes: Int = 0,
        imageWidth: Int = 0,
        imageHeight: Int = 0,
        createdDate: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.sceneId = sceneId
        self.imagePath = imagePath
        self.locationName = locationName
        self.locationType = locationType
        self.indoorOutdoor = indoorOutdoor
        self.description = description
        self.cameraAngle = cameraAngle
        self.lensMm = lensMm
        self.aperture = aperture
        self.timeOfDay = timeOfDay
        self.weather = weather
        self.lightingStyle = lightingStyle
        self.colorTemperature = colorTemperature
        self.aspectRatio = aspectRatio
        self.colorGrading = colorGrading
        self.depthOfField = depthOfField
        self.fullPrompt = fullPrompt
        self.negativePrompt = negativePrompt
        self.modelUsed = modelUsed
        self.generationTimestamp = generationTimestamp
        self.userNotes = userNotes
        self.isFavorite = isFavorite
        self.fileSizeBytes = fileSizeBytes
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.createdDate = createdDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sceneId = "scene_id"
        case imagePath = "image_path"
        case locationName = "location_name"
        case locationType = "location_type"
        case indoorOutdoor = "indoor_outdoor"
        case description
        case cameraAngle = "camera_angle"
        case lensMm = "lens_mm"
        case aperture
        case timeOfDay = "time_of_day"
        case weather
        case lightingStyle = "lighting_style"
        case colorTemperature = "color_temperature"
        case aspectRatio = "aspect_ratio"
        case colorGrading = "color_grading"
        case depthOfField = "depth_of_field"
        case fullPrompt = "full_prompt"
        case negativePrompt = "negative_prompt"
        case modelUsed = "model_used"
        case generationTimestamp = "generation_timestamp"
        case userNotes = "user_notes"
        case isFavorite = "is_favorite"
        case fileSizeBytes = "file_size_bytes"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case createdDate = "created_date"
    }
}
