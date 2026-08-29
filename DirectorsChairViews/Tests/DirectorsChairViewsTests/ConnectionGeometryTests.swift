// DirectorsChairViews/Tests/DirectorsChairViewsTests/ConnectionGeometryTests.swift
//
// Pure curve maths behind the Scene Connections canvas: where a line runs,
// where its × sits, and what counts as a click on it.

import XCTest
import SwiftUI
@testable import DirectorsChairViews

final class ConnectionGeometryTests: XCTestCase {

    /// Script port just left of the canvas column, shot port just right of it —
    /// the real layout: dots live in the side columns, the canvas is between.
    private let start = CGPoint(x: -30, y: 80)
    private let end = CGPoint(x: 430, y: 300)
    private let canvas = CGRect(x: 0, y: 0, width: 400, height: 600)

    // MARK: - Curve

    func testCurveStartsAndEndsAtThePorts() {
        let first = ConnectionGeometry.point(from: start, to: end, at: 0)
        let last = ConnectionGeometry.point(from: start, to: end, at: 1)

        XCTAssertEqual(first.x, start.x, accuracy: 0.001)
        XCTAssertEqual(first.y, start.y, accuracy: 0.001)
        XCTAssertEqual(last.x, end.x, accuracy: 0.001)
        XCTAssertEqual(last.y, end.y, accuracy: 0.001)
    }

    func testMidpointIsTheAverageOfThePorts() {
        // Horizontal tangents at both ends cancel the control offsets at
        // t = 0.5, so the × always sits halfway between the two dots.
        let mid = ConnectionGeometry.midpoint(from: start, to: end)

        XCTAssertEqual(mid.x, 200, accuracy: 0.001)
        XCTAssertEqual(mid.y, 190, accuracy: 0.001)
    }

    func testDrawnCurveAndSampledCurveAgree() {
        // The overlay strokes the true cubic; the hit band samples the same
        // curve — a sampled point must lie on the drawn stroke.
        let drawn = ConnectionGeometry.path(from: start, to: end)
            .strokedPath(StrokeStyle(lineWidth: 2))

        for t: CGFloat in [0.1, 0.37, 0.5, 0.73, 0.9] {
            let sampled = ConnectionGeometry.point(from: start, to: end, at: t)
            XCTAssertTrue(drawn.contains(sampled), "t=\(t) drifted off the drawn curve")
        }
    }

    // MARK: - Hit band

    func testHitBandCoversTheCurveInsideTheCanvas() {
        let hit = ConnectionGeometry.hitPath(from: start, to: end, within: canvas)

        for t: CGFloat in [0.2, 0.35, 0.5, 0.65, 0.8] {
            let onCurve = ConnectionGeometry.point(from: start, to: end, at: t)
            XCTAssertTrue(hit.contains(onCurve), "t=\(t) should be clickable")
        }

        let mid = ConnectionGeometry.midpoint(from: start, to: end)
        XCTAssertTrue(hit.contains(CGPoint(x: mid.x, y: mid.y + 8)), "the band is forgiving")
        XCTAssertFalse(hit.contains(CGPoint(x: mid.x, y: mid.y + 40)), "but not that forgiving")
    }

    func testHitBandStopsShortOfThePortDots() {
        // The dots must stay draggable, so the band never reaches into the
        // side columns.
        let hit = ConnectionGeometry.hitPath(from: start, to: end, within: canvas)
        let halfWidth = SceneConnectionConstants.connectionHitWidth / 2

        XCTAssertFalse(hit.contains(start), "script dot is outside the band")
        XCTAssertFalse(hit.contains(end), "shot dot is outside the band")
        XCTAssertGreaterThanOrEqual(hit.boundingRect.minX, canvas.minX - halfWidth - 0.5)
        XCTAssertLessThanOrEqual(hit.boundingRect.maxX, canvas.maxX + halfWidth + 0.5)
    }

    func testHitBandIsEmptyWhenTheCurveRunsOutsideTheCanvas() {
        // Both cards scrolled above the visible canvas: nothing to click, and
        // nothing floating over the toolbar.
        let hit = ConnectionGeometry.hitPath(
            from: CGPoint(x: -30, y: -200),
            to: CGPoint(x: 430, y: -100),
            within: canvas
        )

        XCTAssertTrue(hit.isEmpty)
    }

    // MARK: - Remove glyph

    func testRemoveGlyphHitRadius() {
        let mid = CGPoint(x: 200, y: 190)
        let radius = SceneConnectionConstants.connectionRemoveHitSize / 2

        XCTAssertTrue(ConnectionGeometry.isOnRemoveGlyph(mid, midpoint: mid))
        XCTAssertTrue(ConnectionGeometry.isOnRemoveGlyph(CGPoint(x: mid.x + radius - 1, y: mid.y), midpoint: mid))
        XCTAssertFalse(ConnectionGeometry.isOnRemoveGlyph(CGPoint(x: mid.x + radius + 1, y: mid.y), midpoint: mid))
        XCTAssertFalse(ConnectionGeometry.isOnRemoveGlyph(CGPoint(x: mid.x, y: mid.y - radius - 1), midpoint: mid))
    }

    func testRemoveGlyphSitsInsideTheHitBand() {
        // The drawn disc is narrower than the band, so every pixel of the ×
        // is both visible and clickable without a shape of its own.
        XCTAssertLessThan(SceneConnectionConstants.connectionRemoveGlyphSize,
                          SceneConnectionConstants.connectionHitWidth)

        let hit = ConnectionGeometry.hitPath(from: start, to: end, within: canvas)
        let mid = ConnectionGeometry.midpoint(from: start, to: end)
        let glyphRadius = SceneConnectionConstants.connectionRemoveGlyphSize / 2
        XCTAssertTrue(hit.contains(CGPoint(x: mid.x + glyphRadius, y: mid.y)))
        XCTAssertTrue(hit.contains(CGPoint(x: mid.x - glyphRadius, y: mid.y)))
    }
}
