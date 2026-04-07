// DirectorsChairServices/Sources/DirectorsChairServices/Capture/SyncToneGenerator.swift
//
// Generates a known audio chirp pattern (3x linear frequency sweeps) for multi-device
// audio synchronization. The chirp's known waveform enables sub-millisecond detection
// via matched filtering in SyncToneDetector.

import Foundation
import AVFoundation
import Accelerate
import DirectorsChairCore

// MARK: - Sync Tone Configuration

/// Shared parameters between generator and detector — defines the chirp waveform
public struct SyncToneConfig {
    /// Start frequency of the linear sweep (Hz)
    public let startFrequency: Float = 2000
    /// End frequency of the linear sweep (Hz)
    public let endFrequency: Float = 6000
    /// Duration of a single chirp (seconds)
    public let chirpDuration: Float = 0.08
    /// Amplitude at peak (-12 dBFS ≈ 0.25)
    public let amplitude: Float = 0.25
    /// Number of chirps in a triplet pattern
    public let tripletCount: Int = 3
    /// Gap between chirps (seconds)
    public let gapDuration: Float = 0.20
    /// Default sample rate
    public let sampleRate: Float = 44100

    public static let shared = SyncToneConfig()

    /// Total duration of the full triplet pattern (seconds)
    public var totalDuration: Float {
        Float(tripletCount) * chirpDuration + Float(tripletCount - 1) * gapDuration
    }

    /// Expected spacing between chirp peaks in a triplet (seconds)
    public var expectedPeakSpacing: Double {
        Double(chirpDuration + gapDuration)
    }

    /// Generate samples for a single Hanning-windowed linear frequency sweep
    public func generateChirpSamples(sampleRate: Float? = nil) -> [Float] {
        let sr = sampleRate ?? self.sampleRate
        let numSamples = Int(chirpDuration * sr)
        var samples = [Float](repeating: 0, count: numSamples)

        let f0 = startFrequency
        let f1 = endFrequency
        let T = chirpDuration

        for i in 0..<numSamples {
            let t = Float(i) / sr

            // Linear chirp: f(t) = f0 + (f1-f0) * t / T
            // Phase integral: φ(t) = 2π * (f0*t + (f1-f0)*t²/(2T))
            let phase = 2.0 * Float.pi * (f0 * t + (f1 - f0) * t * t / (2.0 * T))

            // Hanning window for smooth envelope
            let window = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(numSamples - 1)))

            samples[i] = amplitude * window * sin(phase)
        }

        return samples
    }

    /// Generate the full triplet pattern (3 chirps with gaps)
    public func generateTripletSamples(sampleRate: Float? = nil) -> [Float] {
        let sr = sampleRate ?? self.sampleRate
        let chirp = generateChirpSamples(sampleRate: sr)
        let gapSamples = Int(gapDuration * sr)
        let gap = [Float](repeating: 0, count: gapSamples)

        var result: [Float] = []
        for i in 0..<tripletCount {
            result.append(contentsOf: chirp)
            if i < tripletCount - 1 {
                result.append(contentsOf: gap)
            }
        }
        return result
    }
}

// MARK: - Sync Tone Generator

/// Plays a sync tone chirp pattern through the default audio output.
/// The tone is captured by all devices in the room, enabling precise alignment.
public final class SyncToneGenerator: @unchecked Sendable {
    public static let shared = SyncToneGenerator()

    /// Notification posted when sync tone finishes playing
    public static let didPlayNotification = Notification.Name("syncTone.didPlay")

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private let config = SyncToneConfig.shared
    private var tripletSamples: [Float] = []
    private var sampleIndex: Int = 0
    private var isPlaying: Bool = false
    private let lock = NSLock()

    private init() {
        // Pre-generate samples for instant playback
        tripletSamples = config.generateTripletSamples()
    }

    /// Play the sync tone triplet through the default output device.
    /// Returns the wall-clock timestamp of when playback started.
    @discardableResult
    public func playTriplet() -> Date {
        lock.lock()
        guard !isPlaying else {
            lock.unlock()
            return Date()
        }
        isPlaying = true
        sampleIndex = 0
        lock.unlock()

        let timestamp = Date()

        do {
            let engine = AVAudioEngine()
            let outputFormat = engine.outputNode.outputFormat(forBus: 0)
            let sampleRate = Float(outputFormat.sampleRate)

            // Regenerate samples at the device's native sample rate if different
            let samples: [Float]
            if abs(sampleRate - config.sampleRate) > 1.0 {
                samples = config.generateTripletSamples(sampleRate: sampleRate)
            } else {
                samples = tripletSamples
            }
            let totalSamples = samples.count

            let sourceNode = AVAudioSourceNode(format: outputFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self else { return noErr }

                let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let framesToRender = Int(frameCount)

                self.lock.lock()
                let currentIndex = self.sampleIndex
                self.lock.unlock()

                for buffer in bufferList {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for frame in 0..<framesToRender {
                        let idx = currentIndex + frame
                        if idx < totalSamples {
                            data[frame] = samples[idx]
                        } else {
                            data[frame] = 0
                        }
                    }
                }

                self.lock.lock()
                self.sampleIndex += framesToRender

                if self.sampleIndex >= totalSamples {
                    self.isPlaying = false
                    self.lock.unlock()
                    // Stop engine on a background queue to avoid deadlock
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.stop()
                    }
                } else {
                    self.lock.unlock()
                }

                return noErr
            }

            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: outputFormat)
            try engine.start()

            self.engine = engine
            self.sourceNode = sourceNode

            print("[SyncToneGenerator] Playing sync tone triplet at \(Take.formatForCameraMatch(timestamp))")

            // Post notification
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: SyncToneGenerator.didPlayNotification,
                    object: nil,
                    userInfo: ["timestamp": timestamp]
                )
            }
        } catch {
            print("[SyncToneGenerator] Failed to play sync tone: \(error)")
            lock.lock()
            isPlaying = false
            lock.unlock()
        }

        return timestamp
    }

    /// Stop the audio engine and clean up
    public func stop() {
        engine?.stop()
        if let node = sourceNode {
            engine?.detach(node)
        }
        sourceNode = nil
        engine = nil
    }
}
