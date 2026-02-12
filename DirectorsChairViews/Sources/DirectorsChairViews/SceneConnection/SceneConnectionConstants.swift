// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/SceneConnectionConstants.swift
//
// Layout constants and styling for the Scene Connection View

import SwiftUI

// MARK: - Scene Connection Constants

public enum SceneConnectionConstants {
    // MARK: - Layout

    /// Width of the left script items column
    public static let scriptColumnWidth: CGFloat = 240

    /// Width of the right shots column
    public static let shotsColumnWidth: CGFloat = 280

    /// Minimum width for the center canvas
    public static let canvasMinWidth: CGFloat = 400

    /// Card padding
    public static let cardPadding: CGFloat = 12

    /// Spacing between cards in list
    public static let cardSpacing: CGFloat = 8

    /// Port diameter
    public static let portSize: CGFloat = 14

    /// Port hit area (for easier clicking)
    public static let portHitArea: CGFloat = 24

    // MARK: - Connection Lines

    /// Default connection line width
    public static let connectionLineWidth: CGFloat = 2

    /// Selected connection line width
    public static let connectionLineWidthSelected: CGFloat = 4

    /// Default connection opacity
    public static let connectionOpacity: Double = 0.7

    /// Hover/selected connection opacity
    public static let connectionOpacityHighlight: Double = 1.0

    /// Control point offset factor for bezier curves (0.0 - 1.0)
    public static let bezierControlFactor: CGFloat = 0.5

    /// Maximum control point offset
    public static let maxControlOffset: CGFloat = 100

    // MARK: - Animation

    /// Connection creation animation duration
    public static let connectionAnimationDuration: Double = 0.25

    /// Port hover animation duration
    public static let portHoverDuration: Double = 0.15
}

// MARK: - Colors

public enum SceneConnectionColors {
    // MARK: - Connection Type Colors

    /// Dialogue connection color
    public static let dialogue = Color(hex: "#4A90D9")

    /// Action connection color
    public static let action = Color(hex: "#FFB34D")

    /// Narration connection color
    public static let narration = Color(hex: "#4ECDC4")

    // MARK: - UI Colors

    /// Canvas background
    public static let canvasBackground = Color(hex: "#1E1E1E")

    /// Card background
    public static let cardBackground = Color(hex: "#262626")

    /// Card background when hovered
    public static let cardBackgroundHover = Color(hex: "#2E2E2E")

    /// Card background when selected
    public static let cardBackgroundSelected = Color(hex: "#333333")

    /// Port default color
    public static let portDefault = Color(hex: "#666666")

    /// Port hover color
    public static let portHover = Color.white

    /// Sidebar background
    public static let sidebarBackground = Color(hex: "#252525")

    /// Drag preview line color
    public static let dragPreviewLine = Color.white.opacity(0.5)
}

// MARK: - Script Item Type

public enum ScriptItemType: String, CaseIterable, Identifiable {
    case dialogue = "Dialogue"
    case action = "Action"
    case narration = "Narration"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .dialogue: return SceneConnectionColors.dialogue
        case .action: return SceneConnectionColors.action
        case .narration: return SceneConnectionColors.narration
        }
    }

    public var icon: String {
        switch self {
        case .dialogue: return "text.bubble"
        case .action: return "figure.walk"
        case .narration: return "quote.opening"
        }
    }

    public var label: String {
        rawValue
    }
}

// MARK: - Port Position Preference Key

public struct PortPositionKey: PreferenceKey {
    public static var defaultValue: [String: CGPoint] = [:]

    public static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Script Item (Unified wrapper for Dialogue/Action/Narration)

import DirectorsChairCore

public enum ScriptItem: Identifiable, Hashable {
    case dialogue(Dialogue)
    case action(Action)
    case narration(Narration)

    public var id: String {
        switch self {
        case .dialogue(let d): return d.uuid
        case .action(let a): return a.uuid
        case .narration(let n): return n.uuid
        }
    }

    public var chronologyNumber: Int {
        switch self {
        case .dialogue(let d): return d.chronologyNumber
        case .action(let a): return a.chronologyNumber
        case .narration(let n): return n.chronologyNumber
        }
    }

    public var displayText: String {
        switch self {
        case .dialogue(let d): return d.text
        case .action(let a): return a.description
        case .narration(let n): return n.text
        }
    }

    public var itemType: ScriptItemType {
        switch self {
        case .dialogue: return .dialogue
        case .action: return .action
        case .narration: return .narration
        }
    }

    public var subtitle: String? {
        switch self {
        case .dialogue(let d): return d.character
        case .action: return nil
        case .narration: return nil
        }
    }

    /// Parent dialogue ID (for actions/narrations that are sub-bubbles of a dialogue)
    public var parentDialogueId: String? {
        switch self {
        case .dialogue: return nil
        case .action(let a): return a.parentDialogueId
        case .narration(let n): return n.parentDialogueId
        }
    }

    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ScriptItem, rhs: ScriptItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Script Item Group (Dialogue + its child sub-bubbles)

public struct ScriptItemGroup: Identifiable, Hashable {
    public let dialogue: ScriptItem  // Must be .dialogue
    public let children: [ScriptItem]  // Actions/narrations with parentDialogueId matching this dialogue

    public var id: String { dialogue.id }

    public init(dialogue: ScriptItem, children: [ScriptItem]) {
        self.dialogue = dialogue
        self.children = children
    }
}

// MARK: - Script List Entry (grouped or standalone)

public enum ScriptListEntry: Identifiable {
    case group(ScriptItemGroup)
    case standalone(ScriptItem)

    public var id: String {
        switch self {
        case .group(let group): return "group-\(group.id)"
        case .standalone(let item): return "standalone-\(item.id)"
        }
    }

    /// The primary script item ID used for port connections
    public var primaryItemId: String {
        switch self {
        case .group(let group): return group.dialogue.id
        case .standalone(let item): return item.id
        }
    }
}

// MARK: - Connection Model

public struct ScriptConnection: Identifiable, Hashable {
    public let id: String
    public let scriptItemId: String
    public let shotId: String
    public let itemType: ScriptItemType

    public init(scriptItemId: String, shotId: String, itemType: ScriptItemType) {
        self.id = "\(scriptItemId)-\(shotId)"
        self.scriptItemId = scriptItemId
        self.shotId = shotId
        self.itemType = itemType
    }
}
