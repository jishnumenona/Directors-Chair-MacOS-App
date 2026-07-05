//
// BubbleView+Sheets.swift
//
// Extracted from BubbleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import UniformTypeIdentifiers
import AVFoundation


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

struct FilterToggleButton: View {
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

struct EditDialogueSheet: View {
    let dialogue: Dialogue
    let characters: [Character]
    let projectBasePath: URL?
    let onSave: (Dialogue) -> Void
    let onCancel: () -> Void
    var onCharacterColorChanged: ((String, String) -> Void)?

    @State var editedDialogue: Dialogue
    @State var tagInput: String = ""
    @State var bubbleColor: Color
    @FocusState var textFocused: Bool

    var selectedCharacter: Character? {
        characters.first(where: { $0.name == editedDialogue.character })
    }

    var hasChanges: Bool {
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

    var header: some View {
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

    var characterCard: some View {
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

    var bubbleColorCard: some View {
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

    var orderCard: some View {
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

    var dialogueCard: some View {
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

    var tagsCard: some View {
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

    var audioCard: some View {
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

struct EditActionSheet: View {
    let action: Action
    let onSave: (Action) -> Void
    let onCancel: () -> Void

    @State var editedAction: Action

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

struct EditNarrationSheet: View {
    let narration: Narration
    let onSave: (Narration) -> Void
    let onCancel: () -> Void

    @State var editedNarration: Narration

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

struct EditNoteSheet: View {
    let note: Note
    let onSave: (Note) -> Void
    let onCancel: () -> Void

    @State var editedNote: Note

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
struct HighlightModifier: ViewModifier {
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

struct EditSoundNoteSheet: View {
    let soundNote: SoundNote
    let onSave: (SoundNote) -> Void
    let onCancel: () -> Void

    @State var editedSoundNote: SoundNote

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
    let shortcuts: [(key: String, description: String)] = [
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
