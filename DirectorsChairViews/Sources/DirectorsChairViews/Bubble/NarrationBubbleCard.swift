// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/NarrationBubbleCard.swift
//
// Compact inline narration card for voiceover text

import SwiftUI
import DirectorsChairCore

public struct NarrationBubbleCard: View {
    let narration: Narration
    let isSelected: Bool
    let characters: [Character]

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

    private let accentColor = Color(red: 0.6, green: 0.4, blue: 0.8)

    public init(
        narration: Narration,
        isSelected: Bool = false,
        startInEditMode: Bool = false,
        characters: [Character] = [],
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTextChanged: ((String) -> Void)? = nil,
        onChronologyChanged: ((Int) -> Void)? = nil,
        onEditModeStarted: (() -> Void)? = nil
    ) {
        self.narration = narration
        self.isSelected = isSelected
        self.startInEditMode = startInEditMode
        self.characters = characters
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
                Text("#\(narration.chronologyNumber)")
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

            // Narration icon (microphone for voice-over)
            Image(systemName: "mic.fill")
                .font(.system(size: 10))
                .foregroundColor(accentColor)

            // Inline editable text with @ mention support
            if isEditing {
                CharacterMentionTextField(
                    text: $editedText,
                    placeholder: "Narration text...",
                    characters: characters,
                    font: .system(size: 12).italic(),
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
                Text(narration.text.isEmpty ? "Narration..." : narration.text)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(narration.text.isEmpty ? .gray : accentColor.opacity(0.9))
                    .onTapGesture(count: 2) {
                        startEditing()
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
        .background(accentColor.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected || isEditing ? accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .fixedSize(horizontal: !isEditing, vertical: false)
        .frame(minWidth: isEditing ? 200 : nil)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap?() }
        .contextMenu {
            Button("Edit") { onEdit?() }
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

    private func startEditing() {
        editedText = narration.text
        isEditing = true
        textFieldFocused = true
    }

    private func commitEdit() {
        if isEditing {
            isEditing = false
            if editedText != narration.text {
                onTextChanged?(editedText)
            }
        }
    }

    private func startIndexEditing() {
        editedIndex = "\(narration.chronologyNumber)"
        isEditingIndex = true
        indexFieldFocused = true
    }

    private func commitIndexEdit() {
        if isEditingIndex {
            isEditingIndex = false
            if let newIndex = Int(editedIndex), newIndex != narration.chronologyNumber, newIndex > 0 {
                onChronologyChanged?(newIndex)
            }
        }
    }
}
