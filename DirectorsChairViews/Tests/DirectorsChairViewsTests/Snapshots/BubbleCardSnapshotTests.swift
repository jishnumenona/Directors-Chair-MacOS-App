// BubbleCardSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@available(macOS 14.0, *)
final class BubbleCardSnapshotTests: XCTestCase {

    // MARK: - DialogueBubbleCard

    func testDialogueDefault() {
        let view = DialogueBubbleCard(
            dialogue: TestFixtures.dialogue(),
            character: TestFixtures.character(),
            isSelected: false,
            isPrimaryCharacter: true
        )
        assertViewSnapshot(view)
    }

    func testDialogueSelected() {
        let view = DialogueBubbleCard(
            dialogue: TestFixtures.dialogue(),
            character: TestFixtures.character(),
            isSelected: true,
            isPrimaryCharacter: true
        )
        assertViewSnapshot(view)
    }

    func testDialogueWithTags() {
        let dialogue = TestFixtures.dialogue(tags: ["whispered", "urgent", "emotional"])
        let view = DialogueBubbleCard(
            dialogue: dialogue,
            character: TestFixtures.character(),
            isSelected: false,
            isPrimaryCharacter: true
        )
        assertViewSnapshot(view)
    }

    func testDialogueEmptyText() {
        let dialogue = TestFixtures.dialogue(text: "")
        let view = DialogueBubbleCard(
            dialogue: dialogue,
            character: nil,
            isSelected: false,
            isPrimaryCharacter: false
        )
        assertViewSnapshot(view)
    }

    // MARK: - ActionBubbleCard

    func testActionDefault() {
        let view = ActionBubbleCard(
            action: TestFixtures.action(),
            isSelected: false
        )
        assertViewSnapshot(view)
    }

    func testActionSelected() {
        let view = ActionBubbleCard(
            action: TestFixtures.action(),
            isSelected: true
        )
        assertViewSnapshot(view)
    }

    // MARK: - NarrationBubbleCard

    func testNarrationDefault() {
        let view = NarrationBubbleCard(
            narration: TestFixtures.narration(),
            isSelected: false
        )
        assertViewSnapshot(view)
    }

    func testNarrationSelected() {
        let view = NarrationBubbleCard(
            narration: TestFixtures.narration(),
            isSelected: true
        )
        assertViewSnapshot(view)
    }

    // MARK: - NoteBubbleCard

    func testNoteDefault() {
        let view = NoteBubbleCard(
            note: TestFixtures.note(),
            isSelected: false
        )
        assertViewSnapshot(view)
    }

    func testNoteSelected() {
        let view = NoteBubbleCard(
            note: TestFixtures.note(),
            isSelected: true
        )
        assertViewSnapshot(view)
    }

    // MARK: - SoundNoteBubbleCard

    func testSoundNoteDefault() {
        let view = SoundNoteBubbleCard(
            soundNote: TestFixtures.soundNote(),
            isSelected: false
        )
        assertViewSnapshot(view)
    }

    func testSoundNoteSelected() {
        let view = SoundNoteBubbleCard(
            soundNote: TestFixtures.soundNote(),
            isSelected: true
        )
        assertViewSnapshot(view)
    }
}
