// Tests/DirectorsChairViewsTests/VisionLinkRevealTests.swift
//
// The far end of dragging a scene onto an element: pressing the button on
// that scene has to LAND on it. Arriving at the right board but the wrong
// corner, or at 4% zoom on a wall of two hundred scraps, is the same as
// not arriving.

import XCTest
import SwiftUI
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class VisionLinkRevealTests: XCTestCase {

    private let viewport = CGSize(width: 1200, height: 800)

    private func board() -> (VisionBoardViewModel, VisionCard) {
        let viewModel = VisionBoardViewModel()
        var far = VisionCard()
        far.canvasX = 4200; far.canvasY = 3100
        far.canvasWidth = 240; far.canvasHeight = 160
        viewModel.addCard(far)
        return (viewModel, viewModel.cards[0])
    }

    func testRevealPutsTheElementInTheMiddleOfTheScreen() {
        let (viewModel, card) = board()

        XCTAssertTrue(viewModel.reveal(cardId: card.id, viewSize: viewport))

        let centreOfCard = CGPoint(x: (card.canvasX ?? 0) + 120,
                                   y: (card.canvasY ?? 0) + 80)
        let onScreen = viewModel.transform.toScreen(centreOfCard)
        XCTAssertEqual(onScreen.x, viewport.width / 2, accuracy: 0.5)
        XCTAssertEqual(onScreen.y, viewport.height / 2, accuracy: 0.5)
    }

    func testRevealArrivesAtAReadableZoom() {
        let (viewModel, card) = board()
        viewModel.setZoomLevel(0.04)          // parked right out at the edge

        viewModel.reveal(cardId: card.id, viewSize: viewport)

        XCTAssertGreaterThan(viewModel.transform.zoom, 0.5,
            "landing on an element you cannot read is not arriving")
    }

    func testRevealSelectsWhatItBroughtYouTo() {
        let (viewModel, card) = board()
        viewModel.reveal(cardId: card.id, viewSize: viewport)
        XCTAssertEqual(viewModel.selectedCardIds, [card.id],
                       "so it is obvious WHICH element you were sent to")
    }

    func testRevealCrossesToTheBoardTheElementIsOn() {
        let viewModel = VisionBoardViewModel(
            boards: [VisionBoardMeta(id: "master", name: "Master"),
                     VisionBoardMeta(id: "lighting", name: "Lighting")])
        // addCard assigns the CURRENT board, so the element has to be
        // put up while standing at the lighting wall — setting boardId on
        // the way in would have been silently overwritten and this test
        // would have proved nothing.
        viewModel.currentBoardId = "lighting"
        var card = VisionCard()
        card.canvasX = 100; card.canvasY = 100
        viewModel.addCard(card)
        viewModel.currentBoardId = "master"

        XCTAssertTrue(viewModel.reveal(cardId: viewModel.cards[0].id,
                                       viewSize: viewport))
        XCTAssertEqual(viewModel.currentBoardId, "lighting",
                       "otherwise the trip ends on a blank wall")
    }

    func testRevealingSomethingDeletedDoesNothingRatherThanJumping() {
        let (viewModel, _) = board()
        let before = viewModel.transform
        XCTAssertFalse(viewModel.reveal(cardId: "gone", viewSize: viewport))
        XCTAssertEqual(viewModel.transform, before)
    }

    // MARK: - Making and breaking the link

    func testDroppingASceneOnAnElementPinsItThere() {
        let (viewModel, card) = board()
        viewModel.link(card.id, to: VisionCardLinkRef(
            kind: .scene, id: "scene-7", label: "Scene 3"))

        XCTAssertEqual(viewModel.cards[0].linkedSceneId, "scene-7")
        XCTAssertNil(viewModel.cards[0].linkedShotId)
        XCTAssertEqual(viewModel.cards[0].linkedLabel, "Scene 3")
    }

    func testDroppingAShotAlsoRecordsItsScene() {
        let (viewModel, card) = board()
        viewModel.link(card.id, to: VisionCardLinkRef(
            kind: .shot, id: "shot-2", label: "SHOT 4B", sceneId: "scene-7"))

        XCTAssertEqual(viewModel.cards[0].linkedShotId, "shot-2")
        XCTAssertEqual(viewModel.cards[0].linkedSceneId, "scene-7",
                       "a shot belongs to a scene, so both are known")
    }

    func testASecondDropReplacesTheFirstRatherThanStacking() {
        let (viewModel, card) = board()
        viewModel.link(card.id, to: VisionCardLinkRef(
            kind: .shot, id: "shot-2", label: "SHOT 4B", sceneId: "scene-7"))
        viewModel.link(card.id, to: VisionCardLinkRef(
            kind: .scene, id: "scene-9", label: "Scene 5"))

        XCTAssertNil(viewModel.cards[0].linkedShotId,
                     "an element points at one thing, and it is the last "
                     + "thing you dropped on it")
        XCTAssertEqual(viewModel.cards[0].linkedSceneId, "scene-9")
    }

    // MARK: - A link is never words

    func testASceneDroppedOnAnElementLinksRatherThanPinningUpItsURI() {
        // The owner's report, exactly: dropping a shot pinned up a tiny
        // clipping reading "DCREF://SHOT/…?LABEL=SHOT%204B". Two nested
        // drop targets meant the wall answered before the element did.
        // Now one path decides, by hit-testing where you let go.
        let (viewModel, card) = board()
        let ref = VisionCardLinkRef(kind: .shot, id: "shot-2",
                                    label: "SHOT 4B", sceneId: "scene-7")
        let overTheElement = CGPoint(x: (card.canvasX ?? 0) + 120,
                                     y: (card.canvasY ?? 0) + 80)

        let target = VisionWallHitTest.scrap(at: overTheElement,
                                             cards: viewModel.filteredCards)
        XCTAssertEqual(target?.id, card.id,
                       "the element under the cursor is the one that links")

        viewModel.link(try! XCTUnwrap(target).id, to: ref)
        XCTAssertEqual(viewModel.cards.count, 1,
                       "and no clipping of the raw URI joins the wall")
        XCTAssertEqual(viewModel.cards[0].linkedShotId, "shot-2")
    }

    func testDroppingOnBareWallHitsNothingToLink() {
        let (viewModel, _) = board()
        let emptyWall = CGPoint(x: -900, y: -900)
        XCTAssertNil(VisionWallHitTest.scrap(at: emptyWall,
                                             cards: viewModel.filteredCards),
                     "which is what makes the wall say where to drop it")
    }

    // MARK: - The tag is a way back

    func testAnElementKnowsWhatItIsPinnedTo() {
        let (viewModel, card) = board()
        viewModel.link(card.id, to: VisionCardLinkRef(
            kind: .shot, id: "shot-2", label: "SHOT 4B", sceneId: "scene-7"))

        let ref = viewModel.cards[0].linkedRef
        XCTAssertEqual(ref?.kind, .shot)
        XCTAssertEqual(ref?.id, "shot-2")
        XCTAssertEqual(ref?.label, "SHOT 4B",
                       "the tag shows a name, not an id")
    }

    func testAShotWinsOverItsSceneOnTheTag() {
        // Linking a shot records both ids; the tag must open the SHOT,
        // the more specific of the two.
        let (viewModel, card) = board()
        viewModel.link(card.id, to: VisionCardLinkRef(
            kind: .shot, id: "shot-2", label: "SHOT 4B", sceneId: "scene-7"))
        XCTAssertEqual(viewModel.cards[0].linkedRef?.kind, .shot)
    }

    func testAnUnlinkedElementHasNoTag() {
        let (viewModel, _) = board()
        XCTAssertNil(viewModel.cards[0].linkedRef)
    }

    func testUnlinkingClearsBothEndsAndTheTab() {
        let (viewModel, card) = board()
        viewModel.link(card.id, to: VisionCardLinkRef(
            kind: .shot, id: "shot-2", label: "SHOT 4B", sceneId: "scene-7"))
        viewModel.link(card.id, to: nil)

        XCTAssertNil(viewModel.cards[0].linkedShotId)
        XCTAssertNil(viewModel.cards[0].linkedSceneId)
        XCTAssertNil(viewModel.cards[0].linkedLabel)
    }
}

// MARK: - The drop pipeline end to end (minus the gesture)

/// The gesture itself can't be exercised offscreen, but everything after
/// it can: what an NSItemProvider carrying our URI turns into, and
/// whether that survives the same classification an image or a stray line
/// of text goes through. This is the seam the link kept falling into.
@MainActor
final class VisionLinkDropPipelineTests: XCTestCase {

    private func payload(for text: String) async -> AbsorbPayload? {
        await VisionBoardAbsorb.payload(from: NSItemProvider(object: text as NSString))
    }

    func testADraggedSceneArrivesAsSomethingWeCanRecognise() async {
        let ref = VisionCardLinkRef(kind: .scene, id: "scene-7",
                                    label: "Scene 3")
        let arrived = await payload(for: ref.dragText)

        // Whichever way the pasteboard classifies it, the address has to
        // still be readable — that is the whole contract.
        let text: String?
        switch arrived {
        case .text(let value): text = value
        case .remoteURL(let url): text = url.absoluteString
        default: text = nil
        }
        XCTAssertNotNil(text, "a dragged scene must survive classification")
        XCTAssertEqual(VisionCardLinkRef.parse(text ?? ""), ref)
    }

    func testADraggedShotArrivesTheSameWay() async {
        let ref = VisionCardLinkRef(kind: .shot, id: "shot-2",
                                    label: "SHOT 4B", sceneId: "scene-7")
        let arrived = await payload(for: ref.dragText)
        let text: String?
        switch arrived {
        case .text(let value): text = value
        case .remoteURL(let url): text = url.absoluteString
        default: text = nil
        }
        XCTAssertEqual(VisionCardLinkRef.parse(text ?? ""), ref,
                       "shots were the ones that would not drag at all")
    }

    func testOrdinaryDraggedWordsStillBecomeAClipping() async {
        let arrived = await payload(for: "cold, wide, unforgiving")
        guard case .text(let value) = arrived else {
            return XCTFail("plain words must still arrive as words")
        }
        XCTAssertNil(VisionCardLinkRef.parse(value),
                     "and must not be mistaken for a link")
    }
}
