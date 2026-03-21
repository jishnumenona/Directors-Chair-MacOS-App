//
//  PlaybackViewModel.swift
//  DirectorsChair-Desktop
//
//  Playback state machine, playlist builder, and timer engine.
//  Mirrors TimelineViewModel.rebuildForGlobal() timing logic to build
//  a flat, time-ordered playback playlist from project data.
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore
import DirectorsChairViews

// MARK: - Playback Data Types

struct PlaybackItem: Identifiable {
    let id: UUID
    let shotId: Int?
    let sceneName: String
    let sequenceName: String
    let startTime: CGFloat
    let duration: CGFloat
    let previewImagePath: String?
    let videoPath: String?
    let shotType: String
    let cameraAngle: String
    let lensMm: Int?
    let movement: String
    let description: String
    let linkedDialogueIds: [String]
    let linkedActionIds: [String]
    let linkedNarrationIds: [String]
    let shot: Shot?
    let sceneIndex: Int
}

struct AudioCue: Identifiable {
    let id: UUID
    let dialogueId: String
    let startTime: CGFloat
    let duration: CGFloat
    let audioFilePath: String
    let character: String
    let text: String
}

struct SubtitleCue: Identifiable {
    let id: UUID
    let startTime: CGFloat
    let duration: CGFloat
    let character: String
    let text: String
}

struct SceneBoundary: Identifiable {
    let id = UUID()
    let time: CGFloat
    let name: String
}

// MARK: - PlaybackViewModel

@MainActor
class PlaybackViewModel: ObservableObject {
    // MARK: - Playback State
    @Published var isPlaying = false
    @Published var currentTime: CGFloat = 0
    @Published var totalDuration: CGFloat = 0
    @Published var playbackSpeed: Double = 1.0
    @Published var volume: Double = 0.25
    @Published var isMuted = false

    /// Per-character muted tracks (character names whose TTS audio is silenced)
    @Published var mutedTracks: Set<String> = []

    // MARK: - Subtitle State
    /// Currently active dialogue for subtitle display
    @Published var currentSubtitle: (character: String, text: String)?

    // MARK: - Current Item
    @Published var currentItem: PlaybackItem?
    @Published var currentSceneName: String = ""
    @Published var currentItemIndex: Int = -1

    // MARK: - Playlist Data
    @Published var playlistItems: [PlaybackItem] = []
    @Published var audioCues: [AudioCue] = []
    @Published var subtitleCues: [SubtitleCue] = []
    @Published var sceneBoundaries: [SceneBoundary] = []

    // MARK: - Linked Script Text (for sidebar)
    @Published var currentLinkedDialogues: [Dialogue] = []
    @Published var currentLinkedActions: [Action] = []
    @Published var currentLinkedNarrations: [Narration] = []

    // MARK: - Scene Reference
    @Published var currentScene: DirectorsChairCore.Scene?

    // MARK: - Timeline Integration
    /// Set by PlaybackView to allow direct playhead sync without SwiftUI onChange overhead
    weak var timelineViewModel: TimelineViewModel?

    // MARK: - Private
    private var timer: Timer?
    private var internalTime: CGFloat = 0  // High-frequency internal clock (not @Published)
    private var tickCount: Int = 0
    private var projectRef: Project?
    private var basePath: URL?
    private var allScenes: [DirectorsChairCore.Scene] = []
    private let wpm = TimelineWPMConstants.defaultWPM

    // Audio engine
    var audioEngine = PlaybackAudioEngine()

    // MARK: - Playlist Building

    func buildPlaylist(from project: Project, basePath: URL?) {
        self.projectRef = project
        self.basePath = basePath

        var items: [PlaybackItem] = []
        var cues: [AudioCue] = []
        var subs: [SubtitleCue] = []
        var boundaries: [SceneBoundary] = []
        var scenes: [DirectorsChairCore.Scene] = []
        var t: CGFloat = 0
        var sceneIdx = 0

        for sequence in project.sequences {
            for scene in sequence.scenes {
                scenes.append(scene)
                boundaries.append(SceneBoundary(time: t, name: scene.name))

                // Build dialogue timing map (mirrors rebuildForGlobal)
                var dialogueTiming: [String: (start: CGFloat, duration: CGFloat, character: String)] = [:]

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

                var allTimelineItems: [TimelineItem] = []
                for dialogue in scene.dialogues {
                    allTimelineItems.append(.dialogue(dialogue))
                }
                for action in scene.actions where action.parentDialogueId == nil {
                    allTimelineItems.append(.action(action))
                }
                for narration in scene.narrations where narration.parentDialogueId == nil {
                    allTimelineItems.append(.narration(narration))
                }
                allTimelineItems.sort { $0.chronologyNumber < $1.chronologyNumber }

                // Process items to build timing
                for item in allTimelineItems {
                    switch item {
                    case .dialogue(let dialogue):
                        let duration = DurationEstimator.getEffectiveDuration(
                            manualDuration: dialogue.manualDuration,
                            text: dialogue.text,
                            wpm: wpm
                        )
                        dialogueTiming[dialogue.id] = (start: t, duration: duration, character: dialogue.character)

                        // Build subtitle cue for ALL dialogues
                        let plainText = DurationEstimator.htmlToPlainText(dialogue.text)
                        if !plainText.isEmpty {
                            subs.append(SubtitleCue(
                                id: UUID(),
                                startTime: t,
                                duration: duration,
                                character: dialogue.character,
                                text: plainText
                            ))
                        }

                        // Build audio cue if TTS audio exists
                        if let audioPath = dialogue.audioFilePath, !audioPath.isEmpty {
                            cues.append(AudioCue(
                                id: UUID(),
                                dialogueId: dialogue.id,
                                startTime: t,
                                duration: duration,
                                audioFilePath: audioPath,
                                character: dialogue.character,
                                text: DurationEstimator.htmlToPlainText(dialogue.text)
                            ))
                        }
                        t += duration

                    case .action(let action):
                        let actionDuration = TimelineWPMConstants.actionDuration
                        t += actionDuration

                    case .narration(let narration):
                        let estimatedDuration = max(
                            TimelineWPMConstants.actionDuration,
                            DurationEstimator.estimateDialogueDuration(text: narration.text, wpm: wpm)
                        )
                        t += estimatedDuration
                    }
                }

                // Build PlaybackItems from shots
                let sceneStartTime = boundaries.last?.time ?? 0
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
                        shotDuration = shot.duration.map { CGFloat($0) } ?? max(sceneDuration / CGFloat(sceneShotCount), 2.0)
                    } else {
                        shotTime = sceneStartTime
                        shotDuration = shot.duration.map { CGFloat($0) } ?? 3.0
                    }

                    items.append(PlaybackItem(
                        id: UUID(),
                        shotId: shot.shotId,
                        sceneName: scene.name,
                        sequenceName: sequence.name,
                        startTime: shotTime,
                        duration: max(shotDuration, 1.0),
                        previewImagePath: shot.previewImage,
                        videoPath: shot.videoPath,
                        shotType: shot.shotType,
                        cameraAngle: shot.cameraAngle,
                        lensMm: shot.lensMm,
                        movement: shot.movement,
                        description: shot.description,
                        linkedDialogueIds: shot.linkedDialogueIds,
                        linkedActionIds: shot.linkedActionIds,
                        linkedNarrationIds: shot.linkedNarrationIds,
                        shot: shot,
                        sceneIndex: sceneIdx
                    ))
                }

                // Ensure minimum scene duration
                if scene.dialogues.isEmpty && scene.actions.isEmpty && scene.narrations.isEmpty {
                    t += TimelineWPMConstants.minSceneDuration
                }

                sceneIdx += 1
            }
        }

        // Override shot times using actual timeline positions (single source of truth)
        if let tlvm = timelineViewModel {
            let shotLabelMap: [String: TimelineShotLabel] = {
                // Key: "shotId-sceneName" for matching
                var map: [String: TimelineShotLabel] = [:]
                for label in tlvm.shotLabels {
                    let key = "\(label.shotId)-\(label.sceneName)"
                    map[key] = label
                }
                return map
            }()

            for i in 0..<items.count {
                guard let shotId = items[i].shotId else { continue }
                let key = "\(shotId)-\(items[i].sceneName)"
                if let label = shotLabelMap[key] {
                    items[i] = PlaybackItem(
                        id: items[i].id,
                        shotId: items[i].shotId,
                        sceneName: items[i].sceneName,
                        sequenceName: items[i].sequenceName,
                        startTime: label.time,
                        duration: max(label.duration, 1.0),
                        previewImagePath: items[i].previewImagePath,
                        videoPath: items[i].videoPath,
                        shotType: items[i].shotType,
                        cameraAngle: items[i].cameraAngle,
                        lensMm: items[i].lensMm,
                        movement: items[i].movement,
                        description: items[i].description,
                        linkedDialogueIds: items[i].linkedDialogueIds,
                        linkedActionIds: items[i].linkedActionIds,
                        linkedNarrationIds: items[i].linkedNarrationIds,
                        shot: items[i].shot,
                        sceneIndex: items[i].sceneIndex
                    )
                }
            }
        }

        // Sort items by start time, then by shotId for stability
        items.sort {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return ($0.shotId ?? 0) < ($1.shotId ?? 0)
        }

        // Clamp durations so shots don't overlap — each shot ends at the next shot's start
        for i in 0..<items.count {
            if i + 1 < items.count {
                let maxDuration = items[i + 1].startTime - items[i].startTime
                if maxDuration > 0 && items[i].duration > maxDuration {
                    items[i] = PlaybackItem(
                        id: items[i].id,
                        shotId: items[i].shotId,
                        sceneName: items[i].sceneName,
                        sequenceName: items[i].sequenceName,
                        startTime: items[i].startTime,
                        duration: maxDuration,
                        previewImagePath: items[i].previewImagePath,
                        videoPath: items[i].videoPath,
                        shotType: items[i].shotType,
                        cameraAngle: items[i].cameraAngle,
                        lensMm: items[i].lensMm,
                        movement: items[i].movement,
                        description: items[i].description,
                        linkedDialogueIds: items[i].linkedDialogueIds,
                        linkedActionIds: items[i].linkedActionIds,
                        linkedNarrationIds: items[i].linkedNarrationIds,
                        shot: items[i].shot,
                        sceneIndex: items[i].sceneIndex
                    )
                }
            }
        }

        self.playlistItems = items
        self.audioCues = cues
        self.subtitleCues = subs
        self.sceneBoundaries = boundaries
        self.allScenes = scenes
        self.totalDuration = max(t, items.last.map { $0.startTime + $0.duration } ?? 0)

        // Preload audio
        audioEngine.preloadAudio(cues: cues, basePath: basePath)

        // Set initial item
        if let first = items.first {
            currentItem = first
            currentSceneName = first.sceneName
            currentItemIndex = 0
            updateCurrentScene()
            updateLinkedScriptItems()
        }
    }

    // MARK: - Playback Controls

    func play() {
        guard !playlistItems.isEmpty else { return }
        isPlaying = true
        audioEngine.resumeAll(speed: playbackSpeed)
        startTimer()
    }

    func pause() {
        isPlaying = false
        stopTimer()
        audioEngine.pauseAll()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func stop() {
        isPlaying = false
        stopTimer()
        internalTime = 0
        currentTime = 0
        timelineViewModel?.playheadTime = 0
        audioEngine.stopAll()
        updateCurrentItem()
    }

    func seekTo(time: CGFloat) {
        let t = max(0, min(time, totalDuration))
        internalTime = t
        currentTime = t
        timelineViewModel?.playheadTime = t
        updateCurrentItem()
        // Use seek (stop-then-restart) only on explicit user scrub
        audioEngine.seek(to: t, speed: playbackSpeed, volume: effectiveVolume)
        // Scroll timeline to keep playhead visible
        timelineViewModel?.followPlayheadIfNeeded()
    }

    func goToStart() {
        seekTo(time: 0)
    }

    func goToEnd() {
        seekTo(time: totalDuration)
        pause()
    }

    func skipToNextShot() {
        guard let current = currentItem else { return }
        let nextTime = current.startTime + current.duration
        if let next = playlistItems.first(where: { $0.startTime >= nextTime - 0.01 && $0.id != current.id }) {
            seekTo(time: next.startTime)
        } else {
            goToEnd()
        }
    }

    func skipToPreviousShot() {
        // If more than 1s into current shot, go to its start
        if let current = currentItem, currentTime - current.startTime > 1.0 {
            seekTo(time: current.startTime)
            return
        }
        // Otherwise go to previous shot
        guard let current = currentItem,
              let idx = playlistItems.firstIndex(where: { $0.id == current.id }),
              idx > 0 else {
            goToStart()
            return
        }
        seekTo(time: playlistItems[idx - 1].startTime)
    }

    func skipToNextScene() {
        guard let boundary = sceneBoundaries.first(where: { $0.time > currentTime + 0.1 }) else {
            goToEnd()
            return
        }
        seekTo(time: boundary.time)
    }

    func skipToPreviousScene() {
        // Find current scene boundary
        let currentBoundary = sceneBoundaries.last(where: { $0.time <= currentTime + 0.1 })
        // If more than 1s into scene, go to scene start
        if let cb = currentBoundary, currentTime - cb.time > 1.0 {
            seekTo(time: cb.time)
            return
        }
        // Otherwise go to previous scene
        guard let cb = currentBoundary,
              let idx = sceneBoundaries.firstIndex(where: { $0.id == cb.id }),
              idx > 0 else {
            goToStart()
            return
        }
        seekTo(time: sceneBoundaries[idx - 1].time)
    }

    var effectiveVolume: Double {
        isMuted ? 0 : volume
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        // Timer fires on main run loop — no Task { @MainActor } needed
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private nonisolated func tick() {
        MainActor.assumeIsolated {
            guard isPlaying else { return }

            tickCount += 1
            internalTime += CGFloat(1.0 / 60.0) * CGFloat(playbackSpeed)

            if internalTime >= totalDuration {
                internalTime = totalDuration
                currentTime = internalTime
                timelineViewModel?.playheadTime = internalTime
                pause()
                return
            }

            // Update timeline playhead directly (just sets a CGFloat, very cheap)
            timelineViewModel?.playheadTime = internalTime

            // Throttle @Published currentTime to ~12fps (every 5th frame)
            // Prevents SwiftUI re-diffing the view tree 60x/sec
            if tickCount % 5 == 0 {
                currentTime = internalTime
            }

            // Update current item (only fires when crossing shot boundaries)
            updateCurrentItem()

            // Throttle audio sync to ~15fps (every 4th frame)
            if tickCount % 4 == 0 {
                audioEngine.syncAudio(to: internalTime, speed: playbackSpeed, volume: effectiveVolume, mutedCharacters: mutedTracks)
            }

            // Update subtitle (throttled to ~12fps with currentTime)
            if tickCount % 5 == 0 {
                updateSubtitle(at: internalTime)
            }

            // Auto-scroll timeline to follow playhead (~4fps, every 15th frame)
            if tickCount % 15 == 0 {
                timelineViewModel?.followPlayheadIfNeeded()
            }
        }
    }

    // MARK: - Item Tracking

    private func updateCurrentItem() {
        // Find item at internal time (high-frequency, not throttled)
        let item = findCurrentItem(at: internalTime)
        if item?.id != currentItem?.id {
            currentItem = item
            currentItemIndex = item.flatMap { item in playlistItems.firstIndex(where: { $0.id == item.id }) } ?? -1
            currentSceneName = item?.sceneName ?? ""
            updateCurrentScene()
            updateLinkedScriptItems()
        }
    }

    private func findCurrentItem(at time: CGFloat) -> PlaybackItem? {
        // Items are sorted by startTime. Find the last item whose startTime <= time.
        // With clamped durations, this gives us the correct shot.
        var best: PlaybackItem?
        for item in playlistItems {
            if item.startTime <= time {
                best = item
            } else {
                break  // past current time, stop searching
            }
        }
        return best ?? playlistItems.first
    }

    private func updateCurrentScene() {
        guard let item = currentItem else {
            currentScene = nil
            return
        }
        if item.sceneIndex < allScenes.count {
            currentScene = allScenes[item.sceneIndex]
        }
    }

    private func updateLinkedScriptItems() {
        guard let item = currentItem, let scene = currentScene else {
            currentLinkedDialogues = []
            currentLinkedActions = []
            currentLinkedNarrations = []
            return
        }

        currentLinkedDialogues = scene.dialogues.filter { item.linkedDialogueIds.contains($0.id) }
        currentLinkedActions = scene.actions.filter { item.linkedActionIds.contains($0.id) }
        currentLinkedNarrations = scene.narrations.filter { item.linkedNarrationIds.contains($0.id) }
    }

    // MARK: - Subtitle Tracking

    private func updateSubtitle(at time: CGFloat) {
        // Find the subtitle cue whose time range contains the current time
        // Uses subtitleCues (all dialogues) not audioCues (only TTS dialogues)
        let activeCue = subtitleCues.first { cue in
            time >= cue.startTime && time < cue.startTime + cue.duration
        }
        if let cue = activeCue {
            // Hide subtitle if character is muted
            if mutedTracks.contains(cue.character) {
                if currentSubtitle != nil { currentSubtitle = nil }
                return
            }
            if currentSubtitle?.character != cue.character || currentSubtitle?.text != cue.text {
                currentSubtitle = (character: cue.character, text: cue.text)
            }
        } else if currentSubtitle != nil {
            currentSubtitle = nil
        }
    }

    // MARK: - Track Muting

    func toggleTrackMute(_ characterName: String) {
        if mutedTracks.contains(characterName) {
            mutedTracks.remove(characterName)
        } else {
            mutedTracks.insert(characterName)
            // Stop any currently playing audio for this character
            audioEngine.stopCharacter(characterName)
        }
    }

    /// All unique character names that have audio cues
    var audioCharacters: [String] {
        Array(Set(audioCues.map { $0.character })).sorted()
    }

    // MARK: - Helpers

    func resolvedImagePath(for relativePath: String?) -> URL? {
        guard let path = relativePath, !path.isEmpty, let base = basePath else { return nil }
        return base.appendingPathComponent(path)
    }

    func resolvedVideoPath(for relativePath: String?) -> URL? {
        guard let path = relativePath, !path.isEmpty, let base = basePath else { return nil }
        return base.appendingPathComponent(path)
    }

    /// Formatted timecode for display
    var currentTimecode: String {
        formatTimecode(currentTime)
    }

    var totalTimecode: String {
        formatTimecode(totalDuration)
    }

    private func formatTimecode(_ seconds: CGFloat) -> String {
        let totalSecs = max(0, seconds)
        let mins = Int(totalSecs) / 60
        let secs = Int(totalSecs) % 60
        let frames = Int((totalSecs - CGFloat(Int(totalSecs))) * 24) // 24fps timecode
        return String(format: "%02d:%02d:%02d", mins, secs, frames)
    }

    /// Progress ratio 0…1
    var progress: CGFloat {
        totalDuration > 0 ? currentTime / totalDuration : 0
    }

    /// Current speed label
    var speedLabel: String {
        if playbackSpeed == 1.0 { return "1x" }
        if playbackSpeed == 0.5 { return "0.5x" }
        if playbackSpeed == 1.5 { return "1.5x" }
        if playbackSpeed == 2.0 { return "2x" }
        return String(format: "%.1fx", playbackSpeed)
    }

    deinit {
        timer?.invalidate()
    }
}
