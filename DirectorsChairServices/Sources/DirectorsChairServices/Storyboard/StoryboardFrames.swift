// DirectorsChairServices/Storyboard/StoryboardFrames.swift
//
// The pure halves of the scene/shot storyboard surfaces (DC-0064):
// subject text built from the models, and frame persistence following
// the project's existing asset conventions (relative path stored on the
// entity; timestamped file plus a stable *_latest.png). Callers own the
// asset DIRECTORY (their sanitizers already name scene/shot folders);
// this owns only file naming and IO — one writer, testable in SPM.

import Foundation
import DirectorsChairCore

// MARK: - Subjects

/// Turns scene/shot fields into the plain shot language the styler wraps.
/// Pure and deterministic: same entities, same subject — regeneration is
/// a seed change, not a prompt lottery.
public enum StoryboardSubjects {

    /// The shot's own description leads; the scene supplies setting and
    /// mood facts the description usually omits (slug-line style).
    public static func subject(for shot: Shot, in scene: Scene?) -> String {
        var parts: [String] = []
        let description = shot.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty { parts.append(description) }
        if let scene {
            var setting: [String] = []
            let name = scene.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { setting.append(name) }
            if let location = scene.location, !location.isEmpty { setting.append(location) }
            if let timeOfDay = scene.timeOfDay, !timeOfDay.isEmpty { setting.append(timeOfDay) }
            if let weather = scene.weather, !weather.isEmpty { setting.append(weather) }
            if !setting.isEmpty { parts.append("Setting: \(setting.joined(separator: ", "))") }
            if parts.count == 1 && description.isEmpty {
                // A shot with no description still deserves a drawable subject.
                let summary = (scene.sceneOverviewSummary ?? scene.description)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !summary.isEmpty { parts.append(summary) }
            }
        }
        if parts.isEmpty { parts.append("Untitled shot") }
        return parts.joined(separator: ". ")
    }

    /// Camera facts ride the styler's FRAMING line, not the subject —
    /// the model treats them as direction, not content.
    public static func notes(for shot: Shot) -> String? {
        var terms: [String] = []
        if !shot.shotType.isEmpty { terms.append(shot.shotType) }
        if !shot.cameraAngle.isEmpty { terms.append("\(shot.cameraAngle) angle") }
        if shot.movement != "Static" && !shot.movement.isEmpty {
            terms.append("\(shot.movement) camera")
        }
        if let lens = shot.lensMm { terms.append("\(lens)mm lens") }
        return terms.isEmpty ? nil : terms.joined(separator: ", ")
    }

    /// A scene frame is its establishing image: name, slug-line facts,
    /// then the best prose the project has for it.
    public static func subject(for scene: Scene) -> String {
        var parts: [String] = []
        let name = scene.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { parts.append("Establishing frame: \(name)") }
        var setting: [String] = []
        if let location = scene.location, !location.isEmpty { setting.append(location) }
        if let timeOfDay = scene.timeOfDay, !timeOfDay.isEmpty { setting.append(timeOfDay) }
        if let weather = scene.weather, !weather.isEmpty { setting.append(weather) }
        if !setting.isEmpty { parts.append(setting.joined(separator: ", ")) }
        let prose = (scene.sceneOverviewSummary ?? scene.description)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !prose.isEmpty { parts.append(prose) }
        if parts.isEmpty { parts.append("Untitled scene") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Persistence

public enum StoryboardFrameStore {

    public struct SavedFrame: Equatable, Sendable {
        /// The stable path callers store on the entity ("…/storyboard_latest.png").
        public let relativePath: String
        /// The immutable history copy written alongside it.
        public let timestampedRelativePath: String
    }

    public static let latestFilename = "storyboard_latest.png"

    /// Writes the frame under projectBase/relativeDirectory as a
    /// timestamped PNG plus the overwritten *_latest.png, mirroring the
    /// scene-overview/shot-preview convention exactly (history is cheap,
    /// the stored pointer is stable).
    public static func save(png: Data, projectBasePath: URL,
                            relativeDirectory: String,
                            timestamp: Date = Date()) throws -> SavedFrame {
        let directory = projectBasePath.appendingPathComponent(relativeDirectory,
                                                               isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamped = "storyboard_\(formatter.string(from: timestamp)).png"

        try png.write(to: directory.appendingPathComponent(stamped))
        try png.write(to: directory.appendingPathComponent(latestFilename))

        return SavedFrame(
            relativePath: "\(relativeDirectory)/\(latestFilename)",
            timestampedRelativePath: "\(relativeDirectory)/\(stamped)")
    }
}
