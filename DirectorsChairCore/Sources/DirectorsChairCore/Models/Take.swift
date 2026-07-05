// DirectorsChairCore/Sources/DirectorsChairCore/Models/Take.swift
//
// Take model for production shooting workflow
// Tracks individual takes per shot with ratings, notes, and video paths

import Foundation

/// Rating for a take — used by AD/editor on set
public enum TakeRating: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case none = "None"
    case circle = "Circle"
    case alt = "Alt"
    case ng = "NG"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .none: return "circle"
        case .circle: return "checkmark.circle.fill"
        case .alt: return "arrow.triangle.branch"
        case .ng: return "xmark.circle.fill"
        }
    }

    public var color: String {
        switch self {
        case .none: return "gray"
        case .circle: return "green"
        case .alt: return "orange"
        case .ng: return "red"
        }
    }
}

/// Represents a single take of a shot during production
public struct Take: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var takeNumber: Int
    public var notes: String
    public var rating: TakeRating
    public var tags: [String]
    public var startTimestamp: Date?
    public var endTimestamp: Date?
    public var capturedVideoPath: String?
    public var cameraSourceFileName: String?
    public var thumbnailPath: String?
    public var durationSeconds: Double?

    // MARK: - Camera Footage Metadata (OCR-extracted from viewfinder overlay)

    public var cameraClipName: String?         // e.g. "C0575"
    public var cameraResolution: String?       // e.g. "4K"
    public var cameraFrameRate: String?        // e.g. "23.98"
    public var cameraISO: String?              // e.g. "800EI"
    public var cameraAperture: String?         // e.g. "4.3E/H"
    public var cameraWhiteBalance: String?     // e.g. "3500K"
    public var cameraTimecode: String?         // e.g. "02:44:52:01"
    public var cameraLUT: String?              // e.g. "LUT Off"
    public var cameraFocusMode: String?        // e.g. "MF"
    public var externalAudioFileName: String?  // external audio recording file
    public var useAudioFromVideo: Bool         // true = audio sourced from camera video file (no external audio needed)
    public var isAudioVideoSynced: Bool?       // nil = not checked, true = synced, false = not synced

    // MARK: - Audio Cue Detection (Action/Cut speech recognition)

    public var actionTimestamp: Double?        // seconds from video start where "Action" was detected
    public var cutTimestamp: Double?           // seconds from video start where "Cut" was detected
    public var detectedActionWord: String?     // actual word recognized (e.g. "action", "actions")
    public var detectedCutWord: String?        // actual word recognized (e.g. "cut", "and cut")
    public var actionConfidence: Double?       // 0.0–1.0 combined confidence
    public var cutConfidence: Double?          // 0.0–1.0 combined confidence

    // MARK: - Sync Tone Detection

    public var syncTonePlayedAt: Date?              // Wall-clock time when tone triggered
    public var syncToneRecordingOffset: Double?      // Seconds into DC recording when tone played
    public var syncToneTimestamps: [Double]?         // Detected tone positions (seconds from video start)
    public var syncToneConfidences: [Double]?        // Confidence per detection (0.0-1.0)
    public var syncOffset: Double?                   // Computed offset: camera footage vs DC recording

    /// Whether any camera metadata has been extracted for this take
    public var hasCameraMetadata: Bool {
        cameraClipName != nil || cameraResolution != nil || cameraFrameRate != nil ||
        cameraISO != nil || cameraAperture != nil || cameraWhiteBalance != nil ||
        cameraTimecode != nil || cameraLUT != nil || cameraFocusMode != nil
    }

    /// Whether audio cue detection has been performed (either action or cut found)
    public var hasAudioCueDetection: Bool {
        actionTimestamp != nil || cutTimestamp != nil
    }

    /// Whether sync tone detection has been performed
    public var hasSyncToneDetection: Bool {
        syncToneTimestamps != nil && !(syncToneTimestamps?.isEmpty ?? true)
    }

    /// Best sync tone confidence (highest among detected tones)
    public var bestSyncConfidence: Double? {
        syncToneConfidences?.max()
    }

    /// Duration of the "useful" portion between action and cut cues
    public var usefulDuration: Double? {
        guard let action = actionTimestamp, let cut = cutTimestamp, cut > action else { return nil }
        return cut - action
    }

    // MARK: - Camera-Compatible Timestamp Formatter

    /// Formats dates in the same style as camera file metadata (EXIF / file system creation date).
    /// Format: `yyyy-MM-dd HH:mm:ss` — matches macOS file metadata, Finder Get Info, and video NLE timelines.
    /// Use this for both take timestamps and camera file creation dates so values are directly comparable.
    public static let cameraTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// The record-button-press timestamp formatted for camera file matching.
    /// Returns `nil` if `startTimestamp` is not set.
    public var formattedStartTimestamp: String? {
        guard let ts = startTimestamp else { return nil }
        return Take.cameraTimestampFormatter.string(from: ts)
    }

    /// The recording-end timestamp formatted for camera file matching.
    public var formattedEndTimestamp: String? {
        guard let ts = endTimestamp else { return nil }
        return Take.cameraTimestampFormatter.string(from: ts)
    }

    /// Formats any Date using the camera-compatible formatter.
    public static func formatForCameraMatch(_ date: Date) -> String {
        cameraTimestampFormatter.string(from: date)
    }

    public init(
        id: String = UUID().uuidString,
        takeNumber: Int = 1,
        notes: String = "",
        rating: TakeRating = .none,
        tags: [String] = [],
        startTimestamp: Date? = nil,
        endTimestamp: Date? = nil,
        capturedVideoPath: String? = nil,
        cameraSourceFileName: String? = nil,
        thumbnailPath: String? = nil,
        durationSeconds: Double? = nil,
        cameraClipName: String? = nil,
        cameraResolution: String? = nil,
        cameraFrameRate: String? = nil,
        cameraISO: String? = nil,
        cameraAperture: String? = nil,
        cameraWhiteBalance: String? = nil,
        cameraTimecode: String? = nil,
        cameraLUT: String? = nil,
        cameraFocusMode: String? = nil,
        externalAudioFileName: String? = nil,
        useAudioFromVideo: Bool = false,
        isAudioVideoSynced: Bool? = nil,
        actionTimestamp: Double? = nil,
        cutTimestamp: Double? = nil,
        detectedActionWord: String? = nil,
        detectedCutWord: String? = nil,
        actionConfidence: Double? = nil,
        cutConfidence: Double? = nil,
        syncTonePlayedAt: Date? = nil,
        syncToneRecordingOffset: Double? = nil,
        syncToneTimestamps: [Double]? = nil,
        syncToneConfidences: [Double]? = nil,
        syncOffset: Double? = nil
    ) {
        self.id = id
        self.takeNumber = takeNumber
        self.notes = notes
        self.rating = rating
        self.tags = tags
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.capturedVideoPath = capturedVideoPath
        self.cameraSourceFileName = cameraSourceFileName
        self.thumbnailPath = thumbnailPath
        self.durationSeconds = durationSeconds
        self.cameraClipName = cameraClipName
        self.cameraResolution = cameraResolution
        self.cameraFrameRate = cameraFrameRate
        self.cameraISO = cameraISO
        self.cameraAperture = cameraAperture
        self.cameraWhiteBalance = cameraWhiteBalance
        self.cameraTimecode = cameraTimecode
        self.cameraLUT = cameraLUT
        self.cameraFocusMode = cameraFocusMode
        self.externalAudioFileName = externalAudioFileName
        self.useAudioFromVideo = useAudioFromVideo
        self.isAudioVideoSynced = isAudioVideoSynced
        self.actionTimestamp = actionTimestamp
        self.cutTimestamp = cutTimestamp
        self.detectedActionWord = detectedActionWord
        self.detectedCutWord = detectedCutWord
        self.actionConfidence = actionConfidence
        self.cutConfidence = cutConfidence
        self.syncTonePlayedAt = syncTonePlayedAt
        self.syncToneRecordingOffset = syncToneRecordingOffset
        self.syncToneTimestamps = syncToneTimestamps
        self.syncToneConfidences = syncToneConfidences
        self.syncOffset = syncOffset
    }

    enum CodingKeys: String, CodingKey {
        case id
        case takeNumber = "take_number"
        case notes
        case rating
        case tags
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case capturedVideoPath = "captured_video_path"
        case cameraSourceFileName = "camera_source_file_name"
        case thumbnailPath = "thumbnail_path"
        case durationSeconds = "duration_seconds"
        case cameraClipName = "camera_clip_name"
        case cameraResolution = "camera_resolution"
        case cameraFrameRate = "camera_frame_rate"
        case cameraISO = "camera_iso"
        case cameraAperture = "camera_aperture"
        case cameraWhiteBalance = "camera_white_balance"
        case cameraTimecode = "camera_timecode"
        case cameraLUT = "camera_lut"
        case cameraFocusMode = "camera_focus_mode"
        case externalAudioFileName = "external_audio_file_name"
        case useAudioFromVideo = "use_audio_from_video"
        case isAudioVideoSynced = "is_audio_video_synced"
        case actionTimestamp = "action_timestamp"
        case cutTimestamp = "cut_timestamp"
        case detectedActionWord = "detected_action_word"
        case detectedCutWord = "detected_cut_word"
        case actionConfidence = "action_confidence"
        case cutConfidence = "cut_confidence"
        case syncTonePlayedAt = "sync_tone_played_at"
        case syncToneRecordingOffset = "sync_tone_recording_offset"
        case syncToneTimestamps = "sync_tone_timestamps"
        case syncToneConfidences = "sync_tone_confidences"
        case syncOffset = "sync_offset"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        takeNumber = try container.decodeIfPresent(Int.self, forKey: .takeNumber) ?? 1
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        rating = try container.decodeIfPresent(TakeRating.self, forKey: .rating) ?? .none
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        startTimestamp = try container.decodeIfPresent(Date.self, forKey: .startTimestamp)
        endTimestamp = try container.decodeIfPresent(Date.self, forKey: .endTimestamp)
        capturedVideoPath = try container.decodeIfPresent(String.self, forKey: .capturedVideoPath)
        cameraSourceFileName = try container.decodeIfPresent(String.self, forKey: .cameraSourceFileName)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        cameraClipName = try container.decodeIfPresent(String.self, forKey: .cameraClipName)
        cameraResolution = try container.decodeIfPresent(String.self, forKey: .cameraResolution)
        cameraFrameRate = try container.decodeIfPresent(String.self, forKey: .cameraFrameRate)
        cameraISO = try container.decodeIfPresent(String.self, forKey: .cameraISO)
        cameraAperture = try container.decodeIfPresent(String.self, forKey: .cameraAperture)
        cameraWhiteBalance = try container.decodeIfPresent(String.self, forKey: .cameraWhiteBalance)
        cameraTimecode = try container.decodeIfPresent(String.self, forKey: .cameraTimecode)
        cameraLUT = try container.decodeIfPresent(String.self, forKey: .cameraLUT)
        cameraFocusMode = try container.decodeIfPresent(String.self, forKey: .cameraFocusMode)
        externalAudioFileName = try container.decodeIfPresent(String.self, forKey: .externalAudioFileName)
        useAudioFromVideo = try container.decodeIfPresent(Bool.self, forKey: .useAudioFromVideo) ?? false
        isAudioVideoSynced = try container.decodeIfPresent(Bool.self, forKey: .isAudioVideoSynced)
        actionTimestamp = try container.decodeIfPresent(Double.self, forKey: .actionTimestamp)
        cutTimestamp = try container.decodeIfPresent(Double.self, forKey: .cutTimestamp)
        detectedActionWord = try container.decodeIfPresent(String.self, forKey: .detectedActionWord)
        detectedCutWord = try container.decodeIfPresent(String.self, forKey: .detectedCutWord)
        actionConfidence = try container.decodeIfPresent(Double.self, forKey: .actionConfidence)
        cutConfidence = try container.decodeIfPresent(Double.self, forKey: .cutConfidence)
        syncTonePlayedAt = try container.decodeIfPresent(Date.self, forKey: .syncTonePlayedAt)
        syncToneRecordingOffset = try container.decodeIfPresent(Double.self, forKey: .syncToneRecordingOffset)
        syncToneTimestamps = try container.decodeIfPresent([Double].self, forKey: .syncToneTimestamps)
        syncToneConfidences = try container.decodeIfPresent([Double].self, forKey: .syncToneConfidences)
        syncOffset = try container.decodeIfPresent(Double.self, forKey: .syncOffset)
    }
}
