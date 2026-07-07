//
//  ProjectToScriptConverter.swift
//  DirectorsChair-Desktop
//
//  Script View: Converts between Project model and linear ScriptElement array
//

import Foundation
import DirectorsChairCore

/// Converts between the hierarchical Project model and a linear [ScriptElement] array
struct ProjectToScriptConverter {

    // MARK: - Forward Conversion (Project -> [ScriptElement])

    /// Convert a Project into a linear array of screenplay elements
    static func convert(from project: Project) -> [ScriptElement] {
        var elements: [ScriptElement] = []
        var sceneNumber = 1

        for (seqIndex, sequence) in project.sequences.enumerated() {
            // Sequence heading
            if !sequence.name.isEmpty {
                elements.append(ScriptElement(
                    type: .sectionHeading,
                    text: sequence.name.uppercased(),
                    sourceSequenceIndex: seqIndex
                ))
                elements.append(ScriptElement(type: .blankLine, text: ""))
            }

            for (sceneIdx, scene) in sequence.scenes.enumerated() {
                // Scene heading
                let heading = buildSceneHeading(scene, sequenceLocation: sequence.location)
                let sceneNum = "\(sceneNumber)"

                elements.append(ScriptElement(
                    type: .sceneHeading,
                    text: heading,
                    sourceSequenceIndex: seqIndex,
                    sourceSceneIndex: sceneIdx,
                    sourceItemId: scene.id,
                    sourceItemType: "scene",
                    sceneNumber: sceneNum
                ))

                // Scene description as action
                if !scene.description.isEmpty {
                    elements.append(ScriptElement(
                        type: .action,
                        text: scene.description,
                        sourceSequenceIndex: seqIndex,
                        sourceSceneIndex: sceneIdx
                    ))
                }

                // Collect and sort all scene items by chronology
                let sortedItems = collectAndSortItems(scene: scene, seqIndex: seqIndex, sceneIdx: sceneIdx)
                var lastCharacter: String?

                for item in sortedItems {
                    switch item {
                    case .dialogue(let d, let seqI, let scI):
                        // Check for (CONT'D)
                        let isContinued = (d.character.uppercased() == lastCharacter)

                        // Character name
                        var charText = d.character.uppercased()
                        if isContinued {
                            charText += " (CONT'D)"
                        }
                        elements.append(ScriptElement(
                            type: .character,
                            text: charText,
                            sourceSequenceIndex: seqI,
                            sourceSceneIndex: scI,
                            sourceItemId: d.uuid,
                            sourceItemType: "dialogue",
                            isContinued: isContinued
                        ))

                        // Parenthetical from tags
                        if !d.tags.isEmpty {
                            let parenthetical = "(\(d.tags.joined(separator: ", ")))"
                            elements.append(ScriptElement(
                                type: .parenthetical,
                                text: parenthetical,
                                sourceSequenceIndex: seqI,
                                sourceSceneIndex: scI,
                                sourceItemId: d.uuid,
                                sourceItemType: "dialogue"
                            ))
                        }

                        // Dialogue text
                        elements.append(ScriptElement(
                            type: .dialogue,
                            text: d.text,
                            sourceSequenceIndex: seqI,
                            sourceSceneIndex: scI,
                            sourceItemId: d.uuid,
                            sourceItemType: "dialogue"
                        ))

                        lastCharacter = d.character.uppercased()

                    case .action(let a, let seqI, let scI):
                        elements.append(ScriptElement(
                            type: .action,
                            text: a.description,
                            sourceSequenceIndex: seqI,
                            sourceSceneIndex: scI,
                            sourceItemId: a.uuid,
                            sourceItemType: "action"
                        ))
                        lastCharacter = nil // reset CONT'D tracking

                    case .narration(let n, let seqI, let scI):
                        elements.append(ScriptElement(
                            type: .action,
                            text: n.text,
                            sourceSequenceIndex: seqI,
                            sourceSceneIndex: scI,
                            sourceItemId: n.uuid,
                            sourceItemType: "narration"
                        ))
                        lastCharacter = nil

                    case .note(let n, let seqI, let scI):
                        elements.append(ScriptElement(
                            type: .scriptNote,
                            text: "[[\(n.content)]]",
                            sourceSequenceIndex: seqI,
                            sourceSceneIndex: scI,
                            sourceItemId: n.uuid,
                            sourceItemType: "note"
                        ))

                    case .soundNote(let s, let seqI, let scI):
                        var cueText = "SFX: \(s.soundType.uppercased())"
                        if !s.description.isEmpty {
                            cueText += " - \(s.description)"
                        }
                        elements.append(ScriptElement(
                            type: .soundCue,
                            text: cueText,
                            sourceSequenceIndex: seqI,
                            sourceSceneIndex: scI,
                            sourceItemId: s.uuid,
                            sourceItemType: "soundNote"
                        ))
                    }
                }

                // Blank line between scenes
                elements.append(ScriptElement(type: .blankLine, text: ""))

                sceneNumber += 1
            }
        }

        return elements
    }

    // MARK: - Reverse Sync (ScriptElement edits -> Project mutations)

    /// Apply text edits from a ScriptElement back to the Project model.
    /// Handles both editing existing items and creating new ones (e.g. when the user
    /// types a character name + dialogue in the script that has no backing model object).
    /// Returns the sourceItemId of the created/edited item (nil if no creation).
    @discardableResult
    static func applyEdit(element: ScriptElement, newText: String, to project: inout Project) -> String? {
        guard let seqIdx = element.sourceSequenceIndex,
              let sceneIdx = element.sourceSceneIndex,
              seqIdx < project.sequences.count,
              sceneIdx < project.sequences[seqIdx].scenes.count else { return nil }

        guard let itemId = element.sourceItemId,
              let itemType = element.sourceItemType else {
            // No sourceItemId — could be a scene-level element or a new element
            // created via Tab cycling / autocomplete that doesn't yet have a backing model object.
            if element.type == .sceneHeading {
                let parsed = parseSceneHeading(newText)
                project.sequences[seqIdx].scenes[sceneIdx].location = parsed
            } else if element.type == .action && element.sourceItemId == nil && element.sourceItemType == nil {
                // Scene description (no sourceItemId) — update scene.description
                project.sequences[seqIdx].scenes[sceneIdx].description = newText
            } else if element.type == .dialogue {
                // Dialogue element with no backing object — try to find the most recently
                // created Dialogue with empty text (from the preceding character element)
                let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                let dialogues = project.sequences[seqIdx].scenes[sceneIdx].dialogues
                if let dIdx = dialogues.lastIndex(where: {
                    $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.character.isEmpty
                }) {
                    project.sequences[seqIdx].scenes[sceneIdx].dialogues[dIdx].text = trimmed
                    return project.sequences[seqIdx].scenes[sceneIdx].dialogues[dIdx].uuid
                }

                // No matching Dialogue found — create a new one
                let nextChronology = (dialogues.map(\.chronologyNumber).max() ?? 0) + 1
                let newDialogue = Dialogue(
                    character: "",
                    text: trimmed,
                    chronologyNumber: nextChronology,
                    globalChronologyNumber: nextChronology
                )
                project.sequences[seqIdx].scenes[sceneIdx].dialogues.append(newDialogue)
                return newDialogue.uuid
            } else if element.type == .character {
                // Character element with no backing object — create a new Dialogue
                let typed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " (CONT'D)", with: "")
                // Editor v2: cues are typed/rendered UPPERCASE, but the stored
                // speaker must be the CANONICAL Character name so bubble-view
                // identity, avatars, and rename cascades keep matching.
                let trimmed = project.characters
                    .first { $0.name.compare(typed, options: .caseInsensitive) == .orderedSame }?
                    .name ?? typed
                guard !trimmed.isEmpty else { return nil }

                let nextChronology = (project.sequences[seqIdx].scenes[sceneIdx].dialogues.map(\.chronologyNumber).max() ?? 0) + 1
                let newDialogue = Dialogue(
                    character: trimmed,
                    text: "",
                    chronologyNumber: nextChronology,
                    globalChronologyNumber: nextChronology
                )
                project.sequences[seqIdx].scenes[sceneIdx].dialogues.append(newDialogue)
                return newDialogue.uuid
            }
            return nil
        }

        switch itemType {
        case "dialogue":
            if element.type == .dialogue {
                if let dIdx = project.sequences[seqIdx].scenes[sceneIdx].dialogues.firstIndex(where: { $0.uuid == itemId }) {
                    project.sequences[seqIdx].scenes[sceneIdx].dialogues[dIdx].text = newText
                }
            } else if element.type == .character {
                let typed = newText.replacingOccurrences(of: " (CONT'D)", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Canonicalize to the existing Character's name (Editor v2) so
                // bubble-view matching and rename cascades keep working.
                let cleanName = project.characters
                    .first { $0.name.compare(typed, options: .caseInsensitive) == .orderedSame }?
                    .name ?? typed
                if let dIdx = project.sequences[seqIdx].scenes[sceneIdx].dialogues.firstIndex(where: { $0.uuid == itemId }) {
                    project.sequences[seqIdx].scenes[sceneIdx].dialogues[dIdx].character = cleanName
                }
            }

        case "action":
            if let aIdx = project.sequences[seqIdx].scenes[sceneIdx].actions.firstIndex(where: { $0.uuid == itemId }) {
                project.sequences[seqIdx].scenes[sceneIdx].actions[aIdx].description = newText
            }

        case "narration":
            if let nIdx = project.sequences[seqIdx].scenes[sceneIdx].narrations.firstIndex(where: { $0.uuid == itemId }) {
                project.sequences[seqIdx].scenes[sceneIdx].narrations[nIdx].text = newText
            }

        case "scene":
            // Editing scene heading — update location
            project.sequences[seqIdx].scenes[sceneIdx].location = parseSceneHeading(newText)

        default:
            break
        }
        return nil
    }

    // MARK: - Scene Management Helpers

    /// Create a new scene in the project after the given element index.
    /// Returns (sequenceIndex, sceneIndex) of the newly created scene, or nil on failure.
    static func createScene(
        afterElementIndex: Int,
        elements: [ScriptElement],
        in project: inout Project
    ) -> (sequenceIndex: Int, sceneIndex: Int)? {
        // Determine target sequence from the element at cursor
        var targetSeqIdx: Int? = nil
        var insertAfterSceneIdx: Int? = nil

        if afterElementIndex < elements.count {
            let element = elements[afterElementIndex]
            targetSeqIdx = element.sourceSequenceIndex
            insertAfterSceneIdx = element.sourceSceneIndex
        }

        // If no sequences exist, create a default "Act 1"
        if project.sequences.isEmpty {
            let newSequence = DirectorsChairCore.Sequence(name: "Act 1")
            project.sequences.append(newSequence)
            targetSeqIdx = 0
        }

        let seqIdx = targetSeqIdx ?? 0
        guard seqIdx < project.sequences.count else { return nil }

        // Generate a unique scene name
        let existingNames = Set(project.sequences.flatMap { $0.scenes.map { $0.name } })
        var counter = project.sequences.flatMap({ $0.scenes }).count + 1
        var sceneName = "Scene \(counter)"
        while existingNames.contains(sceneName) {
            counter += 1
            sceneName = "Scene \(counter)"
        }

        // Create the scene with placeholder location
        let newScene = DirectorsChairCore.Scene(
            name: sceneName,
            location: "INT. LOCATION - TIME OF DAY"
        )

        // Insert at the correct position
        let sceneInsertIdx: Int
        if let afterIdx = insertAfterSceneIdx {
            sceneInsertIdx = afterIdx + 1
        } else {
            sceneInsertIdx = project.sequences[seqIdx].scenes.count
        }

        project.sequences[seqIdx].scenes.insert(newScene, at: sceneInsertIdx)

        // Split scene content: move items that come AFTER the cursor from the old
        // scene into the newly created scene.  This lets users insert a scene break
        // in the middle of existing content instead of always appending at the end.
        if let oldSceneIdx = insertAfterSceneIdx,
           afterElementIndex < elements.count,
           elements[afterElementIndex].type != .sceneHeading {

            // Collect sourceItemIds of elements AFTER the cursor that still belong
            // to the old scene.  Skip blank lines / unsaved elements (nil indices)
            // but stop when we reach a different scene.
            var itemIdsToMove: Set<String> = []
            for i in (afterElementIndex + 1)..<elements.count {
                let el = elements[i]
                // Skip elements with nil source indices (blank lines, unsaved)
                if el.sourceSequenceIndex == nil || el.sourceSceneIndex == nil {
                    continue
                }
                // Stop when we reach a different scene
                guard el.sourceSequenceIndex == seqIdx,
                      el.sourceSceneIndex == oldSceneIdx else {
                    break
                }
                if let itemId = el.sourceItemId {
                    itemIdsToMove.insert(itemId)
                }
            }

            if !itemIdsToMove.isEmpty {
                // Identify moved dialogue UUIDs so we also move their child sub-bubbles
                // (actions/narrations/notes/soundNotes with parentDialogueId)
                let movedDialogueIds = Set(
                    project.sequences[seqIdx].scenes[oldSceneIdx].dialogues
                        .filter { itemIdsToMove.contains($0.uuid) }
                        .map { $0.uuid }
                )

                let shouldMove: (String?, String) -> Bool = { parentId, uuid in
                    itemIdsToMove.contains(uuid) ||
                    (parentId != nil && movedDialogueIds.contains(parentId!))
                }

                // Move dialogues
                let dlgToMove = project.sequences[seqIdx].scenes[oldSceneIdx].dialogues
                    .filter { itemIdsToMove.contains($0.uuid) }
                project.sequences[seqIdx].scenes[sceneInsertIdx].dialogues.append(contentsOf: dlgToMove)
                project.sequences[seqIdx].scenes[oldSceneIdx].dialogues.removeAll {
                    itemIdsToMove.contains($0.uuid)
                }

                // Move actions (top-level + children of moved dialogues)
                let actToMove = project.sequences[seqIdx].scenes[oldSceneIdx].actions
                    .filter { shouldMove($0.parentDialogueId, $0.uuid) }
                project.sequences[seqIdx].scenes[sceneInsertIdx].actions.append(contentsOf: actToMove)
                project.sequences[seqIdx].scenes[oldSceneIdx].actions.removeAll {
                    shouldMove($0.parentDialogueId, $0.uuid)
                }

                // Move narrations
                let narToMove = project.sequences[seqIdx].scenes[oldSceneIdx].narrations
                    .filter { shouldMove($0.parentDialogueId, $0.uuid) }
                project.sequences[seqIdx].scenes[sceneInsertIdx].narrations.append(contentsOf: narToMove)
                project.sequences[seqIdx].scenes[oldSceneIdx].narrations.removeAll {
                    shouldMove($0.parentDialogueId, $0.uuid)
                }

                // Move notes
                let notToMove = project.sequences[seqIdx].scenes[oldSceneIdx].sceneNotes
                    .filter { shouldMove($0.parentDialogueId, $0.uuid) }
                project.sequences[seqIdx].scenes[sceneInsertIdx].sceneNotes.append(contentsOf: notToMove)
                project.sequences[seqIdx].scenes[oldSceneIdx].sceneNotes.removeAll {
                    shouldMove($0.parentDialogueId, $0.uuid)
                }

                // Move sound notes
                let sndToMove = project.sequences[seqIdx].scenes[oldSceneIdx].soundNotes
                    .filter { shouldMove($0.parentDialogueId, $0.uuid) }
                project.sequences[seqIdx].scenes[sceneInsertIdx].soundNotes.append(contentsOf: sndToMove)
                project.sequences[seqIdx].scenes[oldSceneIdx].soundNotes.removeAll {
                    shouldMove($0.parentDialogueId, $0.uuid)
                }
            }
        }

        return (sequenceIndex: seqIdx, sceneIndex: sceneInsertIdx)
    }

    /// Delete the scene referenced by the given scene heading element.
    /// Returns true if the scene was successfully removed.
    @discardableResult
    static func deleteScene(
        elementId: UUID,
        elements: [ScriptElement],
        from project: inout Project
    ) -> Bool {
        guard let element = elements.first(where: { $0.id == elementId }),
              element.type == .sceneHeading,
              let seqIdx = element.sourceSequenceIndex,
              let sceneIdx = element.sourceSceneIndex,
              seqIdx < project.sequences.count,
              sceneIdx < project.sequences[seqIdx].scenes.count else {
            return false
        }

        project.sequences[seqIdx].scenes.remove(at: sceneIdx)
        return true
    }

    // MARK: - Scene Outline

    /// Extract scene outline items from elements for the navigator
    static func extractSceneOutline(from elements: [ScriptElement]) -> [SceneOutlineItem] {
        return elements.compactMap { element in
            guard element.type == .sceneHeading, let sceneNum = element.sceneNumber else { return nil }
            return SceneOutlineItem(
                id: UUID(),
                sceneNumber: sceneNum,
                heading: element.text,
                elementId: element.id
            )
        }
    }

    // MARK: - Utility: Find Scene Context

    /// Walk backwards from the given element index to find the nearest scene heading's
    /// sequence/scene indices. Useful for elements that lack their own source indices.
    static func findSceneContext(at elementIndex: Int, in elements: [ScriptElement]) -> (sequenceIndex: Int, sceneIndex: Int)? {
        for i in stride(from: elementIndex, through: 0, by: -1) {
            let el = elements[i]
            if let seqIdx = el.sourceSequenceIndex, let scnIdx = el.sourceSceneIndex {
                return (seqIdx, scnIdx)
            }
        }
        return nil
    }

    // MARK: - Private Helpers

    private enum SortedItem {
        case dialogue(Dialogue, Int, Int)
        case action(Action, Int, Int)
        case narration(Narration, Int, Int)
        case note(Note, Int, Int)
        case soundNote(SoundNote, Int, Int)

        var chronologyNumber: Int {
            switch self {
            case .dialogue(let d, _, _): return d.chronologyNumber
            case .action(let a, _, _): return a.chronologyNumber
            case .narration(let n, _, _): return n.chronologyNumber
            case .note(let n, _, _): return n.chronologyNumber
            case .soundNote(let s, _, _): return s.chronologyNumber
            }
        }
    }

    private static func collectAndSortItems(scene: DirectorsChairCore.Scene, seqIndex: Int, sceneIdx: Int) -> [SortedItem] {
        var items: [SortedItem] = []

        // Only include top-level items (no parentDialogueId = not sub-bubbles)
        for d in scene.dialogues {
            items.append(.dialogue(d, seqIndex, sceneIdx))
        }
        for a in scene.actions where a.parentDialogueId == nil {
            items.append(.action(a, seqIndex, sceneIdx))
        }
        for n in scene.narrations where n.parentDialogueId == nil {
            items.append(.narration(n, seqIndex, sceneIdx))
        }
        for n in scene.sceneNotes where n.parentDialogueId == nil {
            items.append(.note(n, seqIndex, sceneIdx))
        }
        for s in scene.soundNotes where s.parentDialogueId == nil {
            items.append(.soundNote(s, seqIndex, sceneIdx))
        }

        return items.sorted { $0.chronologyNumber < $1.chronologyNumber }
    }

    private static func buildSceneHeading(_ scene: DirectorsChairCore.Scene, sequenceLocation: String?) -> String {
        let location = scene.location ?? sequenceLocation ?? scene.name
        let locationUpper = location.uppercased()

        if locationUpper.hasPrefix("INT") || locationUpper.hasPrefix("EXT") {
            if locationUpper.contains(" - ") {
                return locationUpper
            }
            return "\(locationUpper) - DAY"
        }

        return "INT. \(locationUpper) - DAY"
    }

    private static func parseSceneHeading(_ heading: String) -> String {
        // Extract location from heading like "INT. BEDROOM - DAY"
        return heading
    }
}
