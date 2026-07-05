// DirectorsChairCore/Sources/DirectorsChairCore/Models/SoundtrackTrack.swift
//
// Model for soundtrack/audio tracks on the timeline

import Foundation

/// Represents an imported audio file (music, ambient, SFX) positioned on the timeline.
/// Waveform samples are pre-computed at import time for efficient rendering.
public struct SoundtrackTrack: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String                 // "Background Music"
    public var audioFilePath: String        // "assets/audio/soundtracks/{id}.mp3"
    public var startTimeOffset: Double      // seconds offset on timeline
    public var duration: Double             // audio duration in seconds
    public var volume: Double               // 0.0–1.0
    public var color: String                // hex color for waveform
    public var isMuted: Bool
    public var waveformSamples: [Float]     // downsampled amplitude data (~4096 floats)
    public var sortOrder: Int

    public init(
        id: String = UUID().uuidString,
        name: String = "Soundtrack",
        audioFilePath: String = "",
        startTimeOffset: Double = 0,
        duration: Double = 0,
        volume: Double = 1.0,
        color: String = "#00BCD4",
        isMuted: Bool = false,
        waveformSamples: [Float] = [],
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.audioFilePath = audioFilePath
        self.startTimeOffset = startTimeOffset
        self.duration = duration
        self.volume = volume
        self.color = color
        self.isMuted = isMuted
        self.waveformSamples = waveformSamples
        self.sortOrder = sortOrder
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case audioFilePath = "audio_file_path"
        case startTimeOffset = "start_time_offset"
        case duration
        case volume
        case color
        case isMuted = "is_muted"
        case waveformSamples = "waveform_samples"
        case sortOrder = "sort_order"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Soundtrack"
        audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath) ?? ""
        startTimeOffset = try container.decodeIfPresent(Double.self, forKey: .startTimeOffset) ?? 0
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#00BCD4"
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        waveformSamples = try container.decodeIfPresent([Float].self, forKey: .waveformSamples) ?? []
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}
