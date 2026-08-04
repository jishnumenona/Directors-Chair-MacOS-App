// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionPendingSheet.swift
//
// The Wall, pass 2 — space held while a picture is imagined.
//
// Generating used to put a spinner in the middle of the wall and stop
// everything. But you don't stand and watch a photograph develop: you pin
// up a blank sheet where it will go and carry on. This is that sheet —
// tacked up like anything else, quietly working, and replaced by the real
// picture when it arrives.

import SwiftUI

struct VisionPendingSheet: View {
    let pending: PendingImagine

    @State private var sweep = false

    var body: some View {
        ZStack {
            VisionPaper.bond.base
            VisionPaperTexture(paper: .bond)

            // Something is happening here — a slow band of light moving
            // across the sheet, not a spinner demanding attention.
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.75), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing)
                .rotationEffect(.degrees(18))
                .offset(x: sweep ? pending.size.width : -pending.size.width)
                .blendMode(.overlay)

            VStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VisionWallPalette.greasePencil.opacity(0.75))
                Text(pending.prompt)
                    .font(.system(size: 10.5, design: .serif))
                    .italic()
                    .foregroundStyle(VisionWallPalette.ink.opacity(0.6))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .frame(width: pending.size.width, height: pending.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(VisionWallPalette.ink.opacity(0.12),
                              style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .shadow(color: VisionWallPalette.scrapShadow, radius: 6, y: 3)
        .overlay(alignment: .top) {
            VisionThumbtack(size: 15).offset(y: -6)
        }
        .rotationEffect(.degrees(-1.1), anchor: .top)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                sweep = true
            }
        }
        .accessibilityLabel("Imagining \(pending.prompt)")
    }
}
