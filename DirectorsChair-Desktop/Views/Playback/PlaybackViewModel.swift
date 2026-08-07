//
//  PlaybackViewModel.swift
//  DirectorsChair-Desktop
//
//  Playback state machine, playlist builder, and timer engine.
//  Mirrors TimelineViewModel.rebuildForGlobal() timing logic to build
//  a flat, time-ordered playback playlist from project data.
//
//  Storyteller is a MODE of this view model (storytellerActive): the
//  playlist is retimed to the narration's real audio durations, the
//  narration player becomes the master clock, and the whole transport +
//  sidebar + timeline pipeline runs through the same code paths as
//  normal playback. See StorytellerTimeline.swift for the pure math.
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

extension PlaybackItem {
    /// Copy with a new time window. Metadata — linked ids, media, shot —
    /// is preserved verbatim, so every sidebar card resolves identically
    /// whichever clock the playlist runs on.
    func retimed(startTime: CGFloat, duration: CGFloat) -> PlaybackItem {
        PlaybackItem(id: id, shotId: shotId, sceneName: sceneName,
                     sequenceName: sequenceName, startTime: startTime,
                     duration: duration, previewImagePath: previewImagePath,
                     videoPath: videoPath, shotType: shotType,
                     cameraAngle: cameraAngle, lensMm: lensMm,
                     movement: movement, description: description,
                     linkedDialogueIds: linkedDialogueIds,
                     linkedActionIds: linkedActionIds,
                     linkedNarrationIds: linkedNarrationIds,
                     shot: shot, sceneIndex: sceneIndex)
    }
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
    @Published var playbackSpeed: Double = 1.0 {
        // Storyteller mode: speed is applied as AVAudioPlayer.rate on the
        // narration (time-stretch, pitch preserved) — the transport's speed
        // menu keeps working. Outside the mode the rate lands on the next
        // narration chunk load, which never happens (player is reset).
        didSet { narrationPlayer.rate = Float(playbackSpeed) }
    }
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

    // MARK: - Active Light Cues
    @Published var currentLightCues: [LightCue] = []
    @Published var currentSFXCues: [SFXCue] = []
    @Published var currentSupportCues: [SupportCue] = []

    // MARK: - Timeline Integration
    /// Set by PlaybackView to allow direct playhead sync without SwiftUI onChange overhead
    weak var timelineViewModel: TimelineViewModel?

    // MARK: - Storyteller Mode State
    /// Storyteller is a MODE of this view model, not a parallel player.
    /// While active: the playlist is retimed so scene span == narration
    /// span, the narration AVAudioPlayer is the master clock, and every
    /// transport control routes to the narration. The normal playlist is
    /// saved on entry and restored intact on exit.
    @Published private(set) var storytellerActive = false
    /// Current slideshow image (scene overview / shot stills), keyed by the
    /// storyteller-timed windows.
    @Published private(set) var storytellerSlideURL: URL?
    /// Bumped when play is requested while ungenerated chunks exist and no
    /// generation is running — the view arms the cost-confirmation gate.
    @Published private(set) var storytellerPlayArmRequests = 0

    let narrationPlayer: StorytellerNarrationPlayer

    private var savedNormalItems: [PlaybackItem] = []
    private var savedNormalBoundaries: [SceneBoundary] = []
    private var savedNormalTotalDuration: CGFloat = 0
    private var storytellerSceneMaps: [StorytellerTimeline.SceneMap] = []
    private var storytellerSlides: [StorytellerSlide] = []

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

    // MARK: - Init

    convenience init() {
        self.init(narrationPlayer: StorytellerNarrationPlayer())
    }

    /// Seam: tests inject a narration player with a scripted clock.
    init(narrationPlayer: StorytellerNarrationPlayer) {
        self.narrationPlayer = narrationPlayer
        narrationPlayer.volumeProvider = { [weak self] in self?.effectiveVolume ?? 1.0 }
        narrationPlayer.onStoryFinished = { [weak self] in self?.storytellerStoryFinished() }
        narrationPlayer.onChunksChanged = { [weak self] in self?.retimeStorytellerPlaylist() }
    }

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
                    items[i] = items[i].retimed(startTime: label.time,
                                                duration: max(label.duration, 1.0))
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
                    items[i] = items[i].retimed(startTime: items[i].startTime,
                                                duration: maxDuration)
                }
            }
        }

        self.audioCues = cues
        self.subtitleCues = subs
        self.allScenes = scenes
        let total = max(t, items.last.map { $0.startTime + $0.duration } ?? 0)

        if storytellerActive {
            // A project edit landed mid-narration: refresh the saved normal
            // playlist and re-derive the storyteller timing from it. The
            // published playlist stays on the story clock.
            savedNormalItems = items
            savedNormalBoundaries = boundaries
            savedNormalTotalDuration = total
            retimeStorytellerPlaylist()
        } else {
            self.playlistItems = items
            self.sceneBoundaries = boundaries
            self.totalDuration = total
        }

        // Preload audio
        audioEngine.preloadAudio(cues: cues, basePath: basePath)

        // Preload soundtrack audio
        audioEngine.preloadSoundtracks(tracks: project.soundtracks, basePath: basePath)

        // Set initial item
        if !storytellerActive, let first = items.first {
            currentItem = first
            currentSceneName = first.sceneName
            currentItemIndex = 0
            updateCurrentScene()
            updateLinkedScriptItems()
        }
    }

    // MARK: - Playback Controls

    func play() {
        if storytellerActive {
            // The narration is the player — the normal dialogue/soundtrack
            // engines must never start while the mode is active.
            isPlaying = true
            narrationPlayer.rate = Float(playbackSpeed)
            // Pressing play at the story's end restarts the telling.
            if totalDuration > 0, internalTime >= totalDuration - 0.01 {
                seekTo(time: 0)
            }
            narrationPlayer.play()
            startTimer()
            let engine = narrationPlayer.engine
            if engine.pendingChunkCount > 0, !engine.isGenerating {
                storytellerPlayArmRequests += 1
            }
            return
        }
        guard !playlistItems.isEmpty else { return }
        isPlaying = true
        audioEngine.resumeAll(speed: playbackSpeed)
        audioEngine.resumeAllSoundtracks(speed: playbackSpeed)
        startTimer()
    }

    func pause() {
        isPlaying = false
        stopTimer()
        if storytellerActive {
            narrationPlayer.pause()
        } else {
            audioEngine.pauseAll()
            audioEngine.pauseAllSoundtracks()
        }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func stop() {
        if storytellerActive {
            pause()
            seekTo(time: 0)
            return
        }
        isPlaying = false
        stopTimer()
        internalTime = 0
        currentTime = 0
        timelineViewModel?.playheadTime = 0
        audioEngine.stopAll()
        audioEngine.stopAllSoundtracks()
        updateCurrentItem()
        updateActiveLightCues(at: internalTime)
        updateActiveSFXCues(at: internalTime)
        updateActiveSupportCues(at: internalTime)
    }

    func seekTo(time: CGFloat) {
        let t = max(0, min(time, totalDuration))
        internalTime = t
        currentTime = t
        if storytellerActive {
            // All transport routes to narration: chunk + intra-chunk offset
            // (scene span == narration span, so this is a direct lookup).
            narrationPlayer.seek(toStoryTime: TimeInterval(t))
        } else {
            // Use seek (stop-then-restart) only on explicit user scrub
            audioEngine.seek(to: t, speed: playbackSpeed, volume: effectiveVolume)
            audioEngine.seekSoundtracks(to: t, speed: playbackSpeed, volume: effectiveVolume)
        }
        refreshDerivedState()
        // Scroll timeline to keep playhead visible
        timelineViewModel?.followPlayheadIfNeeded()
    }

    /// Seek arriving from the EDIT timeline ruler (WPM time). In
    /// storyteller mode the incoming time is mapped onto the story clock
    /// (the inverse of the per-scene linear playhead mapping).
    func seekFromEditTimeline(_ editTime: CGFloat) {
        if storytellerActive {
            seekTo(time: StorytellerTimeline.storyTime(forEditTime: editTime,
                                                       maps: storytellerSceneMaps))
        } else {
            seekTo(time: editTime)
        }
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
        MainActor.assumeIsolated { performTick() }
    }

    /// One clock frame. Internal (not private) so tests can drive the clock
    /// deterministically without the runloop timer.
    func performTick() {
        guard isPlaying else { return }

        tickCount += 1

        if storytellerActive {
            // The narration AVAudioPlayer is the master clock: read it,
            // never integrate dt — 1 s of audio is exactly 1 s of playhead,
            // timecode, and scrubber. End-of-story is delegate-driven
            // (storytellerStoryFinished), not a totalDuration compare,
            // because the total grows as chunk audio lands.
            internalTime = CGFloat(narrationPlayer.narrationTime)
        } else {
            internalTime += CGFloat(1.0 / 60.0) * CGFloat(playbackSpeed)

            if internalTime >= totalDuration {
                internalTime = totalDuration
                currentTime = internalTime
                timelineViewModel?.playheadTime = internalTime
                pause()
                return
            }
        }

        // Cue windows + the edit-timeline playhead live in WPM time; the
        // storyteller clock maps onto it linearly per scene.
        let cueTime = cueEvaluationTime(for: internalTime)

        // Update timeline playhead directly (just sets a CGFloat, very cheap)
        timelineViewModel?.playheadTime = cueTime

        // Throttle @Published currentTime to ~12fps (every 5th frame)
        // Prevents SwiftUI re-diffing the view tree 60x/sec
        if tickCount % 5 == 0 {
            currentTime = internalTime
        }

        // Update current item (only fires when crossing shot boundaries)
        updateCurrentItem()

        // Throttle audio sync to ~15fps (every 4th frame). The normal
        // dialogue/soundtrack engines NEVER run while the narration owns
        // the clock — only its volume is refreshed.
        if tickCount % 4 == 0 {
            if storytellerActive {
                narrationPlayer.refreshVolume()
            } else {
                audioEngine.syncAudio(to: internalTime, speed: playbackSpeed, volume: effectiveVolume, mutedCharacters: mutedTracks)
                audioEngine.syncSoundtracks(to: internalTime, speed: playbackSpeed, volume: effectiveVolume)
            }
        }

        // Update subtitle and light cues (throttled to ~12fps with currentTime)
        if tickCount % 5 == 0 {
            updateSubtitle(at: cueTime)
            updateActiveLightCues(at: cueTime)
            updateActiveSFXCues(at: cueTime)
            updateActiveSupportCues(at: cueTime)
            if storytellerActive { updateStorytellerSlide() }
        }

        // Auto-scroll timeline to follow playhead (~4fps, every 15th frame)
        if tickCount % 15 == 0 {
            timelineViewModel?.followPlayheadIfNeeded()
        }
    }

    // MARK: - Storyteller Mode

    /// Enter storyteller mode: build the scene chunks (cache only — the
    /// cost sheet still gates generation), save the normal playlist, and
    /// swap in the storyteller-timed one. The clock starts at 0.
    func enterStorytellerMode() {
        guard !storytellerActive, let project = projectRef else { return }
        narrationPlayer.engine.prepare(project: project)
        guard !narrationPlayer.engine.chunks.isEmpty else { return }

        pause()
        // The normal engines must NOT run during narration.
        audioEngine.stopAll()
        audioEngine.stopAllSoundtracks()

        savedNormalItems = playlistItems
        savedNormalBoundaries = sceneBoundaries
        savedNormalTotalDuration = totalDuration

        narrationPlayer.rate = Float(playbackSpeed)
        narrationPlayer.stopAndReset()
        storytellerActive = true
        retimeStorytellerPlaylist()
        internalTime = 0
        currentTime = 0
        refreshDerivedState()
    }

    /// Leave storyteller mode: restore the normal playlist intact and hand
    /// the playhead the edit-timeline position of the narrated moment.
    func exitStorytellerMode() {
        guard storytellerActive else { return }
        let exitTime = StorytellerTimeline.editTime(forStoryTime: internalTime,
                                                    maps: storytellerSceneMaps)
        pause()
        narrationPlayer.stopAndReset()
        // Stop spending on chunks nobody is listening to; cached audio
        // keeps whatever already finished.
        narrationPlayer.engine.cancelGeneration()
        storytellerActive = false
        storytellerSceneMaps = []
        storytellerSlides = []
        storytellerSlideURL = nil

        playlistItems = savedNormalItems
        sceneBoundaries = savedNormalBoundaries
        totalDuration = savedNormalTotalDuration
        savedNormalItems = []
        savedNormalBoundaries = []
        savedNormalTotalDuration = 0

        internalTime = max(0, min(exitTime, totalDuration))
        currentTime = internalTime
        refreshDerivedState()
    }

    /// Chip-strip / prev-next-scene entry point: snap to a chunk's start on
    /// the story clock (an ungenerated chunk waits at its boundary).
    func seekToStorytellerChunk(_ index: Int) {
        guard storytellerActive else { return }
        seekTo(time: CGFloat(narrationPlayer.engine.chunkStartOffset(at: index)))
    }

    /// (Re)build the storyteller-timed playlist from the saved normal one
    /// plus the chunks' REAL measured audio durations. Runs on entry and
    /// whenever a chunk lands (durations stream in during generation).
    private func retimeStorytellerPlaylist() {
        guard storytellerActive else { return }
        let chunks = narrationPlayer.engine.chunks
        let retimed = StorytellerTimeline.retime(
            normalItems: savedNormalItems,
            normalBoundaries: savedNormalBoundaries,
            normalTotalDuration: savedNormalTotalDuration,
            chunkSpans: chunks.map { (sceneIndex: $0.sceneIndex, duration: $0.duration) })
        playlistItems = retimed.items
        sceneBoundaries = retimed.boundaries
        totalDuration = retimed.totalDuration
        storytellerSceneMaps = retimed.sceneMaps
        storytellerSlides = buildStorytellerSlides(maps: retimed.sceneMaps,
                                                  items: retimed.items)
        internalTime = min(internalTime, totalDuration)
        refreshDerivedState()
    }

    /// Slideshow for the whole story: per narrated scene, the overview
    /// image + shot stills over the retimed (storyteller-clock) windows.
    private func buildStorytellerSlides(maps: [StorytellerTimeline.SceneMap],
                                        items: [PlaybackItem]) -> [StorytellerSlide] {
        var slides: [StorytellerSlide] = []
        for map in maps where map.storyEnd > map.storyStart {
            guard map.sceneIndex < allScenes.count else { continue }
            let scene = allScenes[map.sceneIndex]
            let shots = items
                .filter { $0.sceneIndex == map.sceneIndex }
                .map { (imagePath: $0.previewImagePath, startTime: $0.startTime) }
            slides.append(contentsOf: StorytellerMapping.buildSlides(
                sceneStart: map.storyStart, sceneEnd: map.storyEnd,
                overviewImagePath: scene.sceneOverviewImage, shots: shots))
        }
        return slides
    }

    private func updateStorytellerSlide() {
        guard storytellerActive else { return }
        if let index = StorytellerMapping.slideIndex(at: internalTime,
                                                     in: storytellerSlides) {
            let url = resolvedImagePath(for: storytellerSlides[index].imagePath)
            if url != storytellerSlideURL { storytellerSlideURL = url }
        } else if storytellerSlideURL != nil {
            storytellerSlideURL = nil
        }
    }

    private func storytellerStoryFinished() {
        internalTime = totalDuration
        currentTime = internalTime
        pause()
        refreshDerivedState()
    }

    /// Cue windows (light/SFX/support), subtitles, and the edit-timeline
    /// playhead live in EDIT-timeline (WPM) time. In storyteller mode the
    /// clock runs on narration time, so map it back linearly per scene.
    /// The edit-timeline lanes are WPM-scaled, so the playhead's rate
    /// differs across scenes there BY DESIGN — the playback scrubber and
    /// timecode are the uniform clock.
    private func cueEvaluationTime(for time: CGFloat) -> CGFloat {
        storytellerActive
            ? StorytellerTimeline.editTime(forStoryTime: time, maps: storytellerSceneMaps)
            : time
    }

    /// Re-resolve every time-derived surface (current item, sidebar cues,
    /// subtitle, timeline playhead, slideshow) at the current clock.
    private func refreshDerivedState() {
        let cueTime = cueEvaluationTime(for: internalTime)
        timelineViewModel?.playheadTime = cueTime
        updateCurrentItem()
        updateSubtitle(at: cueTime)
        updateActiveLightCues(at: cueTime)
        updateActiveSFXCues(at: cueTime)
        updateActiveSupportCues(at: cueTime)
        if storytellerActive { updateStorytellerSlide() }
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

    // MARK: - Light Cue Tracking

    /// Cache of previous active cue IDs to avoid redundant @Published writes
    private var lastLightCueIds: Set<String> = []
    private var lastSFXCueIds: Set<String> = []
    private var lastSupportCueIds: Set<String> = []

    private func updateActiveLightCues(at time: CGFloat) {
        guard let project = projectRef else {
            if !currentLightCues.isEmpty { currentLightCues = [] }
            return
        }
        let active = project.lightCues.filter { cue in
            cue.isActive &&
            Double(time) >= cue.startTime &&
            Double(time) < cue.startTime + cue.duration
        }
        let ids = Set(active.map { $0.id })
        if ids != lastLightCueIds {
            lastLightCueIds = ids
            currentLightCues = active
        }
    }

    private func updateActiveSFXCues(at time: CGFloat) {
        guard let project = projectRef else {
            if !currentSFXCues.isEmpty { currentSFXCues = [] }
            return
        }
        let active = project.sfxCues.filter { cue in
            cue.isActive &&
            Double(time) >= cue.startTime &&
            Double(time) < cue.startTime + cue.duration
        }
        let ids = Set(active.map { $0.id })
        if ids != lastSFXCueIds {
            lastSFXCueIds = ids
            currentSFXCues = active
        }
    }

    private func updateActiveSupportCues(at time: CGFloat) {
        guard let project = projectRef else {
            if !currentSupportCues.isEmpty { currentSupportCues = [] }
            return
        }
        let active = project.supportCues.filter { cue in
            cue.isActive &&
            Double(time) >= cue.startTime &&
            Double(time) < cue.startTime + cue.duration
        }
        let ids = Set(active.map { $0.id })
        if ids != lastSupportCueIds {
            lastSupportCueIds = ids
            currentSupportCues = active
        }
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
        // Proxy when fresh and allowed, original otherwise — playback is
        // exactly what proxies exist for (§2.17).
        return ProxyPlayback.url(forRelativePath: path, projectBase: base)
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
