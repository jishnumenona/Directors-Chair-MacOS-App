//
//  PlaybackAudioEngine.swift
//  DirectorsChair-Desktop
//
//  Manages AVAudioPlayer instances for TTS dialogue audio playback.
//  Players are started once at the correct offset and left to play freely —
//  no per-frame drift correction (which causes audible stutter).
//  Seeking only happens on explicit user scrub.
//

import Foundation
import AVFoundation

@MainActor
class PlaybackAudioEngine {
    // MARK: - Private
    private var players: [String: AVAudioPlayer] = [:]  // keyed by dialogueId
    private var cues: [AudioCue] = []
    private var cueCharacterMap: [String: String] = [:]  // dialogueId → character name
    private var currentlyPlayingIds: Set<String> = []
    private var volume: Double = 1.0
    private var speed: Double = 1.0

    // MARK: - Preloading

    func preloadAudio(cues: [AudioCue], basePath: URL?) {
        stopAll()
        self.cues = cues
        players.removeAll()
        cueCharacterMap.removeAll()

        guard let base = basePath else { return }

        for cue in cues {
            cueCharacterMap[cue.dialogueId] = cue.character
            let url = base.appendingPathComponent(cue.audioFilePath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.enableRate = true
                player.prepareToPlay()
                players[cue.dialogueId] = player
            } catch {
                debugLog("PlaybackAudioEngine: Failed to load \(cue.audioFilePath): \(error)")
            }
        }

        debugLog("PlaybackAudioEngine: Preloaded \(players.count)/\(cues.count) audio cues")
    }

    // MARK: - Sync (called throttled ~15fps during playback)

    func syncAudio(to currentTime: CGFloat, speed: Double, volume: Double, mutedCharacters: Set<String> = []) {
        self.volume = volume
        self.speed = speed

        // Determine which cues should be active
        var activeDialogueIds = Set<String>()
        var activeCueMap: [String: AudioCue] = [:]
        for cue in cues {
            if currentTime >= cue.startTime && currentTime < cue.startTime + cue.duration {
                // Skip muted characters
                if mutedCharacters.contains(cue.character) { continue }
                activeDialogueIds.insert(cue.dialogueId)
                activeCueMap[cue.dialogueId] = cue
            }
        }

        // Stop cues that fell out of range or belong to now-muted characters
        let toStop = currentlyPlayingIds.subtracting(activeDialogueIds)
        for dialogueId in toStop {
            players[dialogueId]?.stop()
        }
        currentlyPlayingIds.subtract(toStop)

        // Start new cues (fire-and-forget — no drift correction during playback)
        let toStart = activeDialogueIds.subtracting(currentlyPlayingIds)
        for dialogueId in toStart {
            guard let player = players[dialogueId],
                  let cue = activeCueMap[dialogueId] else { continue }

            let offset = max(0, TimeInterval(currentTime - cue.startTime))
            player.currentTime = offset
            player.volume = Float(volume)
            player.rate = Float(speed)
            player.play()
            currentlyPlayingIds.insert(dialogueId)
        }
    }

    // MARK: - Seek (called only on explicit user scrub)

    func seek(to currentTime: CGFloat, speed: Double, volume: Double) {
        self.volume = volume
        self.speed = speed

        // Stop everything first
        for dialogueId in currentlyPlayingIds {
            players[dialogueId]?.stop()
        }
        currentlyPlayingIds.removeAll()

        // Start any cues that overlap the new time
        for cue in cues {
            if currentTime >= cue.startTime && currentTime < cue.startTime + cue.duration {
                guard let player = players[cue.dialogueId] else { continue }
                let offset = max(0, TimeInterval(currentTime - cue.startTime))
                player.currentTime = offset
                player.volume = Float(volume)
                player.rate = Float(speed)
                player.play()
                currentlyPlayingIds.insert(cue.dialogueId)
            }
        }
    }

    // MARK: - Controls

    func pauseAll() {
        for dialogueId in currentlyPlayingIds {
            players[dialogueId]?.pause()
        }
    }

    func resumeAll(speed: Double) {
        self.speed = speed
        for dialogueId in currentlyPlayingIds {
            guard let player = players[dialogueId] else { continue }
            player.rate = Float(speed)
            player.play()
        }
    }

    func stopAll() {
        for (_, player) in players {
            player.stop()
            player.currentTime = 0
        }
        currentlyPlayingIds.removeAll()
    }

    func setVolume(_ vol: Double) {
        volume = vol
        for dialogueId in currentlyPlayingIds {
            players[dialogueId]?.volume = Float(vol)
        }
    }

    func setSpeed(_ spd: Double) {
        speed = spd
        for dialogueId in currentlyPlayingIds {
            players[dialogueId]?.rate = Float(spd)
        }
    }

    func stopCharacter(_ character: String) {
        for dialogueId in currentlyPlayingIds {
            if cueCharacterMap[dialogueId] == character {
                players[dialogueId]?.stop()
            }
        }
        currentlyPlayingIds = currentlyPlayingIds.filter { cueCharacterMap[$0] != character }
    }
}
