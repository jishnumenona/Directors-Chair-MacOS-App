// DirectorsChairServices/Sources/DirectorsChairServices/TimelineAnalysis/TimelineAnalysisResult.swift
//
// Data structures for AI timeline analysis results and change diffs

import Foundation
import DirectorsChairCore

// MARK: - Script Item Type

public enum ScriptItemType: String, Sendable, Codable {
    case dialogue
    case action
    case narration
}

// MARK: - Individual Change Types

/// A proposed change to an item's chronology number
public struct ChronologyChange: Identifiable, Sendable {
    public let id: String          // UUID of the dialogue/action/narration
    public let itemType: ScriptItemType
    public let label: String       // Human-readable label (e.g. "JOHN: Hello there")
    public let oldNumber: Int
    public let newNumber: Int

    public init(id: String, itemType: ScriptItemType, label: String, oldNumber: Int, newNumber: Int) {
        self.id = id
        self.itemType = itemType
        self.label = label
        self.oldNumber = oldNumber
        self.newNumber = newNumber
    }
}

/// A proposed change to a shot's linked script items
public struct ShotLinkChange: Identifiable, Sendable {
    public let id: UUID
    public let shotId: Int
    public let shotLabel: String   // e.g. "Shot 1 - Wide"
    public let addedDialogueIds: [String]
    public let removedDialogueIds: [String]
    public let addedActionIds: [String]
    public let removedActionIds: [String]
    public let addedNarrationIds: [String]
    public let removedNarrationIds: [String]

    public var totalChanges: Int {
        addedDialogueIds.count + removedDialogueIds.count +
        addedActionIds.count + removedActionIds.count +
        addedNarrationIds.count + removedNarrationIds.count
    }

    public init(
        shotId: Int,
        shotLabel: String,
        addedDialogueIds: [String] = [],
        removedDialogueIds: [String] = [],
        addedActionIds: [String] = [],
        removedActionIds: [String] = [],
        addedNarrationIds: [String] = [],
        removedNarrationIds: [String] = []
    ) {
        self.id = UUID()
        self.shotId = shotId
        self.shotLabel = shotLabel
        self.addedDialogueIds = addedDialogueIds
        self.removedDialogueIds = removedDialogueIds
        self.addedActionIds = addedActionIds
        self.removedActionIds = removedActionIds
        self.addedNarrationIds = addedNarrationIds
        self.removedNarrationIds = removedNarrationIds
    }
}

/// A proposed change to an item's parent dialogue grouping
public struct ParentChildChange: Identifiable, Sendable {
    public let id: String          // UUID of the action/narration
    public let itemType: ScriptItemType
    public let label: String
    public let oldParentDialogueId: String?
    public let newParentDialogueId: String?

    public init(id: String, itemType: ScriptItemType, label: String, oldParentDialogueId: String?, newParentDialogueId: String?) {
        self.id = id
        self.itemType = itemType
        self.label = label
        self.oldParentDialogueId = oldParentDialogueId
        self.newParentDialogueId = newParentDialogueId
    }
}

/// A proposed change to a shot's duration
public struct ShotDurationChange: Identifiable, Sendable {
    public let id: UUID
    public let shotId: Int
    public let shotLabel: String
    public let oldDuration: Double?
    public let newDuration: Double

    public init(shotId: Int, shotLabel: String, oldDuration: Double?, newDuration: Double) {
        self.id = UUID()
        self.shotId = shotId
        self.shotLabel = shotLabel
        self.oldDuration = oldDuration
        self.newDuration = newDuration
    }
}

// MARK: - Per-Scene Result

/// Analysis result for a single scene
public struct SceneAnalysisResult: Identifiable, Sendable {
    public let id: UUID
    public let sceneName: String
    public let sequenceIndex: Int
    public let sceneIndex: Int
    public let chronologyChanges: [ChronologyChange]
    public let shotLinkChanges: [ShotLinkChange]
    public let parentChildChanges: [ParentChildChange]
    public let shotDurationChanges: [ShotDurationChange]

    public var totalChanges: Int {
        chronologyChanges.count + shotLinkChanges.count +
        parentChildChanges.count + shotDurationChanges.count
    }

    public var hasChanges: Bool { totalChanges > 0 }

    public init(
        sceneName: String,
        sequenceIndex: Int,
        sceneIndex: Int,
        chronologyChanges: [ChronologyChange] = [],
        shotLinkChanges: [ShotLinkChange] = [],
        parentChildChanges: [ParentChildChange] = [],
        shotDurationChanges: [ShotDurationChange] = []
    ) {
        self.id = UUID()
        self.sceneName = sceneName
        self.sequenceIndex = sequenceIndex
        self.sceneIndex = sceneIndex
        self.chronologyChanges = chronologyChanges
        self.shotLinkChanges = shotLinkChanges
        self.parentChildChanges = parentChildChanges
        self.shotDurationChanges = shotDurationChanges
    }
}

// MARK: - Aggregated Result

/// Aggregated analysis result across all analyzed scenes
public struct TimelineAnalysisResult: Sendable {
    public let sceneResults: [SceneAnalysisResult]
    public let failedScenes: [(sceneName: String, error: String)]

    public var totalChanges: Int {
        sceneResults.reduce(0) { $0 + $1.totalChanges }
    }

    public var hasChanges: Bool { totalChanges > 0 }

    public var scenesWithChanges: [SceneAnalysisResult] {
        sceneResults.filter { $0.hasChanges }
    }

    public init(sceneResults: [SceneAnalysisResult] = [], failedScenes: [(sceneName: String, error: String)] = []) {
        self.sceneResults = sceneResults
        self.failedScenes = failedScenes
    }
}
