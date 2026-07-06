// DirectorsChairServices/Sources/DirectorsChairServices/Capture/ActionCutDetector.swift
//
// Speech-recognition-based "Action" and "Cut" cue detector for recorded takes.
// Extracts audio from the first and last 30 seconds of a video, runs SFSpeechRecognizer,
// and fuzzy-matches recognized words to action/cut vocabularies.

import Foundation
import AVFoundation
import Speech
import DirectorsChairCore

// MARK: - Detection Result

/// Result of Action/Cut audio cue detection on a take's video
public struct ActionCutDetectionResult {
    public var actionTimestamp: Double?
    public var cutTimestamp: Double?
    public var detectedActionWord: String?
    public var detectedCutWord: String?
    public var actionConfidence: Double?
    public var cutConfidence: Double?
    public var videoDuration: Double = 0

    /// Whether any cue was detected
    public var hasResults: Bool {
        actionTimestamp != nil || cutTimestamp != nil
    }

    /// Apply detection results to a Take
    public func apply(to take: inout Take) {
        take.actionTimestamp = actionTimestamp
        take.cutTimestamp = cutTimestamp
        take.detectedActionWord = detectedActionWord
        take.detectedCutWord = detectedCutWord
        take.actionConfidence = actionConfidence
        take.cutConfidence = cutConfidence
    }
}

// MARK: - Detection Status

/// Progress status for the detection pipeline
public enum DetectionStatus: Equatable {
    case idle
    case extractingAudio
    case recognizingSpeech(progress: Double)
    case analyzing
    case completed
    case failed(String)

    public static func == (lhs: DetectionStatus, rhs: DetectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.extractingAudio, .extractingAudio),
             (.analyzing, .analyzing), (.completed, .completed):
            return true
        case let (.recognizingSpeech(a), .recognizingSpeech(b)):
            return a == b
        case let (.failed(a), .failed(b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Errors

public enum ActionCutDetectorError: LocalizedError {
    case permissionDenied
    case noAudioTrack
    case cannotReadAudio
    case speechRecognizerUnavailable
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Speech recognition permission denied"
        case .noAudioTrack: return "Video has no audio track"
        case .cannotReadAudio: return "Cannot read audio from video"
        case .speechRecognizerUnavailable: return "Speech recognizer unavailable"
        case .exportFailed(let msg): return "Audio export failed: \(msg)"
        }
    }
}

// MARK: - Recognized Word

/// A single word recognized with its timestamp and confidence
private struct RecognizedWord {
    let word: String
    let timestamp: Double          // seconds from segment start
    let confidence: Float
    let segmentOffset: Double      // offset to add for absolute video time
}

// MARK: - Action/Cut Detector

public final class ActionCutDetector: @unchecked Sendable {
    public static let shared = ActionCutDetector()

    private init() {}

    /// Minimum combined score to accept a match
    private let minimumMatchScore: Double = 0.3

    // MARK: - Known Word Variants

    /// Known misrecognitions and variants for "action" with base scores
    private let actionVariants: [String: Double] = [
        "action": 1.0,
        "actions": 0.95,
        "acting": 0.6,
        "auction": 0.4,
        "accent": 0.35,
        "axion": 0.7,
        "and action": 1.0,
    ]

    /// Known misrecognitions and variants for "cut" with base scores
    private let cutVariants: [String: Double] = [
        "cut": 1.0,
        "cut!": 1.0,
        "cuts": 0.95,
        "and cut": 1.0,
        "gut": 0.5,
        "but": 0.35,
        "cut it": 0.9,
        "caught": 0.4,
        "cup": 0.35,
    ]

    // MARK: - Public API

    /// Detect Action and Cut cues in a video file
    /// - Parameters:
    ///   - videoURL: URL to the video file
    ///   - statusHandler: Optional callback for progress updates
    /// - Returns: Detection result with timestamps and confidence
    public func detect(
        inVideoAt videoURL: URL,
        statusHandler: ((DetectionStatus) -> Void)? = nil
    ) async throws -> ActionCutDetectionResult {
        debugLog("[ActionCutDetector] Starting detection for: \(videoURL.lastPathComponent)")

        // 1. Check speech recognition authorization
        let authStatus = await requestSpeechAuthorization()
        debugLog("[ActionCutDetector] Auth status: \(authStatus.rawValue)")
        guard authStatus == .authorized else {
            debugLog("[ActionCutDetector] DENIED — speech recognition not authorized")
            statusHandler?(.failed("Permission denied"))
            throw ActionCutDetectorError.permissionDenied
        }

        // 2. Get video duration
        statusHandler?(.extractingAudio)
        let asset = AVURLAsset(url: videoURL)
        let duration: Double
        if #available(macOS 15, *) {
            duration = try await asset.load(.duration).seconds
        } else {
            duration = asset.duration.seconds
        }
        debugLog("[ActionCutDetector] Video duration: \(duration)s")
        guard duration > 0 else {
            statusHandler?(.failed("Invalid video duration"))
            throw ActionCutDetectorError.cannotReadAudio
        }

        // 3. Check for audio track
        let audioTracks: [AVAssetTrack]
        if #available(macOS 15, *) {
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } else {
            audioTracks = asset.tracks(withMediaType: .audio)
        }
        debugLog("[ActionCutDetector] Audio tracks: \(audioTracks.count)")
        guard !audioTracks.isEmpty else {
            statusHandler?(.failed("No audio track"))
            throw ActionCutDetectorError.noAudioTrack
        }

        // 4. Run speech recognition directly on the video file
        statusHandler?(.recognizingSpeech(progress: 0.3))
        let allWords = try await recognizeSpeech(fileURL: videoURL)
        debugLog("[ActionCutDetector] Recognized \(allWords.count) words")
        for w in allWords {
            debugLog("[ActionCutDetector]   \(String(format: "%.1f", w.timestamp))s: \"\(w.word)\" (conf: \(String(format: "%.2f", w.confidence)))")
        }

        // 5. Analyze words for action/cut cues
        statusHandler?(.analyzing)
        var result = analyzeWords(allWords, videoDuration: duration)
        result.videoDuration = duration

        debugLog("[ActionCutDetector] Result — action: \(result.actionTimestamp.map { String(format: "%.1f", $0) } ?? "nil"), cut: \(result.cutTimestamp.map { String(format: "%.1f", $0) } ?? "nil")")
        statusHandler?(.completed)
        return result
    }

    // MARK: - Speech Authorization

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Speech Recognition

    /// Run SFSpeechRecognizer directly on a video/audio file and return word-level results
    private func recognizeSpeech(fileURL: URL) async throws -> [RecognizedWord] {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            debugLog("[ActionCutDetector] Speech recognizer unavailable")
            throw ActionCutDetectorError.speechRecognizerUnavailable
        }

        debugLog("[ActionCutDetector] Starting speech recognition on: \(fileURL.lastPathComponent)")
        debugLog("[ActionCutDetector] Recognizer locale: \(recognizer.locale), available: \(recognizer.isAvailable), supportsOnDevice: \(recognizer.supportsOnDeviceRecognition)")

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        // Must enable partial results — on-device recognition sometimes returns empty final result
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            debugLog("[ActionCutDetector] Using on-device recognition")
        }

        var hasResumed = false
        // Track best partial result since final can be empty with on-device recognition
        var bestWords: [RecognizedWord] = []

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if hasResumed { return }

                if let error = error {
                    debugLog("[ActionCutDetector] Speech recognition error: \(error.localizedDescription)")
                    // Return whatever we collected from partials
                    hasResumed = true
                    continuation.resume(returning: bestWords)
                    return
                }

                guard let result = result else { return }

                // Extract words from this result (partial or final)
                let segments = result.bestTranscription.segments
                debugLog("[ActionCutDetector] Got result, isFinal: \(result.isFinal), segments: \(segments.count), text: \"\(result.bestTranscription.formattedString)\"")

                if !segments.isEmpty {
                    var words: [RecognizedWord] = []
                    for segment in segments {
                        let word = RecognizedWord(
                            word: segment.substring.lowercased(),
                            timestamp: segment.timestamp,
                            confidence: segment.confidence,
                            segmentOffset: 0
                        )
                        words.append(word)
                    }
                    // Keep the result with the most words
                    if words.count >= bestWords.count {
                        bestWords = words
                    }
                }

                if result.isFinal {
                    hasResumed = true
                    continuation.resume(returning: bestWords)
                }
            }
        }
    }

    // MARK: - Word Analysis

    /// Analyze recognized words to find the best action and cut matches
    private func analyzeWords(_ words: [RecognizedWord], videoDuration: Double) -> ActionCutDetectionResult {
        var result = ActionCutDetectionResult()

        // Find best "action" match — prefer matches in the first 40% of video
        let actionCutoff = videoDuration * 0.4
        var bestActionScore: Double = 0

        for word in words {
            let absoluteTime = word.timestamp + word.segmentOffset
            guard absoluteTime <= actionCutoff else { continue }

            let score = matchScore(word: word.word, against: actionVariants, speechConfidence: word.confidence)
            if score > bestActionScore && score >= minimumMatchScore {
                bestActionScore = score
                result.actionTimestamp = absoluteTime
                result.detectedActionWord = word.word
                result.actionConfidence = score
            }
        }

        // Find best "cut" match — prefer the LAST match in the last 40% of video
        let cutStart = videoDuration * 0.6
        var bestCutScore: Double = 0

        for word in words {
            let absoluteTime = word.timestamp + word.segmentOffset
            guard absoluteTime >= cutStart else { continue }

            let score = matchScore(word: word.word, against: cutVariants, speechConfidence: word.confidence)
            if score >= minimumMatchScore && (score > bestCutScore || absoluteTime > (result.cutTimestamp ?? 0)) {
                bestCutScore = score
                result.cutTimestamp = absoluteTime
                result.detectedCutWord = word.word
                result.cutConfidence = score
            }
        }

        // If no cut found in last 40%, search the whole video for a cut after the action
        if result.cutTimestamp == nil, let actionTime = result.actionTimestamp {
            for word in words {
                let absoluteTime = word.timestamp + word.segmentOffset
                guard absoluteTime > actionTime + 1.0 else { continue } // at least 1s after action

                let score = matchScore(word: word.word, against: cutVariants, speechConfidence: word.confidence)
                if score >= minimumMatchScore {
                    // Take the last good match
                    result.cutTimestamp = absoluteTime
                    result.detectedCutWord = word.word
                    result.cutConfidence = score
                }
            }
        }

        return result
    }

    /// Calculate match score for a word against a vocabulary
    private func matchScore(word: String, against variants: [String: Double], speechConfidence: Float) -> Double {
        let lowered = word.lowercased().trimmingCharacters(in: .punctuationCharacters)

        // Check known variants first
        if let variantScore = variants[lowered] {
            return variantScore * Double(max(speechConfidence, 0.3))
        }

        // Levenshtein distance fallback against each variant key
        var bestFuzzyScore: Double = 0
        for (variant, variantScore) in variants {
            let similarity = levenshteinSimilarity(lowered, variant)
            if similarity > 0.6 {
                let score = similarity * variantScore * Double(max(speechConfidence, 0.3))
                bestFuzzyScore = max(bestFuzzyScore, score)
            }
        }

        return bestFuzzyScore
    }

    /// Levenshtein similarity (1.0 = identical, 0.0 = completely different)
    private func levenshteinSimilarity(_ a: String, _ b: String) -> Double {
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count

        if aLen == 0 && bLen == 0 { return 1.0 }
        if aLen == 0 || bLen == 0 { return 0.0 }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bLen + 1), count: aLen + 1)

        for i in 0...aLen { matrix[i][0] = i }
        for j in 0...bLen { matrix[0][j] = j }

        for i in 1...aLen {
            for j in 1...bLen {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        let distance = Double(matrix[aLen][bLen])
        let maxLen = Double(max(aLen, bLen))
        return 1.0 - (distance / maxLen)
    }
}
