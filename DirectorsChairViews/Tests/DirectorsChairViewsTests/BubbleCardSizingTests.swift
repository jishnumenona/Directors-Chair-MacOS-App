// BubbleCardSizingTests.swift
//
// Bubble cards hug their text (owner 2026-08-29): the cap a card takes from
// its row, and the hugging layout that sizes a card to its content without
// stretching it to that cap.

import XCTest
import SwiftUI
@testable import DirectorsChairViews

final class BubbleCardSizingTests: XCTestCase {

    func testBubblesCapAtAShareOfTheRow() {
        XCTAssertEqual(BubbleCardSizing.maxWidth(forRowWidth: 1000), 700)
        XCTAssertEqual(BubbleCardSizing.maxWidth(forRowWidth: 815), 570, "570.5 floored to a whole point")
        XCTAssertEqual(BubbleCardSizing.maxRowFraction, 0.7, accuracy: 1e-9)
    }

    func testUnknownRowWidthUsesTheFallbackCap() {
        XCTAssertEqual(BubbleCardSizing.maxWidth(forRowWidth: 0), BubbleCardSizing.fallbackMaxWidth)
        XCTAssertEqual(BubbleCardSizing.maxWidth(forRowWidth: -10), BubbleCardSizing.fallbackMaxWidth)
        XCTAssertEqual(BubbleCardSizing.maxWidth(forRowWidth: .nan), BubbleCardSizing.fallbackMaxWidth)
        XCTAssertEqual(BubbleCardSizing.maxWidth(forRowWidth: .infinity), BubbleCardSizing.fallbackMaxWidth)
    }

    func testAnEmptyEditFieldStaysUsable() {
        XCTAssertEqual(BubbleCardSizing.editFieldMinWidth, 160)
        XCTAssertLessThan(BubbleCardSizing.editFieldMinWidth, BubbleCardSizing.maxWidth(forRowWidth: 400),
                          "the minimum field fits inside the cap of a narrow row")
    }

    @MainActor
    func testHuggingLayoutHugsShortTextAndWrapsLongText() {
        let short = NSHostingView(rootView: Text("Yes.").font(.system(size: 12)).hugWidth(max: 200))
        let long = NSHostingView(rootView:
            Text(String(repeating: "A long line of stage direction that must wrap. ", count: 4))
                .font(.system(size: 12))
                .hugWidth(max: 200)
        )
        let shortSize = short.fittingSize
        let longSize = long.fittingSize

        XCTAssertGreaterThan(shortSize.width, 0)
        XCTAssertLessThan(shortSize.width, 100, "a short line is only as wide as its text")
        XCTAssertLessThanOrEqual(longSize.width, 200 + 0.5, "a long line stops at the cap…")
        XCTAssertGreaterThan(longSize.height, shortSize.height * 2, "…and wraps onto more lines")
    }
}
