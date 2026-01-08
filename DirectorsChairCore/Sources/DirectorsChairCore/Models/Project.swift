// DirectorsChairCore/Sources/DirectorsChairCore/Models/Project.swift
//
// Root project model aggregating all data

import Foundation

/// Root project model - aggregates all project data and metadata
/// This is the main data structure that gets serialized to/from project.json
public struct Project: Codable, Identifiable, Hashable {
    public var id: String { name }

    // MARK: - Core Identity
    public var name: String
    public var basePath: String  // Path to project directory

    // MARK: - Project Metadata/Settings
    public var description: String
    public var director: String
    public var productionCompany: String
    public var genre: String
    public var projectType: String  // "Skit", "Motion Film", "Series", "Game play"
    public var targetDuration: String  // e.g., "120 minutes", "2 hours"
    public var budget: String
    public var startDate: String
    public var endDate: String
    public var status: String  // "Analysis", "Pre-production", "Production", "Post-production", "Completed"
    public var projectNotes: String
    public var projectIcon: String  // Path to icon file relative to project base
    public var languages: [String]  // Languages used in dialogues

    // MARK: - Project Data (all the models)
    public var characters: [Character]
    public var props: [Prop]
    public var costumes: [Costume]
    public var lighting: [Lighting]
    public var effects: [EffectDef]
    public var locations: [Location]
    public var sequences: [Sequence]
    public var beats: [VisionCard]  // Vision cards for visual references

    // MARK: - Production Planning
    public var scheduleItems: [ScheduleItem]

    // MARK: - Film Style System
    public var filmStyles: [FilmStyle]
    public var defaultFilmStyle: String?  // FilmStyle ID for project default

    // MARK: - Cast, Crew, Teams, Equipment
    public var castMembers: [CastMember]
    public var crewMembers: [CrewMember]
    public var teams: [Team]
    public var equipmentLibrary: [EquipmentItem]

    // MARK: - User Management
    public var userManager: ProjectUserManager?

    // MARK: - Budget
    public var projectBudget: ProjectBudget?

    // MARK: - Project Overview (for pitching to producers)
    public var overviewPosterPath: String?  // DEPRECATED: Use overviewPosterPaths list
    public var overviewPosterPaths: [String]  // List of poster paths (relative to project base)
    public var overviewPosterCurrentIndex: Int  // Index of currently displayed poster
    public var overviewPosterCustom: Bool  // True if user uploaded custom poster
    public var overviewSummary: String  // AI-generated pitch summary
    public var overviewSummaryGeneratedAt: String?  // ISO timestamp
    public var overviewTagline: String  // One-line tagline
    public var overviewLogline: String  // 2-3 sentence logline
    public var overviewMoodAnalysis: [String: Double]?  // AI mood/tone data

    public init(
        name: String,
        basePath: String = "",
        description: String = "",
        director: String = "",
        productionCompany: String = "",
        genre: String = "",
        projectType: String = "Skit",
        targetDuration: String = "",
        budget: String = "",
        startDate: String = "",
        endDate: String = "",
        status: String = "Pre-production",
        projectNotes: String = "",
        projectIcon: String = "",
        languages: [String] = ["English"],
        characters: [Character] = [],
        props: [Prop] = [],
        costumes: [Costume] = [],
        lighting: [Lighting] = [],
        effects: [EffectDef] = [],
        locations: [Location] = [],
        sequences: [Sequence] = [],
        beats: [VisionCard] = [],
        scheduleItems: [ScheduleItem] = [],
        filmStyles: [FilmStyle] = [],
        defaultFilmStyle: String? = nil,
        castMembers: [CastMember] = [],
        crewMembers: [CrewMember] = [],
        teams: [Team] = [],
        equipmentLibrary: [EquipmentItem] = [],
        userManager: ProjectUserManager? = nil,
        projectBudget: ProjectBudget? = nil,
        overviewPosterPath: String? = nil,
        overviewPosterPaths: [String] = [],
        overviewPosterCurrentIndex: Int = 0,
        overviewPosterCustom: Bool = false,
        overviewSummary: String = "",
        overviewSummaryGeneratedAt: String? = nil,
        overviewTagline: String = "",
        overviewLogline: String = "",
        overviewMoodAnalysis: [String: Double]? = nil
    ) {
        self.name = name
        self.basePath = basePath
        self.description = description
        self.director = director
        self.productionCompany = productionCompany
        self.genre = genre
        self.projectType = projectType
        self.targetDuration = targetDuration
        self.budget = budget
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.projectNotes = projectNotes
        self.projectIcon = projectIcon
        self.languages = languages
        self.characters = characters
        self.props = props
        self.costumes = costumes
        self.lighting = lighting
        self.effects = effects
        self.locations = locations
        self.sequences = sequences
        self.beats = beats
        self.scheduleItems = scheduleItems
        self.filmStyles = filmStyles
        self.defaultFilmStyle = defaultFilmStyle
        self.castMembers = castMembers
        self.crewMembers = crewMembers
        self.teams = teams
        self.equipmentLibrary = equipmentLibrary
        self.userManager = userManager
        self.projectBudget = projectBudget
        self.overviewPosterPath = overviewPosterPath
        self.overviewPosterPaths = overviewPosterPaths
        self.overviewPosterCurrentIndex = overviewPosterCurrentIndex
        self.overviewPosterCustom = overviewPosterCustom
        self.overviewSummary = overviewSummary
        self.overviewSummaryGeneratedAt = overviewSummaryGeneratedAt
        self.overviewTagline = overviewTagline
        self.overviewLogline = overviewLogline
        self.overviewMoodAnalysis = overviewMoodAnalysis
    }

    enum CodingKeys: String, CodingKey {
        case name
        case basePath = "base_path"
        case description
        case director
        case productionCompany = "production_company"
        case genre
        case projectType = "project_type"
        case targetDuration = "target_duration"
        case budget
        case startDate = "start_date"
        case endDate = "end_date"
        case status
        case projectNotes = "project_notes"
        case projectIcon = "project_icon"
        case languages
        case characters
        case props
        case costumes
        case lighting
        case effects
        case locations
        case sequences
        case beats
        case scheduleItems = "schedule_items"
        case filmStyles = "film_styles"
        case defaultFilmStyle = "default_film_style"
        case castMembers = "cast_members"
        case crewMembers = "crew_members"
        case teams
        case equipmentLibrary = "equipment_library"
        case userManager = "user_manager"
        case projectBudget = "project_budget"
        case overviewPosterPath = "overview_poster_path"
        case overviewPosterPaths = "overview_poster_paths"
        case overviewPosterCurrentIndex = "overview_poster_current_index"
        case overviewPosterCustom = "overview_poster_custom"
        case overviewSummary = "overview_summary"
        case overviewSummaryGeneratedAt = "overview_summary_generated_at"
        case overviewTagline = "overview_tagline"
        case overviewLogline = "overview_logline"
        case overviewMoodAnalysis = "overview_mood_analysis"
    }
}

// MARK: - ProjectUserManager

/// Simple user management structure (placeholder for full implementation)
public struct ProjectUserManager: Codable, Hashable {
    public var users: [String]  // List of user IDs or names

    public init(users: [String] = []) {
        self.users = users
    }
}
