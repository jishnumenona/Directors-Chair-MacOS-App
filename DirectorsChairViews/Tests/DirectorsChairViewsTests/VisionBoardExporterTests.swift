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
