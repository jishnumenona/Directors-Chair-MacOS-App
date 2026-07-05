//
// TimelineViewModel+Interaction.swift
//
// Extracted from TimelineViewModel.swift (WS9.1 god-file decomposition).
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

extension TimelineViewModel {

    // MARK: - Public Methods

    /// Set the project reference
    public func setProject(_ project: Project) {
        self.project = project
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
}
