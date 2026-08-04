// DirectorsChairViewsTests/VisionBoardExporterTests.swift
//
// Vision Board repair, Slice 6: PNG export — pure layout math (bbox
// translation + padding), the render-scale cap, and a renderer smoke
// test proving a real PNG comes out at the expected dimensions.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class VisionBoardExporterTests: XCTestCase {

    func testLayoutOfNoCardsIsNil() {
        XCTAssertNil(VisionBoardExporter.layout(cards: []))
    }

    func testLayoutTranslatesBoundingBoxWithPadding() {
        let cards = [
            VisionCard(id: "a", canvasX: 100, canvasY: 100,
                       canvasWidth: 200, canvasHeight: 200),
            VisionCard(id: "b", canvasX: 400, canvasY: 300,
                       canvasWidth: 200, canvasHeight: 200),
        ]
        let layout = VisionBoardExporter.layout(cards: cards, padding: 40)!

        // bbox spans (100,100)–(600,500) → 500×400 world, +40 padding.
        XCTAssertEqual(layout.canvasSize, CGSize(width: 580, height: 480))
        XCTAssertEqual(layout.frames["a"],
                       CGRect(x: 40, y: 40, width: 200, height: 200))
        XCTAssertEqual(layout.frames["b"],
                       CGRect(x: 340, y: 240, width: 200, height: 200))
    }

    func testLayoutHandlesNegativeWorldCoordinates() {
        let cards = [VisionCard(id: "a", canvasX: -500, canvasY: -300,
                                canvasWidth: 200, canvasHeight: 200)]
        let layout = VisionBoardExporter.layout(cards: cards, padding: 40)!
        XCTAssertEqual(layout.frames["a"]?.origin, CGPoint(x: 40, y: 40),
                       "far-negative cards still land inside the bitmap")
        XCTAssertEqual(layout.canvasSize, CGSize(width: 280, height: 280))
    }

    func testRenderScaleCapsHugeBoards() {
        XCTAssertEqual(
            VisionBoardExporter.renderScale(for: CGSize(width: 1000, height: 500)),
            2, "small boards render at the preferred 2x")
        XCTAssertEqual(
            VisionBoardExporter.renderScale(for: CGSize(width: 16384, height: 100)),
            0.5, "longest dimension capped at 8192 pixels")
        XCTAssertEqual(
            VisionBoardExporter.renderScale(for: .zero), 2)
    }

    @MainActor
    func testRenderPNGProducesDecodableImageAtExpectedSize() throws {
        var text = VisionCard(id: "t", canvasX: 0, canvasY: 0,
                              canvasWidth: 200, canvasHeight: 100)
        text.cardType = "text"
        text.text = "Neon rain"
        var palette = VisionCard(id: "p", canvasX: 260, canvasY: 0,
                                 canvasWidth: 200, canvasHeight: 100)
        palette.cardType = "color_palette"
        palette.colorPalette = ["#FF5733", "#1E1E1E"]

        let data = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [text, palette], projectBase: nil))
        let image = try XCTUnwrap(NSImage(data: data))

        // Canvas 540×180 world at 2× — representations carry pixel size.
        let rep = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        XCTAssertEqual(rep.pixelsWide, 1080)
        XCTAssertEqual(rep.pixelsHigh, 360)
    }

    @MainActor
    func testRenderPNGOfEmptyBoardIsNil() {
        XCTAssertNil(VisionBoardExporter.renderPNG(cards: [], projectBase: nil))
    }
}


// MARK: - The export IS the wall (owner report 2026-08-03)

@MainActor
final class VisionBoardExportFidelityTests: XCTestCase {

    private func card(_ id: String, x: Double, y: Double) -> VisionCard {
        var card = VisionCard(id: id)
        card.canvasX = x; card.canvasY = y
        card.canvasWidth = 200; card.canvasHeight = 150
        return card
    }

    func testThreadIsExportedWithTheBoard() throws {
        // The export drew its own thing — black ground, bare rectangles,
        // no pins and no thread — because it kept a private renderer that
        // never learned about the wall. Connections must reach the file.
        let a = card("a", x: 0, y: 0)
        let b = card("b", x: 400, y: 0)
        let thread = VisionConnector(boardId: "master", fromCardId: "a",
                                     toCardId: "b", label: "the look")

        let plain = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [a, b], connectors: [], projectBase: nil))
        let strung = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [a, b], connectors: [thread], projectBase: nil))

        XCTAssertNotEqual(plain, strung,
                          "a board with thread on it must not export identically")
    }

    func testExportedElementsCarryTheirTiltAndStock() throws {
        var flat = card("s", x: 0, y: 0)
        flat.cardType = "text"
        flat.text = "dusk"

        var tilted = flat
        tilted.rotation = -6

        var onKraft = flat
        onKraft.paper = "kraft"

        let a = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [flat], projectBase: nil))
        let b = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [tilted], projectBase: nil))
        let c = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [onKraft], projectBase: nil))

        XCTAssertNotEqual(a, b, "tilt reaches the file")
        XCTAssertNotEqual(a, c, "so does the paper it is written on")
    }
}
