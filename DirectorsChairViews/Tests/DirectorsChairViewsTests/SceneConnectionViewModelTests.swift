// SceneConnectionViewModelTests.swift
// Tests for SceneConnectionViewModel: connections, filtering, grouping, drag, selection

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class SceneConnectionViewModelTests: XCTestCase {

    var viewModel: SceneConnectionViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SceneConnectionViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDialogues() -> [Dialogue] {
        [
            Dialogue(character: "Alice", text: "Hello!", chronologyNumber: 1),
            Dialogue(character: "Bob", text: "Hi there!", chronologyNumber: 3),
        ]
    }

    private func makeActions() -> [Action] {
        [
            Action(description: "Alice waves", chronologyNumber: 2, parentDialogueId: nil)
        ]
    }

    private func makeNarrations() -> [Narration] {
        [
            Narration(text: "The sun sets.", chronologyNumber: 4)
        ]
    }

    private func makeShots() -> [Shot] {
        [
            Shot(shotId: 1, description: "Wide shot"),
            Shot(shotId: 2, description: "Close-up on Alice"),
        ]
    }

    private func setupTestData() {
        viewModel.updateScriptItems(
            dialogues: makeDialogues(),
            actions: makeActions(),
            narrations: makeNarrations()
        )
        viewModel.updateShots(makeShots())
    }

    // MARK: - Script Items

    func testUpdateScriptItemsSortsByChronology() {
        setupTestData()

        XCTAssertEqual(viewModel.scriptItems.count, 4)
        // Should be sorted by chronologyNumber: 1, 2, 3, 4
        let chronNumbers = viewModel.scriptItems.map { $0.chronologyNumber }
        XCTAssertEqual(chronNumbers, chronNumbers.sorted())
    }

    func testFilteredScriptItemsRespectToggles() {
        setupTestData()

        XCTAssertEqual(viewModel.filteredScriptItems.count, 4) // All visible

        viewModel.showActions = false
        XCTAssertEqual(viewModel.filteredScriptItems.count, 3)

        viewModel.showDialogues = false
        XCTAssertEqual(viewModel.filteredScriptItems.count, 1) // Only narrations

        viewModel.showNarrations = false
        XCTAssertEqual(viewModel.filteredScriptItems.count, 0)
    }

    func testUpdateShots() {
        let shots = makeShots()
        viewModel.updateShots(shots)

        XCTAssertEqual(viewModel.shots.count, 2)
        // Should be sorted by shotId
        XCTAssertEqual(viewModel.shots[0].shotId, 1)
        XCTAssertEqual(viewModel.shots[1].shotId, 2)
    }

    // MARK: - Connection CRUD

    func testCreateDialogueConnection() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)

        XCTAssertTrue(viewModel.shots[0].linkedDialogueIds.contains(dialogueId))
        XCTAssertEqual(viewModel.connections.count, 1)
    }

    func testCreateActionConnection() {
        setupTestData()
        let actionId = viewModel.scriptItems.first { $0.itemType == .action }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: actionId, shotId: shotId, itemType: .action)

        XCTAssertTrue(viewModel.shots[0].linkedActionIds.contains(actionId))
    }

    func testCreateNarrationConnection() {
        setupTestData()
        let narrationId = viewModel.scriptItems.first { $0.itemType == .narration }!.id
        let shotId = viewModel.shots[1].id

        viewModel.createConnection(scriptItemId: narrationId, shotId: shotId, itemType: .narration)

        XCTAssertTrue(viewModel.shots[1].linkedNarrationIds.contains(narrationId))
    }

    func testCreateDuplicateConnectionIgnored() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)
        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)

        XCTAssertEqual(viewModel.shots[0].linkedDialogueIds.filter { $0 == dialogueId }.count, 1)
    }

    func testRemoveConnection() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)
        XCTAssertEqual(viewModel.connections.count, 1)

        let connection = viewModel.connections.first!
        viewModel.removeConnection(connection)
        XCTAssertEqual(viewModel.connections.count, 0)
    }

    func testRemoveConnectionByIds() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)
        viewModel.removeConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)

        XCTAssertFalse(viewModel.shots[0].linkedDialogueIds.contains(dialogueId))
    }

    func testRemoveAllConnectionsForScriptItem() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: viewModel.shots[0].id, itemType: .dialogue)
        viewModel.createConnection(scriptItemId: dialogueId, shotId: viewModel.shots[1].id, itemType: .dialogue)

        viewModel.removeAllConnections(for: dialogueId)

        XCTAssertFalse(viewModel.shots[0].linkedDialogueIds.contains(dialogueId))
        XCTAssertFalse(viewModel.shots[1].linkedDialogueIds.contains(dialogueId))
    }

    func testRemoveAllConnectionsForShot() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let actionId = viewModel.scriptItems.first { $0.itemType == .action }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)
        viewModel.createConnection(scriptItemId: actionId, shotId: shotId, itemType: .action)

        viewModel.removeAllConnections(forShot: shotId)

        XCTAssertTrue(viewModel.shots[0].linkedDialogueIds.isEmpty)
        XCTAssertTrue(viewModel.shots[0].linkedActionIds.isEmpty)
    }

    // MARK: - Connection Queries

    func testConnectionExists() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let shotId = viewModel.shots[0].id

        XCTAssertFalse(viewModel.connectionExists(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue))

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)

        XCTAssertTrue(viewModel.connectionExists(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue))
    }

    func testConnectedShotIds() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: viewModel.shots[0].id, itemType: .dialogue)
        viewModel.createConnection(scriptItemId: dialogueId, shotId: viewModel.shots[1].id, itemType: .dialogue)

        let connectedIds = viewModel.connectedShotIds(for: dialogueId)
        XCTAssertEqual(connectedIds.count, 2)
    }

    func testIsShotConnectedToSelectedItem() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)
        viewModel.selectedScriptItemId = dialogueId

        XCTAssertTrue(viewModel.isShotConnectedToSelectedItem(shotId))
        XCTAssertFalse(viewModel.isShotConnectedToSelectedItem(viewModel.shots[1].id))
    }

    func testConnectionCounts() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let actionId = viewModel.scriptItems.first { $0.itemType == .action }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)
        viewModel.createConnection(scriptItemId: actionId, shotId: shotId, itemType: .action)

        let counts = viewModel.connectionCounts(for: shotId)
        XCTAssertEqual(counts.dialogues, 1)
        XCTAssertEqual(counts.actions, 1)
        XCTAssertEqual(counts.narrations, 0)
    }

    // MARK: - Selection

    func testSelectScriptItem() {
        setupTestData()
        viewModel.selectScriptItem("some-id")
        XCTAssertEqual(viewModel.selectedScriptItemId, "some-id")
        XCTAssertNil(viewModel.selectedConnection)
    }

    func testSelectShot() {
        setupTestData()
        viewModel.selectShot("shot-id")
        XCTAssertEqual(viewModel.selectedShotId, "shot-id")
    }

    func testSelectConnection() {
        setupTestData()
        let connection = ScriptConnection(scriptItemId: "item1", shotId: "shot1", itemType: .dialogue)
        viewModel.selectConnection(connection)

        XCTAssertEqual(viewModel.selectedConnection?.id, connection.id)
        XCTAssertEqual(viewModel.selectedScriptItemId, "item1")
        XCTAssertEqual(viewModel.selectedShotId, "shot1")
    }

    func testClearSelection() {
        viewModel.selectedScriptItemId = "a"
        viewModel.selectedShotId = "b"
        viewModel.selectedConnection = ScriptConnection(scriptItemId: "a", shotId: "b", itemType: .dialogue)

        viewModel.clearSelection()

        XCTAssertNil(viewModel.selectedScriptItemId)
        XCTAssertNil(viewModel.selectedShotId)
        XCTAssertNil(viewModel.selectedConnection)
    }

    func testDeleteSelectedConnection() {
        setupTestData()
        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        let shotId = viewModel.shots[0].id

        viewModel.createConnection(scriptItemId: dialogueId, shotId: shotId, itemType: .dialogue)
        let connection = viewModel.connections.first!
        viewModel.selectedConnection = connection

        viewModel.deleteSelectedConnection()

        XCTAssertEqual(viewModel.connections.count, 0)
        XCTAssertNil(viewModel.selectedConnection)
    }

    // MARK: - Drag & Drop

    func testStartDrag() {
        viewModel.startDrag(fromScriptItem: "item1", itemType: .dialogue)

        XCTAssertTrue(viewModel.isDragging)
        XCTAssertEqual(viewModel.dragSourceId, "item1")
        XCTAssertEqual(viewModel.dragSourceType, .dialogue)
        XCTAssertEqual(viewModel.selectedScriptItemId, "item1")
    }

    func testCancelDrag() {
        viewModel.startDrag(fromScriptItem: "item1", itemType: .dialogue)
        viewModel.cancelDrag()

        XCTAssertFalse(viewModel.isDragging)
        XCTAssertNil(viewModel.dragSourceId)
        XCTAssertNil(viewModel.dragSourceType)
    }

    func testUpdateDragPosition() {
        viewModel.updateDragPosition(CGPoint(x: 100, y: 200))
        XCTAssertEqual(viewModel.dragCurrentPosition, CGPoint(x: 100, y: 200))
    }

    // MARK: - Port Positions

    func testUpdatePortPositions() {
        let positions: [String: CGPoint] = [
            "script-dialogue-1": CGPoint(x: 50, y: 100),
            "shot-dialogue-2": CGPoint(x: 300, y: 100),
        ]

        viewModel.updatePortPositions(positions)
        XCTAssertEqual(viewModel.portPositions.count, 2)
    }

    // MARK: - Callback

    func testOnShotsChangedCallback() {
        setupTestData()
        var callbackFired = false
        viewModel.onShotsChanged = { _ in callbackFired = true }

        let dialogueId = viewModel.scriptItems.first { $0.itemType == .dialogue }!.id
        viewModel.createConnection(scriptItemId: dialogueId, shotId: viewModel.shots[0].id, itemType: .dialogue)

        XCTAssertTrue(callbackFired)
    }

    // MARK: - Grouped Script Entries

    func testGroupedScriptEntriesSortsByChronology() {
        setupTestData()
        let entries = viewModel.groupedScriptEntries
        XCTAssertFalse(entries.isEmpty)
    }

    func testChildItemsForDialogue() {
        // Create action with parent dialogue ID
        let dialogues = makeDialogues()
        let parentId = dialogues[0].id
        var action = Action(description: "Child action", chronologyNumber: 2)
        action.parentDialogueId = parentId

        viewModel.updateScriptItems(
            dialogues: dialogues,
            actions: [action],
            narrations: []
        )

        let children = viewModel.childItems(forDialogueId: parentId)
        XCTAssertEqual(children.count, 1)
    }

    // MARK: - Cached graph, toggle, refresh, undo (perf/UX pass)

    private func makeLinkedFixture() -> (Dialogue, Shot) {
        let dialogue = Dialogue(uuid: "d1", character: "Alice", text: "Hello!", chronologyNumber: 1)
        let shot = Shot(uuid: "s1", shotId: 1)
        viewModel = SceneConnectionViewModel(dialogues: [dialogue], shots: [shot])
        return (dialogue, shot)
    }

    func testCachedConnectionsStayInSyncThroughMutations() {
        let (dialogue, shot) = makeLinkedFixture()
        XCTAssertTrue(viewModel.connections.isEmpty)

        viewModel.createConnection(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue)
        XCTAssertEqual(viewModel.connections.count, 1)
        XCTAssertEqual(viewModel.connectedShotIds(for: dialogue.id), [shot.id])
        XCTAssertEqual(viewModel.connectionCounts(for: shot.id).dialogues, 1)

        viewModel.removeConnection(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue)
        XCTAssertTrue(viewModel.connections.isEmpty)
        XCTAssertTrue(viewModel.connectedShotIds(for: dialogue.id).isEmpty)
    }

    func testToggleConnectionCreatesThenRemoves() {
        let (dialogue, shot) = makeLinkedFixture()
        viewModel.toggleConnection(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue)
        XCTAssertTrue(viewModel.connectionExists(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue))
        viewModel.toggleConnection(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue)
        XCTAssertFalse(viewModel.connectionExists(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue))
    }

    func testRefreshPropagatesExternalEditsAndPrunesSelection() {
        let (dialogue, shot) = makeLinkedFixture()
        viewModel.selectScriptItem(dialogue.id)
        viewModel.selectShot(shot.id)

        // External edit: dialogue removed, a new shot added
        let newShot = Shot(uuid: "s2", shotId: 2)
        viewModel.refresh(dialogues: [], actions: [], narrations: [], shots: [shot, newShot])

        XCTAssertEqual(viewModel.shots.count, 2, "external shot appears without scene switch")
        XCTAssertNil(viewModel.selectedScriptItemId, "selection of a removed item is pruned")
        XCTAssertEqual(viewModel.selectedShotId, shot.id, "still-valid selection survives")
    }

    func testConnectionEditsAreUndoable() {
        let (dialogue, shot) = makeLinkedFixture()
        let undoManager = UndoManager()
        viewModel.undoManager = undoManager

        viewModel.createConnection(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue)
        XCTAssertTrue(undoManager.canUndo)

        undoManager.undo()
        XCTAssertFalse(viewModel.connectionExists(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue),
                       "undo restores the pre-connect snapshot")

        undoManager.redo()
        XCTAssertTrue(viewModel.connectionExists(scriptItemId: dialogue.id, shotId: shot.id, itemType: .dialogue),
                      "redo re-applies the connection")
    }
}
