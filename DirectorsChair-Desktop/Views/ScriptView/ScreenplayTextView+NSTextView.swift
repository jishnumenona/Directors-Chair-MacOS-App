//
// ScreenplayTextView+NSTextView.swift
//
// Extracted from ScreenplayTextView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import AppKit


// MARK: - Custom NSTextView Subclass

/// Custom NSTextView that can draw page break indicators and handle key shortcuts
class ScreenplayNSTextView: NSTextView {

    var onNewSceneShortcut: (() -> Void)?
    var onDeleteSceneHandler: ((UUID) -> Void)?
    var onCommandClickHandler: ((ScriptElement) -> Void)?
    var onDoubleClickSceneHandler: ((ScriptElement) -> Void)?
    weak var coordinatorRef: ScreenplayTextView.Coordinator?

    var showPagesMode: Bool = false
    var typewriterModeEnabled: Bool = false

    // Title page metadata
    var projectName: String = ""
    var directorName: String = ""
    var productionCompany: String = ""
    var genre: String = ""

    static let continuousTitleBlockHeight: CGFloat = 500

    // MARK: - Cmd+Hover State
    private var hoveredLinkRange: NSRange?
    private var hoveredOriginalAttrs: [NSAttributedString.Key: Any]?
    private var isCmdHeld = false

    private static let linkHoverColor = NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.75, alpha: 1.0)

    // MARK: - Cmd Bulk Highlight State
    private var bulkHighlightedRanges: [(range: NSRange, originalBg: Any?)] = []
    private var bulkHighlightIconViews: [NSView] = []
    private static let characterHighlightColor = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.40, alpha: 0.50)
    private static let locationHighlightColor = NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 0.40)

    // MARK: - Tracking Area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if isCmdHeld {
            updateHoverHighlight(at: event.locationInWindow)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        let cmdNow = event.modifierFlags.contains(.command)
        if cmdNow && !isCmdHeld {
            isCmdHeld = true
            highlightCharactersAndLocations()
            if let window = self.window {
                let mouseInWindow = window.mouseLocationOutsideOfEventStream
                updateHoverHighlight(at: mouseInWindow)
            }
        } else if !cmdNow && isCmdHeld {
            isCmdHeld = false
            clearHoverHighlight()
            clearCharacterAndLocationHighlights()
            NSCursor.iBeam.set()
        }
    }

    private func isNavigableElement(_ element: ScriptElement) -> Bool {
        switch element.type {
        case .character, .sceneHeading:
            return true
        case .dialogue, .parenthetical:
            return element.sourceItemId != nil
        case .action:
            return element.sourceItemId == nil && element.sourceSequenceIndex != nil
        default:
            return false
        }
    }

    private func updateHoverHighlight(at locationInWindow: NSPoint) {
        let clickPoint = convert(locationInWindow, from: nil)
        let adjustedPoint = NSPoint(
            x: clickPoint.x - textContainerOrigin.x,
            y: clickPoint.y - textContainerOrigin.y
        )

        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let textStorage = textStorage,
              let coordinator = coordinatorRef else { return }

        let charIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        // Find element using paragraph counting
        let elementIndex = coordinator.elementIndexForCursor(charIndex)
        var foundRange: NSRange?

        if elementIndex >= 0, elementIndex < coordinator.parent.elements.count {
            let element = coordinator.parent.elements[elementIndex]
            if isNavigableElement(element) {
                foundRange = coordinator.rangeForParagraph(elementIndex)
            }
        }

        if foundRange == hoveredLinkRange { return }

        clearHoverHighlight()

        if let range = foundRange,
           range.location + range.length <= textStorage.length {
            hoveredOriginalAttrs = textStorage.attributes(at: range.location, effectiveRange: nil)
            hoveredLinkRange = range

            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            textStorage.addAttribute(.foregroundColor, value: Self.linkHoverColor, range: range)

            NSCursor.pointingHand.set()
        } else {
            NSCursor.iBeam.set()
        }
    }

    private func clearHoverHighlight() {
        guard let range = hoveredLinkRange,
              let originalAttrs = hoveredOriginalAttrs,
              let textStorage = textStorage,
              range.location + range.length <= textStorage.length else {
            hoveredLinkRange = nil
            hoveredOriginalAttrs = nil
            return
        }

        textStorage.removeAttribute(.underlineStyle, range: range)
        if let originalColor = originalAttrs[.foregroundColor] {
            textStorage.addAttribute(.foregroundColor, value: originalColor, range: range)
        }

        hoveredLinkRange = nil
        hoveredOriginalAttrs = nil
    }

    // MARK: - Bulk Character + Location Highlights

    private func highlightCharactersAndLocations() {
        guard let textStorage = textStorage,
              let layoutManager = layoutManager,
              let textContainer = textContainer,
              let coordinator = coordinatorRef else { return }

        clearCharacterAndLocationHighlights()

        let imageMap = coordinator.parent.characterImageMap
        let basePath = coordinator.parent.projectBasePath

        for (index, element) in coordinator.parent.elements.enumerated() {
            let highlightColor: NSColor
            switch element.type {
            case .character:
                highlightColor = Self.characterHighlightColor
            case .sceneHeading:
                highlightColor = Self.locationHighlightColor
            default:
                continue
            }

            let range = coordinator.rangeForParagraph(index)
            guard range.location + range.length <= textStorage.length else { continue }

            let originalBg = textStorage.attribute(.backgroundColor, at: range.location, effectiveRange: nil)
            textStorage.addAttribute(.backgroundColor, value: highlightColor, range: range)
            bulkHighlightedRanges.append((range: range, originalBg: originalBg))

            // Place icon badge to the left of the paragraph
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let iconSize: CGFloat = 24
            let iconX = textContainerOrigin.x + lineRect.origin.x - iconSize - 8
            let iconY = textContainerOrigin.y + lineRect.origin.y + (lineRect.height - iconSize) / 2

            let badge = NSView(frame: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
            badge.wantsLayer = true
            badge.layer?.cornerRadius = iconSize / 2
            badge.layer?.masksToBounds = true

            if element.type == .character {
                // Look up character image
                let charName = element.text
                    .replacingOccurrences(of: " (CONT'D)", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .uppercased()
                let info = imageMap[charName]
                var loaded = false

                if let relativePath = info?.imagePath, !relativePath.isEmpty, let base = basePath {
                    let fullURL = base.appendingPathComponent(relativePath)
                    if let image = NSImage(contentsOf: fullURL) {
                        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: iconSize, height: iconSize))
                        imageView.image = image
                        imageView.imageScaling = .scaleProportionallyUpOrDown
                        badge.addSubview(imageView)
                        badge.layer?.borderColor = highlightColor.withAlphaComponent(0.6).cgColor
                        badge.layer?.borderWidth = 1.5
                        loaded = true
                    }
                }

                if !loaded {
                    // Fallback: colored initials circle
                    let hex = info?.color ?? "#777777"
                    badge.layer?.backgroundColor = NSColor.fromHexStr(hex).cgColor
                    let initials = String(charName.prefix(1))
                    let label = NSTextField(labelWithString: initials)
                    label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
                    label.textColor = .white
                    label.alignment = .center
                    label.sizeToFit()
                    label.frame = NSRect(
                        x: (iconSize - label.frame.width) / 2,
                        y: (iconSize - label.frame.height) / 2,
                        width: label.frame.width,
                        height: label.frame.height
                    )
                    badge.addSubview(label)
                }
            } else {
                // Scene heading: location pin icon
                badge.layer?.backgroundColor = Self.locationHighlightColor.withAlphaComponent(0.8).cgColor
                if let symbolImage = NSImage(systemSymbolName: "mappin.and.ellipse", accessibilityDescription: nil) {
                    let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
                    let tinted = symbolImage.withSymbolConfiguration(config) ?? symbolImage
                    let imageView = NSImageView(frame: NSRect(x: 3, y: 3, width: iconSize - 6, height: iconSize - 6))
                    imageView.image = tinted
                    imageView.contentTintColor = NSColor(calibratedRed: 0.15, green: 0.40, blue: 0.80, alpha: 1.0)
                    imageView.imageScaling = .scaleProportionallyDown
                    badge.addSubview(imageView)
                }
            }

            addSubview(badge)
            bulkHighlightIconViews.append(badge)
        }
    }

    private func clearCharacterAndLocationHighlights() {
        // Remove icon badges
        for iconView in bulkHighlightIconViews {
            iconView.removeFromSuperview()
        }
        bulkHighlightIconViews.removeAll()

        guard let textStorage = textStorage else {
            bulkHighlightedRanges.removeAll()
            return
        }

        for entry in bulkHighlightedRanges {
            guard entry.range.location + entry.range.length <= textStorage.length else { continue }
            if let originalBg = entry.originalBg {
                textStorage.addAttribute(.backgroundColor, value: originalBg, range: entry.range)
            } else {
                textStorage.removeAttribute(.backgroundColor, range: entry.range)
            }
        }
        bulkHighlightedRanges.removeAll()
    }

    override func mouseDown(with event: NSEvent) {
        // Double-click on scene heading → open scene in bubble/timeline
        if event.clickCount == 2 {
            let clickPoint = convert(event.locationInWindow, from: nil)
            let adjustedPoint = NSPoint(
                x: clickPoint.x - textContainerOrigin.x,
                y: clickPoint.y - textContainerOrigin.y
            )

            if let layoutManager = layoutManager,
               let textContainer = textContainer,
               let coordinator = coordinatorRef {
                let charIndex = layoutManager.characterIndex(
                    for: adjustedPoint,
                    in: textContainer,
                    fractionOfDistanceBetweenInsertionPoints: nil
                )
                let elementIndex = coordinator.elementIndexForCursor(charIndex)
                if elementIndex >= 0, elementIndex < coordinator.parent.elements.count {
                    let element = coordinator.parent.elements[elementIndex]
                    if element.type == .sceneHeading {
                        onDoubleClickSceneHandler?(element)
                        return
                    }
                }
            }
        }

        // Cmd+Click → navigate to element
        if event.modifierFlags.contains(.command),
           !event.modifierFlags.contains(.shift) {
            clearHoverHighlight()
            clearCharacterAndLocationHighlights()
            isCmdHeld = false

            let clickPoint = convert(event.locationInWindow, from: nil)
            let adjustedPoint = NSPoint(
                x: clickPoint.x - textContainerOrigin.x,
                y: clickPoint.y - textContainerOrigin.y
            )

            guard let layoutManager = layoutManager,
                  let textContainer = textContainer,
                  let coordinator = coordinatorRef else {
                super.mouseDown(with: event)
                return
            }

            let charIndex = layoutManager.characterIndex(
                for: adjustedPoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            let elementIndex = coordinator.elementIndexForCursor(charIndex)
            if elementIndex >= 0, elementIndex < coordinator.parent.elements.count {
                let element = coordinator.parent.elements[elementIndex]
                onCommandClickHandler?(element)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains([.command, .shift]),
           event.charactersIgnoringModifiers?.lowercased() == "n" {
            onNewSceneShortcut?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        let clickPoint = convert(event.locationInWindow, from: nil)
        let adjustedPoint = NSPoint(
            x: clickPoint.x - textContainerOrigin.x,
            y: clickPoint.y - textContainerOrigin.y
        )

        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let coordinator = coordinatorRef else { return menu }

        let charIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        let elementIndex = coordinator.elementIndexForCursor(charIndex)

        if elementIndex >= 0, elementIndex < coordinator.parent.elements.count {
            let element = coordinator.parent.elements[elementIndex]
            if element.type == .sceneHeading {
                menu.insertItem(NSMenuItem.separator(), at: 0)

                let deleteItem = NSMenuItem(
                    title: "Delete Scene",
                    action: #selector(deleteSceneAction(_:)),
                    keyEquivalent: ""
                )
                deleteItem.target = self
                deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
                deleteItem.representedObject = element.id
                menu.insertItem(deleteItem, at: 0)
            }
        }

        return menu
    }

    @objc private func deleteSceneAction(_ sender: NSMenuItem) {
        guard let elementId = sender.representedObject as? UUID else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Scene?"
        alert.informativeText = "This will permanently remove the scene and all its contents. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if let deleteButton = alert.buttons.first {
            deleteButton.hasDestructiveAction = true
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            onDeleteSceneHandler?(elementId)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            super.draw(dirtyRect)
            return
        }

        let linesPerPage: CGFloat = 55
        let lineHeight: CGFloat = ScreenplayFormatting.lineHeight + 2
        let pageHeight = linesPerPage * lineHeight
        let contentHeight = layoutManager.usedRect(for: textContainer).height
        let insetY = textContainerInset.height
        let insetX = textContainerInset.width

        if showPagesMode {
            let deskColor = NSColor(calibratedRed: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
            let fullPageWidth = ScreenplayFormatting.pageWidth

            let pageX = max(10, (bounds.width - fullPageWidth) / 2)

            deskColor.setFill()
            dirtyRect.fill()

            let totalContentHeight = contentHeight + insetY * 2
            let totalPages = max(1, Int(ceil(totalContentHeight / pageHeight)))
            let totalHeight = CGFloat(totalPages) * pageHeight

            let columnRect = NSRect(x: pageX, y: 0, width: fullPageWidth, height: totalHeight)
            let drawableColumn = columnRect.intersection(dirtyRect.insetBy(dx: -16, dy: -16))

            if !drawableColumn.isNull {
                NSGraphicsContext.current?.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.20)
                shadow.shadowOffset = NSSize(width: 3, height: 3)
                shadow.shadowBlurRadius = 8
                shadow.set()
                ScreenplayFormatting.backgroundColor.setFill()
                NSBezierPath(rect: drawableColumn).fill()
                NSGraphicsContext.current?.restoreGraphicsState()

                ScreenplayFormatting.backgroundColor.setFill()
                NSBezierPath(rect: drawableColumn).fill()
            }

            let separatorColor = NSColor(calibratedRed: 0.70, green: 0.68, blue: 0.65, alpha: 0.6)
            for pageIndex in 1..<totalPages {
                let breakY = CGFloat(pageIndex) * pageHeight
                let lineArea = NSRect(x: pageX, y: breakY - 1, width: fullPageWidth, height: 2)
                if dirtyRect.intersects(lineArea) {
                    separatorColor.setFill()
                    NSBezierPath(rect: NSRect(x: pageX, y: breakY - 0.5, width: fullPageWidth, height: 1)).fill()
                }
            }

            let titlePageRect = NSRect(x: pageX, y: 0, width: fullPageWidth, height: pageHeight)
            if dirtyRect.intersects(titlePageRect) {
                drawTitlePage(in: titlePageRect)
            }

            super.draw(dirtyRect)
        } else {
            ScreenplayFormatting.backgroundColor.setFill()
            dirtyRect.fill()

            let titleBlockH = Self.continuousTitleBlockHeight
            let fullPageWidth = ScreenplayFormatting.pageWidth
            let titlePageX = max(10, (bounds.width - fullPageWidth) / 2)
            let titleRect = NSRect(x: titlePageX, y: 0, width: fullPageWidth, height: titleBlockH)
            if dirtyRect.intersects(titleRect) {
                drawTitlePage(in: titleRect)
            }

            let separatorY = titleBlockH + 20
            if dirtyRect.intersects(NSRect(x: 0, y: separatorY - 1, width: bounds.width, height: 2)) {
                NSGraphicsContext.current?.cgContext.saveGState()
                ScreenplayFormatting.pageBreakColor.setStroke()
                let sepPath = NSBezierPath()
                sepPath.move(to: NSPoint(x: insetX, y: separatorY))
                sepPath.line(to: NSPoint(x: insetX + ScreenplayFormatting.contentWidth, y: separatorY))
                sepPath.lineWidth = 0.5
                sepPath.stroke()
                NSGraphicsContext.current?.cgContext.restoreGState()
            }

            super.draw(dirtyRect)

            let context = NSGraphicsContext.current?.cgContext
            context?.setStrokeColor(ScreenplayFormatting.pageBreakColor.cgColor)
            context?.setLineWidth(0.5)
            context?.setLineDash(phase: 0, lengths: [4, 4])

            var y = insetY + pageHeight
            while y < contentHeight + insetY {
                if dirtyRect.intersects(NSRect(x: 0, y: y - 1, width: bounds.width, height: 2)) {
                    context?.move(to: CGPoint(x: insetX, y: y))
                    context?.addLine(to: CGPoint(x: insetX + ScreenplayFormatting.contentWidth, y: y))
                    context?.strokePath()
                }
                y += pageHeight
            }
        }
    }

    // MARK: - Title Page Drawing

    private func drawTitlePage(in pageRect: NSRect) {
        let titleFont = ScreenplayFormatting.withCascade(
            NSFont(name: "Courier-Bold", size: 24) ?? NSFont.monospacedSystemFont(ofSize: 24, weight: .bold)
        )
        let byFont = ScreenplayFormatting.withCascade(
            NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        )
        let smallFont = ScreenplayFormatting.withCascade(
            NSFont(name: "Courier", size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        )

        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center
        centerStyle.lineSpacing = 4

        let leftStyle = NSMutableParagraphStyle()
        leftStyle.alignment = .left
        leftStyle.lineSpacing = 2

        let textColor = ScreenplayFormatting.textColor
        let subtleColor = ScreenplayFormatting.sceneNumberColor

        let contentInsetX: CGFloat = 108
        let contentRight: CGFloat = 72
        let contentWidth = pageRect.width - contentInsetX - contentRight

        let titleBlockTop = pageRect.origin.y + pageRect.height * 0.33

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor,
            .paragraphStyle: centerStyle
        ]
        let titleRect = NSRect(
            x: pageRect.origin.x + contentInsetX,
            y: titleBlockTop,
            width: contentWidth,
            height: 80
        )
        let displayName = projectName.isEmpty ? "Untitled Screenplay" : projectName
        (displayName as NSString).draw(in: titleRect, withAttributes: titleAttrs)

        let titleSize = (displayName as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: 80),
            options: [.usesLineFragmentOrigin],
            attributes: titleAttrs
        )

        let byY = titleBlockTop + titleSize.height + 40
        let byAttrs: [NSAttributedString.Key: Any] = [
            .font: byFont,
            .foregroundColor: textColor,
            .paragraphStyle: centerStyle
        ]
        let byRect = NSRect(
            x: pageRect.origin.x + contentInsetX,
            y: byY,
            width: contentWidth,
            height: 20
        )
        if !directorName.isEmpty {
            ("written by" as NSString).draw(in: byRect, withAttributes: byAttrs)

            let directorRect = NSRect(
                x: pageRect.origin.x + contentInsetX,
                y: byY + 24,
                width: contentWidth,
                height: 20
            )
            (directorName as NSString).draw(in: directorRect, withAttributes: byAttrs)
        }

        let bottomAttrs: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .foregroundColor: subtleColor,
            .paragraphStyle: leftStyle
        ]
        var bottomY = pageRect.origin.y + pageRect.height - 80

        if !productionCompany.isEmpty {
            let companyRect = NSRect(
                x: pageRect.origin.x + contentInsetX,
                y: bottomY,
                width: 300,
                height: 16
            )
            (productionCompany as NSString).draw(in: companyRect, withAttributes: bottomAttrs)
            bottomY += 18
        }

        if !genre.isEmpty {
            let genreRect = NSRect(
                x: pageRect.origin.x + contentInsetX,
                y: bottomY,
                width: 300,
                height: 16
            )
            (genre as NSString).draw(in: genreRect, withAttributes: bottomAttrs)
        }
    }
}
