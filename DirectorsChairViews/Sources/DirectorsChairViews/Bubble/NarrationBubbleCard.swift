// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/NarrationBubbleCard.swift
//
// Narration bubble card for displaying narration/voiceover text

import SwiftUI
import DirectorsChairCore

/// Narration bubble card - displays narration/voiceover text
///
/// Shows:
/// - Narration icon
/// - Text content
/// - Tags
/// - Chronology number
/// - Characters mentioned
public struct NarrationBubbleCard: View {
    let narration: Narration
    let isSelected: Bool

    var onTap: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    public init(
        narration: Narration,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.narration = narration
        self.isSelected = isSelected
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("#\(narration.chronologyNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)

                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundColor(.purple)

                Text("NARRATION")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)

                Spacer()

                Button(action: { onEdit?() }) {
                    Text("Edit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Narration text
            Text(narration.text)
                .font(.body)
                .italic()
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            // Characters mentioned
            if !narration.characters.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(narration.characters.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Tags
            if !narration.tags.isEmpty {
                TagsStackView(tags: narration.tags)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.purple.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.purple.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            Button("Edit Narration") {
                onEdit?()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NarrationBubbleCard(
            narration: Narration(
                text: "Meanwhile, across town, a storm was brewing...",
                tags: ["transition", "mood"],
                chronologyNumber: 4,
                characters: []
            ),
            isSelected: false
        )

        NarrationBubbleCard(
            narration: Narration(
                text: "Three years later, John would look back on this moment as the turning point.",
                tags: ["time-skip", "foreshadowing"],
                chronologyNumber: 10,
                characters: ["John"]
            ),
            isSelected: true
        )
    }
    .padding()
}
