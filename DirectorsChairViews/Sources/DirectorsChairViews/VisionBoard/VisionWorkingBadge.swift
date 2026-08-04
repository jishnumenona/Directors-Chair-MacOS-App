// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionWorkingBadge.swift
//
// The Wall, pass 2 — something is happening to this element.
//
// Work on one element is said ON that element, in its bottom-right
// corner, so the picture stays visible while it happens. A paper chip
// with a turning arc: the same material as everything else on the wall,
// and small enough that several can be working at once without the board
// turning into a progress dashboard.

import SwiftUI

struct VisionWorkingBadge: View {
    /// Diameter in world points before the canvas zoom is applied.
    var size: CGFloat = 22

    @State private var turning = false

    var body: some View {
        ZStack {
            Circle()
                .fill(VisionWallPalette.clipping)
                .shadow(color: VisionWallPalette.scrapShadow,
                        radius: size * 0.14, y: size * 0.07)

            // The track it turns against.
            Circle()
                .strokeBorder(VisionWallPalette.ink.opacity(0.13),
                              lineWidth: size * 0.11)
                .padding(size * 0.19)

            // A grease-pencil arc, sweeping.
            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(VisionWallPalette.greasePencil,
                        style: StrokeStyle(lineWidth: size * 0.11,
                                           lineCap: .round))
                .padding(size * 0.19)
                .rotationEffect(.degrees(turning ? 360 : 0))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                turning = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Working")
    }
}
