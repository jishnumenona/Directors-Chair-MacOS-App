// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionCanvasGeometry.swift
//
// Vision Board repair, Slice 1: the ONE coordinate model for the canvas.
// Pure CoreGraphics — no SwiftUI state — so every formula that was
// previously scattered (and disagreeing) across the canvas, the card view,
// and the view model is unit-testable here.
//
// The model: an unbounded world plane of card rects (canvasX/Y = top-left
// in world points, persisted unchanged) viewed through a single transform:
//
//     screen = world × zoom + offset
//
// All gestures are ANCHORED: state is captured once at gesture start and
// every update derives from (start, cumulative translation) — never from
// the already-mutated model, which was the root cause of the runaway
// drag/resize feedback loops.

import CoreGraphics
import DirectorsChairCore

// MARK: - Transform

public struct CanvasTransform: Equatable, Sendable {
    public var zoom: CGFloat
    public var offset: CGPoint   // screen-space position of the world origin

    public init(zoom: CGFloat = 1.0, offset: CGPoint = .zero) {
        self.zoom = zoom
        self.offset = offset
    }

    public func toScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y)
    }

    public func toWorld(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - offset.x) / zoom, y: (p.y - offset.y) / zoom)
    }

    /// The world-space rectangle currently visible in a viewport.
    public func visibleWorldRect(viewport: CGSize) -> CGRect {
        let origin = toWorld(.zero)
        return CGRect(origin: origin,
                      size: CGSize(width: viewport.width / zoom,
                                   height: viewport.height / zoom))
    }
}

// MARK: - Geometry operations

public enum VisionCanvasGeometry {

    // MARK: Pan / zoom

    /// Anchored pan: same translation from the same start → same result.
    public static func pannedOffset(startOffset: CGPoint,
                                    translation: CGSize) -> CGPoint {
        CGPoint(x: startOffset.x + translation.width,
                y: startOffset.y + translation.height)
    }

    /// Zoom keeping the world point under the focal SCREEN point stationary.
    public static func zoomed(_ t: CanvasTransform, toZoom: CGFloat,
                              about focus: CGPoint,
                              minZoom: CGFloat, maxZoom: CGFloat) -> CanvasTransform {
        let newZoom = min(max(toZoom, minZoom), maxZoom)
        let ratio = newZoom / t.zoom
        let offset = CGPoint(x: focus.x - (focus.x - t.offset.x) * ratio,
                             y: focus.y - (focus.y - t.offset.y) * ratio)
        return CanvasTransform(zoom: newZoom, offset: offset)
    }

    // MARK: Card drag / resize (anchored)

    /// New world origin for a dragged card. `translation` is measured in
    /// unscaled screen points (the named canvas coordinate space).
    public static func draggedOrigin(startOrigin: CGPoint, translation: CGSize,
                                     zoom: CGFloat, snap: CGFloat?) -> CGPoint {
        var p = CGPoint(x: startOrigin.x + translation.width / zoom,
                        y: startOrigin.y + translation.height / zoom)
        if let snap, snap > 0 {
            p.x = (p.x / snap).rounded() * snap
            p.y = (p.y / snap).rounded() * snap
        }
        return p
    }

    /// New world rect for a corner resize. The corner OPPOSITE the grabbed
    /// one stays fixed, including when the minimum size clamps.
    public static func resizedRect(startRect: CGRect, corner: ResizeCorner,
                                   translation: CGSize, zoom: CGFloat,
                                   minSize: CGSize, snap: CGFloat?) -> CGRect {
        let dx = translation.width / zoom
        let dy = translation.height / zoom

        var width: CGFloat
        var height: CGFloat
        switch corner {
        case .topLeft:     width = startRect.width - dx; height = startRect.height - dy
        case .topRight:    width = startRect.width + dx; height = startRect.height - dy
        case .bottomLeft:  width = startRect.width - dx; height = startRect.height + dy
        case .bottomRight: width = startRect.width + dx; height = startRect.height + dy
        }
        if let snap, snap > 0 {
            width = (width / snap).rounded() * snap
            height = (height / snap).rounded() * snap
        }
        width = max(minSize.width, width)
        height = max(minSize.height, height)

        // Re-derive the origin from the fixed (opposite) corner so clamping
        // and snapping never shove the card around.
        var origin = startRect.origin
        switch corner {
        case .topLeft:
            origin = CGPoint(x: startRect.maxX - width, y: startRect.maxY - height)
        case .topRight:
            origin = CGPoint(x: startRect.minX, y: startRect.maxY - height)
        case .bottomLeft:
            origin = CGPoint(x: startRect.maxX - width, y: startRect.minY)
        case .bottomRight:
            origin = startRect.origin
        }
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    // MARK: Fit / bounds

    public static func boundingBox(of cards: [VisionCard]) -> CGRect? {
        var box: CGRect?
        for card in cards {
            let rect = CGRect(x: card.canvasX ?? 0, y: card.canvasY ?? 0,
                              width: card.canvasWidth ?? 200,
                              height: card.canvasHeight ?? 200)
            box = box.map { $0.union(rect) } ?? rect
        }
        return box
    }

    /// One formula for fit / reset / board-switch centering.
    /// Empty content or zero viewport → identity zoom, content centered on
    /// the viewport center (world origin under the center for empty boards).
    public static func fitTransform(contentBounds: CGRect?, viewport: CGSize,
                                    padding: CGFloat, minZoom: CGFloat,
                                    maxZoom: CGFloat) -> CanvasTransform {
        let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        guard let bounds = contentBounds, viewport.width > 0, viewport.height > 0 else {
            return CanvasTransform(zoom: 1.0, offset: center)
        }
        let padded = bounds.insetBy(dx: -padding, dy: -padding)
        let zoom = min(max(min(viewport.width / padded.width,
                               viewport.height / padded.height), minZoom), 1.0)
        let bboxCenter = CGPoint(x: padded.midX, y: padded.midY)
        let offset = CGPoint(x: center.x - bboxCenter.x * zoom,
                             y: center.y - bboxCenter.y * zoom)
        return CanvasTransform(zoom: zoom, offset: offset)
    }

    // MARK: Placement

    /// Cascades from a preferred origin by `step` until the rect intersects
    /// no existing card. Deterministic for a given input.
    public static func placement(for size: CGSize, avoiding existing: [CGRect],
                                 preferredOrigin: CGPoint,
                                 step: CGFloat = 24) -> CGPoint {
        var origin = preferredOrigin
        var attempts = 0
        while attempts < 500 {
            let candidate = CGRect(origin: origin, size: size)
            if !existing.contains(where: { $0.intersects(candidate) }) {
                return origin
            }
            origin.x += step
            origin.y += step
            attempts += 1
        }
        return origin
    }

    /// Where a handful of dropped scraps land: a loose pile around the
    /// drop point, NOT a grid. Positions follow a golden-angle spiral, so
    /// the scatter reads as hand-dropped yet is deterministic (same drop,
    /// same arrangement — and unit-testable). The first scrap sits exactly
    /// under the cursor; later ones fan outward.
    public static func pileOrigins(sizes: [CGSize], around center: CGPoint,
                                   spread: CGFloat = 44) -> [CGPoint] {
        let goldenAngle: CGFloat = 2.399963229728653
        return sizes.enumerated().map { index, size in
            let radius = spread * sqrt(CGFloat(index))
            let angle = goldenAngle * CGFloat(index)
            return CGPoint(x: center.x + cos(angle) * radius - size.width / 2,
                           y: center.y + sin(angle) * radius - size.height / 2)
        }
    }

    /// Row-major scan over a grid; returns the first slot whose rect
    /// intersects no existing card. Used for programmatic placement (the
    /// assistant has no viewport).
    public static func nextFreeGridSlot(cardSize: CGSize, existing: [CGRect],
                                        origin: CGPoint = .zero,
                                        pitch: CGSize = CGSize(width: 220, height: 220),
                                        columns: Int = 5) -> CGPoint {
        var row = 0
        while row < 1000 {
            for column in 0..<columns {
                let slot = CGPoint(x: origin.x + CGFloat(column) * pitch.width,
                                   y: origin.y + CGFloat(row) * pitch.height)
                let candidate = CGRect(origin: slot, size: cardSize)
                if !existing.contains(where: { $0.intersects(candidate) }) {
                    return slot
                }
            }
            row += 1
        }
        return origin
    }
}
