// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/SceneConnectionViewModel.swift
//
// State management for the Scene Connection View

import SwiftUI
import DirectorsChairCore
import Combine

// MARK: - Scene Connection ViewModel

@MainActor
public class SceneConnectionViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All script items (dialogues, actions, narrations) sorted by chronology
    @Published public var scriptItems: [ScriptItem] = []

    /// All shots sorted by shot ID
    @Published public var shots: [Shot] = []

    /// Currently selected script item ID
    @Published public var selectedScriptItemId: String?

    /// Currently selected shot ID
    @Published public var selectedShotId: String?

    /// Currently selected connection
    @Published public var selectedConnection: ScriptConnection?

    /// Filter toggles for item types
    @Published public var showDialogues: Bool = true
    @Published public var showActions: Bool = true
    @Published public var showNarrations: Bool = true

    /// Drag state for connection creation
    @Published public var isDragging: Bool = false
    @Published public var dragSourceId: String?
    @Published public var dragSourceType: ScriptItemType?
    @Published public var dragCurrentPosition: CGPoint = .zero

    /// Port positions (updated via PreferenceKey)
    @Published public var portPositions: [String: CGPoint] = [:]

    // MARK: - Callbacks

    /// Callback when shots change (for persistence)
    public var onShotsChanged: (([Shot]) -> Void)?

    // MARK: - Computed Properties

    /// Filtered script items based on type toggles
    public var filteredScriptItems: [ScriptItem] {
        scriptItems.filter { item in
            switch item.itemType {
            case .dialogue: return showDialogues
            case .action: return showActions
            case .narration: return showNarrations
            }
        }
    }

    /// Grouped script entries: dialogues with their child sub-bubbles, and standalone items
    public var groupedScriptEntries: [ScriptListEntry] {
        let filtered = filteredScriptItems

        // Collect IDs of all dialogues present in filtered list
        let dialogueIds = Set(filtered.compactMap { item -> String? in
            if case .dialogue = item { return item.id }
            return nil
        })

        // Build a map of dialogueId -> [child items]
        var childrenMap: [String: [ScriptItem]] = [:]
        var standaloneItems: [ScriptItem] = []
        var dialogueItems: [ScriptItem] = []

        for item in filtered {
            if case .dialogue = item {
                dialogueItems.append(item)
            } else if let parentId = item.parentDialogueId, dialogueIds.contains(parentId) {
                childrenMap[parentId, default: []].append(item)
            } else {
                standaloneItems.append(item)
            }
        }

        // Build entries sorted by chronology
        var entries: [ScriptListEntry] = []

        for dialogue in dialogueItems {
            let children = (childrenMap[dialogue.id] ?? []).sorted { $0.chronologyNumber < $1.chronologyNumber }
            if children.isEmpty {
                entries.append(.standalone(dialogue))
            } else {
                entries.append(.group(ScriptItemGroup(dialogue: dialogue, children: children)))
            }
        }

        for item in standaloneItems {
            entries.append(.standalone(item))
        }

        // Sort all entries by primary chronology number
        entries.sort { a, b in
            let chronA: Int
            let chronB: Int
            switch a {
            case .group(let g): chronA = g.dialogue.chronologyNumber
            case .standalone(let i): chronA = i.chronologyNumber
            }
            switch b {
            case .group(let g): chronB = g.dialogue.chronologyNumber
            case .standalone(let i): chronB = i.chronologyNumber
            }
            return chronA < chronB
        }

        return entries
    }

    /// Get child items for a given dialogue ID
    public func childItems(forDialogueId dialogueId: String) -> [ScriptItem] {
        scriptItems.filter { $0.parentDialogueId == dialogueId }
            .sorted { $0.chronologyNumber < $1.chronologyNumber }
    }

    /// All connections derived from shots
    public var connections: [ScriptConnection] {
        var result: [ScriptConnection] = []

        for shot in shots {
            // Dialogue connections
            for dialogueId in shot.linkedDialogueIds {
                result.append(ScriptConnection(
                    scriptItemId: dialogueId,
                    shotId: shot.id,
                    itemType: .dialogue
                ))
            }

            // Action connections
            for actionId in shot.linkedActionIds {
                result.append(ScriptConnection(
                    scriptItemId: actionId,
                    shotId: shot.id,
                    itemType: .action
                ))
            }

            // Narration connections
            for narrationId in shot.linkedNarrationIds {
                result.append(ScriptConnection(
                    scriptItemId: narrationId,
                    shotId: shot.id,
                    itemType: .narration
                ))
            }
        }

        return result
    }

    /// Get connected shot IDs for a script item
    public func connectedShotIds(for scriptItemId: String) -> Set<String> {
        Set(connections.filter { $0.scriptItemId == scriptItemId }.map { $0.shotId })
    }

    /// Check if a shot is connected to the currently selected script item
    public func isShotConnectedToSelectedItem(_ shotId: String) -> Bool {
        guard let selectedId = selectedScriptItemId else { return false }
        return connections.contains { $0.scriptItemId == selectedId && $0.shotId == shotId }
    }

    /// Get connection counts for a shot
    public func connectionCounts(for shotId: String) -> (dialogues: Int, actions: Int, narrations: Int) {
        guard let shot = shots.first(where: { $0.id == shotId }) else {
            return (0, 0, 0)
        }
        return (
            dialogues: shot.linkedDialogueIds.count,
            actions: shot.linkedActionIds.count,
            narrations: shot.linkedNarrationIds.count
        )
    }

    /// Check if a connection exists
    public func connectionExists(scriptItemId: String, shotId: String, itemType: ScriptItemType) -> Bool {
        guard let shot = shots.first(where: { $0.id == shotId }) else { return false }

        switch itemType {
        case .dialogue:
            return shot.linkedDialogueIds.contains(scriptItemId)
        case .action:
            return shot.linkedActionIds.contains(scriptItemId)
        case .narration:
            return shot.linkedNarrationIds.contains(scriptItemId)
        }
    }

    // MARK: - Initialization

    public init(
        dialogues: [Dialogue] = [],
        actions: [Action] = [],
        narrations: [Narration] = [],
        shots: [Shot] = []
    ) {
        self.shots = shots.sorted { $0.shotId < $1.shotId }
        updateScriptItems(dialogues: dialogues, actions: actions, narrations: narrations)
    }

    // MARK: - Data Updates

    /// Update script items from scene data
    public func updateScriptItems(
        dialogues: [Dialogue],
        actions: [Action],
        narrations: [Narration]
    ) {
        var items: [ScriptItem] = []
        items.append(contentsOf: dialogues.map { .dialogue($0) })
        items.append(contentsOf: actions.map { .action($0) })
        items.append(contentsOf: narrations.map { .narration($0) })

        scriptItems = items.sorted { $0.chronologyNumber < $1.chronologyNumber }
    }

    /// Update shots
    public func updateShots(_ newShots: [Shot]) {
        shots = newShots.sorted { $0.shotId < $1.shotId }
    }

    // MARK: - Connection CRUD

    /// Create a connection between a script item and a shot
    public func createConnection(scriptItemId: String, shotId: String, itemType: ScriptItemType) {
        guard let shotIndex = shots.firstIndex(where: { $0.id == shotId }) else { return }

        // Check if already connected
        if connectionExists(scriptItemId: scriptItemId, shotId: shotId, itemType: itemType) {
            return
        }

        // Add connection
        switch itemType {
        case .dialogue:
            shots[shotIndex].linkedDialogueIds.append(scriptItemId)
            // Also connect children (sub-bubbles) of this dialogue
            let children = childItems(forDialogueId: scriptItemId)
            for child in children {
                switch child.itemType {
                case .action:
                    if !shots[shotIndex].linkedActionIds.contains(child.id) {
                        shots[shotIndex].linkedActionIds.append(child.id)
                    }
                case .narration:
                    if !shots[shotIndex].linkedNarrationIds.contains(child.id) {
                        shots[shotIndex].linkedNarrationIds.append(child.id)
                    }
                case .dialogue:
                    break
                }
            }
        case .action:
            shots[shotIndex].linkedActionIds.append(scriptItemId)
        case .narration:
            shots[shotIndex].linkedNarrationIds.append(scriptItemId)
        }

        notifyChange()
    }

    /// Remove a connection
    public func removeConnection(_ connection: ScriptConnection) {
        guard let shotIndex = shots.firstIndex(where: { $0.id == connection.shotId }) else { return }

        switch connection.itemType {
        case .dialogue:
            shots[shotIndex].linkedDialogueIds.removeAll { $0 == connection.scriptItemId }
            // Also remove children (sub-bubbles) of this dialogue
            let children = childItems(forDialogueId: connection.scriptItemId)
            for child in children {
                switch child.itemType {
                case .action:
                    shots[shotIndex].linkedActionIds.removeAll { $0 == child.id }
                case .narration:
                    shots[shotIndex].linkedNarrationIds.removeAll { $0 == child.id }
                case .dialogue:
                    break
                }
            }
        case .action:
            shots[shotIndex].linkedActionIds.removeAll { $0 == connection.scriptItemId }
        case .narration:
            shots[shotIndex].linkedNarrationIds.removeAll { $0 == connection.scriptItemId }
        }

        if selectedConnection?.id == connection.id {
            selectedConnection = nil
        }

        notifyChange()
    }

    /// Remove connection by IDs
    public func removeConnection(scriptItemId: String, shotId: String, itemType: ScriptItemType) {
        let connection = ScriptConnection(scriptItemId: scriptItemId, shotId: shotId, itemType: itemType)
        removeConnection(connection)
    }

    /// Remove all connections for a script item
    public func removeAllConnections(for scriptItemId: String) {
        for index in shots.indices {
            shots[index].linkedDialogueIds.removeAll { $0 == scriptItemId }
            shots[index].linkedActionIds.removeAll { $0 == scriptItemId }
            shots[index].linkedNarrationIds.removeAll { $0 == scriptItemId }
        }
        notifyChange()
    }

    /// Remove all connections for a shot
    public func removeAllConnections(forShot shotId: String) {
        guard let shotIndex = shots.firstIndex(where: { $0.id == shotId }) else { return }

        shots[shotIndex].linkedDialogueIds.removeAll()
        shots[shotIndex].linkedActionIds.removeAll()
        shots[shotIndex].linkedNarrationIds.removeAll()

        notifyChange()
    }

    // MARK: - Drag & Drop

    /// Start dragging from a script item port
    public func startDrag(fromScriptItem scriptItemId: String, itemType: ScriptItemType) {
        isDragging = true
        dragSourceId = scriptItemId
        dragSourceType = itemType
        selectedScriptItemId = scriptItemId
    }

    /// Update drag position
    public func updateDragPosition(_ position: CGPoint) {
        dragCurrentPosition = position
    }

    /// End drag and attempt connection
    public func endDrag(at position: CGPoint) {
        defer {
            isDragging = false
            dragSourceId = nil
            dragSourceType = nil
        }

        guard let sourceId = dragSourceId,
              let sourceType = dragSourceType else { return }

        // Find which shot port we're over
        if let targetShotId = findShotAtPosition(position, forType: sourceType) {
            createConnection(scriptItemId: sourceId, shotId: targetShotId, itemType: sourceType)
        }
    }

    /// Cancel drag operation
    public func cancelDrag() {
        isDragging = false
        dragSourceId = nil
        dragSourceType = nil
    }

    /// Find shot at position (checking port positions)
    private func findShotAtPosition(_ position: CGPoint, forType itemType: ScriptItemType) -> String? {
        let hitRadius: CGFloat = SceneConnectionConstants.portHitArea

        for shot in shots {
            let portKey = "shot-\(itemType.rawValue.lowercased())-\(shot.id)"
            if let portPosition = portPositions[portKey] {
                let distance = hypot(position.x - portPosition.x, position.y - portPosition.y)
                if distance <= hitRadius {
                    return shot.id
                }
            }
        }

        return nil
    }

    // MARK: - Selection

    /// Select a script item
    public func selectScriptItem(_ itemId: String?) {
        selectedScriptItemId = itemId
        selectedConnection = nil
    }

    /// Select a shot
    public func selectShot(_ shotId: String?) {
        selectedShotId = shotId
        selectedConnection = nil
    }

    /// Select a connection
    public func selectConnection(_ connection: ScriptConnection?) {
        selectedConnection = connection
        if let conn = connection {
            selectedScriptItemId = conn.scriptItemId
            selectedShotId = conn.shotId
        }
    }

    /// Clear all selection
    public func clearSelection() {
        selectedScriptItemId = nil
        selectedShotId = nil
        selectedConnection = nil
    }

    /// Delete selected connection
    public func deleteSelectedConnection() {
        if let connection = selectedConnection {
            removeConnection(connection)
        }
    }

    // MARK: - Port Position Updates

    /// Update port positions from preference key
    /// Uses full replacement to clear stale positions from off-screen ports
    public func updatePortPositions(_ positions: [String: CGPoint]) {
        portPositions = positions
    }

    // MARK: - Private Helpers

    private func notifyChange() {
        onShotsChanged?(shots)
    }
}
