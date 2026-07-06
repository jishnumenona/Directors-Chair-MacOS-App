//
// TimelineCanvas+DrawLanes.swift
//
// Extracted from TimelineCanvas.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import Foundation

extension TimelineCanvas {

    // MARK: - Drawing Methods

    /// Draw the background color
    func drawBackground(context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(hex: "#262626"))
        )
    }

    /// Draw character lane backgrounds (Y offset by verticalOffset for virtual scrolling)
    func drawLaneBackgrounds(context: GraphicsContext, size: CGSize) {
        var yCursor: CGFloat = -verticalOffset

        if charactersInOrder.isEmpty {
            let placeholderRect = CGRect(
                x: 0,
                y: yCursor,
                width: size.width,
                height: TimelineLayoutConstants.baseRowHeight
            )
            context.fill(
                Path(placeholderRect),
                with: .color(Color.white.opacity(0.03))
            )
            return
        }

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let isCollapsed = hiddenTracks.contains(character)
            let laneRect = CGRect(x: 0, y: yCursor, width: size.width, height: laneHeight)

            if isCollapsed {
                context.fill(Path(laneRect), with: .color(Color.white.opacity(0.015)))
            } else if let info = trackTypeInfo(for: character) {
                context.fill(Path(laneRect), with: .color(info.color.opacity(0.04)))
            } else {
                let alpha: CGFloat = index % 2 == 0 ? 0.03 : 0.06
                context.fill(Path(laneRect), with: .color(Color.white.opacity(alpha)))
            }

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
    }

    /// Icon and accent color for non-character track types
    func trackTypeInfo(for trackName: String) -> (icon: String, color: Color)? {
        switch trackName {
        case "Action":
            return ("figure.walk", Color(hex: TimelineDefaultColors.actionBubble))
        case "Narration":
            return ("text.quote", Color(hex: TimelineDefaultColors.narrationBubble))
        case "Sound":
            return ("speaker.wave.2.fill", Color(hex: TimelineDefaultColors.soundNoteBubble))
        default:
            return nil
        }
    }

    /// Draw lane labels with eye toggle icon and type icons (Y offset by verticalOffset)
    func drawLaneLabels(context: GraphicsContext, size: CGSize) {
        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let isCollapsed = hiddenTracks.contains(character)
            let typeInfo = trackTypeInfo(for: character)

            let labelRect = CGRect(
                x: 4,
                y: yCursor + (isCollapsed ? 2 : 4),
                width: TimelineLayoutConstants.rowLabelWidth - 12,
                height: laneHeight - (isCollapsed ? 4 : 8)
            )

            let bgColor: Color
            let borderColor: Color
            if isCollapsed {
                bgColor = Color(hex: "#333333").opacity(0.7)
                borderColor = Color(hex: "#555555")
            } else if let info = typeInfo {
                bgColor = info.color.opacity(0.15)
                borderColor = info.color.opacity(0.4)
            } else {
                bgColor = Color(hex: "#444444").opacity(0.95)
                borderColor = Color(hex: "#666666")
            }

            context.fill(
                Path(roundedRect: labelRect, cornerRadius: isCollapsed ? 3 : 4),
                with: .color(bgColor)
            )
            context.stroke(
                Path(roundedRect: labelRect, cornerRadius: isCollapsed ? 3 : 4),
                with: .color(borderColor),
                lineWidth: 1
            )

            // Eye icon
            let eyeIcon = isCollapsed ? "eye.slash" : "eye.fill"
            let eyeColor = isCollapsed
                ? Color(hex: "#888888")
                : Color(hex: "#666666")
            let eyeCenter = CGPoint(
                x: labelRect.minX + 14,
                y: yCursor + laneHeight / 2
            )
            context.draw(
                Text(Image(systemName: eyeIcon))
                    .font(.system(size: isCollapsed ? 9 : 10))
                    .foregroundColor(eyeColor),
                at: eyeCenter,
                anchor: .center
            )

            // Type icon for non-character tracks
            if let info = typeInfo, !isCollapsed {
                let iconCenter = CGPoint(
                    x: labelRect.minX + 36,
                    y: yCursor + laneHeight / 2
                )
                context.draw(
                    Text(Image(systemName: info.icon))
                        .font(.system(size: 10))
                        .foregroundColor(info.color.opacity(0.8)),
                    at: iconCenter,
                    anchor: .center
                )
            }

            // Label text
            let textColor: Color
            if isCollapsed {
                textColor = Color(hex: "#666666")
            } else if let info = typeInfo {
                textColor = info.color.opacity(0.9)
            } else {
                textColor = Color(hex: "#AAAAAA")
            }
            let textPoint = CGPoint(
                x: labelRect.maxX - 8,
                y: yCursor + laneHeight / 2
            )
            context.draw(
                Text(character)
                    .font(.system(size: isCollapsed ? 10 : 12, weight: .medium))
                    .foregroundColor(textColor),
                at: textPoint,
                anchor: .trailing
            )

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
    }

    /// Draw scope marker vertical lines through tracks (no labels — those are in the header)
    func drawScopeMarkerLines(context: GraphicsContext, size: CGSize) {
        let lineTop: CGFloat = 0
        let lineBottom = size.height

        if mode == .sequence || mode == .global {
            for boundary in sceneBoundaries {
                let x = originX + boundary.time * pxPerSec
                let markerColor = Color(hex: TimelineDefaultColors.sceneBoundary)
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: lineTop))
                        path.addLine(to: CGPoint(x: x, y: lineBottom))
                    },
                    with: .color(markerColor),
                    lineWidth: 1.4
                )
            }
        }

        if mode == .global {
            for boundary in sequenceBoundaries {
                let x = originX + boundary.time * pxPerSec
                let markerColor = Color(hex: TimelineDefaultColors.sequenceBoundary)
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: lineTop))
                        path.addLine(to: CGPoint(x: x, y: lineBottom))
                    },
                    with: .color(markerColor),
                    lineWidth: 2.2
                )
            }
        }
    }

    /// Draw the playhead vertical red line through all tracks
    func drawPlayheadLine(context: GraphicsContext, size: CGSize) {
        guard let time = playheadTime else { return }
        let x = originX + time * pxPerSec
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            },
            with: .color(Color(hex: TimelineDefaultColors.playheadColor).opacity(0.8)),
            lineWidth: 1.5
        )
    }

    /// Draw shot-dialogue connection lines (lines from shot card position to linked dialogue segments)
    func drawShotDialogueConnections(context: GraphicsContext, size: CGSize) {
        guard showShotConnections, !shotDialogueConnections.isEmpty else { return }

        // Build segment lookup
        let segmentLookup = Dictionary(uniqueKeysWithValues: segments.map { ($0.id, $0) })

        for connection in shotDialogueConnections {
            guard let segment = segmentLookup[connection.dialogueSegmentId] else { continue }

            // Skip if the segment's track is hidden
            if hiddenTracks.contains(segment.character) { continue }

            // Check if this connection is highlighted (either endpoint selected)
            let isHighlighted = selectedSegmentIds.contains(connection.dialogueSegmentId) ||
                                selectedShotLabelId == connection.shotLabelId

            let connectionColor: Color
            let lineWidth: CGFloat
            let strokeStyle: StrokeStyle

            if isHighlighted {
                connectionColor = Color(hex: connection.color).opacity(0.9)
                lineWidth = 3.0
                strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            } else {
                connectionColor = Color(hex: connection.color).opacity(0.5)
                lineWidth = 1.5
                strokeStyle = StrokeStyle(lineWidth: lineWidth, dash: [6, 4])
            }

            // Shot X position (left edge of shot card, with small offset)
            let shotX = originX + connection.shotTime * pxPerSec + 4

            // Segment center position (live from current segment data)
            guard let segCenterY = segmentCenterY(for: segment) else { continue }
            let segBubbleWidth = DurationEstimator.bubbleWidth(for: segment, pxPerSec: pxPerSec, showThumbs: showThumbs)
            let segCenterX = originX + segment.start * pxPerSec + segBubbleWidth / 2

            // Draw line from shot position at top down to segment center
            let linePath = Path { path in
                path.move(to: CGPoint(x: shotX, y: 0))
                path.addLine(to: CGPoint(x: segCenterX, y: segCenterY))
            }

            context.stroke(linePath, with: .color(connectionColor), style: strokeStyle)

            // Draw small filled circle at the segment endpoint
            let dotSize: CGFloat = isHighlighted ? 4 : 3
            let dotRect = CGRect(x: segCenterX - dotSize, y: segCenterY - dotSize, width: dotSize * 2, height: dotSize * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(connectionColor))
        }
    }

    /// Get the center Y position of a segment in the tracks canvas (accounts for verticalOffset)
    func segmentCenterY(for segment: TimelineSegment) -> CGFloat? {
        var yCursor: CGFloat = -verticalOffset
        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            if character == segment.character {
                let subLane = subLaneAssignments[segment.id] ?? 0
                let subLaneY = yCursor + CGFloat(subLane) * TimelineLayoutConstants.subLaneHeight
                return subLaneY + TimelineLayoutConstants.subLaneHeight / 2
            }
            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
        return nil
    }
}
