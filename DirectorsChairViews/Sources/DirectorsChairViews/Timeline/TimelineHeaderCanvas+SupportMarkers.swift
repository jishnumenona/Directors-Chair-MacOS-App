//
// TimelineHeaderCanvas+SupportMarkers.swift
//
// Extracted from TimelineHeaderCanvas.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension. Behaviour unchanged.
//

import SwiftUI
import AppKit
import DirectorsChairCore

extension TimelineHeaderCanvas {

    // MARK: - Support Cue Lane Drawing

    func drawSupportCueLane(context: GraphicsContext, size: CGSize) {
        guard !supportCues.isEmpty else { return }

        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset +
                        sfxLaneOffset
        let totalLaneHeight = supportLaneOffset
        let supportAccent = Color(hex: "#2DD4BF")

        // --- Collapsed strip ---
        if !showSupportLane {
            let collapsedRect = CGRect(x: 0, y: baseLaneY, width: size.width, height: totalLaneHeight)
            context.fill(Path(collapsedRect), with: .color(Color(hex: "#1A1A1A").opacity(0.7)))

            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )
            context.stroke(
                Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY + totalLaneHeight)) },
                with: .color(Color(hex: "#444444")), lineWidth: 1
            )

            let labelRect = CGRect(x: 4, y: baseLaneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            context.fill(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#333333").opacity(0.7)))
            context.stroke(Path(roundedRect: labelRect, cornerRadius: 3), with: .color(Color(hex: "#555555")), lineWidth: 1)

            let centerY = baseLaneY + totalLaneHeight / 2

            context.draw(
                Text(Image(systemName: "eye.slash")).font(.system(size: 9)).foregroundColor(Color(hex: "#888888")),
                at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
            )
            context.draw(
                Text(Image(systemName: "person.2.fill")).font(.system(size: 9)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
            )
            context.draw(
                Text("SUPPORT").font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "#666666")),
                at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
            )
            return
        }

        // --- Expanded lane ---
        let singleLaneH = TimelineLayoutConstants.supportLaneHeight
        let barHeight: CGFloat = 36
        let subLanes = supportCueSubLanes

        // Lane background
        let laneBg = CGRect(x: 0, y: baseLaneY, width: size.width, height: totalLaneHeight)
        context.fill(Path(laneBg), with: .color(Color(nsColor: .controlBackgroundColor).opacity(0.3)))

        // Top separator
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )
        // Bottom separator
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: baseLaneY + totalLaneHeight)); p.addLine(to: CGPoint(x: size.width, y: baseLaneY + totalLaneHeight)) },
            with: .color(Color(hex: "#555555")), lineWidth: 1
        )

        // Lane label with eye toggle
        let labelRect = CGRect(x: 4, y: baseLaneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#2A2A2A")))
        context.stroke(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(Color(hex: "#444444")), lineWidth: 1)

        let centerY = baseLaneY + totalLaneHeight / 2

        context.draw(
            Text(Image(systemName: "eye.fill")).font(.system(size: 10)).foregroundColor(Color(hex: "#666666")),
            at: CGPoint(x: labelRect.minX + 14, y: centerY), anchor: .center
        )
        context.draw(
            Text(Image(systemName: "person.2.fill")).font(.system(size: 10)).foregroundColor(supportAccent),
            at: CGPoint(x: labelRect.minX + 34, y: centerY), anchor: .center
        )
        context.draw(
            Text("SUPPORT").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#BBBBBB")),
            at: CGPoint(x: labelRect.maxX - 8, y: centerY), anchor: .trailing
        )

        for cue in supportCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2

            var cueX = originX + CGFloat(cue.startTime) * pxPerSec
            var cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let isDragging = cue.id == draggingSupportCueId
            let isResizing = cue.id == resizingSupportCueId

            if isDragging && !isResizing {
                cueX += (dragCurrentX - supportCueDragStartX)
            }

            if isResizing {
                cueW += (dragCurrentX - supportCueResizeStartX)
                cueW = max(20, cueW)
            }

            if cueX + cueW < 0 || cueX > size.width { continue }

            let cueColor = Color(hex: cue.markerColor)

            // Main bar (no fade gradients for support actions)
            let barRect = CGRect(x: cueX, y: barY, width: cueW, height: barHeight)
            let barPath = Path(roundedRect: barRect, cornerRadius: 4)
            context.fill(barPath, with: .color(cueColor.opacity(0.5)))
            context.stroke(barPath, with: .color(cueColor.opacity(isDragging || isResizing ? 1.0 : 0.8)), lineWidth: isDragging || isResizing ? 2 : 1)

            // Label: action type icon + truncated name
            let labelMaxW = max(0, cueW - 8)
            if labelMaxW > 20 {
                var clipped = context
                clipped.clip(to: Path(CGRect(x: cueX + 4, y: barY, width: labelMaxW, height: barHeight)))

                clipped.draw(
                    Text(Image(systemName: cue.actionType.icon))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9)),
                    at: CGPoint(x: cueX + 12, y: barY + barHeight / 2),
                    anchor: .center
                )

                if labelMaxW > 40 {
                    let displayName = cue.cueNumber + " " + cue.name
                    clipped.draw(
                        Text(displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.9)),
                        at: CGPoint(x: cueX + 22, y: barY + barHeight / 2),
                        anchor: .leading
                    )
                }
            }

            // Resize handle
            let handleX = cueX + cueW - 2
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: handleX, y: barY + 4))
                    p.addLine(to: CGPoint(x: handleX, y: barY + barHeight - 4))
                },
                with: .color(.white.opacity(0.3)),
                lineWidth: 2
            )
        }
    }

    // MARK: - Support Hit Testing

    func findSupportCue(at point: CGPoint) -> SupportCue? {
        guard showSupportLane, !supportCues.isEmpty else { return nil }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset +
                        sfxLaneOffset
        let singleLaneH = TimelineLayoutConstants.supportLaneHeight
        let barHeight: CGFloat = 36
        let hitMargin: CGFloat = 4
        let subLanes = supportCueSubLanes

        for cue in supportCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2
            let cueX = originX + CGFloat(cue.startTime) * pxPerSec
            let cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let cueRect = CGRect(
                x: cueX - hitMargin,
                y: barY - hitMargin,
                width: cueW + hitMargin * 2,
                height: barHeight + hitMargin * 2
            )
            if cueRect.contains(point) {
                return cue
            }
        }
        return nil
    }

    func findSupportCueRightEdge(at point: CGPoint) -> SupportCue? {
        guard showSupportLane, !supportCues.isEmpty else { return nil }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset +
                        sfxLaneOffset
        let singleLaneH = TimelineLayoutConstants.supportLaneHeight
        let barHeight: CGFloat = 36
        let edgeThreshold: CGFloat = 8
        let subLanes = supportCueSubLanes

        for cue in supportCues {
            let subLane = subLanes[cue.id] ?? 0
            let laneY = baseLaneY + CGFloat(subLane) * singleLaneH
            let barY = laneY + (singleLaneH - barHeight) / 2
            let cueX = originX + CGFloat(cue.startTime) * pxPerSec
            let cueW = max(20, CGFloat(cue.duration) * pxPerSec)
            let cueRight = cueX + cueW

            if point.y >= barY && point.y <= barY + barHeight &&
               abs(point.x - cueRight) <= edgeThreshold {
                return cue
            }
        }
        return nil
    }

    func isSupportEyeToggleHit(at point: CGPoint) -> Bool {
        guard !supportCues.isEmpty else { return false }
        let baseLaneY = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap +
                        shotLaneOffset +
                        soundtrackLaneHeight +
                        lightingLaneOffset +
                        sfxLaneOffset
        let totalLaneHeight = supportLaneOffset

        if showSupportLane {
            let labelRect = CGRect(x: 4, y: baseLaneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
            let eyeRect = CGRect(x: labelRect.minX, y: labelRect.minY, width: 28, height: labelRect.height)
            return eyeRect.contains(point)
        } else {
            let labelRect = CGRect(x: 4, y: baseLaneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            return labelRect.contains(point)
        }
    }

    /// Draw user markers on the ruler baseline
    func drawHeaderUserMarkers(context: GraphicsContext, size: CGSize) {
        guard !userMarkers.isEmpty else { return }

        let rulerBaselineY = TimelineLayoutConstants.topMargin + TimelineLayoutConstants.rulerHeight - 1
        let diamondSize = TimelineLayoutConstants.userMarkerDiamondSize
        let iconSize = TimelineLayoutConstants.userMarkerIconSize

        for marker in userMarkers {
            let x = originX + marker.time * pxPerSec
            let markerColor = Color(hex: marker.color)

            // Diamond shape on ruler baseline
            let diamondPath = Path { path in
                path.move(to: CGPoint(x: x, y: rulerBaselineY - diamondSize))
                path.addLine(to: CGPoint(x: x + diamondSize, y: rulerBaselineY))
                path.addLine(to: CGPoint(x: x, y: rulerBaselineY + diamondSize))
                path.addLine(to: CGPoint(x: x - diamondSize, y: rulerBaselineY))
                path.closeSubpath()
            }
            context.fill(diamondPath, with: .color(markerColor))
            context.stroke(diamondPath, with: .color(markerColor.opacity(0.6)), lineWidth: 1)

            // SF Symbol icon above diamond
            context.draw(
                Text(Image(systemName: marker.icon))
                    .font(.system(size: iconSize))
                    .foregroundColor(markerColor),
                at: CGPoint(x: x, y: rulerBaselineY - diamondSize - iconSize / 2 - 2),
                anchor: .center
            )

            // Label below diamond (compact)
            let labelWidth = max(30, CGFloat(marker.label.count) * 6 + 8)
            let labelHeight: CGFloat = 14
            let labelY = rulerBaselineY + diamondSize + 2

            let labelRect = CGRect(
                x: x - labelWidth / 2,
                y: labelY,
                width: labelWidth,
                height: labelHeight
            )
            context.fill(
                Path(roundedRect: labelRect, cornerRadius: 2),
                with: .color(markerColor.opacity(0.25))
            )

            var clippedCtx = context
            clippedCtx.clip(to: Path(labelRect))
            clippedCtx.draw(
                Text(marker.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(markerColor),
                at: CGPoint(x: x, y: labelY + labelHeight / 2),
                anchor: .center
            )
        }
    }

    /// Compute non-overlapping stack levels for a set of markers.
    /// Returns an array of stack levels (0-based) parallel to the input array.
    func computeStackLevels(
        xPositions: [CGFloat],
        labelWidths: [CGFloat]
    ) -> [Int] {
        struct MarkerSpan {
            let index: Int
            let left: CGFloat
            let right: CGFloat
        }
        // Sort by x position for greedy placement
        var spans = xPositions.enumerated().map { i, x in
            MarkerSpan(index: i, left: x - labelWidths[i] / 2, right: x + labelWidths[i] / 2 + 4)
        }
        spans.sort { $0.left < $1.left }

        var levels = [Int](repeating: 0, count: xPositions.count)
        var levelEndX: [CGFloat] = [] // rightmost occupied X per level

        for span in spans {
            var assignedLevel = -1
            for (level, endX) in levelEndX.enumerated() {
                if span.left >= endX {
                    assignedLevel = level
                    break
                }
            }
            if assignedLevel == -1 {
                assignedLevel = levelEndX.count
                levelEndX.append(span.right)
            } else {
                levelEndX[assignedLevel] = span.right
            }
            levels[span.index] = assignedLevel
        }
        return levels
    }

    /// Draw scope markers (scene/sequence boundary labels + vertical lines through header)
    func drawScopeMarkers(context: GraphicsContext, size: CGSize) {
        let lineTop = TimelineLayoutConstants.topMargin +
                      TimelineLayoutConstants.rulerHeight +
                      TimelineLayoutConstants.rulerGap +
                      shotLaneOffset - 6
        let lineBottom = size.height

        var sequenceLevelCount = 0

        // Sequence boundaries (only in global mode) — draw first (top rows)
        if mode == .global {
            var xPositions: [CGFloat] = []
            var labelWidths: [CGFloat] = []
            var isDraggingFlags: [Bool] = []

            for boundary in sequenceBoundaries {
                var x = originX + boundary.time * pxPerSec
                let isDragging = boundary.id == draggingBoundaryId && draggingBoundaryIsSequence
                if isDragging { x += (dragCurrentX - dragBoundaryStartX) }
                xPositions.append(x)
                labelWidths.append(max(50, CGFloat(boundary.name.count) * 7 + 16))
                isDraggingFlags.append(isDragging)
            }

            let levels = computeStackLevels(xPositions: xPositions, labelWidths: labelWidths)
            sequenceLevelCount = (levels.max() ?? -1) + 1

            for (i, boundary) in sequenceBoundaries.enumerated() {
                drawBoundaryMarker(
                    context: context,
                    x: xPositions[i],
                    lineTop: lineTop,
                    lineBottom: lineBottom,
                    label: boundary.name,
                    color: TimelineDefaultColors.sequenceBoundary,
                    thick: true,
                    stackLevel: levels[i],
                    isDragging: isDraggingFlags[i]
                )
            }
        }

        // Scene boundaries
        if mode == .sequence || mode == .global {
            let baseLevel = mode == .global ? sequenceLevelCount : 0
            var xPositions: [CGFloat] = []
            var labelWidths: [CGFloat] = []
            var isDraggingFlags: [Bool] = []

            for boundary in sceneBoundaries {
                var x = originX + boundary.time * pxPerSec
                let isDragging = boundary.id == draggingBoundaryId && !draggingBoundaryIsSequence
                if isDragging { x += (dragCurrentX - dragBoundaryStartX) }
                xPositions.append(x)
                labelWidths.append(max(50, CGFloat(boundary.name.count) * 7 + 16))
                isDraggingFlags.append(isDragging)
            }

            let levels = computeStackLevels(xPositions: xPositions, labelWidths: labelWidths)

            for (i, boundary) in sceneBoundaries.enumerated() {
                drawBoundaryMarker(
                    context: context,
                    x: xPositions[i],
                    lineTop: lineTop,
                    lineBottom: lineBottom,
                    label: boundary.name,
                    color: TimelineDefaultColors.sceneBoundary,
                    thick: false,
                    stackLevel: baseLevel + levels[i],
                    isDragging: isDraggingFlags[i]
                )
            }
        }
    }

    /// Draw a boundary marker with label in top margin area
    func drawBoundaryMarker(
        context: GraphicsContext,
        x: CGFloat,
        lineTop: CGFloat,
        lineBottom: CGFloat,
        label: String,
        color: String,
        thick: Bool,
        stackLevel: Int,
        isDragging: Bool = false
    ) {
        let markerColor = Color(hex: color)

        // Vertical line through shot lane and tracks area
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: x, y: lineTop))
                path.addLine(to: CGPoint(x: x, y: lineBottom))
            },
            with: .color(markerColor.opacity(isDragging ? 0.5 : 1.0)),
            lineWidth: thick ? 2.2 : 1.4
        )

        // Label box in the top margin area
        let labelHeight: CGFloat = 18
        let labelWidth = max(50, CGFloat(label.count) * 7 + 16)
        let labelY: CGFloat = 4 + CGFloat(stackLevel) * (labelHeight + 4)
        let labelBottom = labelY + labelHeight

        // Connector line from label bottom down to the ruler baseline
        let rulerBaseline = TimelineLayoutConstants.topMargin + TimelineLayoutConstants.rulerHeight - 1
        if labelBottom < rulerBaseline {
            let connectorStyle = StrokeStyle(lineWidth: 1, dash: [3, 2])
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: x, y: labelBottom + 2))
                    path.addLine(to: CGPoint(x: x, y: rulerBaseline))
                },
                with: .color(markerColor.opacity(isDragging ? 0.4 : 0.6)),
                style: connectorStyle
            )
            // Small tick mark at the ruler baseline
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: x - 3, y: rulerBaseline))
                    path.addLine(to: CGPoint(x: x + 3, y: rulerBaseline))
                },
                with: .color(markerColor.opacity(isDragging ? 0.5 : 0.8)),
                lineWidth: 1.5
            )
        }

        let labelRect = CGRect(
            x: x - labelWidth / 2,
            y: labelY,
            width: labelWidth,
            height: labelHeight
        )

        context.fill(
            Path(roundedRect: labelRect, cornerRadius: 3),
            with: .color(markerColor.opacity(isDragging ? 0.7 : 0.9))
        )
        context.stroke(
            Path(roundedRect: labelRect, cornerRadius: 3),
            with: .color(markerColor),
            lineWidth: isDragging ? 2.5 : 1.5
        )

        context.draw(
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white),
            at: CGPoint(x: x, y: labelY + labelHeight / 2),
            anchor: .center
        )
    }
}
