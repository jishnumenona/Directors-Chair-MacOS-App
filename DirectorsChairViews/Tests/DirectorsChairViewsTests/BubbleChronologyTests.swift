// BubbleChronologyTests.swift
//
// Covers the bubble-view drag interactions at the model level (the pure math
// BubbleView delegates to):
//   E2E-BUBBLE-002 — drag-reorder changes chronology (order + numbers update).
//   E2E-BUBBLE-003 — drag-out disconnects a connected sub-bubble.
//
// These used to be inline in the SwiftUI view and untestable; BubbleChronology
// extracts them as value-only transforms so the ordering contract is verified
// without constructing the view.

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class BubbleChronologyTests: XCTestCase {

    /// A scene with one item of each kind, chronology 0…4, ids "i0"…"i4".
    private func makeMixedScene() -> Scene {
        let d0 = Dialogue(uuid: "i0", character: "Alice", text: "Line", chronologyNumber: 0, globalChronologyNumber: 0)
        let a1 = Action(uuid: "i1", description: "Beat", chronologyNumber: 1, globalChronologyNumber: 1)
        let n2 = Narration(uuid: "i2", text: "Narr", chronologyNumber: 2, globalChronologyNumber: 2)
        let note3 = Note(uuid: "i3", content: "Note", chronologyNumber: 3)
        let s4 = SoundNote(uuid: "i4", description: "SFX", chronologyNumber: 4)
        return Scene(name: "S", dialogues: [d0], actions: [a1], narrations: [n2],
                     sceneNotes: [note3], soundNotes: [s4])
    }

    private func chronology(of scene: Scene) -> [String: Int] {
        var m: [String: Int] = [:]
        scene.dialogues.forEach { m[$0.id] = $0.chronologyNumber }
        scene.actions.forEach { m[$0.id] = $0.chronologyNumber }
        scene.narrations.forEach { m[$0.id] = $0.chronologyNumber }
        scene.sceneNotes.forEach { m[$0.id] = $0.chronologyNumber }
        scene.soundNotes.forEach { m[$0.id] = $0.chronologyNumber }
        return m
    }

    // MARK: - E2E-BUBBLE-002: drag-reorder

    func testReindexedShiftsUpWhenMovingItemUp() {
        // Moving from 4 → 1: items in [1,4) shift +1, item 0 unchanged, moved item = 1.
        XCTAssertEqual(BubbleChronology.reindexed(current: 0, isMovingItem: false, oldIndex: 4, newIndex: 1), 0)
        XCTAssertEqual(BubbleChronology.reindexed(current: 1, isMovingItem: false, oldIndex: 4, newIndex: 1), 2)
        XCTAssertEqual(BubbleChronology.reindexed(current: 3, isMovingItem: false, oldIndex: 4, newIndex: 1), 4)
        XCTAssertEqual(BubbleChronology.reindexed(current: 4, isMovingItem: true,  oldIndex: 4, newIndex: 1), 1)
    }

    func testReindexedShiftsDownWhenMovingItemDown() {
        // Moving from 1 → 3: items in (1,3] shift -1, item 0/4 unchanged, moved item = 3.
        XCTAssertEqual(BubbleChronology.reindexed(current: 0, isMovingItem: false, oldIndex: 1, newIndex: 3), 0)
        XCTAssertEqual(BubbleChronology.reindexed(current: 2, isMovingItem: false, oldIndex: 1, newIndex: 3), 1)
        XCTAssertEqual(BubbleChronology.reindexed(current: 3, isMovingItem: false, oldIndex: 1, newIndex: 3), 2)
        XCTAssertEqual(BubbleChronology.reindexed(current: 4, isMovingItem: false, oldIndex: 1, newIndex: 3), 4)
        XCTAssertEqual(BubbleChronology.reindexed(current: 1, isMovingItem: true,  oldIndex: 1, newIndex: 3), 3)
    }

    func testReorderMovingLastItemToFrontRenumbersContiguously() {
        var scene = makeMixedScene()
        // Drag the sound note (chronology 4) up to position 1.
        BubbleChronology.reorder(&scene, movingItemId: "i4", oldIndex: 4, newIndex: 1)

        let c = chronology(of: scene)
        XCTAssertEqual(c["i0"], 0, "unshifted head stays put")
        XCTAssertEqual(c["i4"], 1, "moved item takes the new index")
        XCTAssertEqual(c["i1"], 2)
        XCTAssertEqual(c["i2"], 3)
        XCTAssertEqual(c["i3"], 4)

        // Invariant: still a contiguous, duplicate-free 0…4.
        XCTAssertEqual(Set(c.values), Set(0...4), "chronology must stay contiguous and unique")
    }

    func testReorderKeepsGlobalChronologyInSyncForRichItems() {
        var scene = makeMixedScene()
        BubbleChronology.reorder(&scene, movingItemId: "i1", oldIndex: 1, newIndex: 3)
        // Dialogue/action/narration mirror scene-local into global chronology.
        XCTAssertEqual(scene.actions[0].chronologyNumber, scene.actions[0].globalChronologyNumber)
        XCTAssertEqual(scene.dialogues[0].chronologyNumber, scene.dialogues[0].globalChronologyNumber)
        XCTAssertEqual(scene.narrations[0].chronologyNumber, scene.narrations[0].globalChronologyNumber)
    }

    func testReorderIsNoOpWhenIndicesEqual() {
        var scene = makeMixedScene()
        let before = chronology(of: scene)
        BubbleChronology.reorder(&scene, movingItemId: "i2", oldIndex: 2, newIndex: 2)
        XCTAssertEqual(chronology(of: scene), before, "same-position drag changes nothing")
    }

    // MARK: - E2E-BUBBLE-003: drag-out disconnect

    func testDisconnectClearsParentLink() {
        var scene = makeMixedScene()
        scene.actions[0].parentDialogueId = "i0"   // connected as a sub-bubble of the dialogue

        let found = BubbleChronology.disconnect(&scene, itemId: "i1", itemType: "action")

        XCTAssertTrue(found, "the connected action is located")
        XCTAssertNil(scene.actions[0].parentDialogueId, "drag-out removes the parent connection")
    }

    func testDisconnectAcrossItemTypes() {
        var scene = makeMixedScene()
        scene.narrations[0].parentDialogueId = "i0"
        scene.sceneNotes[0].parentDialogueId = "i0"
        scene.soundNotes[0].parentDialogueId = "i0"

        XCTAssertTrue(BubbleChronology.disconnect(&scene, itemId: "i2", itemType: "narration"))
        XCTAssertTrue(BubbleChronology.disconnect(&scene, itemId: "i3", itemType: "note"))
        XCTAssertTrue(BubbleChronology.disconnect(&scene, itemId: "i4", itemType: "soundNote"))

        XCTAssertNil(scene.narrations[0].parentDialogueId)
        XCTAssertNil(scene.sceneNotes[0].parentDialogueId)
        XCTAssertNil(scene.soundNotes[0].parentDialogueId)
    }

    func testDisconnectUnknownItemReturnsFalse() {
        var scene = makeMixedScene()
        XCTAssertFalse(BubbleChronology.disconnect(&scene, itemId: "nope", itemType: "action"))
    }
}
