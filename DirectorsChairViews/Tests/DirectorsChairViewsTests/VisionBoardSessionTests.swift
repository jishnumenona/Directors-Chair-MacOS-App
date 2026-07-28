// DirectorsChairViewsTests/VisionBoardSessionTests.swift
//
// Vision Board repair, Slice 1: the view model's anchored gesture sessions
// — one persistence callback per gesture, snap only on commit, rigid
// multi-select drags, and fit-driven board switching.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

@MainActor
final class VisionBoardSessionTests: XCTestCase {

    private func makeViewModel() -> (VisionBoardViewModel, () -> Int) {
        let viewModel = VisionBoardViewModel(cards: [
            VisionCard(id: "a", canvasX: 100, canvasY: 100,
                       canvasWidth: 200, canvasHeight: 200),
            VisionCard(id: "b", canvasX: 400, canvasY: 100,
                       canvasWidth: 200, canvasHeight: 200),
        ])
        var changeCount = 0
        viewModel.onCardsChanged = { _ in changeCount += 1 }
        return (viewModel, { changeCount })
    }

    func testDragSessionCommitsOnceAndSnapsOnlyAtEnd() {
        let (viewModel, changes) = makeViewModel()
        viewModel.gridSnapEnabled = true
        viewModel.gridSnapSize = 20

        viewModel.beginCardDrag(anchor: "a")
        viewModel.updateCardDrag(translation: CGSize(width: 7, height: 7))
        viewModel.updateCardDrag(translation: CGSize(width: 13, height: 13))
        XCTAssertEqual(changes(), 0, "no persistence churn mid-gesture")
        // Mid-gesture position is unsnapped (follows the cursor exactly).
        XCTAssertEqual(viewModel.cards[0].canvasX ?? 0, 113, accuracy: 0.001)

        viewModel.endCardDrag(translation: CGSize(width: 13, height: 13))
        XCTAssertEqual(changes(), 1, "exactly one commit per gesture")
        XCTAssertEqual(viewModel.cards[0].canvasX, 120, "snap applied on end")
        XCTAssertEqual(viewModel.cards[0].canvasY, 120)
    }

    func testDragSessionIsAnchoredNotCumulative() {
        let (viewModel, _) = makeViewModel()
        viewModel.gridSnapEnabled = false

        viewModel.beginCardDrag(anchor: "a")
        // The same translation delivered repeatedly (as SwiftUI does) must
        // not accelerate the card — the runaway-drag regression.
        for _ in 0..<10 {
            viewModel.updateCardDrag(translation: CGSize(width: 50, height: 0))
        }
        viewModel.endCardDrag(translation: CGSize(width: 50, height: 0))
        XCTAssertEqual(viewModel.cards[0].canvasX, 150, "100 + 50, not 100 + 10×50")
    }

    func testMultiSelectDragStaysRigid() {
        let (viewModel, changes) = makeViewModel()
        viewModel.gridSnapEnabled = false
        viewModel.selectedCardIds = ["a", "b"]

        viewModel.beginCardDrag(anchor: "a")
        viewModel.endCardDrag(translation: CGSize(width: 30, height: 40))

        XCTAssertEqual(viewModel.cards[0].canvasX, 130)
        XCTAssertEqual(viewModel.cards[1].canvasX, 430, "companion moved by the same delta")
        XCTAssertEqual(viewModel.cards[1].canvasY, 140)
        XCTAssertEqual(changes(), 1)
    }

    func testDragScalesByZoom() {
        let (viewModel, _) = makeViewModel()
        viewModel.gridSnapEnabled = false
        viewModel.transform = CanvasTransform(zoom: 2, offset: .zero)

        viewModel.beginCardDrag(anchor: "a")
        viewModel.endCardDrag(translation: CGSize(width: 100, height: 0))
        XCTAssertEqual(viewModel.cards[0].canvasX, 150, "screen 100 ÷ zoom 2 = world 50")
    }

    func testResizeSessionCommitsOnceWithAnchoredMath() {
        let (viewModel, changes) = makeViewModel()
        viewModel.gridSnapEnabled = false

        viewModel.beginResize(cardId: "a", corner: .bottomRight)
        for _ in 0..<5 {
            viewModel.updateResize(translation: CGSize(width: 40, height: 20))
        }
        viewModel.endResize(translation: CGSize(width: 40, height: 20))

        XCTAssertEqual(viewModel.cards[0].canvasWidth, 240, "anchored, not cumulative")
        XCTAssertEqual(viewModel.cards[0].canvasHeight, 220)
        XCTAssertEqual(viewModel.cards[0].canvasX, 100, "origin fixed for bottomRight")
        XCTAssertEqual(changes(), 1)
    }

    func testPinchZoomIsAnchoredToGestureStart() {
        let (viewModel, _) = makeViewModel()
        viewModel.transform = CanvasTransform(zoom: 1, offset: .zero)

        // Repeated identical magnifications must not compound.
        viewModel.pinchZoom(magnification: 2, focus: CGPoint(x: 100, y: 100))
        viewModel.pinchZoom(magnification: 2, focus: CGPoint(x: 100, y: 100))
        XCTAssertEqual(viewModel.transform.zoom, 2, "relative to session start, not current")
        viewModel.endPinch()
    }

    func testSwitchBoardFitsAndInteractionFlag() {
        let (viewModel, _) = makeViewModel()
        viewModel.viewportSize = CGSize(width: 800, height: 600)
        viewModel.transform = CanvasTransform(zoom: 3, offset: CGPoint(x: 999, y: 999))

        viewModel.switchBoard("master")
        // Cards a+b span x:100–600 y:100–300 → fully visible after fit.
        let screen = viewModel.transform.toScreen(CGPoint(x: 600, y: 300))
        XCTAssertTrue((0...800).contains(screen.x))
        XCTAssertTrue((0...600).contains(screen.y))

        XCTAssertFalse(viewModel.interactionInProgress)
        viewModel.beginCardDrag(anchor: "a")
        XCTAssertTrue(viewModel.interactionInProgress)
        viewModel.endCardDrag(translation: .zero)
        XCTAssertFalse(viewModel.interactionInProgress)
    }

    // MARK: - Trackpad scroll

    func testScrollPanMovesOffsetByDeltaAndPersistsNothing() {
        let (viewModel, changes) = makeViewModel()
        viewModel.transform = CanvasTransform(zoom: 1, offset: .zero)

        viewModel.scrollPan(deltaX: 30, deltaY: -12)
        viewModel.scrollPan(deltaX: 5, deltaY: 2)

        XCTAssertEqual(viewModel.transform.offset.x, 35)
        XCTAssertEqual(viewModel.transform.offset.y, -10)
        XCTAssertEqual(changes(), 0, "panning is view state, not a commit")
    }

    func testScrollZoomAnchorsAtCursorAndClamps() {
        let (viewModel, _) = makeViewModel()
        viewModel.transform = CanvasTransform(zoom: 1, offset: .zero)
        let focus = CGPoint(x: 200, y: 150)
        let worldBefore = viewModel.transform.toWorld(focus)

        viewModel.scrollZoom(deltaY: -120, focus: focus)  // scroll up → in

        XCTAssertGreaterThan(viewModel.transform.zoom, 1)
        let worldAfter = viewModel.transform.toWorld(focus)
        XCTAssertEqual(worldAfter.x, worldBefore.x, accuracy: 0.001,
                       "the point under the cursor stays fixed")
        XCTAssertEqual(worldAfter.y, worldBefore.y, accuracy: 0.001)

        viewModel.scrollZoom(deltaY: -100_000, focus: focus)
        XCTAssertLessThanOrEqual(viewModel.transform.zoom,
                                 VisionBoardViewModel.maxZoom)
        viewModel.scrollZoom(deltaY: 100_000, focus: focus)
        XCTAssertGreaterThanOrEqual(viewModel.transform.zoom,
                                    VisionBoardViewModel.minZoom)
    }

    // MARK: - External reconciliation (Slice 3)

    /// An external snapshot differing from local state: card "b" deleted,
    /// card "c" added.
    private func externalSnapshot(of viewModel: VisionBoardViewModel) -> [VisionCard] {
        var next = viewModel.cards.filter { $0.id != "b" }
        next.append(VisionCard(id: "c", canvasX: 700, canvasY: 100,
                               canvasWidth: 200, canvasHeight: 200))
        return next
    }

    func testReconcileSuppressesEchoOfOwnCommit() {
        let (viewModel, changes) = makeViewModel()
        viewModel.reconcileExternalCards(viewModel.cards)
        XCTAssertEqual(changes(), 0)
        XCTAssertEqual(viewModel.cards.map(\.id), ["a", "b"])
    }

    func testReconcileAppliesWhenIdleAndPrunesSelection() {
        let (viewModel, changes) = makeViewModel()
        viewModel.selectedCardIds = ["a", "b"]

        viewModel.reconcileExternalCards(externalSnapshot(of: viewModel))

        XCTAssertEqual(viewModel.cards.map(\.id), ["a", "c"])
        XCTAssertEqual(viewModel.selectedCardIds, ["a"],
                       "selection pruned to surviving cards")
        XCTAssertEqual(changes(), 0,
                       "adopting external state must not echo a commit back")
    }

    func testReconcileDefersDuringPanThenAppliesAtSessionEnd() {
        let (viewModel, _) = makeViewModel()
        let snapshot = externalSnapshot(of: viewModel)

        viewModel.beginPan()
        viewModel.reconcileExternalCards(snapshot)
        XCTAssertEqual(viewModel.cards.map(\.id), ["a", "b"], "deferred mid-gesture")

        viewModel.endPan()
        XCTAssertEqual(viewModel.cards.map(\.id), ["a", "c"],
                       "pending snapshot applied at session end")
    }

    func testLocalCommitSupersedesPendingSnapshot() {
        let (viewModel, changes) = makeViewModel()
        viewModel.gridSnapEnabled = false
        let snapshot = externalSnapshot(of: viewModel)

        viewModel.beginCardDrag(anchor: "a")
        viewModel.reconcileExternalCards(snapshot)  // arrives mid-drag
        viewModel.endCardDrag(translation: CGSize(width: 50, height: 0))

        XCTAssertEqual(viewModel.cards.map(\.id), ["a", "b"],
                       "the local commit wins; the stale snapshot is dropped")
        XCTAssertEqual(viewModel.cards[0].canvasX, 150)
        XCTAssertEqual(changes(), 1)
    }

    func testReconcileDefersDuringEditorThenAppliesOnCancel() {
        let (viewModel, _) = makeViewModel()
        let snapshot = externalSnapshot(of: viewModel)

        viewModel.editCard(viewModel.cards[0])
        viewModel.reconcileExternalCards(snapshot)
        XCTAssertEqual(viewModel.cards.map(\.id), ["a", "b"], "deferred while editing")

        viewModel.cancelEditing()
        XCTAssertEqual(viewModel.cards.map(\.id), ["a", "c"])
    }

    func testRightClickAddPlacesCardUnderCursor() {
        let (viewModel, _) = makeViewModel()
        viewModel.gridSnapEnabled = false
        viewModel.transform = CanvasTransform(zoom: 2,
                                              offset: CGPoint(x: -100, y: -50))

        // The catcher records the click in screen space; conversion to
        // world happens at record time.
        viewModel.recordRightClick(atScreenPoint: CGPoint(x: 300, y: 250))
        let world = viewModel.consumeRightClickPoint()
        XCTAssertEqual(world?.x, 200, "(300 − −100) ÷ 2")
        XCTAssertEqual(world?.y, 150)
        XCTAssertNil(viewModel.consumeRightClickPoint(), "consumed once")

        viewModel.createNewCard(type: .text, at: CGPoint(x: 333, y: 444))
        XCTAssertEqual(viewModel.editingCard?.canvasX, 333)
        XCTAssertEqual(viewModel.editingCard?.canvasY, 444)
        XCTAssertEqual(viewModel.editingCard?.cardType, "text")

        // Snap applies to right-click placement when enabled.
        viewModel.gridSnapEnabled = true
        viewModel.gridSnapSize = 20
        viewModel.createNewCard(type: .image, at: CGPoint(x: 333, y: 444))
        XCTAssertEqual(viewModel.editingCard?.canvasX, 340)
        XCTAssertEqual(viewModel.editingCard?.canvasY, 440)
    }

    func testFrameDragCarriesContainedCardsOnly() {
        let (viewModel, changes) = makeViewModel()
        viewModel.gridSnapEnabled = false
        var frame = VisionCard(id: "f", cardType: "frame",
                               canvasX: 50, canvasY: 50,
                               zOrder: 5, canvasWidth: 400, canvasHeight: 400)
        frame.boardId = "master"
        viewModel.setCards(viewModel.cards + [frame])
        // Card "a" (center 200,200) is inside the frame; "b" (center
        // 500,200) is outside.

        viewModel.beginCardDrag(anchor: "f")
        viewModel.endCardDrag(translation: CGSize(width: 30, height: 40))

        XCTAssertEqual(viewModel.cards.first { $0.id == "f" }?.canvasX, 80)
        XCTAssertEqual(viewModel.cards.first { $0.id == "a" }?.canvasX, 130,
                       "contained card moves rigidly with its frame")
        XCTAssertEqual(viewModel.cards.first { $0.id == "a" }?.canvasY, 140)
        XCTAssertEqual(viewModel.cards.first { $0.id == "b" }?.canvasX, 400,
                       "cards outside the frame stay put")
        XCTAssertEqual(changes(), 1, "one commit for the whole carry")

        // Frames draw under everything regardless of zOrder.
        XCTAssertEqual(viewModel.filteredCards.first?.id, "f")
    }

    func testConnectorSessionCompletesDedupesAndCascades() {
        let (viewModel, _) = makeViewModel()
        var connectorLog: [[VisionConnector]] = []
        viewModel.onConnectorsChanged = { connectorLog.append($0) }

        viewModel.beginConnector(from: "a")
        XCTAssertEqual(viewModel.pendingConnectorSource, "a")
        viewModel.completeConnector(to: "b")
        XCTAssertEqual(viewModel.connectors.count, 1)
        XCTAssertNil(viewModel.pendingConnectorSource)

        // Self-link and duplicate are ignored (pending clears anyway).
        viewModel.beginConnector(from: "a")
        viewModel.completeConnector(to: "a")
        viewModel.beginConnector(from: "a")
        viewModel.completeConnector(to: "b")
        XCTAssertEqual(viewModel.connectors.count, 1)

        // Clicking empty canvas disarms.
        viewModel.beginConnector(from: "b")
        viewModel.clearSelection()
        XCTAssertNil(viewModel.pendingConnectorSource)

        viewModel.setConnectorLabel(viewModel.connectors[0].id,
                                    label: "palette → night")
        XCTAssertEqual(viewModel.connectors[0].label, "palette → night")

        // Deleting an endpoint severs the arrow.
        viewModel.removeCard("b")
        XCTAssertTrue(viewModel.connectors.isEmpty)
        XCTAssertEqual(connectorLog.count, 3, "create, relabel, cascade")
    }

    func testTextStyleResolutionAndStickyLastUsed() {
        XCTAssertEqual(VisionTextStyle.resolve(nil), .title,
                       "pre-preset cards render as the poster default")
        XCTAssertEqual(VisionTextStyle.resolve("garbage"), .title)
        XCTAssertEqual(VisionTextStyle.resolve("tag"), .tag)

        let defaults = UserDefaults.standard
        defer { defaults.removeObject(
            forKey: VisionBoardViewModel.lastTextStyleKey) }
        let (viewModel, _) = makeViewModel()

        viewModel.createNewCard(type: .text, textStyle: "section")
        XCTAssertEqual(viewModel.editingCard?.textStyle, "section")

        // Next text card with no explicit style reuses the last one.
        viewModel.createNewCard(type: .text)
        XCTAssertEqual(viewModel.editingCard?.textStyle, "section")

        // Non-text cards never carry a text style.
        viewModel.createNewCard(type: .image)
        XCTAssertNil(viewModel.editingCard?.textStyle)
    }

    func testCreateNewCardLandsInVisibleWorld() {
        let (viewModel, _) = makeViewModel()
        viewModel.viewportSize = CGSize(width: 800, height: 600)
        viewModel.transform = CanvasTransform(zoom: 1,
                                              offset: CGPoint(x: -2000, y: -2000))

        viewModel.createNewCard(type: .text)
        guard let card = viewModel.editingCard else { return XCTFail("no editing card") }
        let visible = viewModel.transform.visibleWorldRect(
            viewport: viewModel.viewportSize)
        XCTAssertTrue(visible.contains(CGPoint(x: card.canvasX ?? -1,
                                               y: card.canvasY ?? -1)),
                      "new card must appear in view, not at a stale origin")
    }
}
