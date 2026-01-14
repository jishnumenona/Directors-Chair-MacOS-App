// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/BubbleView.swift
//
// Main Bubble View - dialogue editing interface
//
// Layout:
// - Left: Scene list sidebar
// - Center: Dialogue bubbles (scrollable)
// - Right: Dialogue editor panel (optional)

import SwiftUI
import DirectorsChairCore

/// Main Bubble View - the primary dialogue editing interface
///
/// Shows dialogue, actions, narrations, notes, and sound notes in a chat-like bubble layout.
/// Primary character's bubbles align left, other characters align right.
public struct BubbleView: View {
    @Binding var project: Project
    @State private var selectedScene: DCScene?
    @State private var selectedDialogue: Dialogue?
    @State private var editingDialogue: Dialogue?

    // Filter toggles
    @State private var showDialogues = true
    @State private var showActions = true
    @State private var showNarrations = true
    @State private var showNotes = true
    @State private var showSoundNotes = true
    @State private var showBackground = false

    // UI state
    @State private var showEditorPanel = true

    let projectBasePath: URL?

    public init(project: Binding<Project>, projectBasePath: URL? = nil) {
        self._project = project
        self.projectBasePath = projectBasePath
    }

    public var body: some View {
        HSplitView {
            // Left: Scene list
            SceneListSidebar(project: $project, selectedScene: $selectedScene)
                .frame(minWidth: 180, maxWidth: 300)

            // Center: Bubble content
            VStack(spacing: 0) {
                // Toolbar
                toolbar

                // Bubble scroll area
                bubbleScrollArea
            }
            .frame(minWidth: 400)

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
                .frame(minWidth: 300, maxWidth: 400)
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
                            ForEach(getAllItemsChronologically(for: scene), id: \.id) { item in
                                itemView(for: item, in: scene)
                            }
                        }
                        .padding()
                    }
                    .background(backgroundView)
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

    @ViewBuilder
    private func itemView(for item: BubbleItem, in scene: DCScene) -> some View {
        switch item {
        case .dialogue(let dialogue):
            if showDialogues {
                let character = project.characters.first { $0.name == dialogue.character }
                let isPrimary = scene.primaryCharacter == dialogue.character

                DialogueBubbleCard(
                    dialogue: dialogue,
                    character: character,
                    isSelected: selectedDialogue?.id == dialogue.id,
                    isPrimaryCharacter: isPrimary,
                    projectBasePath: projectBasePath,
                    onTap: { selectedDialogue = dialogue },
                    onDoubleTap: { editingDialogue = dialogue },
                    onEdit: { editingDialogue = dialogue },
                    onPlay: { playDialogue(dialogue) },
                    onStop: { stopDialogue() }
                )
            }

        case .action(let action):
            if showActions {
                ActionBubbleCard(
                    action: action,
                    isSelected: false,
                    onTap: { /* TODO: Select action */ },
                    onEdit: { editAction(action) },
                    onDelete: { deleteAction(action) }
                )
            }

        case .narration(let narration):
            if showNarrations {
                NarrationBubbleCard(
                    narration: narration,
                    isSelected: false,
                    onTap: { /* TODO: Select narration */ },
                    onEdit: { editNarration(narration) },
                    onDelete: { deleteNarration(narration) }
                )
            }

        case .note(let note):
            if showNotes {
                NoteBubbleCard(
                    note: note,
                    isSelected: false,
                    projectBasePath: projectBasePath,
                    onTap: { /* TODO: View note */ },
                    onEdit: { editNote(note) },
                    onDelete: { deleteNote(note) }
                )
            }

        case .soundNote(let soundNote):
            if showSoundNotes {
                SoundNoteBubbleCard(
                    soundNote: soundNote,
                    isSelected: false,
                    onTap: { /* TODO: Select sound note */ },
                    onEdit: { editSoundNote(soundNote) },
                    onPlay: { playSoundNote(soundNote) },
                    onDelete: { deleteSoundNote(soundNote) }
                )
            }
        }
    }

    // MARK: - Get All Items Chronologically

    private func getAllItemsChronologically(for scene: DCScene) -> [BubbleItem] {
        var items: [BubbleItem] = []

        // Add all dialogues
        for dialogue in scene.dialogues {
            items.append(.dialogue(dialogue))
        }

        // Add all actions
        for action in scene.actions {
            items.append(.action(action))
        }

        // Add all narrations
        for narration in scene.narrations {
            items.append(.narration(narration))
        }

        // Add all notes
        for note in scene.sceneNotes {
            items.append(.note(note))
        }

        // Add all sound notes
        for soundNote in scene.soundNotes {
            items.append(.soundNote(soundNote))
        }

        // Sort by chronology number
        items.sort { $0.chronologyNumber < $1.chronologyNumber }

        return items
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
            editingDialogue = newDialogue
        }
    }

    private func addAction() {
        // TODO: Implement
    }

    private func addNarration() {
        // TODO: Implement
    }

    private func addNote() {
        // TODO: Implement
    }

    private func addSoundNote() {
        // TODO: Implement
    }

    private func editAction(_ action: Action) {
        // TODO: Implement
    }

    private func deleteAction(_ action: Action) {
        // TODO: Implement
    }

    private func editNarration(_ narration: Narration) {
        // TODO: Implement
    }

    private func deleteNarration(_ narration: Narration) {
        // TODO: Implement
    }

    private func editNote(_ note: Note) {
        // TODO: Implement
    }

    private func deleteNote(_ note: Note) {
        // TODO: Implement
    }

    private func editSoundNote(_ soundNote: SoundNote) {
        // TODO: Implement
    }

    private func deleteSoundNote(_ soundNote: SoundNote) {
        // TODO: Implement
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
        case .dialogue(let d): return "dialogue-\(d.id)"
        case .action(let a): return "action-\(a.id)"
        case .narration(let n): return "narration-\(n.id)"
        case .note(let n): return "note-\(n.id)"
        case .soundNote(let s): return "soundnote-\(s.id)"
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

