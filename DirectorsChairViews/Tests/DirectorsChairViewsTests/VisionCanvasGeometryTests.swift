// DirectorsChairViewsTests/VisionCanvasGeometryTests.swift
//
// Vision Board repair, Slice 1: the canvas math that was previously
// scattered, disagreeing, and untestable — now pure and pinned. The
// anchored-idempotence tests ARE the regressions for the runaway
// drag/resize bugs.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class VisionCanvasGeometryTests: XCTestCase {

    // MARK: - Transform

    func testScreenWorldRoundTrip() {
        let transforms = [
            CanvasTransform(zoom: 1, offset: .zero),
            CanvasTransform(zoom: 0.25, offset: CGPoint(x: 340, y: -120)),
            CanvasTransform(zoom: 3.5, offset: CGPoint(x: -900, y: 42)),
        ]
        let points = [CGPoint.zero, CGPoint(x: 123.5, y: -77),
                      CGPoint(x: -4000, y: 9000)]
        for t in transforms {
            for p in points {
                let round = t.toWorld(t.toScreen(p))
                XCTAssertEqual(round.x, p.x, accuracy: 0.0001)
                XCTAssertEqual(round.y, p.y, accuracy: 0.0001)
            }
        }
    }

    func testVisibleWorldRect() {
        let t = CanvasTransform(zoom: 2, offset: CGPoint(x: 100, y: 50))
        let rect = t.visibleWorldRect(viewport: CGSize(width: 800, height: 600))
        XCTAssertEqual(rect.origin.x, -50)   // (0-100)/2
        XCTAssertEqual(rect.origin.y, -25)
        XCTAssertEqual(rect.width, 400)
        XCTAssertEqual(rect.height, 300)
    }

    // MARK: - Zoom about focus

    func testZoomAboutFocusKeepsFocalWorldPointStationary() {
        let start = CanvasTransform(zoom: 1, offset: CGPoint(x: 30, y: -60))
        let focus = CGPoint(x: 400, y: 300)
        let worldUnderFocus = start.toWorld(focus)

        let zoomed = VisionCanvasGeometry.zoomed(start, toZoom: 2.5, about: focus,
                                                 minZoom: 0.1, maxZoom: 5)
        let after = zoomed.toScreen(worldUnderFocus)
        XCTAssertEqual(after.x, focus.x, accuracy: 0.0001)
        XCTAssertEqual(after.y, focus.y, accuracy: 0.0001)
    }

    func testZoomClamps() {
        let t = CanvasTransform(zoom: 1, offset: .zero)
        XCTAssertEqual(VisionCanvasGeometry.zoomed(t, toZoom: 99, about: .zero,
                                                   minZoom: 0.1, maxZoom: 5).zoom, 5)
        XCTAssertEqual(VisionCanvasGeometry.zoomed(t, toZoom: 0.001, about: .zero,
                                                   minZoom: 0.1, maxZoom: 5).zoom, 0.1)
    }

    // MARK: - Anchored pan / drag (the runaway regressions)

    func testPannedOffsetIsIdempotentFromTheSameAnchor() {
        let start = CGPoint(x: 10, y: 20)
        let translation = CGSize(width: 55, height: -15)
        let first = VisionCanvasGeometry.pannedOffset(startOffset: start,
                                                      translation: translation)
        let second = VisionCanvasGeometry.pannedOffset(startOffset: start,
                                                       translation: translation)
        XCTAssertEqual(first, second, "same anchor + same translation = same result")
        XCTAssertEqual(first, CGPoint(x: 65, y: 5))
    }

    func testDraggedOriginIsIdempotentAndZoomScaled() {
        let start = CGPoint(x: 100, y: 100)
        let translation = CGSize(width: 50, height: 30)
        let a = VisionCanvasGeometry.draggedOrigin(startOrigin: start,
                                                   translation: translation,
                                                   zoom: 2, snap: nil)
        let b = VisionCanvasGeometry.draggedOrigin(startOrigin: start,
                                                   translation: translation,
                                                   zoom: 2, snap: nil)
        XCTAssertEqual(a, b, "runaway regression: no feedback from prior applications")
        XCTAssertEqual(a, CGPoint(x: 125, y: 115), "screen translation ÷ zoom")
    }

    func testDraggedOriginSnaps() {
        let p = VisionCanvasGeometry.draggedOrigin(
            startOrigin: CGPoint(x: 103, y: 96),
            translation: CGSize(width: 9, height: 9), zoom: 1, snap: 20)
        XCTAssertEqual(p, CGPoint(x: 120, y: 100))
    }

    // MARK: - Resize

    func testResizeBottomRightKeepsOrigin() {
        let rect = VisionCanvasGeometry.resizedRect(
            startRect: CGRect(x: 100, y: 100, width: 200, height: 160),
            corner: .bottomRight, translation: CGSize(width: 40, height: 20),
            zoom: 1, minSize: CGSize(width: 100, height: 80), snap: nil)
        XCTAssertEqual(rect, CGRect(x: 100, y: 100, width: 240, height: 180))
    }

    func testResizeTopLeftMovesOriginAndAnchorsBottomRight() {
        let start = CGRect(x: 100, y: 100, width: 200, height: 160)
        let rect = VisionCanvasGeometry.resizedRect(
            startRect: start, corner: .topLeft,
            translation: CGSize(width: 30, height: 20),
            zoom: 1, minSize: CGSize(width: 100, height: 80), snap: nil)
        XCTAssertEqual(rect.maxX, start.maxX, accuracy: 0.0001, "opposite corner fixed")
        XCTAssertEqual(rect.maxY, start.maxY, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 170)
        XCTAssertEqual(rect.height, 140)
    }

    func testResizeMinClampKeepsAnchorFixed() {
        let start = CGRect(x: 100, y: 100, width: 120, height: 90)
        // Try to shrink far below the minimum from the top-left.
        let rect = VisionCanvasGeometry.resizedRect(
            startRect: start, corner: .topLeft,
            translation: CGSize(width: 500, height: 500),
            zoom: 1, minSize: CGSize(width: 100, height: 80), snap: nil)
        XCTAssertEqual(rect.size, CGSize(width: 100, height: 80))
        XCTAssertEqual(rect.maxX, start.maxX, accuracy: 0.0001,
                       "clamping must not shove the card around")
        XCTAssertEqual(rect.maxY, start.maxY, accuracy: 0.0001)
    }

    func testResizeIsIdempotentFromTheSameAnchor() {
        let start = CGRect(x: 0, y: 0, width: 200, height: 200)
        let t = CGSize(width: 60, height: 60)
        let a = VisionCanvasGeometry.resizedRect(startRect: start, corner: .bottomRight,
                                                 translation: t, zoom: 2,
                                                 minSize: CGSize(width: 100, height: 80),
                                                 snap: nil)
        let b = VisionCanvasGeometry.resizedRect(startRect: start, corner: .bottomRight,
                                                 translation: t, zoom: 2,
                                                 minSize: CGSize(width: 100, height: 80),
                                                 snap: nil)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.size, CGSize(width: 230, height: 230))
    }

    // MARK: - Fit

    func testFitTransformContainsContentAndCapsAtFullSize() {
        let cards = [
            VisionCard(id: "1", canvasX: -200, canvasY: 300,
                       canvasWidth: 400, canvasHeight: 200),
            VisionCard(id: "2", canvasX: 900, canvasY: -100,
                       canvasWidth: 200, canvasHeight: 600),
        ]
        let bounds = VisionCanvasGeometry.boundingBox(of: cards)
        let viewport = CGSize(width: 800, height: 600)
        let t = VisionCanvasGeometry.fitTransform(contentBounds: bounds,
                                                  viewport: viewport, padding: 50,
                                                  minZoom: 0.1, maxZoom: 5)
        XCTAssertLessThanOrEqual(t.zoom, 1.0, "fit never zooms past 100%")
        // Every card corner lands inside the viewport.
        for corner in [CGPoint(x: -200, y: -100), CGPoint(x: 1100, y: 500)] {
            let screen = t.toScreen(corner)
            XCTAssertTrue((0...viewport.width).contains(screen.x), "\(screen)")
            XCTAssertTrue((0...viewport.height).contains(screen.y), "\(screen)")
        }
    }

    func testFitTransformEmptyBoardCentersOrigin() {
        let t = VisionCanvasGeometry.fitTransform(contentBounds: nil,
                                                  viewport: CGSize(width: 800, height: 600),
                                                  padding: 50, minZoom: 0.1, maxZoom: 5)
        XCTAssertEqual(t.zoom, 1.0)
        XCTAssertEqual(t.offset, CGPoint(x: 400, y: 300))
    }

    // MARK: - Placement

    func testPlacementCascadesOffExistingCards() {
        let size = CGSize(width: 200, height: 200)
        let existing = [CGRect(x: 100, y: 100, width: 200, height: 200)]
        let origin = VisionCanvasGeometry.placement(for: size, avoiding: existing,
                                                    preferredOrigin: CGPoint(x: 100, y: 100))
        XCTAssertFalse(existing[0].intersects(CGRect(origin: origin, size: size)))
        // Deterministic: same inputs, same slot.
        XCTAssertEqual(origin, VisionCanvasGeometry.placement(
            for: size, avoiding: existing, preferredOrigin: CGPoint(x: 100, y: 100)))
    }

    func testNextFreeGridSlotScansRowMajorAndWraps() {
        let size = CGSize(width: 200, height: 200)
        var existing: [CGRect] = []
        var slots: [CGPoint] = []
        for _ in 0..<6 {
            let slot = VisionCanvasGeometry.nextFreeGridSlot(
                cardSize: size, existing: existing,
                origin: .zero, pitch: CGSize(width: 220, height: 220), columns: 5)
            slots.append(slot)
            existing.append(CGRect(origin: slot, size: size))
        }
        XCTAssertEqual(slots[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(slots[1], CGPoint(x: 220, y: 0))
        XCTAssertEqual(slots[4], CGPoint(x: 880, y: 0))
        XCTAssertEqual(slots[5], CGPoint(x: 0, y: 220), "row wrap after 5 columns")
    }
}
