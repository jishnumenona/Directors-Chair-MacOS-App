// DirectorsChairViewsTests/VisionBoardAbsorbTests.swift
//
// The Wall, pass 1 — "the board absorbs; it never asks."
//
// The capture path used to be a 6-action trip through a modal with nine
// card types and ~25 fields. These tests pin the replacement: one gesture
// (drop, paste, or a dragged word) puts a scrap on the wall, carrying only
// what the payload itself gave us — no title, no department, no type
// decision — and several at once land as a loose pile, never a grid.

import AppKit
import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

// MARK: - Classification

final class VisionBoardAbsorbClassifyTests: XCTestCase {

    func testTextIsAWordUnlessItPointsAtAPicture() {
        XCTAssertEqual(VisionBoardAbsorb.classify(text: "shoot what is"),
                       .text("shoot what is"))
        XCTAssertEqual(VisionBoardAbsorb.classify(text: "  dusk  "),
                       .text("dusk"), "trimmed, still a word")
        XCTAssertEqual(
            VisionBoardAbsorb.classify(text: "https://example.com/still.jpg"),
            .remoteURL(URL(string: "https://example.com/still.jpg")!))
        XCTAssertEqual(
            VisionBoardAbsorb.classify(text: "example.com/frames/a.png"),
            .remoteURL(URL(string: "https://example.com/frames/a.png")!),
            "people copy image URLs without the scheme")
        XCTAssertEqual(
            VisionBoardAbsorb.classify(text: "https://example.com/article"),
            .text("https://example.com/article"),
            "a link that isn't a picture is still a thought worth pinning")
    }

    func testOnlyImageFilesBecomeScraps() {
        XCTAssertEqual(
            VisionBoardAbsorb.payload(forFile: URL(fileURLWithPath: "/tmp/a.PNG")),
            .fileURL(URL(fileURLWithPath: "/tmp/a.PNG")), "extension case ignored")
        XCTAssertNil(VisionBoardAbsorb.payload(forFile: URL(fileURLWithPath: "/tmp/notes.txt")),
                     "a non-image file must not land as a broken tile")
    }

    // MARK: Scrap sizing — the wall is not a grid of squares

    func testScrapSizeKeepsThePicturesOwnProportions() {
        let landscape = VisionBoardAbsorb.scrapSize(aspectRatio: 16.0 / 9.0)
        XCTAssertEqual(landscape.width, 260)
        XCTAssertEqual(landscape.height, 146)

        let portrait = VisionBoardAbsorb.scrapSize(aspectRatio: 2.0 / 3.0)
        XCTAssertEqual(portrait.height, 260)
        XCTAssertEqual(portrait.width, 173)

        let unknown = VisionBoardAbsorb.scrapSize(aspectRatio: nil)
        XCTAssertEqual(unknown.width, unknown.height, "no ratio → a neutral square")

        let panorama = VisionBoardAbsorb.scrapSize(aspectRatio: 10)
        XCTAssertGreaterThanOrEqual(panorama.height, 110,
                                    "extreme ratios still arrive grabbable")
    }
}

// MARK: - Pasteboard (⌘V)

final class VisionBoardAbsorbPasteboardTests: XCTestCase {

    private func makePasteboard() -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name("dc.absorb.\(UUID().uuidString)"))
        board.clearContents()
        return board
    }

    func testPastedWordsBecomeAWordScrap() {
        let board = makePasteboard()
        board.setString("listening, not spectacle", forType: .string)
        XCTAssertEqual(VisionBoardAbsorb.payloads(from: board),
                       [.text("listening, not spectacle")])
    }

    func testPastedImageFilesBecomeScrapsAndOtherFilesAreIgnored() {
        let board = makePasteboard()
        board.writeObjects([URL(fileURLWithPath: "/tmp/frame.png") as NSURL,
                            URL(fileURLWithPath: "/tmp/notes.txt") as NSURL])
        XCTAssertEqual(VisionBoardAbsorb.payloads(from: board),
                       [.fileURL(URL(fileURLWithPath: "/tmp/frame.png"))])
    }

    func testPastedPixelsBecomeAnImagePayload() throws {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.systemTeal.drawSwatch(in: NSRect(x: 0, y: 0, width: 4, height: 4))
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)

        let board = makePasteboard()
        board.setData(tiff, forType: .tiff)

        guard case .imageData(let data)? = VisionBoardAbsorb.payloads(from: board).first
        else { return XCTFail("clipboard pixels must land as an image payload") }
        XCTAssertNotNil(NSBitmapImageRep(data: data), "decodable image bytes")
    }

    func testEmptyClipboardAbsorbsNothing() {
        XCTAssertTrue(VisionBoardAbsorb.payloads(from: makePasteboard()).isEmpty)
    }
}

// MARK: - Pile placement

final class VisionBoardPileTests: XCTestCase {

    func testFirstScrapLandsUnderTheCursorAndTheRestFanOut() {
        let sizes = Array(repeating: CGSize(width: 200, height: 100), count: 5)
        let origins = VisionCanvasGeometry.pileOrigins(
            sizes: sizes, around: CGPoint(x: 500, y: 400))

        XCTAssertEqual(origins[0], CGPoint(x: 400, y: 350),
                       "the first scrap is centred exactly where you let go")
        XCTAssertEqual(Set(origins.map(\.x)).count, origins.count,
                       "no two scraps share a column — this is a pile, not a grid")
        let distances = origins.dropFirst().map {
            hypot($0.x - origins[0].x, $0.y - origins[0].y)
        }
        XCTAssertEqual(distances, distances.sorted(),
                       "later scraps fan progressively outward")
    }

    func testPileIsDeterministic() {
        let sizes = Array(repeating: CGSize(width: 120, height: 120), count: 4)
        XCTAssertEqual(
            VisionCanvasGeometry.pileOrigins(sizes: sizes, around: .zero),
            VisionCanvasGeometry.pileOrigins(sizes: sizes, around: .zero),
            "same drop, same arrangement")
    }
}

// MARK: - The board absorbs

@MainActor
final class VisionBoardAbsorbViewModelTests: XCTestCase {

    private var projectBase: URL!
    private var viewModel: VisionBoardViewModel!

    override func setUp() async throws {
        try await super.setUp()
        projectBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("wall-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectBase,
                                                withIntermediateDirectories: true)
        viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: projectBase)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: projectBase)
        viewModel = nil
        projectBase = nil
        try await super.tearDown()
    }

    /// A real PNG on disk, outside the project.
    private func makeExternalImage(_ name: String = "still.png") throws -> URL {
        let image = NSImage(size: NSSize(width: 40, height: 20))
        image.lockFocus()
        NSColor.systemOrange.drawSwatch(in: NSRect(x: 0, y: 0, width: 40, height: 20))
        image.unlockFocus()
        let png = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation))?
            .representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name)")
        try png.write(to: url)
        return url
    }

    func testDroppedWordLandsAsAScrapWithNothingAsked() async {
        await viewModel.absorb([.text("shoot what is")],
                               at: CGPoint(x: 120, y: 80))

        XCTAssertEqual(viewModel.cards.count, 1)
        let scrap = viewModel.cards[0]
        XCTAssertEqual(scrap.cardType, VisionCardType.text.rawValue)
        XCTAssertEqual(scrap.text, "shoot what is")
        XCTAssertTrue(scrap.title.isEmpty, "capture never asks for a title")
        XCTAssertNil(scrap.department, "capture never asks for a department")
        XCTAssertEqual(scrap.boardId, viewModel.currentBoardId)
        XCTAssertNotNil(scrap.canvasX)
        XCTAssertNotNil(scrap.canvasY)
    }

    func testDroppedFileIsImportedIntoTheProjectAndSizedToItsPicture() async throws {
        let external = try makeExternalImage()

        await viewModel.absorb([.fileURL(external)], at: .zero)

        let scrap = try XCTUnwrap(viewModel.cards.first)
        let path = try XCTUnwrap(scrap.imagePath)
        XCTAssertTrue(path.hasPrefix("assets/visionboard/"),
                      "projects stay self-contained: \(path)")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectBase.appendingPathComponent(path).path))
        XCTAssertEqual(scrap.cardType, VisionCardType.image.rawValue)
        // 40×20 source → landscape scrap, never a forced square.
        XCTAssertEqual(try XCTUnwrap(scrap.canvasWidth) / XCTUnwrap(scrap.canvasHeight),
                       2, accuracy: 0.05)
    }

    func testPastedPixelsAreStagedAndFinalized() async throws {
        let data = try Data(contentsOf: try makeExternalImage())

        await viewModel.absorb([.imageData(data)], at: .zero)

        let path = try XCTUnwrap(viewModel.cards.first?.imagePath)
        XCTAssertTrue(path.hasPrefix("assets/visionboard/"), path)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectBase.appendingPathComponent(path).path))
    }

    func testSeveralDropsLandAsAPileAndBecomeTheSelection() async throws {
        let first = try makeExternalImage("a.png")
        let second = try makeExternalImage("b.png")

        let landed = await viewModel.absorb(
            [.fileURL(first), .text("dusk"), .fileURL(second)],
            at: CGPoint(x: 300, y: 200))

        XCTAssertEqual(landed.count, 3)
        XCTAssertEqual(viewModel.cards.count, 3)
        XCTAssertEqual(viewModel.selectedCardIds, Set(landed),
                       "what you just dropped is what's selected")
        let origins = viewModel.cards.map { CGPoint(x: $0.canvasX ?? 0, y: $0.canvasY ?? 0) }
        XCTAssertEqual(Set(origins.map(\.x)).count, 3, "a pile, not a stack")
        let zOrders = viewModel.cards.map(\.zOrder)
        XCTAssertEqual(zOrders, zOrders.sorted(), "later scraps sit on top")
    }

    func testAbsorbingNothingChangesNothing() async {
        var notified = false
        viewModel.onCardsChanged = { _ in notified = true }

        let landed = await viewModel.absorb([], at: .zero)

        XCTAssertTrue(landed.isEmpty)
        XCTAssertTrue(viewModel.cards.isEmpty)
        XCTAssertFalse(notified, "an empty drop must not dirty the project")
    }

    func testAbsorbNotifiesOnceSoTheProjectSavesTheWholePile() async throws {
        let image = try makeExternalImage()
        var notifications = 0
        viewModel.onCardsChanged = { _ in notifications += 1 }

        await viewModel.absorb([.fileURL(image), .text("dusk")], at: .zero)

        XCTAssertEqual(notifications, 1, "one commit for the whole gesture")
    }
}
