// DirectorsChairCore/Sources/DirectorsChairCore/Models/Take.swift
//
// Take model for production shooting workflow
// Tracks individual takes per shot with ratings, notes, and video paths

import Foundation

/// Rating for a take — used by AD/editor on set
public enum TakeRating: String, Codable, CaseIterable, Identifiable, Hashable {
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
public struct Take: Codable, Identifiable, Hashable {
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
        durationSeconds: Double? = nil
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
    }
}
