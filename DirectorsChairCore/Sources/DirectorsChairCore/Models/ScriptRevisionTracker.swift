// DirectorsChairCore/Sources/DirectorsChairCore/Models/ScriptRevisionTracker.swift
//
// Script revision tracking (backlog §2.18) — the production workflow
// every professional screenwriting tool treats as table stakes.
//
// Once a script is LOCKED, its scene numbers are promises: call sheets,
// schedules, and department breakdowns all reference them. From then on
// changes ship as colored revision rounds (Blue, Pink, Yellow, …), a
// scene inserted between 22 and 23 becomes 22A so nothing renumbers,
// and a changed scene carries the color of the round that changed it.
//
// Change detection is a stable content fingerprint captured when a round
// begins — computed on demand, so no edit path anywhere in the app needs
// a hook, and the answer is always derived from what the scene actually
// says rather than from bookkeeping that can drift.

import Foundation

// MARK: - A revision round

public struct ScriptRevisionRound: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    /// "White" (the locked base), then the industry progression.
    public var color: String
    /// ISO8601, supplied by the caller — models stay clock-free.
    public var started: String
    /// Locked numbers of the scenes this round changed (empty for the
    /// lock itself).
    public var changedSceneNumbers: [String]

    public init(id: String = UUID().uuidString, color: String,
                started: String, changedSceneNumbers: [String] = []) {
        self.id = id
        self.color = color
        self.started = started
        self.changedSceneNumbers = changedSceneNumbers
    }

    enum CodingKeys: String, CodingKey {
        case id
        case color
        case started
        case changedSceneNumbers = "changed_scene_numbers"
    }
}

// MARK: - Tracker

public enum ScriptRevisionTracker {

    /// The industry progression after the White (locked) draft. Past the
    /// end it wraps as "2nd Blue", "2nd Pink", … the way long shoots do.
    public static let colorOrder = ["Blue", "Pink", "Yellow", "Green",
                                    "Goldenrod", "Buff", "Salmon", "Cherry"]

    public static func nextColor(after current: String?) -> String {
        guard let current, current != "White" else { return colorOrder[0] }
        let base = current.hasPrefix("2nd ")
            ? String(current.dropFirst(4)) : current
        let cycle = current.hasPrefix("2nd ") ? 2 : 1
        guard let index = colorOrder.firstIndex(of: base) else {
            return colorOrder[0]
        }
        if index + 1 < colorOrder.count {
            let next = colorOrder[index + 1]
            return cycle == 2 ? "2nd \(next)" : next
        }
        return "2nd \(colorOrder[0])"
    }

    // MARK: Fingerprint

    /// Stable across launches (FNV-1a, never Hasher — Swift's hash seed
    /// changes per process). Covers what a reader would call "the scene":
    /// name, slugline, and every line of dialogue, action, and narration.
    public static func fingerprint(_ scene: Scene) -> String {
        var hash: UInt64 = 1469598103934665603
        func fold(_ text: String) {
            for byte in text.utf8 {
                hash = (hash ^ UInt64(byte)) &* 1099511628211
            }
            hash = (hash ^ 0x1F) &* 1099511628211   // field separator
        }
        fold(scene.name)
        fold(scene.location ?? "")
        fold(scene.description)
        for dialogue in scene.dialogues {
            fold(dialogue.character); fold(dialogue.text)
        }
        for action in scene.actions { fold(action.description) }
        for narration in scene.narrations { fold(narration.text) }
        return String(format: "%016llx", hash)
    }

    // MARK: Lock

    /// Freeze the numbers: every scene gets its position number in story
    /// order, the White baseline is captured, and the paper trail opens.
    /// Locking twice is a no-op — numbers are promises.
    public static func lock(_ project: inout Project, date: String) {
        guard project.scriptRevisionColor == nil else { return }
        var number = 1
        for seqIndex in project.sequences.indices {
            for sceneIndex in project.sequences[seqIndex].scenes.indices {
                project.sequences[seqIndex].scenes[sceneIndex]
                    .lockedNumber = String(number)
                number += 1
            }
        }
        project.scriptRevisionColor = "White"
        project.scriptRevisionBaseline = baseline(of: project)
        project.scriptRevisionHistory = [
            ScriptRevisionRound(color: "White", started: date)]
    }

    // MARK: Advance

    /// Close the current round: scenes that changed since the round began
    /// (or are new) are stamped with the NEXT color, new scenes get their
    /// letter-suffixed numbers, the baseline resets, and the round joins
    /// the history. Returns the stamped scene numbers, changed-first in
    /// story order.
    @discardableResult
    public static func advance(_ project: inout Project,
                               date: String) -> [String] {
        guard project.scriptRevisionColor != nil else { return [] }
        assignNumbersToNewScenes(&project)
        let color = nextColor(after: project.scriptRevisionColor)
        var stamped: [String] = []
        for seqIndex in project.sequences.indices {
            for sceneIndex in project.sequences[seqIndex].scenes.indices {
                let scene = project.sequences[seqIndex].scenes[sceneIndex]
                let previous = project.scriptRevisionBaseline[scene.id]
                if previous != fingerprint(scene) {
                    project.sequences[seqIndex].scenes[sceneIndex]
                        .revisionColor = color
                    stamped.append(scene.lockedNumber ?? scene.name)
                }
            }
        }
        project.scriptRevisionColor = color
        project.scriptRevisionBaseline = baseline(of: project)
        project.scriptRevisionHistory.append(
            ScriptRevisionRound(color: color, started: date,
                                changedSceneNumbers: stamped))
        return stamped
    }

    /// Scene ids changed since the current round began — the live marks
    /// the UI shows while a round is still open.
    public static func changedSinceRoundStart(_ project: Project) -> Set<String> {
        guard project.scriptRevisionColor != nil else { return [] }
        var changed: Set<String> = []
        for scene in project.sequences.flatMap(\.scenes) {
            if project.scriptRevisionBaseline[scene.id] != fingerprint(scene) {
                changed.insert(scene.id)
            }
        }
        return changed
    }

    // MARK: Numbering

    /// New scenes slot in without renumbering anything already printed: a
    /// scene between 22 and 23 becomes 22A (then 22B), and a scene before
    /// scene 1 becomes A1 — the standard head-insert form.
    public static func assignNumbersToNewScenes(_ project: inout Project) {
        let taken = Set(project.sequences.flatMap(\.scenes)
            .compactMap(\.lockedNumber))
        var used = taken
        var lastNumber: String?
        for seqIndex in project.sequences.indices {
            for sceneIndex in project.sequences[seqIndex].scenes.indices {
                let scene = project.sequences[seqIndex].scenes[sceneIndex]
                if let existing = scene.lockedNumber {
                    lastNumber = existing
                    continue
                }
                let assigned: String
                if let last = lastNumber {
                    if last.first?.isLetter == true {
                        // Still ahead of the base scene a head-insert
                        // preceded: A1, then B1 — never 1A, which would
                        // read as AFTER scene 1.
                        assigned = nextPrefixed(base: baseNumber(of: last),
                                                used: used)
                    } else {
                        assigned = nextSuffixed(base: baseNumber(of: last),
                                                used: used)
                    }
                } else {
                    // Before the first locked scene: A-prefixed onto the
                    // first base that follows (A1 ahead of scene 1).
                    let following = project.sequences.flatMap(\.scenes)
                        .compactMap(\.lockedNumber).first
                        .map(baseNumber(of:)) ?? "1"
                    assigned = nextPrefixed(base: following, used: used)
                }
                project.sequences[seqIndex].scenes[sceneIndex]
                    .lockedNumber = assigned
                used.insert(assigned)
                lastNumber = assigned
            }
        }
    }

    private static func baseNumber(of number: String) -> String {
        String(number.filter(\.isNumber))
    }

    private static func nextSuffixed(base: String,
                                     used: Set<String>) -> String {
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            let candidate = "\(base)\(letter)"
            if !used.contains(candidate) { return candidate }
        }
        return "\(base)Z\(used.count)"   // 26 inserts after one scene: unheard of
    }

    private static func nextPrefixed(base: String,
                                     used: Set<String>) -> String {
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            let candidate = "\(letter)\(base)"
            if !used.contains(candidate) { return candidate }
        }
        return "Z\(base)\(used.count)"
    }

    private static func baseline(of project: Project) -> [String: String] {
        var result: [String: String] = [:]
        for scene in project.sequences.flatMap(\.scenes) {
            result[scene.id] = fingerprint(scene)
        }
        return result
    }
}
