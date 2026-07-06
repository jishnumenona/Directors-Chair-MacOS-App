//
// TimelineCanvas+DrawSegments.swift
//
// Extracted from TimelineCanvas.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import Foundation

extension TimelineCanvas {

    /// Draw segments with VIEWPORT CULLING for 60fps performance (Y offset by verticalOffset)
    func drawSegments(context: GraphicsContext, size: CGSize, viewport: CGRect) {
        let segmentsByCharacter = Dictionary(grouping: segments) { $0.character }

        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let laneY = yCursor

            guard let characterSegments = segmentsByCharacter[character],
                  !hiddenTracks.contains(character) else {
                yCursor += laneHeight + TimelineLayoutConstants.rowGap
                continue
            }

            for segment in characterSegments {
                var rx = originX + segment.start * pxPerSec
                let isGroupDrag = draggingSegmentId != nil && selectedSegmentIds.count > 1
                let isDragging = segment.id == draggingSegmentId ||
                    (isGroupDrag && selectedSegmentIds.contains(segment.id))

                if isDragging {
                    rx += (dragCurrentX - dragStartX)
                }

                let bubbleWidth = DurationEstimator.bubbleWidth(for: segment, pxPerSec: pxPerSec, showThumbs: showThumbs)

                let visibleStart = viewport.minX - TimelineLayoutConstants.viewportBuffer * pxPerSec
                let visibleEnd = viewport.maxX + TimelineLayoutConstants.viewportBuffer * pxPerSec

                if rx + bubbleWidth < visibleStart || rx > visibleEnd {
                    continue
                }

                let subLane = subLaneAssignments[segment.id] ?? 0
                let subLaneY = laneY + CGFloat(subLane) * TimelineLayoutConstants.subLaneHeight

                let bubbleRect = CGRect(
                    x: rx + TimelineLayoutConstants.tailWidth,
                    y: subLaneY + 6,
                    width: bubbleWidth - TimelineLayoutConstants.tailWidth,
                    height: TimelineLayoutConstants.subLaneHeight - 12
                )

                drawBubble(
                    context: context,
                    rect: bubbleRect,
                    segment: segment,
                    isSelected: selectedSegmentIds.contains(segment.id),
                    isDragging: isDragging
                )

                drawBubbleTail(context: context, bubbleRect: bubbleRect, segment: segment)
            }

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
    }

    /// Draw a speech bubble
    func drawBubble(
        context: GraphicsContext,
        rect: CGRect,
        segment: TimelineSegment,
        isSelected: Bool,
        isDragging: Bool = false
    ) {
        let fillColor = segment.fillColor.opacity(isDragging ? 0.95 : 0.82)
        let borderColor: Color
        if isDragging {
            borderColor = Color.white
        } else if isSelected {
            borderColor = Color.white
        } else {
            borderColor = Color(hex: "#0F0F0F")
        }
        let borderWidth: CGFloat = (isDragging || isSelected) ? TimelineLayoutConstants.selectionBorderWidth : 1

        context.fill(Path(rect), with: .color(fillColor))
        context.stroke(Path(rect), with: .color(borderColor), lineWidth: borderWidth)

        let contentLeft = rect.minX + TimelineLayoutConstants.contentPadding
        var textLeft = contentLeft

        let avatarName = segment.parentCharacterName ?? segment.character
        let showAvatar = showThumbs && (segment.contentType == .dialogue || segment.parentCharacterName != nil)
        if showAvatar {
            let avatarRect = CGRect(
                x: contentLeft,
                y: rect.minY + TimelineLayoutConstants.contentPadding,
                width: TimelineLayoutConstants.avatarSize,
                height: TimelineLayoutConstants.avatarSize
            )

            if let cachedImage = imageCache[avatarName] {
                let resolvedImage = context.resolve(Image(nsImage: cachedImage))
                var clippedContext = context
                clippedContext.clip(to: Path(ellipseIn: avatarRect))
                clippedContext.draw(resolvedImage, in: avatarRect)

                context.stroke(
                    Path(ellipseIn: avatarRect),
                    with: .color(.white.opacity(0.6)),
                    lineWidth: 1.5
                )
            } else {
                context.fill(
                    Path(ellipseIn: avatarRect),
                    with: .color(segment.fillColor.opacity(0.6))
                )
                context.stroke(
                    Path(ellipseIn: avatarRect),
                    with: .color(.white.opacity(0.5)),
                    lineWidth: 1
                )

                let initials = initialsFrom(avatarName)
                context.draw(
                    Text(initials)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white),
                    at: CGPoint(x: avatarRect.midX, y: avatarRect.midY),
                    anchor: .center
                )
            }

            textLeft = contentLeft + TimelineLayoutConstants.avatarSize + TimelineLayoutConstants.avatarGap
        }

        let maxTextWidth = rect.width - (textLeft - rect.minX) - TimelineLayoutConstants.contentPadding
        if maxTextWidth > 20 {
            var displayText = DurationEstimator.htmlToPlainText(segment.text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")

            if displayText.count > TimelineLayoutConstants.maxTextDisplayLength {
                displayText = String(displayText.prefix(TimelineLayoutConstants.maxTextDisplayLength)) + "..."
            }

            let approximateCharWidth: CGFloat = 6.5
            let maxChars = Int(maxTextWidth / approximateCharWidth)

            if displayText.count > maxChars && maxChars > 3 {
                displayText = String(displayText.prefix(maxChars - 3)) + "..."
            }

            var clippedContext = context
            let clipRect = CGRect(
                x: textLeft,
                y: rect.minY,
                width: maxTextWidth,
                height: rect.height
            )
            clippedContext.clip(to: Path(clipRect))

            clippedContext.draw(
                Text(displayText)
                    .font(.system(size: 11))
                    .foregroundColor(segment.textFillColor),
                at: CGPoint(x: textLeft, y: rect.minY + rect.height / 2),
                anchor: .leading
            )
        }

        if segment.chronologyNumber > 0 {
            let badgeText = "#\(segment.chronologyNumber)"
            let badgeRect = CGRect(
                x: rect.minX + 2,
                y: rect.maxY - 18,
                width: 24,
                height: 16
            )
            context.fill(
                Path(roundedRect: badgeRect, cornerRadius: 2),
                with: .color(Color.black.opacity(0.5))
            )
            context.draw(
                Text(badgeText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white),
                at: CGPoint(x: badgeRect.midX, y: badgeRect.midY),
                anchor: .center
            )
        }

        // Audio indicator icon for dialogue segments
        if segment.contentType == .dialogue, let sourceId = segment.sourceItemId {
            let isGenerating = generatingAudioSourceIds.contains(sourceId)
            let isPlaying = playingAudioSourceId == sourceId
            if isGenerating || isPlaying || segment.hasAudio {
                let iconSize: CGFloat = 12
                let iconX = rect.maxX - iconSize - 3
                let iconY = rect.minY + 3
                let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)

                if isGenerating {
                    // Orange pulsing dot for generating
                    context.fill(
                        Path(ellipseIn: iconRect.insetBy(dx: 2, dy: 2)),
                        with: .color(Color.orange)
                    )
                } else if isPlaying {
                    // Green speaker icon for playing
                    context.draw(
                        Text(Image(systemName: "speaker.wave.2.fill"))
                            .font(.system(size: 10))
                            .foregroundColor(.green),
                        at: CGPoint(x: iconRect.midX, y: iconRect.midY),
                        anchor: .center
                    )
                } else {
                    // White speaker icon for has audio
                    context.draw(
                        Text(Image(systemName: "speaker.fill"))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6)),
                        at: CGPoint(x: iconRect.midX, y: iconRect.midY),
                        anchor: .center
                    )
                }
            }
        }
    }

    /// Draw the speech bubble tail (pointer)
    func drawBubbleTail(context: GraphicsContext, bubbleRect: CGRect, segment: TimelineSegment) {
        let tailPath = Path { path in
            path.move(to: CGPoint(
                x: bubbleRect.minX - TimelineLayoutConstants.tailWidth + 2,
                y: bubbleRect.midY
            ))
            path.addLine(to: CGPoint(
                x: bubbleRect.minX + 2,
                y: bubbleRect.midY - TimelineLayoutConstants.tailHeight / 2
            ))
            path.addLine(to: CGPoint(
                x: bubbleRect.minX + 2,
                y: bubbleRect.midY + TimelineLayoutConstants.tailHeight / 2
            ))
            path.closeSubpath()
        }

        context.fill(tailPath, with: .color(segment.fillColor.opacity(0.82)))
        context.stroke(tailPath, with: .color(Color(hex: "#0F0F0F")), lineWidth: 1)
    }

    /// Draw user markers (diamond shape) and note markers (Y starts at 0)
    func drawUserMarkers(context: GraphicsContext, size: CGSize) {
        let areaTop: CGFloat = 0

        for marker in markers where marker.kind == .user {
            let x = originX + marker.time * pxPerSec
            let markerColor = marker.markerColor

            let diamondPath = Path { path in
                path.move(to: CGPoint(x: x, y: areaTop))
                path.addLine(to: CGPoint(x: x - TimelineLayoutConstants.markerDiamondSize, y: areaTop + 10))
                path.addLine(to: CGPoint(x: x, y: areaTop + 20))
                path.addLine(to: CGPoint(x: x + TimelineLayoutConstants.markerDiamondSize, y: areaTop + 10))
                path.closeSubpath()
            }

            context.fill(diamondPath, with: .color(markerColor))
            context.stroke(diamondPath, with: .color(markerColor.opacity(0.5)), lineWidth: 1)

            let labelHeight: CGFloat = 16
            let labelWidth = max(30, CGFloat(marker.label.count) * 7 + 10)
            let labelRect = CGRect(
                x: x - labelWidth / 2,
                y: areaTop + 22,
                width: labelWidth,
                height: labelHeight
            )

            context.fill(
                Path(roundedRect: labelRect, cornerRadius: 2),
                with: .color(markerColor.opacity(0.3))
            )
            context.stroke(
                Path(roundedRect: labelRect, cornerRadius: 2),
                with: .color(markerColor.opacity(0.7)),
                lineWidth: 1
            )
            context.draw(
                Text(marker.label)
                    .font(.system(size: 10))
                    .foregroundColor(markerColor),
                at: CGPoint(x: x, y: areaTop + 22 + labelHeight / 2),
                anchor: .center
            )
        }

        for marker in markers where marker.kind == .note {
            let x = originX + marker.time * pxPerSec
            let markerColor = marker.markerColor

            let flagPath = Path { path in
                path.move(to: CGPoint(x: x, y: areaTop))
                path.addLine(to: CGPoint(x: x + 12, y: areaTop + 6))
                path.addLine(to: CGPoint(x: x, y: areaTop + 12))
                path.closeSubpath()
            }

            context.fill(flagPath, with: .color(markerColor))
            context.stroke(flagPath, with: .color(markerColor.opacity(0.7)), lineWidth: 1)

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: x, y: areaTop))
                    path.addLine(to: CGPoint(x: x, y: areaTop + 24))
                },
                with: .color(markerColor.opacity(0.6)),
                lineWidth: 1
            )
        }
    }

    /// Draw a vertical scroll position indicator when content overflows
    func drawScrollIndicator(context: GraphicsContext, size: CGSize) {
        guard totalHeight > size.height else { return }

        let maxOffset = totalHeight - size.height
        // Position scrollbar relative to the current horizontal viewport
        let visibleRight = viewportOffset.x + min(viewportSize.width, size.width)
        let trackX = visibleRight - 10
        let trackTop: CGFloat = 4
        let trackHeight = size.height - 8
        let thumbRatio = min(1, size.height / totalHeight)
        let thumbHeight = max(24, trackHeight * thumbRatio)
        let thumbOffset = maxOffset > 0 ? (verticalOffset / maxOffset) * (trackHeight - thumbHeight) : 0

        // Track background
        context.fill(
            Path(roundedRect: CGRect(x: trackX, y: trackTop, width: 5, height: trackHeight), cornerRadius: 2.5),
            with: .color(Color.white.opacity(0.06))
        )
        // Thumb
        context.fill(
            Path(roundedRect: CGRect(x: trackX, y: trackTop + thumbOffset, width: 5, height: thumbHeight), cornerRadius: 2.5),
            with: .color(Color.white.opacity(0.3))
        )
    }

    // MARK: - Helper Methods

    /// Get initials from character name
    func initialsFrom(_ name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return "?" }

        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }

        return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
    }
}
