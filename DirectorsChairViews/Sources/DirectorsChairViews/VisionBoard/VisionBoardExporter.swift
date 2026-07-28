// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardExporter.swift
//
// Vision Board repair, Slice 6: board → PNG export. The Export toolbar
// button existed but did nothing (showingExportOptions was never read).
// Layout math is pure and unit-tested; rendering goes through
// ImageRenderer with a scale cap so huge boards can't allocate an
// unbounded bitmap; card images are resolved and loaded synchronously
// up front — the one-shot render never waits on async loaders.

import SwiftUI
import DirectorsChairCore

public enum VisionBoardExporter {

    public struct Layout: Equatable {
        public let canvasSize: CGSize
        public let frames: [String: CGRect]  // card id → frame in export space
    }

    /// Pure layout math: the cards' world bounding box translated to the
    /// origin, padded on all sides. Nil when there is nothing to export.
    public static func layout(cards: [VisionCard],
                              padding: CGFloat = 40) -> Layout? {
        let rects = cards.map { card in
            CGRect(x: card.canvasX ?? 0, y: card.canvasY ?? 0,
                   width: card.canvasWidth ?? 200,
                   height: card.canvasHeight ?? 200)
        }
        guard let first = rects.first else { return nil }
        let bbox = rects.dropFirst().reduce(first) { $0.union($1) }

        var frames: [String: CGRect] = [:]
        for (card, rect) in zip(cards, rects) {
            frames[card.id] = rect.offsetBy(dx: padding - bbox.minX,
                                            dy: padding - bbox.minY)
        }
        return Layout(canvasSize: CGSize(width: bbox.width + padding * 2,
                                         height: bbox.height + padding * 2),
                      frames: frames)
    }

    /// Preferred 2× render scale, capped so the longest bitmap dimension
    /// never exceeds maxPixels.
    public static func renderScale(for size: CGSize,
                                   preferred: CGFloat = 2,
                                   maxPixels: CGFloat = 8192) -> CGFloat {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return preferred }
        return min(preferred, maxPixels / longest)
    }

    /// Renders the cards to PNG data; nil when there are no cards or the
    /// renderer fails.
    @MainActor
    public static func renderPNG(cards: [VisionCard],
                                 projectBase: URL?) -> Data? {
        guard let layout = layout(cards: cards) else { return nil }

        var images: [String: NSImage] = [:]
        for card in cards {
            if let url = VisionBoardImagePath.resolveImageURL(
                card.imagePath, projectBase: projectBase),
               let image = NSImage(contentsOf: url) {
                images[card.id] = image
            }
        }
        // Draw order mirrors the canvas: (pinned, zOrder) ascending.
        let ordered = cards.sorted {
            if $0.pinned != $1.pinned { return !$0.pinned }
            return $0.zOrder < $1.zOrder
        }

        let content = ZStack(alignment: .topLeading) {
            Color(hex: "#1A1A1A")
            ForEach(ordered, id: \.id) { card in
                if let frame = layout.frames[card.id] {
                    ExportCardView(card: card, image: images[card.id])
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
        }
        .frame(width: layout.canvasSize.width,
               height: layout.canvasSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = renderScale(for: layout.canvasSize)
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// Minimal static card representation for export — no gestures, no async
/// loading. Legibility of the layout is the goal, not pixel parity with
/// the live canvas.
struct ExportCardView: View {
    let card: VisionCard
    let image: NSImage?

    private var type: VisionCardType {
        VisionCardType(rawValue: card.cardType) ?? .image
    }

    var body: some View {
        ZStack {
            Color(hex: "#2A2A2A")
            switch type {
            case .text:
                // Poster type, matching the live canvas card's fallback.
                Text([card.text, card.description, card.title]
                    .first { !$0.isEmpty } ?? "")
                    .font(.system(size: 200, weight: .bold))
                    .minimumScaleFactor(0.02)
                    .foregroundColor(Color(hex: card.textColor))
                    .multilineTextAlignment(.center)
                    .padding(8)
            case .colorPalette:
                HStack(spacing: 0) {
                    ForEach(Array(card.colorPalette.enumerated()),
                            id: \.offset) {
                        Color(hex: $0.element)
                    }
                }
            default:
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !card.title.isEmpty {
                Text(card.title)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.55))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}
