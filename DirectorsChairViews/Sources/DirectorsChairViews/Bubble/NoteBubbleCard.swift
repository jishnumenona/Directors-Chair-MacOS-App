// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/NoteBubbleCard.swift
//
// Compact note card for displaying production notes

import SwiftUI
import DirectorsChairCore

/// Compact note card - displays production notes inline
public struct NoteBubbleCard: View {
    let note: Note
    let isSelected: Bool
    let projectBasePath: URL?
    let characters: [Character]
    let globalIndex: Int?

    var onTap: (() -> Void)?
    var onEdit: (() -> Void)?
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

    private let accentColor = Color(red: 0.85, green: 0.65, blue: 0.2) // Amber/gold

    public init(
        note: Note,
        isSelected: Bool = false,
        startInEditMode: Bool = false,
        projectBasePath: URL? = nil,
        characters: [Character] = [],
        globalIndex: Int? = nil,
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTextChanged: ((String) -> Void)? = nil,
        onChronologyChanged: ((Int) -> Void)? = nil,
        onEditModeStarted: (() -> Void)? = nil
    ) {
        self.note = note
        self.isSelected = isSelected
        self.startInEditMode = startInEditMode
        self.projectBasePath = projectBasePath
        self.characters = characters
        self.globalIndex = globalIndex
        self.onTap = onTap
        self.onEdit = onEdit
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
                Text("#\(globalIndex ?? note.chronologyNumber)")
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

            // Icon based on type
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundColor(accentColor)

            // Inline editable text with @ mention support
            if isEditing {
                CharacterMentionTextField(
                    text: $editedText,
                    placeholder: "Note content...",
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
                Text(displayText)
                    .font(.system(size: 12))
                    .foregroundColor(note.content.isEmpty && note.title.isEmpty ? .gray : accentColor.opacity(0.9))
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }

            // Type badge for special types (compact)
            if note.noteType != "text" && !isEditing {
                Text(note.noteType.prefix(3).uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(accentColor.opacity(0.7))
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
            Button("Edit Note") { onEdit?() }
            if note.noteType == "link" || note.noteType == "youtube" {
                Button("Open Link") {
                    if let url = URL(string: note.content) {
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

    private var iconName: String {
        switch note.noteType {
        case "youtube": return "play.rectangle.fill"
        case "link": return "link"
        case "image": return "photo"
        default: return "note.text"
        }
    }

    private var displayText: String {
        if !note.title.isEmpty {
            return note.title
        }
        if note.content.isEmpty {
            return "Note..."
        }
        return note.content
    }

    private func startEditing() {
        // Edit content (or title if present)
        editedText = note.title.isEmpty ? note.content : note.title
        isEditing = true
        textFieldFocused = true
    }

    private func commitEdit() {
        if isEditing {
            isEditing = false
            let originalText = note.title.isEmpty ? note.content : note.title
            if editedText != originalText {
                onTextChanged?(editedText)
            }
        }
    }

    private func startIndexEditing() {
        editedIndex = "\(note.chronologyNumber)"
        isEditingIndex = true
        indexFieldFocused = true
    }

    private func commitIndexEdit() {
        if isEditingIndex {
            isEditingIndex = false
            if let newIndex = Int(editedIndex), newIndex != note.chronologyNumber, newIndex > 0 {
                onChronologyChanged?(newIndex)
            }
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        NoteBubbleCard(
            note: Note(
                content: "Remember to have the red dress ready for scene 5",
                noteType: "text",
                chronologyNumber: 6,
                title: "Costume Reference"
            ),
            isSelected: false
        )

        NoteBubbleCard(
            note: Note(
                content: "https://youtube.com/watch?v=abc123",
                noteType: "youtube",
                chronologyNumber: 7,
                title: "Reference Video"
            ),
            isSelected: true
        )

        NoteBubbleCard(
            note: Note(
                content: "https://example.com/reference",
                noteType: "link",
                chronologyNumber: 8
            ),
            isSelected: false
        )
    }
    .padding()
    .frame(width: 600)
    .background(Color(hex: "#1E1E1E"))
}
