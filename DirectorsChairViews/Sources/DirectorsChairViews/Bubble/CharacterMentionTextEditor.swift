// DirectorsChairViews/Bubble/CharacterMentionTextEditor.swift
//
// Multi-line text editor with mention support: "@" lists characters, "#"
// lists locations, "$" lists props (owner request 2026-08-29). One popup,
// one keyboard model (arrows, return, escape), one insert rule
// ("<trigger><name> ").

import SwiftUI
import DirectorsChairCore

/// One thing the popup can offer.
struct MentionCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let color: Color
    let symbol: String?
}

/// The three mention kinds and their trigger characters.
enum MentionKind: CaseIterable {
    case character, location, prop, shot

    var trigger: Swift.Character {
        switch self {
        case .character: return "@"
        case .location: return "#"
        case .prop: return "$"
        case .shot: return "&"
        }
    }

    static func kind(for trigger: Swift.Character?) -> MentionKind? {
        allCases.first { $0.trigger == trigger }
    }
}

/// A multi-line TextEditor that supports @ / # / $ mentions.
public struct CharacterMentionTextEditor: View {
    @Binding var text: String
    let characters: [Character]
    let locations: [Location]
    let props: [Prop]
    /// The shots this shot keeps continuity with — "&" lists them.
    let continuityShots: [Shot]
    let placeholder: String
    let font: Font
    let foregroundColor: Color
    /// The field's minimum height, owned here so the text starts at the
    /// top-left and a click anywhere in the field focuses it. A caller's
    /// own `.frame(minHeight:)` centred the content-sized editor instead —
    /// the text floated mid-field and clicks near the top missed it
    /// (owner, 2026-09-04, location description).
    let minHeight: CGFloat?

    @FocusState private var isFocused: Bool
    @State private var showMentionPopup = false
    @State private var mentionKind: MentionKind = .character
    @State private var mentionQuery = ""
    /// Character offset of the trigger symbol in `text`; the query is what
    /// was typed right after it (so a mention works mid-sentence too).
    @State private var mentionStartOffset: Int?
    @State private var selectedMentionIndex: Int = 0

    public init(
        text: Binding<String>,
        characters: [Character],
        locations: [Location] = [],
        props: [Prop] = [],
        continuityShots: [Shot] = [],
        placeholder: String = "Write a description...",
        font: Font = .system(size: 14),
        foregroundColor: Color = .white.opacity(0.9),
        minHeight: CGFloat? = nil
    ) {
        self._text = text
        self.characters = characters
        self.locations = locations
        self.props = props
        self.continuityShots = continuityShots
        self.placeholder = placeholder
        self.font = font
        self.foregroundColor = foregroundColor
        self.minHeight = minHeight
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
            return continuityShots.map {
                MentionCandidate(id: $0.id, name: MentionNames.shot($0),
                                 detail: String($0.description.prefix(40)),
                                 color: .purple, symbol: "film.stack")
            }
        }
    }

    private var filteredCandidates: [MentionCandidate] {
        if mentionQuery.isEmpty { return candidates }
        return candidates.filter { $0.name.localizedCaseInsensitiveContains(mentionQuery) }
    }

    private var visibleCandidates: [MentionCandidate] { Array(filteredCandidates.prefix(6)) }

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
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    handleTextChange(oldValue: oldValue, newValue: newValue)
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
                .onKeyPress(.return) {
                    let visible = visibleCandidates
                    if showMentionPopup, selectedMentionIndex < visible.count {
                        insertMention(visible[selectedMentionIndex])
                        return .handled
                    }
                    return .ignored
                }
        }
        // The editor is content-sized; the field below the text is still the
        // field — it fills the caller's height from the top and focuses on click.
        .frame(minHeight: minHeight, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .overlay(alignment: .topLeading) {
            if showMentionPopup && !filteredCandidates.isEmpty {
                mentionPopup
                    .offset(y: 24)
            }
        }
        // The popup is an overlay: it must sit above whatever the page
        // stacks below this editor (the Notes card hid it, 2026-08-29).
        .zIndex(showMentionPopup ? 100 : 0)
    }

    private var mentionPopup: some View {
        let visible = visibleCandidates
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(popupTitle)
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
        .accessibilityIdentifier("mention-popup")
    }

    private var popupTitle: String {
        switch mentionKind {
        case .character: return "Characters"
        case .location: return "Locations"
        case .prop: return "Props"
        case .shot: return "Continuity shots"
        }
    }

    /// Where a one-character edit landed: the length of the common prefix.
    private func editOffset(_ oldValue: String, _ newValue: String) -> Int {
        zip(oldValue, newValue).prefix { $0 == $1 }.count
    }

    private func handleTextChange(oldValue: String, newValue: String) {
        let oldCount = oldValue.count
        let newCount = newValue.count

        // One character typed — anywhere in the text (owner report
        // 2026-08-29: "@" only worked at the end of a sentence).
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
            // Typing continues right after the symbol: that is the query.
            // A space is allowed while it can still complete a multi-word
            // name ("Susan L…"); anything else closes the list.
            if at == start + 1 + mentionQuery.count, inserted != "\n" {
                let extended = mentionQuery + String(inserted)
                let stillMatches = candidates.contains { $0.name.localizedCaseInsensitiveContains(extended) }
                if inserted == " " && !stillMatches {
                    closeMentionPopup()
                } else {
                    mentionQuery = extended
                    if filteredCandidates.isEmpty { closeMentionPopup() }
                    selectedMentionIndex = min(selectedMentionIndex, max(visibleCandidates.count - 1, 0))
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
                closeMentionPopup()   // the symbol itself, or text elsewhere
            }
            return
        }

        // Paste, programmatic replacement, or a mention insert: not a query.
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
