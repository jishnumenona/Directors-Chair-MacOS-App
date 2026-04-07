// TestFixtures.swift
// Deterministic mock data factories for snapshot testing

import Foundation
@testable import DirectorsChairCore
@testable import DirectorsChairViews

enum TestFixtures {

    // MARK: - Stable IDs (hardcoded for snapshot determinism)

    static let characterId1 = "test-char-001"
    static let characterId2 = "test-char-002"
    static let dialogueId1 = "test-dialogue-001"
    static let dialogueId2 = "test-dialogue-002"
    static let actionId1 = "test-action-001"
    static let narrationId1 = "test-narration-001"
    static let noteId1 = "test-note-001"
    static let soundNoteId1 = "test-soundnote-001"
    static let shotId1 = "test-shot-001"
    static let shotId2 = "test-shot-002"
    static let sceneId1 = "test-scene-001"
    static let sequenceId1 = "test-seq-001"
    static let visionCardId1 = "test-vcard-001"

    // MARK: - Character

    static func character(
        name: String = "Jane Doe",
        role: String = "Lead",
        color: String = "#3498db",
        textColor: String = "#FFFFFF",
        characterId: String = characterId1
    ) -> Character {
        Character(
            characterId: characterId,
            name: name,
            role: role,
            color: color,
            textColor: textColor,
            about: "A determined protagonist"
        )
    }

    // MARK: - Dialogue

    static func dialogue(
        character: String = "Jane Doe",
        text: String = "We need to leave before sunrise.",
        chronologyNumber: Int = 1,
        uuid: String = dialogueId1,
        tags: [String] = []
    ) -> Dialogue {
        Dialogue(
            uuid: uuid,
            character: character,
            text: text,
            tags: tags,
            chronologyNumber: chronologyNumber
        )
    }

    // MARK: - Action

    static func action(
        description: String = "Walks across the room to the window.",
        chronologyNumber: Int = 2,
        uuid: String = actionId1,
        characters: [String] = ["Jane Doe"]
    ) -> Action {
        Action(
            uuid: uuid,
            description: description,
            chronologyNumber: chronologyNumber,
            characters: characters
        )
    }

    // MARK: - Narration

    static func narration(
        text: String = "The wind howled through the empty corridors.",
        chronologyNumber: Int = 3,
        uuid: String = narrationId1,
        characters: [String] = []
    ) -> Narration {
        Narration(
            uuid: uuid,
            text: text,
            chronologyNumber: chronologyNumber,
            characters: characters
        )
    }

    // MARK: - Note

    static func note(
        content: String = "Remember to add foley sounds here.",
        noteType: String = "text",
        title: String = "Production Note",
        uuid: String = noteId1
    ) -> Note {
        Note(
            uuid: uuid,
            content: content,
            noteType: noteType,
            chronologyNumber: 4,
            title: title
        )
    }

    // MARK: - SoundNote

    static func soundNote(
        description: String = "Rain on rooftop",
        soundType: String = "ambient",
        volume: Int = 70,
        uuid: String = soundNoteId1
    ) -> SoundNote {
        SoundNote(
            uuid: uuid,
            description: description,
            soundType: soundType,
            chronologyNumber: 5,
            volume: volume,
            loop: true
        )
    }

    // MARK: - Shot

    static func shot(
        shotId: Int = 1,
        description: String = "Close-up of Jane's face as she turns",
        uuid: String = shotId1,
        status: String = "Planning",
        cameraAngle: String = "Close-up",
        lensMm: Int = 85
    ) -> Shot {
        Shot(
            uuid: uuid,
            shotId: shotId,
            description: description,
            status: status,
            cameraAngle: cameraAngle,
            lensMm: lensMm
        )
    }

    // MARK: - Scene

    static func scene(
        name: String = "Scene 1 - INT. LIVING ROOM - NIGHT",
        uuid: String = sceneId1
    ) -> Scene {
        Scene(
            uuid: uuid,
            name: name,
            dialogues: [
                dialogue(character: "Jane Doe", text: "We need to leave.", chronologyNumber: 1, uuid: dialogueId1),
                dialogue(character: "Mark", text: "Not yet.", chronologyNumber: 2, uuid: dialogueId2),
            ],
            actions: [
                action(description: "Jane stands up abruptly.", chronologyNumber: 3, uuid: actionId1)
            ],
            shots: [
                shot(shotId: 1, description: "Wide establishing", uuid: shotId1),
                shot(shotId: 2, description: "Close-up dialogue", uuid: shotId2),
            ],
            location: "Living Room"
        )
    }

    // MARK: - Sequence

    static func sequence(
        name: String = "Act 1",
        uuid: String = sequenceId1
    ) -> Sequence {
        Sequence(
            uuid: uuid,
            name: name,
            scenes: [scene()]
        )
    }

    // MARK: - Project

    static func project(
        name: String = "Test Film"
    ) -> Project {
        Project(
            name: name,
            characters: [
                character(name: "Jane Doe", role: "Lead", color: "#3498db", characterId: characterId1),
                character(name: "Mark", role: "Supporting", color: "#e74c3c", characterId: characterId2),
            ],
            sequences: [sequence()]
        )
    }

    // MARK: - VisionCard

    static func visionCard(
        title: String = "Moody Lighting Ref",
        cardType: String = "image",
        id: String = visionCardId1
    ) -> VisionCard {
        VisionCard(
            id: id,
            title: title,
            cardType: cardType,
            size: "medium"
        )
    }

    static func textVisionCard(
        title: String = "Director's Note",
        text: String = "Focus on the tension between light and shadow.",
        id: String = "test-vcard-text"
    ) -> VisionCard {
        VisionCard(
            id: id,
            title: title,
            text: text,
            cardType: "text",
            size: "medium"
        )
    }

    // MARK: - TimelineSegment

    static func timelineSegment(
        character: String = "Jane Doe",
        text: String = "We need to leave.",
        contentType: TimelineSegment.ContentType = .dialogue
    ) -> TimelineSegment {
        TimelineSegment(
            start: 0,
            duration: 120,
            character: character,
            color: "#3498db",
            textColor: "#FFFFFF",
            text: text,
            sceneName: "Scene 1",
            contentType: contentType,
            chronologyNumber: 1,
            propsCount: 0,
            hasAudio: false
        )
    }

    // MARK: - ScriptItem helpers

    static func scriptItemDialogue() -> ScriptItem {
        .dialogue(dialogue())
    }

    static func scriptItemAction() -> ScriptItem {
        .action(action())
    }

    static func scriptItemNarration() -> ScriptItem {
        .narration(narration())
    }
}
