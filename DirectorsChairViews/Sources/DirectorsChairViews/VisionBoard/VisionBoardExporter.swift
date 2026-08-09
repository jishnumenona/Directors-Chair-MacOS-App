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

    /// Pins and thread are physical objects a few points across on screen.
    /// A whole wall exported onto one page is scaled way down, so at fixed
    /// size they vanish — the owner's PDF showed no tacks at all. Scale
    /// them with the board, clamped so they never dominate a small one.
    public static func detailScale(for canvas: CGSize) -> CGFloat {
        let longest = max(canvas.width, canvas.height)
        return min(max(longest / 1400, 1), 3.4)
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

    /// Renders the wall to PNG data; nil when there is nothing on it or
    /// the renderer fails.
    ///
    /// The export used to draw its own thing — a black background and bare
    /// rectangles — because it kept a private card renderer that never
    /// learned about the wall. It now composes the SAME pieces the board
    /// itself uses: plaster, tilt, torn paper, the paper stock, the tacks
    /// and the thread. What you export is what is on your wall.
    @MainActor
    public static func renderPNG(cards: [VisionCard],
                                 connectors: [VisionConnector] = [],
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
            let leftFrame = $0.cardType == VisionCardType.frame.rawValue
            let rightFrame = $1.cardType == VisionCardType.frame.rawValue
            if leftFrame != rightFrame { return leftFrame }
            if $0.pinned != $1.pinned { return !$0.pinned }
            return $0.zOrder < $1.zOrder
        }

        // Where each element's tack sits in export space, so thread is
        // strung between pins exactly as it is on the board.
        func tack(_ cardId: String) -> CGPoint? {
            guard let frame = layout.frames[cardId] else { return nil }
            let anchor = VisionScrapPhysics.tackAnchor(seed: cardId)
            return CGPoint(x: frame.minX + frame.width * anchor.x,
                           y: frame.minY + frame.height * anchor.y)
        }

        let detail = detailScale(for: layout.canvasSize)

        let content = ZStack(alignment: .topLeading) {
            VisionWallSurface(transform: CanvasTransform(zoom: 1, offset: .zero))

            ForEach(ordered, id: \.id) { card in
                if let frame = layout.frames[card.id] {
                    ZStack(alignment: .topLeading) {
                        ExportCardView(card: card, image: images[card.id],
                                       projectBase: projectBase)
                            .frame(width: frame.width, height: frame.height)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .shadow(color: VisionWallPalette.scrapShadow,
                                    radius: 7, y: 3)
                        if let note = card.referenceNote, !note.isEmpty {
                            VisionNoteSlip(text: note, detail: detail)
                                .frame(width: min(max(frame.width * 0.5,
                                                      96 * detail),
                                                  168 * detail))
                                .offset(x: frame.width * 0.5,
                                        y: frame.height * 0.56)
                        }
                        VisionThumbtack(
                            size: 15 * detail,
                            pressed: card.pinned,
                            tint: card.pinned ? Color(hex: "#B08A3C")
                                              : VisionWallPalette.greasePencil)
                            .offset(
                                x: frame.width
                                    * VisionScrapPhysics.tackAnchor(seed: card.id).x
                                    - 7.5 * detail,
                                y: frame.height
                                    * VisionScrapPhysics.tackAnchor(seed: card.id).y
                                    - 7.5 * detail)
                    }
                    .frame(width: frame.width, height: frame.height,
                           alignment: .topLeading)
                    // Turns about the tack, exactly as on the wall.
                    .rotationEffect(
                        .degrees(card.rotation ?? 0),
                        anchor: UnitPoint(
                            x: VisionScrapPhysics.tackAnchor(seed: card.id).x,
                            y: VisionScrapPhysics.tackAnchor(seed: card.id).y))
                    .offset(x: frame.minX, y: frame.minY)
                }
            }

            ForEach(connectors, id: \.id) { connector in
                if let from = tack(connector.fromCardId),
                   let to = tack(connector.toCardId) {
                    ConnectorArrow(from: from, to: to, label: connector.label,
                                   onEditLabel: {}, onDelete: {},
                                   // A cord prints at the weight it was
                                   // strung at, scaled for the page.
                                   thickness: CGFloat(connector.thickness ?? 5)
                                       * detail,
                                   // The export is the wall, so a cord
                                   // prints in the twine it was strung in.
                                   thread: VisionThread.resolve(connector.thread))
                }
            }
        }
        .frame(width: layout.canvasSize.width,
               height: layout.canvasSize.height)
        .environment(\.colorScheme, .light)

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
    var projectBase: URL? = nil

    private var type: VisionCardType {
        VisionCardType(rawValue: card.cardType) ?? .image
    }

    var body: some View {
        ZStack {
            // Paper, not the old near-black: it shows through a torn edge
            // and stands in for an image that can't be loaded.
            VisionPaper.resolve(card.paper).base
            switch type {
            case .shotStrip:
                // One-shot render: synchronous loads are fine here.
                HStack(spacing: 3) {
                    ForEach(Array(card.imagePaths.enumerated()),
                            id: \.offset) { _, path in
                        if let url = VisionBoardImagePath.resolveImageURL(
                            path, projectBase: projectBase),
                           let frame = NSImage(contentsOf: url) {
                            Image(nsImage: frame)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                        } else {
                            VisionWallPalette.ink.opacity(0.08)
                        }
                    }
                }
                .padding(4)
                .background(Color.black)
            case .frame:
                ZStack(alignment: .topLeading) {
                    Color(hex: card.textColor).opacity(0.07)
                    Text((card.title.isEmpty ? "Section" : card.title).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(Color(hex: card.textColor).opacity(0.85))
                        .padding(10)
                }
            case .text:
                // The exact canvas face, fallback and preset included.
                VisionTextCardFace(
                    content: [card.text, card.description, card.title]
                        .first { !$0.isEmpty } ?? "",
                    style: VisionTextStyle.resolve(card.textStyle),
                    colorHex: card.textColor,
                                seedID: card.id,
                                paper: VisionPaper.resolve(card.paper))
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
            if !card.title.isEmpty || !(card.referenceNote ?? "").isEmpty {
                VStack(spacing: 1) {
                    if !card.title.isEmpty {
                        Text(card.title)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    if let note = card.referenceNote, !note.isEmpty {
                        Text(note.uppercased())
                            .font(.system(size: 8, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
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
