//
//  StorytellerNarrationPlayer.swift
//  DirectorsChair-Desktop
//
//  The audio-chunk manager for storyteller mode — all that remains of the
//  old parallel StorytellerPlaybackController. The playing chunk's
//  AVAudioPlayer IS the master clock: PlaybackViewModel's tick reads
//  `narrationTime` (chunk start offset + player.currentTime) instead of
//  integrating wall-clock dt, so one second of audio is exactly one second
//  of playhead. There is NO timer here — PlaybackViewModel owns the only
//  clock loop, and every transport action routes through it.
//
//  Chunk-to-chunk advance is delegate-driven (VoiceConversationController
//  precedent); a chunk whose audio hasn't been generated yet parks the
//  player in a waiting state at the scene boundary and auto-resumes when
//  the engine marks it playable.
//

import Foundation
import AVFoundation
import Combine
import DirectorsChairCore

@MainActor
class StorytellerNarrationPlayer: NSObject, ObservableObject {
    let engine: StorytellerEngine

    /// The current chunk's audio hasn't landed yet — playback waits at the
    /// scene boundary and auto-resumes when generation catches up.
    @Published private(set) var isWaitingForChunk = false
    @Published private(set) var currentChunkIndex = 0

    /// Desired transport state (mirrors PlaybackViewModel.isPlaying while
    /// storyteller mode is active — one source of truth, set only through
    /// the view model's play/pause).
    private(set) var isPlaying = false

    /// Live volume from the playback transport (mute + slider).
    var volumeProvider: () -> Double = { 1.0 }
    /// The last chunk finished — the view model parks the transport.
    var onStoryFinished: (() -> Void)?
    /// engine.chunks changed (a duration landed, a state flipped) — the
    /// view model retimes the storyteller playlist.
    var onChunksChanged: (() -> Void)?

    /// Playback speed, applied as AVAudioPlayer.rate (time-stretch, pitch
    /// preserved) — the same semantics as the dialogue TTS engine, so the
    /// transport's speed menu stays functional in storyteller mode.
    var rate: Float = 1.0 {
        didSet { player?.rate = rate }
    }

    private var player: AVAudioPlayer?
    private var pendingSeekOffset: TimeInterval = 0
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

    // MARK: - Master clock

    /// Story-clock read: the sum of the measured durations before the
    /// current chunk plus the live audio position inside it. Frozen while
    /// waiting for a chunk to generate.
    var narrationTime: TimeInterval {
        engine.chunkStartOffset(at: currentChunkIndex) + (player?.currentTime ?? 0)
    }

    var currentChunkIsCached: Bool {
        engine.chunks.indices.contains(currentChunkIndex)
            && engine.chunks[currentChunkIndex].state == .cached
    }

    // MARK: - Transport (driven only by PlaybackViewModel)

    func play() {
        isPlaying = true
        if let player {
            player.play()
        } else {
            loadCurrentChunk()
        }
    }

    func pause() {
        isPlaying = false
        player?.pause()
    }

    func refreshVolume() {
        player?.volume = Float(volumeProvider())
    }

    /// Seek on the story clock: resolve the chunk by cumulative measured
    /// durations, then the intra-chunk offset via player.currentTime —
    /// trivial now that scene span == narration span.
    func seek(toStoryTime time: TimeInterval) {
        var spans: [(start: CGFloat, end: CGFloat)] = []
        var cursor: CGFloat = 0
        for chunk in engine.chunks {
            let end = cursor + CGFloat(chunk.duration)
            spans.append((cursor, end))
            cursor = end
        }
        guard let index = StorytellerTimeline.spanIndex(at: CGFloat(time),
                                                        spans: spans) else { return }
        seek(toChunk: index, offset: TimeInterval(CGFloat(time) - spans[index].start))
    }

    func seek(toChunk index: Int, offset: TimeInterval = 0) {
        guard engine.chunks.indices.contains(index) else { return }
        player?.stop()
        player = nil
        currentChunkIndex = index
        pendingSeekOffset = offset
        loadCurrentChunk()
    }

    /// Leave storyteller mode: silence and reset. The caller cancels
    /// generation (cached audio keeps whatever already landed).
    func stopAndReset() {
        isPlaying = false
        isWaitingForChunk = false
        pendingSeekOffset = 0
        player?.stop()
        player = nil
        currentChunkIndex = 0
    }

    // MARK: - Chunk lifecycle

    private func loadCurrentChunk() {
        guard engine.chunks.indices.contains(currentChunkIndex) else {
            isWaitingForChunk = false
            return
        }
        let chunk = engine.chunks[currentChunkIndex]
        guard chunk.isPlayable, let url = chunk.audioURL else {
            // Wait at the boundary — chunkStatesChanged auto-resumes.
            isWaitingForChunk = true
            return
        }
        isWaitingForChunk = false
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.enableRate = true
            newPlayer.delegate = self
            newPlayer.volume = Float(volumeProvider())
            if pendingSeekOffset > 0 {
                newPlayer.currentTime = min(pendingSeekOffset,
                                            max(0, chunk.duration - 0.05))
            }
            pendingSeekOffset = 0
            newPlayer.rate = rate
            player = newPlayer
            if isPlaying { newPlayer.play() }
        } catch {
            isPlaying = false
            isWaitingForChunk = false
        }
    }

    private func chunkStatesChanged() {
        onChunksChanged?()
        guard isWaitingForChunk,
              engine.chunks.indices.contains(currentChunkIndex),
              engine.chunks[currentChunkIndex].isPlayable else { return }
        loadCurrentChunk()
    }

    private func advanceToNextChunk() {
        player = nil
        let next = currentChunkIndex + 1
        guard next < engine.chunks.count else {
            // Story over — leave the last frame up, park the transport.
            isPlaying = false
            onStoryFinished?()
            return
        }
        currentChunkIndex = next
        loadCurrentChunk()
    }
}

// MARK: - AVAudioPlayerDelegate (chunk advance)

extension StorytellerNarrationPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                                 successfully flag: Bool) {
        Task { @MainActor in self.advanceToNextChunk() }
    }
}
