// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionNoteSlip.swift
//
// The Wall, pass 2 — a sticky note.
//
// A note has to be unmistakable at a glance: not another paper clipping,
// not a caption. So it is the thing everyone already knows — a square of
// yellow stuck squint over the corner of the work, the adhesive band
// darker across the top, one corner lifted, and a shadow that grows
// toward the lift the way a real one does.
//
// One view, shared by the canvas and the exporter, so a note on the wall
// is a note on the printout.

import SwiftUI

struct VisionNoteSlip: View {
    let text: String
    /// Exports of a large board scale everything down; the exporter passes
    /// a bigger value so the writing stays readable.
    var detail: CGFloat = 1

    /// A hastily stuck note is never square to the world. Stable per note.
    private var tilt: Double {
        let hash = VisionTornPaper.seed(for: text)
        return Double(hash % 900) / 100.0 - 4.5      // −4.5°…4.5°
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11 * detail, weight: .medium))
            .foregroundStyle(Color(hex: "#3A3222"))
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 10 * detail)
            .padding(.top, 14 * detail)          // clear of the adhesive band
            .padding(.bottom, 12 * detail)
            .background(sticky)
            .overlay(liftedCorner, alignment: .bottomTrailing)
            .compositingGroup()
            // Heavier under the lifted corner, the way a curled note casts.
            .shadow(color: Color(hex: "#4A3B26").opacity(0.34),
                    radius: 4 * detail, x: 1.5 * detail, y: 3 * detail)
            .rotationEffect(.degrees(tilt))
    }

    private var sticky: some View {
        ZStack {
            VisionPaper.sticky.base
            VisionPaperTexture(paper: .sticky)
            // Cheap paper takes the light unevenly.
            LinearGradient(
                colors: [Color.white.opacity(0.20), .clear,
                         Color(hex: "#C9B93F").opacity(0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// The corner that never quite stays down.
    private var liftedCorner: some View {
        Path { path in
            let size = 13 * detail
            path.move(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: size, y: size))
            path.addLine(to: CGPoint(x: 0, y: size))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(colors: [Color(hex: "#E8D95C"),
                                    Color(hex: "#BFAF43")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .frame(width: 13 * detail, height: 13 * detail)
    }
}
