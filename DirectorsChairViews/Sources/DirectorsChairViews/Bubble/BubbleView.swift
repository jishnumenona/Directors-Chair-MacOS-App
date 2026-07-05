// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/BubbleView.swift
//
// Main Bubble View - dialogue editing interface
//
// Layout:
// - Main: Dialogue bubbles (scrollable)
// - Right: Dialogue editor panel (optional)

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import UniformTypeIdentifiers
import AVFoundation

/// Main Bubble View - the primary dialogue editing interface
///
/// Shows dialogue, actions, narrations, notes, and sound notes in a chat-like bubble layout.
/// Primary character's bubbles align left, other characters align right.
public struct BubbleView: View {
    @Binding var project: Project
    @State var selectedScene: DCScene?
    @State var selectedDialogue: Dialogue?
    @State var editingDialogue: Dialogue?
    @State var editingAction: Action?
    @State var editingNarration: Narration?
    @State var editingNote: Note?
    @State var editingSoundNote: SoundNote?

    // New-character inline picker (used by BubbleView+CharacterPicker)
    @FocusState var newCharacterFieldFocused: Bool
    @State var isCommittingNewCharacter = false

    // Filter toggles
    @State var showDialogues = true
    @State var showActions = true
    @State var showNarrations = true
    @State var showNotes = true
    @State var showSoundNotes = true
    @State var showBackground = false

    // UI state
    @State var sortRefreshTrigger = UUID()
    @State var newlyAddedItemId: String? = nil  // Track newly added items for auto-edit
    @State var dropTargetDialogueId: String? = nil  // Track which dialogue is being targeted for drop
    @AppStorage("bubbleView.leftAlignedOverrides") private var leftAlignedOverridesData: Data = Data()

    /// Character names whose alignment has been flipped by the user (persisted)
    var leftAlignedOverrides: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: leftAlignedOverridesData)) ?? []
        }
    }

    func toggleAlignmentOverride(for characterName: String) {
        var current = leftAlignedOverrides
        if current.contains(characterName) {
            current.remove(characterName)
        } else {
            current.insert(characterName)
        }
        leftAlignedOverridesData = (try? JSONEncoder().encode(current)) ?? Data()
    }
    @State var showCharacterPicker = false  // Toolbar popover to pick character for new dialogue
    @State var showFloatingCharacterPicker = false  // Floating picker at right-click location
    @State var floatingPickerPosition: CGPoint = .zero  // Position in scroll area local coords
    @State var lastRightClickScreenPos: NSPoint = .zero  // Stored right-click screen position
    @State var rightClickMonitor: Any? = nil  // Event monitor for right-clicks
    @State var scrollAreaFrame: CGRect = .zero  // Scroll area frame in global coords
    @State var showInlineCharacterPicker = false  // Inline picker at end of bubble list
    @State var selectedCharacterIndex: Int = 0  // Arrow-key focused character index
    @State var showShortcutsPopover = false  // Shortcuts help popover
    @State var pickerKeyMonitor: Any? = nil  // Key event monitor for character picker
    @State var showNewCharacterInput = false  // Show text field for new character name
    @State var newCharacterName = ""  // New character name being entered

    // Highlight state for cross-view synchronization
    @State var scrollToItemId: String? = nil
    @State var hasScrolledToHighlight: Bool = false

    // Audio playback state
    @State var audioPlayer: AVAudioPlayer?
    @State var playingDialogueId: String?
    @State var generatingAudioIds: Set<String> = []
    @State var detectingEmotionIds: Set<String> = []
    @State var audioErrorMessage: String?

    // Cached data for performance (rebuilt on scene switch / reorder)
    @State var cachedChronologicalItems: [BubbleItem] = []
    @State var cachedConnectedItems: [String: [BubbleItem]] = [:]  // dialogueId → children
    @State var cachedCharacterMap: [String: Character] = [:]  // name → Character
    @State var cachedGlobalIndices: [String: Int] = [:]  // itemId → global chronology #

    let projectBasePath: URL?

    /// Optional tuple for highlighting an item from external source (e.g., timeline double-click)
    /// Format: (itemId, itemType, sceneName) where itemType is "dialogue", "action", "narration", etc.
    let highlightedBubbleItem: (id: String, type: String, sceneName: String)?

    /// Callback when items are reordered (to sync with timeline)
    let onItemsReordered: (() -> Void)?

    /// Callback when content is added, updated, or deleted (to sync with timeline)
    let onContentChanged: (() -> Void)?

    /// Externally selected scene ID (e.g., from OutlineTab sidebar via AppCoordinator)
    /// When this changes, BubbleView syncs its internal selectedScene to match.
    let externalSelectedSceneId: String?

    /// Incremented by parent when project data changes externally (e.g., ScriptView edits).
    /// Triggers cache rebuild so BubbleView reflects the latest project state.
    let externalRefreshTrigger: Int

    /// Callback when a dialogue is selected (for AI context forwarding)
    let onDialogueSelected: ((Dialogue?) -> Void)?

    /// Callback when user double-clicks a character avatar to navigate to Story Design
    let onNavigateToCharacter: ((Character) -> Void)?

    public init(
        project: Binding<Project>,
        projectBasePath: URL? = nil,
        highlightedBubbleItem: (id: String, type: String, sceneName: String)? = nil,
        onItemsReordered: (() -> Void)? = nil,
        onContentChanged: (() -> Void)? = nil,
        externalSelectedSceneId: String? = nil,
        externalRefreshTrigger: Int = 0,
        onDialogueSelected: ((Dialogue?) -> Void)? = nil,
        onNavigateToCharacter: ((Character) -> Void)? = nil
    ) {
        self._project = project
        self.projectBasePath = projectBasePath
        self.highlightedBubbleItem = highlightedBubbleItem
        self.onItemsReordered = onItemsReordered
        self.onContentChanged = onContentChanged
        self.externalSelectedSceneId = externalSelectedSceneId
        self.externalRefreshTrigger = externalRefreshTrigger
        self.onDialogueSelected = onDialogueSelected
        self.onNavigateToCharacter = onNavigateToCharacter
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            // Bubble scroll area
            bubbleScrollArea
                .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .background {
            // Cmd+D — Add Dialogue
            Button("") {
                selectedCharacterIndex = 0
                showInlineCharacterPicker = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToItemId = "inlineCharacterPicker"
                }
            }
            .keyboardShortcut("d", modifiers: .command)
            .hidden()

            // Cmd+Shift+A — Add Action
            Button("") { addAction() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .hidden()

            // Cmd+Shift+N — Add Narration
            Button("") { addNarration() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .hidden()

            // Cmd+Shift+O — Add Note
            Button("") { addNote() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .hidden()

            // Cmd+Shift+S — Add Sound Note
            Button("") { addSoundNote() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .hidden()

            // Return — Select highlighted character in picker
            Button("") {
                if isAnyPickerOpen {
                    selectCurrentCharacter()
                }
            }
            .keyboardShortcut(.defaultAction)
            .hidden()
        }
        .sheet(item: $editingDialogue) { dialogue in
            EditDialogueSheet(
                dialogue: dialogue,
                characters: project.characters,
                projectBasePath: projectBasePath,
                onSave: { updated in
                    let oldChronology = dialogue.chronologyNumber
                    updateDialogue(updated)
                    // If order changed, reorder all items
                    if updated.chronologyNumber != oldChronology {
                        reorderItems(movingItemId: updated.id, oldIndex: oldChronology, newIndex: updated.chronologyNumber)
                    }
                    editingDialogue = nil
                },
                onCancel: {
                    editingDialogue = nil
                },
                onCharacterColorChanged: { characterName, hexColor in
                    if let idx = project.characters.firstIndex(where: { $0.name == characterName }) {
                        project.characters[idx].color = hexColor
                    }
                }
            )
        }
        .sheet(item: $editingAction) { action in
            EditActionSheet(
                action: action,
                onSave: { updated in
                    updateAction(updated)
                    editingAction = nil
                },
                onCancel: {
                    editingAction = nil
                }
            )
        }
        .sheet(item: $editingNarration) { narration in
            EditNarrationSheet(
                narration: narration,
                onSave: { updated in
                    updateNarration(updated)
                    editingNarration = nil
                },
                onCancel: {
                    editingNarration = nil
                }
            )
        }
        .sheet(item: $editingNote) { note in
            EditNoteSheet(
                note: note,
                onSave: { updated in
                    updateNote(updated)
                    editingNote = nil
                },
                onCancel: {
                    editingNote = nil
                }
            )
        }
        .sheet(item: $editingSoundNote) { soundNote in
            EditSoundNoteSheet(
                soundNote: soundNote,
                onSave: { updated in
                    updateSoundNote(updated)
                    editingSoundNote = nil
                },
                onCancel: {
                    editingSoundNote = nil
                }
            )
        }
        .alert("Voice Generation Error", isPresented: Binding(
            get: { audioErrorMessage != nil },
            set: { if !$0 { audioErrorMessage = nil } }
        )) {
            Button("OK") { audioErrorMessage = nil }
        } message: {
            Text(audioErrorMessage ?? "")
        }
        .onDisappear {
            if let monitor = rightClickMonitor {
                NSEvent.removeMonitor(monitor)
                rightClickMonitor = nil
            }
            removePickerKeyMonitor()
        }
        .onChange(of: showCharacterPicker) { _, isOpen in
            if isOpen { installPickerKeyMonitor() } else { removePickerKeyMonitor() }
        }
        .onChange(of: showInlineCharacterPicker) { _, isOpen in
            if isOpen { installPickerKeyMonitor() } else { removePickerKeyMonitor() }
        }
        .onChange(of: showFloatingCharacterPicker) { _, isOpen in
            if isOpen { installPickerKeyMonitor() } else { removePickerKeyMonitor() }
        }
        .onAppear {
            // Monitor right-clicks to store position for floating character picker
            rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
                lastRightClickScreenPos = NSEvent.mouseLocation
                return event
            }

            // Sync to externally selected scene first (onChange won't fire on initial render)
            if let externalId = externalSelectedSceneId, selectedScene?.id != externalId {
                for sequence in project.sequences {
                    if let targetScene = sequence.scenes.first(where: { $0.id == externalId }) {
                        selectedScene = targetScene
                        break
                    }
                }
            }

            selectFirstSceneIfNeeded()

            // Build initial cache for the selected scene
            if let scene = selectedScene {
                rebuildBubbleCache(for: scene)
            }

            // Check if there's a highlighted item to process on appear
            if let highlighted = highlightedBubbleItem, !hasScrolledToHighlight {
                // Find and switch to the scene
                if let targetScene = findScene(containing: highlighted.id, ofType: highlighted.type) {
                    if selectedScene?.id != targetScene.id {
                        selectedScene = targetScene
                    }
                }

                // Scroll to the item after a brief delay for view to settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToItemId = highlighted.id
                    hasScrolledToHighlight = true
                }
            }
        }
        .onChange(of: highlightedBubbleItem?.id) { newValue in
            guard let highlighted = highlightedBubbleItem else { return }

            // Reset scroll tracking for new highlight
            hasScrolledToHighlight = false

            // Find and switch to the scene containing this item
            if let targetScene = findScene(containing: highlighted.id, ofType: highlighted.type) {
                if selectedScene?.id != targetScene.id {
                    selectedScene = targetScene
                    rebuildBubbleCache(for: targetScene)
                }
            }

            // Scroll to the item immediately
            scrollToItemId = highlighted.id
            hasScrolledToHighlight = true
        }
        .onChange(of: externalSelectedSceneId) { newSceneId in
            guard let sceneId = newSceneId else { return }
            // Only switch if it's a different scene
            guard selectedScene?.id != sceneId else { return }
            // Find the scene by ID across all sequences
            for sequence in project.sequences {
                if let targetScene = sequence.scenes.first(where: { $0.id == sceneId }) {
                    selectedScene = targetScene
                    rebuildBubbleCache(for: targetScene)
                    return
                }
            }
        }
        .onChange(of: externalRefreshTrigger) { _ in
            // External project data changed (e.g., ScriptView edit) — re-fetch scene and rebuild cache
            guard let currentId = selectedScene?.id else { return }
            // Re-read the scene from the project to pick up any external changes
            for sequence in project.sequences {
                if let freshScene = sequence.scenes.first(where: { $0.id == currentId }) {
                    selectedScene = freshScene
                    rebuildBubbleCache(for: freshScene)
                    return
                }
            }
            // Scene was deleted externally — clear selection
            selectedScene = nil
            cachedChronologicalItems = []
            cachedConnectedItems = [:]
        }
        .onChange(of: selectedScene?.id) { _ in
            if let scene = selectedScene {
                rebuildBubbleCache(for: scene)
            }
        }
        .onChange(of: sortRefreshTrigger) { _ in
            if let scene = selectedScene {
                rebuildBubbleCache(for: scene)
            }
        }
        .onChange(of: selectedDialogue?.uuid) { _ in
            onDialogueSelected?(selectedDialogue)
        }
    }
}
