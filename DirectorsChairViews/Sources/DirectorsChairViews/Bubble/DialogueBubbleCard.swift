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
    var onPlay: (() -> Void)?
    var onStop: (() -> Void)?

    public init(
        dialogue: Dialogue,
        character: Character? = nil,
        isSelected: Bool = false,
        isPrimaryCharacter: Bool = false,
        projectBasePath: URL? = nil,
        onTap: (() -> Void)? = nil,
        onDoubleTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onPlay: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil
    ) {
        self.dialogue = dialogue
        self.character = character
        self.isSelected = isSelected
        self.isPrimaryCharacter = isPrimaryCharacter
        self.projectBasePath = projectBasePath
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onEdit = onEdit
        self.onPlay = onPlay
        self.onStop = onStop
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

            // Dialogue text
            Text(htmlToPlainText(dialogue.text))
                .font(.body)
                .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF"))
                .multilineTextAlignment(.leading)

            // Tags
            if !dialogue.tags.isEmpty {
                TagsStackView(tags: dialogue.tags)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: character?.color ?? "#555555"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .frame(maxWidth: 500)
        .onTapGesture {
            onTap?()
        }
        .onTapGesture(count: 2) {
            onDoubleTap?()
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            // Chronology number badge
            Text("#\(dialogue.chronologyNumber)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)

            // Character name
            Text(dialogue.character)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: character?.textColor ?? "#FFFFFF"))

            Spacer()

            // Audio indicator
            if dialogue.audioFilePath != nil {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // Edit button
            Button(action: { onEdit?() }) {
                Text("Edit")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            // Play/Stop buttons
            if dialogue.audioFilePath != nil {
                Button(action: { onPlay?() }) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: { onStop?() }) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
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

        Button("Add to Vision Board") {
            // TODO: Implement
        }

        Divider()

        Button("Delete", role: .destructive) {
            // TODO: Implement deletion callback
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
