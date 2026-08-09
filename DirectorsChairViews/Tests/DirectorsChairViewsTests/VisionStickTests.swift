// Tests/DirectorsChairViewsTests/VisionStickTests.swift
//
// A picture pinned on a picture travels with it — "similar to how a
// paper pasted on another paper will act like the same paper" (owner,
// verbatim). The relationship is explicit (Stick / Peel off on the
// ring), never inferred from overlap alone, because things overlap on a
// collage constantly without belonging together.

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class VisionStickTests: XCTestCase {

    /// A wall with `bottom` under `top` (overlapping) and `apart` off to
    /// the side.
    private func wall() -> (VisionBoardViewModel, bottom: String,
                            top: String, apart: String) {
        let viewModel = VisionBoardViewModel()
        var bottom = VisionCard()
        bottom.canvasX = 100; bottom.canvasY = 100
        bottom.canvasWidth = 300; bottom.canvasHeight = 220
        viewModel.addCard(bottom)
        var top = VisionCard()
        top.canvasX = 180; top.canvasY = 160
        top.canvasWidth = 140; top.canvasHeight = 100
        viewModel.addCard(top)
        var apart = VisionCard()
        apart.canvasX = 900; apart.canvasY = 700
        viewModel.addCard(apart)
        return (viewModel, viewModel.cards[0].id,
                viewModel.cards[1].id, viewModel.cards[2].id)
    }

    // MARK: - What Stick is offered against

    func testTheSheetBeneathIsTheOneItOverlaps() {
        let (viewModel, bottom, top, apart) = wall()
        let topCard = viewModel.cards.first { $0.id == top }!

        XCTAssertEqual(VisionWallHitTest.elementBeneath(
            topCard, in: viewModel.cards)?.id, bottom)

        let apartCard = viewModel.cards.first { $0.id == apart }!
        XCTAssertNil(VisionWallHitTest.elementBeneath(
            apartCard, in: viewModel.cards),
            "nothing beneath means no Stick chip — never a dead tool")
    }

    func testOnlyWhatIsBelowInDrawOrderCounts() {
        // The BOTTOM sheet must never offer to stick to the sheet lying
        // on top of it — sticking goes downward, like gravity and glue.
        let (viewModel, bottom, _, _) = wall()
        let bottomCard = viewModel.cards.first { $0.id == bottom }!
        XCTAssertNil(VisionWallHitTest.elementBeneath(
            bottomCard, in: viewModel.cards))
    }

    // MARK: - Travelling as one

    func testDraggingTheParentCarriesTheStuckPile() {
        let (viewModel, bottom, top, _) = wall()
        viewModel.stick(top)
        XCTAssertEqual(viewModel.cards.first { $0.id == top }?.stuckTo, bottom)

        let topBefore = viewModel.cards.first { $0.id == top }!
        viewModel.selectCard(bottom)
        viewModel.beginCardDrag(anchor: bottom)
        viewModel.updateCardDrag(translation: CGSize(width: 60, height: -25))
        viewModel.endCardDrag(translation: CGSize(width: 60, height: -25))

        let topAfter = viewModel.cards.first { $0.id == top }!
        XCTAssertEqual(topAfter.canvasX ?? 0, (topBefore.canvasX ?? 0) + 60,
                       accuracy: 0.01, "the pile moves rigidly")
        XCTAssertEqual(topAfter.canvasY ?? 0, (topBefore.canvasY ?? 0) - 25,
                       accuracy: 0.01)
    }

    func testDraggingTheChildAdjustsItsPlaceWithoutPeeling() {
        // Sliding the pasted photo around ON its parent is repositioning,
        // not detaching — Peel off is the explicit way out.
        let (viewModel, bottom, top, _) = wall()
        viewModel.stick(top)
        let bottomBefore = viewModel.cards.first { $0.id == bottom }!

        viewModel.clearSelection()
        viewModel.selectCard(top)
        viewModel.beginCardDrag(anchor: top)
        viewModel.updateCardDrag(translation: CGSize(width: 20, height: 10))
        viewModel.endCardDrag(translation: CGSize(width: 20, height: 10))

        XCTAssertEqual(viewModel.cards.first { $0.id == top }?.stuckTo, bottom)
        XCTAssertEqual(viewModel.cards.first { $0.id == bottom }?.canvasX,
                       bottomBefore.canvasX,
                       "moving the child never drags the parent")
    }

    func testAPileOnAPileTravelsWhole() {
        let (viewModel, bottom, top, _) = wall()
        var third = VisionCard()
        third.canvasX = 200; third.canvasY = 180
        third.canvasWidth = 80; third.canvasHeight = 60
        viewModel.addCard(third)
        let thirdId = viewModel.cards.last!.id

        viewModel.stick(top)          // top onto bottom
        viewModel.stick(thirdId)      // third onto top (it lies on top)
        XCTAssertEqual(viewModel.cards.first { $0.id == thirdId }?.stuckTo, top)

        let before = viewModel.cards.first { $0.id == thirdId }!
        viewModel.clearSelection()
        viewModel.selectCard(bottom)
        viewModel.beginCardDrag(anchor: bottom)
        viewModel.updateCardDrag(translation: CGSize(width: 15, height: 15))
        viewModel.endCardDrag(translation: CGSize(width: 15, height: 15))

        XCTAssertEqual(viewModel.cards.first { $0.id == thirdId }?.canvasX ?? 0,
                       (before.canvasX ?? 0) + 15, accuracy: 0.01,
                       "three sheets deep still moves as one")
    }

    func testACycleCannotBeGlued() {
        let (viewModel, bottom, top, _) = wall()
        viewModel.stick(top)
        // Force the reverse direction the UI can't produce.
        if let index = viewModel.cards.firstIndex(where: { $0.id == bottom }) {
            var forged = viewModel.cards[index]
            forged.zOrder = 99   // pretend bottom now lies above top
            viewModel.cards[index] = forged
        }
        viewModel.stick(bottom)
        XCTAssertNil(viewModel.cards.first { $0.id == bottom }?.stuckTo,
                     "a stack must never drag itself in a circle")
    }

    // MARK: - Peeling and removal

    func testPeelPutsItBackOnTheWall() {
        let (viewModel, _, top, _) = wall()
        viewModel.stick(top)
        viewModel.peel(top)
        XCTAssertNil(viewModel.cards.first { $0.id == top }?.stuckTo)
    }

    func testRemovingTheParentLandsThePileOnTheWall() {
        let (viewModel, bottom, top, _) = wall()
        viewModel.stick(top)
        viewModel.removeCard(bottom)
        XCTAssertNil(viewModel.cards.first { $0.id == top }?.stuckTo,
                     "never left pointing at a ghost")
    }

    // MARK: - Persistence

    func testAStackSurvivesSaveAndReload() throws {
        var card = VisionCard()
        card.stuckTo = "parent-id"
        let reloaded = try JSONDecoder().decode(
            VisionCard.self, from: JSONEncoder().encode(card))
        XCTAssertEqual(reloaded.stuckTo, "parent-id")
    }

    func testABoardSavedBeforeStickingStillOpens() throws {
        let legacy = """
        {"id":"c1","title":"","description":"","text":"","tags":[],
         "props":[],"costumes":[],"effects":[],"position":0,
         "cardType":"image","boardId":"master","colorPalette":[],
         "pinned":false,"size":"medium","zOrder":0,"textColor":"#FFFFFF",
         "imagePaths":[]}
        """.data(using: .utf8)!
        let card = try JSONDecoder().decode(VisionCard.self, from: legacy)
        XCTAssertNil(card.stuckTo)
    }
}
