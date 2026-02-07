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

    /// Apply text edits from a ScriptElement back to the Project model
    static func applyEdit(element: ScriptElement, newText: String, to project: inout Project) {
        guard let seqIdx = element.sourceSequenceIndex,
              let sceneIdx = element.sourceSceneIndex,
              seqIdx < project.sequences.count,
              sceneIdx < project.sequences[seqIdx].scenes.count else { return }

        guard let itemId = element.sourceItemId,
              let itemType = element.sourceItemType else {
            // Scene heading or description edit (no sourceItemId = scene-level element)
            if element.type == .sceneHeading {
                // Update scene location from heading
                let parsed = parseSceneHeading(newText)
                project.sequences[seqIdx].scenes[sceneIdx].location = parsed
            } else if element.type == .action {
                // Scene description (action element without sourceItemId)
                project.sequences[seqIdx].scenes[sceneIdx].description = newText
            }
            return
        }

        switch itemType {
        case "dialogue":
            if element.type == .dialogue {
                if let dIdx = project.sequences[seqIdx].scenes[sceneIdx].dialogues.firstIndex(where: { $0.uuid == itemId }) {
                    project.sequences[seqIdx].scenes[sceneIdx].dialogues[dIdx].text = newText
                }
            } else if element.type == .character {
                // Character name edit - strip (CONT'D) and update character field
                let cleanName = newText.replacingOccurrences(of: " (CONT'D)", with: "")
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

        default:
            break
        }
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
