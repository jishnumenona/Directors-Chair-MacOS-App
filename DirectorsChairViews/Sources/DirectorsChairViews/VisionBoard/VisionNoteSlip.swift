// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionNoteSlip.swift
//
// The Wall, pass 2 — a note stuck under an element.
//
// On a real board a note isn't metadata hidden behind an inspector: it is
// a slip of paper taped under the photograph, in the director's own hand.
// One view, shared by the canvas and the exporter, so a note that is on
// the wall is on the printout too.

import SwiftUI

struct VisionNoteSlip: View {
    let text: String
    /// Exports of a large board scale everything down; the exporter passes
    /// a bigger value so the writing stays readable.
    var detail: CGFloat = 1

    var body: some View {
        Text(text)
            .font(.system(size: 10 * detail, design: .serif))
            .italic()
            .foregroundStyle(VisionWallPalette.ink.opacity(0.78))
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8 * detail)
            .padding(.vertical, 5 * detail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    VisionPaper.bond.base
                    VisionPaperTexture(paper: .bond)
                }
            )
            .clipShape(VisionTornPaper(torn: [.bottom],
                                       seed: VisionTornPaper.seed(for: text),
                                       depth: 2.2 * detail))
            .shadow(color: VisionWallPalette.scrapShadow,
                    radius: 3 * detail, y: 1.5 * detail)
            .rotationEffect(.degrees(0.8))
    }
}
