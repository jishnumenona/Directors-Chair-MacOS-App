// DirectorsChairViewsTests/VisionBoardLookbookTests.swift
//
// Vision board roadmap #6: lookbook PDF — pure pagination (frames become
// pages in reading order, unframed cards trail, whole-board fallback)
// and a renderer smoke test.

import XCTest
import PDFKit
import DirectorsChairCore
@testable import DirectorsChairViews

final class VisionBoardLookbookTests: XCTestCase {

    private func frame(_ id: String, _ title: String,
                       x: Double, y: Double,
                       w: Double = 400, h: Double = 300) -> VisionCard {
        var card = VisionCard(id: id, title: title,
                              cardType: "frame",
                              canvasX: x, canvasY: y,
                              canvasWidth: w, canvasHeight: h)
        card.boardId = "master"
        return card
    }

    private func card(_ id: String, x: Double, y: Double) -> VisionCard {
        VisionCard(id: id, canvasX: x, canvasY: y,
                   canvasWidth: 100, canvasHeight: 100)
    }

    func testPagesFollowFramesInReadingOrderWithLeftoversTrailing() {
        let cards = [
            frame("f2", "Lighting", x: 500, y: 0),
            frame("f1", "Tone", x: 0, y: 0),
            card("inTone", x: 50, y: 50),          // center 100,100 ∈ f1
            card("inLighting", x: 600, y: 50),     // center 650,100 ∈ f2
            card("loose", x: 50, y: 900),          // in no frame
        ]
        let pages = VisionBoardLookbook.pages(cards: cards)

        XCTAssertEqual(pages.map(\.title),
                       ["Tone", "Lighting", "Everything else"],
                       "same y → left-to-right; leftovers trail")
        XCTAssertEqual(pages[0].cards.map(\.id), ["f1", "inTone"],
                       "the frame itself rides along as the page backdrop")
        XCTAssertEqual(pages[1].cards.map(\.id), ["f2", "inLighting"])
        XCTAssertEqual(pages[2].cards.map(\.id), ["loose"])
    }

    func testOverlappingFramesClaimFirstComeAndFallbackWithoutFrames() {
        let overlapping = [
            frame("f1", "A", x: 0, y: 0),
            frame("f2", "B", x: 100, y: 0),        // overlaps f1
            card("shared", x: 150, y: 100),        // center ∈ both
        ]
        let pages = VisionBoardLookbook.pages(cards: overlapping)
        XCTAssertEqual(pages[0].cards.map(\.id), ["f1", "shared"],
                       "reading order wins; no duplicate on page B")
        XCTAssertEqual(pages[1].cards.map(\.id), ["f2"])

        let none = VisionBoardLookbook.pages(cards: [card("a", x: 0, y: 0)])
        XCTAssertEqual(none.map(\.title), ["Board"], "no frames → one page")
        XCTAssertTrue(VisionBoardLookbook.pages(cards: []).isEmpty)
    }

    @MainActor
    func testRenderPDFProducesOnePagePerSection() throws {
        let cards = [
            frame("f1", "Tone", x: 0, y: 0),
            card("a", x: 50, y: 50),
            card("loose", x: 50, y: 900),
        ]
        let data = try XCTUnwrap(VisionBoardLookbook.renderPDF(
            cards: cards, projectBase: nil))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 2, "Tone + Everything else")

        XCTAssertNil(VisionBoardLookbook.renderPDF(cards: [], projectBase: nil))
    }
}
