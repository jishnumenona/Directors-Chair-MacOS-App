// DirectorsChairViewsTests/VisionPaletteExtractorTests.swift
//
// Vision board roadmap #2: palette-from-image — deterministic extraction
// and the VM action that turns an image card into an adjacent palette card.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class VisionPaletteExtractorTests: XCTestCase {

    private func solidImage(_ color: NSColor, size: CGFloat = 64) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        image.unlockFocus()
        return image
    }

    /// Channel components: lockFocus renders through the display profile,
    /// so exact hex values shift per machine — dominance is the invariant.
    private func rgb(_ hex: String) -> (r: Int, g: Int, b: Int) {
        let v = Int(hex.dropFirst(), radix: 16) ?? 0
        return (v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
    }

    func testSolidImageYieldsItsSingleColor() {
        let red = solidImage(NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        let colors = VisionPaletteExtractor.extract(from: red)
        XCTAssertEqual(colors.count, 1, "one bucket for a solid image")
        let c = rgb(colors[0])
        XCTAssertGreaterThan(c.r, 190)
        XCTAssertLessThan(max(c.g, c.b), 130, "red-dominant")
    }

    func testTwoToneImageYieldsBothColors() {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.lockFocus()
        NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 32, height: 64).fill()
        NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1).setFill()
        NSRect(x: 32, y: 0, width: 32, height: 64).fill()
        image.unlockFocus()

        let colors = VisionPaletteExtractor.extract(from: image)
        XCTAssertEqual(colors.count, 2,
                       "distance filter keeps both distinct tones, nothing else")
        let parsed = colors.map(rgb)
        XCTAssertTrue(parsed.contains { $0.r > 190 && $0.b < 130 }, "a red")
        XCTAssertTrue(parsed.contains { $0.b > 190 && $0.r < 130 }, "a blue")
    }

    func testInvalidInputYieldsEmpty() {
        XCTAssertEqual(VisionPaletteExtractor.extract(from: NSImage()), [])
        let red = solidImage(NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        XCTAssertEqual(VisionPaletteExtractor.extract(from: red, count: 0), [])
    }

    @MainActor
    func testExtractPaletteCreatesAdjacentPaletteCard() throws {
        let projectBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("vb-palette-\(UUID().uuidString)")
        let assets = projectBase.appendingPathComponent("assets/visionboard")
        try FileManager.default.createDirectory(
            at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectBase) }

        let image = solidImage(NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try rep.representation(using: .png, properties: [:])!
            .write(to: assets.appendingPathComponent("ref.png"))

        var source = VisionCard(id: "src", title: "Forest",
                                imagePath: "assets/visionboard/ref.png",
                                canvasX: 100, canvasY: 60,
                                canvasWidth: 300, canvasHeight: 200)
        source.boardId = "master"
        let viewModel = VisionBoardViewModel(cards: [source])
        viewModel.configureAssetStore(projectBase: projectBase)
        var commits = 0
        viewModel.onCardsChanged = { _ in commits += 1 }

        viewModel.extractPalette(fromCardId: "src")

        XCTAssertEqual(viewModel.cards.count, 2)
        let palette = viewModel.cards[1]
        XCTAssertEqual(palette.cardType, "color_palette")
        XCTAssertEqual(palette.title, "Forest palette")
        XCTAssertEqual(palette.canvasX, 424, "source x + width + 24 gutter")
        XCTAssertEqual(palette.canvasY, 60)
        XCTAssertEqual(palette.colorPalette.count, 1)
        let green = rgb(palette.colorPalette[0])
        XCTAssertGreaterThan(green.g, 190, "green-dominant swatch")
        XCTAssertEqual(commits, 1)

        // Unresolvable image: no card, no commit.
        viewModel.extractPalette(fromCardId: "missing")
        XCTAssertEqual(viewModel.cards.count, 2)
        XCTAssertEqual(commits, 1)
    }
}
