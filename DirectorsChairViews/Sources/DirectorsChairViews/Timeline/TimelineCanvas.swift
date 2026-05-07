// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineCanvas.swift
//
// GPU-accelerated timeline canvas using SwiftUI Canvas API
// Renders character lane tracks (segments, lane labels, user markers).
// The time ruler, shot labels, and scope marker labels are drawn
// by TimelineHeaderCanvas, which stays pinned at the top.

import SwiftUI
import AppKit
import Foundation

/// GPU-accelerated tracks canvas with viewport culling.
/// Renders character lanes, dialogue/action/narration/sound segments,
/// lane labels, user markers, and scope-boundary vertical lines.
public struct TimelineCanvas: View {
    // MARK: - Properties

    /// All segments to potentially render
    public let segments: [TimelineSegment]

    /// User and boundary markers
    public let markers: [TimelineMarker]

    /// Scene boundaries (for vertical lines through tracks)
    public let sceneBoundaries: [TimelineBoundary]

    /// Sequence boundaries (for vertical lines through tracks)
    public let sequenceBoundaries: [TimelineBoundary]

    /// Playhead time in seconds (nil = no playhead)
    public let playheadTime: CGFloat?

    /// Pixels per second (zoom level)
    public let pxPerSec: CGFloat

    /// Whether to show character avatars/thumbnails
    public let showThumbs: Bool

    /// Current timeline mode
    public let mode: TimelineMode

    /// Project base path for loading character images
    public let projectBasePath: URL?

    /// Available viewport size (for ensuring canvas fills panel)
    public let viewportSize: CGSize

    /// Set of hidden track names (collapsed in the canvas)
    public let hiddenTracks: Set<String>

    /// Sub-lane assignment for each segment (segment UUID → sub-lane index)
    public let subLaneAssignments: [UUID: Int]

    /// Number of sub-lanes per character lane (character name → count)
    public let laneSubLaneCounts: [String: Int]

    /// Shot-dialogue connection data for drawing connection lines
    public let shotDialogueConnections: [ShotDialogueConnection]

    /// Whether to show shot-dialogue connection lines
    public let showShotConnections: Bool

    /// Currently selected shot label ID (for highlighting connection lines)
    public let selectedShotLabelId: UUID?

    /// All character names from the project (ensures every character gets a lane)
    public let allCharacterNames: [String]

    /// Vertical scroll offset for virtual track scrolling (no nested ScrollView)
    public let verticalOffset: CGFloat

    /// Available viewport height for the tracks area (used to size the Canvas)
    public let availableHeight: CGFloat

    /// Effective total duration (includes cue extents beyond last dialogue), or nil to auto-compute from segments
    public var effectiveDuration: CGFloat? = nil

    /// Currently selected segment IDs (supports multi-select with Command+click)
    @Binding public var selectedSegmentIds: Set<UUID>

    /// Current viewport offset (scroll position)
    @Binding public var viewportOffset: CGPoint

    /// Callback when a segment is selected
    public var onSegmentSelected: ((TimelineSegment) -> Void)?

    /// Callback when a segment is double-clicked
    public var onSegmentDoubleClicked: ((TimelineSegment) -> Void)?

    /// Callback when a track's eye icon is clicked (track name)
    public var onTrackToggled: ((String) -> Void)?

    /// Callback when a segment is Option+clicked (jump to script)
    public var onOptionClickSegment: ((TimelineSegment) -> Void)?

    /// Callback when a segment is dragged to a new time position (segment, newStartTime)
    public var onSegmentMoved: ((TimelineSegment, CGFloat) -> Void)?

    /// Callback when multiple segments are dragged together (segments with new start times)
    public var onSegmentsMoved: (([(TimelineSegment, CGFloat)]) -> Void)?

    /// Callback when empty space is clicked (position playhead)
    public var onEmptySpaceClicked: ((CGFloat) -> Void)?

    /// Callback when a track lane is right-clicked (character name)
    public var onTrackRightClicked: ((String, CGPoint, NSView) -> Void)?

    /// Callback when a segment is right-clicked (segment, point, nsView)
    public var onSegmentRightClicked: ((TimelineSegment, CGPoint, NSView) -> Void)?

    /// Source IDs of dialogues currently generating audio
    public var generatingAudioSourceIds: Set<String> = []

    /// Source ID of the dialogue currently playing audio
    public var playingAudioSourceId: String? = nil

    /// Cached character images for efficient rendering
    @State private var imageCache: [String: NSImage] = [:]

    /// ID of the segment currently being dragged
    @State private var draggingSegmentId: UUID?

    /// X position where drag started
    @State private var dragStartX: CGFloat = 0

    /// Current X position during drag
    @State private var dragCurrentX: CGFloat = 0

    // MARK: - Computed Properties

    /// Characters in order: first those with segments (by first appearance),
    /// then remaining project characters (so every character gets a lane).
    /// Non-character tracks (Action, Narration, Sound) only appear when they have segments.
    private var charactersInOrder: [String] {
        var seen = Set<String>()
        var order: [String] = []

        // First: characters/tracks that have segments (preserves first-appearance order)
        for segment in segments {
            if !seen.contains(segment.character) {
                seen.insert(segment.character)
                order.append(segment.character)
            }
        }

        // Then: remaining project characters that don't have segments in the current scope
        for name in allCharacterNames {
            if !seen.contains(name) {
                seen.insert(name)
                order.append(name)
            }
        }

        return order
    }

    /// Character to lane index mapping
    private var characterLanes: [String: Int] {
        Dictionary(uniqueKeysWithValues: charactersInOrder.enumerated().map { ($1, $0) })
    }

    /// Lane heights per character (collapsed for hidden tracks, expanded for sub-lanes)
    private var laneHeights: [CGFloat] {
        charactersInOrder.map { character in
            if hiddenTracks.contains(character) {
                return TimelineLayoutConstants.collapsedRowHeight
            }
            let subLaneCount = laneSubLaneCounts[character] ?? 1
            return CGFloat(subLaneCount) * TimelineLayoutConstants.subLaneHeight
        }
    }

    /// Total timeline duration in seconds
    private var totalSeconds: CGFloat {
        let segmentMax = segments.map({ $0.end }).max() ?? 0
        return max(segmentMax, effectiveDuration ?? 0)
    }

    /// Total canvas width - fills viewport or content, whichever is larger
    private var totalWidth: CGFloat {
        let contentWidth = TimelineLayoutConstants.leftMargin +
                           TimelineLayoutConstants.rowLabelWidth +
                           totalSeconds * pxPerSec + 160
        let viewportWidth = max(0, viewportSize.width - 16)
        return max(viewportWidth, max(TimelineLayoutConstants.minCanvasWidth, contentWidth))
    }

    /// Total canvas height — tracks only (no ruler, no shot lane)
    private var totalHeight: CGFloat {
        let lanesHeight = laneHeights.reduce(0, +)
        let gapsHeight = CGFloat(max(0, laneHeights.count - 1)) * TimelineLayoutConstants.rowGap
        let contentHeight = lanesHeight + gapsHeight + TimelineLayoutConstants.bottomPadding
        return max(TimelineLayoutConstants.minCanvasHeight, contentHeight)
    }

    /// Maximum height the Canvas can render without exceeding GPU texture budget.
    /// SwiftUI Canvas creates a single backing texture; on Retina displays the pixel
    /// count is 4x the point count. Keeping total points under ~10M ensures the
    /// texture fits in GPU memory (empirically ~80 MB limit on macOS).
    private var maxRenderHeight: CGFloat {
        let maxPointBudget: CGFloat = 10_000_000
        let safeHeight = maxPointBudget / max(1, totalWidth)
        return max(200, safeHeight)
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
        playheadTime: CGFloat? = nil,
        pxPerSec: CGFloat = TimelineLayoutConstants.defaultPxPerSec,
        showThumbs: Bool = true,
        mode: TimelineMode = .scene,
        projectBasePath: URL? = nil,
        viewportSize: CGSize = CGSize(width: 800, height: 300),
        hiddenTracks: Set<String> = [],
        subLaneAssignments: [UUID: Int] = [:],
        laneSubLaneCounts: [String: Int] = [:],
        shotDialogueConnections: [ShotDialogueConnection] = [],
        showShotConnections: Bool = false,
        selectedShotLabelId: UUID? = nil,
        allCharacterNames: [String] = [],
        verticalOffset: CGFloat = 0,
        availableHeight: CGFloat = 0,
        selectedSegmentIds: Binding<Set<UUID>>,
        viewportOffset: Binding<CGPoint>,
        onSegmentSelected: ((TimelineSegment) -> Void)? = nil,
        onSegmentDoubleClicked: ((TimelineSegment) -> Void)? = nil,
        onOptionClickSegment: ((TimelineSegment) -> Void)? = nil,
        onTrackToggled: ((String) -> Void)? = nil,
        onSegmentMoved: ((TimelineSegment, CGFloat) -> Void)? = nil,
        onSegmentsMoved: (([(TimelineSegment, CGFloat)]) -> Void)? = nil
    ) {
        self.segments = segments
        self.markers = markers
        self.sceneBoundaries = sceneBoundaries
        self.sequenceBoundaries = sequenceBoundaries
        self.playheadTime = playheadTime
        self.pxPerSec = pxPerSec
        self.showThumbs = showThumbs
        self.mode = mode
        self.projectBasePath = projectBasePath
        self.viewportSize = viewportSize
        self.hiddenTracks = hiddenTracks
        self.subLaneAssignments = subLaneAssignments
        self.laneSubLaneCounts = laneSubLaneCounts
        self.shotDialogueConnections = shotDialogueConnections
        self.showShotConnections = showShotConnections
        self.selectedShotLabelId = selectedShotLabelId
        self.allCharacterNames = allCharacterNames
        self.verticalOffset = verticalOffset
        self.availableHeight = availableHeight
        self._selectedSegmentIds = selectedSegmentIds
        self._viewportOffset = viewportOffset
        self.onSegmentSelected = onSegmentSelected
        self.onSegmentDoubleClicked = onSegmentDoubleClicked
        self.onOptionClickSegment = onOptionClickSegment
        self.onTrackToggled = onTrackToggled
        self.onSegmentMoved = onSegmentMoved
        self.onSegmentsMoved = onSegmentsMoved
    }

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            let viewportRect = CGRect(
                x: viewportOffset.x,
                y: viewportOffset.y,
                width: size.width,
                height: size.height
            )

            drawBackground(context: context, size: size)
            drawLaneBackgrounds(context: context, size: size)
            drawShotDialogueConnections(context: context, size: size)
            drawSegments(context: context, size: size, viewport: viewportRect)
            drawUserMarkers(context: context, size: size)
            drawLaneLabels(context: context, size: size)
            drawScopeMarkerLines(context: context, size: size)
            drawPlayheadLine(context: context, size: size)
            drawScrollIndicator(context: context, size: size)

        }
        .frame(width: totalWidth, height: min(availableHeight > 0 ? availableHeight : totalHeight, maxRenderHeight))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
            if let segment = findSegment(at: location) {
                onSegmentDoubleClicked?(segment)
            }
        }
        .onTapGesture(count: 1) { location in
            if let trackName = findLaneLabelToggle(at: location) {
                onTrackToggled?(trackName)
                return
            }

            let isOptionHeld = NSEvent.modifierFlags.contains(.option)
            if isOptionHeld, let segment = findSegment(at: location) {
                onOptionClickSegment?(segment)
                return
            }

            let isCommandHeld = NSEvent.modifierFlags.contains(.command)
            if let segment = findSegment(at: location) {
                if isCommandHeld {
                    if selectedSegmentIds.contains(segment.id) {
                        selectedSegmentIds.remove(segment.id)
                    } else {
                        selectedSegmentIds.insert(segment.id)
                    }
                } else {
                    selectedSegmentIds = [segment.id]
                }
                onSegmentSelected?(segment)
            } else {
                if !isCommandHeld {
                    selectedSegmentIds = []
                }
                // Click on empty space → position playhead
                onEmptySpaceClicked?(location.x)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if draggingSegmentId == nil {
                        if let segment = findSegment(at: value.startLocation) {
                            draggingSegmentId = segment.id
                            if !selectedSegmentIds.contains(segment.id) {
                                selectedSegmentIds = [segment.id]
                            }
                            dragStartX = value.startLocation.x
                        }
                    }
                    if draggingSegmentId != nil {
                        dragCurrentX = value.location.x
                    }
                }
                .onEnded { value in
                    if draggingSegmentId != nil {
                        let deltaX = value.location.x - dragStartX
                        let deltaTime = deltaX / pxPerSec

                        if selectedSegmentIds.count > 1 {
                            var moves: [(TimelineSegment, CGFloat)] = []
                            for selectedId in selectedSegmentIds {
                                if let segment = segments.first(where: { $0.id == selectedId }) {
                                    let newTime = max(0, segment.start + deltaTime)
                                    moves.append((segment, newTime))
                                }
                            }
                            onSegmentsMoved?(moves)
                        } else if let dragId = draggingSegmentId,
                                  let segment = segments.first(where: { $0.id == dragId }) {
                            let newTime = max(0, segment.start + deltaTime)
                            onSegmentMoved?(segment, newTime)
                        }
                    }
                    draggingSegmentId = nil
                    dragCurrentX = 0
                    dragStartX = 0
                }
        )
        .onAppear {
            loadCharacterImages()
        }
        .onChange(of: segments) { _, _ in
            loadCharacterImages()
        }
        .overlay(
            CanvasRightClickOverlay { point, nsView in
                if let segment = findSegment(at: point) {
                    onSegmentRightClicked?(segment, point, nsView)
                } else if let character = findTrackCharacter(at: point) {
                    onTrackRightClicked?(character, point, nsView)
                }
            }
        )
    }

    // MARK: - Hit Testing

    /// Find a lane label at the given point (for track toggle hit-testing, accounts for verticalOffset)
    private func findLaneLabelToggle(at point: CGPoint) -> String? {
        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let isCollapsed = hiddenTracks.contains(character)

            let labelRect = CGRect(
                x: 4,
                y: yCursor + (isCollapsed ? 2 : 4),
                width: TimelineLayoutConstants.rowLabelWidth - 12,
                height: laneHeight - (isCollapsed ? 4 : 8)
            )

            if isCollapsed {
                if labelRect.contains(point) {
                    return character
                }
            } else {
                let eyeRect = CGRect(
                    x: labelRect.minX,
                    y: labelRect.minY,
                    width: 28,
                    height: labelRect.height
                )
                if eyeRect.contains(point) {
                    return character
                }
            }

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }

        return nil
    }

    /// Find a segment at the given point (for gesture hit-testing, accounts for verticalOffset)
    private func findSegment(at point: CGPoint) -> TimelineSegment? {
        let segmentsByCharacter = Dictionary(grouping: segments) { $0.character }

        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let laneY = yCursor

            guard let characterSegments = segmentsByCharacter[character] else {
                yCursor += laneHeight + TimelineLayoutConstants.rowGap
                continue
            }

            for segment in characterSegments {
                let rx = originX + segment.start * pxPerSec
                let bubbleWidth = DurationEstimator.bubbleWidth(for: segment, pxPerSec: pxPerSec, showThumbs: showThumbs)

                let subLane = subLaneAssignments[segment.id] ?? 0
                let subLaneY = laneY + CGFloat(subLane) * TimelineLayoutConstants.subLaneHeight

                let bubbleRect = CGRect(
                    x: rx + TimelineLayoutConstants.tailWidth,
                    y: subLaneY + 6,
                    width: bubbleWidth - TimelineLayoutConstants.tailWidth,
                    height: TimelineLayoutConstants.subLaneHeight - 12
                )

                if bubbleRect.contains(point) {
                    return segment
                }
            }

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }

        return nil
    }

    /// Find which character track lane contains the given point
    private func findTrackCharacter(at point: CGPoint) -> String? {
        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let laneRect = CGRect(x: 0, y: yCursor, width: totalWidth, height: laneHeight)
            if laneRect.contains(point) {
                return character
            }
            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
        return nil
    }

    /// Load character images into cache for efficient canvas rendering
    private func loadCharacterImages() {
        guard let basePath = projectBasePath else { return }

        var newCache: [String: NSImage] = [:]

        for segment in segments {
            guard let avatarPath = segment.avatarPath,
                  !avatarPath.isEmpty else { continue }

            let cacheKey = segment.character
            if newCache[cacheKey] == nil {
                let fullPath = basePath.appendingPathComponent(avatarPath)
                if let image = NSImage(contentsOf: fullPath) {
                    newCache[cacheKey] = image
                }
            }

            if let parentName = segment.parentCharacterName, newCache[parentName] == nil {
                let fullPath = basePath.appendingPathComponent(avatarPath)
                if let image = NSImage(contentsOf: fullPath) {
                    newCache[parentName] = image
                }
            }
        }

        if newCache != imageCache {
            imageCache = newCache
        }
    }

    // MARK: - Drawing Methods

    /// Draw the background color
    private func drawBackground(context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(hex: "#262626"))
        )
    }

    /// Draw character lane backgrounds (Y offset by verticalOffset for virtual scrolling)
    private func drawLaneBackgrounds(context: GraphicsContext, size: CGSize) {
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
    private func trackTypeInfo(for trackName: String) -> (icon: String, color: Color)? {
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
    private func drawLaneLabels(context: GraphicsContext, size: CGSize) {
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
    private func drawScopeMarkerLines(context: GraphicsContext, size: CGSize) {
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
    private func drawPlayheadLine(context: GraphicsContext, size: CGSize) {
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
    private func drawShotDialogueConnections(context: GraphicsContext, size: CGSize) {
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
    private func segmentCenterY(for segment: TimelineSegment) -> CGFloat? {
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

    /// Draw segments with VIEWPORT CULLING for 60fps performance (Y offset by verticalOffset)
    private func drawSegments(context: GraphicsContext, size: CGSize, viewport: CGRect) {
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
    private func drawBubble(
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

    /// Draw user markers (diamond shape) and note markers (Y starts at 0)
    private func drawUserMarkers(context: GraphicsContext, size: CGSize) {
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
    private func drawScrollIndicator(context: GraphicsContext, size: CGSize) {
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
    private func initialsFrom(_ name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return "?" }

        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }

        return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
    }
}

// MARK: - Canvas Right-Click Overlay

/// Invisible overlay that intercepts right-mouse-down events on the canvas
private struct CanvasRightClickOverlay: NSViewRepresentable {
    var onRightClick: (CGPoint, NSView) -> Void

    func makeNSView(context: Context) -> CanvasRightClickNSView {
        let view = CanvasRightClickNSView()
        view.onRightClick = onRightClick
        view.installMonitor()
        return view
    }

    func updateNSView(_ nsView: CanvasRightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    class CanvasRightClickNSView: NSView {
        var onRightClick: ((CGPoint, NSView) -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self = self, let window = self.window, event.window === window else {
                    return event
                }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(locationInView) {
                    let flippedY = self.bounds.height - locationInView.y
                    let point = CGPoint(x: locationInView.x, y: flippedY)
                    self.onRightClick?(point, self)
                }
                return event
            }
        }

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// NSObject target for NSMenu items — holds a closure for the menu action
private class CanvasMenuHandler: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    @objc func execute() {
        action()
    }
}

// MARK: - Timeline Mode

/// Timeline view mode
public enum TimelineMode: String, Sendable {
    case scene      // Single scene view
    case sequence   // All scenes in a sequence
    case global     // All sequences and scenes
}
