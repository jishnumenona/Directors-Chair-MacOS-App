// DirectorsChairCore/Sources/DirectorsChairCore/Models/Character.swift
//
// Comprehensive character model with 70+ fields including physical appearance,
// personality traits, biography, relationships, and multi-angle imagery

import Foundation

/// Comprehensive character model supporting physical appearance, personality traits,
/// biography, relationships, and multi-angle imagery
public struct Character: Codable, Identifiable, Hashable {
    // MARK: - Identifiable
    public var id: String { characterId }

    // MARK: - Basic Information (7 legacy fields + extensions)
    public var characterId: String
    public var name: String
    public var role: String  // e.g., "Protagonist", "Antagonist", "Supporting"
    public var color: String  // Bubble color for dialogue
    public var textColor: String  // Text color for dialogue bubbles
    public var avatar: String?  // Legacy: single avatar image path
    public var about: String  // Legacy: short description
    public var gender: String  // "male", "female", "neutral", "other"
    public var voice: String?  // TTS voice name

    // MARK: - Physical Appearance (12 fields)
    public var heightCm: Double?  // Height in centimeters
    public var weightKg: Double?  // Weight in kilograms
    public var build: String  // "Slim", "Athletic", "Average", "Stocky", "Heavy"
    public var age: Int  // Character's age

    // Hair
    public var hairColor: String  // Hair color (hex or name)
    public var hairStyle: String  // e.g., "Short and Spiky", "Long and Wavy"
    public var hairLength: String  // "Bald", "Short", "Medium", "Long", "Very Long"

    // Eyes
    public var eyeColor: String  // Eye color (hex for color picker)
    public var eyeColorDescription: String  // Eye color description
    public var eyeShape: String  // "Almond", "Round", "Hooded", etc.

    // Skin
    public var skinTone: String  // Skin tone (hex or name)
    public var ethnicity: String  // Ethnic background

    // Other physical features
    public var distinguishingFeatures: String  // Scars, tattoos, birthmarks
    public var facialStructure: String  // "Oval", "Round", "Square", etc.

    // MARK: - Character Images (12 angles for multi-view visualization)
    public var baseImage: String?  // Master reference image
    public var baseImagePrompt: String?  // Comprehensive prompt for base image

    public var imageFront: String?
    public var imageThreeQuarterLeft: String?
    public var imageThreeQuarterRight: String?
    public var imageProfileLeft: String?
    public var imageProfileRight: String?
    public var imageBackThreeQuarterLeft: String?
    public var imageBackThreeQuarterRight: String?
    public var imageBack: String?
    public var imageFaceCloseupFront: String?
    public var imageFaceCloseupThreeQuarter: String?
    public var imageFaceCloseupProfile: String?
    public var imageActionPose: String?

    // MARK: - Face Image Set (consistent face across all angles)
    public var faceImageFront: String?
    public var faceImageThreeQuarterLeft: String?
    public var faceImageThreeQuarterRight: String?
    public var faceImageProfile: String?

    // MARK: - Body Image Set (consistent full body across all angles)
    public var bodyImageFront: String?
    public var bodyImageThreeQuarterLeft: String?
    public var bodyImageThreeQuarterRight: String?
    public var bodyImageProfile: String?

    // MARK: - Costume Image Set (costume-transformed body images)
    public var costumeImageFront: String?
    public var costumeImageThreeQuarterLeft: String?
    public var costumeImageThreeQuarterRight: String?
    public var costumeImageProfile: String?
    public var costumeTransformationPrompt: String?

    // MARK: - Costume/Attire
    public var costume: String?  // Costume/clothing description for AI
    public var backgroundSetting: String?  // Background/location description

    // Multiple Costumes System
    public var costumes: [CharacterCostume]?
    public var activeCostumeIndex: Int?

    // AI Generation prompts
    public var imagePrompts: [String: String]?  // Maps angle field name to generation prompt

    // Image annotations
    public var imageAnnotations: [String: [[String: String]]]?

    // MARK: - Overview / Character Sheet
    public var overviewPortrait: String?  // AI-generated portrait for overview
    public var overviewHtml: String?  // Complete HTML content for character overview

    // MARK: - Personality Traits (25 traits organized by 5 categories)
    public var traits: [String: Double]  // Each trait 0.0-100.0, default 50.0

    // MARK: - AI Calibration Metadata
    public var traitsLastCalibrated: Date?  // When AI last calibrated traits
    public var traitsConfidenceScore: Double?  // AI's confidence (0-100)
    public var traitsDataSources: [String]  // Scene IDs used for calibration
    public var traitsAiReasoning: String?  // AI's explanation of trait assignments
    public var traitsAiRanges: [String: [Double]]?  // AI-suggested trait ranges (min, max)

    // MARK: - Biography (11 fields)
    public var fullName: String?  // Full legal name
    public var nickname: String?  // Nickname or alias
    public var occupation: String?  // Job or profession
    public var affiliation: String?  // Organization, group, faction
    public var backgroundStory: String?  // Character's past

    // Motivations & Goals
    public var primaryGoal: String?  // Main objective
    public var secondaryGoal: String?  // Secondary objective
    public var hiddenMotivation: String?  // Secret desire

    // Fears & Weaknesses
    public var primaryFear: String?  // What character is most afraid of
    public var weakness: String?  // Physical, emotional, or strategic weakness
    public var flaw: String?  // Personality flaw or defect

    // Character Development
    public var characterArcNotes: String?  // Notes on character's development

    // MARK: - Relationships
    public var relationships: [String: String]?  // character_name: relationship_description

    // MARK: - Story Timeline
    public var firstAppearanceSceneId: String?
    public var lastAppearanceSceneId: String?
    public var sceneAppearances: [String]?  // All scene IDs
    public var totalDialogueLines: Int?
    public var totalScreenTimeSeconds: Double?

    // MARK: - Metadata
    public var createdAt: Date?
    public var updatedAt: Date?
    public var version: Int?

    // MARK: - Initialization
    public init(
        characterId: String = UUID().uuidString,
        name: String,
        role: String = "",
        color: String = "#5d5d5d",
        textColor: String = "#FFFFFF",
        avatar: String? = nil,
        about: String = "",
        gender: String = "neutral",
        voice: String? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        build: String = "Average",
        age: Int = 30,
        hairColor: String = "#2C1810",
        hairStyle: String = "Medium, Straight",
        hairLength: String = "Medium",
        eyeColor: String = "#654321",
        eyeColorDescription: String = "",
        eyeShape: String = "Almond",
        skinTone: String = "#D4A574",
        ethnicity: String = "",
        distinguishingFeatures: String = "",
        facialStructure: String = "Oval",
        baseImage: String? = nil,
        baseImagePrompt: String? = nil,
        imageFront: String? = nil,
        imageThreeQuarterLeft: String? = nil,
        imageThreeQuarterRight: String? = nil,
        imageProfileLeft: String? = nil,
        imageProfileRight: String? = nil,
        imageBackThreeQuarterLeft: String? = nil,
        imageBackThreeQuarterRight: String? = nil,
        imageBack: String? = nil,
        imageFaceCloseupFront: String? = nil,
        imageFaceCloseupThreeQuarter: String? = nil,
        imageFaceCloseupProfile: String? = nil,
        imageActionPose: String? = nil,
        faceImageFront: String? = nil,
        faceImageThreeQuarterLeft: String? = nil,
        faceImageThreeQuarterRight: String? = nil,
        faceImageProfile: String? = nil,
        bodyImageFront: String? = nil,
        bodyImageThreeQuarterLeft: String? = nil,
        bodyImageThreeQuarterRight: String? = nil,
        bodyImageProfile: String? = nil,
        costumeImageFront: String? = nil,
        costumeImageThreeQuarterLeft: String? = nil,
        costumeImageThreeQuarterRight: String? = nil,
        costumeImageProfile: String? = nil,
        costumeTransformationPrompt: String? = nil,
        costume: String? = nil,
        backgroundSetting: String? = nil,
        costumes: [CharacterCostume]? = nil,
        activeCostumeIndex: Int? = nil,
        imagePrompts: [String: String]? = nil,
        imageAnnotations: [String: [[String: String]]]? = nil,
        overviewPortrait: String? = nil,
        overviewHtml: String? = nil,
        traits: [String: Double] = Self.defaultTraits(),
        traitsLastCalibrated: Date? = nil,
        traitsConfidenceScore: Double? = nil,
        traitsDataSources: [String] = [],
        traitsAiReasoning: String? = nil,
        traitsAiRanges: [String: [Double]]? = nil,
        fullName: String? = nil,
        nickname: String? = nil,
        occupation: String? = nil,
        affiliation: String? = nil,
        backgroundStory: String? = nil,
        primaryGoal: String? = nil,
        secondaryGoal: String? = nil,
        hiddenMotivation: String? = nil,
        primaryFear: String? = nil,
        weakness: String? = nil,
        flaw: String? = nil,
        characterArcNotes: String? = nil,
        relationships: [String: String]? = nil,
        firstAppearanceSceneId: String? = nil,
        lastAppearanceSceneId: String? = nil,
        sceneAppearances: [String]? = nil,
        totalDialogueLines: Int? = nil,
        totalScreenTimeSeconds: Double? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        version: Int? = nil
    ) {
        self.characterId = characterId
        self.name = name
        self.role = role
        self.color = color
        self.textColor = textColor
        self.avatar = avatar
        self.about = about
        self.gender = gender
        self.voice = voice
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.build = build
        self.age = age
        self.hairColor = hairColor
        self.hairStyle = hairStyle
        self.hairLength = hairLength
        self.eyeColor = eyeColor
        self.eyeColorDescription = eyeColorDescription
        self.eyeShape = eyeShape
        self.skinTone = skinTone
        self.ethnicity = ethnicity
        self.distinguishingFeatures = distinguishingFeatures
        self.facialStructure = facialStructure
        self.baseImage = baseImage
        self.baseImagePrompt = baseImagePrompt
        self.imageFront = imageFront
        self.imageThreeQuarterLeft = imageThreeQuarterLeft
        self.imageThreeQuarterRight = imageThreeQuarterRight
        self.imageProfileLeft = imageProfileLeft
        self.imageProfileRight = imageProfileRight
        self.imageBackThreeQuarterLeft = imageBackThreeQuarterLeft
        self.imageBackThreeQuarterRight = imageBackThreeQuarterRight
        self.imageBack = imageBack
        self.imageFaceCloseupFront = imageFaceCloseupFront
        self.imageFaceCloseupThreeQuarter = imageFaceCloseupThreeQuarter
        self.imageFaceCloseupProfile = imageFaceCloseupProfile
        self.imageActionPose = imageActionPose
        self.faceImageFront = faceImageFront
        self.faceImageThreeQuarterLeft = faceImageThreeQuarterLeft
        self.faceImageThreeQuarterRight = faceImageThreeQuarterRight
        self.faceImageProfile = faceImageProfile
        self.bodyImageFront = bodyImageFront
        self.bodyImageThreeQuarterLeft = bodyImageThreeQuarterLeft
        self.bodyImageThreeQuarterRight = bodyImageThreeQuarterRight
        self.bodyImageProfile = bodyImageProfile
        self.costumeImageFront = costumeImageFront
        self.costumeImageThreeQuarterLeft = costumeImageThreeQuarterLeft
        self.costumeImageThreeQuarterRight = costumeImageThreeQuarterRight
        self.costumeImageProfile = costumeImageProfile
        self.costumeTransformationPrompt = costumeTransformationPrompt
        self.costume = costume
        self.backgroundSetting = backgroundSetting
        self.costumes = costumes
        self.activeCostumeIndex = activeCostumeIndex
        self.imagePrompts = imagePrompts
        self.imageAnnotations = imageAnnotations
        self.overviewPortrait = overviewPortrait
        self.overviewHtml = overviewHtml
        self.traits = traits
        self.traitsLastCalibrated = traitsLastCalibrated
        self.traitsConfidenceScore = traitsConfidenceScore
        self.traitsDataSources = traitsDataSources
        self.traitsAiReasoning = traitsAiReasoning
        self.traitsAiRanges = traitsAiRanges
        self.fullName = fullName
        self.nickname = nickname
        self.occupation = occupation
        self.affiliation = affiliation
        self.backgroundStory = backgroundStory
        self.primaryGoal = primaryGoal
        self.secondaryGoal = secondaryGoal
        self.hiddenMotivation = hiddenMotivation
        self.primaryFear = primaryFear
        self.weakness = weakness
        self.flaw = flaw
        self.characterArcNotes = characterArcNotes
        self.relationships = relationships
        self.firstAppearanceSceneId = firstAppearanceSceneId
        self.lastAppearanceSceneId = lastAppearanceSceneId
        self.sceneAppearances = sceneAppearances
        self.totalDialogueLines = totalDialogueLines
        self.totalScreenTimeSeconds = totalScreenTimeSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    // MARK: - Default Traits
    public static func defaultTraits() -> [String: Double] {
        return [
            // EMOTIONAL (5 traits)
            "confidence": 50.0,
            "empathy": 50.0,
            "aggression": 50.0,
            "optimism": 50.0,
            "anxiety": 50.0,
            // INTELLECTUAL (5 traits)
            "intelligence": 50.0,
            "creativity": 50.0,
            "wisdom": 50.0,
            "curiosity": 50.0,
            "logic": 50.0,
            // SOCIAL (5 traits)
            "charisma": 50.0,
            "humor": 50.0,
            "manipulation": 50.0,
            "leadership": 50.0,
            "loyalty": 50.0,
            // MORAL (5 traits)
            "honesty": 50.0,
            "courage": 50.0,
            "compassion": 50.0,
            "justice": 50.0,
            "selflessness": 50.0,
            // PHYSICAL (5 traits)
            "strength": 50.0,
            "agility": 50.0,
            "stamina": 50.0,
            "coordination": 50.0,
            "reflexes": 50.0,
        ]
    }

    // MARK: - CodingKeys (CRITICAL: snake_case ↔ camelCase mapping)
    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case name, role, color
        case textColor = "text_color"
        case avatar, about, gender, voice
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case build, age
        case hairColor = "hair_color"
        case hairStyle = "hair_style"
        case hairLength = "hair_length"
        case eyeColor = "eye_color"
        case eyeColorDescription = "eye_color_description"
        case eyeShape = "eye_shape"
        case skinTone = "skin_tone"
        case ethnicity
        case distinguishingFeatures = "distinguishing_features"
        case facialStructure = "facial_structure"
        case baseImage = "base_image"
        case baseImagePrompt = "base_image_prompt"
        case imageFront = "image_front"
        case imageThreeQuarterLeft = "image_three_quarter_left"
        case imageThreeQuarterRight = "image_three_quarter_right"
        case imageProfileLeft = "image_profile_left"
        case imageProfileRight = "image_profile_right"
        case imageBackThreeQuarterLeft = "image_back_three_quarter_left"
        case imageBackThreeQuarterRight = "image_back_three_quarter_right"
        case imageBack = "image_back"
        case imageFaceCloseupFront = "image_face_closeup_front"
        case imageFaceCloseupThreeQuarter = "image_face_closeup_three_quarter"
        case imageFaceCloseupProfile = "image_face_closeup_profile"
        case imageActionPose = "image_action_pose"
        case faceImageFront = "face_image_front"
        case faceImageThreeQuarterLeft = "face_image_three_quarter_left"
        case faceImageThreeQuarterRight = "face_image_three_quarter_right"
        case faceImageProfile = "face_image_profile"
        case bodyImageFront = "body_image_front"
        case bodyImageThreeQuarterLeft = "body_image_three_quarter_left"
        case bodyImageThreeQuarterRight = "body_image_three_quarter_right"
        case bodyImageProfile = "body_image_profile"
        case costumeImageFront = "costume_image_front"
        case costumeImageThreeQuarterLeft = "costume_image_three_quarter_left"
        case costumeImageThreeQuarterRight = "costume_image_three_quarter_right"
        case costumeImageProfile = "costume_image_profile"
        case costumeTransformationPrompt = "costume_transformation_prompt"
        case costume
        case backgroundSetting = "background_setting"
        case costumes
        case activeCostumeIndex = "active_costume_index"
        case imagePrompts = "image_prompts"
        case imageAnnotations = "image_annotations"
        case overviewPortrait = "overview_portrait"
        case overviewHtml = "overview_html"
        case traits
        case traitsLastCalibrated = "traits_last_calibrated"
        case traitsConfidenceScore = "traits_confidence_score"
        case traitsDataSources = "traits_data_sources"
        case traitsAiReasoning = "traits_ai_reasoning"
        case traitsAiRanges = "traits_ai_ranges"
        case fullName = "full_name"
        case nickname, occupation, affiliation
        case backgroundStory = "background_story"
        case primaryGoal = "primary_goal"
        case secondaryGoal = "secondary_goal"
        case hiddenMotivation = "hidden_motivation"
        case primaryFear = "primary_fear"
        case weakness, flaw
        case characterArcNotes = "character_arc_notes"
        case relationships
        case firstAppearanceSceneId = "first_appearance_scene_id"
        case lastAppearanceSceneId = "last_appearance_scene_id"
        case sceneAppearances = "scene_appearances"
        case totalDialogueLines = "total_dialogue_lines"
        case totalScreenTimeSeconds = "total_screen_time_seconds"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case version
    }

    // MARK: - Custom Decoder

    /// Custom decoder to handle missing character_id and provide sensible defaults
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle character_id: if missing, generate from name
        let name = try container.decode(String.self, forKey: .name)
        self.characterId = try container.decodeIfPresent(String.self, forKey: .characterId)
            ?? name.replacingOccurrences(of: " ", with: "_").lowercased()

        // Basic information
        self.name = name
        self.role = try container.decodeIfPresent(String.self, forKey: .role) ?? "Supporting"
        self.color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#3498db"
        self.textColor = try container.decodeIfPresent(String.self, forKey: .textColor) ?? "#ffffff"
        self.avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        self.about = try container.decodeIfPresent(String.self, forKey: .about) ?? ""
        // Normalize gender to lowercase for consistency with UI picker
        let rawGender = try container.decodeIfPresent(String.self, forKey: .gender) ?? "neutral"
        self.gender = rawGender.lowercased()
        self.voice = try container.decodeIfPresent(String.self, forKey: .voice)

        // Physical appearance
        self.heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm)
        self.weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        self.build = try container.decodeIfPresent(String.self, forKey: .build) ?? "Average"

        // Handle age as either Int or String
        if let ageInt = try? container.decode(Int.self, forKey: .age) {
            self.age = ageInt
        } else if let ageString = try? container.decode(String.self, forKey: .age),
                  let ageInt = Int(ageString) {
            self.age = ageInt
        } else {
            self.age = 30
        }

        self.hairColor = try container.decodeIfPresent(String.self, forKey: .hairColor) ?? "#000000"
        self.hairStyle = try container.decodeIfPresent(String.self, forKey: .hairStyle) ?? "Short"
        self.hairLength = try container.decodeIfPresent(String.self, forKey: .hairLength) ?? "Short"

        self.eyeColor = try container.decodeIfPresent(String.self, forKey: .eyeColor) ?? "#8B4513"
        self.eyeColorDescription = try container.decodeIfPresent(String.self, forKey: .eyeColorDescription) ?? "Brown"
        self.eyeShape = try container.decodeIfPresent(String.self, forKey: .eyeShape) ?? "Almond"

        self.skinTone = try container.decodeIfPresent(String.self, forKey: .skinTone) ?? "#f5deb3"
        self.ethnicity = try container.decodeIfPresent(String.self, forKey: .ethnicity) ?? ""

        self.distinguishingFeatures = try container.decodeIfPresent(String.self, forKey: .distinguishingFeatures) ?? ""
        self.facialStructure = try container.decodeIfPresent(String.self, forKey: .facialStructure) ?? "Oval"

        // Images
        self.baseImage = try container.decodeIfPresent(String.self, forKey: .baseImage)
        self.baseImagePrompt = try container.decodeIfPresent(String.self, forKey: .baseImagePrompt)
        self.imageFront = try container.decodeIfPresent(String.self, forKey: .imageFront)
        self.imageThreeQuarterLeft = try container.decodeIfPresent(String.self, forKey: .imageThreeQuarterLeft)
        self.imageThreeQuarterRight = try container.decodeIfPresent(String.self, forKey: .imageThreeQuarterRight)
        self.imageProfileLeft = try container.decodeIfPresent(String.self, forKey: .imageProfileLeft)
        self.imageProfileRight = try container.decodeIfPresent(String.self, forKey: .imageProfileRight)
        self.imageBackThreeQuarterLeft = try container.decodeIfPresent(String.self, forKey: .imageBackThreeQuarterLeft)
        self.imageBackThreeQuarterRight = try container.decodeIfPresent(String.self, forKey: .imageBackThreeQuarterRight)
        self.imageBack = try container.decodeIfPresent(String.self, forKey: .imageBack)
        self.imageFaceCloseupFront = try container.decodeIfPresent(String.self, forKey: .imageFaceCloseupFront)
        self.imageFaceCloseupThreeQuarter = try container.decodeIfPresent(String.self, forKey: .imageFaceCloseupThreeQuarter)
        self.imageFaceCloseupProfile = try container.decodeIfPresent(String.self, forKey: .imageFaceCloseupProfile)
        self.imageActionPose = try container.decodeIfPresent(String.self, forKey: .imageActionPose)

        self.faceImageFront = try container.decodeIfPresent(String.self, forKey: .faceImageFront)
        self.faceImageThreeQuarterLeft = try container.decodeIfPresent(String.self, forKey: .faceImageThreeQuarterLeft)
        self.faceImageThreeQuarterRight = try container.decodeIfPresent(String.self, forKey: .faceImageThreeQuarterRight)
        self.faceImageProfile = try container.decodeIfPresent(String.self, forKey: .faceImageProfile)

        self.bodyImageFront = try container.decodeIfPresent(String.self, forKey: .bodyImageFront)
        self.bodyImageThreeQuarterLeft = try container.decodeIfPresent(String.self, forKey: .bodyImageThreeQuarterLeft)
        self.bodyImageThreeQuarterRight = try container.decodeIfPresent(String.self, forKey: .bodyImageThreeQuarterRight)
        self.bodyImageProfile = try container.decodeIfPresent(String.self, forKey: .bodyImageProfile)

        self.costumeImageFront = try container.decodeIfPresent(String.self, forKey: .costumeImageFront)
        self.costumeImageThreeQuarterLeft = try container.decodeIfPresent(String.self, forKey: .costumeImageThreeQuarterLeft)
        self.costumeImageThreeQuarterRight = try container.decodeIfPresent(String.self, forKey: .costumeImageThreeQuarterRight)
        self.costumeImageProfile = try container.decodeIfPresent(String.self, forKey: .costumeImageProfile)
        self.costumeTransformationPrompt = try container.decodeIfPresent(String.self, forKey: .costumeTransformationPrompt)

        self.costume = try container.decodeIfPresent(String.self, forKey: .costume)
        self.backgroundSetting = try container.decodeIfPresent(String.self, forKey: .backgroundSetting)
        self.costumes = try container.decodeIfPresent([CharacterCostume].self, forKey: .costumes)
        self.activeCostumeIndex = try container.decodeIfPresent(Int.self, forKey: .activeCostumeIndex)
        self.imagePrompts = try container.decodeIfPresent([String: String].self, forKey: .imagePrompts)
        self.imageAnnotations = try container.decodeIfPresent([String: [[String: String]]].self, forKey: .imageAnnotations)

        self.overviewPortrait = try container.decodeIfPresent(String.self, forKey: .overviewPortrait)
        self.overviewHtml = try container.decodeIfPresent(String.self, forKey: .overviewHtml)

        // Traits - handle both dictionary format and array of strings
        if let traitsDict = try? container.decode([String: Double].self, forKey: .traits) {
            self.traits = traitsDict
        } else if let traitsArray = try? container.decode([String].self, forKey: .traits) {
            // Convert array of trait names to dictionary with default values
            var traitsDict = Self.defaultTraits()
            // If traits are mentioned in array, give them higher values
            for traitName in traitsArray {
                if traitsDict.keys.contains(traitName) {
                    traitsDict[traitName] = 75.0
                }
            }
            self.traits = traitsDict
        } else {
            self.traits = Self.defaultTraits()
        }
        self.traitsLastCalibrated = try container.decodeIfPresent(Date.self, forKey: .traitsLastCalibrated)
        self.traitsConfidenceScore = try container.decodeIfPresent(Double.self, forKey: .traitsConfidenceScore)
        self.traitsDataSources = try container.decodeIfPresent([String].self, forKey: .traitsDataSources) ?? []
        self.traitsAiReasoning = try container.decodeIfPresent(String.self, forKey: .traitsAiReasoning)
        self.traitsAiRanges = try container.decodeIfPresent([String: [Double]].self, forKey: .traitsAiRanges)

        // Biography
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        self.nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        self.occupation = try container.decodeIfPresent(String.self, forKey: .occupation)
        self.affiliation = try container.decodeIfPresent(String.self, forKey: .affiliation)
        self.backgroundStory = try container.decodeIfPresent(String.self, forKey: .backgroundStory)
        self.primaryGoal = try container.decodeIfPresent(String.self, forKey: .primaryGoal)
        self.secondaryGoal = try container.decodeIfPresent(String.self, forKey: .secondaryGoal)
        self.hiddenMotivation = try container.decodeIfPresent(String.self, forKey: .hiddenMotivation)
        self.primaryFear = try container.decodeIfPresent(String.self, forKey: .primaryFear)
        self.weakness = try container.decodeIfPresent(String.self, forKey: .weakness)
        self.flaw = try container.decodeIfPresent(String.self, forKey: .flaw)
        self.characterArcNotes = try container.decodeIfPresent(String.self, forKey: .characterArcNotes)

        // Relationships - only decode if it's a dictionary, ignore if array
        self.relationships = try? container.decode([String: String].self, forKey: .relationships)

        // Story timeline
        self.firstAppearanceSceneId = try container.decodeIfPresent(String.self, forKey: .firstAppearanceSceneId)
        self.lastAppearanceSceneId = try container.decodeIfPresent(String.self, forKey: .lastAppearanceSceneId)
        self.sceneAppearances = try container.decodeIfPresent([String].self, forKey: .sceneAppearances)
        self.totalDialogueLines = try container.decodeIfPresent(Int.self, forKey: .totalDialogueLines)
        self.totalScreenTimeSeconds = try container.decodeIfPresent(Double.self, forKey: .totalScreenTimeSeconds)

        // Metadata
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version)
    }
}
