//
//  ScreenplayFormatting.swift
//  DirectorsChair-Desktop
//
//  Script View: Industry-standard screenplay typography and layout constants
//

import AppKit
import SwiftUI

/// Industry-standard screenplay formatting constants
/// Based on Final Draft / Movie Magic Screenwriter conventions
enum ScreenplayFormatting {

    // MARK: - Font

    /// Courier 12pt - industry standard screenplay font
    static let font: NSFont = NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let boldFont: NSFont = NSFont(name: "Courier-Bold", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    static let italicFont: NSFont = NSFont(name: "Courier-Oblique", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    // MARK: - Page Dimensions (US Letter in points: 72pt = 1 inch)

    static let pageWidth: CGFloat = 612     // 8.5"
    static let pageHeight: CGFloat = 792    // 11"

    // MARK: - Margins

    static let marginTop: CGFloat = 72      // 1"
    static let marginBottom: CGFloat = 72   // 1"
    static let marginLeft: CGFloat = 108    // 1.5" (binding margin)
    static let marginRight: CGFloat = 72    // 1"
    static let contentWidth: CGFloat = 432  // 6" (pageWidth - marginLeft - marginRight)

    // MARK: - Element Indentation (from left margin)

    static let sceneHeadingIndent: CGFloat = 0
    static let actionIndent: CGFloat = 0
    static let characterIndent: CGFloat = 158   // 2.2" from margin
    static let parentheticalIndent: CGFloat = 115 // 1.6" from margin
    static let dialogueIndent: CGFloat = 72     // 1.0" from margin
    static let dialogueMaxWidth: CGFloat = 252  // 3.5"
    static let transitionIndent: CGFloat = 0    // right-aligned

    // MARK: - Line Spacing

    static let lineHeight: CGFloat = 14

    // MARK: - Typewriter Aesthetic Colors
    // Using calibratedRed to ensure colors stay fixed regardless of dark/light mode
    // (this view has a fixed cream background, so text must always be dark)

    static let backgroundColor = NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.91, alpha: 1.0) // Warm cream #FAF5E8
    static let textColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.15, alpha: 1.0) // Dark charcoal #262626
    static let sceneHeadingColor = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
    static let noteBackground = NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.80, alpha: 0.5) // Light yellow for notes
    static let pageBreakColor = NSColor(calibratedRed: 0.75, green: 0.72, blue: 0.68, alpha: 0.6)
    static let sceneNumberColor = NSColor(calibratedRed: 0.35, green: 0.32, blue: 0.28, alpha: 1.0)
    static let placeholderColor = NSColor(calibratedRed: 0.55, green: 0.52, blue: 0.48, alpha: 0.7)

    // SwiftUI versions
    static let swiftUIBackground = Color(nsColor: backgroundColor)
    static let swiftUIText = Color(nsColor: textColor)

    // MARK: - Paragraph Styles

    static func paragraphStyle(for type: ScriptElementType) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.paragraphSpacingBefore = 0
        style.paragraphSpacing = 0

        switch type {
        case .sceneHeading:
            style.firstLineHeadIndent = sceneHeadingIndent
            style.headIndent = sceneHeadingIndent
            style.paragraphSpacingBefore = 24 // double-space before scene heading
            style.paragraphSpacing = 12

        case .action:
            style.firstLineHeadIndent = actionIndent
            style.headIndent = actionIndent
            style.paragraphSpacingBefore = 12
            style.paragraphSpacing = 0

        case .character:
            style.firstLineHeadIndent = characterIndent
            style.headIndent = characterIndent
            style.paragraphSpacingBefore = 12
            style.paragraphSpacing = 0

        case .parenthetical:
            style.firstLineHeadIndent = parentheticalIndent
            style.headIndent = parentheticalIndent
            style.tailIndent = -(contentWidth - parentheticalIndent - dialogueMaxWidth)
            style.paragraphSpacing = 0

        case .dialogue:
            style.firstLineHeadIndent = dialogueIndent
            style.headIndent = dialogueIndent
            style.tailIndent = -(contentWidth - dialogueIndent - dialogueMaxWidth)
            style.paragraphSpacing = 0

        case .transition:
            style.alignment = .right
            style.paragraphSpacingBefore = 12
            style.paragraphSpacing = 12

        case .dualDialogue:
            style.firstLineHeadIndent = dialogueIndent
            style.headIndent = dialogueIndent
            style.paragraphSpacing = 0

        case .scriptNote:
            style.firstLineHeadIndent = actionIndent
            style.headIndent = actionIndent
            style.paragraphSpacingBefore = 4
            style.paragraphSpacing = 4

        case .soundCue:
            style.firstLineHeadIndent = actionIndent
            style.headIndent = actionIndent
            style.paragraphSpacingBefore = 12
            style.paragraphSpacing = 0

        case .sectionHeading:
            style.firstLineHeadIndent = 0
            style.headIndent = 0
            style.paragraphSpacingBefore = 24
            style.paragraphSpacing = 12

        case .blankLine:
            style.paragraphSpacing = 0
            style.minimumLineHeight = lineHeight
            style.maximumLineHeight = lineHeight
        }

        return style
    }

    /// Get text attributes for a given element type
    static func attributes(for type: ScriptElementType) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle(for: type)
        ]

        switch type {
        case .sceneHeading:
            attrs[.font] = boldFont
            attrs[.foregroundColor] = sceneHeadingColor

        case .character:
            attrs[.font] = boldFont

        case .parenthetical:
            break // normal Courier

        case .dialogue:
            break // normal Courier

        case .transition:
            attrs[.font] = boldFont

        case .scriptNote:
            attrs[.font] = italicFont
            attrs[.foregroundColor] = NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            attrs[.backgroundColor] = noteBackground

        case .soundCue:
            attrs[.font] = italicFont
            attrs[.foregroundColor] = NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.45, alpha: 1.0)

        case .sectionHeading:
            attrs[.font] = boldFont
            attrs[.foregroundColor] = NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)

        default:
            break
        }

        return attrs
    }

    // MARK: - Page Estimation

    /// Estimate page count from script elements
    /// Rule of thumb: ~55 lines per page, 1 page ~ 1 minute of screen time
    static func estimatePageCount(from elements: [ScriptElement]) -> Int {
        var totalLines: Double = 0

        for element in elements {
            switch element.type {
            case .sceneHeading:
                totalLines += 2 // heading + blank line
            case .action:
                totalLines += max(1, Double(element.text.count) / 60.0)
            case .character:
                totalLines += 1
            case .parenthetical:
                totalLines += 1
            case .dialogue:
                totalLines += max(1, Double(element.text.count) / 35.0)
            case .transition:
                totalLines += 2
            case .blankLine:
                totalLines += 1
            case .sectionHeading:
                totalLines += 2
            default:
                totalLines += max(1, Double(element.text.count) / 60.0)
            }
        }

        return max(1, Int(ceil(totalLines / 55.0)))
    }
}
