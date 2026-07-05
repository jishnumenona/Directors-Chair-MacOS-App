// DirectorsChairCore/Sources/DirectorsChairCore/Models/SFXCue.swift
//
// Special effects cue model for SFX choreography (smoke, holograms, pyrotechnics, etc.)

import Foundation

// MARK: - Enums

public enum SFXEffectType: String, Codable, CaseIterable, Hashable, Sendable {
    case smoke = "Smoke"
    case hologram = "Hologram"
    case pyrotechnics = "Pyrotechnics"
    case rain = "Rain"
    case snow = "Snow"
    case wind = "Wind"
    case confetti = "Confetti"
    case laser = "Laser"
    case projection = "Projection"
    case strobe = "Strobe"
    case bubbles = "Bubbles"
    case custom = "Custom"

    public var icon: String {
        switch self {
        case .smoke: return "cloud.fill"
        case .hologram: return "circle.hexagongrid"
        case .pyrotechnics: return "flame"
        case .rain: return "cloud.rain"
        case .snow: return "snowflake"
        case .wind: return "wind"
        case .confetti: return "party.popper"
        case .laser: return "light.max"
        case .projection: return "tv"
        case .strobe: return "bolt"
        case .bubbles: return "bubble.left.and.bubble.right"
        case .custom: return "sparkles"
        }
    }

    public var tooltip: String {
        switch self {
        case .smoke: return "Atmospheric haze or directed smoke jets for mood and depth"
        case .hologram: return "Holographic or Pepper's ghost projection effects"
        case .pyrotechnics: return "Controlled fire, sparks, flash pots, or explosive effects"
        case .rain: return "Artificial rain from overhead rigging or sprinkler systems"
        case .snow: return "Falling snow effect using foam, paper, or machine-generated flakes"
        case .wind: return "Directional air movement from fans or wind machines"
        case .confetti: return "Paper, metallic, or biodegradable confetti cannons or drops"
        case .laser: return "Laser beams, patterns, or laser harp effects"
        case .projection: return "Video projection mapping onto surfaces or scrims"
        case .strobe: return "Rapid flash effects for freeze-frame or disorientation"
        case .bubbles: return "Soap bubble machines for whimsical or underwater effects"
        case .custom: return "Custom effect type — describe in the notes field"
        }
    }
}

public enum SFXIntensityProfile: String, Codable, CaseIterable, Hashable, Sendable {
    case constant = "Constant"
    case rampUp = "Ramp Up"
    case rampDown = "Ramp Down"
    case pulse = "Pulse"
    case burst = "Burst"
    case wave = "Wave"

    public var icon: String {
        switch self {
        case .constant: return "minus"
        case .rampUp: return "chart.line.uptrend.xyaxis"
        case .rampDown: return "chart.line.downtrend.xyaxis"
        case .pulse: return "waveform.path.ecg"
        case .burst: return "bolt.fill"
        case .wave: return "water.waves"
        }
    }
}

public enum SFXTransition: String, Codable, CaseIterable, Hashable, Sendable {
    case cut = "Cut"
    case fadeIn = "Fade In"
    case fadeOut = "Fade Out"
    case crossfade = "Crossfade"
    case burst = "Burst"
    case gradual = "Gradual"

    public var icon: String {
        switch self {
        case .cut: return "scissors"
        case .fadeIn: return "circle.lefthalf.filled"
        case .fadeOut: return "circle.righthalf.filled"
        case .crossfade: return "arrow.left.arrow.right"
        case .burst: return "bolt.fill"
        case .gradual: return "chart.line.uptrend.xyaxis"
        }
    }
}

public enum SFXPlacement: String, Codable, CaseIterable, Hashable, Sendable {
    case fullStage = "Full Stage"
    case centerStage = "Center Stage"
    case stageLeft = "Stage Left"
    case stageRight = "Stage Right"
    case overhead = "Overhead"
    case floor = "Floor"
    case background = "Background"
    case foreground = "Foreground"
    case custom = "Custom"

    public var icon: String {
        switch self {
        case .fullStage: return "rectangle.fill"
        case .centerStage: return "circle.fill"
        case .stageLeft: return "arrow.left"
        case .stageRight: return "arrow.right"
        case .overhead: return "arrow.down"
        case .floor: return "arrow.up"
        case .background: return "rectangle.inset.filled"
        case .foreground: return "rectangle"
        case .custom: return "mappin.and.ellipse"
        }
    }
}

// MARK: - SFXCue Model

public struct SFXCue: Codable, Identifiable, Hashable, Sendable {
    public var id: String

    // Identity
    public var name: String
    public var cueNumber: String
    public var effectType: SFXEffectType

    // Timeline
    public var startTime: Double
    public var duration: Double

    // Effect parameters
    public var intensity: Double
    public var intensityEnd: Double?
    public var intensityProfile: SFXIntensityProfile
    public var color: String
    public var markerColor: String

    // Placement
    public var placement: SFXPlacement
    public var coverage: Double  // 0.0 to 1.0

    // Transitions
    public var transitionIn: SFXTransition
    public var transitionOut: SFXTransition
    public var fadeInDuration: Double
    public var fadeOutDuration: Double

    // Safety
    public var requiresVentilation: Bool
    public var safetyNotes: String
    public var operatorRequired: Bool

    // Metadata
    public var notes: String
    public var isActive: Bool
    public var linkedCueIds: [String]

    public init(
        id: String = UUID().uuidString,
        name: String = "New SFX Cue",
        cueNumber: String = "FX1",
        effectType: SFXEffectType = .smoke,
        startTime: Double = 0,
        duration: Double = 5.0,
        intensity: Double = 0.8,
        intensityEnd: Double? = nil,
        intensityProfile: SFXIntensityProfile = .constant,
        color: String = "#FF6B35",
        markerColor: String = "#FF6B35",
        placement: SFXPlacement = .fullStage,
        coverage: Double = 1.0,
        transitionIn: SFXTransition = .fadeIn,
        transitionOut: SFXTransition = .fadeOut,
        fadeInDuration: Double = 1.0,
        fadeOutDuration: Double = 1.0,
        requiresVentilation: Bool = false,
        safetyNotes: String = "",
        operatorRequired: Bool = false,
        notes: String = "",
        isActive: Bool = true,
        linkedCueIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.cueNumber = cueNumber
        self.effectType = effectType
        self.startTime = startTime
        self.duration = duration
        self.intensity = intensity
        self.intensityEnd = intensityEnd
        self.intensityProfile = intensityProfile
        self.color = color
        self.markerColor = markerColor
        self.placement = placement
        self.coverage = coverage
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.requiresVentilation = requiresVentilation
        self.safetyNotes = safetyNotes
        self.operatorRequired = operatorRequired
        self.notes = notes
        self.isActive = isActive
        self.linkedCueIds = linkedCueIds
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cueNumber = "cue_number"
        case effectType = "effect_type"
        case startTime = "start_time"
        case duration
        case intensity
        case intensityEnd = "intensity_end"
        case intensityProfile = "intensity_profile"
        case color
        case markerColor = "marker_color"
        case placement
        case coverage
        case transitionIn = "transition_in"
        case transitionOut = "transition_out"
        case fadeInDuration = "fade_in_duration"
        case fadeOutDuration = "fade_out_duration"
        case requiresVentilation = "requires_ventilation"
        case safetyNotes = "safety_notes"
        case operatorRequired = "operator_required"
        case notes
        case isActive = "is_active"
        case linkedCueIds = "linked_cue_ids"
    }

    // MARK: - Custom Decoder

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New SFX Cue"
        cueNumber = try container.decodeIfPresent(String.self, forKey: .cueNumber) ?? "FX1"
        effectType = try container.decodeIfPresent(SFXEffectType.self, forKey: .effectType) ?? .smoke
        startTime = try container.decodeIfPresent(Double.self, forKey: .startTime) ?? 0
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 5.0
        intensity = try container.decodeIfPresent(Double.self, forKey: .intensity) ?? 0.8
        intensityEnd = try container.decodeIfPresent(Double.self, forKey: .intensityEnd)
        intensityProfile = try container.decodeIfPresent(SFXIntensityProfile.self, forKey: .intensityProfile) ?? .constant
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#FF6B35"
        markerColor = try container.decodeIfPresent(String.self, forKey: .markerColor) ?? "#FF6B35"
        placement = try container.decodeIfPresent(SFXPlacement.self, forKey: .placement) ?? .fullStage
        coverage = try container.decodeIfPresent(Double.self, forKey: .coverage) ?? 1.0
        transitionIn = try container.decodeIfPresent(SFXTransition.self, forKey: .transitionIn) ?? .fadeIn
        transitionOut = try container.decodeIfPresent(SFXTransition.self, forKey: .transitionOut) ?? .fadeOut
        fadeInDuration = try container.decodeIfPresent(Double.self, forKey: .fadeInDuration) ?? 1.0
        fadeOutDuration = try container.decodeIfPresent(Double.self, forKey: .fadeOutDuration) ?? 1.0
        requiresVentilation = try container.decodeIfPresent(Bool.self, forKey: .requiresVentilation) ?? false
        safetyNotes = try container.decodeIfPresent(String.self, forKey: .safetyNotes) ?? ""
        operatorRequired = try container.decodeIfPresent(Bool.self, forKey: .operatorRequired) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        linkedCueIds = try container.decodeIfPresent([String].self, forKey: .linkedCueIds) ?? []
    }
}
