// DirectorsChairExports/Sources/DirectorsChairExports/PDF/PDFExportService.swift
//
// PDF Export Service
// Generates professional PDF documents with real VECTOR TEXT (selectable,
// searchable, crisp at any zoom) via a CGContext PDF backing store — not
// rasterised NSImage pages. (WS8.6)

import Foundation
import PDFKit
import AppKit
import CoreGraphics
import DirectorsChairCore

/// Service for exporting project data to PDF format
public struct PDFExportService: Sendable {

    // MARK: - Export Types

    // Only formats with real implementations are declared (WS8.7 — no
    // advertised-but-stub export types). Call sheet / shot list / budget
    // report PDFs are future work and will be added WITH their generators.
    public enum PDFExportType: String, Sendable {
        case screenplay
        case characterSheet
    }

    // MARK: - Page Settings

    public struct PageSettings: Sendable {
        public var pageSize: CGSize
        public var margins: NSEdgeInsets
        public var headerHeight: CGFloat
        public var footerHeight: CGFloat

        public static let usLetter = PageSettings(
            pageSize: CGSize(width: 612, height: 792), // 8.5" x 11" at 72 DPI
            margins: NSEdgeInsets(top: 72, left: 108, bottom: 72, right: 72), // 1" top/bottom, 1.5" left, 1" right
            headerHeight: 36,
            footerHeight: 36
        )

        public static let a4 = PageSettings(
            pageSize: CGSize(width: 595, height: 842), // A4 at 72 DPI
            margins: NSEdgeInsets(top: 72, left: 108, bottom: 72, right: 72),
            headerHeight: 36,
            footerHeight: 36
        )

        public init(pageSize: CGSize, margins: NSEdgeInsets, headerHeight: CGFloat, footerHeight: CGFloat) {
            self.pageSize = pageSize
            self.margins = margins
            self.headerHeight = headerHeight
            self.footerHeight = footerHeight
        }
    }

    // MARK: - Screenplay Export

    /// Export screenplay to PDF
    @MainActor
    public static func exportScreenplay(_ project: Project, settings: PageSettings = .usLetter) -> PDFDocument? {
        let generator = ScreenplayPDFGenerator(project: project, settings: settings)
        return generator.generate()
    }

    /// Export character sheet to PDF
    @MainActor
    public static func exportCharacterSheet(_ character: Character, project: Project? = nil, settings: PageSettings = .usLetter) -> PDFDocument? {
        let generator = CharacterSheetPDFGenerator(character: character, project: project, settings: settings)
        return generator.generate()
    }

    /// Save PDF to file
    @MainActor
    public static func saveToFile(_ pdf: PDFDocument, url: URL) -> Bool {
        return pdf.write(to: url)
    }
}

// MARK: - Vector PDF Context
//
// Wraps a CGContext backed by a PDF data consumer. Each page is opened with
// beginPage()/closed with endPage(); AppKit text drawing (NSString.draw,
// NSAttributedString.draw) targets the current NSGraphicsContext, so the glyphs
// are emitted as vector text into the PDF rather than baked into a bitmap.

@MainActor
private final class VectorPDFContext {
    let settings: PDFExportService.PageSettings
    private let data = NSMutableData()
    private let context: CGContext
    private(set) var pageNumber = 0
    private var pageOpen = false

    init?(settings: PDFExportService.PageSettings) {
        self.settings = settings
        guard let consumer = CGDataConsumer(data: data) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: settings.pageSize)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        self.context = ctx
    }

    /// Open a fresh page and make it the current AppKit drawing target.
    func beginPage() {
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        pageOpen = true
        pageNumber += 1

        // White background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: settings.pageSize).fill()
    }

    func endPage() {
        guard pageOpen else { return }
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        pageOpen = false
    }

    /// Close the document and return a searchable PDFDocument.
    func finish() -> PDFDocument? {
        if pageOpen { endPage() }
        context.closePDF()
        return PDFDocument(data: data as Data)
    }
}

// MARK: - Text Drawing Helpers

private enum PDFText {
    /// Draw a single (already-short) string at a point in the current context.
    static func draw(_ text: String, at point: NSPoint, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(at: point, withAttributes: attributes)
    }

    /// Word-wrap `text` to `maxWidth`, drawing each line and advancing `y`.
    static func drawWrapped(_ text: String, font: NSFont, color: NSColor = .black,
                            x: CGFloat, y: inout CGFloat, maxWidth: CGFloat, lineHeight: CGFloat = 14) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let words = text.split(separator: " ")
        var currentLine = ""
        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            let testSize = (testLine as NSString).size(withAttributes: attributes)
            if testSize.width > maxWidth && !currentLine.isEmpty {
                draw(currentLine, at: NSPoint(x: x, y: y), attributes: attributes)
                y -= lineHeight
                currentLine = String(word)
            } else {
                currentLine = testLine
            }
        }
        if !currentLine.isEmpty {
            draw(currentLine, at: NSPoint(x: x, y: y), attributes: attributes)
            y -= lineHeight
        }
    }
}

// MARK: - Screenplay PDF Generator

@MainActor
private final class ScreenplayPDFGenerator {
    let project: Project
    let settings: PDFExportService.PageSettings

    private var currentY: CGFloat = 0

    // Fonts (Courier is the screenplay standard)
    private let titleFont = NSFont(name: "Courier", size: 24) ?? NSFont.systemFont(ofSize: 24)
    private let headingFont = NSFont(name: "Courier-Bold", size: 12) ?? NSFont.boldSystemFont(ofSize: 12)
    private let bodyFont = NSFont(name: "Courier", size: 12) ?? NSFont.systemFont(ofSize: 12)
    private let characterFont = NSFont(name: "Courier-Bold", size: 12) ?? NSFont.boldSystemFont(ofSize: 12)

    init(project: Project, settings: PDFExportService.PageSettings) {
        self.project = project
        self.settings = settings
    }

    func generate() -> PDFDocument? {
        guard let pdf = VectorPDFContext(settings: settings) else { return nil }

        drawTitlePage(pdf)
        drawContent(pdf)

        return pdf.finish()
    }

    // MARK: Title page

    private func drawTitlePage(_ pdf: VectorPDFContext) {
        pdf.beginPage()

        let titleY = settings.pageSize.height * 0.6
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: NSColor.black]
        let titleString = project.name as NSString
        let titleSize = titleString.size(withAttributes: titleAttributes)
        titleString.draw(at: NSPoint(x: (settings.pageSize.width - titleSize.width) / 2, y: titleY),
                         withAttributes: titleAttributes)

        let byAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor.black]
        let byY = titleY - 48
        let byString = "by" as NSString
        let bySize = byString.size(withAttributes: byAttributes)
        byString.draw(at: NSPoint(x: (settings.pageSize.width - bySize.width) / 2, y: byY), withAttributes: byAttributes)

        let authorY = byY - 24
        let authorString = project.director as NSString
        let authorSize = authorString.size(withAttributes: byAttributes)
        authorString.draw(at: NSPoint(x: (settings.pageSize.width - authorSize.width) / 2, y: authorY),
                          withAttributes: byAttributes)

        pdf.endPage()
    }

    // MARK: Content

    private func drawContent(_ pdf: VectorPDFContext) {
        startContentPage(pdf)

        for sequence in project.sequences {
            for scene in sequence.scenes {
                if currentY < settings.margins.bottom + 100 {
                    pageBreak(pdf)
                }

                // Scene heading
                let heading = SceneHeadingFormatter.heading(for: scene, sequenceLocation: sequence.location)
                drawLeft(heading, font: headingFont)
                currentY -= 24

                // Scene description
                if !scene.description.isEmpty {
                    drawLeft(scene.description, font: bodyFont)
                    currentY -= 24
                }

                // Scene elements sorted by chronology
                var elements: [(Int, Any)] = []
                for d in scene.dialogues { elements.append((d.chronologyNumber, d)) }
                for a in scene.actions { elements.append((a.chronologyNumber, a)) }
                elements.sort { $0.0 < $1.0 }

                for (_, element) in elements {
                    if currentY < settings.margins.bottom + 72 {
                        pageBreak(pdf)
                    }

                    if let dialogue = element as? Dialogue {
                        // Character name (centered-ish)
                        let charX = settings.pageSize.width / 2 - 72
                        drawAt(dialogue.character.uppercased(), font: characterFont, x: charX)
                        currentY -= 12
                        // Dialogue (indented)
                        let dialogueX = settings.margins.left + 72
                        drawAt(dialogue.text, font: bodyFont, x: dialogueX, maxWidth: 252)
                        currentY -= 24
                    } else if let action = element as? Action {
                        drawLeft(action.description, font: bodyFont)
                        currentY -= 24
                    }
                }

                currentY -= 24 // Extra space between scenes
            }
        }

        drawPageNumber(pdf)
        pdf.endPage()
    }

    private func startContentPage(_ pdf: VectorPDFContext) {
        pdf.beginPage()
        currentY = settings.pageSize.height - settings.margins.top
    }

    private func pageBreak(_ pdf: VectorPDFContext) {
        drawPageNumber(pdf)
        pdf.endPage()
        startContentPage(pdf)
    }

    private func drawPageNumber(_ pdf: VectorPDFContext) {
        let pageNumString = "\(pdf.pageNumber - 1)." as NSString // title page is #1, content starts at 1
        let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor.black]
        let x = settings.pageSize.width - settings.margins.right - 30
        let y = settings.pageSize.height - settings.margins.top / 2
        pageNumString.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    private func drawLeft(_ text: String, font: NSFont) {
        drawAt(text, font: font, x: settings.margins.left)
    }

    private func drawAt(_ text: String, font: NSFont, x: CGFloat, maxWidth: CGFloat? = nil) {
        let width = maxWidth ?? (settings.pageSize.width - x - settings.margins.right)
        PDFText.drawWrapped(text, font: font, x: x, y: &currentY, maxWidth: width)
    }
}

// MARK: - Character Sheet PDF Generator

@MainActor
private final class CharacterSheetPDFGenerator {
    let character: Character
    let project: Project?
    let settings: PDFExportService.PageSettings

    private let titleFont = NSFont.boldSystemFont(ofSize: 24)
    private let headingFont = NSFont.boldSystemFont(ofSize: 14)
    private let bodyFont = NSFont.systemFont(ofSize: 11)
    private let labelFont = NSFont.systemFont(ofSize: 9)

    private var currentY: CGFloat = 0

    init(character: Character, project: Project?, settings: PDFExportService.PageSettings) {
        self.character = character
        self.project = project
        self.settings = settings
    }

    func generate() -> PDFDocument? {
        guard let pdf = VectorPDFContext(settings: settings) else { return nil }
        pdf.beginPage()

        currentY = settings.pageSize.height - settings.margins.top

        // Header banner with name + role
        let headerRect = NSRect(
            x: settings.margins.left,
            y: currentY - 60,
            width: settings.pageSize.width - settings.margins.left - settings.margins.right,
            height: 60
        )
        NSColor(calibratedRed: 0.4, green: 0.5, blue: 0.9, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: headerRect, xRadius: 8, yRadius: 8).fill()

        (character.name as NSString).draw(
            at: NSPoint(x: headerRect.minX + 20, y: headerRect.minY + 20),
            withAttributes: [.font: titleFont, .foregroundColor: NSColor.white]
        )
        (character.role as NSString).draw(
            at: NSPoint(x: headerRect.minX + 20, y: headerRect.minY + 5),
            withAttributes: [.font: bodyFont, .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
        )

        currentY -= 80

        // Quick facts
        drawSection("Quick Facts")
        drawLabelValue("Age", "\(character.age)", x: settings.margins.left)
        drawLabelValue("Gender", character.gender, x: settings.margins.left + 150)
        drawLabelValue("Build", character.build, x: settings.margins.left + 300)
        currentY -= 30

        // Physical appearance
        drawSection("Physical Appearance")
        drawLabelValue("Hair", "\(character.hairStyle), \(character.hairColor)", x: settings.margins.left)
        currentY -= 20
        drawLabelValue("Eyes", "\(character.eyeShape), \(character.eyeColor)", x: settings.margins.left)
        currentY -= 20
        drawLabelValue("Skin Tone", character.skinTone, x: settings.margins.left)
        currentY -= 30

        // Biography
        if let backgroundStory = character.backgroundStory, !backgroundStory.isEmpty {
            drawSection("Background")
            let maxWidth = settings.pageSize.width - settings.margins.left - settings.margins.right
            PDFText.drawWrapped(backgroundStory, font: bodyFont, x: settings.margins.left, y: &currentY, maxWidth: maxWidth)
        }

        return pdf.finish()
    }

    private func drawSection(_ title: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .foregroundColor: NSColor(calibratedRed: 0.4, green: 0.5, blue: 0.9, alpha: 1.0)
        ]
        (title as NSString).draw(at: NSPoint(x: settings.margins.left, y: currentY), withAttributes: attributes)
        currentY -= 25
    }

    private func drawLabelValue(_ label: String, _ value: String, x: CGFloat) {
        (label as NSString).draw(at: NSPoint(x: x, y: currentY + 12),
                                 withAttributes: [.font: labelFont, .foregroundColor: NSColor.gray])
        (value as NSString).draw(at: NSPoint(x: x, y: currentY),
                                 withAttributes: [.font: bodyFont, .foregroundColor: NSColor.black])
    }
}
