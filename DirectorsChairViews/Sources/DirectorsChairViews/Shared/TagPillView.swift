// DirectorsChairViews/Sources/DirectorsChairViews/Shared/TagPillView.swift
//
// Pill-shaped tag display for dialogue tags

import SwiftUI

/// A pill-shaped tag view used for dialogue tags, emotions, etc.
public struct TagPillView: View {
    let text: String
    let color: Color
    let textColor: Color

    public init(
        text: String,
        color: Color = .blue.opacity(0.2),
        textColor: Color = .blue
    ) {
        self.text = text
        self.color = color
        self.textColor = textColor
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .foregroundColor(textColor)
            .cornerRadius(12)
    }
}

/// A horizontal stack of tag pills
public struct TagsStackView: View {
    let tags: [String]
    let maxVisible: Int

    public init(tags: [String], maxVisible: Int = 5) {
        self.tags = tags
        self.maxVisible = maxVisible
    }

    public var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 4) {
                ForEach(Array(tags.prefix(maxVisible).enumerated()), id: \.offset) { index, tag in
                    TagPillView(
                        text: tag,
                        color: tagColor(for: index).opacity(0.2),
                        textColor: tagColor(for: index)
                    )
                }

                if tags.count > maxVisible {
                    Text("+\(tags.count - maxVisible)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func tagColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan]
        return colors[index % colors.count]
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        TagPillView(text: "angry")

        TagsStackView(tags: ["angry", "whispered", "emotional", "dramatic"])

        TagsStackView(tags: ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7"])
    }
    .padding()
}
