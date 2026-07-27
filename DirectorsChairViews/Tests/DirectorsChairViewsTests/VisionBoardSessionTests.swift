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
