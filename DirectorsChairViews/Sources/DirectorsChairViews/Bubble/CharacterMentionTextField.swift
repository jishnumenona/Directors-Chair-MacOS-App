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
    /// Character offset of the "@" in `text`; the query is what was typed
    /// right after it, so a mention works anywhere in the line.
    @State private var mentionStartOffset: Int?
    @State private var cursorPosition: Int = 0
    @State private var selectedMentionIndex: Int = 0
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
        TextField(placeholder, text: $text)
            .font(font)
            .foregroundColor(foregroundColor)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onChange(of: text) { oldValue, newValue in
                handleTextChange(oldValue: oldValue, newValue: newValue)
            }
            .onSubmit {
                let visible = Array(filteredCharacters.prefix(5))
                if showMentionPopup, selectedMentionIndex < visible.count {
                    insertMention(character: visible[selectedMentionIndex])
                } else {
                    onSubmit?()
                }
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

    /// Where a one-character edit landed: the length of the common prefix.
    private func editOffset(_ oldValue: String, _ newValue: String) -> Int {
        zip(oldValue, newValue).prefix { $0 == $1 }.count
    }

    private func handleTextChange(oldValue: String, newValue: String) {
        let oldCount = oldValue.count
        let newCount = newValue.count

        // One character typed — anywhere in the line (owner report
        // 2026-08-29: "@" only worked at the end).
        if newCount == oldCount + 1 {
            let at = editOffset(oldValue, newValue)
            let inserted = newValue[newValue.index(newValue.startIndex, offsetBy: at)]
            if inserted == "@" {
                mentionQuery = ""
                mentionStartOffset = at
                selectedMentionIndex = 0
                showMentionPopup = true
                return
            }
            guard showMentionPopup, let start = mentionStartOffset else { return }
            if at == start + 1 + mentionQuery.count {
                let extended = mentionQuery + String(inserted)
                let stillMatches = characters.contains { $0.name.localizedCaseInsensitiveContains(extended) }
                if inserted == " " && !stillMatches {
                    closeMentionPopup()
                } else {
                    mentionQuery = extended
                    if !stillMatches { closeMentionPopup() }
                    selectedMentionIndex = 0
                }
                return
            }
            closeMentionPopup()
            return
        }

        // One character deleted.
        if newCount == oldCount - 1, showMentionPopup, let start = mentionStartOffset {
            let at = editOffset(oldValue, newValue)
            if !mentionQuery.isEmpty, at == start + mentionQuery.count {
                mentionQuery.removeLast()
                selectedMentionIndex = 0
            } else {
                closeMentionPopup()
            }
            return
        }

        if showMentionPopup, newCount != oldCount {
            closeMentionPopup()
        }
    }

    private func insertMention(character: Character) {
        guard let start = mentionStartOffset,
              let startIndex = text.index(text.startIndex, offsetBy: start, limitedBy: text.endIndex),
              startIndex < text.endIndex
        else { closeMentionPopup(); return }
        let endIndex = text.index(startIndex, offsetBy: 1 + mentionQuery.count, limitedBy: text.endIndex) ?? text.endIndex
        text.replaceSubrange(startIndex..<endIndex, with: "@\(character.name) ")
        closeMentionPopup()
    }

    private func closeMentionPopup() {
        showMentionPopup = false
        mentionQuery = ""
        mentionStartOffset = nil
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
