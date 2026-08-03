// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionRadialMenu.swift
//
// The Wall, pass 2 — the tools come to your hand.
//
// Right-click anywhere on the wall and the tools bloom in a ring around
// the cursor, so the thing you reach for is already where your hand is.
// They are paper chips with ink glyphs, not a system menu: the wall has
// one material and the tools belong to it.

import SwiftUI

/// One chip on a ring. Both rings — the wall's and a scrap's — are the
/// same object with different contents.
struct VisionRingItem: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    var destructive: Bool = false
}

struct VisionRadialMenu: View {
    /// Where the ring is centred, in canvas (screen) points.
    let anchor: CGPoint
    let items: [VisionRingItem]
    let onPick: (String) -> Void
    let onDismiss: () -> Void

    @State private var bloomed = false
    @State private var hovered: String?

    private static let radius: CGFloat = 78
    private static let chip: CGFloat = 46


    var body: some View {
        ZStack {
            // Anywhere else on the wall dismisses — including a second
            // right-click, which feels like putting the tools back down.
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            ZStack {
                centreDot
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    chipView(item, at: offset(for: index))
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
        VisionRadialGeometry.positions(count: items.count,
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

    private func chipView(_ item: VisionRingItem, at point: CGPoint) -> some View {
        let isHovered = hovered == item.id
        let accent = item.destructive ? Color(hex: "#B3352C")
                                      : VisionWallPalette.greasePencil
        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isHovered ? accent : VisionWallPalette.clipping)
                    .shadow(color: VisionWallPalette.scrapShadow,
                            radius: isHovered ? 9 : 5,
                            y: isHovered ? 4 : 2)
                Image(systemName: item.systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isHovered ? VisionWallPalette.clipping
                                               : VisionWallPalette.ink)
            }
            .frame(width: Self.chip, height: Self.chip)

            Text(item.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(VisionWallPalette.ink.opacity(isHovered ? 1 : 0.72))
                .fixedSize()
        }
        .scaleEffect(isHovered ? 1.12 : 1)
        .offset(x: bloomed ? point.x : 0, y: bloomed ? point.y : 0)
        .opacity(bloomed ? 1 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            hovered = hovering ? item.id : (hovered == item.id ? nil : hovered)
        }
        .onTapGesture { onPick(item.id) }
        .accessibilityLabel(item.title)
    }
}
