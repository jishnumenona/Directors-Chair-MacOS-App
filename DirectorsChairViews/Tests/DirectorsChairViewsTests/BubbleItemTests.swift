// DirectorsChairViews/Tests/DirectorsChairViewsTests/BubbleItemTests.swift
//
// Tests for dialogue, action, narration, note, and sound note item operations

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class BubbleItemTests: XCTestCase {

    // MARK: - Dialogue Creation

    func testCreateDialogue() {
        let dialogue = Dialogue(
            character: "Sarah",
            text: "We need to leave now.",
            tags: ["urgent", "whisper"],
            chronologyNumber: 3,
            globalChronologyNumber: 12
        )

        XCTAssertEqual(dialogue.character, "Sarah")
        XCTAssertEqual(dialogue.text, "We need to leave now.")
        XCTAssertEqual(dialogue.tags, ["urgent", "whisper"])
        XCTAssertEqual(dialogue.chronologyNumber, 3)
        XCTAssertEqual(dialogue.globalChronologyNumber, 12)
        XCTAssertFalse(dialogue.uuid.isEmpty, "UUID should be auto-generated")
        XCTAssertEqual(dialogue.id, dialogue.uuid, "id should return uuid")
        XCTAssertNil(dialogue.audioFilePath)
        XCTAssertNil(dialogue.manualDuration)
        XCTAssertNil(dialogue.manualStartTime)
        XCTAssertTrue(dialogue.costumes.isEmpty)
        XCTAssertTrue(dialogue.effects.isEmpty)
    }

    func testCreateDialogueWithDefaults() {
        let dialogue = Dialogue(character: "Bob", text: "Hello", chronologyNumber: 1)

        XCTAssertEqual(dialogue.character, "Bob")
        XCTAssertEqual(dialogue.text, "Hello")
        XCTAssertEqual(dialogue.chronologyNumber, 1)
        XCTAssertEqual(dialogue.globalChronologyNumber, 0)
        XCTAssertTrue(dialogue.tags.isEmpty)
        XCTAssertTrue(dialogue.costumes.isEmpty)
        XCTAssertTrue(dialogue.effects.isEmpty)
    }

    func testDialogueWithCustomUUID() {
        let customUUID = "custom-dialogue-uuid-123"
        let dialogue = Dialogue(uuid: customUUID, character: "Test", text: "Test", chronologyNumber: 1)

        XCTAssertEqual(dialogue.uuid, customUUID)
        XCTAssertEqual(dialogue.id, customUUID)
    }

    // MARK: - Action Creation

    func testCreateAction() {
        let action = Action(
            description: "The door slams shut behind them.",
            tags: ["dramatic", "loud"],
            chronologyNumber: 4,
            globalChronologyNumber: 15,
            characters: ["Sarah", "John"]
        )

        XCTAssertEqual(action.description, "The door slams shut behind them.")
        XCTAssertEqual(action.tags, ["dramatic", "loud"])
        XCTAssertEqual(action.chronologyNumber, 4)
        XCTAssertEqual(action.globalChronologyNumber, 15)
        XCTAssertEqual(action.characters, ["Sarah", "John"])
        XCTAssertFalse(action.uuid.isEmpty, "UUID should be auto-generated")
        XCTAssertEqual(action.id, action.uuid)
        XCTAssertNil(action.parentDialogueId)
        XCTAssertTrue(action.color.isEmpty)
        XCTAssertTrue(action.textColor.isEmpty)
    }

    func testCreateActionWithDefaults() {
        let action = Action(description: "Walks across room", chronologyNumber: 1, characters: [])

        XCTAssertEqual(action.description, "Walks across room")
        XCTAssertEqual(action.chronologyNumber, 1)
        XCTAssertTrue(action.characters.isEmpty)
        XCTAssertTrue(action.tags.isEmpty)
        XCTAssertNil(action.parentDialogueId)
        XCTAssertNil(action.manualStartTime)
    }

    // MARK: - Narration Creation

    func testCreateNarration() {
        let narration = Narration(
            text: "The sun set slowly over the abandoned city.",
            tags: ["melancholic", "visual"],
            chronologyNumber: 2,
            globalChronologyNumber: 8,
            characters: ["Narrator"]
        )

        XCTAssertEqual(narration.text, "The sun set slowly over the abandoned city.")
        XCTAssertEqual(narration.tags, ["melancholic", "visual"])
        XCTAssertEqual(narration.chronologyNumber, 2)
        XCTAssertEqual(narration.globalChronologyNumber, 8)
        XCTAssertEqual(narration.characters, ["Narrator"])
        XCTAssertFalse(narration.uuid.isEmpty)
        XCTAssertEqual(narration.id, narration.uuid)
        XCTAssertNil(narration.parentDialogueId)
    }

    func testCreateNarrationWithDefaults() {
        let narration = Narration(text: "Voice over text", chronologyNumber: 1, characters: [])

        XCTAssertEqual(narration.text, "Voice over text")
        XCTAssertTrue(narration.color.isEmpty)
        XCTAssertTrue(narration.textColor.isEmpty)
        XCTAssertNil(narration.parentDialogueId)
    }

    // MARK: - Parent Dialogue Linking

    func testParentDialogueIdLinking() {
        let parentDialogue = Dialogue(
            uuid: "parent-dialogue-001",
            character: "Alice",
            text: "Look at that!",
            chronologyNumber: 1
        )

        let childAction = Action(
            description: "Points dramatically at the window",
            chronologyNumber: 2,
            characters: ["Alice"],
            parentDialogueId: parentDialogue.uuid
        )

        let childNarration = Narration(
            text: "Her voice trembled with excitement.",
            chronologyNumber: 3,
            characters: [],
            parentDialogueId: parentDialogue.uuid
        )

        XCTAssertEqual(childAction.parentDialogueId, "parent-dialogue-001")
        XCTAssertEqual(childAction.parentDialogueId, parentDialogue.uuid)
        XCTAssertEqual(childNarration.parentDialogueId, "parent-dialogue-001")
        XCTAssertEqual(childNarration.parentDialogueId, parentDialogue.uuid)
    }

    func testOrphanedItemHasNilParent() {
        let standaloneAction = Action(
            description: "A car drives by",
            chronologyNumber: 1,
            characters: []
        )

        let standaloneNarration = Narration(
            text: "Time passes slowly.",
            chronologyNumber: 2,
            characters: []
        )

        let standaloneNote = Note(
            content: "Remember to add foley",
            noteType: "text",
            chronologyNumber: 3
        )

        let standaloneSoundNote = SoundNote(
            description: "Background traffic",
            soundType: "ambient",
            chronologyNumber: 4
        )

        XCTAssertNil(standaloneAction.parentDialogueId)
        XCTAssertNil(standaloneNarration.parentDialogueId)
        XCTAssertNil(standaloneNote.parentDialogueId)
        XCTAssertNil(standaloneSoundNote.parentDialogueId)
    }

    // MARK: - Reorder Dialogues

    func testReorderDialogues() {
        var dialogues = [
            Dialogue(character: "A", text: "First", chronologyNumber: 1),
            Dialogue(character: "B", text: "Second", chronologyNumber: 2),
            Dialogue(character: "C", text: "Third", chronologyNumber: 3),
        ]

        // Move the last element to the front
        let moved = dialogues.remove(at: 2)
        dialogues.insert(moved, at: 0)

        XCTAssertEqual(dialogues[0].character, "C")
        XCTAssertEqual(dialogues[1].character, "A")
        XCTAssertEqual(dialogues[2].character, "B")

        // Re-assign chronology numbers after reorder
        for i in dialogues.indices {
            dialogues[i].chronologyNumber = i + 1
        }

        XCTAssertEqual(dialogues[0].chronologyNumber, 1)
        XCTAssertEqual(dialogues[1].chronologyNumber, 2)
        XCTAssertEqual(dialogues[2].chronologyNumber, 3)
    }

    func testReorderWithParentChildren() {
        let parentId = "parent-uuid"
        let parent = Dialogue(uuid: parentId, character: "Hero", text: "Watch out!", chronologyNumber: 1)
        let childAction = Action(
            description: "Ducks behind cover",
            chronologyNumber: 2,
            characters: ["Hero"],
            parentDialogueId: parentId
        )
        let childNarration = Narration(
            text: "Just in time.",
            chronologyNumber: 3,
            characters: [],
            parentDialogueId: parentId
        )

        // Build a combined list representing the scene order
        let items: [(id: String, parentId: String?, chrono: Int)] = [
            (parent.uuid, nil, parent.chronologyNumber),
            (childAction.uuid, childAction.parentDialogueId, childAction.chronologyNumber),
            (childNarration.uuid, childNarration.parentDialogueId, childNarration.chronologyNumber),
        ]

        // Simulate reorder: move parent (and children) to end
        // First identify children
        let parentItem = items[0]
        let children = items.filter { $0.parentId == parentItem.id }

        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(children[0].id, childAction.uuid)
        XCTAssertEqual(children[1].id, childNarration.uuid)

        // After reorder, children should still link to the same parent
        for child in children {
            XCTAssertEqual(child.parentId, parentId)
        }
    }

    // MARK: - Delete Dialogue

    func testDeleteDialogueRemovesFromList() {
        var dialogues = [
            Dialogue(uuid: "d1", character: "A", text: "Line 1", chronologyNumber: 1),
            Dialogue(uuid: "d2", character: "B", text: "Line 2", chronologyNumber: 2),
            Dialogue(uuid: "d3", character: "C", text: "Line 3", chronologyNumber: 3),
        ]

        let toRemove = dialogues[1]
        dialogues.removeAll { $0.id == toRemove.id }

        XCTAssertEqual(dialogues.count, 2)
        XCTAssertFalse(dialogues.contains(where: { $0.id == "d2" }))
        XCTAssertTrue(dialogues.contains(where: { $0.id == "d1" }))
        XCTAssertTrue(dialogues.contains(where: { $0.id == "d3" }))
    }

    // MARK: - Note Creation

    func testNoteCreation() {
        let note = Note(
            content: "Remember to check continuity here",
            noteType: "text",
            chronologyNumber: 5,
            title: "Continuity Check"
        )

        XCTAssertEqual(note.content, "Remember to check continuity here")
        XCTAssertEqual(note.noteType, "text")
        XCTAssertEqual(note.chronologyNumber, 5)
        XCTAssertEqual(note.title, "Continuity Check")
        XCTAssertFalse(note.uuid.isEmpty)
        XCTAssertEqual(note.id, note.uuid)
        XCTAssertNil(note.parentDialogueId)
        XCTAssertTrue(note.metadata.isEmpty)
    }

    func testNoteWithParentDialogue() {
        let note = Note(
            content: "Actor should pause here",
            noteType: "text",
            chronologyNumber: 2,
            title: "Direction",
            parentDialogueId: "dialogue-123"
        )

        XCTAssertEqual(note.parentDialogueId, "dialogue-123")
    }

    func testNoteWithMetadata() {
        let note = Note(
            content: "https://youtube.com/watch?v=abc",
            noteType: "youtube",
            chronologyNumber: 1,
            title: "Reference Video",
            metadata: ["videoId": "abc", "duration": "3:45"]
        )

        XCTAssertEqual(note.noteType, "youtube")
        XCTAssertEqual(note.metadata["videoId"], "abc")
        XCTAssertEqual(note.metadata["duration"], "3:45")
    }

    // MARK: - SoundNote Creation

    func testSoundNoteCreation() {
        let soundNote = SoundNote(
            description: "Rain falling on rooftop",
            soundType: "ambient",
            chronologyNumber: 7,
            volume: 65,
            loop: true,
            fadeInDuration: 2.0,
            fadeOutDuration: 1.5
        )

        XCTAssertEqual(soundNote.description, "Rain falling on rooftop")
        XCTAssertEqual(soundNote.soundType, "ambient")
        XCTAssertEqual(soundNote.chronologyNumber, 7)
        XCTAssertEqual(soundNote.volume, 65)
        XCTAssertTrue(soundNote.loop)
        XCTAssertEqual(soundNote.fadeInDuration, 2.0)
        XCTAssertEqual(soundNote.fadeOutDuration, 1.5)
        XCTAssertFalse(soundNote.uuid.isEmpty)
        XCTAssertEqual(soundNote.id, soundNote.uuid)
        XCTAssertNil(soundNote.parentDialogueId)
        XCTAssertNil(soundNote.audioFilePath)
        XCTAssertNil(soundNote.startTime)
        XCTAssertNil(soundNote.endTime)
    }

    func testSoundNoteVolumeClamp() {
        // Volume should clamp to 0-100
        let loudNote = SoundNote(
            description: "Explosion",
            soundType: "effects",
            chronologyNumber: 1,
            volume: 150,
            loop: false
        )
        XCTAssertEqual(loudNote.volume, 100, "Volume above 100 should be clamped to 100")

        let silentNote = SoundNote(
            description: "Silence",
            soundType: "ambient",
            chronologyNumber: 2,
            volume: -10,
            loop: false
        )
        XCTAssertEqual(silentNote.volume, 0, "Volume below 0 should be clamped to 0")
    }

    func testSoundNoteWithParentDialogue() {
        let soundNote = SoundNote(
            description: "Phone ringing",
            soundType: "effects",
            chronologyNumber: 3,
            volume: 80,
            loop: false,
            parentDialogueId: "dialogue-456"
        )

        XCTAssertEqual(soundNote.parentDialogueId, "dialogue-456")
    }

    func testSoundNoteFadeDurationClampsNegative() {
        let soundNote = SoundNote(
            description: "Test",
            soundType: "ambient",
            chronologyNumber: 1,
            volume: 50,
            loop: false,
            fadeInDuration: -5.0,
            fadeOutDuration: -3.0
        )

        XCTAssertEqual(soundNote.fadeInDuration, 0.0, "Negative fade in should be clamped to 0")
        XCTAssertEqual(soundNote.fadeOutDuration, 0.0, "Negative fade out should be clamped to 0")
    }

    // MARK: - Dialogue Codable

    func testDialogueCodableRoundTrip() throws {
        let original = Dialogue(
            uuid: "test-uuid-roundtrip",
            character: "Hero",
            text: "I shall return!",
            tags: ["dramatic"],
            costumes: ["armor"],
            effects: ["echo"],
            chronologyNumber: 5,
            globalChronologyNumber: 42,
            audioFilePath: "/audio/hero_01.mp3",
            manualDuration: 3.5,
            manualStartTime: 10.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Dialogue.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.character, original.character)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.costumes, original.costumes)
        XCTAssertEqual(decoded.effects, original.effects)
        XCTAssertEqual(decoded.chronologyNumber, original.chronologyNumber)
        XCTAssertEqual(decoded.globalChronologyNumber, original.globalChronologyNumber)
        XCTAssertEqual(decoded.audioFilePath, original.audioFilePath)
        XCTAssertEqual(decoded.manualDuration, original.manualDuration)
        XCTAssertEqual(decoded.manualStartTime, original.manualStartTime)
    }

    // MARK: - Action Codable

    func testActionCodableRoundTrip() throws {
        let original = Action(
            uuid: "action-uuid-roundtrip",
            description: "Runs through the forest",
            tags: ["chase"],
            chronologyNumber: 3,
            characters: ["Hero", "Villain"],
            parentDialogueId: "parent-dialogue-x"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Action.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.characters, original.characters)
        XCTAssertEqual(decoded.parentDialogueId, original.parentDialogueId)
    }
}
