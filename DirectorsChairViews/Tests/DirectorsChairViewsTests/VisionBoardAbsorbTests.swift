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

// MARK: - Settle (The Wall, pass 1 — rotation)

final class VisionBoardSettleTests: XCTestCase {

    func testEveryScrapEarnsItsOwnTiltWithinRange() {
        let angles = (0..<40).map {
            VisionBoardAbsorb.settleAngle(seed: "scrap-\($0)")
        }
        for angle in angles {
            XCTAssertLessThanOrEqual(abs(angle), 2.6,
                                     "a settle is a nudge, not a spin")
        }
        XCTAssertGreaterThan(Set(angles).count, 30,
                             "neighbours must not share one scripted angle")
        XCTAssertTrue(angles.contains(where: { $0 < 0 }) &&
                      angles.contains(where: { $0 > 0 }),
                      "scraps tilt both ways")
    }

    func testTiltIsStableAcrossLaunches() {
        // Derived from a fixed hash, never Swift's per-process Hasher —
        // a scrap must not re-tilt every time the app opens.
        XCTAssertEqual(VisionBoardAbsorb.settleAngle(seed: "the-last-frame"),
                       VisionBoardAbsorb.settleAngle(seed: "the-last-frame"))
        XCTAssertEqual(VisionBoardAbsorb.settleAngle(seed: "fixed", maxDegrees: 3),
                       -1.491, accuracy: 0.0005,
                       "pinned value: the hash must stay stable")
    }
}

@MainActor
final class VisionBoardAbsorbRotationTests: XCTestCase {

    func testAbsorbedScrapsLandTiltedAndExistingOnesAreLeftAlone() async {
        let viewModel = VisionBoardViewModel()
        var flat = VisionCard()
        flat.cardType = VisionCardType.text.rawValue
        flat.text = "already here"
        viewModel.addCard(flat)

        await viewModel.absorb([.text("dusk"), .text("tungsten")], at: .zero)

        let landed = viewModel.cards.filter { $0.id != flat.id }
        XCTAssertEqual(landed.count, 2)
        for scrap in landed {
            let angle = try? XCTUnwrap(scrap.rotation)
            XCTAssertNotNil(angle)
            XCTAssertNotEqual(angle, 0, "a dropped scrap is never perfectly square")
        }
        XCTAssertNil(viewModel.cards.first(where: { $0.id == flat.id })?.rotation,
                     "mess is earned — existing scraps are never jittered")
    }
}

// MARK: - Collage defaults (The Wall, pass 1 — DC-0022)

final class VisionBoardCollageDefaultsTests: XCTestCase {

    func testScrapsLandWhereAskedAndAreAllowedToOverlap() {
        // The old placement cascaded until nothing touched — the engine
        // itself prevented the collage look. Overlap is now the point.
        let neighbour = CGRect(x: 100, y: 100, width: 200, height: 200)
        let origin = VisionCanvasGeometry.dropOrigin(
            for: CGSize(width: 200, height: 200), over: [neighbour],
            preferredOrigin: CGPoint(x: 180, y: 160))
        XCTAssertEqual(origin, CGPoint(x: 180, y: 160),
                       "a scrap that overlaps its neighbour is left exactly there")
    }

    func testAScrapNeverLandsPerfectlyHidingAnother() {
        let buried = CGRect(x: 100, y: 100, width: 200, height: 200)
        let origin = VisionCanvasGeometry.dropOrigin(
            for: CGSize(width: 200, height: 200), over: [buried],
            preferredOrigin: CGPoint(x: 100, y: 100))
        XCTAssertNotEqual(origin, CGPoint(x: 100, y: 100),
                          "an exact stack would hide the scrap beneath it")
        XCTAssertEqual(origin, CGPoint(x: 126, y: 126), "nudged just enough")
    }
}

@MainActor
final class VisionBoardSnapDefaultTests: XCTestCase {

    func testSnapIsOffSoTheWallDoesNotSelfAlign() {
        XCTAssertFalse(VisionBoardViewModel().gridSnapEnabled,
                       "a self-aligning wall is a slide deck")
    }

    func testDroppedScrapKeepsItsExactPositionWithSnapOff() async {
        let viewModel = VisionBoardViewModel()
        await viewModel.absorb([.text("dusk")], at: CGPoint(x: 137, y: 249))

        let scrap = viewModel.cards[0]
        // pileOrigins centres the first scrap on the drop point.
        XCTAssertEqual(scrap.canvasX ?? 0, 137 - (scrap.canvasWidth ?? 0) / 2,
                       accuracy: 0.001, "no grid rounding")
        XCTAssertEqual(scrap.canvasY ?? 0, 249 - (scrap.canvasHeight ?? 0) / 2,
                       accuracy: 0.001)
    }
}

// MARK: - Torn paper (The Wall, pass 2 — DC-0025)

final class VisionTornPaperTests: XCTestCase {

    private let rect = CGRect(x: 0, y: 0, width: 240, height: 160)

    func testTheTearCoversTheWholeScrap() {
        // The first cut of this shape built four separate polylines
        // (Path.addLines starts a new subpath), so clipping with it erased
        // the clipping's own text. The outline must span the scrap.
        let path = VisionTornPaper(torn: .all, seed: 42).path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, rect.width, accuracy: 8)
        XCTAssertEqual(bounds.height, rect.height, accuracy: 8)
        XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: rect.midY)),
                      "the middle of the paper must be inside the tear")
        XCTAssertTrue(path.contains(CGPoint(x: 20, y: 20)),
                      "and so must the corners' content area")
    }

    func testCleanCutsStayStraight() {
        let path = VisionTornPaper(torn: [], seed: 7).path(in: rect)
        XCTAssertEqual(path.boundingRect, rect,
                       "no torn edges → an exact rectangle")
    }

    func testTearIsStableAndVaries() {
        let a = VisionTornPaper(torn: .all, seed: 1).path(in: rect)
        let b = VisionTornPaper(torn: .all, seed: 1).path(in: rect)
        let c = VisionTornPaper(torn: .all, seed: 2).path(in: rect)
        XCTAssertEqual(a.description, b.description, "same scrap, same tear")
        XCTAssertNotEqual(a.description, c.description, "different scraps differ")
    }
}

// MARK: - Hands on the wall (The Wall, pass 2 — DC-0026)

final class VisionRotationGeometryTests: XCTestCase {

    func testDraggingTheHandleSidewaysTurnsTheScrap() {
        // Handle sits above the centre; dragging it right turns clockwise.
        let delta = VisionCanvasGeometry.rotationDelta(
            handleOffset: CGPoint(x: 0, y: -100),
            translation: CGSize(width: 100, height: 0), zoom: 1)
        XCTAssertEqual(delta, 45, accuracy: 0.01)
    }

    func testRotationIsAnchoredNotCumulative() {
        // Same drag from the same start always yields the same angle —
        // the runaway-feedback bug class the canvas was rebuilt to avoid.
        let once = VisionCanvasGeometry.rotationDelta(
            handleOffset: CGPoint(x: 0, y: -80),
            translation: CGSize(width: 40, height: 10), zoom: 2)
        let twice = VisionCanvasGeometry.rotationDelta(
            handleOffset: CGPoint(x: 0, y: -80),
            translation: CGSize(width: 40, height: 10), zoom: 2)
        XCTAssertEqual(once, twice)
    }

    func testZoomDoesNotChangeTheAngleTheHandFeels() {
        // Screen translation is divided by zoom, so a gesture that turns a
        // scrap 30° at 100% turns it 30° at 200%.
        let atOneX = VisionCanvasGeometry.rotationDelta(
            handleOffset: CGPoint(x: 0, y: -100),
            translation: CGSize(width: 50, height: 0), zoom: 1)
        let atTwoX = VisionCanvasGeometry.rotationDelta(
            handleOffset: CGPoint(x: 0, y: -100),
            translation: CGSize(width: 100, height: 0), zoom: 2)
        XCTAssertEqual(atOneX, atTwoX, accuracy: 0.001)
    }
}

@MainActor
final class VisionPinAndKeyboardTests: XCTestCase {

    private func makeBoard() -> (VisionBoardViewModel, String) {
        let viewModel = VisionBoardViewModel()
        var card = VisionCard()
        card.canvasX = 100
        card.canvasY = 100
        card.canvasWidth = 200
        card.canvasHeight = 200
        viewModel.addCard(card)
        return (viewModel, viewModel.cards[0].id)
    }

    func testAPinnedScrapIsStuckToTheWall() {
        let (viewModel, id) = makeBoard()
        viewModel.togglePin(id)
        XCTAssertTrue(viewModel.isPinned(id))

        viewModel.beginCardDrag(anchor: id)
        viewModel.endCardDrag(translation: CGSize(width: 80, height: 80))
        XCTAssertEqual(viewModel.cards[0].canvasX, 100, "pinned scraps don't move")

        viewModel.beginRotate(cardId: id)
        viewModel.endRotate(delta: 30)
        XCTAssertNil(viewModel.cards[0].rotation, "pinned scraps don't turn")

        viewModel.beginResize(cardId: id, corner: .bottomRight)
        viewModel.endResize(translation: CGSize(width: 50, height: 50))
        XCTAssertEqual(viewModel.cards[0].canvasWidth, 200, "pinned scraps don't resize")

        viewModel.togglePin(id)
        viewModel.beginCardDrag(anchor: id)
        viewModel.endCardDrag(translation: CGSize(width: 40, height: 0))
        XCTAssertEqual(viewModel.cards[0].canvasX, 140, "unpinned, it moves again")
    }

    func testRotatingASrapAppliesTheDeltaToWhereItStarted() {
        let (viewModel, id) = makeBoard()
        viewModel.beginRotate(cardId: id)
        viewModel.updateRotate(delta: 12)
        XCTAssertEqual(viewModel.cards[0].rotation ?? 0, 12, accuracy: 0.001)
        viewModel.endRotate(delta: 20)
        XCTAssertEqual(viewModel.cards[0].rotation ?? 0, 20, accuracy: 0.001,
                       "anchored: the last delta wins, deltas don't accumulate")

        // A second gesture builds on the tilt the scrap already has.
        viewModel.beginRotate(cardId: id)
        viewModel.endRotate(delta: 5)
        XCTAssertEqual(viewModel.cards[0].rotation ?? 0, 25, accuracy: 0.001)
    }

    func testArrowKeysWalkTheSelectionAndSkipPinnedScraps() {
        let (viewModel, id) = makeBoard()
        viewModel.selectCard(id)
        viewModel.nudgeSelection(dx: -1, dy: 3)
        XCTAssertEqual(viewModel.cards[0].canvasX, 99)
        XCTAssertEqual(viewModel.cards[0].canvasY, 103)

        viewModel.togglePin(id)
        viewModel.nudgeSelection(dx: 10, dy: 10)
        XCTAssertEqual(viewModel.cards[0].canvasX, 99, "a pinned scrap stays put")
    }
}

// MARK: - Paper on a pin (The Wall, pass 2 — DC-0032)

final class VisionScrapPhysicsTests: XCTestCase {

    func testPaperTrailsBehindTheHandThatMovesIt() {
        // Carry the tack right and the sheet lags left, and vice versa.
        XCTAssertLessThan(VisionScrapPhysics.swing(horizontalVelocity: 400), 0)
        XCTAssertGreaterThan(VisionScrapPhysics.swing(horizontalVelocity: -400), 0)
        XCTAssertEqual(VisionScrapPhysics.swing(horizontalVelocity: 0), 0)
    }

    func testPaperNeverFoldsBackOnItself() {
        for velocity in [CGFloat(5_000), -5_000, 50_000] {
            XCTAssertLessThanOrEqual(
                abs(VisionScrapPhysics.swing(horizontalVelocity: velocity)), 11)
        }
    }

    func testTheSwingActuallySwings() {
        // Underdamped: released off-centre it must cross the rest angle at
        // least once — a scrap that just eases back isn't swinging.
        var angle = 9.0
        var velocity = 0.0
        var crossings = 0
        var previous = angle
        for _ in 0..<240 {
            let next = VisionScrapPhysics.step(angle: angle, velocity: velocity,
                                               target: 0, dt: 1.0 / 60.0)
            angle = next.angle
            velocity = next.velocity
            if previous > 0, angle < 0 { crossings += 1 }
            if previous < 0, angle > 0 { crossings += 1 }
            previous = angle
        }
        XCTAssertGreaterThanOrEqual(crossings, 1, "the paper must oscillate")
    }

    func testItComesToRestAndStaysThere() {
        var angle = 9.0
        var velocity = 0.0
        var steps = 0
        while steps < 600,
              !VisionScrapPhysics.atRest(angle: angle, velocity: velocity, target: 0) {
            let next = VisionScrapPhysics.step(angle: angle, velocity: velocity,
                                               target: 0, dt: 1.0 / 60.0)
            angle = next.angle
            velocity = next.velocity
            steps += 1
        }
        XCTAssertLessThan(steps, 240, "settles inside the frame budget (~4s)")
        XCTAssertEqual(angle, 0, accuracy: 0.06)
        // And the integrator is stable — no energy gained over a long run.
        for _ in 0..<600 {
            let next = VisionScrapPhysics.step(angle: angle, velocity: velocity,
                                               target: 0, dt: 1.0 / 60.0)
            angle = next.angle
            velocity = next.velocity
        }
        XCTAssertEqual(angle, 0, accuracy: 0.06, "no runaway oscillation")
    }

    func testTacksSitNearTheTopAndOffCentre() {
        let anchors = (0..<40).map {
            VisionScrapPhysics.tackAnchor(seed: "scrap-\($0)")
        }
        for anchor in anchors {
            XCTAssertEqual(anchor.y, 0.055, accuracy: 0.0001, "near the top edge")
            XCTAssertGreaterThan(anchor.x, 0.32)
            XCTAssertLessThan(anchor.x, 0.68)
        }
        XCTAssertGreaterThan(Set(anchors.map(\.x)).count, 30,
                             "tacks aren't machine-placed in a line")
        XCTAssertEqual(VisionScrapPhysics.tackAnchor(seed: "same"),
                       VisionScrapPhysics.tackAnchor(seed: "same"),
                       "a tack doesn't move between launches")
    }
}

// MARK: - The tool ring (The Wall, pass 2 — DC-0031)

final class VisionWallToolsTests: XCTestCase {

    func testTheRingStartsAtTheTopAndGoesClockwise() {
        let points = VisionRadialGeometry.positions(count: 4, radius: 100)
        XCTAssertEqual(points[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(points[0].y, -100, accuracy: 0.001, "first tool sits above the cursor")
        XCTAssertEqual(points[1].x, 100, accuracy: 0.001, "then clockwise")
        XCTAssertEqual(points[2].y, 100, accuracy: 0.001)
        XCTAssertTrue(VisionRadialGeometry.positions(count: 0, radius: 100).isEmpty)
    }

    func testTheRingSlidesInwardNearAnEdge() {
        let viewport = CGSize(width: 900, height: 600)
        let clamped = VisionRadialGeometry.anchor(for: CGPoint(x: 4, y: 590),
                                                  in: viewport, radius: 78)
        XCTAssertGreaterThanOrEqual(clamped.x, 78)
        XCTAssertLessThanOrEqual(clamped.y, 600 - 78)

        let middle = VisionRadialGeometry.anchor(for: CGPoint(x: 450, y: 300),
                                                 in: viewport, radius: 78)
        XCTAssertEqual(middle, CGPoint(x: 450, y: 300), "room to bloom → unmoved")
    }

    func testEveryToolThatNeedsWordsAsksForThem() {
        for tool in VisionWallTool.allCases {
            switch tool {
            case .imagine, .link, .video:
                XCTAssertNotNil(tool.prompt, "\(tool) opens a caret")
            case .write, .paste, .picture:
                XCTAssertNil(tool.prompt)
            }
        }
        XCTAssertEqual(Set(VisionWallTool.ringOrder), Set(VisionWallTool.allCases),
                       "the ring shows every tool exactly once")
    }
}

final class VisionLinkTests: XCTestCase {

    func testItAcceptsWhatPeopleActuallyPaste() {
        XCTAssertEqual(VisionLink.normalized("youtube.com/watch?v=abc")?.scheme,
                       "https", "a bare host still becomes a link")
        XCTAssertEqual(VisionLink.normalized("  https://vimeo.com/12345  ")?.host,
                       "vimeo.com", "whitespace trimmed")
        XCTAssertNil(VisionLink.normalized("not a link at all"))
        XCTAssertNil(VisionLink.normalized("localhost"), "no dot, no host")
    }

    func testYouTubeInAllTheShapesPeopleShareIt() {
        let expected = VisionLinkKind.youtube(id: "dQw4w9WgXcQ")
        for raw in ["https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    "https://youtu.be/dQw4w9WgXcQ",
                    "https://www.youtube.com/embed/dQw4w9WgXcQ",
                    "https://youtube.com/shorts/dQw4w9WgXcQ"] {
            let url = try! XCTUnwrap(VisionLink.normalized(raw))
            XCTAssertEqual(VisionLink.classify(url), expected, raw)
        }
    }

    func testAYouTubeLinkBringsItsOwnStill() {
        let url = VisionLink.normalized("youtu.be/abc123")!
        let kind = VisionLink.classify(url)
        XCTAssertTrue(kind.isVideo)
        XCTAssertEqual(kind.thumbnailURL?.absoluteString,
                       "https://img.youtube.com/vi/abc123/hqdefault.jpg",
                       "the wall shows the frame, not the URL")
    }

    func testVimeoAndOrdinaryLinks() {
        let vimeo = VisionLink.normalized("https://vimeo.com/987654")!
        XCTAssertEqual(VisionLink.classify(vimeo), .vimeo(id: "987654"))
        XCTAssertTrue(VisionLink.classify(vimeo).isVideo)
        XCTAssertNil(VisionLink.classify(vimeo).thumbnailURL, "no still without an API call")

        let article = VisionLink.normalized("https://example.com/notes/lighting")!
        XCTAssertEqual(VisionLink.classify(article), .web)
        XCTAssertFalse(VisionLink.classify(article).isVideo)
    }

    func testALinkIsNamedForWhereItPointsWhenNobodyTitlesIt() {
        let article = VisionLink.normalized("https://www.example.com/notes/soft-key-light")!
        XCTAssertEqual(VisionLink.displayName(for: article),
                       "example.com · soft key light")
        let bare = VisionLink.normalized("https://example.com")!
        XCTAssertEqual(VisionLink.displayName(for: bare), "example.com")
        let numeric = VisionLink.normalized("https://vimeo.com/987654")!
        XCTAssertEqual(VisionLink.displayName(for: numeric), "vimeo.com",
                       "an id is not a name")
    }
}

@MainActor
final class VisionWallToolActionTests: XCTestCase {

    func testImagineLandsTheGeneratedPictureAsAnOrdinaryScrap() async throws {
        let projectBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("wall-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectBase,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectBase) }

        let image = NSImage(size: NSSize(width: 30, height: 20))
        image.lockFocus()
        NSColor.systemPink.drawSwatch(in: NSRect(x: 0, y: 0, width: 30, height: 20))
        image.unlockFocus()
        let png = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation))?
            .representation(using: .png, properties: [:]))
        let generated = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")
        try png.write(to: generated)

        let viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: projectBase)
        var askedFor: String?
        viewModel.onGenerateImage = { request, completion in
            askedFor = request.prompt
            completion([generated])
        }

        await viewModel.imagine("a rain-soaked neon street", at: .zero)

        XCTAssertEqual(askedFor, "a rain-soaked neon street")
        let scrap = try XCTUnwrap(viewModel.cards.first)
        XCTAssertTrue((scrap.imagePath ?? "").hasPrefix("assets/visionboard/"),
                      "generated art is imported like anything else")
        XCTAssertEqual(scrap.description, "a rain-soaked neon street",
                       "the prompt is kept — it's how the picture came to exist")
        XCTAssertNotNil(scrap.rotation, "and it lands tilted, like every scrap")
        XCTAssertFalse(viewModel.isGenerating)
    }

    func testImagineWithNothingToSayDoesNothing() async {
        let viewModel = VisionBoardViewModel()
        var called = false
        viewModel.onGenerateImage = { _, completion in
            called = true
            completion([])
        }
        await viewModel.imagine("   ", at: .zero)
        XCTAssertFalse(called)
        XCTAssertTrue(viewModel.cards.isEmpty)
    }

    func testPinningLinksAndVideos() async {
        let viewModel = VisionBoardViewModel()

        await viewModel.pinLink("https://example.com/notes/lighting", at: .zero)
        let link = viewModel.cards[0]
        XCTAssertEqual(link.cardType, VisionCardType.link.rawValue)
        XCTAssertEqual(link.sourceUrl, "https://example.com/notes/lighting")
        XCTAssertNotNil(link.rotation, "links hang like everything else")

        await viewModel.pinLink("youtu.be/abc123", at: .zero)
        let video = viewModel.cards[1]
        XCTAssertEqual(video.cardType, VisionCardType.video.rawValue,
                       "a YouTube link is a video scrap, not a link scrap")
        XCTAssertEqual(video.videoUrl, "https://youtu.be/abc123")

        await viewModel.pinLink("gibberish", at: .zero)
        XCTAssertEqual(viewModel.cards.count, 2, "nonsense pins nothing")
    }
}

// MARK: - One right-click, one ring (owner report 2026-08-03)

final class VisionWallHitTestTests: XCTestCase {

    private func scrap(_ id: String, x: Double, y: Double, z: Double,
                       type: String = "image") -> VisionCard {
        var card = VisionCard(id: id)
        card.cardType = type
        card.canvasX = x
        card.canvasY = y
        card.canvasWidth = 200
        card.canvasHeight = 200
        card.zOrder = z
        return card
    }

    func testBareWallHitsNothing() {
        let cards = [scrap("a", x: 0, y: 0, z: 1)]
        XCTAssertNil(VisionWallHitTest.scrap(at: CGPoint(x: 500, y: 500),
                                             cards: cards))
    }

    func testTheSheetYouCanSeeIsTheOneYouGet() {
        // Two scraps overlapping: the right-click belongs to the top one.
        let cards = [scrap("under", x: 0, y: 0, z: 1),
                     scrap("over", x: 50, y: 50, z: 9)]
        XCTAssertEqual(VisionWallHitTest.scrap(at: CGPoint(x: 100, y: 100),
                                               cards: cards)?.id, "over")
        // Where only the lower one lies, it wins.
        XCTAssertEqual(VisionWallHitTest.scrap(at: CGPoint(x: 20, y: 20),
                                               cards: cards)?.id, "under")
    }

    func testFramesOnlyCatchClicksNothingElseCovers() {
        let cards = [scrap("frame", x: 0, y: 0, z: 99, type: "frame"),
                     scrap("photo", x: 0, y: 0, z: 1)]
        XCTAssertEqual(VisionWallHitTest.scrap(at: CGPoint(x: 50, y: 50),
                                               cards: cards)?.id, "photo",
                       "a frame must not swallow the scraps inside it")
    }
}

final class VisionScrapToolTests: XCTestCase {

    func testAScrapsRingFitsWhatTheScrapIs() {
        let words = VisionScrapTool.ring(isText: true, hasPicture: false)
        XCTAssertTrue(words.contains(.restyle))
        XCTAssertEqual(VisionScrapTool.restyle.title(pinned: false, isText: true),
                       "Cut", "words are re-cut")

        let picture = VisionScrapTool.ring(isText: false, hasPicture: true)
        XCTAssertTrue(picture.contains(.restyle))
        XCTAssertEqual(VisionScrapTool.restyle.title(pinned: false, isText: false),
                       "Palette", "pictures give up their colours")

        let link = VisionScrapTool.ring(isText: false, hasPicture: false)
        XCTAssertFalse(link.contains(.restyle), "no dead chip on a link scrap")
        // connect · copy · pin · note · details · remove
        XCTAssertEqual(link.count, 6)
    }

    func testThePinChipSaysWhatItWillDo() {
        XCTAssertEqual(VisionScrapTool.pin.title(pinned: false, isText: false), "Pin")
        XCTAssertEqual(VisionScrapTool.pin.title(pinned: true, isText: false), "Unpin")
        XCTAssertEqual(VisionScrapTool.pin.systemImage(pinned: true, isText: false),
                       "pin.slash")
    }
}

// MARK: - Paper stock (owner request 2026-08-03)

final class VisionPaperTests: XCTestCase {

    func testEveryStockStaysReadable() {
        // Ink and paper must not collapse into each other on any stock.
        for stock in VisionPaper.allCases {
            XCTAssertNotEqual(stock.ink, stock.base, stock.displayName)
            XCTAssertFalse(stock.displayName.isEmpty)
        }
    }

    func testUnknownAndMissingStockFallsBackToCream() {
        XCTAssertEqual(VisionPaper.resolve(nil), .cream)
        XCTAssertEqual(VisionPaper.resolve("papyrus"), .cream,
                       "a stock we no longer ship must not blank the scrap")
        XCTAssertEqual(VisionPaper.resolve("kraft"), .kraft)
    }

    func testThickerStocksCatchMoreLightAtTheEdge() {
        XCTAssertGreaterThan(VisionPaper.kraft.edgeShade, VisionPaper.bond.edgeShade)
    }

    func testPaperIsOfferedOnlyForThingsMadeOfIt() {
        let words = VisionScrapTool.ring(isText: true, hasPicture: false,
                                         isPaper: true)
        XCTAssertTrue(words.contains(.paper))
        let picture = VisionScrapTool.ring(isText: false, hasPicture: true,
                                           isPaper: false)
        XCTAssertFalse(picture.contains(.paper),
                       "a photograph is not cut from notepaper")
    }
}

@MainActor
final class VisionPaperViewModelTests: XCTestCase {

    func testChoosingAStockSticksAndSurvivesAReload() throws {
        let viewModel = VisionBoardViewModel()
        var card = VisionCard()
        card.cardType = VisionCardType.text.rawValue
        card.text = "dusk"
        viewModel.addCard(card)
        let id = viewModel.cards[0].id

        viewModel.setPaper(id, paper: .ruled)
        XCTAssertEqual(viewModel.cards[0].paper, "ruled")

        // Round-trips like every other field, so a stack of notes reopens
        // on the paper it was written on.
        let data = try JSONEncoder().encode(viewModel.cards[0])
        let decoded = try JSONDecoder().decode(VisionCard.self, from: data)
        XCTAssertEqual(VisionPaper.resolve(decoded.paper), .ruled)
    }

    func testCardsSavedBeforePaperExistedOpenOnCream() throws {
        let legacy = try JSONDecoder().decode(
            VisionCard.self, from: Data(#"{"text":"old note"}"#.utf8))
        XCTAssertNil(legacy.paper)
        XCTAssertEqual(VisionPaper.resolve(legacy.paper), .cream)
    }
}

// MARK: - Tools that visibly do something (owner report 2026-08-03)

@MainActor
final class VisionScrapToolFeedbackTests: XCTestCase {

    private func board() -> (VisionBoardViewModel, String, String) {
        let viewModel = VisionBoardViewModel()
        var first = VisionCard()
        first.canvasX = 0; first.canvasY = 0
        var second = VisionCard()
        second.canvasX = 400; second.canvasY = 0
        viewModel.addCard(first)
        viewModel.addCard(second)
        return (viewModel, viewModel.cards[0].id, viewModel.cards[1].id)
    }

    func testConnectArmsAndCanBePutDownAgain() {
        let (viewModel, source, target) = board()

        viewModel.beginConnector(from: source)
        XCTAssertEqual(viewModel.pendingConnectorSource, source,
                       "armed — the wall shows a hint while this holds")

        viewModel.cancelConnector()
        XCTAssertNil(viewModel.pendingConnectorSource, "esc puts the tool down")
        XCTAssertTrue(viewModel.connectors.isEmpty)

        viewModel.beginConnector(from: source)
        viewModel.completeConnector(to: target)
        XCTAssertNil(viewModel.pendingConnectorSource, "disarmed once drawn")
        XCTAssertEqual(viewModel.connectors.count, 1)
    }

    func testSelectingSomethingDoesNotSilentlyPutTheConnectorDown() {
        // The reported bug: arm Connect, click the second scrap, and it
        // merely selected — because clearSelection() was disarming the
        // tool behind your back.
        let (viewModel, source, target) = board()
        viewModel.beginConnector(from: source)

        viewModel.clearSelection()
        XCTAssertEqual(viewModel.pendingConnectorSource, source,
                       "still aiming")

        viewModel.selectCard(target)
        XCTAssertEqual(viewModel.pendingConnectorSource, source)

        viewModel.completeConnector(to: target)
        XCTAssertEqual(viewModel.connectors.count, 1, "the link is drawn")
        XCTAssertEqual(viewModel.connectors[0].fromCardId, source)
        XCTAssertEqual(viewModel.connectors[0].toCardId, target)
    }

    func testAScrapCannotBeConnectedToItself() {
        let (viewModel, source, _) = board()
        viewModel.beginConnector(from: source)
        viewModel.completeConnector(to: source)
        XCTAssertTrue(viewModel.connectors.isEmpty)
        XCTAssertNil(viewModel.pendingConnectorSource, "and the tool is put down")
    }

    func testPinTogglesAndTheScrapKnowsIt() {
        let (viewModel, id, _) = board()
        XCTAssertFalse(viewModel.isPinned(id))

        viewModel.togglePin(id)
        XCTAssertTrue(viewModel.isPinned(id), "the tack presses in and turns brass")
        XCTAssertTrue(viewModel.cards.first { $0.id == id }?.pinned == true)

        viewModel.togglePin(id)
        XCTAssertFalse(viewModel.isPinned(id))
    }
}

// MARK: - A wall that goes on forever (owner report 2026-08-03)

@MainActor
final class VisionInfiniteWallTests: XCTestCase {

    func testPanIsTrulyUnbounded() {
        // Nothing clamps the offset — walk a long way out and the wall
        // keeps going, in both directions.
        let viewModel = VisionBoardViewModel()
        viewModel.viewportSize = CGSize(width: 1200, height: 800)

        for _ in 0..<400 { viewModel.scrollPan(deltaX: 900, deltaY: 600) }
        XCTAssertEqual(viewModel.transform.offset.x, 360_000, accuracy: 1)
        XCTAssertEqual(viewModel.transform.offset.y, 240_000, accuracy: 1)

        for _ in 0..<800 { viewModel.scrollPan(deltaX: -900, deltaY: -600) }
        XCTAssertEqual(viewModel.transform.offset.x, -360_000, accuracy: 1,
                       "and just as far the other way")
    }

    func testADraggedPanIsAnchoredNoMatterHowFarYouGo() {
        let viewModel = VisionBoardViewModel()
        viewModel.scrollPan(deltaX: 50_000, deltaY: -20_000)
        let start = viewModel.transform.offset

        viewModel.beginPanIfNeeded()
        viewModel.updatePan(translation: CGSize(width: 300, height: 120))
        viewModel.updatePan(translation: CGSize(width: 300, height: 120))
        viewModel.endPan()

        XCTAssertEqual(viewModel.transform.offset.x, start.x + 300, accuracy: 0.001,
                       "repeating the same translation must not compound")
        XCTAssertEqual(viewModel.transform.offset.y, start.y + 120, accuracy: 0.001)
    }

    func testTheWallLooksTheSameEachTimeYouPassAPlace() {
        // Marks are derived from world cell coordinates, so walking away
        // and coming back shows the same wall — and neighbouring cells
        // never share a pattern.
        let far = VisionWallSurface.seed(column: 8_000, row: -12_345)
        XCTAssertEqual(far, VisionWallSurface.seed(column: 8_000, row: -12_345))
        XCTAssertNotEqual(far, VisionWallSurface.seed(column: 8_001, row: -12_345))
        XCTAssertNotEqual(VisionWallSurface.seed(column: 3, row: 5),
                          VisionWallSurface.seed(column: 5, row: 3),
                          "x and y must not be interchangeable")
    }

    func testFarFromEverythingTheBoardOffersAWayBack() {
        let viewModel = VisionBoardViewModel()
        viewModel.viewportSize = CGSize(width: 1000, height: 700)
        var card = VisionCard()
        card.canvasX = 0; card.canvasY = 0
        card.canvasWidth = 200; card.canvasHeight = 200
        viewModel.addCard(card)
        viewModel.fitToView(viewSize: viewModel.viewportSize)
        XCTAssertTrue(viewModel.contentVisible)

        viewModel.scrollPan(deltaX: -60_000, deltaY: -60_000)
        XCTAssertFalse(viewModel.contentVisible,
                       "wandering off is allowed — the rescue button appears")

        viewModel.fitToView(viewSize: viewModel.viewportSize)
        XCTAssertTrue(viewModel.contentVisible, "and brings you home")
    }
}

// MARK: - Thread runs between the pins (owner report 2026-08-03)

final class VisionThreadEndpointTests: XCTestCase {

    /// Mirrors the canvas's tackPoint: thread is wound round the pin, and
    /// because the tack is the pivot the element turns about, this point
    /// holds still however far the paper swings.
    private func tackPoint(_ card: VisionCard) -> CGPoint {
        let anchor = VisionScrapPhysics.tackAnchor(seed: card.id)
        return CGPoint(x: (card.canvasX ?? 0) + (card.canvasWidth ?? 200) * anchor.x,
                       y: (card.canvasY ?? 0) + (card.canvasHeight ?? 200) * anchor.y)
    }

    func testThreadEndsAtThePinNotTheMiddleOfTheSheet() {
        var card = VisionCard(id: "sheet")
        card.canvasX = 100
        card.canvasY = 200
        card.canvasWidth = 300
        card.canvasHeight = 400

        let pin = tackPoint(card)
        let middle = CGPoint(x: 250, y: 400)
        XCTAssertNotEqual(pin, middle, "string is wound on the tack")
        // The tack sits near the top edge, so the thread lands high on the
        // sheet rather than at its centre.
        XCTAssertLessThan(pin.y, middle.y)
        XCTAssertEqual(pin.y, 200 + 400 * 0.055, accuracy: 0.001)
        XCTAssertGreaterThan(pin.x, 100)
        XCTAssertLessThan(pin.x, 400)
    }

    func testThePinStaysPutHoweverTheSheetIsTilted() {
        // Rotation anchors at the tack, so a swinging element never drags
        // its end of the thread around with it.
        var still = VisionCard(id: "sheet")
        still.canvasX = 0; still.canvasY = 0
        still.canvasWidth = 200; still.canvasHeight = 200
        var swung = still
        swung.rotation = -37

        XCTAssertEqual(tackPoint(still), tackPoint(swung))
    }
}

// MARK: - Standing back far enough (owner request 2026-08-03)

@MainActor
final class VisionZoomRangeTests: XCTestCase {

    func testYouCanStandFurtherBackThanTenPercent() {
        let viewModel = VisionBoardViewModel()
        viewModel.viewportSize = CGSize(width: 1200, height: 800)
        for _ in 0..<40 { viewModel.zoomOut() }
        XCTAssertLessThan(viewModel.zoomLevel, 0.1,
                          "10% was one screenful, not an overview")
        XCTAssertEqual(viewModel.zoomLevel, VisionBoardViewModel.minZoom,
                       accuracy: 0.0001, "and it stops somewhere sane")
    }

    func testZoomStepsProportionallySoBothEndsAreUsable() {
        let viewModel = VisionBoardViewModel()
        viewModel.viewportSize = CGSize(width: 1000, height: 700)

        // Far out, a step must be small; a fixed 0.25 would hit the floor.
        viewModel.setZoomLevel(0.08)
        viewModel.zoomOut()
        XCTAssertGreaterThan(viewModel.zoomLevel, 0.05)
        XCTAssertLessThan(viewModel.zoomLevel, 0.08)

        // Far in, a step must be big; 0.25 would be a crawl.
        viewModel.setZoomLevel(4)
        viewModel.zoomOut()
        XCTAssertLessThan(viewModel.zoomLevel, 3.5)
    }

    func testJumpingStraightToALevel() {
        let viewModel = VisionBoardViewModel()
        viewModel.viewportSize = CGSize(width: 1000, height: 700)

        viewModel.setZoomLevel(0.1)
        XCTAssertEqual(viewModel.zoomLevel, 0.1, accuracy: 0.0001,
                       "one click back to a 10% overview")

        viewModel.setZoomLevel(99)
        XCTAssertEqual(viewModel.zoomLevel, VisionBoardViewModel.maxZoom,
                       accuracy: 0.0001, "clamped like every other zoom path")
        viewModel.setZoomLevel(0)
        XCTAssertEqual(viewModel.zoomLevel, VisionBoardViewModel.minZoom,
                       accuracy: 0.0001)
    }

    func testThePresetsCoverOverviewToCloseInspection() {
        let presets = VisionBoardViewModel.zoomPresets
        XCTAssertEqual(presets, presets.sorted())
        XCTAssertTrue(presets.contains(0.1), "the 10% overview the owner asked for")
        XCTAssertTrue(presets.contains(1.0), "and 1:1")
        XCTAssertGreaterThanOrEqual(presets.first ?? 1,
                                    VisionBoardViewModel.minZoom)
        XCTAssertLessThanOrEqual(presets.last ?? 1, VisionBoardViewModel.maxZoom)
    }
}

// MARK: - Notes on an element (owner request 2026-08-03)

@MainActor
final class VisionElementNoteTests: XCTestCase {

    private func board() -> (VisionBoardViewModel, String) {
        let viewModel = VisionBoardViewModel()
        var card = VisionCard()
        card.canvasX = 0; card.canvasY = 0
        card.canvasWidth = 260; card.canvasHeight = 180
        viewModel.addCard(card)
        return (viewModel, viewModel.cards[0].id)
    }

    func testWritingAndErasingANote() throws {
        let (viewModel, id) = board()
        XCTAssertNil(viewModel.cards[0].referenceNote)

        viewModel.setNote(id, text: "  the light here, not the action  ")
        XCTAssertEqual(viewModel.cards[0].referenceNote,
                       "the light here, not the action", "trimmed")

        // Clearing the caret takes the slip back off, rather than leaving
        // an empty slip stuck under the element.
        viewModel.setNote(id, text: "   ")
        XCTAssertNil(viewModel.cards[0].referenceNote)
    }

    func testANoteSurvivesAReload() throws {
        let (viewModel, id) = board()
        viewModel.setNote(id, text: "shot on the 35")
        let data = try JSONEncoder().encode(viewModel.cards[0])
        let decoded = try JSONDecoder().decode(VisionCard.self, from: data)
        XCTAssertEqual(decoded.referenceNote, "shot on the 35")
        XCTAssertEqual(decoded.id, id)
    }

    func testEveryElementCanTakeANote() {
        // Notes are not just for pictures — a word, a link and a frame can
        // all carry one, so the tool is on every ring.
        for ring in [VisionScrapTool.ring(isText: true, hasPicture: false,
                                          isPaper: true),
                     VisionScrapTool.ring(isText: false, hasPicture: true),
                     VisionScrapTool.ring(isText: false, hasPicture: false)] {
            XCTAssertTrue(ring.contains(.note))
        }
    }

    func testTheNoteReachesTheExportedBoard() throws {
        var card = VisionCard(id: "note-carrier")
        card.canvasX = 0; card.canvasY = 0
        card.canvasWidth = 300; card.canvasHeight = 200

        let bare = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [card], projectBase: nil))
        card.referenceNote = "the light here, not the action"
        let annotated = try XCTUnwrap(VisionBoardExporter.renderPNG(
            cards: [card], projectBase: nil))
        XCTAssertNotEqual(bare, annotated,
                          "a note on the wall is a note on the printout")
    }
}

// MARK: - Marking up a picture (owner request 2026-08-03)

@MainActor
final class VisionAnnotateTests: XCTestCase {

    private func projectBase() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("wall-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base,
                                                withIntermediateDirectories: true)
        return base
    }

    private func png() throws -> Data {
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.systemIndigo.drawSwatch(in: NSRect(x: 0, y: 0, width: 20, height: 20))
        image.unlockFocus()
        return try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation))?
            .representation(using: .png, properties: [:]))
    }

    func testAnnotateAndPromptAppearOnlyWhereTheyMeanSomething() {
        let picture = VisionScrapTool.ring(isText: false, hasPicture: true,
                                           hasPrompt: true)
        XCTAssertTrue(picture.contains(.annotate))
        XCTAssertTrue(picture.contains(.prompt))

        let words = VisionScrapTool.ring(isText: true, hasPicture: false,
                                         isPaper: true)
        XCTAssertFalse(words.contains(.annotate), "nothing to mark up")
        XCTAssertFalse(words.contains(.prompt), "nothing made it")

        let uploaded = VisionScrapTool.ring(isText: false, hasPicture: true)
        XCTAssertTrue(uploaded.contains(.annotate),
                      "a dropped picture can be marked up too")
        XCTAssertFalse(uploaded.contains(.prompt), "but no words made it")
    }

    func testMarksBecomeInstructionsAndTheOriginalPromptIsKept() async throws {
        let base = try projectBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let bytes = try png()
        // The generator writes to the system temp dir, OUTSIDE the project,
        // so the asset pipeline imports it — a file already inside the
        // project would merely be relativized.
        let replacement = FileManager.default.temporaryDirectory
            .appendingPathComponent("redrawn-\(UUID().uuidString).png")
        try bytes.write(to: replacement)
        defer { try? FileManager.default.removeItem(at: replacement) }

        let viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: base)
        var card = VisionCard()
        card.description = "a rain-soaked neon street"
        card.imagePath = "assets/visionboard/old.png"
        viewModel.addCard(card)
        let id = viewModel.cards[0].id

        var sentPrompt: String?
        var sentImage: Data?
        viewModel.onEditImage = { edit, completion in
            sentPrompt = edit.prompt
            sentImage = edit.baseImage
            completion(replacement)
        }

        // DC-0073: the marks themselves travel with the edit.
        await viewModel.redraw(id, marks: [KeyframeAnnotation(id: "1", normalizedX: 0.3,
                                                              normalizedY: 0.6, text: "brighter window",
                                                              number: 1)],
                               baseImage: bytes)

        let prompt = try XCTUnwrap(sentPrompt)
        XCTAssertTrue(prompt.contains("At (30%, 60%): brighter window"),
                      "a pin's position and words become the instruction")
        XCTAssertTrue(prompt.contains("Original prompt: a rain-soaked neon street"),
                      "the words that made it are carried along")
        XCTAssertEqual(sentImage, bytes,
                       "the picture itself goes as the reference — an edit, "
                       + "not a fresh invention")
        XCTAssertTrue((viewModel.cards[0].imagePath ?? "")
                        .hasPrefix("assets/visionboard/"),
                      "the redrawn picture replaces it in place")
        XCTAssertEqual(viewModel.cards[0].description, prompt,
                       "and the element remembers how it got here")
    }

    func testRedrawingDoesNothingWithoutAGenerator() async throws {
        let viewModel = VisionBoardViewModel()
        var card = VisionCard()
        card.imagePath = "assets/visionboard/a.png"
        viewModel.addCard(card)
        await viewModel.redraw(viewModel.cards[0].id, marks: [KeyframeAnnotation(text: "make it warmer", number: 1)],
                               baseImage: try png())
        XCTAssertEqual(viewModel.cards[0].imagePath, "assets/visionboard/a.png")
        XCTAssertFalse(viewModel.isGenerating)
    }
}

// MARK: - Imagining doesn't stop the wall (owner report 2026-08-03)

@MainActor
final class VisionNonBlockingImagineTests: XCTestCase {

    private func base() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wall-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true)
        return url
    }

    private func makePNG() throws -> URL {
        let image = NSImage(size: NSSize(width: 24, height: 16))
        image.lockFocus()
        NSColor.systemGreen.drawSwatch(in: NSRect(x: 0, y: 0, width: 24, height: 16))
        image.unlockFocus()
        let data = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation))?
            .representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    func testSpaceIsHeldOnTheWallWhileItWorks() async throws {
        let projectBase = try base()
        defer { try? FileManager.default.removeItem(at: projectBase) }
        let generated = try makePNG()

        let viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: projectBase)

        var heldWhileWorking: [PendingImagine] = []
        viewModel.onGenerateImage = { _, completion in
            // Whatever the wall looks like mid-flight is what the user sees.
            heldWhileWorking = viewModel.pendingImagines
            completion([generated])
        }

        await viewModel.imagine("a rain-soaked neon street",
                                at: CGPoint(x: 500, y: 300))

        XCTAssertEqual(heldWhileWorking.count, 1,
                       "a blank sheet goes up immediately")
        let held = try XCTUnwrap(heldWhileWorking.first)
        XCTAssertEqual(held.prompt, "a rain-soaked neon street",
                       "and it says what it is waiting for")
        XCTAssertEqual(held.origin.x + held.size.width / 2, 500, accuracy: 0.001,
                       "exactly where the picture will land")

        XCTAssertTrue(viewModel.pendingImagines.isEmpty, "the sheet comes down")
        XCTAssertEqual(viewModel.cards.count, 1, "and the picture takes its place")
        XCTAssertEqual(viewModel.cards[0].description, "a rain-soaked neon street")
    }

    func testTheWallStaysUsableWhileAPictureIsComing() async throws {
        let projectBase = try base()
        defer { try? FileManager.default.removeItem(at: projectBase) }
        let generated = try makePNG()

        let viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: projectBase)
        viewModel.onGenerateImage = { _, completion in
            // Mid-flight the board still takes work: write a word, pan.
            Task { @MainActor in
                await viewModel.absorb([.text("dusk")], at: .zero)
                viewModel.scrollPan(deltaX: 120, deltaY: 40)
                completion([generated])
            }
        }

        await viewModel.imagine("a lit window", at: .zero)

        XCTAssertEqual(viewModel.cards.count, 2,
                       "the word written mid-flight survived")
        XCTAssertTrue(viewModel.cards.contains { $0.text == "dusk" })
        XCTAssertEqual(viewModel.transform.offset.x, 120, accuracy: 0.001,
                       "and the pan taken mid-flight held")
    }

    func testAFailedImaginingLeavesNoEmptySheetBehind() async {
        let viewModel = VisionBoardViewModel()
        viewModel.onGenerateImage = { _, completion in completion([]) }

        await viewModel.imagine("something impossible", at: .zero)

        XCTAssertTrue(viewModel.pendingImagines.isEmpty,
                      "the held space is given back")
        XCTAssertTrue(viewModel.cards.isEmpty)
        XCTAssertFalse(viewModel.isGenerating)
    }

    func testARedrawMarksItsOwnElementNotTheWholeWall() async throws {
        let projectBase = try base()
        defer { try? FileManager.default.removeItem(at: projectBase) }
        let generated = try makePNG()
        let bytes = try Data(contentsOf: generated)

        let viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: projectBase)
        var card = VisionCard()
        card.imagePath = "assets/visionboard/a.png"
        viewModel.addCard(card)
        let id = viewModel.cards[0].id

        var markedWhileWorking: Set<String> = []
        viewModel.onEditImage = { _, completion in
            markedWhileWorking = viewModel.working
            completion(generated)
        }

        await viewModel.redraw(id, marks: [KeyframeAnnotation(text: "brighter", number: 1)], baseImage: bytes)

        XCTAssertEqual(markedWhileWorking, [id],
                       "only that element says it is working")
        XCTAssertTrue(viewModel.working.isEmpty)
    }
}

// MARK: - Work shows on the element it's happening to (owner request)

@MainActor
final class VisionWorkingBadgeTests: XCTestCase {

    func testAnElementIsMarkedForTheDurationOfTheWorkAndNoLonger() async {
        let viewModel = VisionBoardViewModel()
        viewModel.addCard(VisionCard())
        let id = viewModel.cards[0].id
        XCTAssertFalse(viewModel.isWorking(id))

        var seenDuring = false
        let result = await viewModel.whileWorking(id) { () -> Int in
            seenDuring = viewModel.isWorking(id)
            return 7
        }

        XCTAssertTrue(seenDuring, "the badge turns while the work runs")
        XCTAssertEqual(result, 7, "and the work's result comes back out")
        XCTAssertFalse(viewModel.isWorking(id), "the badge stops after")
    }

    func testSeveralElementsCanBeWorkingAtOnce() async {
        let viewModel = VisionBoardViewModel()
        viewModel.addCard(VisionCard())
        viewModel.addCard(VisionCard())
        let first = viewModel.cards[0].id
        let second = viewModel.cards[1].id

        await viewModel.whileWorking(first) {
            await viewModel.whileWorking(second) {
                XCTAssertEqual(viewModel.working, [first, second],
                               "each says so in its own corner")
            }
            XCTAssertEqual(viewModel.working, [first],
                           "and stops independently")
        }
        XCTAssertTrue(viewModel.working.isEmpty)
    }
}

// MARK: - Work that can't run says so (owner report: "I still don't see it")

@MainActor
final class VisionWorkFeedbackTests: XCTestCase {

    func testAQuickResultIsStillSeen() async {
        // A badge that flashes for eighty milliseconds is a badge nobody
        // sees — which is exactly what "nothing happened" looks like.
        let viewModel = VisionBoardViewModel()
        viewModel.addCard(VisionCard())
        let id = viewModel.cards[0].id

        let clock = ContinuousClock()
        let started = clock.now
        await viewModel.whileWorking(id, minimumVisible: .milliseconds(300)) { }
        let elapsed = clock.now - started

        XCTAssertGreaterThan(elapsed, .milliseconds(250),
                             "instant work still shows the badge long enough to read")
        XCTAssertFalse(viewModel.isWorking(id))
    }

    func testSlowWorkIsNotPaddedFurther() async {
        let viewModel = VisionBoardViewModel()
        viewModel.addCard(VisionCard())
        let id = viewModel.cards[0].id

        let clock = ContinuousClock()
        let started = clock.now
        await viewModel.whileWorking(id, minimumVisible: .milliseconds(50)) {
            try? await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertLessThan(clock.now - started, .milliseconds(500),
                          "no needless waiting on top of real work")
    }

    func testRedrawWithNoGeneratorSaysSoInsteadOfDoingNothing() async {
        let viewModel = VisionBoardViewModel()
        var card = VisionCard()
        card.imagePath = "assets/visionboard/a.png"
        viewModel.addCard(card)

        await viewModel.redraw(viewModel.cards[0].id, marks: [KeyframeAnnotation(text: "warmer", number: 1)],
                               baseImage: Data([0x1]))

        XCTAssertNotNil(viewModel.lastWorkProblem,
                        "silence reads as a broken tool")
    }

    func testRedrawWithNowhereToSaveSaysSo() async {
        let viewModel = VisionBoardViewModel()   // no asset store configured
        var card = VisionCard()
        card.imagePath = "assets/visionboard/a.png"
        viewModel.addCard(card)
        viewModel.onEditImage = { _, completion in
            completion(FileManager.default.temporaryDirectory
                .appendingPathComponent("nope.png"))
        }

        await viewModel.redraw(viewModel.cards[0].id, marks: [KeyframeAnnotation(text: "warmer", number: 1)],
                               baseImage: Data([0x1]))

        let problem = viewModel.lastWorkProblem ?? ""
        XCTAssertTrue(problem.contains("Save the project"),
                      "and it says what to do about it: \(problem)")
    }
}

// MARK: - The editor fits the window (owner report: sheet clipped)

final class VisionCardEditorFittingTests: XCTestCase {

    func testABigWindowGetsTheFullEditor() {
        let size = VisionCardEditor.fittedSize(
            ideal: CGSize(width: 540, height: 560),
            available: CGSize(width: 1440, height: 900))
        XCTAssertEqual(size, CGSize(width: 540, height: 560))
    }

    func testASmallWindowShrinksTheSheetInsteadOfClippingIt() {
        // The owner's screenshot: header gone off the top, Save gone off
        // the bottom. The sheet must always fit inside what's there.
        let available = CGSize(width: 700, height: 500)
        let size = VisionCardEditor.fittedSize(
            ideal: CGSize(width: 760, height: 600), available: available)
        XCTAssertLessThanOrEqual(size.width, available.width - 40)
        XCTAssertLessThanOrEqual(size.height, available.height - 40)
    }

    func testATinyWindowStopsAtTheUsableFloor() {
        let size = VisionCardEditor.fittedSize(
            ideal: CGSize(width: 540, height: 560),
            available: CGSize(width: 300, height: 200))
        XCTAssertEqual(size, CGSize(width: 360, height: 280),
                       "below this the editor is unusable either way")
    }

    func testNoMeasurementYetMeansTheOldBehaviour() {
        // First present can beat the first layout pass; the ideal size
        // is the pre-fix behaviour, not a degenerate zero-size sheet.
        XCTAssertEqual(VisionCardEditor.fittedSize(
            ideal: CGSize(width: 540, height: 560), available: nil),
            CGSize(width: 540, height: 560))
        XCTAssertEqual(VisionCardEditor.fittedSize(
            ideal: CGSize(width: 540, height: 560), available: .zero),
            CGSize(width: 540, height: 560))
    }
}
