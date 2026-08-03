// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionWallHint.swift
//
// The Wall, pass 2 — the note that is already pinned up.
//
// Capture is three gestures and no buttons, which is the point: a wall
// doesn't have an "add" control. The cost is that a bare wall says
// nothing, and the owner had to ask how to put anything on it.
//
// So the wall comes with a note pinned to it. It is a real element in the
// world — paper, tack, shadow, tilt — not a UI overlay, and it comes down
// by itself the moment the first real element lands.

import SwiftUI

struct VisionWallHint: View {
    /// Ways onto the wall, in the order someone reaches for them.
    private static let ways: [(icon: String, gesture: String, result: String)] = [
        ("hand.draw", "Drag a picture in", "from Finder, a browser, anywhere"),
        ("cursorarrow.click.2", "Double-click the wall", "and write a word"),
        ("hand.point.up.left", "Right-click", "for pictures, links, video, and Imagine"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Nothing up yet")
                .font(.system(size: 19, weight: .black))
                .fontWidth(.condensed)
                .foregroundStyle(VisionPaper.ruled.ink)

            VStack(alignment: .leading, spacing: 11) {
                ForEach(Self.ways, id: \.gesture) { way in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: way.icon)
                            // Some cursor symbols render multicolour and
                            // ignore the tint, going invisible on paper.
                            .symbolRenderingMode(.monochrome)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VisionWallPalette.greasePencil)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(way.gesture)
                                .font(.system(size: 13, weight: .semibold))
                            Text(way.result)
                                .font(.system(size: 11))
                                .foregroundStyle(VisionPaper.ruled.ink.opacity(0.6))
                        }
                    }
                }
            }
            .foregroundStyle(VisionPaper.ruled.ink)

            Text("Everything you put up can be moved, turned, pinned and tied together.")
                .font(.system(size: 10.5, design: .serif))
                .italic()
                .foregroundStyle(VisionPaper.ruled.ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 20)
        .frame(width: 320, alignment: .leading)
        .background(
            ZStack {
                VisionPaper.ruled.base
                VisionPaperTexture(paper: .ruled)
            }
        )
        .clipShape(VisionTornPaper(torn: [.bottom],
                                   seed: VisionTornPaper.seed(for: "wall-hint")))
        .shadow(color: VisionWallPalette.scrapShadow, radius: 9, y: 5)
        .overlay(alignment: .top) {
            VisionThumbtack(size: 15)
                .offset(y: -6)
        }
        .rotationEffect(.degrees(-1.4), anchor: .top)
        .environment(\.colorScheme, .light)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("How to put something on the wall: drag a picture in, "
                            + "double-click to write, or right-click for the tools.")
    }
}
