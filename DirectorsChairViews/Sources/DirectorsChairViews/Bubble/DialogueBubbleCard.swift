// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/DialogueBubbleCard.swift
//
// Individual dialogue bubble card displaying character name, text, and tags

import SwiftUI
import DirectorsChairCore

/// Individual dialogue bubble card
///
/// Shows:
/// - Character avatar (40x40 circle)
/// - Character name (colored)
/// - Dialogue text
/// - Tags (rounded pills)
/// - Chronology number
/// - Audio indicator (if TTS audio exists)
public struct DialogueBubbleCard: View {
    let dialogue: Dialogue
    let character: Character?
    let isSelected: Bool
    let isPrimaryCharacter: Bool
    let projectBasePath: URL?

    // Callbacks
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onPlay: (() -> Void)?
    var onStop: (() -> Void)?
    var onGenerateAudio: (() -> Void)?
    var onDetectEmotion: (() -> Void)?
    var onTextChanged: ((String) -> Void)?
    var onChronologyChanged: ((Int) -> Void)?
    var onEditModeStarted: (() -> Void)?
    var alignmentLabel: String?
    var onToggleAlignment: (() -> Void)?
    var onAddConnectedAction: (() -> Void)?
    var onAddConnectedNarration: (() -> Void)?
    var onAddConnectedNote: (() -> Void)?
    var onAddConnectedSoundNote: (() -> Void)?

    // Audio state
    var isGeneratingAudio: Bool = false
    var isPlaying: Bool = false
    var isDetectingEmotion: Bool = false

    let startInEditMode: Bool

    @State private var isEditing: Bool = false
    @State private var editedText: String = ""
    @State private var isEditingIndex: Bool = false
    @State private var editedIndex: String = ""
    @State private var isHovered: Bool = false
    @FocusState private var textFieldFocused: Bool
    @FocusState private var indexFieldFocused: Bool

    public init(
        dialogue: Dialogue,
        character: Character? = nil,
        isSelected: Bool = false,
        isPrimaryCharacter: Bool = false,
        startInEditMode: Bool = false,
        projectBasePath: URL? = nil,
        onTap: (() -> Void)? = nil,
        onDoubleTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onPlay: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil,
        onGenerateAudio: (() -> Void)? = nil,
        onDetectEmotion: (() -> Void)? = nil,
        isGeneratingAudio: Bool = false,
        isPlaying: Bool = false,
        isDetectingEmotion: Bool = false,
        onTextChanged: ((String) -> Void)? = nil,
        onChronologyChanged: ((Int) -> Void)? = nil,
        onEditModeStarted: (() -> Void)? = nil,
        alignmentLabel: String? = nil,
        onToggleAlignment: (() -> Void)? = nil,
        onAddConnectedAction: (() -> Void)? = nil,
        onAddConnectedNarration: (() -> Void)? = nil,
        onAddConnectedNote: (() -> Void)? = nil,
        onAddConnectedSoundNote: (() -> Void)? = nil
    ) {
        self.dialogue = dialogue
        self.character = character
        self.isSelected = isSelected
        self.isPrimaryCharacter = isPrimaryCharacter
        self.startInEditMode = startInEditMode
        self.projectBasePath = projectBasePath
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPlay = onPlay
        self.onStop = onStop
        self.onGenerateAudio = onGenerateAudio
        self.onDetectEmotion = onDetectEmotion
        self.isGeneratingAudio = isGeneratingAudio
        self.isPlaying = isPlaying
        self.isDetectingEmotion = isDetectingEmotion
        self.onTextChanged = onTextChanged
        self.onChronologyChanged = onChronologyChanged
        self.onEditModeStarted = onEditModeStarted
        self.alignmentLabel = alignmentLabel
        self.onToggleAlignment = onToggleAlignment
        self.onAddConnectedAction = onAddConnectedAction
        self.onAddConnectedNarration = onAddConnectedNarration
        self.onAddConnectedNote = onAddConnectedNote
        self.onAddConnectedSoundNote = onAddConnectedSoundNote
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isPrimaryCharacter {
                // Primary character: Avatar on left
                avatar
                bubbleContent
            } else {
                // Other characters: Bubble on left, avatar on right
                bubbleContent
                avatar
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .onAppear {
            if startInEditMode {
                startEditing()
                onEditModeStarted?()
            }
        }
    }

    // MARK: - Avatar

    private var avatar: some View {
        CharacterAvatarView(
            character: character,
            characterName: dialogue.character,
            size: 40,
            projectBasePath: projectBasePath
        )
    }

    // MARK: - Bubble Content

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row: chronology number, character name, edit button
            headerRow

            // Dialogue text - inline editable
            if isEditing {
                TextField("Dialogue text...", text: $editedText, axis: .vertical)
                    .font(.body)
                    .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF"))
                    .textFieldStyle(.plain)
                    .lineLimit(1...10)
                    .focused($textFieldFocused)
                    .onSubmit {
                        commitEdit()
                    }
                    .onChange(of: textFieldFocused) { _, focused in
                        if !focused {
                            commitEdit()
                        }
                    }
            } else {
                Text(htmlToPlainText(dialogue.text))
                    .font(.body)
                    .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF"))
                    .multilineTextAlignment(.leading)
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }

            // Tags + detect emotion
            HStack(spacing: 6) {
                if !dialogue.tags.isEmpty {
                    TagsStackView(tags: dialogue.tags)
                }

                Spacer()

                if isDetectingEmotion {
                    ProgressView()
                        .controlSize(.mini)
                } else if isHovered {
                    Button(action: { onDetectEmotion?() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                            Text(dialogue.tags.isEmpty ? "Detect" : "Re-detect")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF").opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: character?.color ?? "#555555"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected || isEditing ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .frame(maxWidth: 500)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            TapGesture()
                .modifiers(.command)
                .onEnded { _ in
                    onGenerateAudio?()
                }
        )
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            // Chronology number badge - editable on double-click
            if isEditingIndex {
                TextField("", text: $editedIndex)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .frame(width: 35)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.8))
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
                Text("#\(dialogue.chronologyNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                    .onTapGesture(count: 2) {
                        startIndexEditing()
                    }
            }

            // Character name
            Text(dialogue.character)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF"))

            Spacer()

            // Audio state indicators and controls
            if isGeneratingAudio {
                ProgressView()
                    .controlSize(.mini)
                Text("Generating...")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF").opacity(0.5))
            } else if isPlaying {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .symbolEffect(.variableColor.iterative)

                Button(action: { onStop?() }) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF").opacity(0.7))
                }
                .buttonStyle(.plain)
            } else if dialogue.audioFilePath != nil {
                // Has saved audio — show play + regenerate
                Button(action: { onPlay?() }) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Play saved audio")

                if isHovered {
                    Button(action: { onGenerateAudio?() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF").opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate voice")
                }
            } else if isHovered {
                // No audio yet — show generate button on hover
                Button(action: { onGenerateAudio?() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                        Text("Generate")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF").opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Generate voice audio")
            }

            // Edit button (pencil icon, shown on hover)
            if isHovered && !isEditing {
                Button(action: { onEdit?() }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF").opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Edit Dialogue") {
            onEdit?()
        }

        Divider()

        Button(dialogue.tags.isEmpty ? "Detect Emotion" : "Re-detect Emotion") {
            onDetectEmotion?()
        }

        Divider()

        if dialogue.audioFilePath != nil {
            Button("Play Voice") {
                onPlay?()
            }
            Button("Regenerate Voice") {
                onGenerateAudio?()
            }
        } else {
            Button("Generate Voice") {
                onGenerateAudio?()
            }
        }

        Divider()

        Button("Add to Vision Board") {
            // TODO: Implement
        }

        if let label = alignmentLabel {
            Divider()

            Button(label) {
                onToggleAlignment?()
            }
        }

        if onAddConnectedAction != nil {
            Divider()

            Menu("Add Connected") {
                Button("Action") {
                    onAddConnectedAction?()
                }
                Button("Narration") {
                    onAddConnectedNarration?()
                }
                Button("Note") {
                    onAddConnectedNote?()
                }
                Button("Sound Note") {
                    onAddConnectedSoundNote?()
                }
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            onDelete?()
        }
    }

    // MARK: - Inline Editing

    private func startEditing() {
        editedText = htmlToPlainText(dialogue.text)
        isEditing = true
        textFieldFocused = true
    }

    private func commitEdit() {
        if isEditing {
            isEditing = false
            let originalText = htmlToPlainText(dialogue.text)
            if editedText != originalText {
                onTextChanged?(editedText)
            }
        }
    }

    private func startIndexEditing() {
        editedIndex = "\(dialogue.chronologyNumber)"
        isEditingIndex = true
        indexFieldFocused = true
    }

    private func commitIndexEdit() {
        if isEditingIndex {
            isEditingIndex = false
            if let newIndex = Int(editedIndex), newIndex != dialogue.chronologyNumber, newIndex > 0 {
                onChronologyChanged?(newIndex)
            }
        }
    }

    // MARK: - Helper Methods

    /// Convert HTML to plain text (basic implementation)
    private func htmlToPlainText(_ html: String) -> String {
        guard !html.isEmpty else { return "" }

        // Check if it looks like HTML
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<") && (trimmed.contains("</p>") || trimmed.contains("</div>") || trimmed.contains("</span>")) else {
            return html
        }

        // Basic HTML tag removal
        var result = html
        result = result.replacingOccurrences(of: "<br>", with: "\n")
        result = result.replacingOccurrences(of: "<br/>", with: "\n")
        result = result.replacingOccurrences(of: "<br />", with: "\n")
        result = result.replacingOccurrences(of: "</p>", with: "\n")

        // Remove remaining HTML tags
        let tagPattern = "<[^>]+>"
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        // Decode HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    VStack(spacing: 20) {
        DialogueBubbleCard(
            dialogue: Dialogue(
                character: "John",
                text: "Hello, how are you doing today?",
                tags: ["friendly", "greeting"],
                chronologyNumber: 1
            ),
            character: Character(name: "John", role: "Protagonist", color: "#4A90D9", textColor: "#FFFFFF"),
            isSelected: false,
            isPrimaryCharacter: true
        )

        DialogueBubbleCard(
            dialogue: Dialogue(
                character: "Jane",
                text: "I'm doing great, thank you for asking!",
                tags: ["happy"],
                chronologyNumber: 2
            ),
            character: Character(name: "Jane", role: "Supporting", color: "#D94A90", textColor: "#FFFFFF"),
            isSelected: true,
            isPrimaryCharacter: false
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
