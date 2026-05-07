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
    @Published public private(set) var segments: [TimelineSegment] = []

    /// Timeline markers (user + boundaries)
    @Published public private(set) var markers: [TimelineMarker] = []

    /// Scene boundaries
    @Published public private(set) var sceneBoundaries: [TimelineBoundary] = []

    /// Sequence boundaries
    @Published public private(set) var sequenceBoundaries: [TimelineBoundary] = []

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
    @Published public private(set) var currentSceneIndex: Int = 0

    /// All scenes in current scope (for scene navigation)
    @Published public private(set) var allScenesInScope: [DCScene] = []

    // MARK: - Shot Labels

    /// Shot labels for the shot lane
    @Published public private(set) var shotLabels: [TimelineShotLabel] = []

    // MARK: - Duration Tracking

    /// Duration of current scene in seconds
    @Published public private(set) var currentSceneDuration: CGFloat = 0

    /// Total duration of all content in seconds
    @Published public private(set) var totalDuration: CGFloat = 0

    // MARK: - Sub-Lane Layout

    /// Maps segment UUID to its sub-lane index (0 = first row, 1 = second row, etc.)
    @Published public private(set) var subLaneAssignments: [UUID: Int] = [:]

    /// Maps character lane name to the number of sub-lanes it requires
    @Published public private(set) var laneSubLaneCounts: [String: Int] = [:]

    /// Maps shot label UUID to its sub-lane index within the shots lane
    @Published public private(set) var shotSubLaneAssignments: [UUID: Int] = [:]

    /// Number of sub-lanes required in the shots lane
    @Published public private(set) var shotLaneSubLaneCount: Int = 1

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
    @Published public private(set) var shotDialogueConnections: [ShotDialogueConnection] = []

    // MARK: - Private Properties

    /// Current project reference
    private var project: Project?

    /// Current scene ID (for scene mode) — looked up from project on each rebuild to avoid stale snapshots
    private var currentSceneId: String?

    /// Current sequence ID (for sequence mode) — looked up from project on each rebuild
    private var currentSequenceId: String?

    /// Look up the current scene from the project by ID (always fresh data)
    private var currentScene: DCScene? {
        guard let id = currentSceneId, let project = project else { return nil }
        for sequence in project.sequences {
            if let scene = sequence.scenes.first(where: { $0.id == id }) {
                return scene
            }
        }
        return nil
    }

    /// Look up the current sequence from the project by ID (always fresh data)
    private var currentSequence: DirectorsChairCore.Sequence? {
        guard let id = currentSequenceId, let project = project else { return nil }
        return project.sequences.first(where: { $0.id == id })
    }

    /// Event bus subscription cancellable
    private var eventSubscription: AnyCancellable?

    /// Subscriptions for sub-lane recomputation triggers
    private var subLaneSubscriptions = Set<AnyCancellable>()

    /// Cached character lookup by name (rebuilt on each rebuild())
    private var characterByName: [String: Character] = [:]

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

    // MARK: - Public Methods

    /// Set the project reference
    public func setProject(_ project: Project) {
        self.project = project
        // Subscribe to project changes if EventBus is available
    }

    /// Show a single scene on the timeline
    public func showScene(_ scene: DCScene) {
        currentSceneId = scene.id
        currentSequenceId = nil
        mode = .scene
        rebuild()
    }

    /// Show all scenes in a sequence on the timeline
    public func showSequence(_ sequence: DirectorsChairCore.Sequence) {
        currentSequenceId = sequence.id
        currentSceneId = nil
        mode = .sequence
        rebuild()
    }

    /// Show all sequences and scenes (global view)
    public func showGlobal() {
        currentSceneId = nil
        currentSequenceId = nil
        mode = .global
        rebuild()
    }

    /// Refresh the timeline (rebuild segments)
    public func refresh() {
        rebuild()
    }

    /// Move a scene boundary marker to a new time position
    public func moveSceneBoundary(name: String, newTime: CGFloat) {
        let clampedTime = max(0, newTime)
        if let index = sceneBoundaries.firstIndex(where: { $0.name == name }) {
            sceneBoundaries[index].time = clampedTime
        }
    }

    /// Move a sequence boundary marker to a new time position
    public func moveSequenceBoundary(name: String, newTime: CGFloat) {
        let clampedTime = max(0, newTime)
        if let index = sequenceBoundaries.firstIndex(where: { $0.name == name }) {
            sequenceBoundaries[index].time = clampedTime
        }
    }

    /// Move a shot label to a new time position and persist to project model
    public func moveShotLabel(shotId: Int, sceneName: String, newTime: CGFloat) {
        let clampedTime = max(0, newTime)

        // Update visual label
        if let index = shotLabels.firstIndex(where: { $0.shotId == shotId && $0.sceneName == sceneName }) {
            shotLabels[index].time = clampedTime
            shotLabels.sort {
                if $0.time != $1.time { return $0.time < $1.time }
                return $0.shotId < $1.shotId
            }
        }

        // Persist to project model
        guard let project = project else {
            computeShotSubLanes()
            computeShotDialogueConnections()
            return
        }
        for seqIdx in project.sequences.indices {
            for scnIdx in project.sequences[seqIdx].scenes.indices {
                let scene = project.sequences[seqIdx].scenes[scnIdx]
                if scene.name == sceneName,
                   let shotIdx = scene.shots.firstIndex(where: { $0.shotId == shotId }) {
                    self.project!.sequences[seqIdx].scenes[scnIdx].shots[shotIdx].timelinePosition = Double(clampedTime)
                    computeShotSubLanes()
                    computeShotDialogueConnections()
                    return
                }
            }
        }
        computeShotSubLanes()
        computeShotDialogueConnections()
    }

    /// Resize a shot label to a new duration and persist to the project model
    public func resizeShotLabel(shotId: Int, sceneName: String, newDuration: CGFloat) {
        let clampedDuration = max(0.5, newDuration)

        // Update visual label
        if let index = shotLabels.firstIndex(where: { $0.shotId == shotId && $0.sceneName == sceneName }) {
            shotLabels[index].duration = clampedDuration
            shotLabels.sort {
                if $0.time != $1.time { return $0.time < $1.time }
                return $0.shotId < $1.shotId
            }
        }

        // Persist to project model
        guard let project = project else {
            computeShotSubLanes()
            computeShotDialogueConnections()
            return
        }
        for seqIdx in project.sequences.indices {
            for scnIdx in project.sequences[seqIdx].scenes.indices {
                let scene = project.sequences[seqIdx].scenes[scnIdx]
                if scene.name == sceneName,
                   let shotIdx = scene.shots.firstIndex(where: { $0.shotId == shotId }) {
                    self.project!.sequences[seqIdx].scenes[scnIdx].shots[shotIdx].duration = Double(clampedDuration)
                    computeShotSubLanes()
                    computeShotDialogueConnections()
                    return
                }
            }
        }
        computeShotSubLanes()
        computeShotDialogueConnections()
    }

    /// Move a segment to a new start time and persist to project model
    public func moveSegment(id: UUID, newStart: CGFloat, recomputeSubLanes: Bool = true) {
        let clampedStart = max(0, newStart)

        // Find the segment to get its sourceItemId and content type
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        segments[index].start = clampedStart

        let segment = segments[index]
        guard let sourceId = segment.sourceItemId, let project = project else {
            if recomputeSubLanes { recomputeAllSubLanes() }
            return
        }

        // Persist manualStartTime to the source model item
        for seqIdx in project.sequences.indices {
            for scnIdx in project.sequences[seqIdx].scenes.indices {
                let scene = project.sequences[seqIdx].scenes[scnIdx]
                switch segment.contentType {
                case .dialogue:
                    if let itemIdx = scene.dialogues.firstIndex(where: { $0.id == sourceId }) {
                        self.project!.sequences[seqIdx].scenes[scnIdx].dialogues[itemIdx].manualStartTime = Double(clampedStart)
                        if recomputeSubLanes { recomputeAllSubLanes() }
                        return
                    }
                case .action:
                    if let itemIdx = scene.actions.firstIndex(where: { $0.id == sourceId }) {
                        self.project!.sequences[seqIdx].scenes[scnIdx].actions[itemIdx].manualStartTime = Double(clampedStart)
                        if recomputeSubLanes { recomputeAllSubLanes() }
                        return
                    }
                case .narration:
                    if let itemIdx = scene.narrations.firstIndex(where: { $0.id == sourceId }) {
                        self.project!.sequences[seqIdx].scenes[scnIdx].narrations[itemIdx].manualStartTime = Double(clampedStart)
                        if recomputeSubLanes { recomputeAllSubLanes() }
                        return
                    }
                case .soundNote:
                    if let itemIdx = scene.soundNotes.firstIndex(where: { $0.uuid == sourceId }) {
                        self.project!.sequences[seqIdx].scenes[scnIdx].soundNotes[itemIdx].manualStartTime = Double(clampedStart)
                        if recomputeSubLanes { recomputeAllSubLanes() }
                        return
                    }
                case .note:
                    break
                }
            }
        }
        if recomputeSubLanes { recomputeAllSubLanes() }
    }

    /// Move multiple segments at once (for group drag)
    public func moveSegments(_ moves: [(segment: TimelineSegment, newStart: CGFloat)]) {
        for move in moves {
            moveSegment(id: move.segment.id, newStart: move.newStart, recomputeSubLanes: false)
        }
        recomputeAllSubLanes()
    }

    /// Get the current project (for persistence by parent)
    public func getProject() -> Project? {
        return project
    }

    // MARK: - Soundtrack CRUD

    /// Add a new soundtrack track
    public func addSoundtrack(_ track: SoundtrackTrack) {
        var t = track
        t.sortOrder = soundtrackTracks.count
        soundtrackTracks.append(t)
        onSoundtracksChanged?(soundtrackTracks)
    }

    /// Remove a soundtrack track by ID
    public func removeSoundtrack(id: String) {
        soundtrackTracks.removeAll { $0.id == id }
        for i in soundtrackTracks.indices {
            soundtrackTracks[i].sortOrder = i
        }
        onSoundtracksChanged?(soundtrackTracks)
    }

    /// Move a soundtrack track to a new timeline offset
    public func moveSoundtrack(id: String, newOffset: Double) {
        if let idx = soundtrackTracks.firstIndex(where: { $0.id == id }) {
            soundtrackTracks[idx].startTimeOffset = max(0, newOffset)
            onSoundtracksChanged?(soundtrackTracks)
        }
    }

    /// Toggle mute on a soundtrack track
    public func toggleSoundtrackMute(id: String) {
        if let idx = soundtrackTracks.firstIndex(where: { $0.id == id }) {
            soundtrackTracks[idx].isMuted.toggle()
            onSoundtracksChanged?(soundtrackTracks)
        }
    }

    /// Set volume on a soundtrack track
    public func setSoundtrackVolume(id: String, volume: Double) {
        if let idx = soundtrackTracks.firstIndex(where: { $0.id == id }) {
            soundtrackTracks[idx].volume = max(0, min(1, volume))
            onSoundtracksChanged?(soundtrackTracks)
        }
    }

    /// Select a segment by ID (replaces current selection)
    public func selectSegment(_ id: UUID?) {
        if let id = id {
            selectedSegmentIds = [id]
        } else {
            selectedSegmentIds = []
        }
    }

    /// Toggle a segment in the selection (for Command+click multi-select)
    public func toggleSegmentSelection(_ id: UUID) {
        if selectedSegmentIds.contains(id) {
            selectedSegmentIds.remove(id)
        } else {
            selectedSegmentIds.insert(id)
        }
    }

    /// Set zoom level
    public func setZoom(_ pxPerSec: CGFloat) {
        self.pxPerSec = max(
            TimelineLayoutConstants.minPxPerSec,
            min(TimelineLayoutConstants.maxPxPerSec, pxPerSec)
        )
    }

    /// Zoom by factor (for pinch gesture)
    public func zoomByFactor(_ factor: CGFloat) {
        let newZoom = pxPerSec * factor
        setZoom(newZoom)
    }

    /// Scroll to a specific time
    public func scrollToTime(_ time: CGFloat) {
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let x = originX + time * pxPerSec
        viewportOffset = CGPoint(x: max(0, x - 100), y: viewportOffset.y)
        scrollRequestId = UUID()
    }

    /// Follow the playhead during playback — scrolls only when the playhead
    /// moves past the right edge of the visible area (FCP page-scroll style).
    public func followPlayheadIfNeeded() {
        guard let time = playheadTime, playheadActive else { return }
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let playheadX = originX + time * pxPerSec
        let visibleRight = viewportOffset.x + viewportWidth

        // If playhead is past the right edge, page forward so playhead is near the left
        if playheadX > visibleRight - 20 {
            let newOffset = playheadX - 80  // place playhead 80px from left edge
            viewportOffset = CGPoint(x: max(0, newOffset), y: viewportOffset.y)
            scrollRequestId = UUID()
        }
        // If playhead scrolled back (e.g. skip to previous), bring it into view
        else if playheadX < viewportOffset.x + originX {
            let newOffset = playheadX - 80
            viewportOffset = CGPoint(x: max(0, newOffset), y: viewportOffset.y)
            scrollRequestId = UUID()
        }
    }

    /// Navigate to next marker
    public func navigateToNextMarker() {
        let allTimes = getAllMarkerTimes()
        let currentTime = getCurrentTimeFromViewport()

        if let nextTime = allTimes.first(where: { $0 > currentTime }) {
            scrollToTime(nextTime)
        }
    }

    /// Navigate to previous marker
    public func navigateToPreviousMarker() {
        let allTimes = getAllMarkerTimes()
        let currentTime = getCurrentTimeFromViewport()

        if let prevTime = allTimes.last(where: { $0 < currentTime }) {
            scrollToTime(prevTime)
        }
    }

    // MARK: - Scene Navigation

    /// Navigate to the previous scene in scope
    public func navigateToPreviousScene() {
        guard currentSceneIndex > 0 else { return }
        navigateToScene(at: currentSceneIndex - 1)
    }

    /// Navigate to the next scene in scope
    public func navigateToNextScene() {
        guard currentSceneIndex < allScenesInScope.count - 1 else { return }
        navigateToScene(at: currentSceneIndex + 1)
    }

    /// Navigate to a specific scene by index
    public func navigateToScene(at index: Int) {
        guard index >= 0, index < allScenesInScope.count else { return }
        currentSceneIndex = index

        // Find the scene boundary time for this scene
        if index < sceneBoundaries.count {
            scrollToTime(sceneBoundaries[index].time)
        } else if mode == .scene {
            // For single scene mode, just scroll to start
            scrollToTime(0)
        }
    }

    /// Zoom to fit the current scene/content in the viewport
    public func zoomToFit(viewportWidth: CGFloat) {
        // Calculate content duration
        let contentDuration: CGFloat
        if mode == .scene {
            contentDuration = currentSceneDuration
        } else {
            contentDuration = totalDuration
        }

        guard contentDuration > 0 else { return }

        // Calculate pxPerSec to fit content in viewport
        // Leave some padding (20% of viewport width)
        let availableWidth = viewportWidth * 0.8 - TimelineLayoutConstants.leftMargin - TimelineLayoutConstants.rowLabelWidth
        guard availableWidth > 100 else { return }

        let newPxPerSec = availableWidth / contentDuration

        // Clamp to valid range
        setZoom(newPxPerSec)

        // Scroll to start
        scrollToTime(0)
    }

    /// Toggle visibility for a track type
    public func toggleTrack(_ type: TimelineSegment.ContentType) {
        switch type {
        case .dialogue: showDialogue.toggle()
        case .action: showAction.toggle()
        case .narration: showNarration.toggle()
        case .soundNote: showSoundNote.toggle()
        case .note: break  // Notes always visible
        }
    }

    /// Toggle per-track visibility by track name
    public func toggleTrackVisibility(_ trackName: String) {
        if hiddenTracks.contains(trackName) {
            hiddenTracks.remove(trackName)
        } else {
            hiddenTracks.insert(trackName)
        }
    }

    /// Check if a track is hidden
    public func isTrackHidden(_ trackName: String) -> Bool {
        hiddenTracks.contains(trackName)
    }

    /// Show all tracks (clear hidden set)
    public func showAllTracks() {
        hiddenTracks.removeAll()
    }

    // MARK: - Playhead Methods

    /// Toggle playhead on/off via double-click on ruler
    public func togglePlayhead(at x: CGFloat) {
        if playheadActive {
            // Deactivate
            playheadActive = false
            playheadTime = nil
        } else {
            // Activate at this position
            playheadActive = true
            setPlayheadFromX(x)
        }
    }

    /// Position the playhead from a click/drag on the ruler (FCP-style).
    /// Activates the playhead if not already active, and notifies external
    /// consumers (e.g. PlaybackView) via onPlayheadSeeked.
    public func seekPlayheadFromX(_ x: CGFloat) {
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let time = max(0, (x - originX) / pxPerSec)
        playheadActive = true
        playheadTime = time
        onPlayheadSeeked?(time)
    }

    /// Set the playhead from a pixel X coordinate (programmatic, no seek callback)
    public func setPlayheadFromX(_ x: CGFloat) {
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let time = max(0, (x - originX) / pxPerSec)
        playheadTime = time
    }

    /// Formatted playhead time string (e.g. "00:05.2")
    public var playheadTimeFormatted: String {
        guard let t = playheadTime else { return "--:--.-" }
        let totalSec = Int(t)
        let minutes = totalSec / 60
        let secs = totalSec % 60
        let frac = Int((t - CGFloat(totalSec)) * 10)
        return String(format: "%02d:%02d.%d", minutes, secs, frac)
    }

    // MARK: - User Marker CRUD

    /// Add a user marker at the given time
    public func addUserMarker(at time: CGFloat, label: String = "Marker", icon: String = "flag.fill", color: String = "#FF5F5F") {
        let marker = TimelineMarker(
            time: time,
            label: label,
            kind: .user,
            color: color,
            icon: icon
        )
        userMarkers.append(marker)
        saveMarkers()
    }

    /// Update an existing user marker
    public func updateUserMarker(id: UUID, label: String, icon: String, color: String) {
        if let index = userMarkers.firstIndex(where: { $0.id == id }) {
            userMarkers[index].label = label
            userMarkers[index].icon = icon
            userMarkers[index].color = color
            saveMarkers()
        }
    }

    /// Delete a user marker
    public func deleteUserMarker(id: UUID) {
        userMarkers.removeAll { $0.id == id }
        saveMarkers()
    }

    // MARK: - Marker Persistence

    /// URL for the markers JSON file (sibling to project file)
    private var markersFileURL: URL? {
        guard let projectPath = projectFilePath else { return nil }
        return projectPath.deletingLastPathComponent().appendingPathComponent("markers.json")
    }

    /// Save user markers to disk
    public func saveMarkers() {
        guard let url = markersFileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(userMarkers)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[TimelineViewModel] Failed to save markers: \(error.localizedDescription)")
        }
    }

    /// Load user markers from disk
    public func loadMarkers() {
        guard let url = markersFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            userMarkers = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            userMarkers = try decoder.decode([TimelineMarker].self, from: data)
        } catch {
            print("[TimelineViewModel] Failed to load markers: \(error.localizedDescription)")
            userMarkers = []
        }
    }

    /// Get the time for placing a marker: playhead time or viewport center
    public func getMarkerPlacementTime() -> CGFloat {
        if let t = playheadTime { return t }
        return getCurrentTimeFromViewport()
    }

    // MARK: - Light Cue CRUD

    /// Add a new light cue at the given time
    public func addLightCue(at time: CGFloat, name: String = "New Light Cue", color: String = "#FFD60A", intensity: Double = 1.0, duration: Double = 5.0) {
        let nextNumber = lightCues.count + 1
        let cue = LightCue(
            name: name,
            cueNumber: "Q\(nextNumber)",
            startTime: Double(time),
            duration: duration,
            intensity: intensity,
            color: color,
            markerColor: color
        )
        lightCues.append(cue)
        onLightCuesChanged?(lightCues)
        extendDurationIfNeeded()
    }

    /// Update an existing light cue
    public func updateLightCue(_ cue: LightCue) {
        if let index = lightCues.firstIndex(where: { $0.id == cue.id }) {
            lightCues[index] = cue
            onLightCuesChanged?(lightCues)
            extendDurationIfNeeded()
        }
    }

    /// Remove a light cue by ID
    public func removeLightCue(id: String) {
        lightCues.removeAll { $0.id == id }
        onLightCuesChanged?(lightCues)
    }

    // MARK: - SFX Cue CRUD

    /// Add a new SFX cue at the given time
    public func addSFXCue(at time: CGFloat, name: String = "New SFX Cue", effectType: SFXEffectType = .smoke, intensity: Double = 0.8, duration: Double = 5.0, color: String = "#FF6B35") {
        let nextNumber = sfxCues.count + 1
        let cue = SFXCue(
            name: name,
            cueNumber: "FX\(nextNumber)",
            effectType: effectType,
            startTime: Double(time),
            duration: duration,
            intensity: intensity,
            color: color,
            markerColor: color
        )
        sfxCues.append(cue)
        onSFXCuesChanged?(sfxCues)
        extendDurationIfNeeded()
    }

    /// Update an existing SFX cue
    public func updateSFXCue(_ cue: SFXCue) {
        if let index = sfxCues.firstIndex(where: { $0.id == cue.id }) {
            sfxCues[index] = cue
            onSFXCuesChanged?(sfxCues)
            extendDurationIfNeeded()
        }
    }

    /// Remove an SFX cue by ID
    public func removeSFXCue(id: String) {
        sfxCues.removeAll { $0.id == id }
        onSFXCuesChanged?(sfxCues)
    }

    // MARK: - Support Cue CRUD

    /// Add a new support cue at the given time
    public func addSupportCue(at time: CGFloat, name: String = "New Support Cue", actionType: SupportActionType = .propMove, duration: Double = 5.0, color: String = "#2DD4BF") {
        let nextNumber = supportCues.count + 1
        let cue = SupportCue(
            name: name,
            cueNumber: "S\(nextNumber)",
            actionType: actionType,
            startTime: Double(time),
            duration: duration,
            markerColor: color
        )
        supportCues.append(cue)
        onSupportCuesChanged?(supportCues)
        extendDurationIfNeeded()
    }

    /// Update an existing support cue
    public func updateSupportCue(_ cue: SupportCue) {
        if let index = supportCues.firstIndex(where: { $0.id == cue.id }) {
            supportCues[index] = cue
            onSupportCuesChanged?(supportCues)
            extendDurationIfNeeded()
        }
    }

    /// Remove a support cue by ID
    public func removeSupportCue(id: String) {
        supportCues.removeAll { $0.id == id }
        onSupportCuesChanged?(supportCues)
    }

    // MARK: - Private Methods

    /// Rebuild segments from current scene/sequence/project data
    private func rebuild() {
        // Clear per-track hiding when content changes
        hiddenTracks.removeAll()

        // Build character lookup dictionary for O(1) access
        let characters = project?.characters ?? []
        characterByName = Dictionary(uniqueKeysWithValues: characters.map { ($0.name, $0) })

        // Expose all character names so every character gets a timeline lane
        allCharacterNames = characters.map { $0.name }

        // Clear DurationEstimator plain-text cache to avoid stale data
        DurationEstimator.clearCaches()

        switch mode {
        case .scene:
            rebuildForScene()
        case .sequence:
            rebuildForSequence()
        case .global:
            rebuildForGlobal()
        }
    }

    /// Build segments for a single scene
    private func rebuildForScene() {
        guard let scene = currentScene else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }

        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var t: CGFloat = 0

        // Add scene boundary at start
        sceneBoundaries = [TimelineBoundary(time: 0, name: scene.name)]

        // Collect all items and sort by chronology number
        enum TimelineItem {
            case dialogue(Dialogue)
            case action(Action)
            case narration(Narration)

            var chronologyNumber: Int {
                switch self {
                case .dialogue(let d): return d.chronologyNumber
                case .action(let a): return a.chronologyNumber
                case .narration(let n): return n.chronologyNumber
                }
            }

            var parentDialogueId: String? {
                switch self {
                case .dialogue: return nil
                case .action(let a): return a.parentDialogueId
                case .narration(let n): return n.parentDialogueId
                }
            }
        }

        var allItems: [TimelineItem] = []

        // Add dialogues
        for dialogue in scene.dialogues {
            allItems.append(.dialogue(dialogue))
        }

        // Add independent actions (those without parentDialogueId)
        for action in scene.actions where action.parentDialogueId == nil {
            allItems.append(.action(action))
        }

        // Add independent narrations (those without parentDialogueId)
        for narration in scene.narrations where narration.parentDialogueId == nil {
            allItems.append(.narration(narration))
        }

        // Sort all items by chronology number
        allItems.sort { $0.chronologyNumber < $1.chronologyNumber }

        // Build dialogue timing map as we process (for connected items later)
        var dialogueTiming: [String: (start: CGFloat, duration: CGFloat, character: String)] = [:]

        // Process items in chronology order
        for item in allItems {
            switch item {
            case .dialogue(let dialogue):
                let duration = DurationEstimator.getEffectiveDuration(
                    manualDuration: dialogue.manualDuration,
                    text: dialogue.text,
                    wpm: wpm
                )

                dialogueTiming[dialogue.id] = (start: t, duration: duration, character: dialogue.character)

                let characterColor = getCharacterColor(dialogue.character)
                let characterTextColor = getCharacterTextColor(dialogue.character)

                newSegments.append(TimelineSegment(
                    start: t,
                    duration: duration,
                    character: dialogue.character,
                    color: characterColor,
                    textColor: characterTextColor,
                    text: dialogue.text,
                    sceneName: scene.name,
                    contentType: .dialogue,
                    chronologyNumber: dialogue.chronologyNumber,
                    avatarPath: getCharacterAvatar(dialogue.character),
                    propsCount: 0,
                    hasAudio: dialogue.audioFilePath != nil,
                    sourceItemId: dialogue.id
                ))

                t += duration

            case .action(let action):
                let actionDuration = TimelineWPMConstants.actionDuration

                newSegments.append(TimelineSegment(
                    start: t,
                    duration: actionDuration,
                    character: "Action",
                    color: TimelineDefaultColors.actionBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: action.description,
                    sceneName: scene.name,
                    contentType: .action,
                    chronologyNumber: action.chronologyNumber,
                    propsCount: action.effects.count,
                    sourceItemId: action.id
                ))

                t += actionDuration

            case .narration(let narration):
                let estimatedDuration = DurationEstimator.estimateDialogueDuration(
                    text: narration.text,
                    wpm: wpm
                )
                let narrationDuration = max(TimelineWPMConstants.actionDuration, estimatedDuration)

                newSegments.append(TimelineSegment(
                    start: t,
                    duration: narrationDuration,
                    character: "Narration",
                    color: TimelineDefaultColors.narrationBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: narration.text,
                    sceneName: scene.name,
                    contentType: .narration,
                    chronologyNumber: narration.chronologyNumber,
                    sourceItemId: narration.id
                ))

                t += narrationDuration
            }
        }

        // Process connected actions (those with parentDialogueId) - they share parent timing
        for action in scene.actions {
            if let parentId = action.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                newSegments.append(TimelineSegment(
                    start: parentTiming.start,
                    duration: parentTiming.duration,
                    character: "Action",
                    color: TimelineDefaultColors.actionBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: action.description,
                    sceneName: scene.name,
                    contentType: .action,
                    chronologyNumber: action.chronologyNumber,
                    avatarPath: getCharacterAvatar(parentTiming.character),
                    propsCount: action.effects.count,
                    sourceItemId: action.id,
                    parentCharacterName: parentTiming.character
                ))
            }
        }

        // Process connected narrations (those with parentDialogueId) - they share parent timing
        for narration in scene.narrations {
            if let parentId = narration.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                newSegments.append(TimelineSegment(
                    start: parentTiming.start,
                    duration: parentTiming.duration,
                    character: "Narration",
                    color: TimelineDefaultColors.narrationBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: narration.text,
                    sceneName: scene.name,
                    contentType: .narration,
                    chronologyNumber: narration.chronologyNumber,
                    avatarPath: getCharacterAvatar(parentTiming.character),
                    sourceItemId: narration.id,
                    parentCharacterName: parentTiming.character
                ))
            }
        }

        // Process notes as markers - connected ones use parent dialogue timing
        for note in scene.sceneNotes {
            let noteTime: CGFloat
            if let parentId = note.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                noteTime = parentTiming.start
            } else {
                noteTime = t
            }

            newMarkers.append(TimelineMarker(
                time: noteTime,
                label: "Note: \(note.title)",
                kind: .note,
                color: TimelineDefaultColors.noteMarker
            ))
        }

        // Process SoundNotes - connected ones use parent dialogue timing, independent ones use chronology
        for soundNote in scene.soundNotes {
            let soundStart: CGFloat
            let soundDuration: CGFloat

            // Determine start time
            if let parentId = soundNote.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                // Connected to a dialogue - use parent timing
                soundStart = parentTiming.start
                soundDuration = parentTiming.duration
            } else if let startTime = soundNote.startTime, let endTime = soundNote.endTime {
                // Has explicit timing
                soundStart = CGFloat(startTime)
                soundDuration = CGFloat(endTime - startTime)
            } else {
                // Independent - position at current time
                soundStart = t
                soundDuration = TimelineWPMConstants.soundNoteDuration
            }

            // Determine icon based on sound type
            let icon: String
            switch soundNote.soundType {
            case "music": icon = "music.note"
            case "effects", "dialogue_sfx": icon = "speaker.wave.2"
            default: icon = "speaker.wave.2"  // ambient default
            }

            newSegments.append(TimelineSegment(
                start: soundStart,
                duration: soundDuration,
                character: "Sound",
                color: TimelineDefaultColors.soundNoteBubble,
                textColor: TimelineDefaultColors.defaultText,
                text: "\(icon) \(soundNote.description)",
                sceneName: scene.name,
                contentType: .soundNote,
                chronologyNumber: soundNote.chronologyNumber,
                sourceItemId: soundNote.uuid
            ))
        }

        // Build shot labels for the shots lane (no markers)
        var newShotLabels: [TimelineShotLabel] = []
        let totalDur = max(t, TimelineWPMConstants.minSceneDuration)
        let shotCount = scene.shots.count

        for (index, shot) in scene.shots.enumerated() {
            // Find the earliest and latest linked dialogue times for duration span
            var earliestStart: CGFloat = .infinity
            var latestEnd: CGFloat = 0
            var foundTime = false

            for dialogueId in shot.linkedDialogueIds {
                if let timing = dialogueTiming[dialogueId] {
                    earliestStart = min(earliestStart, timing.start)
                    latestEnd = max(latestEnd, timing.start + timing.duration)
                    foundTime = true
                }
            }

            let shotTime: CGFloat
            let shotDuration: CGFloat

            if foundTime {
                shotTime = earliestStart
                shotDuration = latestEnd - earliestStart
            } else if shotCount > 0 {
                // Fallback: spread shots evenly across timeline
                shotTime = totalDur * CGFloat(index) / CGFloat(max(shotCount, 1))
                shotDuration = shot.duration.map { CGFloat($0) } ?? 0
            } else {
                shotTime = 0
                shotDuration = shot.duration.map { CGFloat($0) } ?? 0
            }

            newShotLabels.append(TimelineShotLabel(
                time: shotTime,
                duration: shotDuration,
                shotName: "Shot \(shot.shotId)",
                shotId: shot.shotId,
                sceneName: scene.name,
                linkedDialogueIds: shot.linkedDialogueIds,
                shotType: shot.shotType,
                cameraAngle: shot.cameraAngle,
                lensMm: shot.lensMm,
                movement: shot.movement,
                previewImagePath: shot.previewImage,
                hasVideo: shot.videoPath != nil && !(shot.videoPath?.isEmpty ?? true)
            ))
        }

        // Sort shot labels by time, then by shotId for stable ordering
        newShotLabels.sort {
            if $0.time != $1.time {
                return $0.time < $1.time
            }
            return $0.shotId < $1.shotId
        }

        segments = newSegments
        markers = newMarkers
        shotLabels = newShotLabels
        sequenceBoundaries = []

        // Apply manual position overrides from saved project data
        applyManualPositionOverrides()

        // Compute sub-lane layout for overlapping bubbles
        recomputeAllSubLanes()

        // Update scenes in scope and duration
        allScenesInScope = [scene]
        currentSceneIndex = 0
        // Extend duration if any cue bubbles exceed the last dialogue
        let cueMax = maxCueEndTime()
        if cueMax > t { t = cueMax }
        currentSceneDuration = t
        totalDuration = t
    }

    /// Build segments for a sequence (all scenes)
    private func rebuildForSequence() {
        guard let sequence = currentSequence else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }

        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var newSceneBoundaries: [TimelineBoundary] = []
        var newShotLabels: [TimelineShotLabel] = []
        var t: CGFloat = 0

        sequenceBoundaries = [TimelineBoundary(time: 0, name: sequence.name)]

        for scene in sequence.scenes {
            // Add scene boundary
            newSceneBoundaries.append(TimelineBoundary(time: t, name: scene.name))

            // Build dialogue timing map for this scene
            var dialogueTiming: [String: (start: CGFloat, duration: CGFloat, character: String)] = [:]

            // Collect all independent items and sort by chronology number
            enum TimelineItem {
                case dialogue(Dialogue)
                case action(Action)
                case narration(Narration)

                var chronologyNumber: Int {
                    switch self {
                    case .dialogue(let d): return d.chronologyNumber
                    case .action(let a): return a.chronologyNumber
                    case .narration(let n): return n.chronologyNumber
                    }
                }
            }

            var allItems: [TimelineItem] = []

            for dialogue in scene.dialogues {
                allItems.append(.dialogue(dialogue))
            }
            for action in scene.actions where action.parentDialogueId == nil {
                allItems.append(.action(action))
            }
            for narration in scene.narrations where narration.parentDialogueId == nil {
                allItems.append(.narration(narration))
            }

            allItems.sort { $0.chronologyNumber < $1.chronologyNumber }

            // Process items in chronology order
            for item in allItems {
                switch item {
                case .dialogue(let dialogue):
                    let duration = DurationEstimator.getEffectiveDuration(
                        manualDuration: dialogue.manualDuration,
                        text: dialogue.text,
                        wpm: wpm
                    )

                    dialogueTiming[dialogue.id] = (start: t, duration: duration, character: dialogue.character)

                    let characterColor = getCharacterColor(dialogue.character)
                    let characterTextColor = getCharacterTextColor(dialogue.character)

                    newSegments.append(TimelineSegment(
                        start: t,
                        duration: duration,
                        character: dialogue.character,
                        color: characterColor,
                        textColor: characterTextColor,
                        text: dialogue.text,
                        sceneName: scene.name,
                        contentType: .dialogue,
                        chronologyNumber: dialogue.chronologyNumber,
                        avatarPath: getCharacterAvatar(dialogue.character),
                        propsCount: 0,
                        hasAudio: dialogue.audioFilePath != nil,
                        sourceItemId: dialogue.id
                    ))

                    t += duration

                case .action(let action):
                    let actionDuration = TimelineWPMConstants.actionDuration

                    newSegments.append(TimelineSegment(
                        start: t,
                        duration: actionDuration,
                        character: "Action",
                        color: TimelineDefaultColors.actionBubble,
                        textColor: TimelineDefaultColors.defaultText,
                        text: action.description,
                        sceneName: scene.name,
                        contentType: .action,
                        chronologyNumber: action.chronologyNumber,
                        propsCount: action.effects.count,
                        sourceItemId: action.id
                    ))

                    t += actionDuration

                case .narration(let narration):
                    let estimatedDuration = max(
                        TimelineWPMConstants.actionDuration,
                        DurationEstimator.estimateDialogueDuration(text: narration.text, wpm: wpm)
                    )

                    newSegments.append(TimelineSegment(
                        start: t,
                        duration: estimatedDuration,
                        character: "Narration",
                        color: TimelineDefaultColors.narrationBubble,
                        textColor: TimelineDefaultColors.defaultText,
                        text: narration.text,
                        sceneName: scene.name,
                        contentType: .narration,
                        chronologyNumber: narration.chronologyNumber,
                        sourceItemId: narration.id
                    ))

                    t += estimatedDuration
                }
            }

            // Process connected actions (those with parentDialogueId)
            for action in scene.actions {
                if let parentId = action.parentDialogueId,
                   let parentTiming = dialogueTiming[parentId] {
                    newSegments.append(TimelineSegment(
                        start: parentTiming.start,
                        duration: parentTiming.duration,
                        character: "Action",
                        color: TimelineDefaultColors.actionBubble,
                        textColor: TimelineDefaultColors.defaultText,
                        text: action.description,
                        sceneName: scene.name,
                        contentType: .action,
                        chronologyNumber: action.chronologyNumber,
                        avatarPath: getCharacterAvatar(parentTiming.character),
                        propsCount: action.effects.count,
                        sourceItemId: action.id,
                        parentCharacterName: parentTiming.character
                    ))
                }
            }

            // Process connected narrations (those with parentDialogueId)
            for narration in scene.narrations {
                if let parentId = narration.parentDialogueId,
                   let parentTiming = dialogueTiming[parentId] {
                    newSegments.append(TimelineSegment(
                        start: parentTiming.start,
                        duration: parentTiming.duration,
                        character: "Narration",
                        color: TimelineDefaultColors.narrationBubble,
                        textColor: TimelineDefaultColors.defaultText,
                        text: narration.text,
                        sceneName: scene.name,
                        contentType: .narration,
                        chronologyNumber: narration.chronologyNumber,
                        avatarPath: getCharacterAvatar(parentTiming.character),
                        sourceItemId: narration.id,
                        parentCharacterName: parentTiming.character
                    ))
                }
            }

            // Process notes as markers - connected ones use parent dialogue timing
            for note in scene.sceneNotes {
                let noteTime: CGFloat
                if let parentId = note.parentDialogueId,
                   let parentTiming = dialogueTiming[parentId] {
                    noteTime = parentTiming.start
                } else {
                    noteTime = t
                }

                newMarkers.append(TimelineMarker(
                    time: noteTime,
                    label: "Note: \(note.title)",
                    kind: .note,
                    color: TimelineDefaultColors.noteMarker
                ))
            }

            // Process SoundNotes for this scene
            for soundNote in scene.soundNotes {
                let soundStart: CGFloat
                let soundDuration: CGFloat

                if let parentId = soundNote.parentDialogueId,
                   let parentTiming = dialogueTiming[parentId] {
                    soundStart = parentTiming.start
                    soundDuration = parentTiming.duration
                } else if let startTime = soundNote.startTime, let endTime = soundNote.endTime {
                    soundStart = CGFloat(startTime)
                    soundDuration = CGFloat(endTime - startTime)
                } else {
                    soundStart = t
                    soundDuration = TimelineWPMConstants.soundNoteDuration
                }

                let icon: String
                switch soundNote.soundType {
                case "music": icon = "music.note"
                case "effects", "dialogue_sfx": icon = "speaker.wave.2"
                default: icon = "speaker.wave.2"
                }

                newSegments.append(TimelineSegment(
                    start: soundStart,
                    duration: soundDuration,
                    character: "Sound",
                    color: TimelineDefaultColors.soundNoteBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: "\(icon) \(soundNote.description)",
                    sceneName: scene.name,
                    contentType: .soundNote,
                    chronologyNumber: soundNote.chronologyNumber,
                    sourceItemId: soundNote.uuid
                ))
            }

            // Process shots as labels for the shots lane (no markers)
            let sceneStartTime = newSceneBoundaries.last?.time ?? 0
            let sceneShotCount = scene.shots.count

            for (index, shot) in scene.shots.enumerated() {
                var earliestStart: CGFloat = .infinity
                var latestEnd: CGFloat = 0
                var foundTime = false

                for dialogueId in shot.linkedDialogueIds {
                    if let timing = dialogueTiming[dialogueId] {
                        earliestStart = min(earliestStart, timing.start)
                        latestEnd = max(latestEnd, timing.start + timing.duration)
                        foundTime = true
                    }
                }

                let shotTime: CGFloat
                let shotDuration: CGFloat

                if foundTime {
                    shotTime = earliestStart
                    shotDuration = latestEnd - earliestStart
                } else if sceneShotCount > 0 {
                    let sceneDuration = max(t - sceneStartTime, TimelineWPMConstants.minSceneDuration)
                    shotTime = sceneStartTime + sceneDuration * CGFloat(index) / CGFloat(max(sceneShotCount, 1))
                    shotDuration = shot.duration.map { CGFloat($0) } ?? 0
                } else {
                    shotTime = sceneStartTime
                    shotDuration = shot.duration.map { CGFloat($0) } ?? 0
                }

                newShotLabels.append(TimelineShotLabel(
                    time: shotTime,
                    duration: shotDuration,
                    shotName: "Shot \(shot.shotId)",
                    shotId: shot.shotId,
                    sceneName: scene.name,
                    linkedDialogueIds: shot.linkedDialogueIds,
                    shotType: shot.shotType,
                    cameraAngle: shot.cameraAngle,
                    lensMm: shot.lensMm,
                    movement: shot.movement,
                    previewImagePath: shot.previewImage,
                    hasVideo: shot.videoPath != nil && !(shot.videoPath?.isEmpty ?? true)
                ))
            }

            // Ensure minimum scene duration
            if scene.dialogues.isEmpty && scene.actions.isEmpty && scene.narrations.isEmpty {
                t += TimelineWPMConstants.minSceneDuration
            }
        }

        // Sort shot labels by time, then by shotId for stable ordering
        newShotLabels.sort {
            if $0.time != $1.time {
                return $0.time < $1.time
            }
            return $0.shotId < $1.shotId
        }

        segments = newSegments
        markers = newMarkers
        sceneBoundaries = newSceneBoundaries
        shotLabels = newShotLabels

        // Apply manual position overrides from saved project data
        applyManualPositionOverrides()

        // Compute sub-lane layout for overlapping bubbles
        recomputeAllSubLanes()

        // Update scenes in scope and duration
        allScenesInScope = sequence.scenes
        currentSceneIndex = 0
        // Extend duration if any cue bubbles exceed the last dialogue
        let cueMax = maxCueEndTime()
        if cueMax > t { t = cueMax }
        totalDuration = t
        currentSceneDuration = t  // In sequence mode, show total duration
    }

    /// Build segments for global view (all sequences and scenes)
    private func rebuildForGlobal() {
        guard let project = project else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }

        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var newSceneBoundaries: [TimelineBoundary] = []
        var newSequenceBoundaries: [TimelineBoundary] = []
        var newShotLabels: [TimelineShotLabel] = []
        var t: CGFloat = 0

        for sequence in project.sequences {
            // Add sequence boundary
            newSequenceBoundaries.append(TimelineBoundary(time: t, name: sequence.name))

            for scene in sequence.scenes {
                // Add scene boundary
                newSceneBoundaries.append(TimelineBoundary(time: t, name: scene.name))

                // Build dialogue timing map for this scene
                var dialogueTiming: [String: (start: CGFloat, duration: CGFloat, character: String)] = [:]

                // Collect all independent items and sort by chronology number
                enum TimelineItem {
                    case dialogue(Dialogue)
                    case action(Action)
                    case narration(Narration)

                    var chronologyNumber: Int {
                        switch self {
                        case .dialogue(let d): return d.chronologyNumber
                        case .action(let a): return a.chronologyNumber
                        case .narration(let n): return n.chronologyNumber
                        }
                    }
                }

                var allItems: [TimelineItem] = []

                for dialogue in scene.dialogues {
                    allItems.append(.dialogue(dialogue))
                }
                for action in scene.actions where action.parentDialogueId == nil {
                    allItems.append(.action(action))
                }
                for narration in scene.narrations where narration.parentDialogueId == nil {
                    allItems.append(.narration(narration))
                }

                allItems.sort { $0.chronologyNumber < $1.chronologyNumber }

                // Process items in chronology order
                for item in allItems {
                    switch item {
                    case .dialogue(let dialogue):
                        let duration = DurationEstimator.getEffectiveDuration(
                            manualDuration: dialogue.manualDuration,
                            text: dialogue.text,
                            wpm: wpm
                        )

                        dialogueTiming[dialogue.id] = (start: t, duration: duration, character: dialogue.character)

                        let characterColor = getCharacterColor(dialogue.character)
                        let characterTextColor = getCharacterTextColor(dialogue.character)

                        newSegments.append(TimelineSegment(
                            start: t,
                            duration: duration,
                            character: dialogue.character,
                            color: characterColor,
                            textColor: characterTextColor,
                            text: dialogue.text,
                            sceneName: scene.name,
                            contentType: .dialogue,
                            chronologyNumber: dialogue.chronologyNumber,
                            avatarPath: getCharacterAvatar(dialogue.character),
                            propsCount: 0,
                            hasAudio: dialogue.audioFilePath != nil,
                            sourceItemId: dialogue.id
                        ))

                        t += duration

                    case .action(let action):
                        let actionDuration = TimelineWPMConstants.actionDuration

                        newSegments.append(TimelineSegment(
                            start: t,
                            duration: actionDuration,
                            character: "Action",
                            color: TimelineDefaultColors.actionBubble,
                            textColor: TimelineDefaultColors.defaultText,
                            text: action.description,
                            sceneName: scene.name,
                            contentType: .action,
                            chronologyNumber: action.chronologyNumber,
                            propsCount: action.effects.count,
                            sourceItemId: action.id
                        ))

                        t += actionDuration

                    case .narration(let narration):
                        let estimatedDuration = max(
                            TimelineWPMConstants.actionDuration,
                            DurationEstimator.estimateDialogueDuration(text: narration.text, wpm: wpm)
                        )

                        newSegments.append(TimelineSegment(
                            start: t,
                            duration: estimatedDuration,
                            character: "Narration",
                            color: TimelineDefaultColors.narrationBubble,
                            textColor: TimelineDefaultColors.defaultText,
                            text: narration.text,
                            sceneName: scene.name,
                            contentType: .narration,
                            chronologyNumber: narration.chronologyNumber,
                            sourceItemId: narration.id
                        ))

                        t += estimatedDuration
                    }
                }

                // Process connected actions (those with parentDialogueId)
                for action in scene.actions {
                    if let parentId = action.parentDialogueId,
                       let parentTiming = dialogueTiming[parentId] {
                        newSegments.append(TimelineSegment(
                            start: parentTiming.start,
                            duration: parentTiming.duration,
                            character: "Action",
                            color: TimelineDefaultColors.actionBubble,
                            textColor: TimelineDefaultColors.defaultText,
                            text: action.description,
                            sceneName: scene.name,
                            contentType: .action,
                            chronologyNumber: action.chronologyNumber,
                            avatarPath: getCharacterAvatar(parentTiming.character),
                            propsCount: action.effects.count,
                            sourceItemId: action.id,
                            parentCharacterName: parentTiming.character
                        ))
                    }
                }

                // Process connected narrations (those with parentDialogueId)
                for narration in scene.narrations {
                    if let parentId = narration.parentDialogueId,
                       let parentTiming = dialogueTiming[parentId] {
                        newSegments.append(TimelineSegment(
                            start: parentTiming.start,
                            duration: parentTiming.duration,
                            character: "Narration",
                            color: TimelineDefaultColors.narrationBubble,
                            textColor: TimelineDefaultColors.defaultText,
                            text: narration.text,
                            sceneName: scene.name,
                            contentType: .narration,
                            chronologyNumber: narration.chronologyNumber,
                            avatarPath: getCharacterAvatar(parentTiming.character),
                            sourceItemId: narration.id,
                            parentCharacterName: parentTiming.character
                        ))
                    }
                }

                // Process notes as markers - connected ones use parent dialogue timing
                for note in scene.sceneNotes {
                    let noteTime: CGFloat
                    if let parentId = note.parentDialogueId,
                       let parentTiming = dialogueTiming[parentId] {
                        noteTime = parentTiming.start
                    } else {
                        noteTime = t
                    }

                    newMarkers.append(TimelineMarker(
                        time: noteTime,
                        label: "Note: \(note.title)",
                        kind: .note,
                        color: TimelineDefaultColors.noteMarker
                    ))
                }

                // Process SoundNotes for this scene
                for soundNote in scene.soundNotes {
                    let soundStart: CGFloat
                    let soundDuration: CGFloat

                    if let parentId = soundNote.parentDialogueId,
                       let parentTiming = dialogueTiming[parentId] {
                        soundStart = parentTiming.start
                        soundDuration = parentTiming.duration
                    } else if let startTime = soundNote.startTime, let endTime = soundNote.endTime {
                        soundStart = CGFloat(startTime)
                        soundDuration = CGFloat(endTime - startTime)
                    } else {
                        soundStart = t
                        soundDuration = TimelineWPMConstants.soundNoteDuration
                    }

                    let icon: String
                    switch soundNote.soundType {
                    case "music": icon = "music.note"
                    case "effects", "dialogue_sfx": icon = "speaker.wave.2"
                    default: icon = "speaker.wave.2"
                    }

                    newSegments.append(TimelineSegment(
                        start: soundStart,
                        duration: soundDuration,
                        character: "Sound",
                        color: TimelineDefaultColors.soundNoteBubble,
                        textColor: TimelineDefaultColors.defaultText,
                        text: "\(icon) \(soundNote.description)",
                        sceneName: scene.name,
                        contentType: .soundNote,
                        chronologyNumber: soundNote.chronologyNumber,
                        sourceItemId: soundNote.uuid
                    ))
                }

                // Process shots as labels for the shots lane (no markers)
                let sceneStartTime = newSceneBoundaries.last?.time ?? 0
                let sceneShotCount = scene.shots.count

                for (index, shot) in scene.shots.enumerated() {
                    var earliestStart: CGFloat = .infinity
                    var latestEnd: CGFloat = 0
                    var foundTime = false

                    for dialogueId in shot.linkedDialogueIds {
                        if let timing = dialogueTiming[dialogueId] {
                            earliestStart = min(earliestStart, timing.start)
                            latestEnd = max(latestEnd, timing.start + timing.duration)
                            foundTime = true
                        }
                    }

                    let shotTime: CGFloat
                    let shotDuration: CGFloat

                    if foundTime {
                        shotTime = earliestStart
                        shotDuration = latestEnd - earliestStart
                    } else if sceneShotCount > 0 {
                        let sceneDuration = max(t - sceneStartTime, TimelineWPMConstants.minSceneDuration)
                        shotTime = sceneStartTime + sceneDuration * CGFloat(index) / CGFloat(max(sceneShotCount, 1))
                        shotDuration = shot.duration.map { CGFloat($0) } ?? 0
                    } else {
                        shotTime = sceneStartTime
                        shotDuration = shot.duration.map { CGFloat($0) } ?? 0
                    }

                    newShotLabels.append(TimelineShotLabel(
                        time: shotTime,
                        duration: shotDuration,
                        shotName: "Shot \(shot.shotId)",
                        shotId: shot.shotId,
                        sceneName: scene.name,
                        linkedDialogueIds: shot.linkedDialogueIds,
                        shotType: shot.shotType,
                        cameraAngle: shot.cameraAngle,
                        lensMm: shot.lensMm,
                        movement: shot.movement,
                        previewImagePath: shot.previewImage,
                        hasVideo: shot.videoPath != nil && !(shot.videoPath?.isEmpty ?? true)
                    ))
                }

                // Ensure minimum scene duration
                if scene.dialogues.isEmpty && scene.actions.isEmpty && scene.narrations.isEmpty {
                    t += TimelineWPMConstants.minSceneDuration
                }
            }
        }

        // Collect all scenes across all sequences
        var allScenes: [DCScene] = []
        for sequence in project.sequences {
            allScenes.append(contentsOf: sequence.scenes)
        }

        // Sort shot labels by time, then by shotId for stable ordering
        newShotLabels.sort {
            if $0.time != $1.time {
                return $0.time < $1.time
            }
            return $0.shotId < $1.shotId
        }

        segments = newSegments
        markers = newMarkers
        sceneBoundaries = newSceneBoundaries
        sequenceBoundaries = newSequenceBoundaries
        shotLabels = newShotLabels

        // Apply manual position overrides from saved project data
        applyManualPositionOverrides()

        // Compute sub-lane layout for overlapping bubbles
        recomputeAllSubLanes()

        // Update scenes in scope and duration
        allScenesInScope = allScenes
        currentSceneIndex = 0
        // Extend duration if any cue bubbles exceed the last dialogue
        let cueMax = maxCueEndTime()
        if cueMax > t { t = cueMax }
        totalDuration = t
        currentSceneDuration = t  // In global mode, show total duration
    }

    // MARK: - Cue Duration Extension

    /// Returns the maximum end time across all cue lanes (light, SFX, support) + soundtrack tracks.
    private func maxCueEndTime() -> CGFloat {
        let lightMax = lightCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let sfxMax = sfxCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let supportMax = supportCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let soundtrackMax = soundtrackTracks.map { CGFloat($0.startTimeOffset + $0.duration) }.max() ?? 0
        return max(lightMax, sfxMax, supportMax, soundtrackMax)
    }

    /// Extends totalDuration if any cue bubble extends beyond the current timeline length.
    public func extendDurationIfNeeded() {
        let cueMax = maxCueEndTime()
        if cueMax > totalDuration {
            totalDuration = cueMax
            currentSceneDuration = cueMax
        }
    }

    // MARK: - Manual Position Overrides

    /// Apply manual start time overrides from the project model to computed segments and shot labels.
    /// Called after each rebuild to honor user-dragged positions.
    private func applyManualPositionOverrides() {
        guard let project = project else { return }

        // Build a lookup of sourceItemId → manualStartTime from all scenes
        var manualStartTimes: [String: Double] = [:]
        var shotPositions: [Int: (sceneName: String, position: Double)] = [:]

        for sequence in project.sequences {
            for scene in sequence.scenes {
                for dialogue in scene.dialogues {
                    if let manual = dialogue.manualStartTime {
                        manualStartTimes[dialogue.id] = manual
                    }
                }
                for action in scene.actions {
                    if let manual = action.manualStartTime {
                        manualStartTimes[action.id] = manual
                    }
                }
                for narration in scene.narrations {
                    if let manual = narration.manualStartTime {
                        manualStartTimes[narration.id] = manual
                    }
                }
                for soundNote in scene.soundNotes {
                    if let manual = soundNote.manualStartTime {
                        manualStartTimes[soundNote.uuid] = manual
                    }
                }
                for shot in scene.shots {
                    if let pos = shot.timelinePosition {
                        shotPositions[shot.shotId] = (sceneName: scene.name, position: pos)
                    }
                }
            }
        }

        // Apply segment overrides
        for i in segments.indices {
            if let sourceId = segments[i].sourceItemId,
               let manualTime = manualStartTimes[sourceId] {
                segments[i].start = CGFloat(manualTime)
            }
        }

        // Apply shot label overrides
        for i in shotLabels.indices {
            if let info = shotPositions[shotLabels[i].shotId],
               info.sceneName == shotLabels[i].sceneName {
                shotLabels[i].time = CGFloat(info.position)
            }
        }

        // Re-sort shot labels after overrides
        shotLabels.sort {
            if $0.time != $1.time { return $0.time < $1.time }
            return $0.shotId < $1.shotId
        }
    }

    // MARK: - Sub-Lane Computation

    /// Recompute all sub-lane layouts (segments + shots) and connections.
    /// All results are computed into local vars first, then assigned in a single batch
    /// to coalesce @Published updates into fewer SwiftUI redraw passes.
    private func recomputeAllSubLanes() {
        let (segAssign, segCounts) = computeSubLanesResult()
        let (shotAssign, shotCount) = computeShotSubLanesResult()
        let connections = computeShotDialogueConnectionsResult()

        subLaneAssignments = segAssign
        laneSubLaneCounts = segCounts
        shotSubLaneAssignments = shotAssign
        shotLaneSubLaneCount = shotCount
        shotDialogueConnections = connections
    }

    /// Compute sub-lane assignments using greedy interval partitioning.
    /// Returns results without assigning to @Published properties.
    private func computeSubLanesResult() -> (assignments: [UUID: Int], counts: [String: Int]) {
        let visible = visibleSegments
        let grouped = Dictionary(grouping: visible) { $0.character }

        var newAssignments: [UUID: Int] = [:]
        var newCounts: [String: Int] = [:]

        for (character, charSegments) in grouped {
            var intervals: [(segment: TimelineSegment, start: CGFloat, end: CGFloat)] = []
            for seg in charSegments {
                let rx = seg.start * pxPerSec
                let w = DurationEstimator.bubbleWidth(for: seg, pxPerSec: pxPerSec, showThumbs: showThumbs)
                intervals.append((seg, rx, rx + w))
            }
            intervals.sort { $0.start < $1.start }

            var subLaneEnds: [CGFloat] = []

            for interval in intervals {
                var placed = false
                for lane in 0..<subLaneEnds.count {
                    if subLaneEnds[lane] <= interval.start {
                        subLaneEnds[lane] = interval.end
                        newAssignments[interval.segment.id] = lane
                        placed = true
                        break
                    }
                }
                if !placed {
                    newAssignments[interval.segment.id] = subLaneEnds.count
                    subLaneEnds.append(interval.end)
                }
            }

            newCounts[character] = max(1, subLaneEnds.count)
        }

        return (newAssignments, newCounts)
    }

    /// Compute sub-lane assignments for shot labels using greedy interval partitioning.
    /// Returns results without assigning to @Published properties.
    private func computeShotSubLanesResult() -> (assignments: [UUID: Int], count: Int) {
        guard !shotLabels.isEmpty else {
            return ([:], 1)
        }

        var intervals: [(label: TimelineShotLabel, start: CGFloat, end: CGFloat)] = []
        for label in shotLabels {
            let rx = label.time * pxPerSec
            let w = label.displayWidth(pxPerSec: pxPerSec)
            intervals.append((label, rx, rx + w))
        }
        intervals.sort { $0.start < $1.start }

        var newAssignments: [UUID: Int] = [:]
        var subLaneEnds: [CGFloat] = []

        for interval in intervals {
            var placed = false
            for lane in 0..<subLaneEnds.count {
                if subLaneEnds[lane] <= interval.start {
                    subLaneEnds[lane] = interval.end
                    newAssignments[interval.label.id] = lane
                    placed = true
                    break
                }
            }
            if !placed {
                newAssignments[interval.label.id] = subLaneEnds.count
                subLaneEnds.append(interval.end)
            }
        }

        return (newAssignments, max(1, subLaneEnds.count))
    }

    /// Compute shot-dialogue connections from shot labels and segments.
    /// Returns results without assigning to @Published properties.
    private func computeShotDialogueConnectionsResult() -> [ShotDialogueConnection] {
        var dialogueSourceToSegment: [String: UUID] = [:]
        for segment in segments where segment.contentType == .dialogue {
            if let sourceId = segment.sourceItemId {
                dialogueSourceToSegment[sourceId] = segment.id
            }
        }

        var connections: [ShotDialogueConnection] = []
        for shotLabel in shotLabels {
            for dialogueId in shotLabel.linkedDialogueIds {
                if let segmentId = dialogueSourceToSegment[dialogueId] {
                    connections.append(ShotDialogueConnection(
                        shotLabelId: shotLabel.id,
                        shotTime: shotLabel.time,
                        dialogueSegmentId: segmentId,
                        color: TimelineDefaultColors.colorForShotType(shotLabel.shotType)
                    ))
                }
            }
        }

        return connections
    }

    /// Legacy convenience methods for callers that need individual recomputation
    private func computeSubLanes() {
        let (assign, counts) = computeSubLanesResult()
        subLaneAssignments = assign
        laneSubLaneCounts = counts
    }

    private func computeShotSubLanes() {
        let (assign, count) = computeShotSubLanesResult()
        shotSubLaneAssignments = assign
        shotLaneSubLaneCount = count
    }

    private func computeShotDialogueConnections() {
        shotDialogueConnections = computeShotDialogueConnectionsResult()
    }

    // MARK: - Helper Methods

    /// Get character color from project
    private func getCharacterColor(_ name: String) -> String {
        guard let character = characterByName[name] else {
            return TimelineDefaultColors.bubbleDefault
        }
        return character.color
    }

    /// Get character text color from project
    private func getCharacterTextColor(_ name: String) -> String {
        guard let character = characterByName[name] else {
            return TimelineDefaultColors.defaultText
        }
        return character.textColor
    }

    /// Get character avatar path from project
    /// Priority: avatar > baseImage > imageFront
    private func getCharacterAvatar(_ name: String) -> String? {
        guard let character = characterByName[name] else {
            return nil
        }

        // Priority 1: Legacy avatar
        if let avatar = character.avatar, !avatar.isEmpty {
            return avatar
        }

        // Priority 2: Base image (AI-generated)
        if let baseImage = character.baseImage, !baseImage.isEmpty {
            return baseImage
        }

        // Priority 3: Front image
        if let imageFront = character.imageFront, !imageFront.isEmpty {
            return imageFront
        }

        return nil
    }

    /// Get all marker times (for navigation)
    private func getAllMarkerTimes() -> [CGFloat] {
        var times: [CGFloat] = []

        // Add scene boundaries
        times.append(contentsOf: sceneBoundaries.map { $0.time })

        // Add sequence boundaries
        times.append(contentsOf: sequenceBoundaries.map { $0.time })

        // Add auto-generated markers (notes, etc.)
        times.append(contentsOf: markers.map { $0.time })

        // Add user-created markers
        times.append(contentsOf: userMarkers.map { $0.time })

        return times.sorted()
    }

    /// Get current time from viewport position
    private func getCurrentTimeFromViewport() -> CGFloat {
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let scrollX = viewportOffset.x + 100
        return max(0, (scrollX - originX) / pxPerSec)
    }

    // MARK: - TTS Audio Helpers

    /// Find a Dialogue by its sourceItemId across all scenes
    public func findDialogue(sourceItemId: String) -> Dialogue? {
        guard let project = project else { return nil }
        for sequence in project.sequences {
            for scene in sequence.scenes {
                if let dialogue = scene.dialogues.first(where: { $0.id == sourceItemId }) {
                    return dialogue
                }
            }
        }
        return nil
    }

    /// Find a Character by name
    public func findCharacter(name: String) -> Character? {
        return project?.characters.first(where: { $0.name == name })
    }

    /// Update a dialogue's audioFilePath across all scenes in the project
    public func updateDialogueAudioPath(sourceItemId: String, audioFilePath: String) {
        guard project != nil else { return }
        for seqIdx in project!.sequences.indices {
            for sceneIdx in project!.sequences[seqIdx].scenes.indices {
                if let dlgIdx = project!.sequences[seqIdx].scenes[sceneIdx].dialogues.firstIndex(where: { $0.id == sourceItemId }) {
                    project!.sequences[seqIdx].scenes[sceneIdx].dialogues[dlgIdx].audioFilePath = audioFilePath
                    return
                }
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
