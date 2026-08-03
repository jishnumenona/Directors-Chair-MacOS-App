// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionRadialMenu.swift
//
// The Wall, pass 2 — the tools come to your hand.
//
// Right-click anywhere on the wall and the tools bloom in a ring around
// the cursor, so the thing you reach for is already where your hand is.
// They are paper chips with ink glyphs, not a system menu: the wall has
// one material and the tools belong to it.

import SwiftUI

struct VisionRadialMenu: View {
    /// Where the ring is centred, in canvas (screen) points.
    let anchor: CGPoint
    let onPick: (VisionWallTool) -> Void
    let onDismiss: () -> Void

    @State private var bloomed = false
    @State private var hovered: VisionWallTool?

    private static let radius: CGFloat = 78
    private static let chip: CGFloat = 46

    private var tools: [VisionWallTool] { VisionWallTool.ringOrder }

    var body: some View {
        ZStack {
            // Anywhere else on the wall dismisses — including a second
            // right-click, which feels like putting the tools back down.
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            ZStack {
                centreDot
                ForEach(Array(tools.enumerated()), id: \.element) { index, tool in
                    chipView(tool, at: offset(for: index))
                }
            }
            .position(anchor)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                bloomed = true
            }
        }
        .onExitCommand(perform: onDismiss)
    }

    private func offset(for index: Int) -> CGPoint {
        VisionRadialGeometry.positions(count: tools.count,
                                       radius: Self.radius)[index]
    }

    /// The pinhole the ring blooms out of.
    private var centreDot: some View {
        Circle()
            .fill(VisionWallPalette.ink.opacity(0.25))
            .frame(width: 7, height: 7)
            .scaleEffect(bloomed ? 1 : 0.2)
            .opacity(bloomed ? 1 : 0)
    }

    private func chipView(_ tool: VisionWallTool, at point: CGPoint) -> some View {
        let isHovered = hovered == tool
        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isHovered
                          ? VisionWallPalette.greasePencil
                          : VisionWallPalette.clipping)
                    .shadow(color: VisionWallPalette.scrapShadow,
                            radius: isHovered ? 9 : 5,
                            y: isHovered ? 4 : 2)
                Image(systemName: tool.systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isHovered ? VisionWallPalette.clipping
                                               : VisionWallPalette.ink)
            }
            .frame(width: Self.chip, height: Self.chip)

            Text(tool.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(VisionWallPalette.ink.opacity(isHovered ? 1 : 0.72))
                .fixedSize()
        }
        .scaleEffect(isHovered ? 1.12 : 1)
        .offset(x: bloomed ? point.x : 0, y: bloomed ? point.y : 0)
        .opacity(bloomed ? 1 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            hovered = hovering ? tool : (hovered == tool ? nil : hovered)
        }
        .onTapGesture { onPick(tool) }
        .accessibilityLabel(tool.title)
    }
}
