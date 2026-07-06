// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineHeaderCanvas.swift
//
// Fixed header canvas for the timeline — renders time ruler, shot labels lane,
// and scope marker labels. Stays pinned at top during vertical scrolling.

import SwiftUI
import AppKit
import DirectorsChairCore

/// Fixed header canvas that renders the time ruler, shot labels lane, and scope marker labels.
/// This stays pinned at the top while character-lane tracks scroll vertically underneath.
public struct TimelineHeaderCanvas: View {
    // MARK: - Properties

    /// All segments (used only for computing totalWidth / totalSeconds)
    public let segments: [TimelineSegment]

    /// Scene boundaries (time, name)
    public let sceneBoundaries: [TimelineBoundary]

    /// Sequence boundaries (time, name)
    public let sequenceBoundaries: [TimelineBoundary]

    /// Shot labels for the shot lane
    public let shotLabels: [TimelineShotLabel]

    /// Whether to show shot labels lane
    public let showShotLabels: Bool

    /// Pixels per second (zoom level)
    public let pxPerSec: CGFloat

    /// Current timeline mode
    public let mode: TimelineMode

    /// Available viewport size
    public let viewportSize: CGSize

    /// Sub-lane assignment for each shot label
    public let shotSubLaneAssignments: [UUID: Int]

    /// Number of sub-lanes in the shots lane
    public let shotLaneSubLaneCount: Int

    /// Shot-dialogue connections (for drawing indicators on linked shot cards)
    public let shotDialogueConnections: [ShotDialogueConnection]

    /// Whether to show shot-dialogue connection lines
    public let showShotConnections: Bool

    /// Playhead time in seconds (nil = no playhead)
    public let playheadTime: CGFloat?

    /// Whether the playhead is active (following cursor)
    public let playheadActive: Bool

    /// User-created markers
    public let userMarkers: [TimelineMarker]

    /// Project base path for resolving preview image paths
    public let projectBasePath: URL?

    /// Soundtrack tracks with waveform data
    public let soundtrackTracks: [SoundtrackTrack]

    /// Whether to show soundtrack waveform lanes
    public let showSoundtracks: Bool

    /// Light cues for the lighting lane
    public let lightCues: [LightCue]

    /// Whether to show the lighting cue lane
    public let showLightingLane: Bool

    /// SFX cues for the SFX lane
    public let sfxCues: [SFXCue]

    /// Whether to show the SFX cue lane
    public let showSFXLane: Bool

    /// Callback when a light cue is added (time)
    public var onLightCueAdded: ((CGFloat, String, String, LightingWorkflow, LightFixtureType, Double, Double, String) -> Void)?

    /// Callback when a light cue is deleted (cueId)
    public var onLightCueDeleted: ((String) -> Void)?

    /// Callback when a light cue is updated
    public var onLightCueUpdated: ((LightCue) -> Void)?

    /// Callback when a light cue is moved to a new time (cueId, newStartTime)
    public var onLightCueMoved: ((String, Double) -> Void)?

    /// Callback when a light cue is resized (cueId, newDuration)
    public var onLightCueResized: ((String, Double) -> Void)?

    /// Callback when a light cue is double-clicked (cueId) — opens full editor
    public var onLightCueDoubleClicked: ((String) -> Void)?

    /// Callback when the lighting lane visibility is toggled
    public var onLightingLaneToggled: (() -> Void)?

    /// Callback when an SFX cue is added
    public var onSFXCueAdded: ((CGFloat, String, String, SFXEffectType, Double, Double, String) -> Void)?

    /// Callback when an SFX cue is deleted
    public var onSFXCueDeleted: ((String) -> Void)?

    /// Callback when an SFX cue is updated
    public var onSFXCueUpdated: ((SFXCue) -> Void)?

    /// Callback when an SFX cue is moved (cueId, newStartTime)
    public var onSFXCueMoved: ((String, Double) -> Void)?

    /// Callback when an SFX cue is resized (cueId, newDuration)
    public var onSFXCueResized: ((String, Double) -> Void)?

    /// Callback when an SFX cue is double-clicked (cueId)
    public var onSFXCueDoubleClicked: ((String) -> Void)?

    /// Callback when the SFX lane visibility is toggled
    public var onSFXLaneToggled: (() -> Void)?

    /// Support cues for the support lane
    public let supportCues: [SupportCue]

    /// Whether to show the support cue lane
    public let showSupportLane: Bool

    /// Callback when a support cue is added
    public var onSupportCueAdded: ((CGFloat, String, String, SupportActionType, Double, String) -> Void)?

    /// Callback when a support cue is deleted
    public var onSupportCueDeleted: ((String) -> Void)?

    /// Callback when a support cue is updated
    public var onSupportCueUpdated: ((SupportCue) -> Void)?

    /// Callback when a support cue is moved (cueId, newStartTime)
    public var onSupportCueMoved: ((String, Double) -> Void)?

    /// Callback when a support cue is resized (cueId, newDuration)
    public var onSupportCueResized: ((String, Double) -> Void)?

    /// Callback when a support cue is double-clicked (cueId)
    public var onSupportCueDoubleClicked: ((String) -> Void)?

    /// Callback when the support lane visibility is toggled
    public var onSupportLaneToggled: (() -> Void)?

    /// Callback when a soundtrack track is moved (trackId, newOffset)
    public var onSoundtrackMoved: ((String, Double) -> Void)?

    /// Callback when soundtrack visibility is toggled
    public var onSoundtrackTrackToggled: (() -> Void)?

    /// Callback when a soundtrack track mute is toggled (trackId)
    public var onSoundtrackMuteToggled: ((String) -> Void)?

    /// Callback when a soundtrack track is removed (trackId)
    public var onSoundtrackRemoved: ((String) -> Void)?

    /// Callback when a shot label is double-clicked (shotId, sceneName)
    public var onShotLabelDoubleClicked: ((Int, String) -> Void)?

    /// Callback when a shot label is dragged to a new time position
    public var onShotLabelMoved: ((Int, String, CGFloat) -> Void)?

    /// Callback when a shot label is single-clicked (selected)
    public var onShotLabelSelected: ((UUID) -> Void)?

    /// Callback when a shot label is Option+clicked (jump to script) — (shotId, sceneName)
    public var onOptionClickShotLabel: ((Int, String) -> Void)?

    /// Callback when shot track eye toggle is clicked
    public var onShotTrackToggled: (() -> Void)?

    /// Callback when a shot label is resized to a new duration (shotId, sceneName, newDuration)
    public var onShotLabelResized: ((Int, String, CGFloat) -> Void)?

    /// Callback when a scene boundary marker is double-clicked (sceneName)
    public var onSceneMarkerDoubleClicked: ((String) -> Void)?

    /// Callback when a scene boundary marker is moved (sceneName, newTime)
    public var onSceneBoundaryMoved: ((String, CGFloat) -> Void)?

    /// Callback when a sequence boundary marker is moved (sequenceName, newTime)
    public var onSequenceBoundaryMoved: ((String, CGFloat) -> Void)?

    /// Callback when the ruler is clicked to set the playhead
    public var onRulerClicked: ((CGFloat) -> Void)?

    /// Callback when the playhead is dragged to a new X position
    public var onPlayheadDragged: ((CGFloat) -> Void)?

    /// Callback when a user marker is deleted (marker ID)
    public var onMarkerDeleted: ((UUID) -> Void)?

    /// Callback when a user marker is updated (id, label, icon, color)
    public var onMarkerUpdated: ((UUID, String, String, String) -> Void)?

    /// Callback when a new marker is added (time, label, icon, color)
    public var onMarkerAdded: ((CGFloat, String, String, String) -> Void)?

    /// ID of the shot currently being dragged
    @State var draggingShotId: UUID?

    /// X position where drag started
    @State var dragStartX: CGFloat = 0

    /// Current X position during drag
    @State var dragCurrentX: CGFloat = 0

    /// ID of the shot currently being resized (right-edge drag)
    @State var resizingShotId: UUID?

    /// X position where resize drag started
    @State var resizeStartX: CGFloat = 0

    /// Original duration (seconds) when resize started
    @State var resizeStartDuration: CGFloat = 0

    /// Shot label targeted by the right-click context menu
    @State var contextMenuShot: TimelineShotLabel?

    /// Whether the duration popover is showing
    @State var showDurationPopover: Bool = false

    /// Text field input for duration (seconds)
    @State var durationInputText: String = ""

    /// ID of the boundary marker currently being dragged
    @State var draggingBoundaryId: UUID?

    /// Whether the dragged boundary is a sequence boundary (true) or scene boundary (false)
    @State var draggingBoundaryIsSequence: Bool = false

    /// X position where boundary drag started
    @State var dragBoundaryStartX: CGFloat = 0

    /// Whether the playhead handle is being dragged
    @State var isDraggingPlayhead: Bool = false

    /// Marker targeted by right-click context menu
    @State var contextMenuMarker: TimelineMarker?

    /// Whether the marker edit popover is showing
    @State var showMarkerEditPopover: Bool = false

    /// Marker edit fields
    @State var markerEditLabel: String = ""
    @State var markerEditIcon: String = "flag.fill"
    @State var markerEditColor: String = "#FF5F5F"

    /// Time position for adding a new marker (nil = editing existing)
    @State var addMarkerTime: CGFloat? = nil

    /// Anchor point for marker popover (local view coordinates of the right-click)
    @State var markerPopoverAnchor: CGPoint = .zero

    /// ID of soundtrack track being dragged
    @State var draggingSoundtrackId: String?

    /// X position where soundtrack drag started
    @State var soundtrackDragStartX: CGFloat = 0

    /// Whether the Command key is currently held down (for showing shot previews)
    @State var isCommandKeyDown: Bool = false

    /// Async preview-image cache (keyed by relative path). Draw-path lookups
    /// never touch disk: a miss schedules a background load, and
    /// `previewCacheVersion` bumps to trigger a redraw when it lands (WS9.2).
    @State var previewImageCache = CanvasImageCache()

    /// Incremented when a background image load completes, to invalidate Canvas.
    @State var previewCacheVersion: Int = 0

    /// Light cue targeted by context menu
    @State var contextMenuLightCue: LightCue?

    /// Whether the light cue config popover is showing
    @State var showLightCuePopover: Bool = false

    /// Light cue edit fields
    @State var lightCueEditName: String = "New Light Cue"
    @State var lightCueEditNumber: String = "Q1"
    @State var lightCueEditWorkflow: LightingWorkflow = .cinema
    @State var lightCueEditFixture: LightFixtureType = .keyLight
    @State var lightCueEditIntensity: Double = 1.0
    @State var lightCueEditDuration: Double = 5.0
    @State var lightCueEditColor: String = "#FFD60A"

    /// Time position for adding a new light cue (nil = editing existing)
    @State var addLightCueTime: CGFloat? = nil

    /// Anchor point for light cue popover
    @State var lightCuePopoverAnchor: CGPoint = .zero

    /// ID of the light cue currently being dragged
    @State var draggingLightCueId: String?

    /// X position where light cue drag started
    @State var lightCueDragStartX: CGFloat = 0

    /// ID of the light cue currently being resized
    @State var resizingLightCueId: String?

    /// X position where light cue resize started
    @State var lightCueResizeStartX: CGFloat = 0

    /// Original duration when light cue resize started
    @State var lightCueResizeStartDuration: CGFloat = 0

    // SFX cue interaction state
    @State var contextMenuSFXCue: SFXCue?
    @State var showSFXCuePopover: Bool = false
    @State var sfxCueEditName: String = "New SFX Cue"
    @State var sfxCueEditNumber: String = "FX1"
    @State var sfxCueEditEffectType: SFXEffectType = .smoke
    @State var sfxCueEditIntensity: Double = 0.8
    @State var sfxCueEditDuration: Double = 5.0
    @State var sfxCueEditColor: String = "#FF6B35"
    @State var addSFXCueTime: CGFloat? = nil
    @State var sfxCuePopoverAnchor: CGPoint = .zero
    @State var draggingSFXCueId: String?
    @State var sfxCueDragStartX: CGFloat = 0
    @State var resizingSFXCueId: String?
    @State var sfxCueResizeStartX: CGFloat = 0
    @State var sfxCueResizeStartDuration: CGFloat = 0

    // Support cue interaction state
    @State var contextMenuSupportCue: SupportCue?
    @State var showSupportCuePopover: Bool = false
    @State var supportCueEditName: String = "New Support Cue"
    @State var supportCueEditNumber: String = "S1"
    @State var supportCueEditActionType: SupportActionType = .propMove
    @State var supportCueEditPriority: SupportPriority = .medium
    @State var supportCueEditAssignedTo: String = ""
    @State var supportCueEditDuration: Double = 5.0
    @State var supportCueEditColor: String = "#2DD4BF"
    @State var addSupportCueTime: CGFloat? = nil
    @State var supportCuePopoverAnchor: CGPoint = .zero
    @State var draggingSupportCueId: String?
    @State var supportCueDragStartX: CGFloat = 0
    @State var resizingSupportCueId: String?
    @State var supportCueResizeStartX: CGFloat = 0
    @State var supportCueResizeStartDuration: CGFloat = 0

    // MARK: - Computed Properties

    /// Total timeline duration in seconds (includes cue extents beyond last dialogue)
    var totalSeconds: CGFloat {
        let segmentMax = segments.map({ $0.end }).max() ?? 0
        let lightMax = lightCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let sfxMax = sfxCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let supportMax = supportCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let soundtrackMax = soundtrackTracks.map { CGFloat($0.startTimeOffset + $0.duration) }.max() ?? 0
        return max(segmentMax, lightMax, sfxMax, supportMax, soundtrackMax)
    }

    /// Total canvas width
    var totalWidth: CGFloat {
        let contentWidth = TimelineLayoutConstants.leftMargin +
                           TimelineLayoutConstants.rowLabelWidth +
                           totalSeconds * pxPerSec + 160
        let viewportWidth = max(0, viewportSize.width - 16)
        return max(viewportWidth, max(TimelineLayoutConstants.minCanvasWidth, contentWidth))
    }

    /// Height of the shot labels lane (dynamic based on sub-lane count)
    var shotLaneOffset: CGFloat {
        if showShotLabels {
            return CGFloat(shotLaneSubLaneCount) * TimelineLayoutConstants.shotLaneHeight
        } else {
            return 24 // Collapsed strip
        }
    }

    /// Height of the soundtrack waveform area
    var soundtrackLaneHeight: CGFloat {
        guard showSoundtracks, !soundtrackTracks.isEmpty else { return 0 }
        return CGFloat(soundtrackTracks.count) * TimelineLayoutConstants.soundtrackLaneHeight
    }

    // Cached sub-lane layouts (recomputed via .onChange instead of on every access)
    @State var cachedLightSubLanes: [String: Int] = [:]
    @State var cachedSFXSubLanes: [String: Int] = [:]
    @State var cachedSupportSubLanes: [String: Int] = [:]

    var lightCueSubLanes: [String: Int] { cachedLightSubLanes }
    var sfxCueSubLanes: [String: Int] { cachedSFXSubLanes }
    var supportCueSubLanes: [String: Int] { cachedSupportSubLanes }

    /// Number of sub-lanes needed for light cues
    var lightCueSubLaneCount: Int {
        guard showLightingLane, !lightCues.isEmpty else { return 0 }
        return (cachedLightSubLanes.values.max() ?? 0) + 1
    }

    /// Height of the lighting cue lane (dynamic based on sub-lane count, or collapsed strip)
    var lightingLaneOffset: CGFloat {
        guard !lightCues.isEmpty else { return 0 }
        if showLightingLane {
            return CGFloat(lightCueSubLaneCount) * TimelineLayoutConstants.lightingLaneHeight
        } else {
            return 24 // Collapsed strip height
        }
    }

    /// Number of sub-lanes needed for SFX cues
    var sfxCueSubLaneCount: Int {
        guard showSFXLane, !sfxCues.isEmpty else { return 0 }
        return (cachedSFXSubLanes.values.max() ?? 0) + 1
    }

    /// Height of the SFX cue lane (dynamic based on sub-lane count, or collapsed strip)
    var sfxLaneOffset: CGFloat {
        guard !sfxCues.isEmpty else { return 0 }
        if showSFXLane {
            return CGFloat(sfxCueSubLaneCount) * TimelineLayoutConstants.sfxLaneHeight
        } else {
            return 24
        }
    }

    /// Number of sub-lanes needed for support cues
    var supportCueSubLaneCount: Int {
        guard showSupportLane, !supportCues.isEmpty else { return 0 }
        return (cachedSupportSubLanes.values.max() ?? 0) + 1
    }

    /// Height of the support cue lane (dynamic based on sub-lane count, or collapsed strip)
    var supportLaneOffset: CGFloat {
        guard !supportCues.isEmpty else { return 0 }
        if showSupportLane {
            return CGFloat(supportCueSubLaneCount) * TimelineLayoutConstants.supportLaneHeight
        } else {
            return 24
        }
    }

    /// Recompute all cached sub-lane dictionaries
    func recomputeCachedSubLanes() {
        cachedLightSubLanes = Self.computeSubLanes(ids: lightCues.map(\.id), starts: lightCues.map(\.startTime), durations: lightCues.map(\.duration))
        cachedSFXSubLanes = Self.computeSubLanes(ids: sfxCues.map(\.id), starts: sfxCues.map(\.startTime), durations: sfxCues.map(\.duration))
        cachedSupportSubLanes = Self.computeSubLanes(ids: supportCues.map(\.id), starts: supportCues.map(\.startTime), durations: supportCues.map(\.duration))
    }

    /// Compute sub-lane assignments using greedy interval partitioning
    static func computeSubLanes(ids: [String], starts: [Double], durations: [Double]) -> [String: Int] {
        guard !ids.isEmpty else { return [:] }
        let indices = ids.indices.sorted { starts[$0] < starts[$1] }
        var assignments: [String: Int] = [:]
        var subLaneEnds: [Double] = []

        for i in indices {
            let start = starts[i]
            var placed = false
            for lane in 0..<subLaneEnds.count {
                if start >= subLaneEnds[lane] {
                    assignments[ids[i]] = lane
                    subLaneEnds[lane] = start + durations[i]
                    placed = true
                    break
                }
            }
            if !placed {
                assignments[ids[i]] = subLaneEnds.count
                subLaneEnds.append(start + durations[i])
            }
        }
        return assignments
    }

    /// Height of this header canvas
    public var headerHeight: CGFloat {
        TimelineLayoutConstants.topMargin +
        TimelineLayoutConstants.rulerHeight +
        TimelineLayoutConstants.rulerGap +
        shotLaneOffset +
        soundtrackLaneHeight +
        lightingLaneOffset +
        sfxLaneOffset +
        supportLaneOffset
    }

    /// Content origin X (where timeline content starts, after labels)
    var originX: CGFloat {
        TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
    }

    // MARK: - Init

    public init(
        segments: [TimelineSegment],
        sceneBoundaries: [TimelineBoundary] = [],
        sequenceBoundaries: [TimelineBoundary] = [],
        shotLabels: [TimelineShotLabel] = [],
        showShotLabels: Bool = false,
        pxPerSec: CGFloat = TimelineLayoutConstants.defaultPxPerSec,
        mode: TimelineMode = .scene,
        viewportSize: CGSize = CGSize(width: 800, height: 300),
        shotSubLaneAssignments: [UUID: Int] = [:],
        shotLaneSubLaneCount: Int = 1,
        shotDialogueConnections: [ShotDialogueConnection] = [],
        showShotConnections: Bool = false,
        playheadTime: CGFloat? = nil,
        playheadActive: Bool = false,
        userMarkers: [TimelineMarker] = [],
        projectBasePath: URL? = nil,
        soundtrackTracks: [SoundtrackTrack] = [],
        showSoundtracks: Bool = true,
        lightCues: [LightCue] = [],
        showLightingLane: Bool = true,
        sfxCues: [SFXCue] = [],
        showSFXLane: Bool = true,
        supportCues: [SupportCue] = [],
        showSupportLane: Bool = true,
        onLightCueAdded: ((CGFloat, String, String, LightingWorkflow, LightFixtureType, Double, Double, String) -> Void)? = nil,
        onLightCueDeleted: ((String) -> Void)? = nil,
        onLightCueUpdated: ((LightCue) -> Void)? = nil,
        onLightCueMoved: ((String, Double) -> Void)? = nil,
        onLightCueResized: ((String, Double) -> Void)? = nil,
        onLightCueDoubleClicked: ((String) -> Void)? = nil,
        onLightingLaneToggled: (() -> Void)? = nil,
        onSFXCueAdded: ((CGFloat, String, String, SFXEffectType, Double, Double, String) -> Void)? = nil,
        onSFXCueDeleted: ((String) -> Void)? = nil,
        onSFXCueUpdated: ((SFXCue) -> Void)? = nil,
        onSFXCueMoved: ((String, Double) -> Void)? = nil,
        onSFXCueResized: ((String, Double) -> Void)? = nil,
        onSFXCueDoubleClicked: ((String) -> Void)? = nil,
        onSFXLaneToggled: (() -> Void)? = nil,
        onSupportCueAdded: ((CGFloat, String, String, SupportActionType, Double, String) -> Void)? = nil,
        onSupportCueDeleted: ((String) -> Void)? = nil,
        onSupportCueUpdated: ((SupportCue) -> Void)? = nil,
        onSupportCueMoved: ((String, Double) -> Void)? = nil,
        onSupportCueResized: ((String, Double) -> Void)? = nil,
        onSupportCueDoubleClicked: ((String) -> Void)? = nil,
        onSupportLaneToggled: (() -> Void)? = nil,
        onSoundtrackMoved: ((String, Double) -> Void)? = nil,
        onSoundtrackTrackToggled: (() -> Void)? = nil,
        onSoundtrackMuteToggled: ((String) -> Void)? = nil,
        onSoundtrackRemoved: ((String) -> Void)? = nil,
        onShotLabelDoubleClicked: ((Int, String) -> Void)? = nil,
        onSceneMarkerDoubleClicked: ((String) -> Void)? = nil,
        onShotLabelMoved: ((Int, String, CGFloat) -> Void)? = nil,
        onShotLabelSelected: ((UUID) -> Void)? = nil,
        onOptionClickShotLabel: ((Int, String) -> Void)? = nil,
        onShotTrackToggled: (() -> Void)? = nil,
        onShotLabelResized: ((Int, String, CGFloat) -> Void)? = nil,
        onSceneBoundaryMoved: ((String, CGFloat) -> Void)? = nil,
        onSequenceBoundaryMoved: ((String, CGFloat) -> Void)? = nil,
        onRulerClicked: ((CGFloat) -> Void)? = nil,
        onPlayheadDragged: ((CGFloat) -> Void)? = nil,
        onMarkerDeleted: ((UUID) -> Void)? = nil,
        onMarkerUpdated: ((UUID, String, String, String) -> Void)? = nil,
        onMarkerAdded: ((CGFloat, String, String, String) -> Void)? = nil
    ) {
        self.segments = segments
        self.sceneBoundaries = sceneBoundaries
        self.sequenceBoundaries = sequenceBoundaries
        self.shotLabels = shotLabels
        self.showShotLabels = showShotLabels
        self.pxPerSec = pxPerSec
        self.mode = mode
        self.viewportSize = viewportSize
        self.shotSubLaneAssignments = shotSubLaneAssignments
        self.shotLaneSubLaneCount = shotLaneSubLaneCount
        self.shotDialogueConnections = shotDialogueConnections
        self.showShotConnections = showShotConnections
        self.playheadTime = playheadTime
        self.playheadActive = playheadActive
        self.userMarkers = userMarkers
        self.projectBasePath = projectBasePath
        self.soundtrackTracks = soundtrackTracks
        self.showSoundtracks = showSoundtracks
        self.lightCues = lightCues
        self.showLightingLane = showLightingLane
        self.sfxCues = sfxCues
        self.showSFXLane = showSFXLane
        self.supportCues = supportCues
        self.showSupportLane = showSupportLane
        self.onLightCueAdded = onLightCueAdded
        self.onLightCueDeleted = onLightCueDeleted
        self.onLightCueUpdated = onLightCueUpdated
        self.onLightCueMoved = onLightCueMoved
        self.onLightCueResized = onLightCueResized
        self.onLightCueDoubleClicked = onLightCueDoubleClicked
        self.onLightingLaneToggled = onLightingLaneToggled
        self.onSFXCueAdded = onSFXCueAdded
        self.onSFXCueDeleted = onSFXCueDeleted
        self.onSFXCueUpdated = onSFXCueUpdated
        self.onSFXCueMoved = onSFXCueMoved
        self.onSFXCueResized = onSFXCueResized
        self.onSFXCueDoubleClicked = onSFXCueDoubleClicked
        self.onSFXLaneToggled = onSFXLaneToggled
        self.onSupportCueAdded = onSupportCueAdded
        self.onSupportCueDeleted = onSupportCueDeleted
        self.onSupportCueUpdated = onSupportCueUpdated
        self.onSupportCueMoved = onSupportCueMoved
        self.onSupportCueResized = onSupportCueResized
        self.onSupportCueDoubleClicked = onSupportCueDoubleClicked
        self.onSupportLaneToggled = onSupportLaneToggled
        self.onSoundtrackMoved = onSoundtrackMoved
        self.onSoundtrackTrackToggled = onSoundtrackTrackToggled
        self.onSoundtrackMuteToggled = onSoundtrackMuteToggled
        self.onSoundtrackRemoved = onSoundtrackRemoved
        self.onShotLabelDoubleClicked = onShotLabelDoubleClicked
        self.onSceneMarkerDoubleClicked = onSceneMarkerDoubleClicked
        self.onShotLabelMoved = onShotLabelMoved
        self.onShotLabelSelected = onShotLabelSelected
        self.onOptionClickShotLabel = onOptionClickShotLabel
        self.onShotTrackToggled = onShotTrackToggled
        self.onShotLabelResized = onShotLabelResized
        self.onSceneBoundaryMoved = onSceneBoundaryMoved
        self.onSequenceBoundaryMoved = onSequenceBoundaryMoved
        self.onRulerClicked = onRulerClicked
        self.onPlayheadDragged = onPlayheadDragged
        self.onMarkerDeleted = onMarkerDeleted
        self.onMarkerUpdated = onMarkerUpdated
        self.onMarkerAdded = onMarkerAdded
    }

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            // Read the cache version so the Canvas redraws when a background
            // preview-image load completes (WS9.2).
            _ = previewCacheVersion
            drawBackground(context: context, size: size)
            drawTimeRuler(context: context, size: size)

            // Always draw shot lane (expanded or collapsed strip)
            drawShotLabels(context: context, size: size)

            drawSoundtrackLane(context: context, size: size)
            drawLightingCueLane(context: context, size: size)
            drawSFXCueLane(context: context, size: size)
            drawSupportCueLane(context: context, size: size)
            drawHeaderUserMarkers(context: context, size: size)
            drawScopeMarkers(context: context, size: size)
            drawPlayhead(context: context, size: size)
        }
        .frame(width: totalWidth, height: headerHeight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { location in
            // Check for scene marker double-click
            if let (boundary, isSequence) = findBoundaryMarker(at: location), !isSequence {
                onSceneMarkerDoubleClicked?(boundary.name)
                return
            }
            if showShotLabels, let shotLabel = findShotLabel(at: location) {
                onShotLabelDoubleClicked?(shotLabel.shotId, shotLabel.sceneName)
                return
            }
            // Check for light cue double-click → open full editor
            if showLightingLane, let cue = findLightCue(at: location) {
                onLightCueDoubleClicked?(cue.id)
                return
            }
            // Check for SFX cue double-click → open full editor
            if showSFXLane, let cue = findSFXCue(at: location) {
                onSFXCueDoubleClicked?(cue.id)
                return
            }
            // Check for support cue double-click → open full editor
            if showSupportLane, let cue = findSupportCue(at: location) {
                onSupportCueDoubleClicked?(cue.id)
                return
            }
            // Double-click anywhere else in header → position playhead
            if location.x >= originX {
                onRulerClicked?(location.x)
            }
        }
        .onTapGesture(count: 1) { location in
            // Check for support lane eye toggle
            if isSupportEyeToggleHit(at: location) {
                onSupportLaneToggled?()
                return
            }
            // Check for SFX lane eye toggle
            if isSFXEyeToggleHit(at: location) {
                onSFXLaneToggled?()
                return
            }
            // Check for lighting lane eye toggle
            if isLightingEyeToggleHit(at: location) {
                onLightingLaneToggled?()
                return
            }
            // Check for shot track eye toggle first
            if isShotEyeToggleHit(at: location) {
                onShotTrackToggled?()
                return
            }
            // Option+Click on shot label → jump to script
            if showShotLabels, NSEvent.modifierFlags.contains(.option), let shotLabel = findShotLabel(at: location) {
                onOptionClickShotLabel?(shotLabel.shotId, shotLabel.sceneName)
                return
            }
            // Click on shot label → select it AND position playhead
            if showShotLabels, let shotLabel = findShotLabel(at: location) {
                onShotLabelSelected?(shotLabel.id)
                onRulerClicked?(location.x)
                return
            }
            // Click anywhere in the header area → position playhead (FCP-style)
            if location.x >= originX {
                onRulerClicked?(location.x)
                return
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    // First frame: decide what we're dragging
                    if draggingShotId == nil && resizingShotId == nil && draggingBoundaryId == nil && !isDraggingPlayhead && draggingSoundtrackId == nil && draggingLightCueId == nil && resizingLightCueId == nil && draggingSFXCueId == nil && resizingSFXCueId == nil && draggingSupportCueId == nil && resizingSupportCueId == nil {
                        // 0x. Check support cue right-edge (resize)
                        if showSupportLane, let cue = findSupportCueRightEdge(at: value.startLocation) {
                            resizingSupportCueId = cue.id
                            supportCueResizeStartX = value.startLocation.x
                            supportCueResizeStartDuration = CGFloat(cue.duration)
                        }
                        // 0x2. Check support cue body (move)
                        else if showSupportLane, let cue = findSupportCue(at: value.startLocation) {
                            draggingSupportCueId = cue.id
                            supportCueDragStartX = value.startLocation.x
                        }
                        // 0w. Check SFX cue right-edge (resize)
                        else if showSFXLane, let cue = findSFXCueRightEdge(at: value.startLocation) {
                            resizingSFXCueId = cue.id
                            sfxCueResizeStartX = value.startLocation.x
                            sfxCueResizeStartDuration = CGFloat(cue.duration)
                        }
                        // 0v. Check SFX cue body (move)
                        else if showSFXLane, let cue = findSFXCue(at: value.startLocation) {
                            draggingSFXCueId = cue.id
                            sfxCueDragStartX = value.startLocation.x
                        }
                        // 0z. Check light cue right-edge (resize)
                        else if showLightingLane, let cue = findLightCueRightEdge(at: value.startLocation) {
                            resizingLightCueId = cue.id
                            lightCueResizeStartX = value.startLocation.x
                            lightCueResizeStartDuration = CGFloat(cue.duration)
                        }
                        // 0y. Check light cue body (move)
                        else if showLightingLane, let cue = findLightCue(at: value.startLocation) {
                            draggingLightCueId = cue.id
                            lightCueDragStartX = value.startLocation.x
                        }
                        // 0a. Check soundtrack waveform drag
                        else if let trackId = findSoundtrackTrack(at: value.startLocation) {
                            draggingSoundtrackId = trackId
                            soundtrackDragStartX = value.startLocation.x
                        }
                        // 0. Check playhead handle or any area not on a shot label/boundary (FCP-style scrub)
                        let startInClickableArea = value.startLocation.x >= originX
                        let startOnShotLabel = showShotLabels && findShotLabel(at: value.startLocation) != nil
                        let startOnShotEdge = showShotLabels && findShotLabelRightEdge(at: value.startLocation) != nil
                        let startOnBoundary = findBoundaryMarker(at: value.startLocation) != nil
                        let startOnSoundtrack = draggingSoundtrackId != nil
                        let startOnLightCue = draggingLightCueId != nil || resizingLightCueId != nil
                        let startOnSFXCue = draggingSFXCueId != nil || resizingSFXCueId != nil
                        let startOnSupportCue = draggingSupportCueId != nil || resizingSupportCueId != nil
                        if !startOnSoundtrack && !startOnLightCue && !startOnSFXCue && !startOnSupportCue && (findPlayheadHandle(at: value.startLocation) ||
                           (startInClickableArea && !startOnShotLabel && !startOnShotEdge && !startOnBoundary)) {
                            isDraggingPlayhead = true
                            onPlayheadDragged?(value.location.x)
                            return
                        }
                        // 1. Check boundary markers first (top margin area)
                        if let (boundary, isSequence) = findBoundaryMarker(at: value.startLocation) {
                            draggingBoundaryId = boundary.id
                            draggingBoundaryIsSequence = isSequence
                            dragBoundaryStartX = value.startLocation.x
                        }
                        // 2. Check shot right-edge (resize)
                        else if showShotLabels, let shotLabel = findShotLabelRightEdge(at: value.startLocation) {
                            resizingShotId = shotLabel.id
                            resizeStartX = value.startLocation.x
                            resizeStartDuration = shotLabel.duration > 0 ? shotLabel.duration : shotLabel.displayWidth(pxPerSec: pxPerSec) / pxPerSec
                        }
                        // 3. Check shot label body (move)
                        else if showShotLabels, let shotLabel = findShotLabel(at: value.startLocation) {
                            draggingShotId = shotLabel.id
                            dragStartX = value.startLocation.x
                        }
                    }
                    if isDraggingPlayhead {
                        onPlayheadDragged?(value.location.x)
                        return
                    }
                    if draggingSoundtrackId != nil {
                        dragCurrentX = value.location.x
                    }
                    if draggingLightCueId != nil || resizingLightCueId != nil {
                        dragCurrentX = value.location.x
                    }
                    if draggingSFXCueId != nil || resizingSFXCueId != nil {
                        dragCurrentX = value.location.x
                    }
                    if draggingSupportCueId != nil || resizingSupportCueId != nil {
                        dragCurrentX = value.location.x
                    }
                    if draggingShotId != nil || resizingShotId != nil || draggingBoundaryId != nil {
                        dragCurrentX = value.location.x
                    }
                }
                .onEnded { value in
                    // Handle playhead drag end
                    if isDraggingPlayhead {
                        onPlayheadDragged?(value.location.x)
                        isDraggingPlayhead = false
                        return
                    }
                    // Handle boundary move end
                    if let boundaryId = draggingBoundaryId {
                        let deltaX = value.location.x - dragBoundaryStartX
                        let deltaTime = deltaX / pxPerSec
                        if draggingBoundaryIsSequence {
                            if let boundary = sequenceBoundaries.first(where: { $0.id == boundaryId }) {
                                let newTime = max(0, boundary.time + deltaTime)
                                onSequenceBoundaryMoved?(boundary.name, newTime)
                            }
                        } else {
                            if let boundary = sceneBoundaries.first(where: { $0.id == boundaryId }) {
                                let newTime = max(0, boundary.time + deltaTime)
                                onSceneBoundaryMoved?(boundary.name, newTime)
                            }
                        }
                    }
                    // Handle resize end
                    else if let resizeId = resizingShotId,
                       let shotLabel = shotLabels.first(where: { $0.id == resizeId }) {
                        let deltaX = value.location.x - resizeStartX
                        let newDuration = max(0.5, resizeStartDuration + deltaX / pxPerSec)
                        onShotLabelResized?(shotLabel.shotId, shotLabel.sceneName, newDuration)
                    }
                    // Handle shot move end
                    else if let dragId = draggingShotId,
                       let shotLabel = shotLabels.first(where: { $0.id == dragId }) {
                        let deltaX = value.location.x - dragStartX
                        let deltaTime = deltaX / pxPerSec
                        let newTime = max(0, shotLabel.time + deltaTime)
                        onShotLabelMoved?(shotLabel.shotId, shotLabel.sceneName, newTime)
                    }
                    // Handle light cue resize end
                    if let resizeId = resizingLightCueId,
                       let cue = lightCues.first(where: { $0.id == resizeId }) {
                        let deltaX = value.location.x - lightCueResizeStartX
                        let newDuration = max(0.5, Double(lightCueResizeStartDuration + deltaX / pxPerSec))
                        onLightCueResized?(cue.id, newDuration)
                    }
                    // Handle light cue move end
                    else if let dragId = draggingLightCueId,
                       let cue = lightCues.first(where: { $0.id == dragId }) {
                        let deltaX = value.location.x - lightCueDragStartX
                        let deltaTime = Double(deltaX / pxPerSec)
                        let newTime = max(0, cue.startTime + deltaTime)
                        onLightCueMoved?(cue.id, newTime)
                    }
                    // Handle SFX cue resize end
                    if let resizeId = resizingSFXCueId,
                       let cue = sfxCues.first(where: { $0.id == resizeId }) {
                        let deltaX = value.location.x - sfxCueResizeStartX
                        let newDuration = max(0.5, Double(sfxCueResizeStartDuration + deltaX / pxPerSec))
                        onSFXCueResized?(cue.id, newDuration)
                    }
                    // Handle SFX cue move end
                    else if let dragId = draggingSFXCueId,
                       let cue = sfxCues.first(where: { $0.id == dragId }) {
                        let deltaX = value.location.x - sfxCueDragStartX
                        let deltaTime = Double(deltaX / pxPerSec)
                        let newTime = max(0, cue.startTime + deltaTime)
                        onSFXCueMoved?(cue.id, newTime)
                    }
                    // Handle support cue resize end
                    if let resizeId = resizingSupportCueId,
                       let cue = supportCues.first(where: { $0.id == resizeId }) {
                        let deltaX = value.location.x - supportCueResizeStartX
                        let newDuration = max(0.5, Double(supportCueResizeStartDuration + deltaX / pxPerSec))
                        onSupportCueResized?(cue.id, newDuration)
                    }
                    // Handle support cue move end
                    else if let dragId = draggingSupportCueId,
                       let cue = supportCues.first(where: { $0.id == dragId }) {
                        let deltaX = value.location.x - supportCueDragStartX
                        let deltaTime = Double(deltaX / pxPerSec)
                        let newTime = max(0, cue.startTime + deltaTime)
                        onSupportCueMoved?(cue.id, newTime)
                    }
                    // Handle soundtrack move end
                    if let trackId = draggingSoundtrackId,
                       let track = soundtrackTracks.first(where: { $0.id == trackId }) {
                        let deltaX = value.location.x - soundtrackDragStartX
                        let deltaTime = Double(deltaX / pxPerSec)
                        let newOffset = max(0, track.startTimeOffset + deltaTime)
                        onSoundtrackMoved?(trackId, newOffset)
                    }
                    draggingShotId = nil
                    resizingShotId = nil
                    draggingBoundaryId = nil
                    draggingBoundaryIsSequence = false
                    draggingSoundtrackId = nil
                    soundtrackDragStartX = 0
                    draggingLightCueId = nil
                    lightCueDragStartX = 0
                    resizingLightCueId = nil
                    lightCueResizeStartX = 0
                    lightCueResizeStartDuration = 0
                    draggingSFXCueId = nil
                    sfxCueDragStartX = 0
                    resizingSFXCueId = nil
                    sfxCueResizeStartX = 0
                    sfxCueResizeStartDuration = 0
                    draggingSupportCueId = nil
                    supportCueDragStartX = 0
                    resizingSupportCueId = nil
                    supportCueResizeStartX = 0
                    supportCueResizeStartDuration = 0
                    dragCurrentX = 0
                    dragStartX = 0
                    dragBoundaryStartX = 0
                    resizeStartX = 0
                    resizeStartDuration = 0
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                // Cursor changes for resize handles
                if showShotLabels, findShotLabelRightEdge(at: location) != nil {
                    NSCursor.resizeLeftRight.set()
                } else if showLightingLane, findLightCueRightEdge(at: location) != nil {
                    NSCursor.resizeLeftRight.set()
                } else if showSFXLane, findSFXCueRightEdge(at: location) != nil {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
                // Marker tooltip
                if let marker = findUserMarker(at: location) {
                    let screenPoint = NSEvent.mouseLocation
                    MarkerTooltip.shared.show(text: marker.label, near: screenPoint)
                } else {
                    MarkerTooltip.shared.hide()
                }
            case .ended:
                NSCursor.arrow.set()
                MarkerTooltip.shared.hide()
            }
        }
        .overlay(
            RightClickOverlay { point, nsView in
                // Check user markers first
                if let marker = findUserMarker(at: point) {
                    let menu = NSMenu()
                    let editItem = NSMenuItem(title: "Edit Marker...", action: nil, keyEquivalent: "")
                    let deleteItem = NSMenuItem(title: "Delete Marker", action: nil, keyEquivalent: "")

                    let editHandler = MarkerMenuHandler {
                        contextMenuMarker = marker
                        addMarkerTime = nil
                        markerPopoverAnchor = point
                        markerEditLabel = marker.label
                        markerEditIcon = marker.icon
                        markerEditColor = marker.color
                        showMarkerEditPopover = true
                    }
                    editItem.target = editHandler
                    editItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(editItem, "handler", editHandler, .OBJC_ASSOCIATION_RETAIN)

                    let deleteHandler = MarkerMenuHandler {
                        onMarkerDeleted?(marker.id)
                    }
                    deleteItem.target = deleteHandler
                    deleteItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(deleteItem, "handler", deleteHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(editItem)
                    menu.addItem(deleteItem)

                    // Use unflipped coordinates relative to the NSView
                    let unflippedY = nsView.bounds.height - point.y
                    menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: unflippedY), in: nsView)
                    return
                }
                // Right-click on ruler area → "Add Marker Here"
                let rulerTop = TimelineLayoutConstants.topMargin
                let rulerBottom = rulerTop + TimelineLayoutConstants.rulerHeight
                if point.y >= rulerTop && point.y <= rulerBottom && point.x >= originX {
                    let time = max(0, (point.x - originX) / pxPerSec)
                    let menu = NSMenu()
                    let addItem = NSMenuItem(title: "Add Marker Here", action: nil, keyEquivalent: "")

                    let addHandler = MarkerMenuHandler {
                        addMarkerTime = time
                        contextMenuMarker = nil
                        markerPopoverAnchor = point
                        markerEditLabel = "Marker"
                        markerEditIcon = "flag.fill"
                        markerEditColor = "#FF5F5F"
                        showMarkerEditPopover = true
                    }
                    addItem.target = addHandler
                    addItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(addItem, "handler", addHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(addItem)

                    // Add Lighting Cue Here
                    menu.addItem(NSMenuItem.separator())
                    let addLightingItem = NSMenuItem(title: "Add Lighting Cue Here", action: nil, keyEquivalent: "")
                    addLightingItem.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: nil)

                    let addLightingHandler = MarkerMenuHandler {
                        addLightCueTime = time
                        contextMenuLightCue = nil
                        lightCuePopoverAnchor = point
                        lightCueEditName = "New Light Cue"
                        let nextNum = lightCues.count + 1
                        lightCueEditNumber = "Q\(nextNum)"
                        lightCueEditWorkflow = .cinema
                        lightCueEditFixture = .keyLight
                        lightCueEditIntensity = 1.0
                        lightCueEditDuration = 5.0
                        lightCueEditColor = "#FFD60A"
                        showLightCuePopover = true
                    }
                    addLightingItem.target = addLightingHandler
                    addLightingItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(addLightingItem, "handler", addLightingHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(addLightingItem)

                    // Add SFX Cue Here
                    let addSFXItem = NSMenuItem(title: "Add SFX Cue Here", action: nil, keyEquivalent: "")
                    addSFXItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)

                    let addSFXHandler = MarkerMenuHandler {
                        addSFXCueTime = time
                        contextMenuSFXCue = nil
                        sfxCuePopoverAnchor = point
                        sfxCueEditName = "New SFX Cue"
                        let nextNum = sfxCues.count + 1
                        sfxCueEditNumber = "FX\(nextNum)"
                        sfxCueEditEffectType = .smoke
                        sfxCueEditIntensity = 0.8
                        sfxCueEditDuration = 5.0
                        sfxCueEditColor = "#FF6B35"
                        showSFXCuePopover = true
                    }
                    addSFXItem.target = addSFXHandler
                    addSFXItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(addSFXItem, "handler", addSFXHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(addSFXItem)

                    // Add Support Cue Here
                    let addSupportItem = NSMenuItem(title: "Add Support Cue Here", action: nil, keyEquivalent: "")
                    addSupportItem.image = NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: nil)

                    let addSupportHandler = MarkerMenuHandler {
                        addSupportCueTime = time
                        contextMenuSupportCue = nil
                        supportCuePopoverAnchor = point
                        supportCueEditName = "New Support Cue"
                        let nextNum = supportCues.count + 1
                        supportCueEditNumber = "S\(nextNum)"
                        supportCueEditActionType = .propMove
                        supportCueEditPriority = .medium
                        supportCueEditAssignedTo = ""
                        supportCueEditDuration = 5.0
                        supportCueEditColor = "#2DD4BF"
                        showSupportCuePopover = true
                    }
                    addSupportItem.target = addSupportHandler
                    addSupportItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(addSupportItem, "handler", addSupportHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(addSupportItem)

                    // Use unflipped coordinates relative to the NSView
                    let unflippedY = nsView.bounds.height - point.y
                    menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: unflippedY), in: nsView)
                    return
                }
                // Right-click on an SFX cue bar → Edit/Delete
                if let cue = findSFXCue(at: point) {
                    let menu = NSMenu()
                    let editItem = NSMenuItem(title: "Edit SFX Cue...", action: nil, keyEquivalent: "")
                    let deleteItem = NSMenuItem(title: "Delete SFX Cue", action: nil, keyEquivalent: "")
                    deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)

                    let editHandler = MarkerMenuHandler {
                        contextMenuSFXCue = cue
                        addSFXCueTime = nil
                        sfxCuePopoverAnchor = point
                        sfxCueEditName = cue.name
                        sfxCueEditNumber = cue.cueNumber
                        sfxCueEditEffectType = cue.effectType
                        sfxCueEditIntensity = cue.intensity
                        sfxCueEditDuration = cue.duration
                        sfxCueEditColor = cue.markerColor
                        showSFXCuePopover = true
                    }
                    editItem.target = editHandler
                    editItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(editItem, "handler", editHandler, .OBJC_ASSOCIATION_RETAIN)

                    let deleteHandler = MarkerMenuHandler {
                        onSFXCueDeleted?(cue.id)
                    }
                    deleteItem.target = deleteHandler
                    deleteItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(deleteItem, "handler", deleteHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(editItem)
                    menu.addItem(deleteItem)

                    let unflippedY = nsView.bounds.height - point.y
                    menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: unflippedY), in: nsView)
                    return
                }
                // Right-click on a light cue bar → Edit/Delete
                if let cue = findLightCue(at: point) {
                    let menu = NSMenu()
                    let editItem = NSMenuItem(title: "Edit Light Cue...", action: nil, keyEquivalent: "")
                    let deleteItem = NSMenuItem(title: "Delete Light Cue", action: nil, keyEquivalent: "")
                    deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)

                    let editHandler = MarkerMenuHandler {
                        contextMenuLightCue = cue
                        addLightCueTime = nil
                        lightCuePopoverAnchor = point
                        lightCueEditName = cue.name
                        lightCueEditNumber = cue.cueNumber
                        lightCueEditWorkflow = cue.workflow
                        lightCueEditFixture = cue.fixtureType
                        lightCueEditIntensity = cue.intensity
                        lightCueEditDuration = cue.duration
                        lightCueEditColor = cue.markerColor
                        showLightCuePopover = true
                    }
                    editItem.target = editHandler
                    editItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(editItem, "handler", editHandler, .OBJC_ASSOCIATION_RETAIN)

                    let deleteHandler = MarkerMenuHandler {
                        onLightCueDeleted?(cue.id)
                    }
                    deleteItem.target = deleteHandler
                    deleteItem.action = #selector(MarkerMenuHandler.execute)
                    objc_setAssociatedObject(deleteItem, "handler", deleteHandler, .OBJC_ASSOCIATION_RETAIN)

                    menu.addItem(editItem)
                    menu.addItem(deleteItem)

                    let unflippedY = nsView.bounds.height - point.y
                    menu.popUp(positioning: nil, at: NSPoint(x: point.x, y: unflippedY), in: nsView)
                    return
                }
                if showShotLabels, let shotLabel = findShotLabel(at: point) {
                    contextMenuShot = shotLabel
                    let currentDuration = shotLabel.duration > 0 ? shotLabel.duration : shotLabel.displayWidth(pxPerSec: pxPerSec) / pxPerSec
                    durationInputText = String(format: "%.1f", currentDuration)
                    showDurationPopover = true
                }
            }
        )
        .popover(isPresented: $showDurationPopover, arrowEdge: .bottom) {
            if let shot = contextMenuShot {
                VStack(spacing: 12) {
                    Text("\(shot.shotName) \u{2022} \(shot.shotType)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text("Duration (sec):")
                            .font(.system(size: 11))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        TextField("", text: $durationInputText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onSubmit {
                                applyDurationInput()
                            }
                    }

                    HStack(spacing: 8) {
                        Button("Cancel") {
                            showDurationPopover = false
                            contextMenuShot = nil
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("Set") {
                            applyDurationInput()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
                .frame(width: 240)
            }
        }
        .overlay(
            Color.clear
                .frame(width: 1, height: 1)
                .position(markerPopoverAnchor)
                .popover(isPresented: $showMarkerEditPopover, arrowEdge: .bottom) {
                    if let marker = contextMenuMarker {
                        // Editing existing marker
                        MarkerConfigPopover(
                            markerLabel: $markerEditLabel,
                            markerIcon: $markerEditIcon,
                            markerColor: $markerEditColor,
                            isEditing: true,
                            onSave: {
                                onMarkerUpdated?(marker.id, markerEditLabel, markerEditIcon, markerEditColor)
                                showMarkerEditPopover = false
                                contextMenuMarker = nil
                            },
                            onCancel: {
                                showMarkerEditPopover = false
                                contextMenuMarker = nil
                            }
                        )
                    } else if let time = addMarkerTime {
                        // Adding new marker
                        MarkerConfigPopover(
                            markerLabel: $markerEditLabel,
                            markerIcon: $markerEditIcon,
                            markerColor: $markerEditColor,
                            isEditing: false,
                            onSave: {
                                onMarkerAdded?(time, markerEditLabel, markerEditIcon, markerEditColor)
                                showMarkerEditPopover = false
                                addMarkerTime = nil
                            },
                            onCancel: {
                                showMarkerEditPopover = false
                                addMarkerTime = nil
                            }
                        )
                    }
                }
        )
        .overlay(
            Color.clear
                .frame(width: 1, height: 1)
                .position(lightCuePopoverAnchor)
                .popover(isPresented: $showLightCuePopover, arrowEdge: .bottom) {
                    if let cue = contextMenuLightCue {
                        LightCueConfigPopover(
                            cueName: $lightCueEditName,
                            cueNumber: $lightCueEditNumber,
                            workflow: $lightCueEditWorkflow,
                            fixtureType: $lightCueEditFixture,
                            intensity: $lightCueEditIntensity,
                            duration: $lightCueEditDuration,
                            cueColor: $lightCueEditColor,
                            isEditing: true,
                            onSave: {
                                var updated = cue
                                updated.name = lightCueEditName
                                updated.cueNumber = lightCueEditNumber
                                updated.workflow = lightCueEditWorkflow
                                updated.fixtureType = lightCueEditFixture
                                updated.intensity = lightCueEditIntensity
                                updated.duration = lightCueEditDuration
                                updated.markerColor = lightCueEditColor
                                updated.color = lightCueEditColor
                                onLightCueUpdated?(updated)
                                showLightCuePopover = false
                                contextMenuLightCue = nil
                            },
                            onCancel: {
                                showLightCuePopover = false
                                contextMenuLightCue = nil
                            }
                        )
                    } else if let time = addLightCueTime {
                        LightCueConfigPopover(
                            cueName: $lightCueEditName,
                            cueNumber: $lightCueEditNumber,
                            workflow: $lightCueEditWorkflow,
                            fixtureType: $lightCueEditFixture,
                            intensity: $lightCueEditIntensity,
                            duration: $lightCueEditDuration,
                            cueColor: $lightCueEditColor,
                            isEditing: false,
                            onSave: {
                                onLightCueAdded?(time, lightCueEditName, lightCueEditNumber, lightCueEditWorkflow, lightCueEditFixture, lightCueEditIntensity, lightCueEditDuration, lightCueEditColor)
                                showLightCuePopover = false
                                addLightCueTime = nil
                            },
                            onCancel: {
                                showLightCuePopover = false
                                addLightCueTime = nil
                            }
                        )
                    }
                }
        )
        .popover(isPresented: $showSFXCuePopover, arrowEdge: .bottom) {
            if let cue = contextMenuSFXCue {
                SFXCueConfigPopover(
                    cueName: $sfxCueEditName,
                    cueNumber: $sfxCueEditNumber,
                    effectType: $sfxCueEditEffectType,
                    intensity: $sfxCueEditIntensity,
                    duration: $sfxCueEditDuration,
                    cueColor: $sfxCueEditColor,
                    isEditing: true,
                    onSave: {
                        var updated = cue
                        updated.name = sfxCueEditName
                        updated.cueNumber = sfxCueEditNumber
                        updated.effectType = sfxCueEditEffectType
                        updated.intensity = sfxCueEditIntensity
                        updated.duration = sfxCueEditDuration
                        updated.markerColor = sfxCueEditColor
                        updated.color = sfxCueEditColor
                        onSFXCueUpdated?(updated)
                        showSFXCuePopover = false
                        contextMenuSFXCue = nil
                    },
                    onCancel: {
                        showSFXCuePopover = false
                        contextMenuSFXCue = nil
                    }
                )
            } else if let time = addSFXCueTime {
                SFXCueConfigPopover(
                    cueName: $sfxCueEditName,
                    cueNumber: $sfxCueEditNumber,
                    effectType: $sfxCueEditEffectType,
                    intensity: $sfxCueEditIntensity,
                    duration: $sfxCueEditDuration,
                    cueColor: $sfxCueEditColor,
                    isEditing: false,
                    onSave: {
                        onSFXCueAdded?(time, sfxCueEditName, sfxCueEditNumber, sfxCueEditEffectType, sfxCueEditIntensity, sfxCueEditDuration, sfxCueEditColor)
                        showSFXCuePopover = false
                        addSFXCueTime = nil
                    },
                    onCancel: {
                        showSFXCuePopover = false
                        addSFXCueTime = nil
                    }
                )
            }
        }
        .overlay(CommandKeyMonitor(isCommandKeyDown: $isCommandKeyDown))
        .onAppear {
            recomputeCachedSubLanes()
            // Redraw when a background preview-image load completes (WS9.2).
            previewImageCache.onImageLoaded = { previewCacheVersion += 1 }
        }
        .onChange(of: lightCues) { _ in recomputeCachedSubLanes() }
        .onChange(of: sfxCues) { _ in recomputeCachedSubLanes() }
        .onChange(of: supportCues) { _ in recomputeCachedSubLanes() }
        .onChange(of: showLightingLane) { _ in recomputeCachedSubLanes() }
        .onChange(of: showSFXLane) { _ in recomputeCachedSubLanes() }
        .onChange(of: showSupportLane) { _ in recomputeCachedSubLanes() }
    }
}

// MARK: - Right-Click Overlay

/// Transparent NSView overlay that intercepts only right-click events via a local event monitor.
/// Uses hitTest → nil so it never blocks left-click / drag events from reaching SwiftUI.
private struct RightClickOverlay: NSViewRepresentable {
    var onRightClick: (CGPoint, NSView) -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        view.installMonitor()
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    class RightClickNSView: NSView {
        var onRightClick: ((CGPoint, NSView) -> Void)?
        private var monitor: Any?

        // Never intercept hit-testing — all left-click/drag events pass through to SwiftUI
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }

        func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self = self, let window = self.window, event.window === window else {
                    return event
                }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                // Only handle if the click is within our bounds
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

// MARK: - Command Key Monitor

/// Invisible overlay that monitors Command key press/release via flagsChanged events
private struct CommandKeyMonitor: NSViewRepresentable {
    @Binding var isCommandKeyDown: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isCommandKeyDown: $isCommandKeyDown)
    }

    func makeNSView(context: Context) -> CommandKeyNSView {
        let view = CommandKeyNSView()
        view.coordinator = context.coordinator
        view.installMonitor()
        return view
    }

    func updateNSView(_ nsView: CommandKeyNSView, context: Context) {
        nsView.coordinator = context.coordinator
    }

    class Coordinator {
        var isCommandKeyDown: Binding<Bool>
        init(isCommandKeyDown: Binding<Bool>) {
            self.isCommandKeyDown = isCommandKeyDown
        }
    }

    class CommandKeyNSView: NSView {
        weak var coordinator: Coordinator?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                let isCommand = event.modifierFlags.contains(.command)
                DispatchQueue.main.async {
                    self?.coordinator?.isCommandKeyDown.wrappedValue = isCommand
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

// MARK: - Marker Menu Handler

/// NSObject target for NSMenu items — holds a closure for the menu action
private class MarkerMenuHandler: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    @objc func execute() {
        action()
    }
}

// MARK: - Marker Config Popover

/// Popover for creating or editing a user marker (name, icon, color)
struct MarkerConfigPopover: View {
    @Binding var markerLabel: String
    @Binding var markerIcon: String
    @Binding var markerColor: String

    var isEditing: Bool = false
    var onSave: () -> Void
    var onCancel: () -> Void

    let iconOptions = [
        "flag.fill", "star.fill", "bolt.fill", "lightbulb.fill",
        "camera.fill", "music.note", "exclamationmark.triangle.fill", "bookmark.fill",
        "mappin", "heart.fill", "bell.fill", "tag.fill"
    ]

    let colorOptions = [
        "#FF5F5F", "#FF9500", "#FFD60A", "#34C759",
        "#007AFF", "#AF52DE", "#FF2D55"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing ? "Edit Marker" : "Add Marker")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            // Name field
            HStack {
                Text("Name:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .frame(width: 40, alignment: .trailing)
                TextField("Marker", text: $markerLabel)
                    .textFieldStyle(.roundedBorder)
            }

            // Icon grid
            VStack(alignment: .leading, spacing: 4) {
                Text("Icon:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 6), spacing: 4) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button(action: { markerIcon = icon }) {
                            Image(systemName: icon)
                                .font(.system(size: 13))
                                .foregroundColor(markerIcon == icon ? .white : Color(nsColor: .secondaryLabelColor))
                                .frame(width: 28, height: 28)
                                .background(markerIcon == icon ? Color(hex: markerColor).opacity(0.7) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(markerIcon == icon ? Color(hex: markerColor) : Color(nsColor: .separatorColor), lineWidth: markerIcon == icon ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color swatches
            VStack(alignment: .leading, spacing: 4) {
                Text("Color:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))

                HStack(spacing: 6) {
                    ForEach(colorOptions, id: \.self) { color in
                        Button(action: { markerColor = color }) {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: markerColor == color ? 2.5 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Buttons
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Update" : "Add") { onSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

// MARK: - Instant Marker Tooltip

/// Floating tooltip window that appears instantly on marker hover
private class MarkerTooltip {
    static let shared = MarkerTooltip()

    var window: NSWindow?
    var currentText: String?

    private init() {}

    func show(text: String, near point: NSPoint) {
        // Skip if already showing the same text
        if currentText == text, window?.isVisible == true { return }
        hide()
        currentText = text

        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.systemFont(ofSize: 11)
        textField.textColor = NSColor.labelColor
        textField.backgroundColor = NSColor.windowBackgroundColor
        textField.isBordered = false
        textField.sizeToFit()

        let padding: CGFloat = 8
        let contentSize = NSSize(
            width: textField.frame.width + padding * 2,
            height: textField.frame.height + padding
        )
        textField.frame.origin = NSPoint(x: padding, y: padding / 2)

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = NSColor.windowBackgroundColor
        win.isOpaque = false
        win.hasShadow = true
        win.level = .floating
        win.ignoresMouseEvents = true
        win.contentView?.wantsLayer = true
        win.contentView?.layer?.cornerRadius = 4
        win.contentView?.addSubview(textField)

        let screenPoint = NSPoint(
            x: point.x - contentSize.width / 2,
            y: point.y - contentSize.height - 20
        )
        win.setFrameOrigin(screenPoint)
        win.orderFront(nil)

        self.window = win
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        currentText = nil
    }
}
