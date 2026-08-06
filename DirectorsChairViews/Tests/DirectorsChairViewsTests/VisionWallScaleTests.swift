// Tests/DirectorsChairViewsTests/VisionWallScaleTests.swift
//
// The wall at project scale. The owner's requirement is blunt: really
// big projects must be usable, and the board must never drag the app
// down because the PROJECT is big. Before the scale policy, a
// 1,000-element board did not lag — it died on mount; after it, the
// numbers below hold. Ceilings are catastrophe guards (thermals drift
// 2× on this machine): they catch a return to the everything-mounted
// world, where pan cost 217ms/tick and drag-all never finished.
//
// Images are generated only when BIGIMG=1 (manual runs) — the CI run
// keeps the board imageless for speed and determinism.

import XCTest
import SwiftUI
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class VisionWallScaleTests: XCTestCase {

    private func footprintMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.resident_size) / 1_048_576
    }

    func testThousandElementBoard() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bigboard-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("assets/visionboard"),
            withIntermediateDirectories: true)
        // Real JPEGs so image memory is measured, not imagined — manual
        // runs only (BIGIMG=1).
        for index in 0..<(ProcessInfo.processInfo.environment["BIGIMG"] == "1"
                          ? 300 : 0) {
            let size = CGSize(width: 1600, height: 1200)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor(calibratedHue: CGFloat(index % 100) / 100,
                    saturation: 0.5, brightness: 0.8, alpha: 1).setFill()
            NSRect(origin: .zero, size: size).fill()
            image.unlockFocus()
            let tiff = image.tiffRepresentation!
            let jpeg = NSBitmapImageRep(data: tiff)!
                .representation(using: .jpeg,
                                properties: [.compressionFactor: 0.7])!
            try jpeg.write(to: base.appendingPathComponent(
                "assets/visionboard/pic-\(index).jpg"))
        }

        let viewModel = VisionBoardViewModel()
        viewModel.configureAssetStore(projectBase: base)
        for index in 0..<Int(ProcessInfo.processInfo.environment["BIGN"] ?? "1000")! {
            var card = VisionCard()
            card.cardType = index % 3 == 0 ? "text" : "image"
            if index % 3 != 0
                && ProcessInfo.processInfo.environment["BIGIMG"] == "1" {
                card.imagePath = "assets/visionboard/pic-\(index % 300).jpg"
            } else {
                card.text = "IDEA \(index)"
            }
            card.canvasX = Double(index % 32) * 260
            card.canvasY = Double(index / 32) * 220
            card.canvasWidth = 220; card.canvasHeight = 170
            card.rotation = Double(index % 7) - 3
            viewModel.addCard(card)
        }
        for index in 0..<min(80, (viewModel.cards.count / 13)) {
            viewModel.connectors.append(VisionConnector(
                fromCardId: viewModel.cards[index * 12].id,
                toCardId: viewModel.cards[index * 12 + 6].id))
        }
        viewModel.viewportSize = CGSize(width: 1440, height: 900)
        viewModel.fitToView(viewSize: CGSize(width: 1440, height: 900))

        let before = footprintMB()
        var start = DispatchTime.now().uptimeNanoseconds
        let view = NSHostingView(rootView: AnyView(
            VisionBoardCanvas(viewModel: viewModel)
                .frame(width: 1440, height: 900)))
        let window = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 1440, height: 900),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderBack(nil)
        RunLoop.main.run(mode: .default, before: Date())
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        let mountMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
        FileHandle.standardError.write("BIG[mount \(viewModel.cards.count)]: \(Int(mountMs))ms\n".data(using: .utf8)!)
        XCTAssertLessThan(mountMs, 8000,
            "mounting a 1,000-element board took \(Int(mountMs))ms — before "
            + "the scale policy this crashed outright; treat any blowup here "
            + "as that regression")

        // Let async thumbnail loads land.
        for _ in 0..<200 {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        view.displayIfNeeded()
        FileHandle.standardError.write("BIG[footprint after load]: \(Int(footprintMB() - before))MB over baseline\n".data(using: .utf8)!)

        func tick(_ label: String, _ mutate: () -> Void) {
            start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<30 {
                mutate()
                RunLoop.main.run(mode: .default, before: Date())
                view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            }
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / 30
            FileHandle.standardError.write("BIG[\(label)]: \(String(format: "%.1f", ms))ms/tick\n".data(using: .utf8)!)
            XCTAssertLessThan(ms, 900,
                "\(label) at \(ms)ms/tick — the everything-mounted world "
                + "was 217–529ms and death; this is a catastrophic regression")
        }

        tick("pan") { viewModel.scrollPan(deltaX: 3, deltaY: 2) }
        tick("select-toggle") {
            viewModel.selectCard(viewModel.cards[5].id)
            viewModel.clearSelection()
        }
        viewModel.selectCard(viewModel.cards[40].id)
        viewModel.beginCardDrag(anchor: viewModel.cards[40].id)
        tick("drag-one") {
            viewModel.updateCardDrag(translation: CGSize(width: 4, height: 2))
        }
        viewModel.endCardDrag(translation: .zero)
        viewModel.selectAllCards()
        viewModel.beginCardDrag(anchor: viewModel.cards[40].id)
        tick("drag-all") {
            viewModel.updateCardDrag(translation: CGSize(width: 4, height: 2))
        }
        viewModel.endCardDrag(translation: .zero)
        viewModel.clearSelection()

        // Working zoom: standing close, staged mounting active.
        viewModel.setZoomLevel(0.9)
        RunLoop.main.run(mode: .default, before: Date())
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        tick("pan@working-zoom") { viewModel.scrollPan(deltaX: 3, deltaY: 2) }
        viewModel.selectCard(viewModel.cards[40].id)
        viewModel.beginCardDrag(anchor: viewModel.cards[40].id)
        tick("drag-one@working-zoom") {
            viewModel.updateCardDrag(translation: CGSize(width: 4, height: 2))
        }
        try? FileManager.default.removeItem(at: base)
    }
}

// MARK: - The policy itself, pinned

@MainActor
final class WallScalePolicyTests: XCTestCase {

    func testSmallBoardsAreUntouchedByThePolicy() {
        // Boards at the limit mount everything in full at every zoom —
        // nothing about the owner's current boards changes, ever.
        XCTAssertFalse(WallScale.isBig(WallScale.fullDetailLimit))
        XCTAssertFalse(WallScale.rendersChips(
            count: WallScale.fullDetailLimit, zoom: 0.05))
        let cards = (0..<10).map { _ in VisionCard() }
        XCTAssertEqual(WallScale.staged(cards, stage: .zero, count: 10).count,
                       10, "a stage never culls a small board")
    }

    func testBigBoardsChipOnlyWhenFarOut() {
        XCTAssertTrue(WallScale.rendersChips(count: 500, zoom: 0.2))
        XCTAssertFalse(WallScale.rendersChips(count: 500, zoom: 0.5),
                       "close up, big boards mount full elements — staged")
    }

    func testStagingKeepsWhatTheStageTouches() {
        var inside = VisionCard()
        inside.canvasX = 100; inside.canvasY = 100
        var outside = VisionCard()
        outside.canvasX = 90_000; outside.canvasY = 90_000
        let staged = WallScale.staged([inside, outside],
                                      stage: CGRect(x: 0, y: 0,
                                                    width: 2000, height: 2000),
                                      count: 400)
        XCTAssertEqual(staged.map(\.id), [inside.id])
    }

    func testNoMeasurementMeansEverythingMounts() {
        // Before the first layout pass the stage is unknown — mounting
        // everything is the safe default, culling nothing is a bug the
        // user can see, culling everything is a blank wall.
        let cards = (0..<400).map { _ in VisionCard() }
        XCTAssertEqual(WallScale.staged(cards, stage: nil, count: 400).count,
                       400)
    }

    func testTheCameraPublishesTheStageWithHysteresis() {
        let camera = VisionWallCamera()
        camera.viewport = CGSize(width: 1000, height: 800)
        camera.transform = CanvasTransform(zoom: 1, offset: .zero)
        let first = camera.stage.region
        XCTAssertNotNil(first)

        // A small pan stays inside the margin: no republish.
        camera.transform.offset.x -= 40
        XCTAssertEqual(camera.stage.region, first,
                       "40pt of pan must not re-filter the wall")

        // Travelling far enough moves the stage.
        camera.transform.offset.x -= 3000
        XCTAssertNotEqual(camera.stage.region, first)
    }

    func testFarOutFlipsExactlyAtTheChipThreshold() {
        let camera = VisionWallCamera()
        camera.viewport = CGSize(width: 1000, height: 800)
        camera.transform = CanvasTransform(zoom: 1, offset: .zero)
        XCTAssertFalse(camera.stage.farOut)
        camera.transform.zoom = 0.2
        XCTAssertTrue(camera.stage.farOut)
        camera.transform.zoom = 0.9
        XCTAssertFalse(camera.stage.farOut)
    }
}
