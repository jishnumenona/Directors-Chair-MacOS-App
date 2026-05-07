// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/CharacterMentionTextEditor.swift
//
// Multi-line text editor with @ mention support for character names

import SwiftUI
import DirectorsChairCore

/// A multi-line TextEditor that supports @ mentions for character names
public struct CharacterMentionTextEditor: View {
    @Binding var text: String
    let characters: [Character]
    let placeholder: String
    let font: Font
    let foregroundColor: Color

    @State private var showMentionPopup = false
    @State private var mentionQuery = ""
    @State private var mentionStartIndex: String.Index?
    @State private var selectedMentionIndex: Int = 0

    public init(
        text: Binding<String>,
        characters: [Character],
        placeholder: String = "Write a description...",
        font: Font = .system(size: 14),
        foregroundColor: Color = .white.opacity(0.9)
    ) {
        self._text = text
        self.characters = characters
        self.placeholder = placeholder
        self.font = font
        self.foregroundColor = foregroundColor
    }

    private var filteredCharacters: [Character] {
        if mentionQuery.isEmpty {
            return characters
        }
        return characters.filter { $0.name.localizedCaseInsensitiveContains(mentionQuery) }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(.gray.opacity(0.35))
                    .italic()
                    .padding(.vertical, 2)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(font)
                .foregroundColor(foregroundColor)
                .scrollContentBackground(.hidden)
                .lineSpacing(3)
                .frame(minHeight: 20)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: text) { oldValue, newValue in
                    handleTextChange(oldValue: oldValue, newValue: newValue)
                }
                .onKeyPress(.downArrow) {
                    if showMentionPopup {
                        selectedMentionIndex = min(selectedMentionIndex + 1, filteredCharacters.prefix(5).count - 1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.upArrow) {
                    if showMentionPopup {
                        selectedMentionIndex = max(selectedMentionIndex - 1, 0)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    if showMentionPopup {
                        closeMentionPopup()
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.return) {
                    let visible = Array(filteredCharacters.prefix(5))
                    if showMentionPopup, selectedMentionIndex < visible.count {
                        insertMention(character: visible[selectedMentionIndex])
                        return .handled
                    }
                    return .ignored
                }
        }
        .overlay(alignment: .topLeading) {
            if showMentionPopup && !filteredCharacters.isEmpty {
                mentionPopup
                    .offset(y: 24)
            }
        }
    }

    private var mentionPopup: some View {
        let visible = Array(filteredCharacters.prefix(5))
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, character in
                Button {
                    insertMention(character: character)
                } label: {
                    HStack(spacing: 8) {
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
                .background(index == selectedMentionIndex ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                .onHover { hovering in
                    if hovering { selectedMentionIndex = index }
                }

                if index < visible.count - 1 {
                    Divider()
                }
            }
        }
        .frame(minWidth: 150, maxWidth: 250)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
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
                mentionQuery = ""
                mentionStartIndex = newValue.index(before: newValue.endIndex)
                selectedMentionIndex = 0
                showMentionPopup = true
                return
            }
        }

        // If we're in mention mode, update the query
        if showMentionPopup, let startIndex = mentionStartIndex {
            if startIndex < newValue.endIndex {
                let afterAt = newValue[newValue.index(after: startIndex)...]

                // Find the end of the mention (space, newline, or end of string)
                if let endIdx = afterAt.firstIndex(where: { $0 == " " || $0 == "\n" }) {
                    mentionQuery = String(afterAt[..<endIdx])
                } else {
                    mentionQuery = String(afterAt)
                }

                // Close if user deleted the @
                if newValue[startIndex] != "@" {
                    closeMentionPopup()
                }
            } else {
                closeMentionPopup()
            }
        }

        // Close popup if @ was removed
        if showMentionPopup && !newValue.contains("@") {
            closeMentionPopup()
        }
    }

    private func insertMention(character: Character) {
        guard let startIndex = mentionStartIndex else { return }

        let afterAt = text[text.index(after: startIndex)...]
        let endIndex: String.Index
        if let spaceOrNewline = afterAt.firstIndex(where: { $0 == " " || $0 == "\n" }) {
            endIndex = spaceOrNewline
        } else {
            endIndex = text.endIndex
        }

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
