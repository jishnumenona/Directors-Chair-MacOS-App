// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionThumbtack.swift
//
// The Wall, pass 2 — the tack that holds a scrap up.
//
// Drawn rather than an SF Symbol: a tack is a dome with a highlight, a
// shadow cast on the paper below it, and a colour. Symbols read as UI
// glyphs; this reads as an object sitting on top of the sheet.

import SwiftUI

public struct VisionThumbtack: View {
    /// Head diameter in points, before canvas zoom.
    public var size: CGFloat
    /// Pressed tacks sit flatter and darker — that's how a locked scrap
    /// says it's held down harder.
    public var pressed: Bool
    public var tint: Color

    public init(size: CGFloat = 15, pressed: Bool = false,
                tint: Color = VisionWallPalette.greasePencil) {
        self.size = size
        self.pressed = pressed
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            // The shadow the head casts onto the paper.
            Circle()
                .fill(Color.black.opacity(pressed ? 0.34 : 0.26))
                .frame(width: size * 0.92, height: size * 0.92)
                .offset(x: size * 0.10, y: size * 0.14)
                .blur(radius: size * 0.09)

            // The dome, lit from the top left like everything on this wall.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.95), tint,
                                 tint.opacity(pressed ? 0.75 : 0.55)],
                        center: UnitPoint(x: 0.34, y: 0.3),
                        startRadius: 0, endRadius: size * 0.62)
                )
                .frame(width: size, height: size)

            // A single specular highlight sells the plastic.
            Circle()
                .fill(Color.white.opacity(pressed ? 0.35 : 0.6))
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: -size * 0.19, y: -size * 0.21)
                .blur(radius: size * 0.03)

            Circle()
                .strokeBorder(Color.black.opacity(0.18), lineWidth: size * 0.05)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .scaleEffect(pressed ? 0.88 : 1)
        .accessibilityHidden(true)
    }
}
