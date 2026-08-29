// DirectorsChairCore/Models/Project+ShotRenumbering.swift
//
// Owner 2026-08-29: a shot's number is its place in the story, not the
// number it was born with. After a reorder every shot gets 1…N in story
// order (sequence, scene, position). A shot's pictures live in
// assets/shots/shot_<number>, so the folder — and every stored path into
// it — moves with the shot.

import Foundation

/// One shot whose number changed.
public struct ShotNumberMove: Equatable, Sendable {
    public let shotUUID: String
    public let from: Int
    public let to: Int

    public init(shotUUID: String, from: Int, to: Int) {
        self.shotUUID = shotUUID
        self.from = from
        self.to = to
    }
}

public extension Project {
    /// The project with shots numbered 1…N in story order, plus the moves
    /// (so the caller can rename the shots' folders on disk).
    func renumberingShots() -> (project: Project, moves: [ShotNumberMove]) {
        var updated = self
        var moves: [ShotNumberMove] = []
        var next = 1
        for s in updated.sequences.indices {
            for c in updated.sequences[s].scenes.indices {
                for i in updated.sequences[s].scenes[c].shots.indices {
                    let shot = updated.sequences[s].scenes[c].shots[i]
                    if shot.shotId != next {
                        moves.append(ShotNumberMove(shotUUID: shot.id, from: shot.shotId, to: next))
                        updated.sequences[s].scenes[c].shots[i] = Self.shot(shot, renumbered: next)
                    }
                    next += 1
                }
            }
        }
        return (updated, moves)
    }

    /// The shot with its new number and every stored path into its old
    /// folder pointed at the new one (previews, takes, keyframes, media…).
    static func shot(_ shot: Shot, renumbered new: Int) -> Shot {
        let old = shot.shotId
        var renumbered = shot
        renumbered.shotId = new
        guard old != new,
              let data = try? JSONEncoder().encode(renumbered),
              let json = String(data: data, encoding: .utf8) else { return renumbered }
        let rewritten = json.replacingOccurrences(of: "assets/shots/shot_\(old)/", with: "assets/shots/shot_\(new)/")
        guard let out = rewritten.data(using: .utf8), let decoded = try? JSONDecoder().decode(Shot.self, from: out) else {
            return renumbered
        }
        return decoded
    }
}

/// Moves `assets/shots/shot_<from>` folders to their new numbers — every
/// source to a temporary name first, so swaps (1↔2) never collide; a
/// folder already sitting at a destination (a deleted shot's leftovers) is
/// set aside as `shot_<n>.orphan`, never deleted.
public enum ShotFolderMigration {
    public static func apply(_ moves: [ShotNumberMove], projectDirectory: URL) throws {
        let fm = FileManager.default
        let shotsDir = projectDirectory.appendingPathComponent("assets").appendingPathComponent("shots")
        var staged: [(temp: URL, destination: URL)] = []
        for move in moves {
            let source = shotsDir.appendingPathComponent("shot_\(move.from)")
            guard fm.fileExists(atPath: source.path) else { continue }
            let temp = shotsDir.appendingPathComponent("shot_\(move.from).moving-to-\(move.to)")
            try fm.moveItem(at: source, to: temp)
            staged.append((temp, shotsDir.appendingPathComponent("shot_\(move.to)")))
        }
        for (temp, destination) in staged {
            if fm.fileExists(atPath: destination.path) {
                var orphan = destination.appendingPathExtension("orphan")
                var n = 1
                while fm.fileExists(atPath: orphan.path) { orphan = destination.appendingPathExtension("orphan\(n)"); n += 1 }
                try fm.moveItem(at: destination, to: orphan)
            }
            try fm.moveItem(at: temp, to: destination)
        }
    }
}
