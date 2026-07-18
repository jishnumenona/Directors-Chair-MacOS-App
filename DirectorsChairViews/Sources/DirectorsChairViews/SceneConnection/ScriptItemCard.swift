// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/ScriptItemCard.swift
//
// Card component for displaying dialogue, action, or narration with output port

import SwiftUI
import DirectorsChairCore

// MARK: - Script Item Card

/// A "Connect to…" context-menu entry — menu-driven linking so connections
/// can be authored without a pointer drag (long lists, accessibility).
struct ConnectionMenuTarget: Identifiable {
    let id: String
    let title: String
    let isConnected: Bool
    var itemType: ScriptItemType? = nil
}

public struct ScriptItemCard: View {
    // MARK: - Properties

    let item: ScriptItem
    let isSelected: Bool
    let connectedShotIds: Set<String>
    var character: Character?
    var projectBasePath: URL?

    var onSelect: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDragUpdate: ((CGPoint) -> Void)?
    var onDragEnd: ((CGPoint) -> Void)?
    var connectTargetsProvider: (() -> [ConnectionMenuTarget])? = nil
    var onToggleConnect: ((ConnectionMenuTarget) -> Void)? = nil

    // MARK: - State

    @State private var isHovered: Bool = false

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            // Card content
            cardContent

            // Output port on right edge
            ConnectionPort(
                portId: "script-\(item.id)",
                itemType: item.itemType,
                isOutput: true,
                isConnected: !connectedShotIds.isEmpty,
                isHighlighted: isSelected,
                onDragStart: onDragStart,
                onDragUpdate: onDragUpdate,
                onDragEnd: onDragEnd
            )
            .padding(.trailing, 4)
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 0)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .onTapGesture {
            onSelect?()
        }
        .contextMenu {
            if !connectedShotIds.isEmpty {
                Text("\(connectedShotIds.count) connection(s)")
                Divider()
            }
            if let onToggleConnect, let targets = connectTargetsProvider?(), !targets.isEmpty {
                Menu("Connect to Shot") {
                    ForEach(targets) { target in
                        Button(action: { onToggleConnect(target) }) {
                            if target.isConnected {
                                Label(target.title, systemImage: "checkmark")
                            } else {
                                Text(target.title)
                            }
                        }
                    }
                }
                Divider()
            }
            Button("Select") {
                onSelect?()
            }
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        HStack(spacing: 10) {
            // Type indicator
            typeIndicator

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                // Subtitle (character name for dialogue)
                if let subtitle = item.subtitle {
                    Text(subtitle.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(item.itemType.color)
                }

                // Main text
                Text(item.displayText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .truncationMode(.tail)

                // Chronology badge
                HStack(spacing: 4) {
                    Text("#\(item.chronologyNumber)")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    if !connectedShotIds.isEmpty {
                        Text("\(connectedShotIds.count)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(item.itemType.color.opacity(0.3))
                            .foregroundColor(item.itemType.color)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(SceneConnectionConstants.cardPadding)
    }

    // MARK: - Type Indicator

    @ViewBuilder
    private var typeIndicator: some View {
        if item.itemType == .dialogue, let charName = item.subtitle {
            CharacterAvatarView(
                character: character,
                characterName: charName,
                size: 32,
                projectBasePath: projectBasePath
            )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.itemType.color.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: item.itemType.icon)
                    .font(.system(size: 14))
                    .foregroundColor(item.itemType.color)
            }
        }
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        if isSelected {
            return SceneConnectionColors.cardBackgroundSelected
        } else if isHovered {
            return SceneConnectionColors.cardBackgroundHover
        } else {
            return SceneConnectionColors.cardBackground
        }
    }

    private var borderColor: Color {
        isSelected ? item.itemType.color : .clear
    }
}

// MARK: - Script Item Group Card

public struct ScriptItemGroupCard: View {
    // MARK: - Properties

    let group: ScriptItemGroup
    let isSelected: Bool
    let connectedShotIds: Set<String>
    var character: Character?
    var projectBasePath: URL?

    var onSelect: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDragUpdate: ((CGPoint) -> Void)?
    var onDragEnd: ((CGPoint) -> Void)?
    var connectTargetsProvider: (() -> [ConnectionMenuTarget])? = nil
    var onToggleConnect: ((ConnectionMenuTarget) -> Void)? = nil

    // MARK: - State

    @State private var isHovered: Bool = false

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            // Group content
            VStack(alignment: .leading, spacing: 0) {
                // Parent dialogue card
                dialogueContent

                // Children with connector line
                if !group.children.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        // Vertical connector line
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(SceneConnectionColors.dialogue.opacity(0.3))
                                .frame(width: 2)
                        }
                        .padding(.leading, 22)

                        // Child items
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(group.children) { child in
                                childCard(child)
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 4)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }

            Spacer(minLength: 0)

            // Single output port for the group (keyed to dialogue ID)
            ConnectionPort(
                portId: "script-\(group.dialogue.id)",
                itemType: .dialogue,
                isOutput: true,
                isConnected: !connectedShotIds.isEmpty,
                isHighlighted: isSelected,
                onDragStart: onDragStart,
                onDragUpdate: onDragUpdate,
                onDragEnd: onDragEnd
            )
            .padding(.trailing, 4)
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 0)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .onTapGesture {
            onSelect?()
        }
        .contextMenu {
            if !connectedShotIds.isEmpty {
                Text("\(connectedShotIds.count) connection(s)")
                Divider()
            }
            Text("\(group.children.count) sub-item(s)")
            Divider()
            if let onToggleConnect, let targets = connectTargetsProvider?(), !targets.isEmpty {
                Menu("Connect to Shot") {
                    ForEach(targets) { target in
                        Button(action: { onToggleConnect(target) }) {
                            if target.isConnected {
                                Label(target.title, systemImage: "checkmark")
                            } else {
                                Text(target.title)
                            }
                        }
                    }
                }
                Divider()
            }
            Button("Select") {
                onSelect?()
            }
        }
    }

    // MARK: - Dialogue Content

    @ViewBuilder
    private var dialogueContent: some View {
        HStack(spacing: 10) {
            // Character avatar
            if let charName = group.dialogue.subtitle {
                CharacterAvatarView(
                    character: character,
                    characterName: charName,
                    size: 32,
                    projectBasePath: projectBasePath
                )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ScriptItemType.dialogue.color.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: ScriptItemType.dialogue.icon)
                        .font(.system(size: 14))
                        .foregroundColor(ScriptItemType.dialogue.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let subtitle = group.dialogue.subtitle {
                    Text(subtitle.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(ScriptItemType.dialogue.color)
                }

                Text(group.dialogue.displayText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    Text("#\(group.dialogue.chronologyNumber)")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    if !connectedShotIds.isEmpty {
                        Text("\(connectedShotIds.count)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(ScriptItemType.dialogue.color.opacity(0.3))
                            .foregroundColor(ScriptItemType.dialogue.color)
                            .cornerRadius(4)
                    }

                    // Child count badge
                    Text("\(group.children.count) sub")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(SceneConnectionConstants.cardPadding)
    }

    // MARK: - Child Card

    @ViewBuilder
    private func childCard(_ child: ScriptItem) -> some View {
        HStack(spacing: 6) {
            // Small type icon
            Image(systemName: child.itemType.icon)
                .font(.system(size: 10))
                .foregroundColor(child.itemType.color)
                .frame(width: 16, height: 16)

            // Truncated text
            Text(child.displayText)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(child.itemType.color.opacity(0.08))
        .cornerRadius(4)
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        if isSelected {
            return SceneConnectionColors.cardBackgroundSelected
        } else if isHovered {
            return SceneConnectionColors.cardBackgroundHover
        } else {
            return SceneConnectionColors.cardBackground
        }
    }

    private var borderColor: Color {
        isSelected ? ScriptItemType.dialogue.color : .clear
    }
}

// MARK: - Preview

#if DEBUG
struct ScriptItemCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: SceneConnectionConstants.cardSpacing) {
            ScriptItemCard(
                item: .dialogue(Dialogue(
                    uuid: "1",
                    character: "HERO",
                    text: "I've been waiting for this moment my whole life. Let's do this.",
                    tags: [],
                    costumes: [],
                    effects: [],
                    chronologyNumber: 1,
                    globalChronologyNumber: 1
                )),
                isSelected: false,
                connectedShotIds: []
            )

            ScriptItemCard(
                item: .action(Action(
                    uuid: "2",
                    description: "The hero walks slowly through the abandoned warehouse, footsteps echoing.",
                    tags: [],
                    costumes: [],
                    effects: [],
                    color: "",
                    textColor: "",
                    chronologyNumber: 2,
                    globalChronologyNumber: 2,
                    characters: []
                )),
                isSelected: true,
                connectedShotIds: ["shot1", "shot2"]
            )

            ScriptItemCard(
                item: .narration(Narration(
                    uuid: "3",
                    text: "Little did he know, this would be the last time he'd see the sun.",
                    tags: [],
                    costumes: [],
                    effects: [],
                    color: "",
                    textColor: "",
                    chronologyNumber: 3,
                    globalChronologyNumber: 3,
                    characters: []
                )),
                isSelected: false,
                connectedShotIds: ["shot1"]
            )
        }
        .frame(width: SceneConnectionConstants.scriptColumnWidth)
        .padding()
        .background(SceneConnectionColors.sidebarBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif
