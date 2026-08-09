// Tests/DirectorsChairViewsTests/VisionWorkingBadgeWiringTests.swift
//
// The owner reported a missing progress indicator three times. Twice the
// answer was "make it more visible" — and twice that was wrong, because
// VisionCardItem drew the badge perfectly whenever it was asked to, and
// the canvas never asked. A test that renders the ITEM would have passed
// throughout. So this one renders the WALL, the way the owner sees it.

import XCTest
import SwiftUI
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class VisionWorkingBadgeWiringTests: XCTestCase {

    /// Renders a view at a fixed size and returns its pixels.
    private func pixels(_ view: some View, size: CGSize) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content:
            view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.nsImage)
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        return try XCTUnwrap(NSBitmapImageRep(data: tiff))
    }

    /// Where the two renders disagree, and how much. Comparing the busy
    /// wall against the idle one is the only measure that can't be fooled
    /// by the element's own bright paper.
    private func difference(_ a: NSBitmapImageRep,
                            _ b: NSBitmapImageRep) -> (count: Int, centre: CGPoint) {
        var count = 0
        var sumX = 0.0, sumY = 0.0
        for x in 0..<min(a.pixelsWide, b.pixelsWide) {
            for y in 0..<min(a.pixelsHigh, b.pixelsHigh) {
                guard let left = a.colorAt(x: x, y: y),
                      let right = b.colorAt(x: x, y: y) else { continue }
                let delta = abs(left.brightnessComponent - right.brightnessComponent)
                    + abs(left.alphaComponent - right.alphaComponent)
                if delta > 0.08 {
                    count += 1
                    sumX += Double(x); sumY += Double(y)
                }
            }
        }
        guard count > 0 else { return (0, .zero) }
        return (count, CGPoint(x: sumX / Double(count), y: sumY / Double(count)))
    }

    private func wall() -> (VisionBoardViewModel, String) {
        let viewModel = VisionBoardViewModel()
        var card = VisionCard()
        card.canvasX = 40
        card.canvasY = 40
        card.canvasWidth = 240
        card.canvasHeight = 160
        card.title = ""
        viewModel.addCard(card)
        return (viewModel, viewModel.cards[0].id)
    }

    /// Holds an element busy through the real production API — no
    /// test-only door into the state, or the test proves nothing about
    /// what happens when the app runs.
    private func holdBusy(_ viewModel: VisionBoardViewModel,
                          _ id: String) async -> Task<Void, Never> {
        let task = Task { @MainActor in
            let _: Void = await viewModel.whileWorking(id) {
                try? await Task.sleep(for: .seconds(30))
            }
        }
        while !viewModel.isWorking(id) { await Task.yield() }
        return task
    }

    func testTheWallShowsTheBadgeWhenAnElementIsBusy() async throws {
        let size = CGSize(width: 420, height: 320)

        // ONE wall, photographed before and after. Two separate models
        // would differ anyway: tilt and tack position are hashed from the
        // card's id, so a fresh card is never pixel-identical, and the
        // test would pass on that noise alone.
        let (viewModel, id) = wall()
        let idleRender = try pixels(VisionBoardCanvas(viewModel: viewModel),
                                    size: size)
        let held = await holdBusy(viewModel, id)
        defer { held.cancel() }
        let busyRender = try pixels(VisionBoardCanvas(viewModel: viewModel),
                                    size: size)
        let changed = difference(idleRender, busyRender)

        XCTAssertGreaterThan(changed.count, 150,
            "a busy element must look different AT THE CANVAS LEVEL — the "
            + "item drawing the badge correctly in isolation is not enough, "
            + "which is exactly how this shipped broken three times")

        // And it belongs in the element's bottom-right corner, not
        // wherever it happens to land.
        XCTAssertGreaterThan(changed.centre.x, 160,
                             "badge sits toward the element's right edge")
        XCTAssertGreaterThan(changed.centre.y, 100,
                             "and toward its bottom (\(changed.centre))")
    }

    func testTheCanvasAsksTheModelWhichElementsAreBusy() async {
        // The direct statement of the defect: the flag must come from the
        // model, so marking work anywhere reaches the element on screen.
        let (viewModel, id) = wall()
        let held = await holdBusy(viewModel, id)
        defer { held.cancel() }
        XCTAssertTrue(viewModel.isWorking(id))

        let other = VisionCard()
        viewModel.addCard(other)
        XCTAssertFalse(viewModel.isWorking(viewModel.cards[1].id),
                       "only the element being worked on wears the badge")
    }
}
