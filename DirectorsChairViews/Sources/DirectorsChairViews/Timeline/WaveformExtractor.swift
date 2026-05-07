// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/WaveformExtractor.swift
//
// Extracts peak-envelope waveform samples from audio files for timeline rendering.

import Foundation
import AVFoundation

/// Extracts downsampled waveform amplitude data from audio files.
/// Runs synchronously — call from a background queue if needed.
public struct WaveformExtractor {
    /// Number of output samples for the waveform
    public static let defaultSampleCount = 4096

    /// Result of waveform extraction
    public struct WaveformData {
        public let samples: [Float]
        public let duration: Double
    }

    /// Extract peak-envelope waveform from an audio file URL.
    /// Returns downsampled amplitude data and total duration.
    public static func extract(from url: URL, sampleCount: Int = defaultSampleCount) throws -> WaveformData {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0 else {
            return WaveformData(samples: [], duration: 0)
        }

        let duration = Double(frameCount) / format.sampleRate

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return WaveformData(samples: [], duration: duration)
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            return WaveformData(samples: [], duration: duration)
        }

        let channelCount = Int(format.channelCount)
        let totalFrames = Int(buffer.frameLength)
        let framesPerSample = max(1, totalFrames / sampleCount)
        let actualSampleCount = min(sampleCount, totalFrames)

        var samples = [Float](repeating: 0, count: actualSampleCount)

        for i in 0..<actualSampleCount {
            let startFrame = i * framesPerSample
            let endFrame = min(startFrame + framesPerSample, totalFrames)
            var peak: Float = 0

            for frame in startFrame..<endFrame {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += abs(channelData[ch][frame])
                }
                let avg = sum / Float(channelCount)
                if avg > peak { peak = avg }
            }

            samples[i] = peak
        }

        // Normalize to 0…1
        let maxPeak = samples.max() ?? 1.0
        if maxPeak > 0 {
            for i in 0..<samples.count {
                samples[i] /= maxPeak
            }
        }

        return WaveformData(samples: samples, duration: duration)
    }
}
