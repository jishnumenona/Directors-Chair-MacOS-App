// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/NoteBubbleCard.swift
//
// Note bubble card for displaying production notes

import SwiftUI
import DirectorsChairCore

/// Note bubble card - displays production notes
///
/// Supports different note types:
/// - text: Plain text note
/// - link: Web link
/// - youtube: YouTube video with thumbnail
/// - image: Image reference
public struct NoteBubbleCard: View {
    let note: Note
    let isSelected: Bool
    let projectBasePath: URL?

    var onTap: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    public init(
        note: Note,
        isSelected: Bool = false,
        projectBasePath: URL? = nil,
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.note = note
        self.isSelected = isSelected
        self.projectBasePath = projectBasePath
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("#\(note.chronologyNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)

                noteTypeIcon

                Text(note.noteType.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)

                Spacer()

                Button(action: { onEdit?() }) {
                    Text("Edit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Title (if present)
            if !note.title.isEmpty {
                Text(note.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Content based on note type
            noteContent
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.yellow.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            Button("Edit Note") {
                onEdit?()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        }
    }

    // MARK: - Note Type Icon

    private var noteTypeIcon: some View {
        Image(systemName: iconName)
            .font(.caption)
            .foregroundColor(.yellow)
    }

    private var iconName: String {
        switch note.noteType {
        case "youtube": return "play.rectangle.fill"
        case "link": return "link"
        case "image": return "photo.fill"
        default: return "note.text"
        }
    }

    // MARK: - Note Content

    @ViewBuilder
    private var noteContent: some View {
        switch note.noteType {
        case "youtube":
            VStack(alignment: .leading, spacing: 4) {
                // YouTube thumbnail placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )

                // YouTube link
                Text(note.content)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

        case "link":
            HStack {
                Image(systemName: "safari.fill")
                    .foregroundColor(.blue)
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.blue)
                    .lineLimit(2)
            }

        case "image":
            VStack(alignment: .leading, spacing: 4) {
                // Image preview placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                    )

                Text(note.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

        default: // text
            Text(note.content)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NoteBubbleCard(
            note: Note(
                content: "Remember to have the red dress ready for scene 5",
                noteType: "text",
                chronologyNumber: 6,
                title: "Costume Reference"
            ),
            isSelected: false
        )

        NoteBubbleCard(
            note: Note(
                content: "https://youtube.com/watch?v=abc123",
                noteType: "youtube",
                chronologyNumber: 7,
                title: "Reference Video"
            ),
            isSelected: true
        )
    }
    .padding()
}
