// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/SoundNoteBubbleCard.swift
//
// Compact sound note card for displaying audio/music/SFX notes

import SwiftUI
import DirectorsChairCore

/// Compact sound note card - displays audio/music/SFX notes inline
public struct SoundNoteBubbleCard: View {
    let soundNote: SoundNote
    let isSelected: Bool
    let characters: [Character]
    let globalIndex: Int?

    var onTap: (() -> Void)?
    var onEdit: (() -> Void)?
    var onPlay: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTextChanged: ((String) -> Void)?
    var onChronologyChanged: ((Int) -> Void)?
    var onEditModeStarted: (() -> Void)?

    let startInEditMode: Bool

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedText: String = ""
    @State private var isEditingIndex: Bool = false
    @State private var editedIndex: String = ""
    @FocusState private var textFieldFocused: Bool
    @FocusState private var indexFieldFocused: Bool

    private let accentColor = Color(red: 0.3, green: 0.6, blue: 0.7) // Teal/cyan

    public init(
        soundNote: SoundNote,
        isSelected: Bool = false,
        startInEditMode: Bool = false,
        characters: [Character] = [],
        globalIndex: Int? = nil,
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onPlay: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTextChanged: ((String) -> Void)? = nil,
        onChronologyChanged: ((Int) -> Void)? = nil,
        onEditModeStarted: (() -> Void)? = nil
    ) {
        self.soundNote = soundNote
        self.isSelected = isSelected
        self.startInEditMode = startInEditMode
        self.characters = characters
        self.globalIndex = globalIndex
        self.onTap = onTap
        self.onEdit = onEdit
        self.onPlay = onPlay
        self.onDelete = onDelete
        self.onTextChanged = onTextChanged
        self.onChronologyChanged = onChronologyChanged
        self.onEditModeStarted = onEditModeStarted
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Index badge - editable on double-click
            if isEditingIndex {
                TextField("", text: $editedIndex)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .textFieldStyle(.plain)
                    .frame(width: 30)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.8))
                    .cornerRadius(4)
                    .focused($indexFieldFocused)
                    .onSubmit {
                        commitIndexEdit()
                    }
                    .onChange(of: indexFieldFocused) { _, focused in
                        if !focused {
                            commitIndexEdit()
                        }
                    }
            } else {
                Text("#\(globalIndex ?? soundNote.chronologyNumber)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.6))
                    .cornerRadius(4)
                    .onTapGesture(count: 2) {
                        startIndexEditing()
                    }
            }

            // Sound type icon
            Image(systemName: soundIconName)
                .font(.system(size: 10))
                .foregroundColor(accentColor)

            // Inline editable description with @ mention support
            if isEditing {
                CharacterMentionTextField(
                    text: $editedText,
                    placeholder: "Sound description...",
                    characters: characters,
                    font: .system(size: 12),
                    foregroundColor: accentColor.opacity(0.9),
                    onSubmit: { commitEdit() }
                )
                .focused($textFieldFocused)
                .onChange(of: textFieldFocused) { _, focused in
                    if !focused {
                        commitEdit()
                    }
                }
            } else {
                Text(soundNote.description.isEmpty ? "Sound..." : soundNote.description)
                    .font(.system(size: 12))
                    .foregroundColor(soundNote.description.isEmpty ? .gray : accentColor.opacity(0.9))
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }

            // Compact type indicator (hide when editing)
            if !isEditing {
                Text(soundNote.soundType.prefix(3).uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(accentColor.opacity(0.7))

                // Loop indicator
                if soundNote.loop {
                    Image(systemName: "repeat")
                        .font(.system(size: 8))
                        .foregroundColor(accentColor.opacity(0.6))
                }

                // Play button (if audio file exists)
                if let audioPath = soundNote.audioFilePath, !audioPath.isEmpty {
                    Button(action: { onPlay?() }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                            .foregroundColor(accentColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            if isHovered && !isEditing {
                Button(action: { onEdit?() }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundColor(accentColor.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected || isEditing ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .fixedSize(horizontal: !isEditing, vertical: false)
        .frame(minWidth: isEditing ? 200 : nil)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap?() }
        .contextMenu {
            Button("Edit Sound Note") { onEdit?() }
            if soundNote.audioFilePath != nil {
                Button("Play Audio") { onPlay?() }
            }
            if let refUrl = soundNote.referenceUrl, !refUrl.isEmpty {
                Button("Open Reference") {
                    if let url = URL(string: refUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete?() }
        }
        .onAppear {
            if startInEditMode {
                startEditing()
                onEditModeStarted?()
            }
        }
    }

    private var soundIconName: String {
        switch soundNote.soundType.lowercased() {
        case "music": return "music.note"
        case "effects", "sfx": return "waveform"
        case "ambient", "ambience": return "leaf.fill"
        case "dialogue_sfx": return "text.bubble"
        default: return "speaker.wave.2.fill"
        }
    }

    private var volumeIcon: String {
        switch soundNote.volume {
        case 0: return "speaker.slash"
        case 1..<33: return "speaker"
        case 33..<66: return "speaker.wave.1"
        default: return "speaker.wave.2"
        }
    }

    private func startEditing() {
        editedText = soundNote.description
        isEditing = true
        textFieldFocused = true
    }

    private func commitEdit() {
        if isEditing {
            isEditing = false
            if editedText != soundNote.description {
                onTextChanged?(editedText)
            }
        }
    }

    private func startIndexEditing() {
        editedIndex = "\(globalIndex ?? soundNote.chronologyNumber)"
        isEditingIndex = true
        indexFieldFocused = true
    }

    private func commitIndexEdit() {
        if isEditingIndex {
            isEditingIndex = false
            if let newIndex = Int(editedIndex), newIndex != soundNote.chronologyNumber, newIndex > 0 {
                onChronologyChanged?(newIndex)
            }
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        SoundNoteBubbleCard(
            soundNote: SoundNote(
                description: "Dramatic orchestral hit",
                soundType: "music",
                chronologyNumber: 8,
                volume: 80,
                loop: false,
                fadeInDuration: 0.5,
                fadeOutDuration: 1.0,
                tags: ["dramatic", "impact"]
            ),
            isSelected: false
        )

        SoundNoteBubbleCard(
            soundNote: SoundNote(
                description: "Rain and thunder ambience",
                soundType: "ambient",
                chronologyNumber: 9,
                volume: 40,
                loop: true,
                fadeInDuration: 2.0,
                fadeOutDuration: 3.0,
                tags: ["weather", "mood"]
            ),
            isSelected: true
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color(hex: "#1E1E1E"))
}
