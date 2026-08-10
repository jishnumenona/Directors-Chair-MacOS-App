// DirectorsChairViewsTests/VisionImagineTests.swift
//
// The Imagine panel's request (DC-0034). What must stay true: the
// request can't ask the gateway for a shape it doesn't speak or a count
// that bills absurdly; several variations land as SIBLING scraps each
// keeping the prompt; and the held space matches the shape that was
// asked for, so the wall doesn't jump when the pictures arrive.

import XCTest
import SwiftUI
@testable import DirectorsChairViews
import DirectorsChairCore

@MainActor
final class VisionImagineTests: XCTestCase {

    // MARK: - Request validation

    func testUnknownRatiosAndWildCountsAreTamedAtConstruction() {
        let odd = ImagineRequest(prompt: "p", aspectRatio: "21:9",
                                 variationCount: 99)
        XCTAssertEqual(odd.aspectRatio, "16:9",
                       "a ratio the gateway doesn't speak becomes the "
                       + "default, never a wire error")
        XCTAssertEqual(odd.variationCount, ImagineRequest.maxVariations)
        XCTAssertEqual(ImagineRequest(prompt: "p", variationCount: 0)
            .variationCount, 1)
        XCTAssertEqual(ImagineRequest(prompt: "p", aspectRatio: "9:16")
            .aspectRatio, "9:16")
    }

    func testPlaceholderMatchesTheAskedShape() {
        let portrait = ImagineRequest(prompt: "p", aspectRatio: "9:16")
        XCTAssertGreaterThan(portrait.placeholderSize.height,
                             portrait.placeholderSize.width,
                             "a portrait ask holds portrait space")
        let square = ImagineRequest(prompt: "p", aspectRatio: "1:1")
        XCTAssertEqual(square.placeholderSize.width,
                       square.placeholderSize.height, accuracy: 0.001)
    }

    // MARK: - Variations on the wall

    private func makePNG(in base: URL) throws -> URL {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        let data = try XCTUnwrap(image.tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .png, properties: [:]) })
        let url = base.appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    func testVariationsLandAsSiblingScrapsEachKeepingThePrompt() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("VisionImagineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: base)
        let urls = try (0..<3).map { _ in try makePNG(in: base) }

        var receivedCount: Int?
        var heldPrompt: String?
        viewModel.onGenerateImage = { request, completion in
            receivedCount = request.variationCount
            heldPrompt = viewModel.pendingImagines.first?.prompt
            completion(urls)
        }

        await viewModel.imagine(
            ImagineRequest(prompt: "dawn over the harbour",
                           aspectRatio: "1:1", variationCount: 3),
            at: CGPoint(x: 400, y: 400))

        XCTAssertEqual(receivedCount, 3,
                       "the ask carries the count to the executor")
        XCTAssertEqual(heldPrompt, "dawn over the harbour ×3",
                       "the held sheet says how many are coming")
        XCTAssertEqual(viewModel.cards.count, 3,
                       "three variations, three sibling scraps")
        XCTAssertTrue(viewModel.cards.allSatisfy {
            $0.description == "dawn over the harbour"
        }, "every sibling keeps the prompt that made it")
        XCTAssertTrue(viewModel.pendingImagines.isEmpty)

        let origins = Set(viewModel.cards.map {
            "\(Int($0.canvasX ?? 0)),\(Int($0.canvasY ?? 0))"
        })
        XCTAssertEqual(origins.count, 3,
                       "siblings scatter — a stack of three identical "
                       + "positions would hide two of them")
    }

    func testEmptyResultGivesTheSpaceBackWithoutScraps() async {
        let viewModel = VisionBoardViewModel()
        viewModel.onGenerateImage = { _, completion in completion([]) }
        await viewModel.imagine(
            ImagineRequest(prompt: "impossible", variationCount: 4),
            at: .zero)
        XCTAssertTrue(viewModel.pendingImagines.isEmpty)
        XCTAssertTrue(viewModel.cards.isEmpty)
    }
}
