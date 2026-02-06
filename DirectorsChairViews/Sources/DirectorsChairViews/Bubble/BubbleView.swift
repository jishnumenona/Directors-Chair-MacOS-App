// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/BubbleView.swift
//
// Main Bubble View - dialogue editing interface
//
// Layout:
// - Main: Dialogue bubbles (scrollable)
// - Right: Dialogue editor panel (optional)

import SwiftUI
import DirectorsChairCore
import UniformTypeIdentifiers

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
    @State private var showEditorPanel = true
    @State private var sortRefreshTrigger = UUID()
    @State private var newlyAddedItemId: String? = nil  // Track newly added items for auto-edit
    @State private var dropTargetDialogueId: String? = nil  // Track which dialogue is being targeted for drop

    // Highlight state for cross-view synchronization
    @State private var scrollToItemId: String? = nil
    @State private var hasScrolledToHighlight: Bool = false

    // Cached data for performance (rebuilt on scene switch / reorder)
    @State private var cachedChronologicalItems: [BubbleItem] = []
    @State private var cachedConnectedItems: [String: [BubbleItem]] = [:]  // dialogueId → children
    @State private var cachedCharacterMap: [String: Character] = [:]  // name → Character

    let projectBasePath: URL?

    /// Optional tuple for highlighting an item from external source (e.g., timeline double-click)
    /// Format: (itemId, itemType, sceneName) where itemType is "dialogue", "action", "narration", etc.
    let highlightedBubbleItem: (id: String, type: String, sceneName: String)?

    /// Callback when items are reordered (to sync with timeline)
    let onItemsReordered: (() -> Void)?

    /// Callback when content is added, updated, or deleted (to sync with timeline)
    let onContentChanged: (() -> Void)?

    /// Externally selected scene name (e.g., from OutlineTab sidebar via AppCoordinator)
    /// When this changes, BubbleView syncs its internal selectedScene to match.
    let externalSelectedSceneName: String?

    public init(
        project: Binding<Project>,
        projectBasePath: URL? = nil,
        highlightedBubbleItem: (id: String, type: String, sceneName: String)? = nil,
        onItemsReordered: (() -> Void)? = nil,
        onContentChanged: (() -> Void)? = nil,
        externalSelectedSceneName: String? = nil
    ) {
        self._project = project
        self.projectBasePath = projectBasePath
        self.highlightedBubbleItem = highlightedBubbleItem
        self.onItemsReordered = onItemsReordered
        self.onContentChanged = onContentChanged
        self.externalSelectedSceneName = externalSelectedSceneName
    }

    public var body: some View {
        HSplitView {
            // Main: Bubble content
            VStack(spacing: 0) {
                // Toolbar
                toolbar

                // Bubble scroll area
                bubbleScrollArea
                    .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 400, idealWidth: 800, maxHeight: .infinity)

            // Right: Editor panel (if showing and dialogue selected)
            if showEditorPanel, let dialogue = selectedDialogue {
                DialogueEditorPanel(
                    dialogue: dialogue,
                    characters: project.characters,
                    projectBasePath: projectBasePath,
                    onSave: { updated in
                        updateDialogue(updated)
                    },
                    onCancel: {
                        selectedDialogue = nil
                    }
                )
                .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .sheet(item: $editingDialogue) { dialogue in
            EditDialogueSheet(
                dialogue: dialogue,
                characters: project.characters,
                projectBasePath: projectBasePath,
                onSave: { updated in
                    updateDialogue(updated)
                    editingDialogue = nil
                },
                onCancel: {
                    editingDialogue = nil
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
        .onAppear {
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
                }
            }

            // Scroll to the item immediately
            scrollToItemId = highlighted.id
            hasScrolledToHighlight = true
        }
        .onChange(of: externalSelectedSceneName) { newSceneName in
            guard let sceneName = newSceneName else { return }
            // Only switch if it's a different scene
            guard selectedScene?.name != sceneName else { return }
            // Find the scene by name across all sequences
            for sequence in project.sequences {
                if let targetScene = sequence.scenes.first(where: { $0.name == sceneName }) {
                    selectedScene = targetScene
                    return
                }
            }
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

            // Editor panel toggle
            Toggle(isOn: $showEditorPanel) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .help("Show editor panel")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
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
            addDialogue()
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

    // MARK: - Dialogue View with Drop Target and Sub-Bubbles

    @ViewBuilder
    private func dialogueItemView(dialogue: Dialogue, scene: DCScene, isHighlighted: Bool = false) -> some View {
        let character = cachedCharacterMap[dialogue.character]
        let isPrimary = scene.primaryCharacter == dialogue.character
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
                    onTap: { selectedDialogue = dialogue },
                    onDoubleTap: { editingDialogue = dialogue },
                    onEdit: { editingDialogue = dialogue },
                    onDelete: { deleteDialogue(dialogue) },
                    onPlay: { playDialogue(dialogue) },
                    onStop: { stopDialogue() },
                    onTextChanged: { newText in
                        var updated = dialogue
                        updated.text = newText
                        updateDialogue(updated)
                    },
                    onChronologyChanged: { newIndex in
                        reorderItems(movingItemId: dialogue.id, oldIndex: dialogue.chronologyNumber, newIndex: newIndex)
                    },
                    onEditModeStarted: { newlyAddedItemId = nil }
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

        // TODO: Trigger save via EventBus
    }

    private func addDialogue() {
        guard var scene = selectedScene else { return }

        let newDialogue = Dialogue(
            character: project.characters.first?.name ?? "Unknown",
            text: "",
            chronologyNumber: (scene.dialogues.map(\.chronologyNumber).max() ?? 0) + 1
        )

        // Find and update scene in project
        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].dialogues.append(newDialogue)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newDialogue.id
            sortRefreshTrigger = UUID()
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

            onContentChanged?()
        }
    }

    private func addAction() {
        guard let scene = selectedScene else { return }

        let maxChronology = max(
            scene.dialogues.map(\.chronologyNumber).max() ?? 0,
            scene.actions.map(\.chronologyNumber).max() ?? 0,
            scene.narrations.map(\.chronologyNumber).max() ?? 0,
            scene.sceneNotes.map(\.chronologyNumber).max() ?? 0,
            scene.soundNotes.map(\.chronologyNumber).max() ?? 0
        )

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
            sortRefreshTrigger = UUID()
            onContentChanged?()
        }
    }

    private func addNarration() {
        guard let scene = selectedScene else { return }

        let maxChronology = max(
            scene.dialogues.map(\.chronologyNumber).max() ?? 0,
            scene.actions.map(\.chronologyNumber).max() ?? 0,
            scene.narrations.map(\.chronologyNumber).max() ?? 0,
            scene.sceneNotes.map(\.chronologyNumber).max() ?? 0,
            scene.soundNotes.map(\.chronologyNumber).max() ?? 0
        )

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
            sortRefreshTrigger = UUID()
            onContentChanged?()
        }
    }

    private func addNote() {
        guard let scene = selectedScene else { return }

        let maxChronology = max(
            scene.dialogues.map(\.chronologyNumber).max() ?? 0,
            scene.actions.map(\.chronologyNumber).max() ?? 0,
            scene.narrations.map(\.chronologyNumber).max() ?? 0,
            scene.sceneNotes.map(\.chronologyNumber).max() ?? 0,
            scene.soundNotes.map(\.chronologyNumber).max() ?? 0
        )

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
            sortRefreshTrigger = UUID()
            onContentChanged?()
        }
    }

    private func addSoundNote() {
        guard let scene = selectedScene else { return }

        let maxChronology = max(
            scene.dialogues.map(\.chronologyNumber).max() ?? 0,
            scene.actions.map(\.chronologyNumber).max() ?? 0,
            scene.narrations.map(\.chronologyNumber).max() ?? 0,
            scene.sceneNotes.map(\.chronologyNumber).max() ?? 0,
            scene.soundNotes.map(\.chronologyNumber).max() ?? 0
        )

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
            sortRefreshTrigger = UUID()
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
        }
    }

    private func playSoundNote(_ soundNote: SoundNote) {
        // TODO: Implement via TTS service
    }

    private func playDialogue(_ dialogue: Dialogue) {
        // TODO: Implement via TTS service
    }

    private func stopDialogue() {
        // TODO: Implement
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
        sortRefreshTrigger = UUID()
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
        sortRefreshTrigger = UUID()
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

    @State private var editedDialogue: Dialogue

    init(
        dialogue: Dialogue,
        characters: [Character],
        projectBasePath: URL?,
        onSave: @escaping (Dialogue) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.dialogue = dialogue
        self.characters = characters
        self.projectBasePath = projectBasePath
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedDialogue = State(initialValue: dialogue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Dialogue")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(editedDialogue) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Editor content
            Form {
                // Character picker
                Picker("Character", selection: $editedDialogue.character) {
                    ForEach(characters) { character in
                        Text(character.name).tag(character.name)
                    }
                }

                // Dialogue text
                Section("Dialogue") {
                    TextEditor(text: $editedDialogue.text)
                        .frame(minHeight: 100)
                }

                // Tags
                Section("Tags") {
                    TextField("Tags (comma separated)", text: Binding(
                        get: { editedDialogue.tags.joined(separator: ", ") },
                        set: { editedDialogue.tags = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                    ))
                }

                // Audio settings
                Section("Audio") {
                    if let duration = editedDialogue.manualDuration {
                        LabeledContent("Duration", value: "\(String(format: "%.2f", duration))s")
                    }
                    if let audioPath = editedDialogue.audioFilePath {
                        LabeledContent("Audio File", value: audioPath)
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
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

