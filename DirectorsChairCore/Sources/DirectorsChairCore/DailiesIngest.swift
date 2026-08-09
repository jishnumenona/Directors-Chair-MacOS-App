// DirectorsChairCore/Sources/DirectorsChairCore/DailiesIngest.swift
//
// Watch-folder dailies ingest (backlog §2.18) — the pure half.
//
// Footage arrives as files named by set convention ("S22A_T03.mov",
// "Scene 22 Take 3.mp4"); this file owns reading that convention and
// finding where in the project such a clip belongs. Locked production
// numbers (script revisions, §2.18) are first-class here: after a lock,
// "S22A" means the scene whose LOCKED number is 22A — the number the
// slate actually showed.
//
// Deliberately strict about what counts as a match: filing a take on the
// wrong shot silently is worse than parking it unsorted for a human.

import Foundation

public enum DailiesIngest {

    public static let videoExtensions: Set<String> =
        ["mov", "mp4", "m4v", "mxf", "avi", "mkv"]

    // MARK: - Filename convention

    public struct Match: Equatable, Sendable {
        /// "22" or "22A" — matched against a scene's locked number first,
        /// then against "Scene 22"-style names.
        public var sceneNumber: String
        /// The shot's display number, when the name carries one.
        public var shotNumber: Int?
        /// The slate's take number, when the name carries one.
        public var takeNumber: Int?

        public init(sceneNumber: String, shotNumber: Int? = nil,
                    takeNumber: Int? = nil) {
            self.sceneNumber = sceneNumber
            self.shotNumber = shotNumber
            self.takeNumber = takeNumber
        }
    }

    /// Reads the slate convention out of a file name. Understood forms
    /// (case-insensitive, separators space/underscore/dash/dot):
    ///   S22_T03      S22A-T3     SC22_SH04_T03
    ///   Scene 22 Shot 4 Take 3   scene22_take3
    /// nil = no scene token — the file goes to the unsorted bucket.
    public static func parse(fileName: String) -> Match? {
        let stem = (fileName as NSString).deletingPathExtension
        let pattern = #"(?i)(?:^|[ _\-.])(?:scene|sc|s)[ _\-.]?(\d+[a-z]?)"#
            + #"(?:.*?(?:shot|sh)[ _\-.]?(\d+))?"#
            + #"(?:.*?(?:take|tk|t)[ _\-.]?(\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: stem, range: NSRange(stem.startIndex..., in: stem))
        else { return nil }

        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: stem)
            else { return nil }
            return String(stem[range])
        }
        guard let scene = group(1)?.uppercased() else { return nil }
        // Slates zero-pad ("S07"); locked numbers don't. "07" and "7"
        // are the same scene.
        let digits = scene.prefix(while: \.isNumber)
        let letters = scene.drop(while: \.isNumber)
        let normalized = (Int(digits).map(String.init) ?? String(digits))
            + letters
        return Match(sceneNumber: normalized,
                     shotNumber: group(2).flatMap(Int.init),
                     takeNumber: group(3).flatMap(Int.init))
    }

    // MARK: - Destination

    public struct Destination: Equatable, Sendable {
        public var sequenceIndex: Int
        public var sceneIndex: Int
        public var shotIndex: Int

        public init(sequenceIndex: Int, sceneIndex: Int, shotIndex: Int) {
            self.sequenceIndex = sequenceIndex
            self.sceneIndex = sceneIndex
            self.shotIndex = shotIndex
        }
    }

    /// Where the clip belongs, or nil when the project can't answer
    /// unambiguously. Scene: locked number first (that is what the slate
    /// showed), then "Scene 22"-style names. Shot: by display number; a
    /// nameless shot token is accepted only when the scene has exactly
    /// one shot — guessing between shots misfiles footage.
    public static func destination(for match: Match,
                                   in project: Project) -> Destination? {
        for (seqIndex, sequence) in project.sequences.enumerated() {
            for (sceneIndex, scene) in sequence.scenes.enumerated() {
                let byLocked = scene.lockedNumber?.uppercased()
                    == match.sceneNumber
                let byName = scene.name.uppercased()
                    == "SCENE \(match.sceneNumber)"
                guard byLocked || byName else { continue }

                if let shotNumber = match.shotNumber {
                    if let shotIndex = scene.shots.firstIndex(
                        where: { $0.shotId == shotNumber }) {
                        return Destination(sequenceIndex: seqIndex,
                                           sceneIndex: sceneIndex,
                                           shotIndex: shotIndex)
                    }
                    return nil   // named a shot the scene doesn't have
                }
                if scene.shots.count == 1 {
                    return Destination(sequenceIndex: seqIndex,
                                       sceneIndex: sceneIndex,
                                       shotIndex: 0)
                }
                return nil   // several shots, none named — a human files it
            }
        }
        return nil
    }

    /// A clip already ingested must not come back on relaunch: the take
    /// remembers its camera file name, and that memory is the dedupe.
    public static func alreadyIngested(fileName: String,
                                       in project: Project) -> Bool {
        project.sequences.flatMap(\.scenes).flatMap(\.shots)
            .flatMap(\.takes)
            .contains { $0.cameraSourceFileName == fileName }
    }

    /// Build the take for an ingested clip, numbered from the slate when
    /// the name carried a number, else after the shot's existing takes.
    public static func makeTake(fileName: String,
                                relativeVideoPath: String,
                                match: Match,
                                existingTakes: [Take]) -> Take {
        let number = match.takeNumber
            ?? (existingTakes.map(\.takeNumber).max() ?? 0) + 1
        var take = Take(takeNumber: number)
        take.capturedVideoPath = relativeVideoPath
        take.cameraSourceFileName = fileName
        take.useAudioFromVideo = true
        return take
    }
}
