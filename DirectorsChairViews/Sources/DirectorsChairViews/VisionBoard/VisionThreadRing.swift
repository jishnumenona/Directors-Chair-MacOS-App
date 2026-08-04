// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionThreadRing.swift
//
// The Wall — the tools for a cord.
//
// Right-clicking a thread used to bloom the wall's making tools AND a
// system context menu on top of them, which is neither: the wall's ring
// offers to make things, and none of it applies to a piece of string.
//
// So a cord gets its own ring. Colour is the outer ring — eight lengths
// of real twine you pick by looking at, because that is how you pick
// thread — and thickness sits in the middle, where the cord you are
// changing is drawn live at the weight you are choosing.

import SwiftUI
import DirectorsChairCore

struct VisionThreadRing: View {
    let anchor: CGPoint
    let connector: VisionConnector
    let onPickThread: (VisionThread) -> Void
    let onSetThickness: (Double) -> Void
    let onRename: () -> Void
    let onCut: () -> Void
    let onDismiss: () -> Void

    @State private var bloomed = false
    @State private var hovered: VisionThread?

    private static let radius: CGFloat = 116
    private static let chip: CGFloat = 40

    /// The weights a cord comes in: button thread through to parcel
    /// string. Stepped, not a slider — you are choosing a material, and
    /// there is no meaningful difference between 5.0 and 5.2.
    static let weights: [Double] = [2.5, 4, 5, 7, 9.5]

    private var thread: VisionThread {
        VisionThread.resolve(connector.thread)
    }

    private var thickness: Double {
        connector.thickness ?? 5
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            ZStack {
                centre
                ForEach(Array(VisionThread.allCases.enumerated()),
                        id: \.element.id) { index, twine in
                    chip(twine, at: offset(for: index))
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
        VisionRadialGeometry.positions(count: VisionThread.allCases.count,
                                       radius: Self.radius)[index]
    }

    // MARK: - Colour, as cord

    private func chip(_ twine: VisionThread, at point: CGPoint) -> some View {
        let chosen = thread == twine
        let isHovered = hovered == twine
        return ZStack {
            Circle()
                .fill(VisionWallPalette.clipping)
                .shadow(color: VisionWallPalette.scrapShadow,
                        radius: isHovered ? 9 : 5, y: isHovered ? 4 : 2)
            // A faint bed, or pale twine — cotton especially — vanishes
            // into paper of almost the same value.
            Circle()
                .fill(VisionWallPalette.ink.opacity(0.07))
                .padding(3)
            // A wound reel of the actual twine, drawn by the one view
            // that knows how cord looks.
            VisionCordStrokes(cord: Path { path in
                path.move(to: CGPoint(x: 9, y: 17))
                path.addQuadCurve(to: CGPoint(x: Self.chip - 9, y: 17),
                                  control: CGPoint(x: Self.chip / 2, y: 30))
            }, thickness: 6, thread: twine)
                .frame(width: Self.chip, height: Self.chip)
            Circle()
                .strokeBorder(VisionWallPalette.greasePencil,
                              lineWidth: chosen ? 2.5 : 0)
        }
        .frame(width: Self.chip, height: Self.chip)
        .scaleEffect(isHovered ? 1.14 : 1)
        .offset(x: bloomed ? point.x : 0, y: bloomed ? point.y : 0)
        .opacity(bloomed ? 1 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            hovered = hovering ? twine : (hovered == twine ? nil : hovered)
        }
        .onTapGesture { onPickThread(twine) }
        .help(twine.displayName)
        .accessibilityLabel("\(twine.displayName) thread")
    }

    // MARK: - Thickness, in the middle

    private var centre: some View {
        VStack(spacing: 6) {
            Text(hovered?.displayName ?? thread.displayName)
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VisionWallPalette.ink.opacity(0.6))

            // The cord you are changing, at the weight you are choosing.
            VisionCordStrokes(cord: Path { path in
                path.move(to: CGPoint(x: 5, y: 8))
                path.addQuadCurve(to: CGPoint(x: 63, y: 8),
                                  control: CGPoint(x: 34, y: 24))
            }, thickness: CGFloat(thickness), thread: hovered ?? thread)
                .frame(width: 68, height: 24)

            HStack(spacing: 10) {
                weightButton("minus", enabled: thickness > Self.weights.first!) {
                    onSetThickness(Self.step(from: thickness, by: -1))
                }
                Text(Self.weightName(thickness))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VisionWallPalette.ink.opacity(0.75))
                    .frame(width: 42)
                weightButton("plus", enabled: thickness < Self.weights.last!) {
                    onSetThickness(Self.step(from: thickness, by: 1))
                }
            }

            HStack(spacing: 8) {
                textButton("Name", action: onRename)
                textButton("Cut", destructive: true, action: onCut)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(VisionWallPalette.clipping,
                    in: RoundedRectangle(cornerRadius: 13))
        // A hairline so the hub reads as its own piece of paper rather
        // than melting into the chips, which share its colour.
        .overlay(RoundedRectangle(cornerRadius: 13)
            .strokeBorder(VisionWallPalette.ink.opacity(0.14), lineWidth: 1))
        .shadow(color: VisionWallPalette.scrapShadow, radius: 11, y: 5)
        .environment(\.colorScheme, .light)
        .scaleEffect(bloomed ? 1 : 0.4)
        .opacity(bloomed ? 1 : 0)
    }

    private func weightButton(_ symbol: String, enabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(VisionWallPalette.ink.opacity(enabled ? 0.8 : 0.25))
                .frame(width: 20, height: 18)
                .background(VisionWallPalette.ink.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func textButton(_ title: String, destructive: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(destructive ? Color(hex: "#B3352C")
                                             : VisionWallPalette.ink.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(VisionWallPalette.ink.opacity(0.06),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weights

    /// Moves one notch along the weights, staying inside them.
    static func step(from current: Double, by delta: Int) -> Double {
        let nearest = weights.enumerated().min {
            abs($0.element - current) < abs($1.element - current)
        }?.offset ?? 2
        let next = min(max(nearest + delta, 0), weights.count - 1)
        return weights[next]
    }

    /// String is sold by name, not by point size.
    static func weightName(_ thickness: Double) -> String {
        switch thickness {
        case ..<3.2: return "Fine"
        case ..<4.5: return "Light"
        case ..<6: return "Twine"
        case ..<8.2: return "Heavy"
        default: return "Rope"
        }
    }
}
