// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/CharacterMentionTextField.swift
//
// Text field with @ mention support for character names

import SwiftUI
import DirectorsChairCore

/// A text field that supports @ mentions for character names
public struct CharacterMentionTextField: View {
    @Binding var text: String
    let placeholder: String
    let characters: [Character]
    let font: Font
    let foregroundColor: Color
    var onSubmit: (() -> Void)?

    @State private var showMentionPopup = false
    @State private var mentionQuery = ""
    @State private var mentionStartIndex: String.Index?
    @State private var cursorPosition: Int = 0
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "",
        characters: [Character],
        font: Font = .body,
        foregroundColor: Color = .primary,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.characters = characters
        self.font = font
        self.foregroundColor = foregroundColor
        self.onSubmit = onSubmit
    }

    private var filteredCharacters: [Character] {
        if mentionQuery.isEmpty {
            return characters
        }
        return characters.filter { $0.name.localizedCaseInsensitiveContains(mentionQuery) }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Main text field
            TextField(placeholder, text: $text)
                .font(font)
                .foregroundColor(foregroundColor)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    handleTextChange(oldValue: oldValue, newValue: newValue)
                }
                .onSubmit {
                    if showMentionPopup, let firstMatch = filteredCharacters.first {
                        insertMention(character: firstMatch)
                    } else {
                        onSubmit?()
                    }
                }
                .onKeyPress(.downArrow) {
                    // Could implement keyboard navigation here
                    return .ignored
                }
                .onKeyPress(.escape) {
                    if showMentionPopup {
                        closeMentionPopup()
                        return .handled
                    }
                    return .ignored
                }

            // Mention popup overlay
            if showMentionPopup && !filteredCharacters.isEmpty {
                mentionPopup
                    .offset(y: 24)  // Position below the text field
            }
        }
    }

    private var mentionPopup: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredCharacters.prefix(5)) { character in
                Button {
                    insertMention(character: character)
                } label: {
                    HStack(spacing: 8) {
                        // Character color indicator
                        Circle()
                            .fill(Color(hex: character.color.isEmpty ? "#666666" : character.color))
                            .frame(width: 12, height: 12)

                        Text(character.name)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)

                        if !character.role.isEmpty {
                            Text("(\(character.role))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor))
                .onHover { isHovered in
                    // Could add hover effect here
                }

                if character.id != filteredCharacters.prefix(5).last?.id {
                    Divider()
                }
            }
        }
        .frame(minWidth: 150, maxWidth: 250)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func handleTextChange(oldValue: String, newValue: String) {
        // Check if user just typed @
        if newValue.count > oldValue.count {
            let addedChar = newValue.last
            if addedChar == "@" {
                // Start mention mode
                showMentionPopup = true
                mentionQuery = ""
                mentionStartIndex = newValue.index(before: newValue.endIndex)
                return
            }
        }

        // If we're in mention mode, update the query
        if showMentionPopup, let startIndex = mentionStartIndex {
            // Check if the @ is still there
            if startIndex < newValue.endIndex {
                let afterAt = newValue[newValue.index(after: startIndex)...]

                // Find the end of the mention (space or end of string)
                if let spaceIndex = afterAt.firstIndex(of: " ") {
                    mentionQuery = String(afterAt[..<spaceIndex])
                } else {
                    mentionQuery = String(afterAt)
                }

                // Close if user deleted the @
                if newValue[startIndex] != "@" {
                    closeMentionPopup()
                }
            } else {
                // @ was deleted
                closeMentionPopup()
            }
        }

        // Close popup if text is empty or @ was removed
        if showMentionPopup && !newValue.contains("@") {
            closeMentionPopup()
        }
    }

    private func insertMention(character: Character) {
        guard let startIndex = mentionStartIndex else { return }

        // Find the range to replace (from @ to current position or space)
        let afterAt = text[text.index(after: startIndex)...]
        let endIndex: String.Index
        if let spaceIndex = afterAt.firstIndex(of: " ") {
            endIndex = spaceIndex
        } else {
            endIndex = text.endIndex
        }

        // Replace @query with @CharacterName
        let range = startIndex..<endIndex
        text.replaceSubrange(range, with: "@\(character.name) ")

        closeMentionPopup()
    }

    private func closeMentionPopup() {
        showMentionPopup = false
        mentionQuery = ""
        mentionStartIndex = nil
    }
}

#Preview {
    VStack(spacing: 20) {
        CharacterMentionTextField(
            text: .constant("Hello @"),
            placeholder: "Type something...",
            characters: [
                Character(name: "John", role: "Protagonist", color: "#4A90D9"),
                Character(name: "Jane", role: "Supporting", color: "#D94A90"),
                Character(name: "Bob", role: "Antagonist", color: "#90D94A")
            ],
            font: .system(size: 14),
            foregroundColor: .white
        )
        .padding()
        .background(Color.gray.opacity(0.3))
    }
    .padding()
    .frame(width: 400, height: 200)
}
