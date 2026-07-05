// DirectorsChairCore/Sources/DirectorsChairCore/Models/Scene.swift
//
// Scene model containing dialogues, actions, narrations, notes, and shots

import Foundation

/// Represents a scene containing dialogues, actions, narrations, notes, and cinematography
public struct Scene: Codable, Identifiable, Hashable, Sendable {
    public var id: String { uuid }

    public var uuid: String

    // MARK: - Basic Information
    public var name: String
    public var description: String
    public var notes: String  // Additional notes for the scene

    // MARK: - Scene Items
    public var dialogues: [Dialogue]
    public var actions: [Action]
    public var narrations: [Narration]
    public var sceneNotes: [Note]  // Production notes
    public var soundNotes: [SoundNote]  // Background sounds, music, SFX
    public var shots: [Shot]  // Planned camera shots
    public var locationImages: [SceneLocationImage]  // AI-generated location images

    // MARK: - Location & Context
    public var locationContext: [String: String]?  // Cached AI-analyzed location context
    public var stage: [String: String]  // Stage layout data (placeholder)
    public var props: [String]  // Props used in this scene
    public var location: String?  // Location name reference
    public var primaryCharacter: String?  // Character whose bubbles align left

    // MARK: - Production
    public var productionStatus: String  // "Planning", "Scheduled", "Ready", "Shooting", "Shot", "Complete"
    public var styleOverride: String?  // FilmStyle ID to override project default

    // MARK: - Scene Overview
    public var sceneOverviewImage: String?  // AI-generated composite showing emotional essence
    public var sceneEmotionalAnalysis: [String: Double]?  // Emotional analysis (emotions and weights)
    public var sceneOverviewPrompt: String?  // Prompt used to generate overview
    public var sceneOverviewSummary: String?  // AI-generated 2-3 sentence summary

    public init(
        uuid: String = UUID().uuidString,
        name: String,
        description: String = "",
        notes: String = "",
        dialogues: [Dialogue] = [],
        actions: [Action] = [],
        narrations: [Narration] = [],
        sceneNotes: [Note] = [],
        soundNotes: [SoundNote] = [],
        shots: [Shot] = [],
        locationImages: [SceneLocationImage] = [],
        locationContext: [String: String]? = nil,
        stage: [String: String] = [:],
        props: [String] = [],
        location: String? = nil,
        primaryCharacter: String? = nil,
        productionStatus: String = "Planning",
        styleOverride: String? = nil,
        sceneOverviewImage: String? = nil,
        sceneEmotionalAnalysis: [String: Double]? = nil,
        sceneOverviewPrompt: String? = nil,
        sceneOverviewSummary: String? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.notes = notes
        self.dialogues = dialogues
        self.actions = actions
        self.narrations = narrations
        self.sceneNotes = sceneNotes
        self.soundNotes = soundNotes
        self.shots = shots
        self.locationImages = locationImages
        self.locationContext = locationContext
        self.stage = stage
        self.props = props
        self.location = location
        self.primaryCharacter = primaryCharacter
        self.productionStatus = productionStatus
        self.styleOverride = styleOverride
        self.sceneOverviewImage = sceneOverviewImage
        self.sceneEmotionalAnalysis = sceneEmotionalAnalysis
        self.sceneOverviewPrompt = sceneOverviewPrompt
        self.sceneOverviewSummary = sceneOverviewSummary
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case description
        case notes
        case dialogues
        case actions
        case narrations
        case sceneNotes = "scene_notes"
        case soundNotes = "sound_notes"
        case shots
        case locationImages = "location_images"
        case locationContext = "location_context"
        case stage
        case props
        case location
        case primaryCharacter = "primary_character"
        case productionStatus = "production_status"
        case styleOverride = "style_override"
        case sceneOverviewImage = "scene_overview_image"
        case sceneEmotionalAnalysis = "scene_emotional_analysis"
        case sceneOverviewPrompt = "scene_overview_prompt"
        case sceneOverviewSummary = "scene_overview_summary"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // uuid: generate fresh if missing (migration from old projects)
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString

        // Required fields
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""

        // Scene items - provide empty arrays
        dialogues = try container.decodeIfPresent([Dialogue].self, forKey: .dialogues) ?? []
        actions = try container.decodeIfPresent([Action].self, forKey: .actions) ?? []
        narrations = try container.decodeIfPresent([Narration].self, forKey: .narrations) ?? []
        sceneNotes = try container.decodeIfPresent([Note].self, forKey: .sceneNotes) ?? []
        soundNotes = try container.decodeIfPresent([SoundNote].self, forKey: .soundNotes) ?? []
        shots = try container.decodeIfPresent([Shot].self, forKey: .shots) ?? []
        locationImages = try container.decodeIfPresent([SceneLocationImage].self, forKey: .locationImages) ?? []

        // Location & Context
        locationContext = try container.decodeIfPresent([String: String].self, forKey: .locationContext)
        stage = try container.decodeIfPresent([String: String].self, forKey: .stage) ?? [:]
        props = try container.decodeIfPresent([String].self, forKey: .props) ?? []
        location = try container.decodeIfPresent(String.self, forKey: .location)
        primaryCharacter = try container.decodeIfPresent(String.self, forKey: .primaryCharacter)

        // Production
        productionStatus = try container.decodeIfPresent(String.self, forKey: .productionStatus) ?? "Planning"
        styleOverride = try container.decodeIfPresent(String.self, forKey: .styleOverride)

        // Scene Overview
        sceneOverviewImage = try container.decodeIfPresent(String.self, forKey: .sceneOverviewImage)
        sceneEmotionalAnalysis = try container.decodeIfPresent([String: Double].self, forKey: .sceneEmotionalAnalysis)
        sceneOverviewPrompt = try container.decodeIfPresent(String.self, forKey: .sceneOverviewPrompt)
        sceneOverviewSummary = try container.decodeIfPresent(String.self, forKey: .sceneOverviewSummary)
    }
}
