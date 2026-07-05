// DirectorsChairCore/Sources/DirectorsChairCore/Models/SupportCue.swift
//
// Support cue model for stagehand actions (prop moves, scene changes, costume changes, etc.)

import Foundation

// MARK: - Enums

public enum SupportActionType: String, Codable, CaseIterable, Hashable, Sendable {
    case propMove = "Prop Move"
    case sceneChange = "Scene Change"
    case costumeChange = "Costume Change"
    case curtain = "Curtain"
    case rigging = "Rigging"
    case cleaning = "Cleaning"
    case furnitureReset = "Furniture Reset"
    case setDressing = "Set Dressing"
    case quickChange = "Quick Change"
    case custom = "Custom"

    public var icon: String {
        switch self {
        case .propMove: return "shippingbox"
        case .sceneChange: return "rectangle.2.swap"
        case .costumeChange: return "tshirt"
        case .curtain: return "curtains.closed"
        case .rigging: return "link"
        case .cleaning: return "sparkles"
        case .furnitureReset: return "chair.lounge"
        case .setDressing: return "paintbrush"
        case .quickChange: return "bolt.fill"
        case .custom: return "wrench"
        }
    }

    public var tooltip: String {
        switch self {
        case .propMove: return "Move props on or off stage between scenes or during blackouts"
        case .sceneChange: return "Full scene transition — swap backdrops, flats, or set pieces"
        case .costumeChange: return "Assist actor with costume change backstage"
        case .curtain: return "Operate main curtain, traveller, or cyc drops"
        case .rigging: return "Fly in/out scenery, drops, or equipment from the fly loft"
        case .cleaning: return "Stage cleaning or reset between scenes"
        case .furnitureReset: return "Rearrange furniture or large set pieces on stage"
        case .setDressing: return "Adjust decorative elements, tablecloths, flowers, etc."
        case .quickChange: return "Rapid costume/makeup change requiring multiple crew"
        case .custom: return "Custom support action — describe in the notes field"
        }
    }
}

public enum SupportPriority: String, Codable, CaseIterable, Hashable, Sendable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    public var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "circle.fill"
        case .low: return "circle"
        }
    }
}

public enum SupportStageArea: String, Codable, CaseIterable, Hashable, Sendable {
    case stageLeft = "Stage Left"
    case stageRight = "Stage Right"
    case centerStage = "Center Stage"
    case upstage = "Upstage"
    case downstage = "Downstage"
    case backstage = "Backstage"
    case wings = "Wings"
    case flyLoft = "Fly Loft"
    case orchestra = "Orchestra"
    case custom = "Custom"

    public var icon: String {
        switch self {
        case .stageLeft: return "arrow.left"
        case .stageRight: return "arrow.right"
        case .centerStage: return "circle.fill"
        case .upstage: return "arrow.up"
        case .downstage: return "arrow.down"
        case .backstage: return "arrow.uturn.backward"
        case .wings: return "arrow.left.and.right"
        case .flyLoft: return "arrow.up.to.line"
        case .orchestra: return "music.note"
        case .custom: return "mappin.and.ellipse"
        }
    }
}

// MARK: - SupportCue Model

public struct SupportCue: Codable, Identifiable, Hashable, Sendable {
    public var id: String

    // Identity
    public var name: String
    public var cueNumber: String
    public var actionType: SupportActionType

    // Timeline
    public var startTime: Double
    public var duration: Double

    // Assignment
    public var priority: SupportPriority
    public var stageArea: SupportStageArea
    public var assignedTo: String
    public var equipment: String

    // Safety & Notes
    public var notes: String
    public var safetyNotes: String
    public var markerColor: String
    public var isActive: Bool
    public var linkedCueIds: [String]

    public init(
        id: String = UUID().uuidString,
        name: String = "New Support Cue",
        cueNumber: String = "S1",
        actionType: SupportActionType = .propMove,
        startTime: Double = 0,
        duration: Double = 5.0,
        priority: SupportPriority = .medium,
        stageArea: SupportStageArea = .backstage,
        assignedTo: String = "",
        equipment: String = "",
        notes: String = "",
        safetyNotes: String = "",
        markerColor: String = "#2DD4BF",
        isActive: Bool = true,
        linkedCueIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.cueNumber = cueNumber
        self.actionType = actionType
        self.startTime = startTime
        self.duration = duration
        self.priority = priority
        self.stageArea = stageArea
        self.assignedTo = assignedTo
        self.equipment = equipment
        self.notes = notes
        self.safetyNotes = safetyNotes
        self.markerColor = markerColor
        self.isActive = isActive
        self.linkedCueIds = linkedCueIds
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cueNumber = "cue_number"
        case actionType = "action_type"
        case startTime = "start_time"
        case duration
        case priority
        case stageArea = "stage_area"
        case assignedTo = "assigned_to"
        case equipment
        case notes
        case safetyNotes = "safety_notes"
        case markerColor = "marker_color"
        case isActive = "is_active"
        case linkedCueIds = "linked_cue_ids"
    }

    // MARK: - Custom Decoder

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New Support Cue"
        cueNumber = try container.decodeIfPresent(String.self, forKey: .cueNumber) ?? "S1"
        actionType = try container.decodeIfPresent(SupportActionType.self, forKey: .actionType) ?? .propMove
        startTime = try container.decodeIfPresent(Double.self, forKey: .startTime) ?? 0
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 5.0
        priority = try container.decodeIfPresent(SupportPriority.self, forKey: .priority) ?? .medium
        stageArea = try container.decodeIfPresent(SupportStageArea.self, forKey: .stageArea) ?? .backstage
        assignedTo = try container.decodeIfPresent(String.self, forKey: .assignedTo) ?? ""
        equipment = try container.decodeIfPresent(String.self, forKey: .equipment) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        safetyNotes = try container.decodeIfPresent(String.self, forKey: .safetyNotes) ?? ""
        markerColor = try container.decodeIfPresent(String.self, forKey: .markerColor) ?? "#2DD4BF"
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        linkedCueIds = try container.decodeIfPresent([String].self, forKey: .linkedCueIds) ?? []
    }
}
