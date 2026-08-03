// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionTextStyle.swift
//
// The Wall, pass 2 — words are imagery.
//
// On a real vision board a phrase is a clipping: ink on paper, cut out and
// pinned up, as much a picture as any photograph. These are six ways to cut
// one — a poster statement, a torn strip, an editorial line, a technical
// caption, a working note, a filing label. Whole-scrap styling, no font
// pickers, and size always comes from resizing the scrap.
//
// No handwriting faces: research is blunt that they sit in the uncanny
// valley (identical e's give the lie away). Honest editorial type instead.

import SwiftUI

public enum VisionTextStyle: String, CaseIterable, Identifiable, Sendable {
    case title
    case section
    case quote
    case caption
    case note
    case tag

    public var id: String { rawValue }

    /// Named for the cut, not the semantics — you pick these by eye.
    public var displayName: String {
        switch self {
        case .title: return "Poster"
        case .section: return "Torn strip"
        case .quote: return "Editorial"
        case .caption: return "Caption"
        case .note: return "Note"
        case .tag: return "Label"
        }
    }

    /// Stored values are free strings for JSON stability; unknown or nil
    /// resolves to the poster cut.
    public static func resolve(_ raw: String?) -> VisionTextStyle {
        raw.flatMap(VisionTextStyle.init(rawValue:)) ?? .title
    }

    /// The next cut, for cycling through them on the wall.
    public var next: VisionTextStyle {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// Which edges look hand-torn. Scissors cut the rest.
    var tornEdges: Edge.Set {
        switch self {
        case .title: return .all
        case .section: return [.top, .bottom]
        case .note: return [.bottom]
        case .quote, .caption, .tag: return []
        }
    }
}

/// The rendered face of a word clipping — one implementation shared by the
/// canvas, the editor preview, and the PNG exporter so all three always
/// match. Auto-fits its frame in every cut.
public struct VisionTextCardFace: View {
    public let content: String
    public let style: VisionTextStyle
    public let colorHex: String
    /// Stable per-scrap variation for the tear; pass the card id.
    public let seedID: String
    /// The stock this clipping is cut from.
    public let paper: VisionPaper

    public init(content: String, style: VisionTextStyle, colorHex: String,
                seedID: String = "clipping", paper: VisionPaper = .cream) {
        self.content = content
        self.style = style
        self.colorHex = colorHex
        self.seedID = seedID
        self.paper = paper
    }

    /// Stored colours default to white, which would be invisible as ink on
    /// paper; near-white falls back to the wall's ink.
    /// Stored colours default to white, which would be invisible on any
    /// of these stocks; near-white falls back to the paper's own ink.
    private var ink: Color {
        let stored = VisionWallPalette.inkColor(fromStored: colorHex)
        return stored == VisionWallPalette.ink ? paper.ink : stored
    }

    public var body: some View {
        clipping
            .background(sheet)
            .clipShape(VisionTornPaper(torn: style.tornEdges,
                                       seed: VisionTornPaper.seed(for: seedID)))
    }

    private var sheet: some View {
        ZStack {
            paper.base
            VisionPaperTexture(paper: paper)
            // The light catches a real sheet at its edge.
            RoundedRectangle(cornerRadius: 1)
                .strokeBorder(Color.black.opacity(paper.edgeShade), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var clipping: some View {
        switch style {
        case .title:
            // A statement torn from a poster: condensed, black, all caps.
            fitted(Text(content.uppercased())
                .font(.system(size: 400, weight: .black))
                .fontWidth(.condensed)
                .multilineTextAlignment(.center)
                .foregroundColor(ink),
                   alignment: .center)

        case .section:
            // A strip of a headline: wide tracking, one rule beneath.
            VStack(alignment: .leading, spacing: 0) {
                fitted(Text(content.uppercased())
                    .font(.system(size: 200, weight: .bold))
                    .tracking(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(ink),
                       alignment: .leading)
                Rectangle()
                    .fill(ink.opacity(0.5))
                    .frame(height: 1.5)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }

        case .quote:
            // A line lifted from a page: serif italic, generous margins.
            fitted(Text(content)
                .font(.system(size: 200, weight: .regular, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundColor(ink.opacity(0.9)),
                   alignment: .center)

        case .caption:
            // The technical note under a still.
            fitted(Text(content.uppercased())
                .font(.system(size: 80, weight: .medium))
                .tracking(1.8)
                .multilineTextAlignment(.leading)
                .foregroundColor(ink.opacity(0.62)),
                   alignment: .leading)

        case .note:
            // A working thought, written to be replaced.
            fitted(Text(content)
                .font(.system(size: 120, weight: .regular, design: .serif))
                .multilineTextAlignment(.leading)
                .foregroundColor(ink.opacity(0.85)),
                   alignment: .topLeading)

        case .tag:
            // A filing label: small, bold, one word.
            fitted(Text(content.uppercased())
                .font(.system(size: 200, weight: .heavy))
                .fontWidth(.condensed)
                .tracking(1)
                .multilineTextAlignment(.center)
                .foregroundColor(ink),
                   alignment: .center)
        }
    }

    /// Shared auto-fit treatment: huge base size scaled down to the frame.
    private func fitted(_ text: some View, alignment: Alignment) -> some View {
        text
            .minimumScaleFactor(0.01)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: alignment)
    }
}
