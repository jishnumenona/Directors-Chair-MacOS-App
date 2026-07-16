// DirectorsChairCore/Sources/DirectorsChairCore/Models/Shot.swift
//
// Shot model for cinematography planning (PLACEHOLDER - to be fully implemented)

import Foundation

/// Represents a planned camera shot for a scene (cinematography)
/// Note: This is a placeholder. Full implementation with all 579 lines of Python reference pending.
public struct Shot: Codable, Identifiable, Hashable, Sendable {
    public var id: String { uuid }

    public var uuid: String
    public var shotId: Int  // Display number shown to users
    public var itemChronology: Int  // Links to dialogue/action/narration chronology
    public var description: String
    public var status: String  // "Planning", "Ready", "Shooting", "Review", "Approved"
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

    // Takes (production shooting)
    public var takes: [Take]

    // Video generation
    public var videoPath: String?                    // Relative path to generated video
    public var videoKeyframes: [VideoKeyframe]?      // Ordered keyframe images
    public var videoGenerationJobId: String?          // Active job ID for polling
    public var videoPrompt: String?                  // Last used prompt
    public var videoDuration: Double?                // Video-specific duration (bidirectional sync with shot.duration)
    public var videoProvider: String?                // Last used provider
    public var videoQuality: String?                 // Standard/High/Ultra
    public var videoResolution: String?              // "720p"/"1080p"

    public init(
        uuid: String = UUID().uuidString,
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
        timelinePosition: Double? = nil,
        takes: [Take] = [],
        videoPath: String? = nil,
        videoKeyframes: [VideoKeyframe]? = nil,
        videoGenerationJobId: String? = nil,
        videoPrompt: String? = nil,
        videoDuration: Double? = nil,
        videoProvider: String? = nil,
        videoQuality: String? = nil,
        videoResolution: String? = nil
    ) {
        self.uuid = uuid
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
        self.takes = takes
        self.videoPath = videoPath
        self.videoKeyframes = videoKeyframes
        self.videoGenerationJobId = videoGenerationJobId
        self.videoPrompt = videoPrompt
        self.videoDuration = videoDuration
        self.videoProvider = videoProvider
        self.videoQuality = videoQuality
        self.videoResolution = videoResolution
    }

    enum CodingKeys: String, CodingKey {
        case uuid
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
        case takes
        case videoPath = "video_path"
        case videoKeyframes = "video_keyframes"
        case videoGenerationJobId = "video_generation_job_id"
        case videoPrompt = "video_prompt"
        case videoDuration = "video_duration"
        case videoProvider = "video_provider"
        case videoQuality = "video_quality"
        case videoResolution = "video_resolution"
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

        // uuid: generate fresh if missing (migration from old projects)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString

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
        takes = try container.decodeIfPresent([Take].self, forKey: .takes) ?? []

        // Video generation fields
        videoPath = try container.decodeIfPresent(String.self, forKey: .videoPath)
        videoKeyframes = try container.decodeIfPresent([VideoKeyframe].self, forKey: .videoKeyframes)
        videoGenerationJobId = try container.decodeIfPresent(String.self, forKey: .videoGenerationJobId)
        videoPrompt = try container.decodeIfPresent(String.self, forKey: .videoPrompt)
        videoDuration = try container.decodeIfPresent(Double.self, forKey: .videoDuration)
        videoProvider = try container.decodeIfPresent(String.self, forKey: .videoProvider)
        videoQuality = try container.decodeIfPresent(String.self, forKey: .videoQuality)
        videoResolution = try container.decodeIfPresent(String.self, forKey: .videoResolution)
    }

    // MARK: - Take Helpers

    /// Next take number for this shot
    public var nextTakeNumber: Int {
        (takes.map { $0.takeNumber }.max() ?? 0) + 1
    }

    /// Takes rated as Circle (best/print)
    public var circledTakes: [Take] {
        takes.filter { $0.rating == .circle }
    }

    /// Whether this shot has any takes recorded
    public var hasTakes: Bool {
        !takes.isEmpty
    }

    /// Auto-compute shot status based on take ratings.
    /// - Any circled take → Approved
    /// - All takes rated NG → Not Good
    /// - Has takes → Review
    /// - No takes → status unchanged
    public mutating func updateStatusFromTakes() {
        guard !takes.isEmpty else { return }

        if takes.contains(where: { $0.rating == .circle }) {
            status = "Approved"
        } else if takes.allSatisfy({ $0.rating == .ng }) {
            status = "Not Good"
        } else {
            status = "Review"
        }
    }
}

// MARK: - Video Keyframe

/// A keyframe position within a video generation request
public struct VideoKeyframe: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var position: Double     // 0.0 = start, 1.0 = end (fractional position)
    public var imagePath: String?   // Relative path to keyframe image
    public var label: String        // "Start", "End", or custom
    public var timestamp: Double    // Time in seconds within the video
    public var annotations: [KeyframeAnnotation]?  // Point-and-click edit annotations

    public init(
        id: String = UUID().uuidString,
        position: Double = 0.0,
        imagePath: String? = nil,
        label: String = "",
        timestamp: Double = 0.0,
        annotations: [KeyframeAnnotation]? = nil
    ) {
        self.id = id
        self.position = position
        self.imagePath = imagePath
        self.label = label
        self.timestamp = timestamp
        self.annotations = annotations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        position = try container.decode(Double.self, forKey: .position)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        timestamp = try container.decodeIfPresent(Double.self, forKey: .timestamp) ?? 0.0
        annotations = try container.decodeIfPresent([KeyframeAnnotation].self, forKey: .annotations)
    }

    enum CodingKeys: String, CodingKey {
        case id, position, imagePath, label, timestamp, annotations
    }
}

// MARK: - Keyframe Annotation

/// A spatial annotation pinned to a keyframe image for edit instructions
public struct KeyframeAnnotation: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var normalizedX: Double  // 0.0-1.0 (left to right)
    public var normalizedY: Double  // 0.0-1.0 (top to bottom)
    public var text: String
    public var number: Int          // Display number (1, 2, 3...)

    public init(
        id: String = UUID().uuidString,
        normalizedX: Double = 0.5,
        normalizedY: Double = 0.5,
        text: String = "",
        number: Int = 1
    ) {
        self.id = id
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.text = text
        self.number = number
    }
}

// MARK: - Reference Media

/// Represents a reference image or video for a shot
public struct ReferenceMedia: Codable, Identifiable, Hashable, Sendable {
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

    public enum MediaType: String, Codable, Hashable, Sendable {
        case image
        case video
    }
}
