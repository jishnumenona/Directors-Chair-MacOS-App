// Tests/DirectorsChairViewsTests/VisionThreadColourTests.swift
//
// Colour per cord. The risks worth pinning are not "does the enum hold
// hexes" — they are the two that have actually bitten this board:
//   · a board saved before threads had colour must still open, and its
//     cords must still be the crimson they were drawn in;
//   · the wall, the PNG export and the PDF lookbook are three separate
//     renderers of the same picture, and they have drifted apart before
//     (the export lost its pins and thread entirely). A colour that only
//     the screen honours is the same bug wearing a different hat.

import XCTest
import SwiftUI
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class VisionThreadColourTests: XCTestCase {

    // MARK: - Old boards keep opening

    func testAConnectorSavedBeforeThreadColourStillDecodes() throws {
        let legacy = """
        {"id":"c1","board_id":"master","from_card_id":"a",
         "to_card_id":"b","label":"echo"}
        """.data(using: .utf8)!

        let connector = try JSONDecoder().decode(VisionConnector.self, from: legacy)

        XCTAssertEqual(connector.label, "echo")
        XCTAssertNil(connector.thread)
        XCTAssertEqual(VisionThread.resolve(connector.thread), .crimson,
                       "every cord on an old board was crimson; it stays crimson")
    }

    func testThreadColourSurvivesASaveAndReload() throws {
        var connector = VisionConnector(fromCardId: "a", toCardId: "b")
        connector.thread = VisionThread.navy.rawValue

        let data = try JSONEncoder().encode(connector)
        let reloaded = try JSONDecoder().decode(VisionConnector.self, from: data)

        XCTAssertEqual(VisionThread.resolve(reloaded.thread), .navy)
    }

    func testAnUnknownColourFallsBackRatherThanFailing() {
        // A board written by a newer version, or a hand-edited file.
        XCTAssertEqual(VisionThread.resolve("chartreuse"), .crimson)
        XCTAssertEqual(VisionThread.resolve(nil), .crimson)
    }

    // MARK: - Restringing one cord

    func testRestringingChangesOnlyThatCord() {
        let viewModel = VisionBoardViewModel()
        viewModel.addCard(VisionCard())
        viewModel.addCard(VisionCard())
        let first = VisionConnector(fromCardId: viewModel.cards[0].id,
                                    toCardId: viewModel.cards[1].id)
        let second = VisionConnector(fromCardId: viewModel.cards[1].id,
                                     toCardId: viewModel.cards[0].id)
        viewModel.connectors = [first, second]

        viewModel.setThread(first.id, to: .forest)

        XCTAssertEqual(VisionThread.resolve(
            viewModel.connectors.first { $0.id == first.id }?.thread), .forest)
        XCTAssertEqual(VisionThread.resolve(
            viewModel.connectors.first { $0.id == second.id }?.thread), .crimson,
            "colour is per thread — restringing one must not repaint the board")
    }

    func testRestringingAThreadThatIsNoLongerThereIsHarmless() {
        let viewModel = VisionBoardViewModel()
        viewModel.setThread("cut-already", to: .mustard)
        XCTAssertTrue(viewModel.connectors.isEmpty)
    }

    // MARK: - Every renderer honours it

    /// Mean colour of a render, as a cheap "what hue is this picture".
    private func averageHue(_ bitmap: NSBitmapImageRep) -> (red: Double, blue: Double) {
        var red = 0.0, blue = 0.0, count = 0.0
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
                guard let colour = bitmap.colorAt(x: x, y: y) else { continue }
                red += colour.redComponent
                blue += colour.blueComponent
                count += 1
            }
        }
        guard count > 0 else { return (0, 0) }
        return (red / count, blue / count)
    }

    private func twoTackedCards() -> [VisionCard] {
        var a = VisionCard()
        a.canvasX = 30; a.canvasY = 40
        a.canvasWidth = 120; a.canvasHeight = 90
        var b = VisionCard()
        b.canvasX = 300; b.canvasY = 220
        b.canvasWidth = 120; b.canvasHeight = 90
        return [a, b]
    }

    func testTheExportedWallIsStrungInTheChosenTwine() throws {
        // The PNG export and the PDF lookbook share this renderer, so
        // proving it here covers both — that sharing is the whole reason
        // they stopped drifting.
        let cards = twoTackedCards()
        var crimson = VisionConnector(fromCardId: cards[0].id,
                                      toCardId: cards[1].id)
        crimson.thread = VisionThread.crimson.rawValue
        var navy = crimson
        navy.thread = VisionThread.navy.rawValue

        // The real export path, end to end, not a stand-in view.
        let base: URL? = nil
        let crimsonPNG = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: cards, connectors: [crimson], projectBase: base))
        let navyPNG = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: cards, connectors: [navy], projectBase: base))
        let red = averageHue(try XCTUnwrap(NSBitmapImageRep(data: crimsonPNG)))
        let blue = averageHue(try XCTUnwrap(NSBitmapImageRep(data: navyPNG)))

        XCTAssertGreaterThan(red.red - red.blue, blue.red - blue.blue,
            "a navy cord must export bluer than a crimson one — if the "
            + "export ignores the colour, the wall and the print disagree "
            + "again (crimson r-b: \(red.red - red.blue), "
            + "navy r-b: \(blue.red - blue.blue))")
    }

    func testEveryTwineIsDistinguishableFromCrimson() {
        // A palette where two entries look alike is a palette that can't
        // do its job — keeping several lines of thinking apart.
        for twine in VisionThread.allCases where twine != .crimson {
            XCTAssertNotEqual(twine.cord.description,
                              VisionThread.crimson.cord.description,
                              "\(twine.displayName) must not read as crimson")
        }
        XCTAssertEqual(Set(VisionThread.allCases.map { $0.cord.description }).count,
                       VisionThread.allCases.count,
                       "no two twines share a colour")
    }
}

// MARK: - A cord has its own tools

/// Right-clicking a thread used to bloom the wall's making tools AND a
/// system context menu on top. The rule that fixes it is a routing rule,
/// so it is pinned as one — the ring that opens is decided by what the
/// click landed on, and exactly one thing can be under it.
@MainActor
final class VisionThreadRingTests: XCTestCase {

    private let leftTack = CGPoint(x: 100, y: 100)
    private let rightTack = CGPoint(x: 400, y: 100)

    private func connector() -> VisionConnector {
        VisionConnector(fromCardId: "a", toCardId: "b")
    }

    private func tack(_ id: String) -> CGPoint? {
        id == "a" ? leftTack : (id == "b" ? rightTack : nil)
    }

    func testClickingOnTheCordFindsIt() {
        // The cord SAGS, so its middle is well below the straight line
        // between the pins — clicking the straight line must miss, and
        // clicking the sag must hit, or you'd be aiming at a cord that
        // isn't where it's drawn.
        //
        // 300pt run → sag 45 → control y = 100 + 90 = 190, and the
        // midpoint of a quadratic sits at a quarter/half/quarter blend:
        // 0.25·100 + 0.5·190 + 0.25·100 = 145. Forty-five points below
        // the pins, which is the whole point of testing it.
        let sagged = CGPoint(x: 250, y: 145)

        let hit = VisionWallHitTest.thread(at: sagged, connectors: [connector()],
                                           tack: tack, tolerance: 13)
        XCTAssertNotNil(hit)
    }

    func testClickingWellAwayFromTheCordFindsNothing() {
        let empty = CGPoint(x: 250, y: 400)
        XCTAssertNil(VisionWallHitTest.thread(at: empty, connectors: [connector()],
                                              tack: tack, tolerance: 13))
    }

    func testTheStraightLineBetweenPinsIsNotTheCord() {
        // Midway, the drawn cord hangs ~45pt lower. A hit-test that used
        // a straight line would light up here, where there is no thread.
        let straight = CGPoint(x: 250, y: 100)
        XCTAssertNil(VisionWallHitTest.thread(at: straight,
                                              connectors: [connector()],
                                              tack: tack, tolerance: 13),
                     "the clickable cord must follow the drawn curve")
    }

    func testTheNearestOfSeveralCordsWins() {
        let first = VisionConnector(id: "one", fromCardId: "a", toCardId: "b")
        let second = VisionConnector(id: "two", fromCardId: "b", toCardId: "a")
        // Both cords occupy the same curve here, so this only asserts the
        // search returns one of them rather than throwing or picking none.
        let hit = VisionWallHitTest.thread(at: CGPoint(x: 250, y: 145),
                                           connectors: [first, second],
                                           tack: tack, tolerance: 20)
        XCTAssertNotNil(hit)
    }

    func testAConnectorWithAMissingEndIsSkipped() {
        // A card can be deleted while its cord is still in the array.
        let orphan = VisionConnector(fromCardId: "a", toCardId: "gone")
        XCTAssertNil(VisionWallHitTest.thread(at: CGPoint(x: 250, y: 145),
                                              connectors: [orphan],
                                              tack: tack, tolerance: 20))
    }

    // MARK: - Weight

    func testWeightStepsThroughRealStringSizes() {
        XCTAssertEqual(VisionThreadRing.step(from: 5, by: 1), 7)
        XCTAssertEqual(VisionThreadRing.step(from: 5, by: -1), 4)
    }

    func testWeightStopsAtTheEnds() {
        let thinnest = VisionThreadRing.weights.first!
        let thickest = VisionThreadRing.weights.last!
        XCTAssertEqual(VisionThreadRing.step(from: thinnest, by: -1), thinnest)
        XCTAssertEqual(VisionThreadRing.step(from: thickest, by: 1), thickest)
    }

    func testAnOddStoredWeightSnapsToTheNearestNotch() {
        // A board hand-edited, or written by a later version.
        XCTAssertEqual(VisionThreadRing.step(from: 6.9, by: 0), 7)
    }

    func testWeightIsNamedNotNumbered() {
        XCTAssertEqual(VisionThreadRing.weightName(2.5), "Fine")
        XCTAssertEqual(VisionThreadRing.weightName(5), "Twine")
        XCTAssertEqual(VisionThreadRing.weightName(9.5), "Rope")
    }

    func testWeightIsPerThreadAndSurvivesReload() throws {
        let viewModel = VisionBoardViewModel()
        let cord = connector()
        viewModel.connectors = [cord]
        viewModel.setThreadThickness(cord.id, to: 9.5)

        let data = try JSONEncoder().encode(viewModel.connectors[0])
        let reloaded = try JSONDecoder().decode(VisionConnector.self, from: data)
        XCTAssertEqual(reloaded.thickness, 9.5)
    }

    func testACordSavedBeforeWeightsStillOpens() throws {
        let legacy = """
        {"id":"c1","from_card_id":"a","to_card_id":"b","label":""}
        """.data(using: .utf8)!
        let cord = try JSONDecoder().decode(VisionConnector.self, from: legacy)
        XCTAssertNil(cord.thickness, "and draws at the standard 5 it always did")
    }
}
