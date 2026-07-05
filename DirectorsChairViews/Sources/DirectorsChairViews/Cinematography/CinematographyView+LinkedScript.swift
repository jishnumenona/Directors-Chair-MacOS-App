//
// CinematographyView+LinkedScript.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices

struct LinkedScriptElementsSection: View {
    let shot: Shot
    let scene: DCScene
    var onJumpToScript: ((String, String) -> Void)?

    @State private var isExpanded = true

    private var linkedItems: [(id: String, type: String, icon: String, color: Color, label: String, text: String, character: String?)] {
        var items: [(id: String, type: String, icon: String, color: Color, label: String, text: String, character: String?)] = []

        for dialogueId in shot.linkedDialogueIds {
            if let dialogue = scene.dialogues.first(where: { $0.id == dialogueId }) {
                items.append((
                    id: dialogue.id,
                    type: "dialogue",
                    icon: "text.quote",
                    color: .blue,
                    label: "Dialogue",
                    text: dialogue.text,
                    character: dialogue.character
                ))
            }
        }

        for actionId in shot.linkedActionIds {
            if let action = scene.actions.first(where: { $0.id == actionId }) {
                items.append((
                    id: action.id,
                    type: "action",
                    icon: "figure.walk",
                    color: .orange,
                    label: "Action",
                    text: action.description,
                    character: nil
                ))
            }
        }

        for narrationId in shot.linkedNarrationIds {
            if let narration = scene.narrations.first(where: { $0.id == narrationId }) {
                items.append((
                    id: narration.id,
                    type: "narration",
                    icon: "text.alignleft",
                    color: .teal,
                    label: "Narration",
                    text: narration.text,
                    character: nil
                ))
            }
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)

                    Text("SCRIPT ELEMENTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)

                    Text("\(linkedItems.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.7)))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(Array(linkedItems.enumerated()), id: \.element.id) { _, item in
                        LinkedScriptItemRow(
                            icon: item.icon,
                            color: item.color,
                            label: item.label,
                            text: item.text,
                            character: item.character,
                            onJump: {
                                onJumpToScript?(item.id, item.type)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

/// Individual row for a linked script element
struct LinkedScriptItemRow: View {
    let icon: String
    let color: Color
    let label: String
    let text: String
    let character: String?
    let onJump: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Type indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4, height: 36)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                        .tracking(0.8)

                    if let character = character {
                        Text(character)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }

                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Jump to script button
            Button(action: onJump) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.doc")
                        .font(.system(size: 10))
                    Text("Script")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isHovered ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternarySystemFill).opacity(0.3))
        )
    }
}
