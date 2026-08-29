// DirectorsChairViews/Bubble/CharacterMentionTextField.swift
//
// Single-line text field with mention support — "@" characters, "#"
// locations, "$" props, "&" shots — anywhere in the line (owner 2026-08-29:
// every place text is typed gets the same shortcuts as the shot description).

import SwiftUI
import DirectorsChairCore

public struct CharacterMentionTextField: View {
    @Binding var text: String
    let placeholder: String
    let characters: [Character]
    let locations: [Location]
    let props: [Prop]
    let shots: [Shot]
    let font: Font
    let foregroundColor: Color
    var onSubmit: (() -> Void)?

    @State private var showMentionPopup = false
    @State private var mentionKind: MentionKind = .character
    @State private var mentionQuery = ""
    @State private var mentionStartOffset: Int?
    @State private var selectedMentionIndex: Int = 0
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "",
        characters: [Character],
        locations: [Location] = [],
        props: [Prop] = [],
        shots: [Shot] = [],
        font: Font = .body,
        foregroundColor: Color = .primary,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.characters = characters
        self.locations = locations
        self.props = props
        self.shots = shots
        self.font = font
        self.foregroundColor = foregroundColor
        self.onSubmit = onSubmit
    }

    private var candidates: [MentionCandidate] {
        switch mentionKind {
        case .character:
            return characters.map {
                MentionCandidate(id: $0.id, name: $0.name, detail: $0.role,
                                 color: Color(hex: $0.color.isEmpty ? "#666666" : $0.color), symbol: nil)
            }
        case .location:
            return locations.map {
                MentionCandidate(id: $0.id, name: $0.name, detail: $0.locationType.capitalized,
                                 color: .green, symbol: "mappin.and.ellipse")
            }
        case .prop:
            return props.map {
                MentionCandidate(id: $0.id, name: $0.name, detail: $0.category,
                                 color: .orange, symbol: "shippingbox.fill")
            }
        case .shot:
            return shots.map {
                MentionCandidate(id: $0.id, name: MentionNames.shot($0), detail: String($0.description.prefix(40)),
                                 color: .purple, symbol: "film.stack")
            }
        }
    }

    private var filteredCandidates: [MentionCandidate] {
        if mentionQuery.isEmpty { return candidates }
        return candidates.filter { $0.name.localizedCaseInsensitiveContains(mentionQuery) }
    }

    private var visibleCandidates: [MentionCandidate] { Array(filteredCandidates.prefix(5)) }

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
                let visible = visibleCandidates
                if showMentionPopup, selectedMentionIndex < visible.count {
                    insertMention(visible[selectedMentionIndex])
                } else {
                    onSubmit?()
                }
            }
            .onKeyPress(.downArrow) {
                if showMentionPopup {
                    selectedMentionIndex = min(selectedMentionIndex + 1, max(visibleCandidates.count - 1, 0))
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
                if showMentionPopup && !filteredCandidates.isEmpty {
                    mentionPopup
                        .offset(y: 24)
                }
            }
            .zIndex(showMentionPopup ? 100 : 0)
    }

    private var mentionPopup: some View {
        let visible = visibleCandidates
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(mentionKind.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("↑↓ · return")
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            Divider()
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, candidate in
                Button {
                    insertMention(candidate)
                } label: {
                    HStack(spacing: 8) {
                        if let symbol = candidate.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 10))
                                .foregroundColor(candidate.color)
                                .frame(width: 12)
                        } else {
                            Circle()
                                .fill(candidate.color)
                                .frame(width: 12, height: 12)
                        }
                        Text(candidate.name)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                        if !candidate.detail.isEmpty {
                            Text("(\(candidate.detail))")
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
        .frame(minWidth: 180, maxWidth: 280)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func editOffset(_ oldValue: String, _ newValue: String) -> Int {
        zip(oldValue, newValue).prefix { $0 == $1 }.count
    }

    private func handleTextChange(oldValue: String, newValue: String) {
        let oldCount = oldValue.count
        let newCount = newValue.count
        if newCount == oldCount + 1 {
            let at = editOffset(oldValue, newValue)
            let inserted = newValue[newValue.index(newValue.startIndex, offsetBy: at)]
            if let kind = MentionKind.kind(for: inserted) {
                mentionKind = kind
                mentionQuery = ""
                mentionStartOffset = at
                selectedMentionIndex = 0
                showMentionPopup = true
                return
            }
            guard showMentionPopup, let start = mentionStartOffset else { return }
            if at == start + 1 + mentionQuery.count {
                let extended = mentionQuery + String(inserted)
                let stillMatches = candidates.contains { $0.name.localizedCaseInsensitiveContains(extended) }
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

    private func insertMention(_ candidate: MentionCandidate) {
        guard let start = mentionStartOffset,
              let startIndex = text.index(text.startIndex, offsetBy: start, limitedBy: text.endIndex),
              startIndex < text.endIndex
        else { closeMentionPopup(); return }
        let endIndex = text.index(startIndex, offsetBy: 1 + mentionQuery.count, limitedBy: text.endIndex) ?? text.endIndex
        text.replaceSubrange(startIndex..<endIndex, with: "\(mentionKind.trigger)\(candidate.name) ")
        closeMentionPopup()
    }

    private func closeMentionPopup() {
        showMentionPopup = false
        mentionQuery = ""
        mentionStartOffset = nil
    }
}
