//
// BubbleView+Layout.swift
//
// Extracted from BubbleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import UniformTypeIdentifiers
import AVFoundation

extension BubbleView {

    // MARK: - Reorder Items by Chronology

    /// Reorders all items in the scene when one item's chronology number changes.
    /// This shifts other items to avoid duplicate indexes.
    func reorderItems(movingItemId: String, oldIndex: Int, newIndex: Int) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        // Update dialogues
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].dialogues.count {
            let dialogue = project.sequences[seqIndex].scenes[sceneIndex].dialogues[i]
            if dialogue.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].chronologyNumber = newIndex
                project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].globalChronologyNumber = newIndex
            } else {
                let currentIndex = dialogue.chronologyNumber
                if newIndex < oldIndex {
                    // Moving up: shift items in range [newIndex, oldIndex) down by 1
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].chronologyNumber = currentIndex + 1
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].globalChronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    // Moving down: shift items in range (oldIndex, newIndex] up by 1
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].chronologyNumber = currentIndex - 1
                        project.sequences[seqIndex].scenes[sceneIndex].dialogues[i].globalChronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update actions
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].actions.count {
            let action = project.sequences[seqIndex].scenes[sceneIndex].actions[i]
            if action.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].actions[i].chronologyNumber = newIndex
                project.sequences[seqIndex].scenes[sceneIndex].actions[i].globalChronologyNumber = newIndex
            } else {
                let currentIndex = action.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].chronologyNumber = currentIndex + 1
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].globalChronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].chronologyNumber = currentIndex - 1
                        project.sequences[seqIndex].scenes[sceneIndex].actions[i].globalChronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update narrations
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].narrations.count {
            let narration = project.sequences[seqIndex].scenes[sceneIndex].narrations[i]
            if narration.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].narrations[i].chronologyNumber = newIndex
                project.sequences[seqIndex].scenes[sceneIndex].narrations[i].globalChronologyNumber = newIndex
            } else {
                let currentIndex = narration.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].chronologyNumber = currentIndex + 1
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].globalChronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].chronologyNumber = currentIndex - 1
                        project.sequences[seqIndex].scenes[sceneIndex].narrations[i].globalChronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update notes
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.count {
            let note = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i]
            if note.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i].chronologyNumber = newIndex
            } else {
                let currentIndex = note.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i].chronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[i].chronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update sound notes
        for i in 0..<project.sequences[seqIndex].scenes[sceneIndex].soundNotes.count {
            let soundNote = project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i]
            if soundNote.id == movingItemId {
                project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i].chronologyNumber = newIndex
            } else {
                let currentIndex = soundNote.chronologyNumber
                if newIndex < oldIndex {
                    if currentIndex >= newIndex && currentIndex < oldIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i].chronologyNumber = currentIndex + 1
                    }
                } else if newIndex > oldIndex {
                    if currentIndex > oldIndex && currentIndex <= newIndex {
                        project.sequences[seqIndex].scenes[sceneIndex].soundNotes[i].chronologyNumber = currentIndex - 1
                    }
                }
            }
        }

        // Update selected scene reference
        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        sortRefreshTrigger = UUID()

        // Notify that items were reordered (to sync timeline)
        onItemsReordered?()
    }

    // MARK: - Get All Items Chronologically

    func getAllItemsChronologically(for scene: DCScene) -> [BubbleItem] {
        var items: [BubbleItem] = []

        // Add all dialogues
        for dialogue in scene.dialogues {
            items.append(.dialogue(dialogue))
        }

        // Add all actions (only those without a parent dialogue)
        for action in scene.actions {
            if action.parentDialogueId == nil {
                items.append(.action(action))
            }
        }

        // Add all narrations (only those without a parent dialogue)
        for narration in scene.narrations {
            if narration.parentDialogueId == nil {
                items.append(.narration(narration))
            }
        }

        // Add all notes (only those without a parent dialogue)
        for note in scene.sceneNotes {
            if note.parentDialogueId == nil {
                items.append(.note(note))
            }
        }

        // Add all sound notes (only those without a parent dialogue)
        for soundNote in scene.soundNotes {
            if soundNote.parentDialogueId == nil {
                items.append(.soundNote(soundNote))
            }
        }

        // Sort by chronology number
        items.sort { $0.chronologyNumber < $1.chronologyNumber }

        return items
    }

    // MARK: - Get Connected Items for a Dialogue

    /// Returns all items connected to a specific dialogue as sub-bubbles
    func getConnectedItems(for dialogueId: String, in scene: DCScene) -> [BubbleItem] {
        var items: [BubbleItem] = []

        // Find connected actions
        for action in scene.actions {
            if action.parentDialogueId == dialogueId {
                items.append(.action(action))
            }
        }

        // Find connected narrations
        for narration in scene.narrations {
            if narration.parentDialogueId == dialogueId {
                items.append(.narration(narration))
            }
        }

        // Find connected notes
        for note in scene.sceneNotes {
            if note.parentDialogueId == dialogueId {
                items.append(.note(note))
            }
        }

        // Find connected sound notes
        for soundNote in scene.soundNotes {
            if soundNote.parentDialogueId == dialogueId {
                items.append(.soundNote(soundNote))
            }
        }

        // Sort by chronology number
        items.sort { $0.chronologyNumber < $1.chronologyNumber }

        return items
    }

    // MARK: - Cache Rebuild

    /// Rebuilds all cached lookup data for the given scene in a single pass
    /// Maximum chronologyNumber across ALL scenes in the project
    func globalMaxChronology() -> Int {
        var maxVal = 0
        for seq in project.sequences {
            for scene in seq.scenes {
                maxVal = max(maxVal,
                    scene.dialogues.map(\.chronologyNumber).max() ?? 0,
                    scene.actions.map(\.chronologyNumber).max() ?? 0,
                    scene.narrations.map(\.chronologyNumber).max() ?? 0,
                    scene.sceneNotes.map(\.chronologyNumber).max() ?? 0,
                    scene.soundNotes.map(\.chronologyNumber).max() ?? 0
                )
            }
        }
        return maxVal
    }

    /// Count of top-level bubble items in all scenes before the given scene
    func globalIndexOffset(for sceneId: String) -> Int {
        var count = 0
        for seq in project.sequences {
            for scene in seq.scenes {
                if scene.id == sceneId { return count }
                // Count top-level items only (parentDialogueId == nil for non-dialogue types)
                count += scene.dialogues.count
                count += scene.actions.filter { $0.parentDialogueId == nil }.count
                count += scene.narrations.filter { $0.parentDialogueId == nil }.count
                count += scene.sceneNotes.filter { $0.parentDialogueId == nil }.count
                count += scene.soundNotes.filter { $0.parentDialogueId == nil }.count
            }
        }
        return count
    }

    func rebuildBubbleCache(for scene: DCScene) {
        // 1. Build chronological items (same logic as getAllItemsChronologically)
        var items: [BubbleItem] = []
        for dialogue in scene.dialogues {
            items.append(.dialogue(dialogue))
        }
        for action in scene.actions where action.parentDialogueId == nil {
            items.append(.action(action))
        }
        for narration in scene.narrations where narration.parentDialogueId == nil {
            items.append(.narration(narration))
        }
        for note in scene.sceneNotes where note.parentDialogueId == nil {
            items.append(.note(note))
        }
        for soundNote in scene.soundNotes where soundNote.parentDialogueId == nil {
            items.append(.soundNote(soundNote))
        }
        items.sort { $0.chronologyNumber < $1.chronologyNumber }
        cachedChronologicalItems = items

        // 1b. Build global index cache
        let offset = globalIndexOffset(for: scene.id)
        var indices: [String: Int] = [:]
        for (i, item) in items.enumerated() {
            indices[item.id] = offset + i + 1
        }
        cachedGlobalIndices = indices

        // 2. Build connected items index (parentDialogueId → [BubbleItem])
        var connected: [String: [BubbleItem]] = [:]
        for action in scene.actions {
            if let parentId = action.parentDialogueId {
                connected[parentId, default: []].append(.action(action))
            }
        }
        for narration in scene.narrations {
            if let parentId = narration.parentDialogueId {
                connected[parentId, default: []].append(.narration(narration))
            }
        }
        for note in scene.sceneNotes {
            if let parentId = note.parentDialogueId {
                connected[parentId, default: []].append(.note(note))
            }
        }
        for soundNote in scene.soundNotes {
            if let parentId = soundNote.parentDialogueId {
                connected[parentId, default: []].append(.soundNote(soundNote))
            }
        }
        // Sort each group by chronology number
        for key in connected.keys {
            connected[key]?.sort { $0.chronologyNumber < $1.chronologyNumber }
        }
        cachedConnectedItems = connected

        // 3. Build character name → Character dictionary
        cachedCharacterMap = Dictionary(uniqueKeysWithValues: project.characters.map { ($0.name, $0) })
    }
}
