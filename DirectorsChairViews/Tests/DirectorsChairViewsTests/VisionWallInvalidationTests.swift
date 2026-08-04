import XCTest
import SwiftUI
@testable import DirectorsChairViews
@testable import DirectorsChairCore

// The wall's performance CONTRACT, asserted by invalidation counts
// rather than milliseconds — wall-clock flakes with thermals, but "a pan
// re-renders zero elements" is deterministic. This is the test that
// guards the camera-split + Equatable architecture: before it, every
// publish re-ran every element body on the wall (measured 33ms/tick pan
// on a 150-element board), and any regression to that world trips these
// exact assertions.

enum RenderTally {
    nonisolated(unsafe) static var itemBodies = 0
    nonisolated(unsafe) static var cordBodies = 0
    nonisolated(unsafe) static var surfaceBodies = 0
}

@MainActor
final class VisionWallInvalidationTests: XCTestCase {
    func testWhoRerendersOnEachKindOfChange() {
        RenderProbe.onItem = { RenderTally.itemBodies += 1 }
        RenderProbe.onCord = { RenderTally.cordBodies += 1 }
        RenderProbe.onSurface = { RenderTally.surfaceBodies += 1 }
        let viewModel = VisionBoardViewModel()
        for index in 0..<60 {
            var card = VisionCard()
            card.canvasX = Double(index % 10) * 250
            card.canvasY = Double(index / 10) * 210
            card.canvasWidth = 200; card.canvasHeight = 160
            viewModel.addCard(card)
        }
        for index in 0..<8 {
            viewModel.connectors.append(VisionConnector(
                fromCardId: viewModel.cards[index].id,
                toCardId: viewModel.cards[index + 20].id))
        }
        viewModel.viewportSize = CGSize(width: 1200, height: 800)
        viewModel.fitToView(viewSize: viewModel.viewportSize)

        let view = NSHostingView(rootView: AnyView(
            VisionBoardCanvas(viewModel: viewModel)
                .frame(width: 1200, height: 800)))
        let window = NSWindow(contentRect: NSRect(x: -3000, y: -3000,
                                                  width: 1200, height: 800),
                              styleMask: [.borderless], backing: .buffered,
                              defer: false)
        window.contentView = view
        window.orderBack(nil)
        RunLoop.main.run(mode: .default, before: Date())
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()

        func tickAndReport(_ label: String, _ mutate: () -> Void) {
            RenderTally.itemBodies = 0
            RenderTally.cordBodies = 0
            RenderTally.surfaceBodies = 0
            mutate()
            RunLoop.main.run(mode: .default, before: Date())
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            print("TALLY[\(label)]: items=\(RenderTally.itemBodies) "
                  + "cords=\(RenderTally.cordBodies) "
                  + "surface=\(RenderTally.surfaceBodies)")
        }

        // Selecting one element re-renders THAT element, not the wall.
        tickAndReport("select") { viewModel.selectCard(viewModel.cards[3].id) }
        XCTAssertEqual(RenderTally.itemBodies, 1,
                       "selection must touch exactly the selected element")

        // The camera moving re-renders NO elements — the whole point of
        // publishing it separately from the board's data.
        tickAndReport("pan") { viewModel.scrollPan(deltaX: 5, deltaY: 3) }
        XCTAssertEqual(RenderTally.itemBodies, 0,
                       "a pan must not re-render elements")
        XCTAssertGreaterThan(RenderTally.surfaceBodies, 0,
                             "while the plaster follows the camera")

        tickAndReport("zoom") {
            viewModel.scrollZoom(deltaY: 2, focus: CGPoint(x: 600, y: 400))
        }
        XCTAssertEqual(RenderTally.itemBodies, 0,
                       "zoom reaches adornments through \\.wallZoom, "
                       + "never whole elements")

        // Dragging one element re-renders that element alone.
        viewModel.beginCardDrag(anchor: viewModel.cards[3].id)
        tickAndReport("drag") {
            viewModel.updateCardDrag(translation: CGSize(width: 8, height: 4))
        }
        XCTAssertEqual(RenderTally.itemBodies, 1,
                       "dragging one element must not re-render the rest")
    }
}
