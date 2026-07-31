//
//  StorytellerPlaybackController.swift
//  DirectorsChair-Desktop
//
//  Storyteller playback: the AVAudioPlayer of the playing chunk is the
//  master clock (two-clock pattern from PlaybackViewModel — high-frequency
//  reads, throttled @Published writes). Narration progress within a scene
//  maps onto that scene's existing playlist shot spans to drive the
//  timeline playhead and the image slideshow; chunk-to-chunk advance is
//  delegate-driven (VoiceConversationController precedent).
//

import Foundation
import AVFoundation
import Combine
import SwiftUI
import DirectorsChairCore
import DirectorsChairViews

// MARK: - Slides + pure mapping math (unit-tested)

/// One slideshow image with its window in TIMELINE time inside the scene.
struct StorytellerSlide: Equatable {
    let imagePath: String   // relative to the project base path
    var start: CGFloat
    var end: CGFloat
}

enum StorytellerMapping {
    /// Narration progress within a chunk → timeline time inside the scene
    /// span (the shot spans are normalized to the narration length).
    static func timelineTime(narrationTime: Double, narrationDuration: Double,
                             sceneStart: CGFloat, sceneEnd: CGFloat) -> CGFloat {
        guard narrationDuration > 0, sceneEnd > sceneStart else { return sceneStart }
        let fraction = min(max(narrationTime / narrationDuration, 0), 1)
        return sceneStart + CGFloat(fraction) * (sceneEnd - sceneStart)
    }

    /// Slideshow sequence for one scene: the overview image leads, then the
    /// shot stills in shot order (shots without images are skipped — their
    /// span is absorbed by the previous slide). The overview gets the
    /// pre-first-shot span when one exists; when the first shot starts at
    /// the scene start, the colliding slide is pushed to the midpoint of
    /// the space up to the next boundary so both get a window.
    static func buildSlides(sceneStart: CGFloat, sceneEnd: CGFloat,
                            overviewImagePath: String?,
                            shots: [(imagePath: String?, startTime: CGFloat)])
    -> [StorytellerSlide] {
        guard sceneEnd > sceneStart else { return [] }

        var entries: [(path: String, start: CGFloat)] = []
        if let overview = overviewImagePath, !overview.isEmpty {
            entries.append((overview, sceneStart))
        }
        let shotEntries = shots
            .filter { !($0.imagePath ?? "").isEmpty }
            .sorted { $0.startTime < $1.startTime }
            .map { (path: $0.imagePath!,
                    start: min(max($0.startTime, sceneStart), sceneEnd)) }
        entries.append(contentsOf: shotEntries)
        guard !entries.isEmpty else { return [] }

        // Stable order: by start, overview-before-shot on ties.
        entries = entries.enumerated()
            .sorted { a, b in
                a.element.start != b.element.start
                    ? a.element.start < b.element.start
                    : a.offset < b.offset
            }
            .map(\.element)

        // Enforce strictly increasing starts so every slide gets a window.
        for i in 1..<entries.count where entries[i].start <= entries[i - 1].start {
            let nextBoundary = entries[(i + 1)...]
                .first(where: { $0.start > entries[i - 1].start })?.start ?? sceneEnd
            entries[i].start = entries[i - 1].start
                + (nextBoundary - entries[i - 1].start) / 2
        }

        var slides: [StorytellerSlide] = []
        for i in entries.indices {
            let end = i + 1 < entries.count ? entries[i + 1].start : sceneEnd
            if end > entries[i].start {
                slides.append(StorytellerSlide(imagePath: entries[i].path,
                                               start: entries[i].start, end: end))
            }
        }
        return slides
    }

    /// The slide showing at a timeline instant (last slide whose start has
    /// passed; nil only when the scene has no slides).
    static func slideIndex(at timelineTime: CGFloat,
                           in slides: [StorytellerSlide]) -> Int? {
        guard !slides.isEmpty else { return nil }
        var best = 0
        for (i, slide) in slides.enumerated() where slide.start <= timelineTime {
            best = i
        }
        return best
    }
}

// MARK: - Controller

@MainActor
final class StorytellerPlaybackController: NSObject, ObservableObject {
    let engine: StorytellerEngine

    @Published private(set) var isActive = false
    @Published private(set) var isPlaying = false
    /// The current chunk's audio hasn't landed yet — auto-resumes when the
    /// engine marks it ready (chunk-streamed generation).
    @Published private(set) var isWaitingForChunk = false
    @Published private(set) var currentChunkIndex = 0
    @Published private(set) var currentSlideURL: URL?
    @Published private(set) var storyTime: TimeInterval = 0   // throttled

    /// Scene geometry captured from the playback playlist when the mode
    /// opens — scene spans + per-scene slide windows in timeline time.
    struct SceneGeometry {
        let start: CGFloat
        let end: CGFloat
        let slides: [StorytellerSlide]
    }
    private var geometry: [Int: SceneGeometry] = [:]   // keyed by global scene index
    private var basePath: URL?
    weak var timelineViewModel: TimelineViewModel?
    /// Live volume from the playback transport (mute + slider).
    var volumeProvider: () -> Double = { 1.0 }

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var tickCount = 0
    private var chunkObserver: AnyCancellable?

    init(engine: StorytellerEngine = StorytellerEngine()) {
        self.engine = engine
        super.init()
        // Deferred to the next runloop turn so engine.chunks is committed
        // when we re-check playability.
        chunkObserver = engine.$chunks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.chunkStatesChanged() }
    }

    var currentChunkIsCached: Bool {
        engine.chunks.indices.contains(currentChunkIndex)
            && engine.chunks[currentChunkIndex].state == .cached
    }

    // MARK: - Geometry

    /// Capture scene spans + slide windows from the live playlist. Safe to
    /// call again after a playlist rebuild while the mode stays open.
    func configure(project: Project, basePath: URL?,
                   playlistItems: [PlaybackItem],
                   sceneBoundaries: [SceneBoundary],
                   totalDuration: CGFloat,
                   timelineViewModel: TimelineViewModel?) {
        self.basePath = basePath
        self.timelineViewModel = timelineViewModel

        let scenes = project.sequences.flatMap(\.scenes)
        var built: [Int: SceneGeometry] = [:]
        for (index, scene) in scenes.enumerated() {
            guard index < sceneBoundaries.count else { break }
            let start = sceneBoundaries[index].time
            let end = index + 1 < sceneBoundaries.count
                ? sceneBoundaries[index + 1].time : totalDuration
            let shots = playlistItems
                .filter { $0.sceneIndex == index }
                .map { (imagePath: $0.previewImagePath, startTime: $0.startTime) }
            let slides = StorytellerMapping.buildSlides(
                sceneStart: start, sceneEnd: end,
                overviewImagePath: scene.sceneOverviewImage, shots: shots)
            built[index] = SceneGeometry(start: start, end: end, slides: slides)
        }
        geometry = built
    }

    // MARK: - Transport

    /// Enter storyteller mode from the top of the story. Chunk 1 may still
    /// be generating — playback starts the moment it lands.
    func beginStory() {
        isActive = true
        isPlaying = true
        currentChunkIndex = 0
        updateVisualsForChunkStart()
        startCurrentChunk()
    }

    func pause() {
        isPlaying = false
        player?.pause()
        stopTimer()
    }

    func resume() {
        guard isActive else { return }
        isPlaying = true
        if let player {
            player.play()
            startTimer()
        } else {
            startCurrentChunk()
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    /// Seek-by-scene: snap to the chunk's start.
    func seek(toChunk index: Int) {
        guard isActive, engine.chunks.indices.contains(index) else { return }
        player?.stop()
        player = nil
        stopTimer()
        currentChunkIndex = index
        updateVisualsForChunkStart()
        startCurrentChunk()
    }

    func seekToNextChunk() { seek(toChunk: currentChunkIndex + 1) }

    func seekToPreviousChunk() {
        // More than a second in: restart the scene (transport convention).
        if let player, player.currentTime > 1.0 {
            seek(toChunk: currentChunkIndex)
        } else {
            seek(toChunk: max(0, currentChunkIndex - 1))
        }
    }

    func deactivate() {
        isActive = false
        isPlaying = false
        isWaitingForChunk = false
        stopTimer()
        player?.stop()
        player = nil
        // Stop spending on chunks nobody is listening to; cached audio
        // keeps whatever already finished.
        engine.cancelGeneration()
    }

    // MARK: - Chunk lifecycle

    private func startCurrentChunk() {
        guard engine.chunks.indices.contains(currentChunkIndex) else {
            isPlaying = false
            return
        }
        let chunk = engine.chunks[currentChunkIndex]
        guard chunk.isPlayable, let url = chunk.audioURL else {
            isWaitingForChunk = true
            stopTimer()
            return
        }
        isWaitingForChunk = false
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.volume = Float(volumeProvider())
            player = newPlayer
            if isPlaying {
                newPlayer.play()
                startTimer()
            }
        } catch {
            isPlaying = false
            isWaitingForChunk = false
        }
    }

    private func chunkStatesChanged() {
        guard isActive, isWaitingForChunk,
              engine.chunks.indices.contains(currentChunkIndex),
              engine.chunks[currentChunkIndex].isPlayable else { return }
        startCurrentChunk()
    }

    private func advanceToNextChunk() {
        player = nil
        let next = currentChunkIndex + 1
        guard next < engine.chunks.count else {
            // Story over — leave the last frame up, park the transport.
            isPlaying = false
            stopTimer()
            return
        }
        currentChunkIndex = next
        updateVisualsForChunkStart()
        startCurrentChunk()
    }

    // MARK: - Clock (audio player is the master)

    private func startTimer() {
        stopTimer()
        // 30 Hz: the playhead write is a cheap CGFloat set; @Published
        // state below is throttled (PlaybackViewModel pattern).
        timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
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
            guard isPlaying, let player,
                  engine.chunks.indices.contains(currentChunkIndex) else { return }
            tickCount += 1
            let chunk = engine.chunks[currentChunkIndex]
            let narrationTime = player.currentTime

            if let geo = geometry[chunk.sceneIndex] {
                let t = StorytellerMapping.timelineTime(
                    narrationTime: narrationTime,
                    narrationDuration: chunk.duration,
                    sceneStart: geo.start, sceneEnd: geo.end)
                timelineViewModel?.playheadTime = t
                if let idx = StorytellerMapping.slideIndex(at: t, in: geo.slides) {
                    let url = resolvedURL(geo.slides[idx].imagePath)
                    if url != currentSlideURL { currentSlideURL = url }
                } else if currentSlideURL != nil {
                    currentSlideURL = nil
                }
                if tickCount % 10 == 0 {
                    timelineViewModel?.followPlayheadIfNeeded()
                }
            }

            // Throttle the @Published story clock to ~10 fps.
            if tickCount % 3 == 0 {
                storyTime = engine.chunkStartOffset(at: currentChunkIndex) + narrationTime
            }
            player.volume = Float(volumeProvider())
        }
    }

    private func updateVisualsForChunkStart() {
        guard engine.chunks.indices.contains(currentChunkIndex) else {
            currentSlideURL = nil
            return
        }
        let chunk = engine.chunks[currentChunkIndex]
        if let geo = geometry[chunk.sceneIndex] {
            timelineViewModel?.playheadTime = geo.start
            timelineViewModel?.followPlayheadIfNeeded()
            let idx = StorytellerMapping.slideIndex(at: geo.start, in: geo.slides)
            currentSlideURL = idx.flatMap { resolvedURL(geo.slides[$0].imagePath) }
        } else {
            currentSlideURL = nil
        }
        storyTime = engine.chunkStartOffset(at: currentChunkIndex)
    }

    private func resolvedURL(_ relativePath: String) -> URL? {
        guard let basePath, !relativePath.isEmpty else { return nil }
        return basePath.appendingPathComponent(relativePath)
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - AVAudioPlayerDelegate (chunk advance)

extension StorytellerPlaybackController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                                 successfully flag: Bool) {
        Task { @MainActor in self.advanceToNextChunk() }
    }
}
