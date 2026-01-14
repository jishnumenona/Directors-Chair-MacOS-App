// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/ActionBubbleCard.swift
//
// Action bubble card for displaying action/stage directions

import SwiftUI
import DirectorsChairCore

/// Action bubble card - displays action/stage directions
///
/// Shows:
/// - Action icon
/// - Description text
/// - Tags
/// - Chronology number
/// - Characters involved
public struct ActionBubbleCard: View {
    let action: Action
    let isSelected: Bool

    var onTap: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    public init(
        action: Action,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.action = action
        self.isSelected = isSelected
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("#\(action.chronologyNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)

                Image(systemName: "film.fill")
                    .font(.caption)
                    .foregroundColor(.orange)

                Text("ACTION")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                Spacer()

                Button(action: { onEdit?() }) {
                    Text("Edit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Description
            Text(action.description)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            // Characters involved
            if !action.characters.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(action.characters.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Tags
            if !action.tags.isEmpty {
                TagsStackView(tags: action.tags)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.orange.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            Button("Edit Action") {
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
        ActionBubbleCard(
            action: Action(
                description: "John walks across the room and picks up the phone",
                tags: ["movement", "props"],
                chronologyNumber: 3,
                characters: ["John"]
            ),
            isSelected: false
        )

        ActionBubbleCard(
            action: Action(
                description: "The lights dim as thunder rumbles in the distance",
                tags: ["lighting", "atmosphere"],
                chronologyNumber: 5,
                characters: []
            ),
            isSelected: true
        )
    }
    .padding()
}
