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
    @State var imageCache: [String: NSImage] = [:]

    /// ID of the segment currently being dragged
    @State var draggingSegmentId: UUID?

    /// X position where drag started
    @State var dragStartX: CGFloat = 0

    /// Current X position during drag
    @State var dragCurrentX: CGFloat = 0

    // MARK: - Computed Properties

    /// Characters in order: first those with segments (by first appearance),
    /// then remaining project characters (so every character gets a lane).
    /// Non-character tracks (Action, Narration, Sound) only appear when they have segments.
    var charactersInOrder: [String] {
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
    var characterLanes: [String: Int] {
        Dictionary(uniqueKeysWithValues: charactersInOrder.enumerated().map { ($1, $0) })
    }

    /// Lane heights per character (collapsed for hidden tracks, expanded for sub-lanes)
    var laneHeights: [CGFloat] {
        charactersInOrder.map { character in
            if hiddenTracks.contains(character) {
                return TimelineLayoutConstants.collapsedRowHeight
            }
            let subLaneCount = laneSubLaneCounts[character] ?? 1
            return CGFloat(subLaneCount) * TimelineLayoutConstants.subLaneHeight
        }
    }

    /// Total timeline duration in seconds
    var totalSeconds: CGFloat {
        let segmentMax = segments.map({ $0.end }).max() ?? 0
        return max(segmentMax, effectiveDuration ?? 0)
    }

    /// Total canvas width - fills viewport or content, whichever is larger
    var totalWidth: CGFloat {
        let contentWidth = TimelineLayoutConstants.leftMargin +
                           TimelineLayoutConstants.rowLabelWidth +
                           totalSeconds * pxPerSec + 160
        let viewportWidth = max(0, viewportSize.width - 16)
        return max(viewportWidth, max(TimelineLayoutConstants.minCanvasWidth, contentWidth))
    }

    /// Total canvas height — tracks only (no ruler, no shot lane)
    var totalHeight: CGFloat {
        let lanesHeight = laneHeights.reduce(0, +)
        let gapsHeight = CGFloat(max(0, laneHeights.count - 1)) * TimelineLayoutConstants.rowGap
        let contentHeight = lanesHeight + gapsHeight + TimelineLayoutConstants.bottomPadding
        return max(TimelineLayoutConstants.minCanvasHeight, contentHeight)
    }

    /// Maximum height the Canvas can render without exceeding GPU texture budget.
    /// SwiftUI Canvas creates a single backing texture; on Retina displays the pixel
    /// count is 4x the point count. Keeping total points under ~10M ensures the
    /// texture fits in GPU memory (empirically ~80 MB limit on macOS).
    var maxRenderHeight: CGFloat {
        let maxPointBudget: CGFloat = 10_000_000
        let safeHeight = maxPointBudget / max(1, totalWidth)
        return max(200, safeHeight)
    }

    /// Content origin X (where timeline content starts, after labels)
    var originX: CGFloat {
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
        // WS9.6 — expose the drawn timeline to VoiceOver: a summary on the
        // canvas plus one child element per segment (its speaker and text).
        .accessibilityLabel("Timeline content")
        .accessibilityValue("\(segments.count) segments")
        .accessibilityChildren {
            ForEach(segments) { segment in
                Text("\(segment.character): \(segment.text)")
            }
        }
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
}
