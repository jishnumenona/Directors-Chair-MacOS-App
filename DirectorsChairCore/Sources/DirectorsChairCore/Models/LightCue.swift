// DirectorsChairCore/Sources/DirectorsChairCore/Models/LightCue.swift
//
// Light cue model for cinema and theater lighting choreography

import Foundation

// MARK: - Enums

public enum LightingWorkflow: String, Codable, CaseIterable, Hashable, Sendable {
    case cinema = "Cinema"
    case theater = "Theater"
}

public enum LightFixtureType: String, Codable, CaseIterable, Hashable, Sendable {
    // Cinema
    case keyLight = "Key Light"
    case fillLight = "Fill Light"
    case backLight = "Back Light"
    case practical = "Practical"
    case bounce = "Bounce"
    case kicker = "Kicker"
    // Theater
    case fresnel = "Fresnel"
    case ellipsoidal = "Ellipsoidal"
    case par = "PAR"
    case ledPanel = "LED Panel"
    case followSpot = "Follow Spot"
    case cyc = "Cyclorama"
    case gobo = "Gobo"
    case movingHead = "Moving Head"
    // Common
    case spot = "Spot"
    case flood = "Flood"
    case custom = "Custom"

    public var icon: String {
        switch self {
        case .keyLight: return "light.max"
        case .fillLight: return "light.min"
        case .backLight: return "light.beacon.max"
        case .practical: return "lamp.desk"
        case .bounce: return "arrow.triangle.2.circlepath"
        case .kicker: return "bolt.fill"
        case .fresnel: return "circle.dotted"
        case .ellipsoidal: return "scope"
        case .par: return "circle.fill"
        case .ledPanel: return "rectangle.split.3x3"
        case .followSpot: return "figure.walk"
        case .cyc: return "rectangle.fill"
        case .gobo: return "circle.hexagongrid"
        case .movingHead: return "arrow.triangle.turn.up.right.diamond"
        case .spot: return "flashlight.on.fill"
        case .flood: return "sun.max.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    public var tooltip: String {
        switch self {
        case .keyLight: return "Primary light source illuminating the subject — sets the overall exposure and mood"
        case .fillLight: return "Softer secondary light that reduces shadows cast by the key light"
        case .backLight: return "Light from behind the subject creating rim/edge separation from the background"
        case .practical: return "On-screen light sources (lamps, candles, TVs) visible in the frame"
        case .bounce: return "Reflected light off a white/silver surface for soft, natural fill"
        case .kicker: return "Accent light from behind at an angle — adds edge highlight and dimension"
        case .fresnel: return "Soft-edged spotlight with adjustable beam — workhorse of theater lighting"
        case .ellipsoidal: return "Sharp-edged profile spot (ERS/Leko) — precise beam shaping with shutters and gobos"
        case .par: return "Parabolic reflector can — punchy, wide wash of light, great for color washes"
        case .ledPanel: return "Multi-color LED array — tunable color temperature, energy efficient, low heat"
        case .followSpot: return "Manually operated spotlight that tracks performers across the stage"
        case .cyc: return "Wide flood that washes the cyclorama backdrop — creates sky/horizon effects"
        case .gobo: return "Projects patterns or images via a metal/glass template in an ellipsoidal fixture"
        case .movingHead: return "Motorized fixture with pan/tilt — programmable position, color, and beam effects"
        case .spot: return "Focused beam of light — illuminates a specific area or subject"
        case .flood: return "Wide, even wash of light — covers large areas without hard edges"
        case .custom: return "Custom fixture type — describe in the notes field"
        }
    }
}

public enum LightMotivation: String, Codable, CaseIterable, Hashable, Sendable {
    case window = "Window"
    case lamp = "Lamp"
    case fire = "Fire/Candle"
    case moonlight = "Moonlight"
    case sunlight = "Sunlight"
    case neon = "Neon Sign"
    case screen = "Screen/TV"
    case streetLight = "Street Light"
    case natural = "Natural Ambient"
    case none = "Unmotivated"

    public var icon: String {
        switch self {
        case .window: return "window.horizontal"
        case .lamp: return "lamp.desk"
        case .fire: return "flame"
        case .moonlight: return "moon.fill"
        case .sunlight: return "sun.max.fill"
        case .neon: return "textformat"
        case .screen: return "tv"
        case .streetLight: return "light.cylindrical.ceiling"
        case .natural: return "leaf"
        case .none: return "questionmark.circle"
        }
    }
}

public enum LightTransition: String, Codable, CaseIterable, Hashable, Sendable {
    case cut = "Cut"
    case fadeIn = "Fade In"
    case fadeOut = "Fade Out"
    case crossfade = "Crossfade"
    case snap = "Snap"
    case bump = "Bump"
    case slow = "Slow Build"

    public var icon: String {
        switch self {
        case .cut: return "scissors"
        case .fadeIn: return "circle.lefthalf.filled"
        case .fadeOut: return "circle.righthalf.filled"
        case .crossfade: return "arrow.left.arrow.right"
        case .snap: return "bolt.fill"
        case .bump: return "waveform.path.ecg"
        case .slow: return "chart.line.uptrend.xyaxis"
        }
    }
}

public enum LightPosition: String, Codable, CaseIterable, Hashable, Sendable {
    case frontHigh = "Front High"
    case frontLow = "Front Low"
    case sideLeft = "Side Left"
    case sideRight = "Side Right"
    case backHigh = "Back High"
    case backLow = "Back Low"
    case overhead = "Overhead"
    case floor = "Floor/Up"
    case followSpotBooth = "Follow Spot Booth"
    case custom = "Custom"

    public var icon: String {
        switch self {
        case .frontHigh: return "arrow.down.backward"
        case .frontLow: return "arrow.up.backward"
        case .sideLeft: return "arrow.left"
        case .sideRight: return "arrow.right"
        case .backHigh: return "arrow.down.forward"
        case .backLow: return "arrow.up.forward"
        case .overhead: return "arrow.down"
        case .floor: return "arrow.up"
        case .followSpotBooth: return "figure.walk"
        case .custom: return "mappin.and.ellipse"
        }
    }
}

// MARK: - LightCue Model

public struct LightCue: Codable, Identifiable, Hashable, Sendable {
    public var id: String

    // Identity
    public var name: String
    public var cueNumber: String
    public var workflow: LightingWorkflow
    public var fixtureType: LightFixtureType

    // Timeline
    public var startTime: Double
    public var duration: Double
    public var sceneId: String?
    public var sceneName: String?

    // Lighting params
    public var intensity: Double
    public var intensityEnd: Double?
    public var color: String
    public var colorTemperature: Int?
    public var gelFilter: String?

    // Position
    public var position: LightPosition
    public var positionCustom: String?
    public var angle: Double?
    public var elevation: Double?

    // Transitions
    public var transitionIn: LightTransition
    public var transitionOut: LightTransition
    public var fadeInDuration: Double
    public var fadeOutDuration: Double

    // Cinema-specific
    public var motivation: LightMotivation
    public var diffusion: String?
    public var flagsAndCutters: String?

    // Theater-specific
    public var dmxChannel: Int?
    public var dmxUniverse: Int?
    public var goboPattern: String?
    public var goboRotation: Double?
    public var followSpotOperator: String?
    public var focusTarget: String?

    // Metadata
    public var notes: String
    public var sortOrder: Int
    public var markerColor: String
    public var isActive: Bool
    public var linkedCueIds: [String]

    public init(
        id: String = UUID().uuidString,
        name: String = "New Light Cue",
        cueNumber: String = "Q1",
        workflow: LightingWorkflow = .cinema,
        fixtureType: LightFixtureType = .keyLight,
        startTime: Double = 0,
        duration: Double = 5.0,
        sceneId: String? = nil,
        sceneName: String? = nil,
        intensity: Double = 1.0,
        intensityEnd: Double? = nil,
        color: String = "#FFFAF0",
        colorTemperature: Int? = 5600,
        gelFilter: String? = nil,
        position: LightPosition = .frontHigh,
        positionCustom: String? = nil,
        angle: Double? = 45,
        elevation: Double? = 30,
        transitionIn: LightTransition = .cut,
        transitionOut: LightTransition = .cut,
        fadeInDuration: Double = 0,
        fadeOutDuration: Double = 0,
        motivation: LightMotivation = .none,
        diffusion: String? = nil,
        flagsAndCutters: String? = nil,
        dmxChannel: Int? = nil,
        dmxUniverse: Int? = nil,
        goboPattern: String? = nil,
        goboRotation: Double? = nil,
        followSpotOperator: String? = nil,
        focusTarget: String? = nil,
        notes: String = "",
        sortOrder: Int = 0,
        markerColor: String = "#FFD60A",
        isActive: Bool = true,
        linkedCueIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.cueNumber = cueNumber
        self.workflow = workflow
        self.fixtureType = fixtureType
        self.startTime = startTime
        self.duration = duration
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.intensity = intensity
        self.intensityEnd = intensityEnd
        self.color = color
        self.colorTemperature = colorTemperature
        self.gelFilter = gelFilter
        self.position = position
        self.positionCustom = positionCustom
        self.angle = angle
        self.elevation = elevation
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.motivation = motivation
        self.diffusion = diffusion
        self.flagsAndCutters = flagsAndCutters
        self.dmxChannel = dmxChannel
        self.dmxUniverse = dmxUniverse
        self.goboPattern = goboPattern
        self.goboRotation = goboRotation
        self.followSpotOperator = followSpotOperator
        self.focusTarget = focusTarget
        self.notes = notes
        self.sortOrder = sortOrder
        self.markerColor = markerColor
        self.isActive = isActive
        self.linkedCueIds = linkedCueIds
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cueNumber = "cue_number"
        case workflow
        case fixtureType = "fixture_type"
        case startTime = "start_time"
        case duration
        case sceneId = "scene_id"
        case sceneName = "scene_name"
        case intensity
        case intensityEnd = "intensity_end"
        case color
        case colorTemperature = "color_temperature"
        case gelFilter = "gel_filter"
        case position
        case positionCustom = "position_custom"
        case angle
        case elevation
        case transitionIn = "transition_in"
        case transitionOut = "transition_out"
        case fadeInDuration = "fade_in_duration"
        case fadeOutDuration = "fade_out_duration"
        case motivation
        case diffusion
        case flagsAndCutters = "flags_and_cutters"
        case dmxChannel = "dmx_channel"
        case dmxUniverse = "dmx_universe"
        case goboPattern = "gobo_pattern"
        case goboRotation = "gobo_rotation"
        case followSpotOperator = "follow_spot_operator"
        case focusTarget = "focus_target"
        case notes
        case sortOrder = "sort_order"
        case markerColor = "marker_color"
        case isActive = "is_active"
        case linkedCueIds = "linked_cue_ids"
    }

    // MARK: - Custom Decoder

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New Light Cue"
        cueNumber = try container.decodeIfPresent(String.self, forKey: .cueNumber) ?? "Q1"
        workflow = try container.decodeIfPresent(LightingWorkflow.self, forKey: .workflow) ?? .cinema
        fixtureType = try container.decodeIfPresent(LightFixtureType.self, forKey: .fixtureType) ?? .keyLight
        startTime = try container.decodeIfPresent(Double.self, forKey: .startTime) ?? 0
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 5.0
        sceneId = try container.decodeIfPresent(String.self, forKey: .sceneId)
        sceneName = try container.decodeIfPresent(String.self, forKey: .sceneName)
        intensity = try container.decodeIfPresent(Double.self, forKey: .intensity) ?? 1.0
        intensityEnd = try container.decodeIfPresent(Double.self, forKey: .intensityEnd)
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#FFFAF0"
        colorTemperature = try container.decodeIfPresent(Int.self, forKey: .colorTemperature)
        gelFilter = try container.decodeIfPresent(String.self, forKey: .gelFilter)
        position = try container.decodeIfPresent(LightPosition.self, forKey: .position) ?? .frontHigh
        positionCustom = try container.decodeIfPresent(String.self, forKey: .positionCustom)
        angle = try container.decodeIfPresent(Double.self, forKey: .angle)
        elevation = try container.decodeIfPresent(Double.self, forKey: .elevation)
        transitionIn = try container.decodeIfPresent(LightTransition.self, forKey: .transitionIn) ?? .cut
        transitionOut = try container.decodeIfPresent(LightTransition.self, forKey: .transitionOut) ?? .cut
        fadeInDuration = try container.decodeIfPresent(Double.self, forKey: .fadeInDuration) ?? 0
        fadeOutDuration = try container.decodeIfPresent(Double.self, forKey: .fadeOutDuration) ?? 0
        motivation = try container.decodeIfPresent(LightMotivation.self, forKey: .motivation) ?? .none
        diffusion = try container.decodeIfPresent(String.self, forKey: .diffusion)
        flagsAndCutters = try container.decodeIfPresent(String.self, forKey: .flagsAndCutters)
        dmxChannel = try container.decodeIfPresent(Int.self, forKey: .dmxChannel)
        dmxUniverse = try container.decodeIfPresent(Int.self, forKey: .dmxUniverse)
        goboPattern = try container.decodeIfPresent(String.self, forKey: .goboPattern)
        goboRotation = try container.decodeIfPresent(Double.self, forKey: .goboRotation)
        followSpotOperator = try container.decodeIfPresent(String.self, forKey: .followSpotOperator)
        focusTarget = try container.decodeIfPresent(String.self, forKey: .focusTarget)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        markerColor = try container.decodeIfPresent(String.self, forKey: .markerColor) ?? "#FFD60A"
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        linkedCueIds = try container.decodeIfPresent([String].self, forKey: .linkedCueIds) ?? []
    }
}
