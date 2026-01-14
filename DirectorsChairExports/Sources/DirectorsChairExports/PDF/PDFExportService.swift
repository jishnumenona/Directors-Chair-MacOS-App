// DirectorsChairExports/Sources/DirectorsChairExports/PDF/PDFExportService.swift
//
// PDF Export Service
// Generates professional PDF documents using PDFKit

import Foundation
import PDFKit
import AppKit
import DirectorsChairCore

/// Service for exporting project data to PDF format
public struct PDFExportService: Sendable {
    
    // MARK: - Export Types
    
    public enum PDFExportType: String, Sendable {
        case screenplay
        case characterSheet
        case callSheet
        case shotList
        case budgetReport
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

// MARK: - Screenplay PDF Generator

@MainActor
private class ScreenplayPDFGenerator {
    let project: Project
    let settings: PDFExportService.PageSettings
    
    private var currentY: CGFloat = 0
    private var pageNumber: Int = 1
    private var pages: [NSImage] = []
    private var currentContext: CGContext?
    
    // Fonts
    private let titleFont = NSFont(name: "Courier", size: 24) ?? NSFont.systemFont(ofSize: 24)
    private let headingFont = NSFont(name: "Courier-Bold", size: 12) ?? NSFont.boldSystemFont(ofSize: 12)
    private let bodyFont = NSFont(name: "Courier", size: 12) ?? NSFont.systemFont(ofSize: 12)
    private let characterFont = NSFont(name: "Courier-Bold", size: 12) ?? NSFont.boldSystemFont(ofSize: 12)
    
    init(project: Project, settings: PDFExportService.PageSettings) {
        self.project = project
        self.settings = settings
    }
    
    func generate() -> PDFDocument? {
        // Create PDF document
        let pdfDocument = PDFDocument()
        
        // Generate title page
        if let titlePage = generateTitlePage() {
            pdfDocument.insert(titlePage, at: pdfDocument.pageCount)
        }
        
        // Generate content pages
        let contentPages = generateContentPages()
        for page in contentPages {
            pdfDocument.insert(page, at: pdfDocument.pageCount)
        }
        
        return pdfDocument
    }
    
    private func generateTitlePage() -> PDFPage? {
        let image = NSImage(size: settings.pageSize)
        image.lockFocus()
        
        // White background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: settings.pageSize).fill()
        
        // Title (centered, 40% from top)
        let titleY = settings.pageSize.height * 0.6
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]
        
        let titleString = project.name as NSString
        let titleSize = titleString.size(withAttributes: titleAttributes)
        let titleX = (settings.pageSize.width - titleSize.width) / 2
        titleString.draw(at: NSPoint(x: titleX, y: titleY), withAttributes: titleAttributes)
        
        // "by" line
        let byY = titleY - 48
        let byString = "by" as NSString
        let byAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]
        let bySize = byString.size(withAttributes: byAttributes)
        let byX = (settings.pageSize.width - bySize.width) / 2
        byString.draw(at: NSPoint(x: byX, y: byY), withAttributes: byAttributes)
        
        // Author/Director name
        let authorY = byY - 24
        let authorString = project.director as NSString
        let authorSize = authorString.size(withAttributes: byAttributes)
        let authorX = (settings.pageSize.width - authorSize.width) / 2
        authorString.draw(at: NSPoint(x: authorX, y: authorY), withAttributes: byAttributes)
        
        image.unlockFocus()
        
        return PDFPage(image: image)
    }
    
    private func generateContentPages() -> [PDFPage] {
        var pages: [PDFPage] = []
        var currentPage = startNewPage()
        currentY = settings.pageSize.height - settings.margins.top
        
        for sequence in project.sequences {
            for scene in sequence.scenes {
                // Check if we need a new page
                if currentY < settings.margins.bottom + 100 {
                    if let pdfPage = finishPage(currentPage) {
                        pages.append(pdfPage)
                    }
                    currentPage = startNewPage()
                    currentY = settings.pageSize.height - settings.margins.top
                }
                
                // Scene heading
                let location = scene.location ?? sequence.location ?? scene.name
                let heading = "INT. \(location.uppercased()) - DAY"
                drawText(heading, font: headingFont, y: &currentY, image: currentPage)
                currentY -= 24
                
                // Scene description
                if !scene.description.isEmpty {
                    drawText(scene.description, font: bodyFont, y: &currentY, image: currentPage)
                    currentY -= 24
                }
                
                // Scene elements sorted by chronology
                var elements: [(Int, Any)] = []
                for d in scene.dialogues { elements.append((d.chronologyNumber, d)) }
                for a in scene.actions { elements.append((a.chronologyNumber, a)) }
                elements.sort { $0.0 < $1.0 }
                
                for (_, element) in elements {
                    // Check for page break
                    if currentY < settings.margins.bottom + 72 {
                        if let pdfPage = finishPage(currentPage) {
                            pages.append(pdfPage)
                        }
                        currentPage = startNewPage()
                        currentY = settings.pageSize.height - settings.margins.top
                    }
                    
                    if let dialogue = element as? Dialogue {
                        // Character name (centered)
                        let charX = settings.pageSize.width / 2 - 72
                        drawTextAt(dialogue.character.uppercased(), font: characterFont, x: charX, y: &currentY, image: currentPage)
                        currentY -= 12
                        
                        // Dialogue (indented)
                        let dialogueX = settings.margins.left + 72
                        drawTextAt(dialogue.text, font: bodyFont, x: dialogueX, y: &currentY, image: currentPage, maxWidth: 252)
                        currentY -= 24
                    } else if let action = element as? Action {
                        drawText(action.description, font: bodyFont, y: &currentY, image: currentPage)
                        currentY -= 24
                    }
                }
                
                currentY -= 24 // Extra space between scenes
            }
        }
        
        // Finish last page
        if let pdfPage = finishPage(currentPage) {
            pages.append(pdfPage)
        }
        
        return pages
    }
    
    private func startNewPage() -> NSImage {
        let image = NSImage(size: settings.pageSize)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: settings.pageSize).fill()
        pageNumber += 1
        return image
    }
    
    private func finishPage(_ image: NSImage) -> PDFPage? {
        // Draw page number
        let pageNumString = "\(pageNumber)." as NSString
        let pageNumAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]
        let pageNumX = settings.pageSize.width - settings.margins.right - 30
        let pageNumY = settings.pageSize.height - settings.margins.top / 2
        pageNumString.draw(at: NSPoint(x: pageNumX, y: pageNumY), withAttributes: pageNumAttributes)
        
        image.unlockFocus()
        return PDFPage(image: image)
    }
    
    private func drawText(_ text: String, font: NSFont, y: inout CGFloat, image: NSImage) {
        drawTextAt(text, font: font, x: settings.margins.left, y: &y, image: image)
    }
    
    private func drawTextAt(_ text: String, font: NSFont, x: CGFloat, y: inout CGFloat, image: NSImage, maxWidth: CGFloat? = nil) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let width = maxWidth ?? (settings.pageSize.width - x - settings.margins.right)
        
        // Simple text wrapping
        let words = text.split(separator: " ")
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            let testSize = (testLine as NSString).size(withAttributes: attributes)
            
            if testSize.width > width && !currentLine.isEmpty {
                // Draw current line and start new one
                (currentLine as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
                y -= 14
                currentLine = String(word)
            } else {
                currentLine = testLine
            }
        }
        
        // Draw remaining text
        if !currentLine.isEmpty {
            (currentLine as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
            y -= 14
        }
    }
}

// MARK: - Character Sheet PDF Generator

@MainActor
private class CharacterSheetPDFGenerator {
    let character: Character
    let project: Project?
    let settings: PDFExportService.PageSettings
    
    private let titleFont = NSFont.boldSystemFont(ofSize: 24)
    private let headingFont = NSFont.boldSystemFont(ofSize: 14)
    private let bodyFont = NSFont.systemFont(ofSize: 11)
    private let labelFont = NSFont.systemFont(ofSize: 9)
    
    init(character: Character, project: Project?, settings: PDFExportService.PageSettings) {
        self.character = character
        self.project = project
        self.settings = settings
    }
    
    func generate() -> PDFDocument? {
        let pdfDocument = PDFDocument()
        
        let image = NSImage(size: settings.pageSize)
        image.lockFocus()
        
        // Background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: settings.pageSize).fill()
        
        var currentY = settings.pageSize.height - settings.margins.top
        
        // Header with name
        let headerRect = NSRect(
            x: settings.margins.left,
            y: currentY - 60,
            width: settings.pageSize.width - settings.margins.left - settings.margins.right,
            height: 60
        )
        
        // Draw header background
        NSColor(calibratedRed: 0.4, green: 0.5, blue: 0.9, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: headerRect, xRadius: 8, yRadius: 8).fill()
        
        // Character name
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white
        ]
        (character.name as NSString).draw(
            at: NSPoint(x: headerRect.minX + 20, y: headerRect.minY + 20),
            withAttributes: nameAttributes
        )
        
        // Role
        let roleAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        (character.role as NSString).draw(
            at: NSPoint(x: headerRect.minX + 20, y: headerRect.minY + 5),
            withAttributes: roleAttributes
        )
        
        currentY -= 80
        
        // Quick facts
        drawSection("Quick Facts", y: &currentY)
        drawLabelValue("Age", "\(character.age)", x: settings.margins.left, y: &currentY)
        drawLabelValue("Gender", character.gender, x: settings.margins.left + 150, y: &currentY)
        drawLabelValue("Build", character.build, x: settings.margins.left + 300, y: &currentY)
        currentY -= 30
        
        // Physical appearance
        drawSection("Physical Appearance", y: &currentY)
        drawLabelValue("Hair", "\(character.hairStyle), \(character.hairColor)", x: settings.margins.left, y: &currentY)
        currentY -= 20
        drawLabelValue("Eyes", "\(character.eyeShape), \(character.eyeColor)", x: settings.margins.left, y: &currentY)
        currentY -= 20
        drawLabelValue("Skin Tone", character.skinTone, x: settings.margins.left, y: &currentY)
        currentY -= 30
        
        // Biography
        if let backgroundStory = character.backgroundStory, !backgroundStory.isEmpty {
            drawSection("Background", y: &currentY)
            drawWrappedText(backgroundStory, y: &currentY)
        }
        
        image.unlockFocus()
        
        if let pdfPage = PDFPage(image: image) {
            pdfDocument.insert(pdfPage, at: 0)
        }
        
        return pdfDocument
    }
    
    private func drawSection(_ title: String, y: inout CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .foregroundColor: NSColor(calibratedRed: 0.4, green: 0.5, blue: 0.9, alpha: 1.0)
        ]
        (title as NSString).draw(at: NSPoint(x: settings.margins.left, y: y), withAttributes: attributes)
        y -= 25
    }
    
    private func drawLabelValue(_ label: String, _ value: String, x: CGFloat, y: inout CGFloat) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.gray
        ]
        (label as NSString).draw(at: NSPoint(x: x, y: y + 12), withAttributes: labelAttributes)
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: valueAttributes)
    }
    
    private func drawWrappedText(_ text: String, y: inout CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]
        
        let maxWidth = settings.pageSize.width - settings.margins.left - settings.margins.right
        let words = text.split(separator: " ")
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            let testSize = (testLine as NSString).size(withAttributes: attributes)
            
            if testSize.width > maxWidth && !currentLine.isEmpty {
                (currentLine as NSString).draw(at: NSPoint(x: settings.margins.left, y: y), withAttributes: attributes)
                y -= 14
                currentLine = String(word)
            } else {
                currentLine = testLine
            }
        }
        
        if !currentLine.isEmpty {
            (currentLine as NSString).draw(at: NSPoint(x: settings.margins.left, y: y), withAttributes: attributes)
            y -= 14
        }
    }
}
