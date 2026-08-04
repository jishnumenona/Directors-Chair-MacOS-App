// Tests/DirectorsChairViewsTests/VisionWallPerformanceTests.swift
//
// The wall's interaction cost, measured the way the user feels it: a
// populated board hosted for real, with pan / zoom / drag ticks pumped
// through the same code path a trackpad drives. Numbers print to the log;
// ceilings are generous (catastrophe guards, per the project's perf
// convention) so CI noise doesn't flake them.

import XCTest
import SwiftUI
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class VisionWallPerformanceTests: XCTestCase {

    /// A board the size of a real production wall: pictures, words,
    /// notes, links, working badges, and a web of cords.
    private func populatedModel(cards cardCount: Int = 150,
                                cords cordCount: Int = 12) -> VisionBoardViewModel {
        let viewModel = VisionBoardViewModel()
        for index in 0..<cardCount {
            var card = VisionCard()
            card.cardType = index % 4 == 0 ? "text" : "image"
            card.text = index % 4 == 0 ? "IDEA \(index)" : ""
            card.canvasX = Double((index % 15)) * 260
            card.canvasY = Double(index / 15) * 220
            card.canvasWidth = 220
            card.canvasHeight = 170
            card.rotation = Double(index % 7) - 3
            if index % 9 == 0 { card.referenceNote = "note \(index)" }
            if index % 11 == 0 {
                card.linkedShotId = "shot-\(index)"
                card.linkedLabel = "SHOT \(index)"
            }
            viewModel.addCard(card)
        }
        for index in 0..<cordCount {
            var cord = VisionConnector(
                fromCardId: viewModel.cards[index * 3].id,
                toCardId: viewModel.cards[index * 3 + 2].id)
            cord.thread = VisionThread.allCases[index % 8].rawValue
            cord.thickness = VisionThreadRing.weights[index % 5]
            viewModel.connectors.append(cord)
        }
        viewModel.viewportSize = CGSize(width: 1440, height: 900)
        viewModel.fitToView(viewSize: viewModel.viewportSize)
        return viewModel
    }

    /// Hosts the canvas in a real (offscreen) window and returns a tick
    /// that runs the runloop until SwiftUI's scheduled update has been
    /// applied and drawn. Without the window + runloop pump, @Published
    /// mutations queue an update that never runs, and the "measurement"
    /// is of an empty loop — the first cut of this harness reported
    /// 0.13ms/tick for everything, which was the cost of nothing.
    private func host(_ viewModel: VisionBoardViewModel)
        -> (NSWindow, () -> Void) {
        let view = NSHostingView(rootView:
            AnyView(VisionBoardCanvas(viewModel: viewModel)
                .frame(width: 1440, height: 900)))
        let window = NSWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: 1440, height: 900),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        window.orderBack(nil)          // real layer tree, no focus steal
        pump()
        return (window, {
            self.pump()
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
        })
    }

    /// One runloop turn — lets SwiftUI apply the queued update.
    private func pump() {
        RunLoop.main.run(mode: .default, before: Date())
    }

    private func measureTicks(_ label: String, ticks: Int = 120,
                              _ mutate: (Int) -> Void,
                              tick: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        for index in 0..<ticks {
            mutate(index)
            tick()
        }
        let totalMs = Double(DispatchTime.now().uptimeNanoseconds - start)
            / 1_000_000
        let perTick = totalMs / Double(ticks)
        print("PERF[\(label)]: \(String(format: "%.2f", perTick))ms/tick "
              + "(\(Int(totalMs))ms / \(ticks) ticks)")
        return perTick
    }

    func testHarnessFloor() {
        // Ticks with NO mutation: whatever this costs is the harness —
        // runloop housekeeping, layout, display — not the wall. Every
        // other number must be read net of it.
        let viewModel = populatedModel()
        let (_, tick) = host(viewModel)
        _ = measureTicks("floor", { _ in }, tick: tick)
    }

    func testPanTickCost() {
        let viewModel = populatedModel()
        let (_, tick) = host(viewModel)
        let ms = measureTicks("pan", { _ in
            viewModel.scrollPan(deltaX: 3, deltaY: 2)
        }, tick: tick)
        // Numbers on this machine drift up to 2× with thermals, so the
        // ceiling is a catastrophe guard; the deterministic architecture
        // guard is VisionWallInvalidationTests.
        XCTAssertLessThan(ms, 120, "pan cost \(ms)ms/tick — regression")
    }

    func testZoomTickCost() {
        let viewModel = populatedModel()
        let (_, tick) = host(viewModel)
        let ms = measureTicks("zoom", { index in
            viewModel.scrollZoom(deltaY: index % 40 < 20 ? 2 : -2,
                                 focus: CGPoint(x: 720, y: 450))
        }, tick: tick)
        XCTAssertLessThan(ms, 150, "zoom cost \(ms)ms/tick — regression")
    }

    func testDragOneCardTickCost() {
        let viewModel = populatedModel()
        let (_, tick) = host(viewModel)
        let dragged = viewModel.cards[40].id
        viewModel.selectCard(dragged)
        viewModel.beginCardDrag(anchor: dragged)
        let ms = measureTicks("drag-one-card", { index in
            viewModel.updateCardDrag(translation:
                CGSize(width: index * 2, height: index))
        }, tick: tick)
        XCTAssertLessThan(ms, 120, "drag cost \(ms)ms/tick — regression")
    }

    func testIdleRepublishCost() {
        // The cost of ANY unrelated @Published change reaching the wall —
        // e.g. the working set during an Imagine. Should be near-free.
        let viewModel = populatedModel()
        let (_, tick) = host(viewModel)
        let target = viewModel.cards[0].id
        let ms = measureTicks("idle-republish", { _ in
            // touching selection is the cheapest real republish the
            // wall reacts to
            viewModel.selectCard(target)
            viewModel.clearSelection()
        }, tick: tick)
        XCTAssertLessThan(ms, 120,
                          "republish cost \(ms)ms/tick — regression")
    }
}
