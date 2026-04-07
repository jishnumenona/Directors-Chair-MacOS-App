// DirectorsChairViews/Tests/DirectorsChairViewsTests/SceneConnectionTests.swift
//
// Tests for port ID generation, connection linking, and port ID parsing
// in the Scene Connection system.

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class SceneConnectionTests: XCTestCase {

    // MARK: - Script Port ID Format

    func testScriptPortIdFormat() {
        // Port IDs for script items follow the format "script-{itemId}"
        let dialogueId = "dialogue-abc-123"
        let expectedPortId = "script-\(dialogueId)"

        XCTAssertEqual(expectedPortId, "script-dialogue-abc-123")
        XCTAssertTrue(expectedPortId.hasPrefix("script-"))
    }

    func testScriptPortIdFromDialogue() {
        let dialogue = Dialogue(
            uuid: "d-uuid-001",
            character: "Alice",
            text: "Hello",
            chronologyNumber: 1
        )

        let portId = "script-\(dialogue.id)"
        XCTAssertEqual(portId, "script-d-uuid-001")
    }

    func testScriptPortIdFromAction() {
        let action = Action(
            uuid: "a-uuid-002",
            description: "Runs away",
            chronologyNumber: 2,
            characters: ["Bob"]
        )

        let portId = "script-\(action.id)"
        XCTAssertEqual(portId, "script-a-uuid-002")
    }

    func testScriptPortIdFromNarration() {
        let narration = Narration(
            uuid: "n-uuid-003",
            text: "Time passes",
            chronologyNumber: 3,
            characters: []
        )

        let portId = "script-\(narration.id)"
        XCTAssertEqual(portId, "script-n-uuid-003")
    }

    // MARK: - Shot Port ID Format

    func testShotPortIdFormat() {
        // Shot port IDs follow the format "shot-{type}-{shotId}"
        let shotId = "shot-uuid-456"

        let dialoguePort = "shot-dialogue-\(shotId)"
        let actionPort = "shot-action-\(shotId)"
        let narrationPort = "shot-narration-\(shotId)"

        XCTAssertEqual(dialoguePort, "shot-dialogue-shot-uuid-456")
        XCTAssertEqual(actionPort, "shot-action-shot-uuid-456")
        XCTAssertEqual(narrationPort, "shot-narration-shot-uuid-456")

        XCTAssertTrue(dialoguePort.hasPrefix("shot-"))
        XCTAssertTrue(actionPort.hasPrefix("shot-"))
        XCTAssertTrue(narrationPort.hasPrefix("shot-"))
    }

    func testShotPortIdFromShotModel() {
        let shot = Shot(
            uuid: "s-uuid-789",
            shotId: 1,
            description: "Wide shot"
        )

        let dialoguePort = "shot-dialogue-\(shot.id)"
        let actionPort = "shot-action-\(shot.id)"
        let narrationPort = "shot-narration-\(shot.id)"

        XCTAssertEqual(dialoguePort, "shot-dialogue-s-uuid-789")
        XCTAssertEqual(actionPort, "shot-action-s-uuid-789")
        XCTAssertEqual(narrationPort, "shot-narration-s-uuid-789")
    }

    func testShotPortIdUsesScriptItemTypeRawValue() {
        // Verify ScriptItemType raw values match the port ID generation
        let shot = Shot(uuid: "test-shot", shotId: 1, description: "Test")

        let dialoguePort = "shot-\(ScriptItemType.dialogue.rawValue.lowercased())-\(shot.id)"
        let actionPort = "shot-\(ScriptItemType.action.rawValue.lowercased())-\(shot.id)"
        let narrationPort = "shot-\(ScriptItemType.narration.rawValue.lowercased())-\(shot.id)"

        XCTAssertEqual(dialoguePort, "shot-dialogue-test-shot")
        XCTAssertEqual(actionPort, "shot-action-test-shot")
        XCTAssertEqual(narrationPort, "shot-narration-test-shot")
    }

    // MARK: - Connection Linking

    func testConnectionLinking() {
        let scriptItemId = "dialogue-uuid-100"
        let shotId = "shot-uuid-200"

        let connection = ScriptConnection(
            scriptItemId: scriptItemId,
            shotId: shotId,
            itemType: .dialogue
        )

        XCTAssertEqual(connection.scriptItemId, scriptItemId)
        XCTAssertEqual(connection.shotId, shotId)
        XCTAssertEqual(connection.itemType, .dialogue)
        XCTAssertEqual(connection.id, "\(scriptItemId)-\(shotId)")
    }

    func testConnectionGeneratesSourceAndTargetKeys() {
        let connection = ScriptConnection(
            scriptItemId: "item-abc",
            shotId: "shot-xyz",
            itemType: .action
        )

        let sourceKey = "script-\(connection.scriptItemId)"
        let targetKey = "shot-\(connection.itemType.rawValue.lowercased())-\(connection.shotId)"

        XCTAssertEqual(sourceKey, "script-item-abc")
        XCTAssertEqual(targetKey, "shot-action-shot-xyz")
    }

    func testConnectionForEachItemType() {
        let itemId = "item-001"
        let shotId = "shot-001"

        let dialogueConnection = ScriptConnection(scriptItemId: itemId, shotId: shotId, itemType: .dialogue)
        let actionConnection = ScriptConnection(scriptItemId: itemId, shotId: shotId, itemType: .action)
        let narrationConnection = ScriptConnection(scriptItemId: itemId, shotId: shotId, itemType: .narration)

        XCTAssertEqual(dialogueConnection.itemType, .dialogue)
        XCTAssertEqual(actionConnection.itemType, .action)
        XCTAssertEqual(narrationConnection.itemType, .narration)

        // All connections have the same id since same itemId-shotId pair
        XCTAssertEqual(dialogueConnection.id, actionConnection.id)
    }

    // MARK: - Port ID Parsing

    func testPortIdParsing() {
        // Extracting the item ID from a script port ID
        let scriptPortId = "script-my-item-uuid"
        let extractedItemId = String(scriptPortId.dropFirst("script-".count))
        XCTAssertEqual(extractedItemId, "my-item-uuid")
    }

    func testShotPortIdParsing() {
        // Extracting type and shot ID from a shot port ID
        let shotPortId = "shot-dialogue-my-shot-uuid"

        // Remove "shot-" prefix
        let remainder = String(shotPortId.dropFirst("shot-".count))

        // Split on first "-" to get type
        if let firstDash = remainder.firstIndex(of: "-") {
            let typeString = String(remainder[remainder.startIndex..<firstDash])
            let shotIdStr = String(remainder[remainder.index(after: firstDash)...])

            XCTAssertEqual(typeString, "dialogue")
            XCTAssertEqual(shotIdStr, "my-shot-uuid")
        } else {
            XCTFail("Expected to find a dash separator in shot port ID remainder")
        }
    }

    func testPortIdParsingForAllTypes() {
        let types = ["dialogue", "action", "narration"]
        let shotId = "uuid-123"

        for type in types {
            let portId = "shot-\(type)-\(shotId)"
            let remainder = String(portId.dropFirst("shot-".count))

            if let firstDash = remainder.firstIndex(of: "-") {
                let parsedType = String(remainder[remainder.startIndex..<firstDash])
                let parsedShotId = String(remainder[remainder.index(after: firstDash)...])

                XCTAssertEqual(parsedType, type)
                XCTAssertEqual(parsedShotId, shotId)
            } else {
                XCTFail("Failed to parse port ID for type: \(type)")
            }
        }
    }

    // MARK: - Unique Port IDs

    func testUniquePortIds() {
        let dialogue1 = Dialogue(uuid: "d1", character: "A", text: "Hi", chronologyNumber: 1)
        let dialogue2 = Dialogue(uuid: "d2", character: "B", text: "Hey", chronologyNumber: 2)
        let action1 = Action(uuid: "a1", description: "Walk", chronologyNumber: 3, characters: [])

        let port1 = "script-\(dialogue1.id)"
        let port2 = "script-\(dialogue2.id)"
        let port3 = "script-\(action1.id)"

        // All port IDs should be different
        XCTAssertNotEqual(port1, port2)
        XCTAssertNotEqual(port1, port3)
        XCTAssertNotEqual(port2, port3)

        // Put them in a set to verify uniqueness
        let portSet: Set<String> = [port1, port2, port3]
        XCTAssertEqual(portSet.count, 3)
    }

    func testUniquePortIdsForShots() {
        let shot1 = Shot(uuid: "s1", shotId: 1, description: "Wide")
        let shot2 = Shot(uuid: "s2", shotId: 2, description: "Close")

        let port1Dialogue = "shot-dialogue-\(shot1.id)"
        let port1Action = "shot-action-\(shot1.id)"
        let port2Dialogue = "shot-dialogue-\(shot2.id)"

        // Same shot, different types should have different port IDs
        XCTAssertNotEqual(port1Dialogue, port1Action)

        // Different shots, same type should have different port IDs
        XCTAssertNotEqual(port1Dialogue, port2Dialogue)
    }

    // MARK: - ScriptItem Wrapper

    func testScriptItemDialogueWrapper() {
        let dialogue = Dialogue(uuid: "d-wrap", character: "Test", text: "Hello", chronologyNumber: 1)
        let item = ScriptItem.dialogue(dialogue)

        XCTAssertEqual(item.id, "d-wrap")
        XCTAssertEqual(item.itemType, .dialogue)
        XCTAssertEqual(item.displayText, "Hello")
        XCTAssertEqual(item.subtitle, "Test")
        XCTAssertEqual(item.chronologyNumber, 1)
        XCTAssertNil(item.parentDialogueId)
    }

    func testScriptItemActionWrapper() {
        let action = Action(uuid: "a-wrap", description: "Runs", chronologyNumber: 2, characters: ["Bob"], parentDialogueId: "parent-d")
        let item = ScriptItem.action(action)

        XCTAssertEqual(item.id, "a-wrap")
        XCTAssertEqual(item.itemType, .action)
        XCTAssertEqual(item.displayText, "Runs")
        XCTAssertNil(item.subtitle)
        XCTAssertEqual(item.parentDialogueId, "parent-d")
    }

    func testScriptItemNarrationWrapper() {
        let narration = Narration(uuid: "n-wrap", text: "Narrating", chronologyNumber: 3, characters: [])
        let item = ScriptItem.narration(narration)

        XCTAssertEqual(item.id, "n-wrap")
        XCTAssertEqual(item.itemType, .narration)
        XCTAssertEqual(item.displayText, "Narrating")
        XCTAssertNil(item.subtitle)
        XCTAssertNil(item.parentDialogueId)
    }

    // MARK: - ScriptItemType Properties

    func testScriptItemTypeRawValues() {
        XCTAssertEqual(ScriptItemType.dialogue.rawValue, "Dialogue")
        XCTAssertEqual(ScriptItemType.action.rawValue, "Action")
        XCTAssertEqual(ScriptItemType.narration.rawValue, "Narration")
    }

    func testScriptItemTypeAllCases() {
        let allCases = ScriptItemType.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.dialogue))
        XCTAssertTrue(allCases.contains(.action))
        XCTAssertTrue(allCases.contains(.narration))
    }

    func testScriptItemTypeIcons() {
        XCTAssertEqual(ScriptItemType.dialogue.icon, "text.bubble")
        XCTAssertEqual(ScriptItemType.action.icon, "figure.walk")
        XCTAssertEqual(ScriptItemType.narration.icon, "quote.opening")
    }

    // MARK: - ScriptConnection Identity

    func testScriptConnectionId() {
        let connection = ScriptConnection(
            scriptItemId: "item-A",
            shotId: "shot-B",
            itemType: .dialogue
        )

        XCTAssertEqual(connection.id, "item-A-shot-B")
    }

    func testScriptConnectionEquality() {
        let connection1 = ScriptConnection(scriptItemId: "item-1", shotId: "shot-1", itemType: .dialogue)
        let connection2 = ScriptConnection(scriptItemId: "item-1", shotId: "shot-1", itemType: .dialogue)
        let connection3 = ScriptConnection(scriptItemId: "item-1", shotId: "shot-2", itemType: .dialogue)

        XCTAssertEqual(connection1, connection2)
        XCTAssertNotEqual(connection1, connection3)
    }

    // MARK: - PortPositionKey

    func testPortPositionKeyDefaultValue() {
        let defaultValue = PortPositionKey.defaultValue
        XCTAssertTrue(defaultValue.isEmpty)
    }

    func testPortPositionKeyReduce() {
        var value: [String: CGPoint] = ["port-1": CGPoint(x: 10, y: 20)]
        let nextValue: () -> [String: CGPoint] = { ["port-2": CGPoint(x: 30, y: 40)] }

        PortPositionKey.reduce(value: &value, nextValue: nextValue)

        XCTAssertEqual(value.count, 2)
        XCTAssertEqual(value["port-1"], CGPoint(x: 10, y: 20))
        XCTAssertEqual(value["port-2"], CGPoint(x: 30, y: 40))
    }

    func testPortPositionKeyReduceOverwrites() {
        var value: [String: CGPoint] = ["port-1": CGPoint(x: 10, y: 20)]
        let nextValue: () -> [String: CGPoint] = { ["port-1": CGPoint(x: 99, y: 99)] }

        PortPositionKey.reduce(value: &value, nextValue: nextValue)

        XCTAssertEqual(value.count, 1)
        XCTAssertEqual(value["port-1"], CGPoint(x: 99, y: 99), "New value should overwrite old value")
    }
}
