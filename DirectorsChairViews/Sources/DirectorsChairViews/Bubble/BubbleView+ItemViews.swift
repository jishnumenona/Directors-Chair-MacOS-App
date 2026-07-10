//
// BubbleView+ItemViews.swift
//
// Extracted from BubbleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import UniformTypeIdentifiers
import AVFoundation

extension BubbleView {

    // MARK: - Filter Buttons

    var filterButtons: some View {
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

    var bubbleScrollArea: some View {
        Group {
            if let scene = selectedScene {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(cachedChronologicalItems, id: \.id) { item in
                                reorderDropZone(insertBefore: item.chronologyNumber)
                                itemView(for: item, in: scene)
                                    .id(item.id)  // ID for ScrollViewReader
                                    .accessibilityIdentifier("bubble-item-\(item.id)")
                                    .padding(.vertical, 4)
                            }
                            // Trailing zone: drop here to move an item to the end
                            reorderDropZone(insertBefore: nil)

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
                        // Perf Tier 2 (audit C4/M1): no .id(sortRefreshTrigger)
                        // teardown here. The ForEach already diffs by stable
                        // item.id, and sortRefreshTrigger's onChange rebuilds
                        // cachedChronologicalItems — so reorders re-diff the
                        // rows in place instead of discarding the whole list.
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
    var backgroundView: some View {
        if showBackground, let scene = selectedScene, let locationName = scene.location {
            // TODO: Load actual location image
            Color.gray.opacity(0.1)
        } else {
            Color.clear
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    var addItemsContextMenu: some View {
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
    func connectedItemsContextMenu(for dialogue: Dialogue) -> some View {
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
    func isItemHighlighted(_ itemId: String) -> Bool {
        return highlightedBubbleItem?.id == itemId
    }

    @ViewBuilder
    func itemView(for item: BubbleItem, in scene: DCScene) -> some View {
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
    func isLeftAligned(_ characterName: String, in scene: DCScene) -> Bool {
        let isPrimary = scene.primaryCharacter == characterName
        let isOverridden = leftAlignedOverrides.contains(characterName)
        return isPrimary != isOverridden
    }

    // MARK: - Dialogue View with Drop Target and Sub-Bubbles

    @ViewBuilder
    func dialogueItemView(dialogue: Dialogue, scene: DCScene, isHighlighted: Bool = false) -> some View {
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
                .draggable(BubbleItemDragData(itemId: dialogue.id, itemType: "dialogue"))
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
    func subBubbleContent(for item: BubbleItem, parentDialogueId: String) -> some View {
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
    func draggableActionView(action: Action, isHighlighted: Bool = false) -> some View {
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
    func draggableNarrationView(narration: Narration, isHighlighted: Bool = false) -> some View {
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
    func draggableNoteView(note: Note, isHighlighted: Bool = false) -> some View {
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
    func draggableSoundNoteView(soundNote: SoundNote, isHighlighted: Bool = false) -> some View {
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
    // MARK: - Drag reorder / disconnect (WS: bubble drag UX)

    /// Thin insertion zone between rows. Invisible until a drag hovers it,
    /// then shows a blue insertion line. Dropping moves the dragged item to
    /// this position (a connected item is detached first).
    @ViewBuilder
    func reorderDropZone(insertBefore chronology: Int?) -> some View {
        let zoneId = chronology ?? Int.max
        RoundedRectangle(cornerRadius: 2)
            .fill(reorderDropTarget == zoneId ? Color.accentColor : Color.clear)
            .frame(height: reorderDropTarget == zoneId ? 4 : 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.json], isTargeted: Binding(
                get: { reorderDropTarget == zoneId },
                set: { targeted in reorderDropTarget = targeted ? zoneId : nil }
            )) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadDataRepresentation(for: UTType.json) { data, _ in
                    guard let data = data,
                          let dragData = try? JSONDecoder().decode(BubbleItemDragData.self, from: data) else { return }
                    DispatchQueue.main.async {
                        handleReorderDrop(itemId: dragData.itemId, itemType: dragData.itemType,
                                          insertBefore: chronology)
                    }
                }
                return true
            }
            .accessibilityHidden(true)
    }

}
