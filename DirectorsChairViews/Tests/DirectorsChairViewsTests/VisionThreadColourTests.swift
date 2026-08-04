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
