// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionWallSurface.swift
//
// The Wall, pass 2 — a surface that goes on forever.
//
// The canvas was always mathematically unbounded: pan just adds to an
// offset with nothing clamping it. But the wall LOOKED frozen, because the
// plaster was a static gradient painted on the viewport — pan slid the
// scraps across a backdrop that never moved, so the board felt like a page
// rather than a wall you can walk along.
//
// Fixed by giving the plaster its own place in the world:
//   · the grain scrolls with the pan (the motion cue that was missing),
//   · sparse marks — scuffs, old tack holes, patches — are generated per
//     world cell, so wherever you go there is something to tell you that
//     you moved, and it is the SAME something when you come back,
//   · only the light stays with the viewer, the way light does.
//
// Marks are procedural per cell, so nothing is stored and the wall is
// genuinely endless in every direction.

import SwiftUI

struct VisionWallSurface: View {
    let transform: CanvasTransform
    /// Grain tile size in screen points.
    private static let grainTile: CGFloat = 96
    /// World size of a cell that carries its own marks.
    private static let cell: CGFloat = 620

    var body: some View {
        ZStack {
            LinearGradient(colors: VisionWallPalette.surface,
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            // Grain travels with the wall — this is what makes panning
            // read as movement instead of a frozen backdrop.
            GeometryReader { geometry in
                Image(nsImage: Self.grain)
                    .resizable(resizingMode: .tile)
                    .frame(width: geometry.size.width + Self.grainTile * 2,
                           height: geometry.size.height + Self.grainTile * 2)
                    .offset(x: phase(transform.offset.x) - Self.grainTile,
                            y: phase(transform.offset.y) - Self.grainTile)
                    .opacity(0.17)
                    .blendMode(.multiply)
            }
            .allowsHitTesting(false)

            // The wall's own history, in world space.
            Canvas { context, size in
                draw(marks: &context, viewport: size)
            }
            .allowsHitTesting(false)

            // Light belongs to the viewer, not the wall, so it stays put.
            RadialGradient(colors: [.clear, Color(hex: "#4A3B26").opacity(0.18)],
                           center: .center, startRadius: 240, endRadius: 900)
                .allowsHitTesting(false)
        }
    }

    private func phase(_ offset: CGFloat) -> CGFloat {
        let tile = Self.grainTile
        let value = offset.truncatingRemainder(dividingBy: tile)
        return value < 0 ? value + tile : value
    }

    /// Every cell of the world carries a few faint marks, derived from its
    /// coordinates — so the wall is endless, needs no storage, and looks
    /// the same each time you pass.
    private func draw(marks context: inout GraphicsContext, viewport: CGSize) {
        guard transform.zoom > 0.12 else { return }   // too far out to read
        let visible = transform.visibleWorldRect(viewport: viewport)
        let cell = Self.cell
        let firstColumn = Int(floor(visible.minX / cell))
        let lastColumn = Int(floor(visible.maxX / cell))
        let firstRow = Int(floor(visible.minY / cell))
        let lastRow = Int(floor(visible.maxY / cell))
        // A screenful is a handful of cells; the guard stops a pathological
        // zoom-out from drawing thousands.
        guard (lastColumn - firstColumn + 1) * (lastRow - firstRow + 1) <= 400
        else { return }

        for column in firstColumn...lastColumn {
            for row in firstRow...lastRow {
                var hash = Self.seed(column: column, row: row)
                let count = Int(hash % 3) + 1
                for _ in 0..<count {
                    hash = (hash ^ (hash >> 11)) &* 1099511628211
                    let worldX = CGFloat(column) * cell
                        + CGFloat(hash % UInt64(cell))
                    let worldY = CGFloat(row) * cell
                        + CGFloat((hash >> 17) % UInt64(cell))
                    let point = transform.toScreen(CGPoint(x: worldX, y: worldY))
                    let kind = hash % 5

                    if kind == 0 {
                        // An old tack hole someone left behind.
                        let radius = 1.6 * transform.zoom
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - radius,
                                                   y: point.y - radius,
                                                   width: radius * 2,
                                                   height: radius * 2)),
                            with: .color(Color(hex: "#6B573A").opacity(0.30)))
                    } else if kind == 1 {
                        // A scuff.
                        let length = (16 + CGFloat(hash % 40)) * transform.zoom
                        context.stroke(
                            Path {
                                $0.move(to: point)
                                $0.addLine(to: CGPoint(x: point.x + length,
                                                       y: point.y + length * 0.16))
                            },
                            with: .color(Color(hex: "#8A7350").opacity(0.10)),
                            lineWidth: max(0.6, 1.1 * transform.zoom))
                    } else {
                        // A patch where the plaster dried differently.
                        let radius = (30 + CGFloat(hash % 90)) * transform.zoom
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - radius,
                                                   y: point.y - radius,
                                                   width: radius * 2,
                                                   height: radius * 2)),
                            with: .color(Color(hex: "#B7A181").opacity(0.055)))
                    }
                }
            }
        }
    }

    /// Stable per cell — walk away and come back, the wall is unchanged.
    static func seed(column: Int, row: Int) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for value in [UInt64(bitPattern: Int64(column)),
                      UInt64(bitPattern: Int64(row))] {
            hash = (hash ^ value) &* 1099511628211
            hash ^= hash >> 29
        }
        return hash
    }

    /// One tileable grain swatch, generated once. Deterministic (a fixed
    /// FNV walk, never `random`) so the wall looks identical every launch.
    static let grain: NSImage = {
        let side = Int(grainTile)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        var hash: UInt64 = 1469598103934665603
        for y in 0..<side {
            for x in 0..<side {
                hash = (hash ^ UInt64(truncatingIfNeeded: x &* 31 &+ y)) &* 1099511628211
                guard hash % 7 == 0 else { continue }
                let alpha = Double((hash >> 8) % 40) / 400.0
                NSColor(white: 0.35, alpha: alpha).setFill()
                NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1).fill()
            }
        }
        image.unlockFocus()
        return image
    }()
}
