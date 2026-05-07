// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/ActionBubbleCard.swift
//
// Compact inline action card for stage directions

import SwiftUI
import DirectorsChairCore

public struct ActionBubbleCard: View {
    let action: Action
    let isSelected: Bool
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

    public init(
        action: Action,
        isSelected: Bool = false,
        startInEditMode: Bool = false,
        characters: [Character] = [],
        globalIndex: Int? = nil,
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTextChanged: ((String) -> Void)? = nil,
        onChronologyChanged: ((Int) -> Void)? = nil,
        onEditModeStarted: (() -> Void)? = nil
    ) {
        self.action = action
        self.isSelected = isSelected
        self.startInEditMode = startInEditMode
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
                    .background(Color.orange.opacity(0.8))
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
                Text("#\(globalIndex ?? action.chronologyNumber)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.6))
                    .cornerRadius(4)
                    .onTapGesture(count: 2) {
                        startIndexEditing()
                    }
            }

            // Action icon
            Image(systemName: "figure.walk")
                .font(.system(size: 10))
                .foregroundColor(.orange)

            // Inline editable text with @ mention support
            if isEditing {
                CharacterMentionTextField(
                    text: $editedText,
                    placeholder: "Action description...",
                    characters: characters,
                    font: .system(size: 12).italic(),
                    foregroundColor: .orange.opacity(0.9),
                    onSubmit: { commitEdit() }
                )
                .focused($textFieldFocused)
                .onChange(of: textFieldFocused) { _, focused in
                    if !focused {
                        commitEdit()
                    }
                }
            } else {
                Text(action.description.isEmpty ? "Action..." : action.description)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(action.description.isEmpty ? .gray : .orange.opacity(0.9))
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }

            if isHovered && !isEditing {
                Button(action: { onEdit?() }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundColor(.orange.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected || isEditing ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
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
        editedText = action.description
        isEditing = true
        textFieldFocused = true
    }

    private func commitEdit() {
        if isEditing {
            isEditing = false
            if editedText != action.description {
                onTextChanged?(editedText)
            }
        }
    }

    private func startIndexEditing() {
        editedIndex = "\(action.chronologyNumber)"
        isEditingIndex = true
        indexFieldFocused = true
    }

    private func commitIndexEdit() {
        if isEditingIndex {
            isEditingIndex = false
            if let newIndex = Int(editedIndex), newIndex != action.chronologyNumber, newIndex > 0 {
                onChronologyChanged?(newIndex)
            }
        }
    }
}
