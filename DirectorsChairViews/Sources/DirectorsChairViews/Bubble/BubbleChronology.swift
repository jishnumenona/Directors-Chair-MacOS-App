//
// BubbleChronology.swift
//
// Pure chronology math for bubble drag-reorder and drag-out disconnect,
// extracted from BubbleView (BubbleView+Layout / +Mutations) so the ordering
// logic can be unit-tested without constructing the SwiftUI view. BubbleView
// delegates to these; the shift algorithm and the parent-link clear used to be
// duplicated across all five item collections inline in the view.
//
// This file deliberately imports only Foundation + DirectorsChairCore, so
// `Scene` unambiguously refers to the model (not SwiftUI.Scene) and the whole
// unit stays value-only and view-free.
//

import Foundation
import DirectorsChairCore

enum BubbleChronology {

    /// New chronology index for a single item when `movingItemId` is dragged
    /// from `oldIndex` to `newIndex`. The moved item takes `newIndex`; every
    /// other item inside the shifted range moves by one to keep the numbering
    /// contiguous and duplicate-free.
    static func reindexed(current: Int, isMovingItem: Bool, oldIndex: Int, newIndex: Int) -> Int {
        if isMovingItem { return newIndex }
        if newIndex < oldIndex {
            // Moving up: items in [newIndex, oldIndex) shift down by 1.
            if current >= newIndex && current < oldIndex { return current + 1 }
        } else if newIndex > oldIndex {
            // Moving down: items in (oldIndex, newIndex] shift up by 1.
            if current > oldIndex && current <= newIndex { return current - 1 }
        }
        return current
    }

    /// Applies the reorder across every item collection in the scene. Dialogues,
    /// actions and narrations carry both a scene-local and a global chronology
    /// number; notes and sound notes carry only the scene-local one (matching
    /// the model).
    static func reorder(_ scene: inout Scene, movingItemId: String, oldIndex: Int, newIndex: Int) {
        for i in scene.dialogues.indices {
            let v = reindexed(current: scene.dialogues[i].chronologyNumber,
                              isMovingItem: scene.dialogues[i].id == movingItemId,
                              oldIndex: oldIndex, newIndex: newIndex)
            scene.dialogues[i].chronologyNumber = v
            scene.dialogues[i].globalChronologyNumber = v
        }
        for i in scene.actions.indices {
            let v = reindexed(current: scene.actions[i].chronologyNumber,
                              isMovingItem: scene.actions[i].id == movingItemId,
                              oldIndex: oldIndex, newIndex: newIndex)
            scene.actions[i].chronologyNumber = v
            scene.actions[i].globalChronologyNumber = v
        }
        for i in scene.narrations.indices {
            let v = reindexed(current: scene.narrations[i].chronologyNumber,
                              isMovingItem: scene.narrations[i].id == movingItemId,
                              oldIndex: oldIndex, newIndex: newIndex)
            scene.narrations[i].chronologyNumber = v
            scene.narrations[i].globalChronologyNumber = v
        }
        for i in scene.sceneNotes.indices {
            scene.sceneNotes[i].chronologyNumber = reindexed(
                current: scene.sceneNotes[i].chronologyNumber,
                isMovingItem: scene.sceneNotes[i].id == movingItemId,
                oldIndex: oldIndex, newIndex: newIndex)
        }
        for i in scene.soundNotes.indices {
            scene.soundNotes[i].chronologyNumber = reindexed(
                current: scene.soundNotes[i].chronologyNumber,
                isMovingItem: scene.soundNotes[i].id == movingItemId,
                oldIndex: oldIndex, newIndex: newIndex)
        }
    }

    /// Detaches a connected sub-item from its parent dialogue by clearing the
    /// `parentDialogueId` link. Returns true if a matching item was found.
    @discardableResult
    static func disconnect(_ scene: inout Scene, itemId: String, itemType: String) -> Bool {
        switch itemType {
        case "action":
            if let idx = scene.actions.firstIndex(where: { $0.id == itemId }) {
                scene.actions[idx].parentDialogueId = nil; return true
            }
        case "narration":
            if let idx = scene.narrations.firstIndex(where: { $0.id == itemId }) {
                scene.narrations[idx].parentDialogueId = nil; return true
            }
        case "note":
            if let idx = scene.sceneNotes.firstIndex(where: { $0.id == itemId }) {
                scene.sceneNotes[idx].parentDialogueId = nil; return true
            }
        case "soundNote":
            if let idx = scene.soundNotes.firstIndex(where: { $0.id == itemId }) {
                scene.soundNotes[idx].parentDialogueId = nil; return true
            }
        default:
            break
        }
        return false
    }
}
