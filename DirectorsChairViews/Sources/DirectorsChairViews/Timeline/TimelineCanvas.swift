// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineCanvas.swift
//
// GPU-accelerated timeline canvas using SwiftUI Canvas API
// CRITICAL: Viewport culling is mandatory for 60fps performance with 100+ bubbles

import SwiftUI
import Foundation

/// GPU-accelerated timeline canvas with viewport culling
/// Renders dialogue bubbles, character lanes, time ruler, and markers
public struct TimelineCanvas: View {
    // MARK: - Properties

    /// All segments to potentially render
    public let segments: [TimelineSegment]

    /// User and boundary markers
    public let markers: [TimelineMarker]

    /// Scene boundaries (time, name)
    public let sceneBoundaries: [TimelineBoundary]

    /// Sequence boundaries (time, name)
    public let sequenceBoundaries: [TimelineBoundary]

    /// Pixels per second (zoom level)
    public let pxPerSec: CGFloat

    /// Whether to show character avatars/thumbnails
    public let showThumbs: Bool

    /// Current timeline mode
    public let mode: TimelineMode

    /// Currently selected segment ID
    @Binding public var selectedSegmentId: UUID?

    /// Current viewport offset (scroll position)
    @Binding public var viewportOffset: CGPoint

    /// Callback when a segment is selected
    public var onSegmentSelected: ((TimelineSegment) -> Void)?

    /// Callback when a segment is double-clicked
    public var onSegmentDoubleClicked: ((TimelineSegment) -> Void)?

    // MARK: - Computed Properties

    /// Characters in order of first appearance
    private var charactersInOrder: [String] {
        var seen = Set<String>()
        var order: [String] = []
        for segment in segments {
            if !seen.contains(segment.character) {
                seen.insert(segment.character)
                order.append(segment.character)
            }
        }
        return order
    }

    /// Character to lane index mapping
    private var characterLanes: [String: Int] {
        Dictionary(uniqueKeysWithValues: charactersInOrder.enumerated().map { ($1, $0) })
    }

    /// Lane heights per character (based on content)
    private var laneHeights: [CGFloat] {
        charactersInOrder.map { _ in TimelineLayoutConstants.baseRowHeight }
    }

    /// Total timeline duration in seconds
    private var totalSeconds: CGFloat {
        guard let maxEnd = segments.map({ $0.end }).max() else { return 0 }
        return maxEnd
    }

    /// Total canvas width
    private var totalWidth: CGFloat {
        let contentWidth = TimelineLayoutConstants.leftMargin +
                           TimelineLayoutConstants.rowLabelWidth +
                           totalSeconds * pxPerSec + 160
        return max(TimelineLayoutConstants.minCanvasWidth, contentWidth)
    }

    /// Total canvas height
    private var totalHeight: CGFloat {
        let lanesHeight = laneHeights.reduce(0, +)
        let gapsHeight = CGFloat(max(0, laneHeights.count - 1)) * TimelineLayoutConstants.rowGap
        let height = TimelineLayoutConstants.topMargin +
                     TimelineLayoutConstants.rulerHeight +
                     TimelineLayoutConstants.rulerGap +
                     lanesHeight + gapsHeight +
                     TimelineLayoutConstants.bottomPadding
        return max(TimelineLayoutConstants.minCanvasHeight, height)
    }

    /// Content origin X (where timeline content starts, after labels)
    private var originX: CGFloat {
        TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
    }

    // MARK: - Init

    public init(
        segments: [TimelineSegment],
        markers: [TimelineMarker] = [],
        sceneBoundaries: [TimelineBoundary] = [],
        sequenceBoundaries: [TimelineBoundary] = [],
        pxPerSec: CGFloat = TimelineLayoutConstants.defaultPxPerSec,
        showThumbs: Bool = true,
        mode: TimelineMode = .scene,
        selectedSegmentId: Binding<UUID?>,
        viewportOffset: Binding<CGPoint>,
        onSegmentSelected: ((TimelineSegment) -> Void)? = nil,
        onSegmentDoubleClicked: ((TimelineSegment) -> Void)? = nil
    ) {
        self.segments = segments
        self.markers = markers
        self.sceneBoundaries = sceneBoundaries
        self.sequenceBoundaries = sequenceBoundaries
        self.pxPerSec = pxPerSec
        self.showThumbs = showThumbs
        self.mode = mode
        self._selectedSegmentId = selectedSegmentId
        self._viewportOffset = viewportOffset
        self.onSegmentSelected = onSegmentSelected
        self.onSegmentDoubleClicked = onSegmentDoubleClicked
    }

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            // Calculate visible viewport for culling
            let viewportRect = CGRect(
                x: viewportOffset.x,
                y: viewportOffset.y,
                width: size.width,
                height: size.height
            )

            // Draw background
            drawBackground(context: context, size: size)

            // Draw lane backgrounds
            drawLaneBackgrounds(context: context, size: size)

            // Draw scope markers (scene/sequence boundaries)
            drawScopeMarkers(context: context, size: size)

            // Draw segments with viewport culling
            drawSegments(context: context, size: size, viewport: viewportRect)

            // Draw user markers on top
            drawUserMarkers(context: context, size: size)

            // Draw time ruler (always on top, sticky)
            drawTimeRuler(context: context, size: size)

            // Draw lane labels (always on top, sticky)
            drawLaneLabels(context: context, size: size)
        }
        .frame(width: totalWidth, height: totalHeight)
    }

    // MARK: - Drawing Methods

    /// Draw the background color
    private func drawBackground(context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(hex: "#262626"))
        )
    }

    /// Draw character lane backgrounds
    private func drawLaneBackgrounds(context: GraphicsContext, size: CGSize) {
        var yCursor = TimelineLayoutConstants.topMargin +
                      TimelineLayoutConstants.rulerHeight +
                      TimelineLayoutConstants.rulerGap

        for (index, _) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let laneRect = CGRect(x: 0, y: yCursor, width: size.width, height: laneHeight)

            // Subtle alternating background
            let alpha = index % 2 == 0 ? 0.03 : 0.06
            context.fill(
                Path(laneRect),
                with: .color(Color.white.opacity(alpha))
            )

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
    }

    /// Draw time ruler at top
    private func drawTimeRuler(context: GraphicsContext, size: CGSize) {
        let rulerY = TimelineLayoutConstants.topMargin
        let baselineY = rulerY + TimelineLayoutConstants.rulerHeight - 1

        // Ruler background
        let rulerRect = CGRect(
            x: 0,
            y: rulerY - 4,
            width: size.width,
            height: TimelineLayoutConstants.rulerHeight + 8
        )
        context.fill(
            Path(rulerRect),
            with: .color(Color(hex: "#262626").opacity(0.95))
        )

        // Baseline
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: originX, y: baselineY))
                path.addLine(to: CGPoint(x: size.width - 20, y: baselineY))
            },
            with: .color(Color(hex: "#3A3A3A")),
            lineWidth: 1
        )

        // Draw ticks and labels
        let totalSecs = Int(max(totalSeconds, (size.width - originX) / pxPerSec))

        for sec in 0...totalSecs {
            let px = originX + CGFloat(sec) * pxPerSec

            // Determine tick height based on interval
            let tickHeight: CGFloat
            if sec % 60 == 0 {
                tickHeight = TimelineLayoutConstants.minuteTickHeight
            } else if sec % 10 == 0 {
                tickHeight = TimelineLayoutConstants.majorTickHeight
            } else if sec % 5 == 0 {
                tickHeight = TimelineLayoutConstants.mediumTickHeight
            } else {
                tickHeight = TimelineLayoutConstants.minorTickHeight
            }

            // Draw tick
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: px, y: baselineY))
                    path.addLine(to: CGPoint(x: px, y: baselineY - tickHeight))
                },
                with: .color(Color(hex: "#3A3A3A")),
                lineWidth: 1
            )

            // Draw label every 5 seconds
            if sec % 5 == 0 {
                let label = DurationEstimator.formatTime(CGFloat(sec))
                let textPoint = CGPoint(x: px, y: rulerY + 4)

                context.draw(
                    Text(label)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(hex: "#CCCCCC")),
                    at: textPoint,
                    anchor: .top
                )
            }
        }
    }

    /// Draw lane labels (sticky on left)
    private func drawLaneLabels(context: GraphicsContext, size: CGSize) {
        var yCursor = TimelineLayoutConstants.topMargin +
                      TimelineLayoutConstants.rulerHeight +
                      TimelineLayoutConstants.rulerGap

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]

            // Label background
            let labelRect = CGRect(
                x: 4,
                y: yCursor + 4,
                width: TimelineLayoutConstants.rowLabelWidth - 12,
                height: laneHeight - 8
            )
            context.fill(
                Path(roundedRect: labelRect, cornerRadius: 4),
                with: .color(Color(hex: "#444444").opacity(0.95))
            )
            context.stroke(
                Path(roundedRect: labelRect, cornerRadius: 4),
                with: .color(Color(hex: "#666666")),
                lineWidth: 1
            )

            // Label text
            let textPoint = CGPoint(
                x: labelRect.maxX - 8,
                y: yCursor + laneHeight / 2
            )
            context.draw(
                Text(character)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#AAAAAA")),
                at: textPoint,
                anchor: .trailing
            )

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
    }

    /// Draw scope markers (scene/sequence boundaries)
    private func drawScopeMarkers(context: GraphicsContext, size: CGSize) {
        let markerTop = TimelineLayoutConstants.topMargin +
                        TimelineLayoutConstants.rulerHeight +
                        TimelineLayoutConstants.rulerGap - 6
        let markerBottom = size.height - TimelineLayoutConstants.bottomPadding + 8

        // Scene boundaries
        if mode == .sequence || mode == .global {
            for boundary in sceneBoundaries {
                let x = originX + boundary.time * pxPerSec
                drawVerticalMarker(
                    context: context,
                    x: x,
                    top: markerTop,
                    bottom: markerBottom,
                    label: boundary.name,
                    color: TimelineDefaultColors.sceneBoundary,
                    thick: false,
                    stackLevel: mode == .global ? 1 : 0
                )
            }
        }

        // Sequence boundaries (only in global mode)
        if mode == .global {
            for boundary in sequenceBoundaries {
                let x = originX + boundary.time * pxPerSec
                drawVerticalMarker(
                    context: context,
                    x: x,
                    top: markerTop,
                    bottom: markerBottom,
                    label: boundary.name,
                    color: TimelineDefaultColors.sequenceBoundary,
                    thick: true,
                    stackLevel: 0
                )
            }
        }
    }

    /// Draw a vertical boundary marker line
    private func drawVerticalMarker(
        context: GraphicsContext,
        x: CGFloat,
        top: CGFloat,
        bottom: CGFloat,
        label: String,
        color: String,
        thick: Bool,
        stackLevel: Int
    ) {
        let markerColor = Color(hex: color)

        // Draw vertical line
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x, y: bottom))
            },
            with: .color(markerColor),
            lineWidth: thick ? 2.2 : 1.4
        )

        // Draw label box
        let labelHeight: CGFloat = 18
        let labelWidth = max(40, CGFloat(label.count) * 7 + 12)
        let yOffset = top - labelHeight - 8 - CGFloat(stackLevel) * (labelHeight + 4)

        let labelRect = CGRect(
            x: x - labelWidth / 2,
            y: yOffset,
            width: labelWidth,
            height: labelHeight
        )

        context.fill(
            Path(roundedRect: labelRect, cornerRadius: 2),
            with: .color(Color(hex: "#1A1A1A"))
        )
        context.stroke(
            Path(roundedRect: labelRect, cornerRadius: 2),
            with: .color(markerColor),
            lineWidth: 1
        )

        context.draw(
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(markerColor),
            at: CGPoint(x: x, y: yOffset + labelHeight / 2),
            anchor: .center
        )
    }

    /// Draw segments with VIEWPORT CULLING for 60fps performance
    private func drawSegments(context: GraphicsContext, size: CGSize, viewport: CGRect) {
        // Group segments by character for efficient rendering
        let segmentsByCharacter = Dictionary(grouping: segments) { $0.character }

        var yCursor = TimelineLayoutConstants.topMargin +
                      TimelineLayoutConstants.rulerHeight +
                      TimelineLayoutConstants.rulerGap

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let laneY = yCursor

            guard let characterSegments = segmentsByCharacter[character] else {
                yCursor += laneHeight + TimelineLayoutConstants.rowGap
                continue
            }

            for segment in characterSegments {
                let rx = originX + segment.start * pxPerSec
                let bubbleWidth = max(TimelineLayoutConstants.minBubbleWidth, segment.duration * pxPerSec)

                // VIEWPORT CULLING: Skip segments outside visible area
                // Add buffer for smooth scrolling
                let visibleStart = viewport.minX - TimelineLayoutConstants.viewportBuffer * pxPerSec
                let visibleEnd = viewport.maxX + TimelineLayoutConstants.viewportBuffer * pxPerSec

                if rx + bubbleWidth < visibleStart || rx > visibleEnd {
                    continue  // Skip - not visible
                }

                // Draw the bubble
                let bubbleRect = CGRect(
                    x: rx + TimelineLayoutConstants.tailWidth,
                    y: laneY + 6,
                    width: bubbleWidth - TimelineLayoutConstants.tailWidth,
                    height: laneHeight - 12
                )

                drawBubble(
                    context: context,
                    rect: bubbleRect,
                    segment: segment,
                    isSelected: segment.id == selectedSegmentId
                )

                // Draw tail
                drawBubbleTail(context: context, bubbleRect: bubbleRect, segment: segment)
            }

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
    }

    /// Draw a speech bubble
    private func drawBubble(
        context: GraphicsContext,
        rect: CGRect,
        segment: TimelineSegment,
        isSelected: Bool
    ) {
        let fillColor = segment.fillColor.opacity(0.82)
        let borderColor = isSelected ? Color.white : Color(hex: "#0F0F0F")

        // Fill
        context.fill(
            Path(rect),
            with: .color(fillColor)
        )

        // Border
        context.stroke(
            Path(rect),
            with: .color(borderColor),
            lineWidth: isSelected ? TimelineLayoutConstants.selectionBorderWidth : 1
        )

        // Content
        let contentLeft = rect.minX + TimelineLayoutConstants.contentPadding
        var textLeft = contentLeft
        let contentWidth = rect.width - 2 * TimelineLayoutConstants.contentPadding

        // Avatar (if enabled)
        if showThumbs {
            let avatarRect = CGRect(
                x: contentLeft,
                y: rect.minY + TimelineLayoutConstants.contentPadding,
                width: TimelineLayoutConstants.avatarSize,
                height: TimelineLayoutConstants.avatarSize
            )

            // Draw avatar circle placeholder
            context.fill(
                Path(ellipseIn: avatarRect),
                with: .color(segment.fillColor.opacity(0.6))
            )
            context.stroke(
                Path(ellipseIn: avatarRect),
                with: .color(.white.opacity(0.5)),
                lineWidth: 1
            )

            // Draw initials
            let initials = initialsFrom(segment.character)
            context.draw(
                Text(initials)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white),
                at: CGPoint(x: avatarRect.midX, y: avatarRect.midY),
                anchor: .center
            )

            textLeft = contentLeft + TimelineLayoutConstants.avatarSize + TimelineLayoutConstants.avatarGap
        }

        // Text (truncated for performance)
        let maxTextWidth = rect.width - (textLeft - rect.minX) - TimelineLayoutConstants.contentPadding
        if maxTextWidth > 20 {
            var displayText = DurationEstimator.htmlToPlainText(segment.text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")

            if displayText.count > TimelineLayoutConstants.maxTextDisplayLength {
                displayText = String(displayText.prefix(TimelineLayoutConstants.maxTextDisplayLength)) + "..."
            }

            context.draw(
                Text(displayText)
                    .font(.system(size: 11))
                    .foregroundColor(segment.textFillColor),
                at: CGPoint(x: textLeft, y: rect.minY + rect.height / 2),
                anchor: .leading
            )
        }

        // Chronology number badge
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
    }

    /// Draw the speech bubble tail (pointer)
    private func drawBubbleTail(context: GraphicsContext, bubbleRect: CGRect, segment: TimelineSegment) {
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

    /// Draw user markers (diamond shape)
    private func drawUserMarkers(context: GraphicsContext, size: CGSize) {
        let areaTop = TimelineLayoutConstants.topMargin +
                      TimelineLayoutConstants.rulerHeight +
                      TimelineLayoutConstants.rulerGap

        for marker in markers where marker.kind == .user {
            let x = originX + marker.time * pxPerSec
            let markerColor = marker.markerColor

            // Diamond shape
            let diamondPath = Path { path in
                path.move(to: CGPoint(x: x, y: areaTop))
                path.addLine(to: CGPoint(x: x - TimelineLayoutConstants.markerDiamondSize, y: areaTop + 10))
                path.addLine(to: CGPoint(x: x, y: areaTop + 20))
                path.addLine(to: CGPoint(x: x + TimelineLayoutConstants.markerDiamondSize, y: areaTop + 10))
                path.closeSubpath()
            }

            context.fill(diamondPath, with: .color(markerColor))
            context.stroke(diamondPath, with: .color(markerColor.opacity(0.5)), lineWidth: 1)

            // Label
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
    }

    // MARK: - Helper Methods

    /// Get initials from character name
    private func initialsFrom(_ name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return "?" }

        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }

        return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
    }
}

// MARK: - Timeline Mode

/// Timeline view mode
public enum TimelineMode: String, Sendable {
    case scene      // Single scene view
    case sequence   // All scenes in a sequence
    case global     // All sequences and scenes
}
