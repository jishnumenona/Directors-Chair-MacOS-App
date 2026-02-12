// DirectorsChairViews/Sources/DirectorsChairViews/SceneConnection/ShotConnectionCard.swift
//
// Card component for displaying a shot with input port for connections

import SwiftUI
import AppKit
import DirectorsChairCore

// MARK: - Shot Connection Card

public struct ShotConnectionCard: View {
    // MARK: - Properties

    let shot: Shot
    let isSelected: Bool
    let isHighlighted: Bool
    let connectedDialogueCount: Int
    let connectedActionCount: Int
    let connectedNarrationCount: Int
    let highlightedItemType: ScriptItemType?
    var showPreviewImage: Bool = false
    var projectBasePath: URL? = nil

    var onSelect: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onPortHit: ((ScriptItemType) -> Void)?

    // MARK: - State

    @State private var isHovered: Bool = false

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            // Input ports on left edge
            inputPorts

            // Card content
            cardContent
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: (isSelected || isHighlighted) ? 2 : 0)
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
            Text("Shot #\(shot.shotId)")
            Divider()
            if totalConnections > 0 {
                Text("\(totalConnections) connection(s)")
                Divider()
            }
            Button("Select") {
                onSelect?()
            }
        }
    }

    // MARK: - Input Ports

    @ViewBuilder
    private var inputPorts: some View {
        VStack(spacing: 6) {
            // Dialogue port
            ConnectionPort(
                portId: "shot-dialogue-\(shot.id)",
                itemType: .dialogue,
                isOutput: false,
                isConnected: connectedDialogueCount > 0,
                isHighlighted: highlightedItemType == .dialogue
            )

            // Action port
            ConnectionPort(
                portId: "shot-action-\(shot.id)",
                itemType: .action,
                isOutput: false,
                isConnected: connectedActionCount > 0,
                isHighlighted: highlightedItemType == .action
            )

            // Narration port
            ConnectionPort(
                portId: "shot-narration-\(shot.id)",
                itemType: .narration,
                isOutput: false,
                isConnected: connectedNarrationCount > 0,
                isHighlighted: highlightedItemType == .narration
            )
        }
        .padding(.leading, 4)
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Shot number badge
                Text("Shot \(shot.shotId)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let videoPath = shot.videoPath, !videoPath.isEmpty {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green.opacity(0.8))
                }

                Spacer()

                // Status badge
                statusBadge
            }

            if showPreviewImage, let previewPath = shot.previewImage, !previewPath.isEmpty {
                // Preview image mode
                previewImageView(path: previewPath)
            } else if showPreviewImage {
                // Preview mode but no image available — show placeholder
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No preview")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color.white.opacity(0.03))
                .cornerRadius(6)
            } else {
                // Description mode (default)
                shotDetailsContent
            }

            // Connection counts
            if totalConnections > 0 {
                connectionIndicators
            }
        }
        .padding(SceneConnectionConstants.cardPadding)
    }

    // MARK: - Shot Details Content

    @ViewBuilder
    private var shotDetailsContent: some View {
        // Shot type and camera info
        HStack(spacing: 8) {
            Text(shot.shotType)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)

            Text(shot.cameraAngle)
                .font(.caption2)
                .foregroundColor(.gray)

            if let lens = shot.lensMm {
                Text("\(lens)mm")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }

        if !shot.description.isEmpty {
            Text(shot.description)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }

    // MARK: - Preview Image

    @ViewBuilder
    private func previewImageView(path: String) -> some View {
        let imageURL: URL? = {
            if let base = projectBasePath {
                return base.appendingPathComponent(path)
            }
            return URL(fileURLWithPath: path)
        }()

        if let url = imageURL, let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipped()
                .cornerRadius(6)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.5))
                Text("Image not found")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        let status = ShotStatus(rawValue: shot.status) ?? .planning

        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            Text(status.rawValue)
                .font(.caption2)
                .foregroundColor(status.color)
        }
    }

    // MARK: - Connection Indicators

    @ViewBuilder
    private var connectionIndicators: some View {
        HStack(spacing: 8) {
            if connectedDialogueCount > 0 {
                connectionBadge(count: connectedDialogueCount, type: .dialogue)
            }
            if connectedActionCount > 0 {
                connectionBadge(count: connectedActionCount, type: .action)
            }
            if connectedNarrationCount > 0 {
                connectionBadge(count: connectedNarrationCount, type: .narration)
            }
        }
    }

    @ViewBuilder
    private func connectionBadge(count: Int, type: ScriptItemType) -> some View {
        HStack(spacing: 2) {
            Image(systemName: type.icon)
                .font(.system(size: 8))
            Text("\(count)")
                .font(.caption2)
        }
        .foregroundColor(type.color)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(type.color.opacity(0.2))
        .cornerRadius(4)
    }

    // MARK: - Computed Properties

    private var totalConnections: Int {
        connectedDialogueCount + connectedActionCount + connectedNarrationCount
    }

    private var backgroundColor: Color {
        if isSelected || isHighlighted {
            return SceneConnectionColors.cardBackgroundSelected
        } else if isHovered {
            return SceneConnectionColors.cardBackgroundHover
        } else {
            return SceneConnectionColors.cardBackground
        }
    }

    private var borderColor: Color {
        if isSelected {
            if let itemType = highlightedItemType {
                return itemType.color
            }
            return .accentColor
        }
        if isHighlighted {
            return .accentColor
        }
        return .clear
    }
}

// MARK: - Preview

#if DEBUG
struct ShotConnectionCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: SceneConnectionConstants.cardSpacing) {
            ShotConnectionCard(
                shot: Shot(
                    shotId: 1,
                    description: "Close-up on protagonist's face showing determination",
                    cameraAngle: "Eye Level",
                    lensMm: 85,
                    shotType: "CU"
                ),
                isSelected: false,
                isHighlighted: false,
                connectedDialogueCount: 2,
                connectedActionCount: 0,
                connectedNarrationCount: 1,
                highlightedItemType: nil
            )

            ShotConnectionCard(
                shot: Shot(
                    shotId: 2,
                    description: "Wide establishing shot of the warehouse",
                    status: "Ready",
                    cameraAngle: "High",
                    lensMm: 24,
                    shotType: "WS"
                ),
                isSelected: true,
                isHighlighted: false,
                connectedDialogueCount: 0,
                connectedActionCount: 1,
                connectedNarrationCount: 0,
                highlightedItemType: .action
            )

            ShotConnectionCard(
                shot: Shot(
                    shotId: 3,
                    description: "Over-the-shoulder shot during conversation",
                    status: "Shot",
                    cameraAngle: "Eye Level",
                    lensMm: 50,
                    shotType: "OTS"
                ),
                isSelected: false,
                isHighlighted: false,
                connectedDialogueCount: 0,
                connectedActionCount: 0,
                connectedNarrationCount: 0,
                highlightedItemType: nil
            )
        }
        .frame(width: SceneConnectionConstants.shotsColumnWidth)
        .padding()
        .background(SceneConnectionColors.sidebarBackground)
        .previewLayout(.sizeThatFits)
    }
}
#endif
