// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionTextStyle.swift
//
// Semantic text-style presets for vision-board text cards, modeled on the
// convergent pattern of Milanote/FigJam/Canva/Freeform (research 2026-07):
// a small opinionated set, whole-card styling, no font pickers — and size
// always comes from resizing the card, never a point-size field. The
// presets map to how directors annotate lookbooks: poster statements,
// section headers, tone quotes, technical captions, working notes, and
// one-word mood tags.

import SwiftUI

public enum VisionTextStyle: String, CaseIterable, Identifiable, Sendable {
    case title
    case section
    case quote
    case caption
    case note
    case tag

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .title: return "Title"
        case .section: return "Section"
        case .quote: return "Quote"
        case .caption: return "Caption"
        case .note: return "Note"
        case .tag: return "Tag"
        }
    }

    /// Stored values are free strings for JSON stability; unknown or nil
    /// resolves to the poster default.
    public static func resolve(_ raw: String?) -> VisionTextStyle {
        raw.flatMap(VisionTextStyle.init(rawValue:)) ?? .title
    }
}

/// The rendered face of a text card — one implementation shared by the
/// canvas card, the editor preview, and the PNG exporter so all three
/// always match. Auto-fits its frame in every style.
public struct VisionTextCardFace: View {
    public let content: String
    public let style: VisionTextStyle
    public let colorHex: String

    public init(content: String, style: VisionTextStyle, colorHex: String) {
        self.content = content
        self.style = style
        self.colorHex = colorHex
    }

    private var color: Color { Color(hex: colorHex) }

    public var body: some View {
        switch style {
        case .title:
            // Film-poster statement: black weight, caps, centered.
            fitted(Text(content.uppercased())
                .font(.system(size: 400, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundColor(color),
                   alignment: .center)

        case .section:
            // Board-region header: caps, wide tracking, left, thin rule.
            VStack(alignment: .leading, spacing: 0) {
                fitted(Text(content.uppercased())
                    .font(.system(size: 200, weight: .bold))
                    .tracking(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(color),
                       alignment: .leading)
                Rectangle()
                    .fill(color.opacity(0.55))
                    .frame(height: 2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

        case .quote:
            // Tone line: serif italic, sentence case, slightly muted.
            fitted(Text(content)
                .font(.system(size: 200, weight: .regular, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundColor(color.opacity(0.88)),
                   alignment: .center)

        case .caption:
            // Technical annotation: small caps-style metadata line.
            fitted(Text(content.uppercased())
                .font(.system(size: 80, weight: .medium))
                .tracking(1.5)
                .multilineTextAlignment(.leading)
                .foregroundColor(color.opacity(0.65)),
                   alignment: .leading)

        case .note:
            // Sticky-note working thought: filled tint, sentence case.
            ZStack(alignment: .topLeading) {
                color.opacity(0.16)
                fitted(Text(content)
                    .font(.system(size: 120, weight: .regular))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.white),
                       alignment: .topLeading)
            }

        case .tag:
            // One-word mood keyword: bold caps in a pill.
            fitted(Text(content.uppercased())
                .font(.system(size: 200, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white),
                   alignment: .center)
            .padding(6)
            .background(Capsule().fill(color.opacity(0.85)))
            .padding(6)
        }
    }

    /// Shared auto-fit treatment: huge base size scaled down to the frame.
    private func fitted(_ text: some View, alignment: Alignment) -> some View {
        text
            .minimumScaleFactor(0.01)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: alignment)
    }
}
