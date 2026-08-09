// DirectorsChairViewsTests/VisionWallTextureTests.swift
//
// The wall's material (owner ask: "change the texture of the board").
//
// What must stay true:
//   · plaster is the default AND the fallback — a legacy project, a nil,
//     and a value from the future all open as the wall they always had;
//   · the choice is PER BOARD and persists through the registry, even
//     for legacy boards that never had a registry entry;
//   · each material actually LOOKS different — on the wall and in the
//     export, because a texture that only changes in the picker is a
//     setting, not a material.

import XCTest
import SwiftUI
import AppKit
@testable import DirectorsChairViews
import DirectorsChairCore

@MainActor
final class VisionWallTextureTests: XCTestCase {

    // MARK: - Resolution (never fail a load)

    func testNilAndUnknownStoredValuesFallBackToPlaster() {
        XCTAssertEqual(VisionWallTexture.resolve(nil), .plaster,
                       "every board that predates textures is plaster")
        XCTAssertEqual(VisionWallTexture.resolve("granite"), .plaster,
                       "a value from a newer app must open, not fail")
        XCTAssertEqual(VisionWallTexture.resolve("cork"), .cork)
        XCTAssertEqual(VisionWallTexture.resolve("felt"), .felt)
    }

    func testLegacyBoardMetaDecodesWithoutTexture() throws {
        // A pre-texture project's JSON has no texture key.
        let legacy = Data(#"{"id":"master","name":"Master"}"#.utf8)
        let meta = try JSONDecoder().decode(VisionBoardMeta.self, from: legacy)
        XCTAssertNil(meta.texture)
        XCTAssertEqual(VisionWallTexture.resolve(meta.texture), .plaster)

        // And a chosen material round-trips.
        var chosen = meta
        chosen.texture = VisionWallTexture.cork.rawValue
        let reloaded = try JSONDecoder().decode(
            VisionBoardMeta.self, from: JSONEncoder().encode(chosen))
        XCTAssertEqual(VisionWallTexture.resolve(reloaded.texture), .cork)
    }

    // MARK: - Per-board choice through the view model

    func testSetTextureIsPerBoardAndPersistsThroughTheRegistry() {
        let viewModel = VisionBoardViewModel(
            boards: [VisionBoardMeta(id: "master", name: "Master"),
                     VisionBoardMeta(id: "night", name: "Night")])
        var saved: [VisionBoardMeta]?
        viewModel.onBoardsChanged = { saved = $0 }

        viewModel.setTexture(.cork)
        XCTAssertEqual(viewModel.currentTexture, .cork)
        XCTAssertEqual(saved?.first { $0.id == "master" }?.texture, "cork",
                       "the choice must reach the persistence callback")

        viewModel.switchBoard("night")
        XCTAssertEqual(viewModel.currentTexture, .plaster,
                       "the corkboard must not drag the other walls with it")

        viewModel.setTexture(.felt)
        viewModel.switchBoard("master")
        XCTAssertEqual(viewModel.currentTexture, .cork,
                       "switching back must find the board's own material")
    }

    func testSetTextureOnALegacyBoardCreatesItsRegistryEntry() {
        // Legacy projects derive boards from cards alone — no registry
        // entry exists to carry the texture until we make one.
        var card = VisionCard()
        card.boardId = "locations_wall"
        let viewModel = VisionBoardViewModel(cards: [card], boards: [])
        viewModel.switchBoard("locations_wall")
        var saved: [VisionBoardMeta]?
        viewModel.onBoardsChanged = { saved = $0 }

        viewModel.setTexture(.linen)

        let entry = saved?.first { $0.id == "locations_wall" }
        XCTAssertEqual(entry?.texture, "linen")
        XCTAssertEqual(entry?.name, "Locations Wall",
                       "the created entry keeps the picker's display name")
        XCTAssertEqual(viewModel.currentTexture, .linen)
    }

    // MARK: - The materials are actually different materials

    private func flatten(_ surface: VisionWallSurface, side: CGFloat) -> NSBitmapImageRep? {
        let renderer = ImageRenderer(
            content: surface.frame(width: side, height: side))
        renderer.scale = 1
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)
    }

    private func averageRGB(_ bitmap: NSBitmapImageRep) -> (red: Double, green: Double, blue: Double) {
        var red = 0.0, green = 0.0, blue = 0.0
        var count = 0.0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                guard let color = bitmap.colorAt(x: x, y: y) else { continue }
                red += color.redComponent
                green += color.greenComponent
                blue += color.blueComponent
                count += 1
            }
        }
        return (red / count, green / count, blue / count)
    }

    func testEveryMaterialRendersDistinctFromEveryOther() throws {
        // Average colour separates the materials robustly (cork is
        // browner, felt darker and greener) without pinning pixels the
        // grain design should stay free to evolve.
        var averages: [VisionWallTexture: (red: Double, green: Double, blue: Double)] = [:]
        for texture in VisionWallTexture.allCases {
            let surface = VisionWallSurface(
                transform: CanvasTransform(zoom: 1, offset: .zero),
                texture: texture)
            let bitmap = try XCTUnwrap(flatten(surface, side: 220),
                                       "\(texture) must render")
            averages[texture] = averageRGB(bitmap)
        }
        let pairs = VisionWallTexture.allCases.flatMap { a in
            VisionWallTexture.allCases.compactMap { b in
                a.rawValue < b.rawValue ? (a, b) : nil
            }
        }
        for (a, b) in pairs {
            let left = averages[a]!, right = averages[b]!
            let distance = abs(left.red - right.red)
                + abs(left.green - right.green)
                + abs(left.blue - right.blue)
            XCTAssertGreaterThan(distance, 0.02,
                "\(a.displayName) and \(b.displayName) must not read as "
                + "the same material (distance \(distance))")
        }
    }

    func testTheExportedWallWearsTheBoardsMaterial() throws {
        // Same guarantee the thread colours earned: the PNG export and
        // the PDF lookbook share this renderer, so proving it here
        // covers both — a felt board must not print as plaster.
        var card = VisionCard()
        card.canvasX = 30; card.canvasY = 40
        card.canvasWidth = 120; card.canvasHeight = 90

        let plasterPNG = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [card], projectBase: nil, texture: .plaster))
        let feltPNG = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [card], projectBase: nil, texture: .felt))

        let plaster = averageRGB(try XCTUnwrap(NSBitmapImageRep(data: plasterPNG)))
        let felt = averageRGB(try XCTUnwrap(NSBitmapImageRep(data: feltPNG)))
        XCTAssertGreaterThan(plaster.red, felt.red + 0.1,
            "a felt wall must export darker than plaster — if the export "
            + "ignores the material, the wall and the print disagree "
            + "(plaster r: \(plaster.red), felt r: \(felt.red))")
        XCTAssertGreaterThan(felt.green, felt.red,
            "felt must actually be green, not dark plaster")
    }

    func testPlasterGrainIsTheOriginalWalkBitForBit() {
        // The pre-texture wall generated its grain with an unseeded FNV
        // walk; the existing snapshot baselines all assume it. Re-derive
        // the original tile here and require identity — if a refactor
        // reseeds plaster, every old board subtly changes and the
        // snapshots fail far from the cause.
        let side = Int(VisionWallTexture.tile)
        let reference = NSImage(size: NSSize(width: side, height: side))
        reference.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        var hash: UInt64 = 1469598103934665603
        for y in 0..<side {
            for x in 0..<side {
                hash = (hash ^ UInt64(truncatingIfNeeded: x &* 31 &+ y)) &* 1099511628211
                guard hash % 7 == 0 else { continue }
                let alpha = Double((hash >> 8) % 40) / 400.0
                NSColor(white: 0.35, alpha: alpha).setFill()
                NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1).fill()
            }
        }
        reference.unlockFocus()

        XCTAssertEqual(VisionWallTexture.grain(for: .plaster).tiffRepresentation,
                       reference.tiffRepresentation,
                       "plaster's grain must remain the pre-texture original")
    }
}
