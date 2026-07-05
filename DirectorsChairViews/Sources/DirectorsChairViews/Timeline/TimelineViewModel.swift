// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineViewModel.swift
//
// ViewModel for Timeline - builds segments from Scene/Dialogue data

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

// Note: DCScene typealias is defined in SceneListSidebar.swift
// Using DirectorsChairCore.Sequence for Sequence disambiguation

/// ViewModel for TimelineView
/// Builds TimelineSegments from Scene/Dialogue/Action/Narration data
@MainActor
public class TimelineViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current mode (scene, sequence, global)
    @Published public var mode: TimelineMode = .scene

    /// Computed timeline segments
    @Published public internal(set) var segments: [TimelineSegment] = []

    /// Timeline markers (user + boundaries)
    @Published public internal(set) var markers: [TimelineMarker] = []

    /// Scene boundaries
    @Published public internal(set) var sceneBoundaries: [TimelineBoundary] = []

    /// Sequence boundaries
    @Published public internal(set) var sequenceBoundaries: [TimelineBoundary] = []

    /// Currently selected segment IDs (supports multi-select with Command+click)
    @Published public var selectedSegmentIds: Set<UUID> = []

    /// Currently selected shot label ID (for highlighting connection lines)
    @Published public var selectedShotLabelId: UUID?

    /// Viewport scroll offset
    @Published public var viewportOffset: CGPoint = .zero

    /// Viewport visible width in points (set by TimelineView's GeometryReader)
    public var viewportWidth: CGFloat = 800

    /// Incremented each time we want the view to programmatically scroll to `viewportOffset.x`
    @Published public var scrollRequestId: UUID?

    /// Zoom level (pixels per second)
    @Published public var pxPerSec: CGFloat = TimelineLayoutConstants.defaultPxPerSec

    /// Words per minute for duration calculation
    @Published public var wpm: Int = TimelineWPMConstants.defaultWPM

    /// Whether to show character avatars
    @Published public var showThumbs: Bool = true

    /// Loading state
    @Published public var isLoading: Bool = false

    /// Error state
    @Published public var error: Error?

    // MARK: - Track Visibility Filters

    /// Show dialogue tracks
    @Published public var showDialogue: Bool = true

    /// Show action track
    @Published public var showAction: Bool = false

    /// Show narration track
    @Published public var showNarration: Bool = true

    /// Show sound note track
    @Published public var showSoundNote: Bool = true

    /// Show shot labels lane
    @Published public var showShotLabels: Bool = true

    /// Show shot markers on timeline
    @Published public var showShotMarkers: Bool = true

    /// Per-track visibility: set of hidden track names (character names, "Action", "Narration", "Sound")
    @Published public var hiddenTracks: Set<String> = []

    // MARK: - Soundtrack Tracks

    /// Whether to show soundtrack waveform lanes in the header
    @Published public var showSoundtracks: Bool = true

    /// Imported soundtrack tracks with waveform data
    @Published public var soundtrackTracks: [SoundtrackTrack] = []

    /// Callback when soundtrack tracks are modified (add/remove/move/mute)
    public var onSoundtracksChanged: (([SoundtrackTrack]) -> Void)?

    /// Callback when the user clicks "Import Audio" in the controls
    public var onImportSoundtrack: (() -> Void)?

    // MARK: - Light Cues

    /// Light cues for the lighting lane
    @Published public var lightCues: [LightCue] = []

    /// Whether to show the lighting cue lane
    @Published public var showLightingLane: Bool = true

    /// Callback when light cues are modified
    public var onLightCuesChanged: (([LightCue]) -> Void)?

    // MARK: - SFX Cues

    /// SFX cues for the SFX lane
    @Published public var sfxCues: [SFXCue] = []

    /// Whether to show the SFX cue lane
    @Published public var showSFXLane: Bool = true

    /// Callback when SFX cues are modified
    public var onSFXCuesChanged: (([SFXCue]) -> Void)?

    // MARK: - Support Cues

    /// Support cues for the support lane
    @Published public var supportCues: [SupportCue] = []

    /// Whether to show the support cue lane
    @Published public var showSupportLane: Bool = true

    /// Callback when support cues are modified
    public var onSupportCuesChanged: (([SupportCue]) -> Void)?

    // MARK: - Scene Navigation

    /// Current scene index within allScenesInScope
    @Published public internal(set) var currentSceneIndex: Int = 0

    /// All scenes in current scope (for scene navigation)
    @Published public internal(set) var allScenesInScope: [DCScene] = []

    // MARK: - Shot Labels

    /// Shot labels for the shot lane
    @Published public internal(set) var shotLabels: [TimelineShotLabel] = []

    // MARK: - Duration Tracking

    /// Duration of current scene in seconds
    @Published public internal(set) var currentSceneDuration: CGFloat = 0

    /// Total duration of all content in seconds
    @Published public internal(set) var totalDuration: CGFloat = 0

    // MARK: - Sub-Lane Layout

    /// Maps segment UUID to its sub-lane index (0 = first row, 1 = second row, etc.)
    @Published public internal(set) var subLaneAssignments: [UUID: Int] = [:]

    /// Maps character lane name to the number of sub-lanes it requires
    @Published public internal(set) var laneSubLaneCounts: [String: Int] = [:]

    /// Maps shot label UUID to its sub-lane index within the shots lane
    @Published public internal(set) var shotSubLaneAssignments: [UUID: Int] = [:]

    /// Number of sub-lanes required in the shots lane
    @Published public internal(set) var shotLaneSubLaneCount: Int = 1

    /// Whether to show shot-dialogue connection lines
    @Published public var showShotConnections: Bool = false

    /// Whether to show user markers on the timeline
    @Published public var showUserMarkers: Bool = true

    // MARK: - Playhead

    /// Whether the playhead is active (following cursor)
    @Published public var playheadActive: Bool = false

    /// Playhead position in seconds (nil = no playhead placed yet)
    @Published public var playheadTime: CGFloat? = nil

    /// Called when the user clicks/drags the ruler to seek the playhead.
    /// External consumers (e.g. PlaybackView) set this to react to user seeks.
    public var onPlayheadSeeked: ((CGFloat) -> Void)?

    /// Called when the user clicks the Analyze button in the timeline controls.
    public var onAnalyzeTimelineRequested: (() -> Void)?

    /// Per-character muted TTS tracks (shared with PlaybackViewModel)
    @Published public var mutedTracks: Set<String> = []

    /// Called when the user toggles mute on a track from the timeline context menu.
    /// External consumers (e.g. PlaybackView) set this to sync with PlaybackViewModel.
    public var onTrackMuteToggled: ((String) -> Void)?

    /// Source IDs of dialogues currently generating TTS audio
    @Published public var generatingAudioSourceIds: Set<String> = []

    /// Source ID of the dialogue currently playing TTS audio
    @Published public var playingAudioSourceId: String?

    // MARK: - User Markers

    /// User-created custom markers (separate from auto-rebuilt `markers`)
    @Published public var userMarkers: [TimelineMarker] = []

    /// Project file path (used for saving markers alongside the project)
    public var projectFilePath: URL? {
        didSet {
            if projectFilePath != oldValue {
                loadMarkers()
            }
        }
    }

    /// Computed shot-dialogue connections for drawing connection lines
    @Published public internal(set) var shotDialogueConnections: [ShotDialogueConnection] = []

    // MARK: - Private Properties

    /// Current project reference
    var project: Project?

    /// Current scene ID (for scene mode) — looked up from project on each rebuild to avoid stale snapshots
    var currentSceneId: String?

    /// Current sequence ID (for sequence mode) — looked up from project on each rebuild
    var currentSequenceId: String?

    /// Look up the current scene from the project by ID (always fresh data)
    var currentScene: DCScene? {
        guard let id = currentSceneId, let project = project else { return nil }
        for sequence in project.sequences {
            if let scene = sequence.scenes.first(where: { $0.id == id }) {
                return scene
            }
        }
        return nil
    }

    /// Look up the current sequence from the project by ID (always fresh data)
    var currentSequence: DirectorsChairCore.Sequence? {
        guard let id = currentSequenceId, let project = project else { return nil }
        return project.sequences.first(where: { $0.id == id })
    }

    /// Event bus subscription cancellable
    var eventSubscription: AnyCancellable?

    /// Subscriptions for sub-lane recomputation triggers
    var subLaneSubscriptions = Set<AnyCancellable>()

    /// Cached character lookup by name (rebuilt on each rebuild())
    var characterByName: [String: Character] = [:]

    /// All character names from the project (so every character gets a timeline lane)
    @Published public var allCharacterNames: [String] = []

    // MARK: - Init

    public init() {
        // Recompute sub-lanes when zoom, thumbs, or visibility toggles change
        $pxPerSec
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeAllSubLanes() }
            .store(in: &subLaneSubscriptions)

        $showThumbs
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.recomputeAllSubLanes() }
            .store(in: &subLaneSubscriptions)

        $showDialogue
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.recomputeAllSubLanes() }
            .store(in: &subLaneSubscriptions)

        $showAction
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.recomputeAllSubLanes() }
            .store(in: &subLaneSubscriptions)

        $showNarration
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.recomputeAllSubLanes() }
            .store(in: &subLaneSubscriptions)

        $showSoundNote
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.recomputeAllSubLanes() }
            .store(in: &subLaneSubscriptions)

        $hiddenTracks
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.recomputeAllSubLanes() }
            .store(in: &subLaneSubscriptions)
    }

    // MARK: - Computed Properties

    /// Segments filtered by content type visibility settings
    public var visibleSegments: [TimelineSegment] {
        segments.filter { segment in
            switch segment.contentType {
            case .dialogue: return showDialogue
            case .action: return showAction
            case .narration: return showNarration
            case .soundNote: return showSoundNote
            case .note: return true  // Notes always visible
            }
        }
    }

    /// All track names from current segments (in order of first appearance)
    public var allTrackNames: [String] {
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

    /// Markers filtered by visibility settings
    public var visibleMarkers: [TimelineMarker] {
        markers.filter { marker in
            switch marker.kind {
            case .shot: return showShotMarkers
            case .user, .scene, .sequence, .note: return true
            }
        }
    }
}

// MARK: - TimelineShotLabel

/// Represents a shot label for the shot lane
public struct TimelineShotLabel: Identifiable {
    public let id: UUID
    public var time: CGFloat              // Position in seconds (start)
    public var duration: CGFloat          // Span width in seconds (from linked dialogues)
    public var shotName: String           // e.g., "Shot 1"
    public var shotId: Int                // Reference to Shot.shotId
    public var sceneName: String          // Scene this shot belongs to
    public var linkedDialogueIds: [String]  // Linked dialogue IDs for connections
    public var shotType: String           // e.g., "Wide", "Close-up", "Medium"
    public var cameraAngle: String        // e.g., "Eye Level", "High Angle"
    public var lensMm: Int?               // e.g., 50, 85
    public var movement: String           // e.g., "Static", "Pan", "Dolly"
    public var previewImagePath: String?  // Relative path to AI-generated preview image
    public var hasVideo: Bool              // Whether this shot has a generated video

    /// End time in seconds
    public var end: CGFloat { time + duration }

    public init(
        id: UUID = UUID(),
        time: CGFloat,
        duration: CGFloat = 0,
        shotName: String,
        shotId: Int,
        sceneName: String,
        linkedDialogueIds: [String] = [],
        shotType: String = "Standard",
        cameraAngle: String = "Medium",
        lensMm: Int? = nil,
        movement: String = "Static",
        previewImagePath: String? = nil,
        hasVideo: Bool = false
    ) {
        self.id = id
        self.time = time
        self.duration = duration
        self.shotName = shotName
        self.shotId = shotId
        self.sceneName = sceneName
        self.linkedDialogueIds = linkedDialogueIds
        self.shotType = shotType
        self.cameraAngle = cameraAngle
        self.lensMm = lensMm
        self.movement = movement
        self.previewImagePath = previewImagePath
        self.hasVideo = hasVideo
    }

    /// Compute the visual card width for this shot label (shared between Canvas and ViewModel)
    public func cardWidth() -> CGFloat {
        let topText = "Shot \(shotId) \u{2022} \(shotType)"
        var bottomParts: [String] = [cameraAngle]
        if let lens = lensMm { bottomParts.append("\(lens)mm") }
        let bottomText = bottomParts.joined(separator: " \u{2022} ")

        let longerLen = max(topText.count, bottomText.count)
        let hasMovement = TimelineDefaultColors.iconForMovement(movement) != nil
        let movementExtra: CGFloat = hasMovement ? 18 : 0
        let width = CGFloat(longerLen) * 6.0 + TimelineLayoutConstants.shotAccentBarWidth + 16 + movementExtra
        return max(TimelineLayoutConstants.minShotCardWidth, min(width, 180))
    }

    /// Duration-aware card width: uses duration * pxPerSec when duration is set, otherwise falls back to text-based width
    public func displayWidth(pxPerSec: CGFloat) -> CGFloat {
        if duration > 0 {
            return max(cardWidth(), duration * pxPerSec)
        }
        return cardWidth()
    }
}

// MARK: - ShotDialogueConnection

/// Represents a visual connection between a shot card and a dialogue segment in the timeline
public struct ShotDialogueConnection: Equatable {
    public let shotLabelId: UUID        // Shot label's UUID (for header indicator)
    public let shotTime: CGFloat        // Shot card time position in seconds
    public let dialogueSegmentId: UUID  // Linked dialogue segment UUID
    public let color: String            // Hex color for the connection line
}
