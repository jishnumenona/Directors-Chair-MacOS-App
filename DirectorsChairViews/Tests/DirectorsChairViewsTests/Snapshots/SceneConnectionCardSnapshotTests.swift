// SceneConnectionCardSnapshotTests.swift

import XCTest
import SwiftUI
import SnapshotTesting
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@available(macOS 14.0, *)
final class SceneConnectionCardSnapshotTests: XCTestCase {

    // MARK: - ScriptItemCard

    func testScriptItemDialogue() {
        let view = ScriptItemCard(
            item: TestFixtures.scriptItemDialogue(),
            isSelected: false,
            connectedShotIds: []
        )
        assertViewSnapshot(view, size: CGSize(width: 280, height: 80))
    }

    func testScriptItemAction() {
        let view = ScriptItemCard(
            item: TestFixtures.scriptItemAction(),
            isSelected: false,
            connectedShotIds: []
        )
        assertViewSnapshot(view, size: CGSize(width: 280, height: 80))
    }

    func testScriptItemSelected() {
        let view = ScriptItemCard(
            item: TestFixtures.scriptItemDialogue(),
            isSelected: true,
            connectedShotIds: ["shot-1"]
        )
        assertViewSnapshot(view, size: CGSize(width: 280, height: 80))
    }

    // MARK: - ShotConnectionCard

    func testShotConnectionDefault() {
        let view = ShotConnectionCard(
            shot: TestFixtures.shot(),
            isSelected: false,
            isHighlighted: false,
            connectedDialogueCount: 0,
            connectedActionCount: 0,
            connectedNarrationCount: 0,
            highlightedItemType: nil
        )
        assertViewSnapshot(view, size: CGSize(width: 280, height: 100))
    }

    func testShotConnectionWithCounts() {
        let view = ShotConnectionCard(
            shot: TestFixtures.shot(),
            isSelected: false,
            isHighlighted: true,
            connectedDialogueCount: 2,
            connectedActionCount: 1,
            connectedNarrationCount: 1,
            highlightedItemType: .dialogue
        )
        assertViewSnapshot(view, size: CGSize(width: 280, height: 100))
    }

    // MARK: - ConnectionPort

    func testConnectionPortStates() {
        let view = HStack(spacing: 20) {
            ConnectionPort(
                portId: "port-1",
                itemType: .dialogue,
                isOutput: true,
                isConnected: false,
                isHighlighted: false
            )
            ConnectionPort(
                portId: "port-2",
                itemType: .dialogue,
                isOutput: true,
                isConnected: true,
                isHighlighted: true
            )
        }
        assertCompactSnapshot(view, size: CGSize(width: 120, height: 40))
    }
}
