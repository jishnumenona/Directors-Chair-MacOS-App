// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionTornPaper.swift
//
// The Wall, pass 2 — the torn edge.
//
// Research finding worth one shape: "a straight digital crop looks fake;
// the torn edge is the secret to a believable collage." A word clipping
// cut with a ruler reads as a UI label. This gives paper a ragged edge
// that is deterministic per scrap (same scrap, same tear, every launch)
// and cheap enough to draw at any zoom.

import SwiftUI

public struct VisionTornPaper: Shape {
    /// Which sides are torn; the rest are clean cuts (scissors, not hands).
    public var torn: Edge.Set
    /// Stable per-scrap variation — pass the card id's hash.
    public var seed: UInt64
    /// How deep the tear bites, in points.
    public var depth: CGFloat

    public init(torn: Edge.Set = .all, seed: UInt64 = 1, depth: CGFloat = 3.5) {
        self.torn = torn
        self.seed = seed
        self.depth = depth
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        var state = seed &* 1099511628211 &+ 14695981039346656

        /// Deterministic −1…1.
        func wobble() -> CGFloat {
            state = (state ^ (state >> 13)) &* 1099511628211
            return CGFloat(state % 2001) / 1000.0 - 1.0
        }

        let step: CGFloat = 11
        func edgePoints(from start: CGPoint, to end: CGPoint,
                        ragged: Bool) -> [CGPoint] {
            guard ragged else { return [end] }
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = max(hypot(dx, dy), 1)
            let count = max(Int(length / step), 2)
            // Unit normal, so the tear bites inward/outward across the edge.
            let nx = -dy / length
            let ny = dx / length
            return (1...count).map { index in
                let t = CGFloat(index) / CGFloat(count)
                let bite = index == count ? 0 : wobble() * depth
                return CGPoint(x: start.x + dx * t + nx * bite,
                               y: start.y + dy * t + ny * bite)
            }
        }

        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)

        // One continuous outline. NOTE: Path.addLines starts a NEW subpath
        // at its first point, which would leave four disconnected polylines
        // and a clip that erases everything inside — add each point.
        path.move(to: topLeft)
        for point in edgePoints(from: topLeft, to: topRight,
                                ragged: torn.contains(.top)) {
            path.addLine(to: point)
        }
        for point in edgePoints(from: topRight, to: bottomRight,
                                ragged: torn.contains(.trailing)) {
            path.addLine(to: point)
        }
        for point in edgePoints(from: bottomRight, to: bottomLeft,
                                ragged: torn.contains(.bottom)) {
            path.addLine(to: point)
        }
        for point in edgePoints(from: bottomLeft, to: topLeft,
                                ragged: torn.contains(.leading)) {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    /// Stable hash for a scrap id — never Swift's per-process `Hasher`, so
    /// a tear looks the same tomorrow.
    public static func seed(for id: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in id.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return hash
    }
}
