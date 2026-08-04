// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardLookbook.swift
//
// Vision board roadmap #6: lookbook PDF export. The board wins the
// argument internally; a paginated per-section PDF travels to financiers
// and department heads (StudioBinder's bridge from mood board to
// deliverable). Each SECTION FRAME becomes a page — the reason frames
// shipped first — with an "Everything else" page for unframed cards and
// a whole-board fallback when no frames exist. Rendering reuses the
// tested PNG exporter per page.

import SwiftUI
import PDFKit
import DirectorsChairCore

public enum VisionBoardLookbook {

    public struct Page {
        public let title: String
        public let cards: [VisionCard]
    }

    /// Pure pagination: frames ordered by (y, x); each page holds the
    /// frame plus every non-frame card whose CENTER lies inside it. A
    /// card inside two overlapping frames goes to the first (reading
    /// order). Unframed cards form a trailing page; no frames at all
    /// collapses to a single whole-board page.
    public static func pages(cards: [VisionCard]) -> [Page] {
        let frames = cards
            .filter { $0.cardType == VisionCardType.frame.rawValue }
            .sorted {
                if ($0.canvasY ?? 0) != ($1.canvasY ?? 0) {
                    return ($0.canvasY ?? 0) < ($1.canvasY ?? 0)
                }
                return ($0.canvasX ?? 0) < ($1.canvasX ?? 0)
            }
        let content = cards.filter {
            $0.cardType != VisionCardType.frame.rawValue
        }
        guard !frames.isEmpty else {
            return cards.isEmpty ? [] : [Page(title: "Board", cards: cards)]
        }

        var claimed = Set<String>()
        var pages: [Page] = []
        for frame in frames {
            let rect = CGRect(x: frame.canvasX ?? 0, y: frame.canvasY ?? 0,
                              width: frame.canvasWidth ?? 0,
                              height: frame.canvasHeight ?? 0)
            let inside = content.filter { card in
                guard !claimed.contains(card.id) else { return false }
                let center = CGPoint(
                    x: (card.canvasX ?? 0) + (card.canvasWidth ?? 200) / 2,
                    y: (card.canvasY ?? 0) + (card.canvasHeight ?? 200) / 2)
                return rect.contains(center)
            }
            inside.forEach { claimed.insert($0.id) }
            pages.append(Page(
                title: frame.title.isEmpty ? "Section" : frame.title,
                cards: [frame] + inside))
        }
        let leftovers = content.filter { !claimed.contains($0.id) }
        if !leftovers.isEmpty {
            pages.append(Page(title: "Everything else", cards: leftovers))
        }
        return pages
    }

    /// Renders the lookbook; nil when the board is empty or every page
    /// fails to render.
    @MainActor
    public static func renderPDF(cards: [VisionCard],
                                 connectors: [VisionConnector] = [],
                                 projectBase: URL?) -> Data? {
        let bookPages = pages(cards: cards)
        guard !bookPages.isEmpty else { return nil }

        let document = PDFDocument()
        for page in bookPages {
            // Only the thread whose BOTH ends are on this page — a
            // dangling cord to an element printed elsewhere is a mistake.
            let ids = Set(page.cards.map(\.id))
            let pageThread = connectors.filter {
                ids.contains($0.fromCardId) && ids.contains($0.toCardId)
            }
            guard let png = VisionBoardExporter.renderPNG(
                cards: page.cards, connectors: pageThread,
                projectBase: projectBase),
                  let image = NSImage(data: png),
                  let pdfPage = PDFPage(image: image) else { continue }
            document.insert(pdfPage, at: document.pageCount)
        }
        guard document.pageCount > 0 else { return nil }
        return document.dataRepresentation()
    }
}
