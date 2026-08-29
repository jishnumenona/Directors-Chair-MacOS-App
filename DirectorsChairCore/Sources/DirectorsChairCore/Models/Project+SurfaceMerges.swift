//
//  Project+SurfaceMerges.swift
//  DirectorsChairCore
//
//  Some surfaces (the timeline, the shot-list adapter) work on their own
//  copy of the project and used to write that whole copy back, silently
//  reverting anything edited elsewhere since the copy was taken — a
//  schedule or budget change, typed script text (audit 2026-08-28, P0).
//  Each surface now merges back ONLY the fields it owns, matched by uuid,
//  onto the live project.
//

import Foundation

public extension Project {

    /// Adopt the timeline's edits from `other`: shot placement and length,
    /// the manual start time of dialogue, action, narration and sound-note
    /// rows, and dialogue/sound-note audio takes. Everything else — script
    /// text, production data, characters, boards — stays as it is here.
    /// Scenes or rows that no longer exist here are ignored.
    func adoptingTimelineEdits(from other: Project) -> Project {
        var merged = self
        let theirScenes = Dictionary(other.sequences.flatMap(\.scenes).map { ($0.uuid, $0) },
                                     uniquingKeysWith: { first, _ in first })
        for s in merged.sequences.indices {
            for c in merged.sequences[s].scenes.indices {
                guard let theirs = theirScenes[merged.sequences[s].scenes[c].uuid] else { continue }
                let shots = Dictionary(theirs.shots.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
                for i in merged.sequences[s].scenes[c].shots.indices {
                    guard let t = shots[merged.sequences[s].scenes[c].shots[i].uuid] else { continue }
                    merged.sequences[s].scenes[c].shots[i].timelinePosition = t.timelinePosition
                    merged.sequences[s].scenes[c].shots[i].duration = t.duration
                }
                let dialogues = Dictionary(theirs.dialogues.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
                for i in merged.sequences[s].scenes[c].dialogues.indices {
                    guard let t = dialogues[merged.sequences[s].scenes[c].dialogues[i].uuid] else { continue }
                    merged.sequences[s].scenes[c].dialogues[i].manualStartTime = t.manualStartTime
                    merged.sequences[s].scenes[c].dialogues[i].audioFilePath = t.audioFilePath
                }
                let actions = Dictionary(theirs.actions.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
                for i in merged.sequences[s].scenes[c].actions.indices {
                    guard let t = actions[merged.sequences[s].scenes[c].actions[i].uuid] else { continue }
                    merged.sequences[s].scenes[c].actions[i].manualStartTime = t.manualStartTime
                }
                let narrations = Dictionary(theirs.narrations.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
                for i in merged.sequences[s].scenes[c].narrations.indices {
                    guard let t = narrations[merged.sequences[s].scenes[c].narrations[i].uuid] else { continue }
                    merged.sequences[s].scenes[c].narrations[i].manualStartTime = t.manualStartTime
                }
                let notes = Dictionary(theirs.soundNotes.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
                for i in merged.sequences[s].scenes[c].soundNotes.indices {
                    guard let t = notes[merged.sequences[s].scenes[c].soundNotes[i].uuid] else { continue }
                    merged.sequences[s].scenes[c].soundNotes[i].manualStartTime = t.manualStartTime
                    merged.sequences[s].scenes[c].soundNotes[i].audioFilePath = t.audioFilePath
                }
            }
        }
        return merged
    }

    /// Adopt the shot-list's edits from `other`: each scene's shots, matched
    /// by scene uuid. A scene that no longer exists here is ignored (never
    /// resurrected); when this project has no sequence at all, the shot
    /// list's freshly created structure is taken whole.
    func adoptingShots(from other: Project) -> Project {
        guard !sequences.isEmpty else {
            var merged = self
            merged.sequences = other.sequences
            return merged
        }
        var merged = self
        let theirScenes = Dictionary(other.sequences.flatMap(\.scenes).map { ($0.uuid, $0) },
                                     uniquingKeysWith: { first, _ in first })
        for s in merged.sequences.indices {
            for c in merged.sequences[s].scenes.indices {
                guard let theirs = theirScenes[merged.sequences[s].scenes[c].uuid] else { continue }
                merged.sequences[s].scenes[c].shots = theirs.shots
            }
        }
        return merged
    }
}
