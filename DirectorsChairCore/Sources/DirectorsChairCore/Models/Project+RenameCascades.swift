// DirectorsChairCore/Sources/DirectorsChairCore/Models/Project+RenameCascades.swift
//
// WS2.5b — renaming an entity must not orphan the strings that reference it.
//
// Characters and locations are referenced BY NAME throughout the model
// (dialogue speaker cues, action/narration participant lists, scene/sequence
// locations, cast assignments, schedule rows, gantt tasks, vision cards).
// Names are the industry-facing contract (Fountain/FDX cues are names), so
// rather than migrating the wire format to opaque UUID keys, a rename
// CASCADES: every exact-match reference is rewritten in the same mutation.
// This is the same pattern the budget-category rename fix (WS8.1) uses.

import Foundation

public extension Project {

    /// Rewrite every reference to a character's old name after a rename.
    /// Exact-match only — names are stored verbatim wherever they're referenced.
    /// - Returns: the number of references updated (0 when nothing referenced it).
    @discardableResult
    mutating func cascadeCharacterRename(from oldName: String, to newName: String) -> Int {
        guard oldName != newName, !oldName.isEmpty, !newName.isEmpty else { return 0 }
        var updated = 0

        for s in sequences.indices {
            for c in sequences[s].scenes.indices {
                if sequences[s].scenes[c].primaryCharacter == oldName {
                    sequences[s].scenes[c].primaryCharacter = newName; updated += 1
                }
                for d in sequences[s].scenes[c].dialogues.indices
                where sequences[s].scenes[c].dialogues[d].character == oldName {
                    sequences[s].scenes[c].dialogues[d].character = newName; updated += 1
                }
                for a in sequences[s].scenes[c].actions.indices {
                    updated += replace(in: &sequences[s].scenes[c].actions[a].characters,
                                       oldName: oldName, newName: newName)
                }
                for n in sequences[s].scenes[c].narrations.indices {
                    updated += replace(in: &sequences[s].scenes[c].narrations[n].characters,
                                       oldName: oldName, newName: newName)
                }
            }
        }

        for i in costumes.indices where costumes[i].character == oldName {
            costumes[i].character = newName; updated += 1
        }
        for i in castMembers.indices where castMembers[i].characterName == oldName {
            castMembers[i].characterName = newName; updated += 1
        }
        for i in beats.indices where beats[i].character == oldName {
            beats[i].character = newName; updated += 1
        }
        return updated
    }

    /// Rewrite every reference to a location's old name after a rename.
    /// - Returns: the number of references updated.
    @discardableResult
    mutating func cascadeLocationRename(from oldName: String, to newName: String) -> Int {
        guard oldName != newName, !oldName.isEmpty, !newName.isEmpty else { return 0 }
        var updated = 0

        for s in sequences.indices {
            if sequences[s].location == oldName {
                sequences[s].location = newName; updated += 1
            }
            for c in sequences[s].scenes.indices
            where sequences[s].scenes[c].location == oldName {
                sequences[s].scenes[c].location = newName; updated += 1
            }
        }
        for i in scheduleItems.indices where scheduleItems[i].location == oldName {
            scheduleItems[i].location = newName; updated += 1
        }
        for i in ganttTasks.indices {
            updated += replace(in: &ganttTasks[i].locationNames,
                               oldName: oldName, newName: newName)
        }
        return updated
    }

    private func replace(in list: inout [String], oldName: String, newName: String) -> Int {
        var n = 0
        for i in list.indices where list[i] == oldName {
            list[i] = newName; n += 1
        }
        return n
    }
}
