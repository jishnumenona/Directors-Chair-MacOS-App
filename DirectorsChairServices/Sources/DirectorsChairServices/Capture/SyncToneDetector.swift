// DirectorsChairServices/Sources/DirectorsChairServices/Capture/SyncToneDetector.swift
//
// Detects sync tone chirps in audio recordings using FFT-based matched filtering.
// The known chirp waveform (from SyncToneConfig) is cross-correlated with the recording
// to find precise tone positions, enabling sub-millisecond multi-device alignment.

import Foundation
import AVFoundation
import Accelerate
import DirectorsChairCore

// MARK: - Detection Result Types

/// A single detected sync tone peak
public struct SyncPeak {
    public let timestamp: Double       // seconds from audio start
    public let confidence: Double      // 0.0–1.0 normalized correlation
    public let isTriplet: Bool         // true if part of a confirmed 3-chirp triplet
}

/// Result of sync tone detection on an audio file
public struct SyncToneDetectionResult {
    public var peaks: [SyncPeak]
    public var audioDuration: Double
    public var sourceFile: String

    public var hasResults: Bool { !peaks.isEmpty }

    /// Best (highest confidence) peak
    public var bestPeak: SyncPeak? {
        peaks.max(by: { $0.confidence < $1.confidence })
    }

    /// All peak timestamps
    public var timestamps: [Double] {
        peaks.map { $0.timestamp }
    }

    /// All peak confidences
    public var confidences: [Double] {
        peaks.map { $0.confidence }
    }

    /// Apply detection results to a Take
    public func apply(to take: inout Take) {
        take.syncToneTimestamps = timestamps
        take.syncToneConfidences = confidences
    }
}

// MARK: - Detection Status

/// Progress status for the sync tone detection pipeline
public enum SyncDetectionStatus: Equatable {
    case idle
    case loadingAudio
    case filtering
    case correlating(progress: Double)
    case findingPeaks
    case completed
    case failed(String)

    public static func == (lhs: SyncDetectionStatus, rhs: SyncDetectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loadingAudio, .loadingAudio),
             (.filtering, .filtering), (.findingPeaks, .findingPeaks),
             (.completed, .completed):
            return true
        case let (.correlating(a), .correlating(b)):
            return a == b
        case let (.failed(a), .failed(b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Errors

public enum SyncToneDetectorError: LocalizedError {
    case cannotOpenFile
    case cannotReadAudio
    case noAudioData
    case conversionFailed

    public var errorDescription: String? {
        switch self {
        case .cannotOpenFile: return "Cannot open audio file"
        case .cannotReadAudio: return "Cannot read audio data"
        case .noAudioData: return "Audio file contains no data"
        case .conversionFailed: return "Audio format conversion failed"
        }
    }
}

// MARK: - Sync Tone Detector

/// Detects sync tone chirps in audio files via FFT cross-correlation
public final class SyncToneDetector: @unchecked Sendable {
    public static let shared = SyncToneDetector()

    private let config = SyncToneConfig.shared
    private let targetSampleRate: Float = 44100
    private let chirpTemplate: [Float]
    private let detectionThreshold: Float = 0.15  // minimum normalized correlation to consider

    private init() {
        chirpTemplate = config.generateChirpSamples(sampleRate: 44100)
    }

    // MARK: - Public API

    /// Detect sync tones in an audio or video file
    public func detect(
        inFileAt fileURL: URL,
        statusHandler: ((SyncDetectionStatus) -> Void)? = nil
    ) async throws -> SyncToneDetectionResult {
        debugLog("[SyncToneDetector] Starting detection for: \(fileURL.lastPathComponent)")

        // 1. Load audio as mono Float32
        statusHandler?(.loadingAudio)
        let (samples, sampleRate) = try loadAudioSamples(from: fileURL)
        let audioDuration = Double(samples.count) / Double(sampleRate)
        debugLog("[SyncToneDetector] Loaded \(samples.count) samples, \(sampleRate) Hz, \(String(format: "%.1f", audioDuration))s")

        guard !samples.isEmpty else {
            throw SyncToneDetectorError.noAudioData
        }

        // 2. Bandpass filter 1.5–7 kHz
        statusHandler?(.filtering)
        let filtered = bandpassFilter(samples, sampleRate: sampleRate)
        debugLog("[SyncToneDetector] Bandpass filter applied")

        // 3. Cross-correlate with chirp template
        statusHandler?(.correlating(progress: 0.0))
        let template: [Float]
        if abs(sampleRate - targetSampleRate) > 1.0 {
            template = config.generateChirpSamples(sampleRate: sampleRate)
        } else {
            template = chirpTemplate
        }
        let correlation = crossCorrelate(signal: filtered, template: template)
        statusHandler?(.correlating(progress: 1.0))
        debugLog("[SyncToneDetector] Cross-correlation computed (\(correlation.count) samples)")

        // 4. Normalize
        let signalPower = computeRMS(filtered)
        let normalized = normalize(correlation, signalRMS: signalPower)

        // 5. Find peaks
        statusHandler?(.findingPeaks)
        var peaks = findPeaks(in: normalized, sampleRate: sampleRate, threshold: detectionThreshold)
        debugLog("[SyncToneDetector] Found \(peaks.count) raw peaks")

        // 6. Sub-sample refinement
        peaks = peaks.map { peak in
            let sampleIndex = Int(peak.timestamp * Double(sampleRate))
            let refined = refinePeakPosition(correlation: normalized, peakIndex: sampleIndex, sampleRate: sampleRate)
            return SyncPeak(timestamp: refined, confidence: peak.confidence, isTriplet: peak.isTriplet)
        }

        // 7. Identify triplets
        peaks = identifyTriplets(peaks)
        debugLog("[SyncToneDetector] After triplet identification: \(peaks.count) peaks, \(peaks.filter { $0.isTriplet }.count) in triplets")

        for peak in peaks {
            debugLog("[SyncToneDetector]   \(String(format: "%.3f", peak.timestamp))s  conf=\(String(format: "%.3f", peak.confidence))  triplet=\(peak.isTriplet)")
        }

        statusHandler?(.completed)
        return SyncToneDetectionResult(
            peaks: peaks,
            audioDuration: audioDuration,
            sourceFile: fileURL.lastPathComponent
        )
    }

    /// Compute alignment offset between two detection results (e.g., DC recording vs camera footage)
    /// Returns the time offset to add to sourceB timestamps to align with sourceA
    public static func computeOffset(sourceA: SyncToneDetectionResult, sourceB: SyncToneDetectionResult) -> Double? {
        // Use first triplet peak from each, or best peak if no triplets
        let peakA = sourceA.peaks.first(where: { $0.isTriplet }) ?? sourceA.bestPeak
        let peakB = sourceB.peaks.first(where: { $0.isTriplet }) ?? sourceB.bestPeak

        guard let a = peakA, let b = peakB else { return nil }
        return a.timestamp - b.timestamp
    }

    // MARK: - Audio Loading

    /// Load audio from file as mono Float32 at native sample rate
    private func loadAudioSamples(from url: URL) throws -> (samples: [Float], sampleRate: Float) {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            debugLog("[SyncToneDetector] Cannot open file: \(error)")
            throw SyncToneDetectorError.cannotOpenFile
        }

        let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: audioFile.processingFormat.sampleRate,
            channels: 1,
            interleaved: false
        )!

        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
            throw SyncToneDetectorError.cannotReadAudio
        }

        // If formats differ, use converter
        if audioFile.processingFormat.channelCount != 1 ||
           audioFile.processingFormat.commonFormat != .pcmFormatFloat32 {
            guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: processingFormat) else {
                throw SyncToneDetectorError.conversionFailed
            }

            let sourceBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: frameCount
            )!

            try audioFile.read(into: sourceBuffer)

            var error: NSError?
            converter.convert(to: buffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return sourceBuffer
            }

            if let error {
                debugLog("[SyncToneDetector] Conversion error: \(error)")
                throw SyncToneDetectorError.conversionFailed
            }
        } else {
            try audioFile.read(into: buffer)
        }

        guard let channelData = buffer.floatChannelData?[0] else {
            throw SyncToneDetectorError.noAudioData
        }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        return (samples, Float(processingFormat.sampleRate))
    }

    // MARK: - Bandpass Filter

    /// Apply a bandpass filter (1.5–7 kHz) using cascaded biquad sections via vDSP_deq22
    private func bandpassFilter(_ signal: [Float], sampleRate: Float) -> [Float] {
        // Design 2nd-order Butterworth bandpass filter
        let lowFreq: Float = 1500
        let highFreq: Float = 7000
        let centerFreq = sqrt(lowFreq * highFreq)
        let bandwidth = highFreq - lowFreq

        let w0 = 2.0 * Float.pi * centerFreq / sampleRate
        let Q = centerFreq / bandwidth
        let alpha = sin(w0) / (2.0 * Q)

        // Bandpass filter coefficients (constant 0 dB peak gain)
        let b0 = alpha
        let b1: Float = 0
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos(w0)
        let a2 = 1.0 - alpha

        // Normalize coefficients for vDSP_deq22: [b0/a0, b1/a0, b2/a0, a1/a0, a2/a0]
        let coefficients: [Float] = [b0/a0, b1/a0, b2/a0, a1/a0, a2/a0]

        var output = [Float](repeating: 0, count: signal.count)
        var delays = [Float](repeating: 0, count: signal.count + 2)

        // Copy input with 2-sample padding
        for i in 0..<signal.count {
            delays[i + 2] = signal[i]
        }

        vDSP_deq22(&delays, 1, coefficients, &output, 1, vDSP_Length(signal.count))

        return output
    }

    // MARK: - Cross-Correlation

    /// FFT-based cross-correlation: C = IFFT(FFT(signal) * conj(FFT(template)))
    private func crossCorrelate(signal: [Float], template: [Float]) -> [Float] {
        // Pad to next power of 2
        let n = signal.count + template.count - 1
        let fftLength = nextPowerOf2(n)
        let log2n = vDSP_Length(log2(Float(fftLength)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            debugLog("[SyncToneDetector] Failed to create FFT setup")
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfN = fftLength / 2

        // Prepare signal — zero-padded
        var signalReal = [Float](repeating: 0, count: halfN)
        var signalImag = [Float](repeating: 0, count: halfN)
        var paddedSignal = [Float](repeating: 0, count: fftLength)
        for i in 0..<signal.count { paddedSignal[i] = signal[i] }

        // Convert to split complex using safe pointer access
        paddedSignal.withUnsafeBufferPointer { ptr in
            signalReal.withUnsafeMutableBufferPointer { realBuf in
                signalImag.withUnsafeMutableBufferPointer { imagBuf in
                    var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
            }
        }

        // FFT of signal
        signalReal.withUnsafeMutableBufferPointer { realBuf in
            signalImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        // Prepare template — zero-padded
        var templateReal = [Float](repeating: 0, count: halfN)
        var templateImag = [Float](repeating: 0, count: halfN)
        var paddedTemplate = [Float](repeating: 0, count: fftLength)
        for i in 0..<template.count { paddedTemplate[i] = template[i] }

        paddedTemplate.withUnsafeBufferPointer { ptr in
            templateReal.withUnsafeMutableBufferPointer { realBuf in
                templateImag.withUnsafeMutableBufferPointer { imagBuf in
                    var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
            }
        }

        // FFT of template
        templateReal.withUnsafeMutableBufferPointer { realBuf in
            templateImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        // Multiply signal FFT by conjugate of template FFT
        // conj(template) = (real, -imag)
        // (a+bi)(c-di) = (ac+bd) + (bc-ad)i
        var resultReal = [Float](repeating: 0, count: halfN)
        var resultImag = [Float](repeating: 0, count: halfN)

        for i in 0..<halfN {
            let sr = signalReal[i], si = signalImag[i]
            let tr = templateReal[i], ti = templateImag[i]
            resultReal[i] = sr * tr + si * ti
            resultImag[i] = si * tr - sr * ti
        }

        // IFFT
        resultReal.withUnsafeMutableBufferPointer { realBuf in
            resultImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
            }
        }

        // Convert back to real
        var output = [Float](repeating: 0, count: fftLength)
        output.withUnsafeMutableBufferPointer { outBuf in
            resultReal.withUnsafeMutableBufferPointer { realBuf in
                resultImag.withUnsafeMutableBufferPointer { imagBuf in
                    var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                    outBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ztoc(&split, 1, complexPtr, 2, vDSP_Length(halfN))
                    }
                }
            }
        }

        // Scale by 1/N
        var scale = 1.0 / Float(fftLength)
        vDSP_vsmul(output, 1, &scale, &output, 1, vDSP_Length(fftLength))

        // Return only valid correlation length
        return Array(output.prefix(n))
    }

    // MARK: - Normalization

    /// Compute RMS of a signal
    private func computeRMS(_ signal: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(signal, 1, &rms, vDSP_Length(signal.count))
        return rms
    }

    /// Normalize correlation to be volume-independent (0.0–1.0 range)
    private func normalize(_ correlation: [Float], signalRMS: Float) -> [Float] {
        let templateRMS = computeRMS(chirpTemplate)
        let normFactor = signalRMS * templateRMS * Float(chirpTemplate.count)

        guard normFactor > 0 else { return correlation }

        var output = [Float](repeating: 0, count: correlation.count)
        var divisor = normFactor
        vDSP_vsdiv(correlation, 1, &divisor, &output, 1, vDSP_Length(correlation.count))

        // Take absolute value (correlation can be negative)
        vDSP_vabs(output, 1, &output, 1, vDSP_Length(output.count))

        return output
    }

    // MARK: - Peak Detection

    /// Find local maxima above threshold with minimum separation
    private func findPeaks(in correlation: [Float], sampleRate: Float, threshold: Float) -> [SyncPeak] {
        let minSeparationSamples = Int(0.05 * sampleRate) // 50ms minimum between peaks
        var peaks: [SyncPeak] = []
        var lastPeakIndex = -minSeparationSamples

        for i in 1..<(correlation.count - 1) {
            // Local maximum check
            guard correlation[i] > correlation[i - 1],
                  correlation[i] > correlation[i + 1],
                  correlation[i] > threshold,
                  i - lastPeakIndex >= minSeparationSamples else { continue }

            let timestamp = Double(i) / Double(sampleRate)
            peaks.append(SyncPeak(
                timestamp: timestamp,
                confidence: Double(correlation[i]),
                isTriplet: false
            ))
            lastPeakIndex = i
        }

        return peaks
    }

    /// Parabolic interpolation around a peak for sub-sample accuracy
    private func refinePeakPosition(correlation: [Float], peakIndex: Int, sampleRate: Float) -> Double {
        guard peakIndex > 0, peakIndex < correlation.count - 1 else {
            return Double(peakIndex) / Double(sampleRate)
        }

        let alpha = correlation[peakIndex - 1]
        let beta = correlation[peakIndex]
        let gamma = correlation[peakIndex + 1]

        // Parabolic interpolation: offset = 0.5 * (alpha - gamma) / (alpha - 2*beta + gamma)
        let denominator = alpha - 2 * beta + gamma
        guard abs(denominator) > 1e-10 else {
            return Double(peakIndex) / Double(sampleRate)
        }

        let offset = 0.5 * Double(alpha - gamma) / Double(denominator)
        return (Double(peakIndex) + offset) / Double(sampleRate)
    }

    // MARK: - Triplet Identification

    /// Group peaks spaced ~280ms (chirpDuration + gapDuration) apart and mark as triplets
    private func identifyTriplets(_ peaks: [SyncPeak]) -> [SyncPeak] {
        guard peaks.count >= 3 else { return peaks }

        let expectedSpacing = config.expectedPeakSpacing
        let tolerance = 0.025 // ±25ms

        var result = peaks
        var usedIndices = Set<Int>()

        for i in 0..<peaks.count {
            guard !usedIndices.contains(i) else { continue }

            // Try to find 2 more peaks at expected spacing
            var tripletIndices = [i]

            for j in (i + 1)..<peaks.count {
                guard !usedIndices.contains(j) else { continue }
                let spacing = peaks[j].timestamp - peaks[tripletIndices.last!].timestamp

                if abs(spacing - expectedSpacing) < tolerance {
                    tripletIndices.append(j)
                    if tripletIndices.count == 3 { break }
                } else if spacing > expectedSpacing + tolerance {
                    break // too far apart, stop looking
                }
            }

            if tripletIndices.count == 3 {
                for idx in tripletIndices {
                    result[idx] = SyncPeak(
                        timestamp: result[idx].timestamp,
                        confidence: result[idx].confidence,
                        isTriplet: true
                    )
                    usedIndices.insert(idx)
                }
            }
        }

        return result
    }

    // MARK: - Utilities

    private func nextPowerOf2(_ n: Int) -> Int {
        var v = n - 1
        v |= v >> 1
        v |= v >> 2
        v |= v >> 4
        v |= v >> 8
        v |= v >> 16
        return v + 1
    }
}
