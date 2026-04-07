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
    @State private var selectedScene: DCScene?
    @State private var selectedDialogue: Dialogue?
    @State private var editingDialogue: Dialogue?
    @State private var editingAction: Action?
    @State private var editingNarration: Narration?
    @State private var editingNote: Note?
    @State private var editingSoundNote: SoundNote?

    // Filter toggles
    @State private var showDialogues = true
    @State private var showActions = true
    @State private var showNarrations = true
    @State private var showNotes = true
    @State private var showSoundNotes = true
    @State private var showBackground = false

    // UI state
    @State private var sortRefreshTrigger = UUID()
    @State private var newlyAddedItemId: String? = nil  // Track newly added items for auto-edit
    @State private var dropTargetDialogueId: String? = nil  // Track which dialogue is being targeted for drop
    @AppStorage("bubbleView.leftAlignedOverrides") private var leftAlignedOverridesData: Data = Data()

    /// Character names whose alignment has been flipped by the user (persisted)
    private var leftAlignedOverrides: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: leftAlignedOverridesData)) ?? []
        }
    }

    private func toggleAlignmentOverride(for characterName: String) {
        var current = leftAlignedOverrides
        if current.contains(characterName) {
            current.remove(characterName)
        } else {
            current.insert(characterName)
        }
        leftAlignedOverridesData = (try? JSONEncoder().encode(current)) ?? Data()
    }
    @State private var showCharacterPicker = false  // Toolbar popover to pick character for new dialogue
    @State private var showFloatingCharacterPicker = false  // Floating picker at right-click location
    @State private var floatingPickerPosition: CGPoint = .zero  // Position in scroll area local coords
    @State private var lastRightClickScreenPos: NSPoint = .zero  // Stored right-click screen position
    @State private var rightClickMonitor: Any? = nil  // Event monitor for right-clicks
    @State private var scrollAreaFrame: CGRect = .zero  // Scroll area frame in global coords
    @State private var showInlineCharacterPicker = false  // Inline picker at end of bubble list
    @State private var selectedCharacterIndex: Int = 0  // Arrow-key focused character index
    @State private var showShortcutsPopover = false  // Shortcuts help popover
    @State private var pickerKeyMonitor: Any? = nil  // Key event monitor for character picker
    @State private var showNewCharacterInput = false  // Show text field for new character name
    @State private var newCharacterName = ""  // New character name being entered

    // Highlight state for cross-view synchronization
    @State private var scrollToItemId: String? = nil
    @State private var hasScrolledToHighlight: Bool = false

    // Audio playback state
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingDialogueId: String?
    @State private var generatingAudioIds: Set<String> = []
    @State private var detectingEmotionIds: Set<String> = []
    @State private var audioErrorMessage: String?

    // Cached data for performance (rebuilt on scene switch / reorder)
    @State private var cachedChronologicalItems: [BubbleItem] = []
    @State private var cachedConnectedItems: [String: [BubbleItem]] = [:]  // dialogueId → children
    @State private var cachedCharacterMap: [String: Character] = [:]  // name → Character
    @State private var cachedGlobalIndices: [String: Int] = [:]  // itemId → global chronology #

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

    /// Find the scene containing an item by ID and type
    private func findScene(containing itemId: String, ofType itemType: String) -> DCScene? {
        for sequence in project.sequences {
            for scene in sequence.scenes {
                switch itemType {
                case "dialogue":
                    if scene.dialogues.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "action":
                    if scene.actions.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "narration":
                    if scene.narrations.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "note":
                    if scene.sceneNotes.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "soundNote":
                    if scene.soundNotes.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                default:
                    break
                }
            }
        }
        return nil
    }

    /// Select the first scene from the first sequence if no scene is currently selected
    private func selectFirstSceneIfNeeded() {
        guard selectedScene == nil else { return }

        // Find the first sequence with at least one scene
        if let firstSequence = project.sequences.first(where: { !$0.scenes.isEmpty }),
           let firstScene = firstSequence.scenes.first {
            selectedScene = firstScene
        } else if let anyScene = project.sequences.flatMap({ $0.scenes }).first {
            // Fallback: any scene from any sequence
            selectedScene = anyScene
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Bubble View")
                    .font(.headline)
                if let scene = selectedScene {
                    Text(scene.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Filter buttons
            filterButtons

            Divider()
                .frame(height: 20)

            // Background toggle
            Toggle(isOn: $showBackground) {
                Image(systemName: "photo")
            }
            .toggleStyle(.button)
            .help("Show location background")

            Divider()
                .frame(height: 20)

            // Shortcuts help
            Button {
                showShortcutsPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text("Shortcuts")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.borderless)
            .help("View all keyboard shortcuts")
            .popover(isPresented: $showShortcutsPopover, arrowEdge: .bottom) {
                BubbleShortcutsPopoverView()
            }

            Divider()
                .frame(height: 20)

            // Add dialogue button with character picker popover
            Button(action: { selectedCharacterIndex = 0; showCharacterPicker = true }) {
                Image(systemName: "plus.bubble")
            }
            .help("Add Dialogue")
            .popover(isPresented: $showCharacterPicker, arrowEdge: .bottom) {
                characterPickerPopover
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Shared Character Picker Grid

    /// Number badge label for a character at the given index (1-9, 0 for 10th, nil for 11+)
    private func numberBadgeLabel(for index: Int) -> String? {
        if index < 9 { return "\(index + 1)" }
        if index == 9 { return "0" }
        return nil
    }

    /// Shared character picker grid with keyboard navigation
    @ViewBuilder
    private func characterPickerGrid(useHStack: Bool = false, dismiss: @escaping () -> Void) -> some View {
        let characters = project.characters
        let content = Group {
            if useHStack {
                HStack(spacing: 12) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        characterPickerCell(character: character, index: index, dismiss: dismiss)
                    }
                    newCharacterCell(dismiss: dismiss)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        characterPickerCell(character: character, index: index, dismiss: dismiss)
                    }
                    newCharacterCell(dismiss: dismiss)
                }
            }
        }

        content
    }

    @ViewBuilder
    private func characterPickerCell(character: Character, index: Int, dismiss: @escaping () -> Void) -> some View {
        let isSelected = index == selectedCharacterIndex

        VStack(spacing: 4) {
            CharacterAvatarView(
                character: character,
                characterName: character.name,
                size: 40,
                projectBasePath: projectBasePath
            )
            .overlay(alignment: .topLeading) {
                if let badge = numberBadgeLabel(for: index) {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.accentColor.opacity(0.85)))
                        .offset(x: -4, y: -4)
                }
            }

            Text(character.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(width: 60)
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
            addDialogue(for: character.name)
        }
    }

    @FocusState private var newCharacterFieldFocused: Bool
    @State private var isCommittingNewCharacter = false

    @ViewBuilder
    private func newCharacterCell(dismiss: @escaping () -> Void) -> some View {
        if showNewCharacterInput {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.accentColor)
                }

                TextField("Name", text: $newCharacterName)
                    .font(.system(size: 9, weight: .medium))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .focused($newCharacterFieldFocused)
                    .onSubmit {
                        isCommittingNewCharacter = true
                        commitNewCharacter(dismiss: dismiss)
                    }
                    .onChange(of: newCharacterFieldFocused) { _, focused in
                        if !focused && !isCommittingNewCharacter {
                            // Cancelled — just hide the input
                            showNewCharacterInput = false
                            newCharacterName = ""
                        }
                    }
                    .onAppear {
                        isCommittingNewCharacter = false
                        newCharacterFieldFocused = true
                    }
            }
            .frame(width: 60)
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
        } else {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(NSColor.quaternarySystemFill))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Text("New")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 60)
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture {
                newCharacterName = ""
                showNewCharacterInput = true
            }
        }
    }

    private static let characterColors = [
        "#3498db", "#e74c3c", "#2ecc71", "#9b59b6", "#f39c12",
        "#1abc9c", "#e67e22", "#2980b9", "#c0392b", "#27ae60",
        "#8e44ad", "#d35400", "#16a085", "#f1c40f", "#7f8c8d"
    ]

    private func commitNewCharacter(dismiss: @escaping () -> Void) {
        let name = newCharacterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showNewCharacterInput = false
            newCharacterName = ""
            isCommittingNewCharacter = false
            return
        }
        // Check if character already exists
        let alreadyExists = project.characters.contains { $0.name.lowercased() == name.lowercased() }
        if !alreadyExists {
            let colorIndex = project.characters.count % Self.characterColors.count
            let newCharacter = Character(
                name: name,
                color: Self.characterColors[colorIndex]
            )
            project.characters.append(newCharacter)
        }
        showNewCharacterInput = false
        newCharacterName = ""
        // Dismiss picker first, then add dialogue after a brief delay so view settles
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.addDialogue(for: name)
            self.isCommittingNewCharacter = false
        }
    }

    /// Popover wrapper using the shared grid
    private var characterPickerPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose Character")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 4)

            characterPickerGrid {
                showCharacterPicker = false
                showFloatingCharacterPicker = false
            }
        }
        .padding(12)
        .frame(minWidth: 160)
    }

    // MARK: - Inline Character Picker (Cmd+D)

    private var inlineCharacterPicker: some View {
        HStack {
            Spacer()

            VStack(spacing: 8) {
                HStack {
                    Text("Choose Character")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showInlineCharacterPicker = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                characterPickerGrid(useHStack: true) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showInlineCharacterPicker = false
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
            )
            .frame(maxWidth: 500)

            Spacer()
        }
    }

    /// Convert stored right-click screen position to scroll area local coords and show the floating picker
    private func showFloatingPickerAtRightClick() {
        guard let window = NSApp.keyWindow, let contentView = window.contentView else { return }
        // Convert screen coords (bottom-left origin) to window coords
        var windowPos = window.convertPoint(fromScreen: lastRightClickScreenPos)
        // Flip Y to match SwiftUI's top-left origin (same as GeometryReader .global)
        windowPos.y = contentView.frame.height - windowPos.y
        // Convert to scroll area local coordinates
        floatingPickerPosition = CGPoint(
            x: windowPos.x - scrollAreaFrame.minX,
            y: windowPos.y - scrollAreaFrame.minY
        )
        selectedCharacterIndex = 0
        showFloatingCharacterPicker = true
    }

    // MARK: - Picker Key Monitor

    private func dismissAllPickers() {
        showCharacterPicker = false
        showFloatingCharacterPicker = false
        withAnimation(.easeOut(duration: 0.15)) {
            showInlineCharacterPicker = false
        }
    }

    /// Whether any character picker is currently open
    private var isAnyPickerOpen: Bool {
        showCharacterPicker || showInlineCharacterPicker || showFloatingCharacterPicker
    }

    private func selectCurrentCharacter() {
        let characters = project.characters
        guard selectedCharacterIndex < characters.count else { return }
        let name = characters[selectedCharacterIndex].name
        dismissAllPickers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            addDialogue(for: name)
        }
    }

    private func installPickerKeyMonitor() {
        guard pickerKeyMonitor == nil else { return }
        pickerKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isAnyPickerOpen else { return event }
            let characters = self.project.characters
            guard !characters.isEmpty else { return event }

            switch Int(event.keyCode) {
            case 123: // Left arrow
                self.selectedCharacterIndex = max(0, self.selectedCharacterIndex - 1)
                return nil
            case 124: // Right arrow
                self.selectedCharacterIndex = min(characters.count - 1, self.selectedCharacterIndex + 1)
                return nil
            case 125: // Down arrow
                self.selectedCharacterIndex = min(characters.count - 1, self.selectedCharacterIndex + 1)
                return nil
            case 126: // Up arrow
                self.selectedCharacterIndex = max(0, self.selectedCharacterIndex - 1)
                return nil
            case 36, 76: // Return / numpad Enter
                self.selectCurrentCharacter()
                return nil
            case 53: // Escape
                self.dismissAllPickers()
                return nil
            default:
                if let chars = event.characters, chars.count == 1,
                   let digit = Int(chars), (0...9).contains(digit) {
                    let mappedIndex = digit == 0 ? 9 : digit - 1
                    if mappedIndex < characters.count {
                        let name = characters[mappedIndex].name
                        self.dismissAllPickers()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.addDialogue(for: name)
                        }
                        return nil
                    }
                }
                return event
            }
        }
    }

    private func removePickerKeyMonitor() {
        if let monitor = pickerKeyMonitor {
            NSEvent.removeMonitor(monitor)
            pickerKeyMonitor = nil
        }
    }

    // MARK: - Filter Buttons

    private var filterButtons: some View {
        HStack(spacing: 4) {
            FilterToggleButton(
                title: "Dialogue",
                icon: "text.bubble",
                isOn: $showDialogues,
                color: .blue
            )

            FilterToggleButton(
                title: "Actions",
                icon: "film",
                isOn: $showActions,
                color: .orange
            )

            FilterToggleButton(
                title: "Narration",
                icon: "mic",
                isOn: $showNarrations,
                color: .purple
            )

            FilterToggleButton(
                title: "Notes",
                icon: "note.text",
                isOn: $showNotes,
                color: .yellow
            )

            FilterToggleButton(
                title: "Sound",
                icon: "speaker.wave.2",
                isOn: $showSoundNotes,
                color: .cyan
            )
        }
    }

    // MARK: - Bubble Scroll Area

    private var bubbleScrollArea: some View {
        Group {
            if let scene = selectedScene {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(cachedChronologicalItems, id: \.id) { item in
                                itemView(for: item, in: scene)
                                    .id(item.id)  // ID for ScrollViewReader
                            }

                            // Inline character picker (Cmd+D)
                            if showInlineCharacterPicker {
                                inlineCharacterPicker
                                    .id("inlineCharacterPicker")
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            // Bottom breathing room so last items aren't flush with edge
                            Spacer()
                                .frame(height: 80)
                                .id("bottomSpacer")
                        }
                        .id(sortRefreshTrigger) // Force re-render when chronology changes
                        .padding()
                    }
                    .background(backgroundView)
                    .onChange(of: scrollToItemId) { newItemId in
                        if let itemId = newItemId {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(itemId, anchor: .center)
                            }
                            // Clear scroll target after scrolling
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                scrollToItemId = nil
                            }
                        }
                    }
                }
                .contextMenu {
                    addItemsContextMenu
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { scrollAreaFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { newFrame in
                                scrollAreaFrame = newFrame
                            }
                    }
                )
                .overlay {
                    if showFloatingCharacterPicker {
                        ZStack {
                            // Dismiss background
                            Color.black.opacity(0.001)
                                .onTapGesture { showFloatingCharacterPicker = false }

                            characterPickerPopover
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(NSColor.windowBackgroundColor))
                                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .fixedSize()
                                .position(floatingPickerPosition)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Scene",
                    systemImage: "film",
                    description: Text("Choose a scene from the sidebar to view its dialogues")
                )
            }
        }
    }

    // MARK: - Background View

    @ViewBuilder
    private var backgroundView: some View {
        if showBackground, let scene = selectedScene, let locationName = scene.location {
            // TODO: Load actual location image
            Color.gray.opacity(0.1)
        } else {
            Color.clear
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var addItemsContextMenu: some View {
        Button("Add Dialogue") {
            showFloatingPickerAtRightClick()
        }
        Button("Add Action") {
            addAction()
        }
        Button("Add Narration") {
            addNarration()
        }
        Button("Add Note") {
            addNote()
        }
        Button("Add Sound Note") {
            addSoundNote()
        }
    }

    /// Context menu for the connector area between sub-bubbles
    @ViewBuilder
    private func connectedItemsContextMenu(for dialogue: Dialogue) -> some View {
        Button("Add Action") {
            addConnectedAction(to: dialogue)
        }
        Button("Add Narration") {
            addConnectedNarration(to: dialogue)
        }
        Button("Add Note") {
            addConnectedNote(to: dialogue)
        }
        Button("Add Sound Note") {
            addConnectedSoundNote(to: dialogue)
        }
    }

    // MARK: - Item Views

    /// Check if an item should be highlighted based on the external highlight request
    private func isItemHighlighted(_ itemId: String) -> Bool {
        return highlightedBubbleItem?.id == itemId
    }

    @ViewBuilder
    private func itemView(for item: BubbleItem, in scene: DCScene) -> some View {
        switch item {
        case .dialogue(let dialogue):
            if showDialogues {
                dialogueItemView(dialogue: dialogue, scene: scene, isHighlighted: isItemHighlighted(dialogue.id))
            }

        case .action(let action):
            if showActions {
                draggableActionView(action: action, isHighlighted: isItemHighlighted(action.id))
            }

        case .narration(let narration):
            if showNarrations {
                draggableNarrationView(narration: narration, isHighlighted: isItemHighlighted(narration.id))
            }

        case .note(let note):
            if showNotes {
                draggableNoteView(note: note, isHighlighted: isItemHighlighted(note.id))
            }

        case .soundNote(let soundNote):
            if showSoundNotes {
                draggableSoundNoteView(soundNote: soundNote, isHighlighted: isItemHighlighted(soundNote.id))
            }
        }
    }

    // MARK: - Alignment Helper

    /// Determines effective left-alignment for a character using XOR logic:
    /// primary defaults left, override flips it; non-primary defaults right, override flips it
    private func isLeftAligned(_ characterName: String, in scene: DCScene) -> Bool {
        let isPrimary = scene.primaryCharacter == characterName
        let isOverridden = leftAlignedOverrides.contains(characterName)
        return isPrimary != isOverridden
    }

    // MARK: - Dialogue View with Drop Target and Sub-Bubbles

    @ViewBuilder
    private func dialogueItemView(dialogue: Dialogue, scene: DCScene, isHighlighted: Bool = false) -> some View {
        let character = cachedCharacterMap[dialogue.character]
        let isPrimary = isLeftAligned(dialogue.character, in: scene)
        let connectedItems = cachedConnectedItems[dialogue.id] ?? []
        let isDropTarget = dropTargetDialogueId == dialogue.id

        // Use HStack to position everything on the correct side
        HStack {
            if !isPrimary {
                Spacer()  // Push to right for non-primary characters
            }

            VStack(alignment: isPrimary ? .trailing : .leading, spacing: 4) {
                // Main dialogue bubble with drop target
                DialogueBubbleCard(
                    dialogue: dialogue,
                    character: character,
                    isSelected: selectedDialogue?.id == dialogue.id,
                    isPrimaryCharacter: isPrimary,
                    startInEditMode: dialogue.id == newlyAddedItemId,
                    projectBasePath: projectBasePath,
                    globalIndex: cachedGlobalIndices[dialogue.id],
                    onTap: { selectedDialogue = dialogue },
                    onDoubleTap: { editingDialogue = dialogue },
                    onEdit: { editingDialogue = dialogue },
                    onDelete: { deleteDialogue(dialogue) },
                    onPlay: { playDialogue(dialogue) },
                    onStop: { stopDialogue() },
                    onGenerateAudio: { Task { await generateAndPlayDialogue(dialogue) } },
                    onDetectEmotion: { Task { await detectDialogueEmotion(dialogue) } },
                    isGeneratingAudio: generatingAudioIds.contains(dialogue.id),
                    isPlaying: playingDialogueId == dialogue.id,
                    isDetectingEmotion: detectingEmotionIds.contains(dialogue.id),
                    onTextChanged: { newText in
                        var updated = dialogue
                        updated.text = newText
                        updateDialogue(updated)
                    },
                    onChronologyChanged: { newIndex in
                        reorderItems(movingItemId: dialogue.id, oldIndex: dialogue.chronologyNumber, newIndex: newIndex)
                    },
                    onEditModeStarted: { newlyAddedItemId = nil },
                    alignmentLabel: isPrimary ? "Move \(dialogue.character) to Right" : "Move \(dialogue.character) to Left",
                    onToggleAlignment: {
                        toggleAlignmentOverride(for: dialogue.character)
                    },
                    onAddConnectedAction: { addConnectedAction(to: dialogue) },
                    onAddConnectedNarration: { addConnectedNarration(to: dialogue) },
                    onAddConnectedNote: { addConnectedNote(to: dialogue) },
                    onAddConnectedSoundNote: { addConnectedSoundNote(to: dialogue) },
                    onNavigateToCharacter: {
                        if let char = character {
                            onNavigateToCharacter?(char)
                        }
                    }
                )
                .modifier(HighlightModifier(isHighlighted: isHighlighted))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDropTarget ? Color.green : Color.clear, lineWidth: 3)
                )
                .onDrop(of: [UTType.json], isTargeted: Binding(
                    get: { dropTargetDialogueId == dialogue.id },
                    set: { isTargeted in
                        dropTargetDialogueId = isTargeted ? dialogue.id : nil
                    }
                )) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadDataRepresentation(for: UTType.json) { data, error in
                        guard let data = data,
                              let dragData = try? JSONDecoder().decode(BubbleItemDragData.self, from: data) else {
                            return
                        }
                        DispatchQueue.main.async {
                            connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogue.id)
                        }
                    }
                    return true
                }

                // Connected sub-bubbles directly below the dialogue bubble
                if !connectedItems.isEmpty {
                    HStack(spacing: 0) {
                        // Small connector line on the left
                        if isPrimary {
                            Spacer()
                                .frame(width: 20)
                        }

                        // Vertical connector line
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 2)
                            .padding(.vertical, 2)

                        // Sub-bubbles
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(connectedItems, id: \.id) { subItem in
                                HStack(spacing: 4) {
                                    // Horizontal connector tick
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(width: 8, height: 2)

                                    subBubbleContent(for: subItem, parentDialogueId: dialogue.id)
                                }
                            }
                        }
                        .padding(.leading, 4)

                        if !isPrimary {
                            Spacer()
                                .frame(width: 20)
                        }
                    }
                    .padding(.leading, isPrimary ? 50 : 0)  // Align with bubble content area
                    .padding(.trailing, isPrimary ? 0 : 50)
                    .contextMenu {
                        connectedItemsContextMenu(for: dialogue)
                    }
                }
            }

            if isPrimary {
                Spacer()  // Push to left for primary characters
            }
        }
    }

    // MARK: - Sub-Bubble Content (just the bubble card, no wrapper)

    @ViewBuilder
    private func subBubbleContent(for item: BubbleItem, parentDialogueId: String) -> some View {
        switch item {
        case .action(let action):
            ActionBubbleCard(
                action: action,
                isSelected: false,
                startInEditMode: false,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[action.id],
                onTap: { },
                onEdit: { editAction(action) },
                onDelete: { deleteAction(action) },
                onTextChanged: { newText in
                    var updated = action
                    updated.description = newText
                    updateAction(updated)
                },
                onChronologyChanged: { _ in }
            )
            .modifier(HighlightModifier(isHighlighted: isItemHighlighted(action.id)))
            .draggable(BubbleItemDragData(itemId: action.id, itemType: "action"))
            .contextMenu {
                Button("Disconnect from Dialogue") {
                    disconnectItem(itemId: action.id, itemType: "action")
                }
                Divider()
                Button("Edit") { editAction(action) }
                Button("Delete", role: .destructive) { deleteAction(action) }
            }

        case .narration(let narration):
            NarrationBubbleCard(
                narration: narration,
                isSelected: false,
                startInEditMode: false,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[narration.id],
                onTap: { },
                onEdit: { editNarration(narration) },
                onDelete: { deleteNarration(narration) },
                onTextChanged: { newText in
                    var updated = narration
                    updated.text = newText
                    updateNarration(updated)
                },
                onChronologyChanged: { _ in }
            )
            .modifier(HighlightModifier(isHighlighted: isItemHighlighted(narration.id)))
            .draggable(BubbleItemDragData(itemId: narration.id, itemType: "narration"))
            .contextMenu {
                Button("Disconnect from Dialogue") {
                    disconnectItem(itemId: narration.id, itemType: "narration")
                }
                Divider()
                Button("Edit") { editNarration(narration) }
                Button("Delete", role: .destructive) { deleteNarration(narration) }
            }

        case .note(let note):
            NoteBubbleCard(
                note: note,
                isSelected: false,
                startInEditMode: false,
                projectBasePath: projectBasePath,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[note.id],
                onTap: { },
                onEdit: { editNote(note) },
                onDelete: { deleteNote(note) },
                onTextChanged: { newText in
                    var updated = note
                    if !note.title.isEmpty {
                        updated.title = newText
                    } else {
                        updated.content = newText
                    }
                    updateNote(updated)
                },
                onChronologyChanged: { _ in }
            )
            .modifier(HighlightModifier(isHighlighted: isItemHighlighted(note.id)))
            .draggable(BubbleItemDragData(itemId: note.id, itemType: "note"))
            .contextMenu {
                Button("Disconnect from Dialogue") {
                    disconnectItem(itemId: note.id, itemType: "note")
                }
                Divider()
                Button("Edit") { editNote(note) }
                Button("Delete", role: .destructive) { deleteNote(note) }
            }

        case .soundNote(let soundNote):
            SoundNoteBubbleCard(
                soundNote: soundNote,
                isSelected: false,
                startInEditMode: false,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[soundNote.id],
                onTap: { },
                onEdit: { editSoundNote(soundNote) },
                onPlay: { playSoundNote(soundNote) },
                onDelete: { deleteSoundNote(soundNote) },
                onTextChanged: { newText in
                    var updated = soundNote
                    updated.description = newText
                    updateSoundNote(updated)
                },
                onChronologyChanged: { _ in }
            )
            .modifier(HighlightModifier(isHighlighted: isItemHighlighted(soundNote.id)))
            .draggable(BubbleItemDragData(itemId: soundNote.id, itemType: "soundNote"))
            .contextMenu {
                Button("Disconnect from Dialogue") {
                    disconnectItem(itemId: soundNote.id, itemType: "soundNote")
                }
                Divider()
                Button("Edit") { editSoundNote(soundNote) }
                Button("Delete", role: .destructive) { deleteSoundNote(soundNote) }
            }

        case .dialogue:
            EmptyView()  // Dialogues can't be sub-bubbles
        }
    }

    // MARK: - Draggable Item Views

    @ViewBuilder
    private func draggableActionView(action: Action, isHighlighted: Bool = false) -> some View {
        HStack {
            ActionBubbleCard(
                action: action,
                isSelected: false,
                startInEditMode: action.id == newlyAddedItemId,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[action.id],
                onTap: { },
                onEdit: { editAction(action) },
                onDelete: { deleteAction(action) },
                onTextChanged: { newText in
                    var updated = action
                    updated.description = newText
                    updateAction(updated)
                },
                onChronologyChanged: { newIndex in
                    reorderItems(movingItemId: action.id, oldIndex: action.chronologyNumber, newIndex: newIndex)
                },
                onEditModeStarted: { newlyAddedItemId = nil }
            )
            .modifier(HighlightModifier(isHighlighted: isHighlighted))
            .draggable(BubbleItemDragData(itemId: action.id, itemType: "action"))
            Spacer()
        }
    }

    @ViewBuilder
    private func draggableNarrationView(narration: Narration, isHighlighted: Bool = false) -> some View {
        HStack {
            NarrationBubbleCard(
                narration: narration,
                isSelected: false,
                startInEditMode: narration.id == newlyAddedItemId,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[narration.id],
                onTap: { },
                onEdit: { editNarration(narration) },
                onDelete: { deleteNarration(narration) },
                onTextChanged: { newText in
                    var updated = narration
                    updated.text = newText
                    updateNarration(updated)
                },
                onChronologyChanged: { newIndex in
                    reorderItems(movingItemId: narration.id, oldIndex: narration.chronologyNumber, newIndex: newIndex)
                },
                onEditModeStarted: { newlyAddedItemId = nil }
            )
            .modifier(HighlightModifier(isHighlighted: isHighlighted))
            .draggable(BubbleItemDragData(itemId: narration.id, itemType: "narration"))
            Spacer()
        }
    }

    @ViewBuilder
    private func draggableNoteView(note: Note, isHighlighted: Bool = false) -> some View {
        HStack {
            NoteBubbleCard(
                note: note,
                isSelected: false,
                startInEditMode: note.id == newlyAddedItemId,
                projectBasePath: projectBasePath,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[note.id],
                onTap: { },
                onEdit: { editNote(note) },
                onDelete: { deleteNote(note) },
                onTextChanged: { newText in
                    var updated = note
                    if !note.title.isEmpty {
                        updated.title = newText
                    } else {
                        updated.content = newText
                    }
                    updateNote(updated)
                },
                onChronologyChanged: { newIndex in
                    reorderItems(movingItemId: note.id, oldIndex: note.chronologyNumber, newIndex: newIndex)
                },
                onEditModeStarted: { newlyAddedItemId = nil }
            )
            .modifier(HighlightModifier(isHighlighted: isHighlighted))
            .draggable(BubbleItemDragData(itemId: note.id, itemType: "note"))
            Spacer()
        }
    }

    @ViewBuilder
    private func draggableSoundNoteView(soundNote: SoundNote, isHighlighted: Bool = false) -> some View {
        HStack {
            SoundNoteBubbleCard(
                soundNote: soundNote,
                isSelected: false,
                startInEditMode: soundNote.id == newlyAddedItemId,
                characters: project.characters,
                globalIndex: cachedGlobalIndices[soundNote.id],
                onTap: { },
                onEdit: { editSoundNote(soundNote) },
                onPlay: { playSoundNote(soundNote) },
                onDelete: { deleteSoundNote(soundNote) },
                onTextChanged: { newText in
                    var updated = soundNote
                    updated.description = newText
                    updateSoundNote(updated)
                },
                onChronologyChanged: { newIndex in
                    reorderItems(movingItemId: soundNote.id, oldIndex: soundNote.chronologyNumber, newIndex: newIndex)
                },
                onEditModeStarted: { newlyAddedItemId = nil }
            )
            .modifier(HighlightModifier(isHighlighted: isHighlighted))
            .draggable(BubbleItemDragData(itemId: soundNote.id, itemType: "soundNote"))
            Spacer()
        }
    }

    // MARK: - Reorder Items by Chronology

    /// Reorders all items in the scene when one item's chronology number changes.
    /// This shifts other items to avoid duplicate indexes.
    private func reorderItems(movingItemId: String, oldIndex: Int, newIndex: Int) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        // Update dialogues
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].dialogues.count {
            let dialogue = project.sequences[seqIndex].scenes[sceneIndex].dialogues[i]
            if dialogue.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].chronologyNumber = newIndex
                project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].globalChronologyNumber = newIndex
            } else {
                let currentIndex = dialogue.chronologyNumber
                if newIndex < oldIndex {
                    // Moving up: shift items in range [newIndex, oldIndex) down by 1
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].chronologyNumber = currentIndex + 1
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].globalChronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    // Moving down: shift items in range (oldIndex, newIndex] up by 1
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].chronologyNumber = currentIndex - 1
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].globalChronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update actions
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].actions.count {
            let action = project.sequences[seqIndex].scenes[sceneIndex].actions[i]
            if action.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].actions[i].chronologyNumber = newIndex
                project.sequences[seqIndex].scenes[sceneIndex].actions[i].globalChronologyNumber = newIndex
            } else {
                let currentIndex = action.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].chronologyNumber = currentIndex + 1
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].globalChronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].chronologyNumber = currentIndex - 1
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].globalChronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update narrations
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].narrations.count {
            let narration = project.sequences[seqIndex].scenes[sceneIndex].narrations[i]
            if narration.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].narrations[i].chronologyNumber = newIndex
                project.sequences[seqIndex].scenes[sceneIndex].narrations[i].globalChronologyNumber = newIndex
            } else {
                let currentIndex = narration.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].chronologyNumber = currentIndex + 1
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].globalChronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].chronologyNumber = currentIndex - 1
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].globalChronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update notes
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.count {
            let note = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i]
            if note.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i].chronologyNumber = newIndex
            } else {
                let currentIndex = note.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i].chronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i].chronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update sound notes
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].soundNotes.count {
            let soundNote = project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i]
            if soundNote.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i].chronologyNumber = newIndex
            } else {
                let currentIndex = soundNote.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i].chronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i].chronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update selected scene reference
        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        sortRefreshTrigger = UUID()

        // Notify that items were reordered (to sync timeline)
        onItemsReordered?()
    }

    // MARK: - Get All Items Chronologically

    private func getAllItemsChronologically(for scene: DCScene) -> [BubbleItem] {
        var items: [BubbleItem] = []

        // Add all dialogues
        for dialogue in scene.dialogues {
            items.append(.dialogue(dialogue))
        }

        // Add all actions (only those without a parent dialogue)
        for action in scene.actions {
            if action.parentDialogueId == nil {
                items.append(.action(action))
            }
        }

        // Add all narrations (only those without a parent dialogue)
        for narration in scene.narrations {
            if narration.parentDialogueId == nil {
                items.append(.narration(narration))
            }
        }

        // Add all notes (only those without a parent dialogue)
        for note in scene.sceneNotes {
            if note.parentDialogueId == nil {
                items.append(.note(note))
            }
        }

        // Add all sound notes (only those without a parent dialogue)
        for soundNote in scene.soundNotes {
            if soundNote.parentDialogueId == nil {
                items.append(.soundNote(soundNote))
            }
        }

        // Sort by chronology number
        items.sort { $0.chronologyNumber < $1.chronologyNumber }

        return items
    }

    // MARK: - Get Connected Items for a Dialogue

    /// Returns all items connected to a specific dialogue as sub-bubbles
    private func getConnectedItems(for dialogueId: String, in scene: DCScene) -> [BubbleItem] {
        var items: [BubbleItem] = []

        // Find connected actions
        for action in scene.actions {
            if action.parentDialogueId == dialogueId {
                items.append(.action(action))
            }
        }

        // Find connected narrations
        for narration in scene.narrations {
            if narration.parentDialogueId == dialogueId {
                items.append(.narration(narration))
            }
        }

        // Find connected notes
        for note in scene.sceneNotes {
            if note.parentDialogueId == dialogueId {
                items.append(.note(note))
            }
        }

        // Find connected sound notes
        for soundNote in scene.soundNotes {
            if soundNote.parentDialogueId == dialogueId {
                items.append(.soundNote(soundNote))
            }
        }

        // Sort by chronology number
        items.sort { $0.chronologyNumber < $1.chronologyNumber }

        return items
    }

    // MARK: - Cache Rebuild

    /// Rebuilds all cached lookup data for the given scene in a single pass
    /// Maximum chronologyNumber across ALL scenes in the project
    private func globalMaxChronology() -> Int {
        var maxVal = 0
        for seq in project.sequences {
            for scene in seq.scenes {
                maxVal = max(maxVal,
                    scene.dialogues.map(\.chronologyNumber).max() ?? 0,
                    scene.actions.map(\.chronologyNumber).max() ?? 0,
                    scene.narrations.map(\.chronologyNumber).max() ?? 0,
                    scene.sceneNotes.map(\.chronologyNumber).max() ?? 0,
                    scene.soundNotes.map(\.chronologyNumber).max() ?? 0
                )
            }
        }
        return maxVal
    }

    /// Count of top-level bubble items in all scenes before the given scene
    private func globalIndexOffset(for sceneId: String) -> Int {
        var count = 0
        for seq in project.sequences {
            for scene in seq.scenes {
                if scene.id == sceneId { return count }
                // Count top-level items only (parentDialogueId == nil for non-dialogue types)
                count += scene.dialogues.count
                count += scene.actions.filter { $0.parentDialogueId == nil }.count
                count += scene.narrations.filter { $0.parentDialogueId == nil }.count
                count += scene.sceneNotes.filter { $0.parentDialogueId == nil }.count
                count += scene.soundNotes.filter { $0.parentDialogueId == nil }.count
            }
        }
        return count
    }

    private func rebuildBubbleCache(for scene: DCScene) {
        // 1. Build chronological items (same logic as getAllItemsChronologically)
        var items: [BubbleItem] = []
        for dialogue in scene.dialogues {
            items.append(.dialogue(dialogue))
        }
        for action in scene.actions where action.parentDialogueId == nil {
            items.append(.action(action))
        }
        for narration in scene.narrations where narration.parentDialogueId == nil {
            items.append(.narration(narration))
        }
        for note in scene.sceneNotes where note.parentDialogueId == nil {
            items.append(.note(note))
        }
        for soundNote in scene.soundNotes where soundNote.parentDialogueId == nil {
            items.append(.soundNote(soundNote))
        }
        items.sort { $0.chronologyNumber < $1.chronologyNumber }
        cachedChronologicalItems = items

        // 1b. Build global index cache
        let offset = globalIndexOffset(for: scene.id)
        var indices: [String: Int] = [:]
        for (i, item) in items.enumerated() {
            indices[item.id] = offset + i + 1
        }
        cachedGlobalIndices = indices

        // 2. Build connected items index (parentDialogueId → [BubbleItem])
        var connected: [String: [BubbleItem]] = [:]
        for action in scene.actions {
            if let parentId = action.parentDialogueId {
                connected[parentId, default: []].append(.action(action))
            }
        }
        for narration in scene.narrations {
            if let parentId = narration.parentDialogueId {
                connected[parentId, default: []].append(.narration(narration))
            }
        }
        for note in scene.sceneNotes {
            if let parentId = note.parentDialogueId {
                connected[parentId, default: []].append(.note(note))
            }
        }
        for soundNote in scene.soundNotes {
            if let parentId = soundNote.parentDialogueId {
                connected[parentId, default: []].append(.soundNote(soundNote))
            }
        }
        // Sort each group by chronology number
        for key in connected.keys {
            connected[key]?.sort { $0.chronologyNumber < $1.chronologyNumber }
        }
        cachedConnectedItems = connected

        // 3. Build character name → Character dictionary
        cachedCharacterMap = Dictionary(uniqueKeysWithValues: project.characters.map { ($0.name, $0) })
    }

    // MARK: - Actions

    private func updateDialogue(_ updated: Dialogue) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
              let dialogueIndex = project.sequences[seqIndex].scenes[sceneIndex].dialogues.firstIndex(where: { $0.id == updated.id })
        else { return }

        project.sequences[seqIndex].scenes[sceneIndex].dialogues[dialogueIndex] = updated

        // Update selected scene reference
        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        onContentChanged?()
    }

    /// Scroll to a newly added item after a brief delay for the view to settle
    private func scrollToNewItem(_ itemId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToItemId = itemId
        }
    }

    private func addDialogue(for characterName: String) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newDialogue = Dialogue(
            character: characterName,
            text: "",
            chronologyNumber: maxChronology + 1
        )

        // Find and update scene in project
        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].dialogues.append(newDialogue)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newDialogue.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newDialogue.id)
            onContentChanged?()
        }
    }

    private func deleteDialogue(_ dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].dialogues.removeAll { $0.id == dialogue.id }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]

            // Clear selection if deleted dialogue was selected
            if selectedDialogue?.id == dialogue.id {
                selectedDialogue = nil
            }

            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func addAction() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newAction = Action(
            uuid: UUID().uuidString,
            description: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: []
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions.append(newAction)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newAction.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newAction.id)
            onContentChanged?()
        }
    }

    private func addNarration() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNarration = Narration(
            uuid: UUID().uuidString,
            text: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: []
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations.append(newNarration)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNarration.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newNarration.id)
            onContentChanged?()
        }
    }

    private func addNote() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNote = Note(
            uuid: UUID().uuidString,
            content: "",
            noteType: "text",
            chronologyNumber: maxChronology + 1
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.append(newNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newNote.id)
            onContentChanged?()
        }
    }

    private func addSoundNote() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newSoundNote = SoundNote(
            uuid: UUID().uuidString,
            description: "",
            soundType: "ambient",
            chronologyNumber: maxChronology + 1
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes.append(newSoundNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newSoundNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newSoundNote.id)
            onContentChanged?()
        }
    }

    // MARK: - Add Connected Items (directly to a dialogue)

    private func addConnectedAction(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newAction = Action(
            uuid: UUID().uuidString,
            description: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: [],
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions.append(newAction)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newAction.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    private func addConnectedNarration(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNarration = Narration(
            uuid: UUID().uuidString,
            text: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: [],
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations.append(newNarration)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNarration.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    private func addConnectedNote(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNote = Note(
            uuid: UUID().uuidString,
            content: "",
            noteType: "text",
            chronologyNumber: maxChronology + 1,
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.append(newNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    private func addConnectedSoundNote(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newSoundNote = SoundNote(
            uuid: UUID().uuidString,
            description: "",
            soundType: "ambient",
            chronologyNumber: maxChronology + 1,
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes.append(newSoundNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newSoundNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    private func editAction(_ action: Action) {
        editingAction = action
    }

    private func deleteAction(_ action: Action) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions.removeAll { $0.uuid == action.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func editNarration(_ narration: Narration) {
        editingNarration = narration
    }

    private func deleteNarration(_ narration: Narration) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations.removeAll { $0.uuid == narration.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func editNote(_ note: Note) {
        editingNote = note
    }

    private func deleteNote(_ note: Note) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.removeAll { $0.uuid == note.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func editSoundNote(_ soundNote: SoundNote) {
        editingSoundNote = soundNote
    }

    private func deleteSoundNote(_ soundNote: SoundNote) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes.removeAll { $0.uuid == soundNote.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func updateAction(_ updated: Action) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let actionIndex = project.sequences[seqIndex].scenes[sceneIndex].actions.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions[actionIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func updateNarration(_ updated: Narration) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let narrationIndex = project.sequences[seqIndex].scenes[sceneIndex].narrations.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations[narrationIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func updateNote(_ updated: Note) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let noteIndex = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[noteIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func updateSoundNote(_ updated: SoundNote) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let soundNoteIndex = project.sequences[seqIndex].scenes[sceneIndex].soundNotes.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes[soundNoteIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    private func playSoundNote(_ soundNote: SoundNote) {
        // TODO: Implement via TTS service
    }

    private func playDialogue(_ dialogue: Dialogue) {
        // If audio file exists on disk, play it
        if let audioPath = dialogue.audioFilePath,
           let basePath = projectBasePath {
            let fileURL = basePath.appendingPathComponent(audioPath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    stopDialogue()
                    audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                    audioPlayer?.delegate = BubbleAudioDelegate.shared
                    BubbleAudioDelegate.shared.onFinished = { [weak audioPlayer] in
                        if audioPlayer != nil {
                            playingDialogueId = nil
                        }
                    }
                    audioPlayer?.play()
                    playingDialogueId = dialogue.id
                } catch {
                    print("Error playing dialogue audio: \(error)")
                }
                return
            }
        }
        // No saved audio — generate it
        Task { await generateAndPlayDialogue(dialogue) }
    }

    private func stopDialogue() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingDialogueId = nil
    }

    private func generateAndPlayDialogue(_ dialogue: Dialogue) async {
        let dialogueId = dialogue.id
        generatingAudioIds.insert(dialogueId)

        do {
            // Look up character voice
            let character = cachedCharacterMap[dialogue.character]
            let voiceName = character?.voice ?? (character?.gender.lowercased() == "female" ? "Kore" : "Charon")

            // Build emotion from voiceStyle + tags
            var emotionParts: [String] = []
            if let style = character?.voiceStyle, !style.isEmpty {
                emotionParts.append(style)
            }
            if !dialogue.tags.isEmpty {
                emotionParts.append(contentsOf: dialogue.tags)
            }
            let emotion = emotionParts.isEmpty ? nil : "Say \(emotionParts.joined(separator: ", "))"

            // Strip HTML from dialogue text
            var text = dialogue.text
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<") {
                let tagPattern = "<[^>]+>"
                if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                    let range = NSRange(location: 0, length: text.utf16.count)
                    text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            let request = SpeechGenerationRequest(
                text: text,
                provider: .google,
                voiceName: voiceName,
                emotion: emotion,
                characterName: dialogue.character,
                voiceTone: character?.voiceTone,
                voicePersonality: character?.voicePersonality,
                voicePace: character?.voicePace,
                voiceAccent: character?.voiceAccent,
                voiceAge: character?.voiceAge
            )

            let response = try await AIServiceClient.shared.generateSpeech(request)

            // Save audio file
            if let basePath = projectBasePath {
                let audioDir = basePath.appendingPathComponent("assets/audio/dialogues")
                try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

                let fileName = "\(dialogueId).wav"
                let filePath = audioDir.appendingPathComponent(fileName)
                try response.audioData.write(to: filePath)

                // Update dialogue with audio path
                var updated = dialogue
                updated.audioFilePath = "assets/audio/dialogues/\(fileName)"
                updateDialogue(updated)
            }

            // Play the audio
            stopDialogue()
            audioPlayer = try AVAudioPlayer(data: response.audioData)
            audioPlayer?.delegate = BubbleAudioDelegate.shared
            BubbleAudioDelegate.shared.onFinished = { [weak audioPlayer] in
                if audioPlayer != nil {
                    playingDialogueId = nil
                }
            }
            audioPlayer?.play()
            playingDialogueId = dialogueId

        } catch {
            print("Error generating dialogue audio: \(error)")
            audioErrorMessage = error.localizedDescription
        }

        generatingAudioIds.remove(dialogueId)
    }

    // MARK: - Emotion Detection

    private func detectDialogueEmotion(_ dialogue: Dialogue) async {
        let dialogueId = dialogue.id
        detectingEmotionIds.insert(dialogueId)

        do {
            // Strip HTML from text
            var text = dialogue.text
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<") {
                let tagPattern = "<[^>]+>"
                if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                    let range = NSRange(location: 0, length: text.utf16.count)
                    text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            guard !text.isEmpty else {
                detectingEmotionIds.remove(dialogueId)
                return
            }

            let characterName = dialogue.character
            let prompt = """
            Analyze the emotion/tone of this dialogue line spoken by \(characterName):

            "\(text)"

            Return ONLY a comma-separated list of 1-3 emotion tags (single words, lowercase).
            Examples: angry, sarcastic, tender, fearful, joyful, melancholic, anxious, determined, playful, bitter, hopeful, resigned, threatening, pleading, nostalgic, disgusted, confused, amused, defiant, vulnerable
            Do not include any other text, explanation, or formatting.
            """

            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 50,
                temperature: 0.3
            )

            let response = try await AIServiceClient.shared.generateText(request)
            let emotionText = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let tags = emotionText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count < 20 }

            if !tags.isEmpty {
                var updated = dialogue
                updated.tags = tags
                updateDialogue(updated)
            }
        } catch {
            print("Error detecting dialogue emotion: \(error)")
        }

        detectingEmotionIds.remove(dialogueId)
    }

    // MARK: - Handle Drop

    /// Handles the drop of a dragged item onto a dialogue
    private func handleDrop(providers: [NSItemProvider], dialogueId: String) -> Bool {
        guard let provider = providers.first else { return false }

        // Try to load as plain text (our encoded format)
        if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, error in
                DispatchQueue.main.async {
                    if let data = data as? Data, let encoded = String(data: data, encoding: .utf8),
                       let dragData = BubbleItemDragData.decode(encoded) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    } else if let string = data as? String,
                              let dragData = BubbleItemDragData.decode(string) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    }
                }
            }
            return true
        }

        // Try loading as UTF8 text
        if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
            provider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { data, error in
                DispatchQueue.main.async {
                    if let data = data as? Data, let encoded = String(data: data, encoding: .utf8),
                       let dragData = BubbleItemDragData.decode(encoded) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    } else if let string = data as? String,
                              let dragData = BubbleItemDragData.decode(string) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    }
                }
            }
            return true
        }

        return false
    }

    // MARK: - Connect/Disconnect Items

    /// Connects an item to a dialogue as a sub-bubble
    private func connectItem(itemId: String, itemType: String, toDialogueId dialogueId: String) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        switch itemType {
        case "action":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].actions.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].actions[idx].parentDialogueId = dialogueId
            }
        case "narration":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].narrations.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].narrations[idx].parentDialogueId = dialogueId
            }
        case "note":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[idx].parentDialogueId = dialogueId
            }
        case "soundNote":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].soundNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].soundNotes[idx].parentDialogueId = dialogueId
            }
        default:
            break
        }

        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        sortRefreshTrigger = UUID()
        onContentChanged?()
    }

    /// Disconnects an item from its parent dialogue
    private func disconnectItem(itemId: String, itemType: String) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        switch itemType {
        case "action":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].actions.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].actions[idx].parentDialogueId = nil
            }
        case "narration":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].narrations.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].narrations[idx].parentDialogueId = nil
            }
        case "note":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[idx].parentDialogueId = nil
            }
        case "soundNote":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].soundNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].soundNotes[idx].parentDialogueId = nil
            }
        default:
            break
        }

        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        sortRefreshTrigger = UUID()
        onContentChanged?()
    }
}

// MARK: - BubbleItem Enum

/// Represents any item that can appear in the bubble view
enum BubbleItem: Identifiable {
    case dialogue(Dialogue)
    case action(Action)
    case narration(Narration)
    case note(Note)
    case soundNote(SoundNote)

    var id: String {
        switch self {
        case .dialogue(let d): return d.id
        case .action(let a): return a.id
        case .narration(let n): return n.id
        case .note(let n): return n.id
        case .soundNote(let s): return s.id
        }
    }

    var chronologyNumber: Int {
        switch self {
        case .dialogue(let d): return d.chronologyNumber
        case .action(let a): return a.chronologyNumber
        case .narration(let n): return n.chronologyNumber
        case .note(let n): return n.chronologyNumber
        case .soundNote(let s): return s.chronologyNumber
        }
    }

    var parentDialogueId: String? {
        switch self {
        case .dialogue: return nil  // Dialogues can't be children
        case .action(let a): return a.parentDialogueId
        case .narration(let n): return n.parentDialogueId
        case .note(let n): return n.parentDialogueId
        case .soundNote(let s): return s.parentDialogueId
        }
    }

    var isDialogue: Bool {
        if case .dialogue = self { return true }
        return false
    }

    var itemTypeString: String {
        switch self {
        case .dialogue: return "dialogue"
        case .action: return "action"
        case .narration: return "narration"
        case .note: return "note"
        case .soundNote: return "soundNote"
        }
    }
}

// MARK: - Drag Data for Bubble Items

/// Transferable wrapper for bubble item drag data
struct BubbleItemDragData: Codable, Transferable, Equatable {
    let itemId: String
    let itemType: String  // "action", "narration", "note", "soundNote"

    /// Encode to string for drag
    var encoded: String {
        "\(itemType):\(itemId)"
    }

    /// Decode from string
    static func decode(_ string: String) -> BubbleItemDragData? {
        let parts = string.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return BubbleItemDragData(itemId: String(parts[1]), itemType: String(parts[0]))
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

// MARK: - Filter Toggle Button

private struct FilterToggleButton: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isOn ? color.opacity(0.2) : Color.clear)
            .foregroundColor(isOn ? color : .secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isOn ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(isOn ? "Hide \(title)" : "Show \(title)")
    }
}

// MARK: - Edit Dialogue Sheet

private struct EditDialogueSheet: View {
    let dialogue: Dialogue
    let characters: [Character]
    let projectBasePath: URL?
    let onSave: (Dialogue) -> Void
    let onCancel: () -> Void
    var onCharacterColorChanged: ((String, String) -> Void)?

    @State private var editedDialogue: Dialogue
    @State private var tagInput: String = ""
    @State private var bubbleColor: Color
    @FocusState private var textFocused: Bool

    private var selectedCharacter: Character? {
        characters.first(where: { $0.name == editedDialogue.character })
    }

    private var hasChanges: Bool {
        editedDialogue.character != dialogue.character ||
        editedDialogue.text != dialogue.text ||
        editedDialogue.tags != dialogue.tags ||
        editedDialogue.chronologyNumber != dialogue.chronologyNumber
    }

    init(
        dialogue: Dialogue,
        characters: [Character],
        projectBasePath: URL?,
        onSave: @escaping (Dialogue) -> Void,
        onCancel: @escaping () -> Void,
        onCharacterColorChanged: ((String, String) -> Void)? = nil
    ) {
        self.dialogue = dialogue
        self.characters = characters
        self.projectBasePath = projectBasePath
        self.onSave = onSave
        self.onCancel = onCancel
        self.onCharacterColorChanged = onCharacterColorChanged
        self._editedDialogue = State(initialValue: dialogue)
        self._tagInput = State(initialValue: dialogue.tags.joined(separator: ", "))
        let charColor = characters.first(where: { $0.name == dialogue.character })?.color ?? "#5d5d5d"
        self._bubbleColor = State(initialValue: Color(hex: charColor))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            header

            ScrollView {
                VStack(spacing: 20) {
                    // Character + Order row
                    HStack(spacing: 16) {
                        characterCard
                        orderCard
                    }

                    // Bubble color
                    bubbleColorCard

                    // Dialogue text
                    dialogueCard

                    // Tags
                    tagsCard

                    // Audio info (read-only, only if present)
                    if editedDialogue.audioFilePath != nil || editedDialogue.manualDuration != nil {
                        audioCard
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Character avatar preview
            CharacterAvatarView(
                character: selectedCharacter,
                characterName: editedDialogue.character,
                size: 28,
                projectBasePath: projectBasePath
            )

            VStack(alignment: .leading, spacing: 1) {
                Text("Edit Dialogue")
                    .font(.system(size: 13, weight: .semibold))
                Text("#\(editedDialogue.chronologyNumber) \u{2022} \(editedDialogue.character)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cancel") { onCancel() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12, weight: .medium))
                .keyboardShortcut(.cancelAction)

            Button(action: { onSave(editedDialogue) }) {
                Text("Save")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(hasChanges ? Color.accentColor : Color.accentColor.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Character Card

    private var characterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("CHARACTER")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
                ForEach(characters) { character in
                    let isSelected = editedDialogue.character == character.name
                    Button(action: {
                        editedDialogue.character = character.name
                        bubbleColor = Color(hex: character.color)
                    }) {
                        VStack(spacing: 3) {
                            CharacterAvatarView(
                                character: character,
                                characterName: character.name,
                                size: 32,
                                projectBasePath: projectBasePath
                            )
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            )

                            Text(character.name)
                                .font(.system(size: 8, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .accentColor : .secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 52)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Bubble Color Card

    private var bubbleColorCard: some View {
        HStack(spacing: 12) {
            Label {
                Text("BUBBLE COLOR")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
            }

            Spacer()

            // Color preview circle
            Circle()
                .fill(bubbleColor)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1))

            ColorPicker("", selection: $bubbleColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)
                .onChange(of: bubbleColor) { _, newColor in
                    let hex = newColor.hexString
                    onCharacterColorChanged?(editedDialogue.character, hex)
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Order Card

    private var orderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("ORDER")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                // Large number display
                Text("\(editedDialogue.chronologyNumber)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Stepper controls
                HStack(spacing: 12) {
                    Button(action: {
                        if editedDialogue.chronologyNumber > 1 {
                            editedDialogue.chronologyNumber -= 1
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(NSColor.controlBackgroundColor)))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(editedDialogue.chronologyNumber <= 1)

                    Button(action: {
                        editedDialogue.chronologyNumber += 1
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(NSColor.controlBackgroundColor)))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(width: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Dialogue Card

    private var dialogueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("DIALOGUE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
            }

            TextEditor(text: $editedDialogue.text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 100, maxHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
                )
                .focused($textFocused)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Tags Card

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("TAGS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "tag.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
            }

            // Existing tags as removable chips
            if !editedDialogue.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(editedDialogue.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))

                            Button(action: {
                                editedDialogue.tags.removeAll { $0 == tag }
                                tagInput = editedDialogue.tags.joined(separator: ", ")
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                    }
                }
            }

            // Tag input field
            TextField("Add tags (comma separated)...", text: $tagInput)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.quaternarySystemFill))
                )
                .onChange(of: tagInput) { _, newValue in
                    editedDialogue.tags = newValue
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Audio Card

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("AUDIO")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "waveform")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
            }

            HStack(spacing: 16) {
                if let duration = editedDialogue.manualDuration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.2f", duration))s")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }

                if let audioPath = editedDialogue.audioFilePath {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(URL(fileURLWithPath: audioPath).lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}


// MARK: - Edit Action Sheet

private struct EditActionSheet: View {
    let action: Action
    let onSave: (Action) -> Void
    let onCancel: () -> Void

    @State private var editedAction: Action

    init(
        action: Action,
        onSave: @escaping (Action) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.action = action
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedAction = State(initialValue: action)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Action")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(editedAction) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Editor content
            Form {
                // Action description
                Section("Description") {
                    TextEditor(text: $editedAction.description)
                        .frame(minHeight: 100)
                }

                // Tags
                Section("Tags") {
                    TextField("Tags (comma separated)", text: Binding(
                        get: { editedAction.tags.joined(separator: ", ") },
                        set: { editedAction.tags = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                    ))
                }

                // Characters involved
                Section("Characters") {
                    TextField("Characters (comma separated)", text: Binding(
                        get: { editedAction.characters.joined(separator: ", ") },
                        set: { editedAction.characters = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                    ))
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Edit Narration Sheet

private struct EditNarrationSheet: View {
    let narration: Narration
    let onSave: (Narration) -> Void
    let onCancel: () -> Void

    @State private var editedNarration: Narration

    init(
        narration: Narration,
        onSave: @escaping (Narration) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.narration = narration
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedNarration = State(initialValue: narration)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Narration")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(editedNarration) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Editor content
            Form {
                // Narration text
                Section("Text") {
                    TextEditor(text: $editedNarration.text)
                        .frame(minHeight: 100)
                }

                // Tags
                Section("Tags") {
                    TextField("Tags (comma separated)", text: Binding(
                        get: { editedNarration.tags.joined(separator: ", ") },
                        set: { editedNarration.tags = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                    ))
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Edit Note Sheet

private struct EditNoteSheet: View {
    let note: Note
    let onSave: (Note) -> Void
    let onCancel: () -> Void

    @State private var editedNote: Note

    init(
        note: Note,
        onSave: @escaping (Note) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.note = note
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedNote = State(initialValue: note)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Note")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(editedNote) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Editor content
            Form {
                // Title
                Section("Title") {
                    TextField("Note title", text: $editedNote.title)
                }

                // Note content
                Section("Content") {
                    TextEditor(text: $editedNote.content)
                        .frame(minHeight: 100)
                }

                // Note type
                Section("Type") {
                    Picker("Note Type", selection: $editedNote.noteType) {
                        Text("Text").tag("text")
                        Text("Image").tag("image")
                        Text("Link").tag("link")
                        Text("YouTube").tag("youtube")
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Highlight Modifier

/// Applies a visual highlight effect to bubble items when they are selected from the timeline
private struct HighlightModifier: ViewModifier {
    let isHighlighted: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: isHighlighted ? 3 : 0)
                    .shadow(color: Color.accentColor.opacity(0.6), radius: isHighlighted ? 10 : 0)
            )
            .animation(.easeOut(duration: 0.15), value: isHighlighted)
    }
}

// MARK: - Edit Sound Note Sheet

private struct EditSoundNoteSheet: View {
    let soundNote: SoundNote
    let onSave: (SoundNote) -> Void
    let onCancel: () -> Void

    @State private var editedSoundNote: SoundNote

    init(
        soundNote: SoundNote,
        onSave: @escaping (SoundNote) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.soundNote = soundNote
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedSoundNote = State(initialValue: soundNote)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Sound Note")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(editedSoundNote) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Editor content
            Form {
                // Sound description
                Section("Description") {
                    TextEditor(text: $editedSoundNote.description)
                        .frame(minHeight: 100)
                }

                // Sound type
                Section("Sound Type") {
                    Picker("Type", selection: $editedSoundNote.soundType) {
                        Text("Ambient").tag("ambient")
                        Text("Music").tag("music")
                        Text("Effects").tag("effects")
                        Text("Dialogue SFX").tag("dialogue_sfx")
                    }
                }

                // Volume
                Section("Volume") {
                    Slider(value: Binding(
                        get: { Double(editedSoundNote.volume) },
                        set: { editedSoundNote.volume = Int($0) }
                    ), in: 0...100, step: 1)
                    Text("\(editedSoundNote.volume)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Tags
                Section("Tags") {
                    TextField("Tags (comma separated)", text: Binding(
                        get: { editedSoundNote.tags.joined(separator: ", ") },
                        set: { editedSoundNote.tags = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                    ))
                }
            }
            .padding()
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Bubble Shortcuts Popover

struct BubbleShortcutsPopoverView: View {
    private let shortcuts: [(key: String, description: String)] = [
        ("Cmd + D", "Add Dialogue"),
        ("Cmd + Shift + A", "Add Action"),
        ("Cmd + Shift + N", "Add Narration"),
        ("Cmd + Shift + O", "Add Note"),
        ("Cmd + Shift + S", "Add Sound Note"),
        ("1 – 9, 0", "Select character (in picker)"),
        ("\u{2190} \u{2192} arrows", "Navigate characters (in picker)"),
        ("Return", "Confirm selection (in picker)"),
        ("Esc", "Dismiss picker"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Bubble View Shortcuts")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                    HStack {
                        Text(shortcut.key)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 150, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                            )

                        Text(shortcut.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }
}

// MARK: - Audio Player Delegate for BubbleView

class BubbleAudioDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = BubbleAudioDelegate()
    var onFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinished?()
        }
    }
}

