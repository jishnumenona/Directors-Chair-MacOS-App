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
    @Published public var showDialogues: Bool = true { didSet { rebuildGrouped() } }
    @Published public var showActions: Bool = true { didSet { rebuildGrouped() } }
    @Published public var showNarrations: Bool = true { didSet { rebuildGrouped() } }

    /// Drag state for connection creation
    @Published public var isDragging: Bool = false
    @Published public var dragSourceId: String?
    @Published public var dragSourceType: ScriptItemType?
    @Published public var dragCurrentPosition: CGPoint = .zero
    /// The shot the drag currently hovers (drop target) — scopes highlight to
    /// one card instead of invalidating every shot card per drag tick.
    @Published public var dragHoverShotId: String?

    /// Port positions (updated via PreferenceKey)
    @Published public var portPositions: [String: CGPoint] = [:]

    /// Shot CARD frames (drop anywhere on the card, not just the 24pt port)
    public var cardFrames: [String: CGRect] = [:]

    /// All connections derived from shots — CACHED, rebuilt only on mutation
    /// (previously a computed property re-scanned per render).
    @Published public private(set) var connections: [ScriptConnection] = []

    // MARK: - Derived caches (rebuilt on mutation, O(1) at render time)

    private var shotIdsByItem: [String: Set<String>] = [:]
    private var shotsById: [String: Shot] = [:]
    private var groupedCache: [ScriptListEntry] = []

    // MARK: - Callbacks

    /// Callback when shots change (for persistence)
    public var onShotsChanged: (([Shot]) -> Void)?

    /// Window undo manager (wired by the hosting view) — link edits are undoable.
    public weak var undoManager: UndoManager?

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

    /// Grouped script entries — served from cache; rebuilt only when items or
    /// filters change (previously O(n log n) on every render).
    public var groupedScriptEntries: [ScriptListEntry] { groupedCache }

    private func rebuildGrouped() {
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

        groupedCache = entries
    }

    /// Get child items for a given dialogue ID
    public func childItems(forDialogueId dialogueId: String) -> [ScriptItem] {
        scriptItems.filter { $0.parentDialogueId == dialogueId }
            .sorted { $0.chronologyNumber < $1.chronologyNumber }
    }

    /// Rebuild every shot-derived cache. Called on any shots mutation —
    /// render-time lookups are then O(1).
    private func rebuildDerived() {
        var result: [ScriptConnection] = []
        var byItem: [String: Set<String>] = [:]
        var byId: [String: Shot] = [:]

        for shot in shots {
            byId[shot.id] = shot
            for dialogueId in shot.linkedDialogueIds {
                result.append(ScriptConnection(scriptItemId: dialogueId, shotId: shot.id, itemType: .dialogue))
                byItem[dialogueId, default: []].insert(shot.id)
            }
            for actionId in shot.linkedActionIds {
                result.append(ScriptConnection(scriptItemId: actionId, shotId: shot.id, itemType: .action))
                byItem[actionId, default: []].insert(shot.id)
            }
            for narrationId in shot.linkedNarrationIds {
                result.append(ScriptConnection(scriptItemId: narrationId, shotId: shot.id, itemType: .narration))
                byItem[narrationId, default: []].insert(shot.id)
            }
        }

        connections = result
        shotIdsByItem = byItem
        shotsById = byId
    }

    /// Get connected shot IDs for a script item — O(1)
    public func connectedShotIds(for scriptItemId: String) -> Set<String> {
        shotIdsByItem[scriptItemId] ?? []
    }

    /// Check if a shot is connected to the currently selected script item — O(1)
    public func isShotConnectedToSelectedItem(_ shotId: String) -> Bool {
        guard let selectedId = selectedScriptItemId else { return false }
        return shotIdsByItem[selectedId]?.contains(shotId) ?? false
    }

    /// Get connection counts for a shot — O(1)
    public func connectionCounts(for shotId: String) -> (dialogues: Int, actions: Int, narrations: Int) {
        guard let shot = shotsById[shotId] else {
            return (0, 0, 0)
        }
        return (
            dialogues: shot.linkedDialogueIds.count,
            actions: shot.linkedActionIds.count,
            narrations: shot.linkedNarrationIds.count
        )
    }

    /// Check if a connection exists — O(1) shot lookup
    public func connectionExists(scriptItemId: String, shotId: String, itemType: ScriptItemType) -> Bool {
        guard let shot = shotsById[shotId] else { return false }

        switch itemType {
        case .dialogue:
            return shot.linkedDialogueIds.contains(scriptItemId)
        case .action:
            return shot.linkedActionIds.contains(scriptItemId)
        case .narration:
            return shot.linkedNarrationIds.contains(scriptItemId)
        }
    }

    /// Menu-driven linking (keyboard/pointer-accessible alternative to drag).
    public func toggleConnection(scriptItemId: String, shotId: String, itemType: ScriptItemType) {
        if connectionExists(scriptItemId: scriptItemId, shotId: shotId, itemType: itemType) {
            removeConnection(scriptItemId: scriptItemId, shotId: shotId, itemType: itemType)
        } else {
            createConnection(scriptItemId: scriptItemId, shotId: shotId, itemType: itemType)
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
        rebuildDerived()
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
        rebuildGrouped()
    }

    /// Update shots
    public func updateShots(_ newShots: [Shot]) {
        shots = newShots.sorted { $0.shotId < $1.shotId }
        rebuildDerived()
    }

    /// Refresh everything from the hosting scene (keeps still-valid selection
    /// and drag state). Called by the view when scene content changes
    /// externally — Bubble/Shots edits now propagate into an open canvas.
    public func refresh(
        dialogues: [Dialogue],
        actions: [Action],
        narrations: [Narration],
        shots newShots: [Shot]
    ) {
        updateScriptItems(dialogues: dialogues, actions: actions, narrations: narrations)
        updateShots(newShots)
        if let selected = selectedScriptItemId, !scriptItems.contains(where: { $0.id == selected }) {
            selectedScriptItemId = nil
        }
        if let selected = selectedShotId, shotsById[selected] == nil {
            selectedShotId = nil
        }
        if let connection = selectedConnection,
           !connections.contains(where: { $0.id == connection.id }) {
            selectedConnection = nil
        }
    }

    // MARK: - Connection CRUD

    /// Create a connection between a script item and a shot
    public func createConnection(scriptItemId: String, shotId: String, itemType: ScriptItemType) {
        guard let shotIndex = shots.firstIndex(where: { $0.id == shotId }) else { return }

        // Check if already connected
        if connectionExists(scriptItemId: scriptItemId, shotId: shotId, itemType: itemType) {
            return
        }

        let before = shots

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

        notifyChange(undoing: before, actionName: "Connect")
    }

    /// Remove a connection
    public func removeConnection(_ connection: ScriptConnection) {
        guard let shotIndex = shots.firstIndex(where: { $0.id == connection.shotId }) else { return }

        let before = shots

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

        notifyChange(undoing: before, actionName: "Remove Connection")
    }

    /// Remove connection by IDs
    public func removeConnection(scriptItemId: String, shotId: String, itemType: ScriptItemType) {
        let connection = ScriptConnection(scriptItemId: scriptItemId, shotId: shotId, itemType: itemType)
        removeConnection(connection)
    }

    /// Remove all connections for a script item
    public func removeAllConnections(for scriptItemId: String) {
        let before = shots
        for index in shots.indices {
            shots[index].linkedDialogueIds.removeAll { $0 == scriptItemId }
            shots[index].linkedActionIds.removeAll { $0 == scriptItemId }
            shots[index].linkedNarrationIds.removeAll { $0 == scriptItemId }
        }
        notifyChange(undoing: before, actionName: "Remove Connections")
    }

    /// Remove all connections for a shot
    public func removeAllConnections(forShot shotId: String) {
        guard let shotIndex = shots.firstIndex(where: { $0.id == shotId }) else { return }

        let before = shots
        shots[shotIndex].linkedDialogueIds.removeAll()
        shots[shotIndex].linkedActionIds.removeAll()
        shots[shotIndex].linkedNarrationIds.removeAll()

        notifyChange(undoing: before, actionName: "Remove Connections")
    }

    // MARK: - Drag & Drop

    /// Start dragging from a script item port
    public func startDrag(fromScriptItem scriptItemId: String, itemType: ScriptItemType) {
        isDragging = true
        dragSourceId = scriptItemId
        dragSourceType = itemType
        selectedScriptItemId = scriptItemId
    }

    /// Update drag position and resolve the hovered drop target.
    public func updateDragPosition(_ position: CGPoint) {
        dragCurrentPosition = position
        let hovered = shotId(at: position)
        if hovered != dragHoverShotId { dragHoverShotId = hovered }
    }

    /// End drag and attempt connection
    public func endDrag(at position: CGPoint) {
        defer {
            isDragging = false
            dragSourceId = nil
            dragSourceType = nil
            dragHoverShotId = nil
        }

        guard let sourceId = dragSourceId,
              let sourceType = dragSourceType else { return }

        if let targetShotId = shotId(at: position) {
            createConnection(scriptItemId: sourceId, shotId: targetShotId, itemType: sourceType)
        }
    }

    /// Cancel drag operation
    public func cancelDrag() {
        isDragging = false
        dragSourceId = nil
        dragSourceType = nil
        dragHoverShotId = nil
    }

    /// The shot at a canvas position: port proximity first (24pt forgiveness),
    /// then anywhere on the shot card — dropping on the card body now works.
    private func shotId(at position: CGPoint) -> String? {
        if let sourceType = dragSourceType,
           let byPort = findShotAtPosition(position, forType: sourceType) {
            return byPort
        }
        return cardFrames.first { $0.value.contains(position) }?.key
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

    /// Update shot-card frames (non-published: only drag resolution reads them,
    /// so scroll ticks don't trigger extra render passes).
    public func updateCardFrames(_ frames: [String: CGRect]) {
        cardFrames = frames
    }

    // MARK: - Private Helpers

    /// Rebuild caches, register undo (snapshot-based, symmetric for cascades),
    /// and notify the host. Every shots mutation funnels through here via
    /// `notifyChange(undoing:)`.
    private func notifyChange(undoing before: [Shot]? = nil, actionName: String = "Edit Connection") {
        rebuildDerived()
        if let before, let undoManager {
            undoManager.registerUndo(withTarget: self) { viewModel in
                MainActor.assumeIsolated {
                    viewModel.applySnapshot(before, actionName: actionName)
                }
            }
            undoManager.setActionName(actionName)
        }
        onShotsChanged?(shots)
    }

    /// Undo/redo application: restore a shots snapshot, registering the
    /// inverse so redo works (UndoManager flips registrations made during undo).
    private func applySnapshot(_ snapshot: [Shot], actionName: String) {
        let current = shots
        shots = snapshot
        notifyChange(undoing: current, actionName: actionName)
    }
}
