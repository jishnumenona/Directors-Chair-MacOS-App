// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionPaper.swift
//
// The Wall, pass 2 — what the words are written on.
//
// A clipping is only as convincing as its stock. These are papers you'd
// actually find on a director's desk: the cream of a printed page, kraft
// from a parcel, newsprint, a legal pad, graph paper, a sticky note, and
// paper that has been in a drawer too long. Each carries its own texture,
// drawn rather than photographed so it stays crisp at any zoom.

import SwiftUI

public enum VisionPaper: String, CaseIterable, Identifiable, Sendable {
    case cream
    case bond
    case kraft
    case newsprint
    case ruled
    case graph
    case sticky
    case aged

    public var id: String { rawValue }

    public static func resolve(_ raw: String?) -> VisionPaper {
        raw.flatMap(VisionPaper.init(rawValue:)) ?? .cream
    }

    public var displayName: String {
        switch self {
        case .cream: return "Cream"
        case .bond: return "Bond"
        case .kraft: return "Kraft"
        case .newsprint: return "Newsprint"
        case .ruled: return "Legal pad"
        case .graph: return "Graph"
        case .sticky: return "Sticky"
        case .aged: return "Aged"
        }
    }

    /// The stock itself.
    public var base: Color {
        switch self {
        case .cream: return Color(hex: "#F8F3E7")
        case .bond: return Color(hex: "#FCFBF7")
        case .kraft: return Color(hex: "#C9A97B")
        case .newsprint: return Color(hex: "#DFDBD0")
        case .ruled: return Color(hex: "#FBF6DF")
        case .graph: return Color(hex: "#FAFAF6")
        case .sticky: return Color(hex: "#F6E96E")
        case .aged: return Color(hex: "#E8DCC0")
        }
    }

    /// Ink that stays readable on it. Kraft takes a softer black; aged
    /// paper suits a brown-black the way old type does.
    public var ink: Color {
        switch self {
        case .kraft: return Color(hex: "#2A211A")
        case .aged: return Color(hex: "#332A20")
        case .newsprint: return Color(hex: "#1C1A17")
        default: return VisionWallPalette.ink
        }
    }

    /// A hint of shadow inside the edge — thicker stocks catch more light.
    public var edgeShade: Double {
        switch self {
        case .kraft, .sticky: return 0.12
        case .newsprint, .aged: return 0.09
        default: return 0.06
        }
    }
}

// MARK: - The texture on top of the stock

/// Drawn, not photographed: rules, grids, fibres and foxing scale with the
/// canvas and cost one Canvas pass.
public struct VisionPaperTexture: View {
    public let paper: VisionPaper

    public init(paper: VisionPaper) {
        self.paper = paper
    }

    public var body: some View {
        Canvas { context, size in
            switch paper {
            case .ruled:
                rule(&context, size: size)
            case .graph:
                grid(&context, size: size)
            case .kraft:
                fibres(&context, size: size, count: 90,
                       color: Color(hex: "#8A6A42").opacity(0.30))
            case .newsprint:
                fibres(&context, size: size, count: 140,
                       color: Color(hex: "#7A776E").opacity(0.22))
            case .aged:
                foxing(&context, size: size)
            case .sticky:
                sticky(&context, size: size)
            case .cream, .bond:
                fibres(&context, size: size, count: 34,
                       color: Color(hex: "#A79C82").opacity(0.14))
            }
        }
        .allowsHitTesting(false)
    }

    // Deterministic scatter — the same sheet looks the same every launch.
    private func scatter(_ count: Int, in size: CGSize,
                         _ body: (CGPoint, UInt64) -> Void) {
        var hash: UInt64 = 1469598103934665603
        for index in 0..<count {
            hash = (hash ^ UInt64(index &* 2654435761)) &* 1099511628211
            let x = CGFloat(hash % 1000) / 1000 * size.width
            let y = CGFloat((hash >> 20) % 1000) / 1000 * size.height
            body(CGPoint(x: x, y: y), hash)
        }
    }

    private func rule(_ context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 22
        var y = spacing
        while y < size.height {
            context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y))
                                  $0.addLine(to: CGPoint(x: size.width, y: y)) },
                           with: .color(Color(hex: "#8FA9C4").opacity(0.55)),
                           lineWidth: 0.7)
            y += spacing
        }
        let margin = min(34, size.width * 0.16)
        context.stroke(Path { $0.move(to: CGPoint(x: margin, y: 0))
                              $0.addLine(to: CGPoint(x: margin, y: size.height)) },
                       with: .color(Color(hex: "#C98A8A").opacity(0.6)),
                       lineWidth: 0.8)
    }

    private func grid(_ context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 13
        let colour = Color(hex: "#9FB6C9").opacity(0.42)
        var x: CGFloat = 0
        while x < size.width {
            context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0))
                                  $0.addLine(to: CGPoint(x: x, y: size.height)) },
                           with: .color(colour), lineWidth: 0.5)
            x += spacing
        }
        var y: CGFloat = 0
        while y < size.height {
            context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y))
                                  $0.addLine(to: CGPoint(x: size.width, y: y)) },
                           with: .color(colour), lineWidth: 0.5)
            y += spacing
        }
    }

    private func fibres(_ context: inout GraphicsContext, size: CGSize,
                        count: Int, color: Color) {
        scatter(count, in: size) { point, hash in
            let length = 1.5 + CGFloat(hash % 7)
            let horizontal = hash % 2 == 0
            context.stroke(
                Path {
                    $0.move(to: point)
                    $0.addLine(to: CGPoint(x: point.x + (horizontal ? length : 0),
                                           y: point.y + (horizontal ? 0 : length)))
                },
                with: .color(color), lineWidth: 0.7)
        }
    }

    private func foxing(_ context: inout GraphicsContext, size: CGSize) {
        scatter(26, in: size) { point, hash in
            let radius = 1.5 + CGFloat(hash % 9)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(Color(hex: "#A98E62").opacity(0.13)))
        }
    }

    /// The band of adhesive across the top of a sticky note.
    private func sticky(_ context: inout GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.18)),
            with: .color(Color(hex: "#E0D050").opacity(0.35)))
    }
}
