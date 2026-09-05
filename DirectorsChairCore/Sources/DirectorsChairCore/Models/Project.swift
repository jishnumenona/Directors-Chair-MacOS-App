// DirectorsChairCore/Sources/DirectorsChairCore/Models/Project.swift
//
// Root project model aggregating all data

import Foundation

/// Root project model - aggregates all project data and metadata
/// This is the main data structure that gets serialized to/from project.json
public struct Project: Codable, Identifiable, Hashable, Sendable {
    public var id: String { uuid }

    /// Stable identity, independent of name. Renaming a project no longer
    /// changes its identity for sync, repo mapping, or cross-app references.
    /// Legacy files without a uuid get one on first load.
    public var uuid: String = UUID().uuidString

    /// The document format version this project was written with. Persisted as
    /// `schema_version`. Legacy files that predate versioning decode as 1.
    /// `ProjectPersistence.load` refuses to open a file whose major version is
    /// newer than the app supports, so an older build can never silently strip
    /// fields it doesn't understand and rewrite a lossy file.
    ///
    /// History — bump this whenever a release adds fields an older build
    /// would drop on save (DC-0116):
    ///   1  2026-07 — first versioned files
    ///   2  2026-09 — shot sketches and studio state (sketch_image), the
    ///                saved-by stamps, pictures kept from the iPad
    public static let currentSchemaVersion: Int = 2
    public var schemaVersion: Int = Project.currentSchemaVersion
    /// Which app wrote the file last (DC-0116) — persisted so an older build
    /// can name the version the user needs: "saved by Director's Chair 3.12.0
    /// on macOS". Stamped by ProjectPersistence.save.
    public var savedByAppVersion: String? = nil
    public var savedByPlatform: String? = nil
    public var savedAt: String? = nil

    // MARK: - Core Identity
    public var name: String
    /// Absolute path to the project directory. This is DEVICE-LOCAL runtime
    /// state, deliberately NOT serialized — a project.json synced to another Mac
    /// or an iPad must not carry a dead /Users/... path. It is populated at load
    /// time from the file's own location (ProjectPersistence.load).
    public var basePath: String  // Path to project directory (not persisted)

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
    /// Vision cards for visual references. The JSON key "beats" is
    /// LOAD-BEARING legacy naming (vision cards were once beat cards) —
    /// every saved project on disk uses it. Never rename the key.
    public var beats: [VisionCard]
    public var visionBoards: [VisionBoardMeta]  // Persisted board registry
    public var visionConnectors: [VisionConnector]  // Labeled arrows between cards

    // MARK: - Production Planning
    public var scheduleItems: [ScheduleItem]
    public var ganttTasks: [GanttTask]

    // MARK: - Film Style System
    public var filmStyles: [FilmStyle]
    public var defaultFilmStyle: String?  // FilmStyle ID for project default

    // MARK: - Cast, Crew, Teams, Equipment
    public var castMembers: [CastMember]
    public var crewMembers: [CrewMember]
    public var teams: [Team]
    public var equipmentLibrary: [EquipmentItem]
    public var equipmentAllocations: [EquipmentAllocation]

    // MARK: - User Management
    public var userManager: ProjectUserManager?

    // MARK: - Soundtracks
    public var soundtracks: [SoundtrackTrack]

    // MARK: - Light Cues
    public var lightCues: [LightCue]

    // MARK: - SFX Cues
    public var sfxCues: [SFXCue]

    // MARK: - Support Cues
    public var supportCues: [SupportCue]

    // MARK: - Budget
    public var projectBudget: ProjectBudget?

    // MARK: - Accounting Defaults
    public var defaultExpenseDepartment: String
    public var defaultExpenseAccountCode: String

    // MARK: - Generated Previews (DC-0090)
    /// The size every generated shot/scene/location preview is delivered at.
    public var previewResolution: PreviewResolution

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

    // MARK: - Script revisions (§2.18)
    /// The current revision round's color ("White" at lock, then "Blue",
    /// "Pink", …). nil = scene numbers not locked; the script is still a
    /// working draft.
    public var scriptRevisionColor: String?
    /// One row per round, oldest first — the production paper trail.
    public var scriptRevisionHistory: [ScriptRevisionRound]
    /// Scene fingerprints captured when the current round began; what a
    /// scene is compared against to decide "changed this round".
    public var scriptRevisionBaseline: [String: String]

    /// Next globally unique shot display number across all scenes
    public var nextShotDisplayNumber: Int {
        let allShots = sequences.flatMap { $0.scenes.flatMap { $0.shots } }
        return (allShots.map { $0.shotId }.max() ?? 0) + 1
    }

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
        visionBoards: [VisionBoardMeta] = [],
        visionConnectors: [VisionConnector] = [],
        scheduleItems: [ScheduleItem] = [],
        ganttTasks: [GanttTask] = [],
        filmStyles: [FilmStyle] = [],
        defaultFilmStyle: String? = nil,
        castMembers: [CastMember] = [],
        crewMembers: [CrewMember] = [],
        teams: [Team] = [],
        equipmentLibrary: [EquipmentItem] = [],
        equipmentAllocations: [EquipmentAllocation] = [],
        soundtracks: [SoundtrackTrack] = [],
        lightCues: [LightCue] = [],
        sfxCues: [SFXCue] = [],
        supportCues: [SupportCue] = [],
        userManager: ProjectUserManager? = nil,
        projectBudget: ProjectBudget? = nil,
        defaultExpenseDepartment: String = "",
        defaultExpenseAccountCode: String = "",
        previewResolution: PreviewResolution = .default,
        overviewPosterPath: String? = nil,
        overviewPosterPaths: [String] = [],
        overviewPosterCurrentIndex: Int = 0,
        overviewPosterCustom: Bool = false,
        overviewSummary: String = "",
        overviewSummaryGeneratedAt: String? = nil,
        overviewTagline: String = "",
        overviewLogline: String = "",
        overviewMoodAnalysis: [String: Double]? = nil,
        scriptRevisionColor: String? = nil,
        scriptRevisionHistory: [ScriptRevisionRound] = [],
        scriptRevisionBaseline: [String: String] = [:]
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
        self.visionBoards = visionBoards
        self.visionConnectors = visionConnectors
        self.scheduleItems = scheduleItems
        self.ganttTasks = ganttTasks
        self.filmStyles = filmStyles
        self.defaultFilmStyle = defaultFilmStyle
        self.castMembers = castMembers
        self.crewMembers = crewMembers
        self.teams = teams
        self.equipmentLibrary = equipmentLibrary
        self.equipmentAllocations = equipmentAllocations
        self.soundtracks = soundtracks
        self.lightCues = lightCues
        self.sfxCues = sfxCues
        self.supportCues = supportCues
        self.userManager = userManager
        self.projectBudget = projectBudget
        self.defaultExpenseDepartment = defaultExpenseDepartment
        self.previewResolution = previewResolution
        self.defaultExpenseAccountCode = defaultExpenseAccountCode
        self.overviewPosterPath = overviewPosterPath
        self.overviewPosterPaths = overviewPosterPaths
        self.overviewPosterCurrentIndex = overviewPosterCurrentIndex
        self.overviewPosterCustom = overviewPosterCustom
        self.overviewSummary = overviewSummary
        self.overviewSummaryGeneratedAt = overviewSummaryGeneratedAt
        self.overviewTagline = overviewTagline
        self.overviewLogline = overviewLogline
        self.overviewMoodAnalysis = overviewMoodAnalysis
        self.scriptRevisionColor = scriptRevisionColor
        self.scriptRevisionHistory = scriptRevisionHistory
        self.scriptRevisionBaseline = scriptRevisionBaseline
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case schemaVersion = "schema_version"
        case savedByAppVersion = "saved_by_app_version"
        case savedByPlatform = "saved_by_platform"
        case savedAt = "saved_at"
        case name
        // base_path intentionally omitted — device-local, populated at load.
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
        case visionBoards = "vision_boards"
        case visionConnectors = "vision_connectors"
        case scheduleItems = "schedule_items"
        case ganttTasks = "gantt_tasks"
        case filmStyles = "film_styles"
        case defaultFilmStyle = "default_film_style"
        case castMembers = "cast_members"
        case crewMembers = "crew_members"
        case teams
        case equipmentLibrary = "equipment_library"
        case equipmentAllocations = "equipment_allocations"
        case soundtracks
        case lightCues = "light_cues"
        case sfxCues = "sfx_cues"
        case supportCues = "support_cues"
        case userManager = "user_manager"
        case projectBudget = "project_budget"
        case defaultExpenseDepartment = "default_expense_department"
        case defaultExpenseAccountCode = "default_expense_account_code"
        case previewResolution = "preview_resolution"
        case overviewPosterPath = "overview_poster_path"
        case overviewPosterPaths = "overview_poster_paths"
        case overviewPosterCurrentIndex = "overview_poster_current_index"
        case overviewPosterCustom = "overview_poster_custom"
        case overviewSummary = "overview_summary"
        case overviewSummaryGeneratedAt = "overview_summary_generated_at"
        case overviewTagline = "overview_tagline"
        case overviewLogline = "overview_logline"
        case overviewMoodAnalysis = "overview_mood_analysis"
        case scriptRevisionColor = "script_revision_color"
        case scriptRevisionHistory = "script_revision_history"
        case scriptRevisionBaseline = "script_revision_baseline"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Stable identity — legacy files without a uuid get a fresh one.
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString

        // Format version — absent in legacy (pre-versioning) files, which are v1.
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        savedByAppVersion = try container.decodeIfPresent(String.self, forKey: .savedByAppVersion)
        savedByPlatform = try container.decodeIfPresent(String.self, forKey: .savedByPlatform)
        savedAt = try container.decodeIfPresent(String.self, forKey: .savedAt)

        // Core identity (required)
        name = try container.decode(String.self, forKey: .name)
        // Device-local; populated after decode by ProjectPersistence.load.
        basePath = ""

        // Project metadata with defaults
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        director = try container.decodeIfPresent(String.self, forKey: .director) ?? ""
        productionCompany = try container.decodeIfPresent(String.self, forKey: .productionCompany) ?? ""
        genre = try container.decodeIfPresent(String.self, forKey: .genre) ?? ""
        projectType = try container.decodeIfPresent(String.self, forKey: .projectType) ?? "Skit"
        targetDuration = try container.decodeIfPresent(String.self, forKey: .targetDuration) ?? ""
        budget = try container.decodeIfPresent(String.self, forKey: .budget) ?? ""
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate) ?? ""
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Pre-production"
        projectNotes = try container.decodeIfPresent(String.self, forKey: .projectNotes) ?? ""
        projectIcon = try container.decodeIfPresent(String.self, forKey: .projectIcon) ?? ""
        languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? ["English"]

        // Project data arrays
        characters = try container.decodeIfPresent([Character].self, forKey: .characters) ?? []
        props = try container.decodeIfPresent([Prop].self, forKey: .props) ?? []
        costumes = try container.decodeIfPresent([Costume].self, forKey: .costumes) ?? []
        lighting = try container.decodeIfPresent([Lighting].self, forKey: .lighting) ?? []
        effects = try container.decodeIfPresent([EffectDef].self, forKey: .effects) ?? []
        locations = try container.decodeIfPresent([Location].self, forKey: .locations) ?? []
        sequences = try container.decodeIfPresent([Sequence].self, forKey: .sequences) ?? []
        beats = try container.decodeIfPresent([VisionCard].self, forKey: .beats) ?? []
        visionBoards = try container.decodeIfPresent([VisionBoardMeta].self,
                                                     forKey: .visionBoards) ?? []
        visionConnectors = try container.decodeIfPresent([VisionConnector].self,
                                                         forKey: .visionConnectors) ?? []

        // Production planning
        scheduleItems = try container.decodeIfPresent([ScheduleItem].self, forKey: .scheduleItems) ?? []
        ganttTasks = try container.decodeIfPresent([GanttTask].self, forKey: .ganttTasks) ?? []

        // Film styles
        filmStyles = try container.decodeIfPresent([FilmStyle].self, forKey: .filmStyles) ?? []
        defaultFilmStyle = try container.decodeIfPresent(String.self, forKey: .defaultFilmStyle)

        // Cast, crew, teams, equipment
        castMembers = try container.decodeIfPresent([CastMember].self, forKey: .castMembers) ?? []
        crewMembers = try container.decodeIfPresent([CrewMember].self, forKey: .crewMembers) ?? []
        teams = try container.decodeIfPresent([Team].self, forKey: .teams) ?? []
        equipmentLibrary = try container.decodeIfPresent([EquipmentItem].self, forKey: .equipmentLibrary) ?? []
        equipmentAllocations = try container.decodeIfPresent([EquipmentAllocation].self, forKey: .equipmentAllocations) ?? []

        // Soundtracks
        soundtracks = try container.decodeIfPresent([SoundtrackTrack].self, forKey: .soundtracks) ?? []

        // Light cues
        lightCues = try container.decodeIfPresent([LightCue].self, forKey: .lightCues) ?? []

        // SFX cues
        sfxCues = try container.decodeIfPresent([SFXCue].self, forKey: .sfxCues) ?? []

        // Support cues
        supportCues = try container.decodeIfPresent([SupportCue].self, forKey: .supportCues) ?? []

        // User management and budget
        userManager = try container.decodeIfPresent(ProjectUserManager.self, forKey: .userManager)
        projectBudget = try container.decodeIfPresent(ProjectBudget.self, forKey: .projectBudget)

        // Accounting defaults
        defaultExpenseDepartment = try container.decodeIfPresent(String.self, forKey: .defaultExpenseDepartment) ?? ""
        defaultExpenseAccountCode = try container.decodeIfPresent(String.self, forKey: .defaultExpenseAccountCode) ?? ""

        // Generated previews (DC-0090): absent in older files = Full HD.
        previewResolution = PreviewResolution.stored(try? container.decodeIfPresent(String.self, forKey: .previewResolution))

        // Project overview
        overviewPosterPath = try container.decodeIfPresent(String.self, forKey: .overviewPosterPath)
        overviewPosterPaths = try container.decodeIfPresent([String].self, forKey: .overviewPosterPaths) ?? []
        overviewPosterCurrentIndex = try container.decodeIfPresent(Int.self, forKey: .overviewPosterCurrentIndex) ?? 0
        overviewPosterCustom = try container.decodeIfPresent(Bool.self, forKey: .overviewPosterCustom) ?? false
        overviewSummary = try container.decodeIfPresent(String.self, forKey: .overviewSummary) ?? ""
        overviewSummaryGeneratedAt = try container.decodeIfPresent(String.self, forKey: .overviewSummaryGeneratedAt)
        overviewTagline = try container.decodeIfPresent(String.self, forKey: .overviewTagline) ?? ""
        overviewLogline = try container.decodeIfPresent(String.self, forKey: .overviewLogline) ?? ""
        overviewMoodAnalysis = try container.decodeIfPresent([String: Double].self, forKey: .overviewMoodAnalysis)

        // Script revisions (§2.18) — decode-optional, pre-revision
        // projects open unchanged.
        scriptRevisionColor = try container.decodeIfPresent(String.self, forKey: .scriptRevisionColor)
        scriptRevisionHistory = try container.decodeIfPresent([ScriptRevisionRound].self, forKey: .scriptRevisionHistory) ?? []
        scriptRevisionBaseline = try container.decodeIfPresent([String: String].self, forKey: .scriptRevisionBaseline) ?? [:]
    }
}

// MARK: - ProjectUserManager

/// Simple user management structure (placeholder for full implementation)
public struct ProjectUserManager: Codable, Hashable, Sendable {
    public var users: [String]  // List of user IDs or names

    public init(users: [String] = []) {
        self.users = users
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decodeIfPresent([String].self, forKey: .users) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case users
    }
}
