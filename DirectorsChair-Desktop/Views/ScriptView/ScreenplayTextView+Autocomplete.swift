//
// ScreenplayTextView+Autocomplete.swift
//
// Extracted from ScreenplayTextView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import AppKit


// MARK: - Autocomplete View Controller (Typewriter Aesthetic)

class AutocompleteViewController: NSViewController {
    var items: [AutocompleteItem] = []
    var projectBasePath: URL?
    var onSelect: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private var tableView: NSTableView!
    private var imageCache: [String: NSImage] = [:]

    override func loadView() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 240, height: 200))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = ScreenplayFormatting.backgroundColor
        scrollView.appearance = NSAppearance(named: .aqua)

        tableView = NSTableView(frame: scrollView.bounds)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.title = ""
        column.width = 220
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(itemClicked)
        tableView.rowHeight = 32
        tableView.style = .plain
        tableView.backgroundColor = ScreenplayFormatting.backgroundColor
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .regular
        tableView.appearance = NSAppearance(named: .aqua)

        scrollView.documentView = tableView
        self.view = scrollView
        tableView.reloadData()

        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    @objc func itemClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < items.count else { return }
        onSelect?(items[row].text)
    }

    func moveSelectionUp() {
        let current = tableView.selectedRow
        let newRow = max(0, current - 1)
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }

    func moveSelectionDown() {
        let current = tableView.selectedRow
        let newRow = min(items.count - 1, current + 1)
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }

    func selectedItemText() -> String? {
        let row = tableView.selectedRow
        guard row >= 0 && row < items.count else { return nil }
        return items[row].text
    }

    func updateItems(_ newItems: [AutocompleteItem]) {
        items = newItems
        tableView?.reloadData()
        if !items.isEmpty {
            tableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    private func loadImage(for item: AutocompleteItem) -> NSImage? {
        guard let relativePath = item.imagePath, !relativePath.isEmpty,
              let basePath = projectBasePath else { return nil }

        if let cached = imageCache[relativePath] { return cached }

        let fullURL = basePath.appendingPathComponent(relativePath)
        guard let image = NSImage(contentsOf: fullURL) else { return nil }
        imageCache[relativePath] = image
        return image
    }
}

extension AutocompleteViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let rowView = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 32))

        let hasImage = item.imagePath != nil || item.color != nil
        let imageSize: CGFloat = 22
        let textX: CGFloat = hasImage ? imageSize + 14 : 8

        if hasImage {
            let imageFrame = NSRect(x: 8, y: 5, width: imageSize, height: imageSize)

            if let image = loadImage(for: item) {
                let imageView = NSImageView(frame: imageFrame)
                imageView.image = image
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.wantsLayer = true
                imageView.layer?.cornerRadius = imageSize / 2
                imageView.layer?.masksToBounds = true
                rowView.addSubview(imageView)
            } else {
                let circleView = NSView(frame: imageFrame)
                circleView.wantsLayer = true
                let hex = item.color ?? "#777777"
                circleView.layer?.backgroundColor = NSColor.fromHex(hex).cgColor
                circleView.layer?.cornerRadius = imageSize / 2

                let initials = String(item.text.prefix(1)).uppercased()
                let label = NSTextField(labelWithString: initials)
                label.font = NSFont(name: "Courier-Bold", size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
                label.textColor = .white
                label.alignment = .center
                label.frame = imageFrame
                label.sizeToFit()
                label.frame = NSRect(
                    x: imageFrame.origin.x + (imageFrame.width - label.frame.width) / 2,
                    y: imageFrame.origin.y + (imageFrame.height - label.frame.height) / 2,
                    width: label.frame.width,
                    height: label.frame.height
                )
                rowView.addSubview(circleView)
                rowView.addSubview(label)
            }
        }

        let textLabel = NSTextField(labelWithString: item.text)
        textLabel.font = ScreenplayFormatting.font
        textLabel.textColor = ScreenplayFormatting.textColor
        textLabel.backgroundColor = .clear
        textLabel.drawsBackground = false
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.frame = NSRect(x: textX, y: 6, width: tableView.bounds.width - textX - 8, height: 20)

        rowView.addSubview(textLabel)
        return rowView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = TypewriterTableRowView()
        return rowView
    }
}

/// Custom row view matching the typewriter cream aesthetic
class TypewriterTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let color = NSColor(calibratedRed: 0.88, green: 0.85, blue: 0.78, alpha: 1.0)
            color.setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 3, yRadius: 3)
            path.fill()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        ScreenplayFormatting.backgroundColor.setFill()
        dirtyRect.fill()
    }
}

// MARK: - Transliteration Candidates View Controller

class TransliterationCandidatesVC: NSViewController {
    var items: [String] = []
    var selectedIndex: Int = 0
    var onSelect: ((String) -> Void)?

    private var tableView: NSTableView!

    override func loadView() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 220, height: 160))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = ScreenplayFormatting.backgroundColor
        scrollView.appearance = NSAppearance(named: .aqua)

        tableView = NSTableView(frame: scrollView.bounds)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("candidate"))
        column.title = ""
        column.width = 200
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(itemClicked)
        tableView.rowHeight = 26
        tableView.style = .plain
        tableView.backgroundColor = ScreenplayFormatting.backgroundColor
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.selectionHighlightStyle = .regular
        tableView.appearance = NSAppearance(named: .aqua)

        scrollView.documentView = tableView
        self.view = scrollView
        tableView.reloadData()

        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    @objc func itemClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < items.count else { return }
        selectedIndex = row
        onSelect?(items[row])
    }

    func moveSelectionUp() {
        selectedIndex = max(0, selectedIndex - 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    func moveSelectionDown() {
        selectedIndex = min(items.count - 1, selectedIndex + 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    func setSelectedIndex(_ index: Int) {
        guard index >= 0, index < items.count else { return }
        selectedIndex = index
        tableView?.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    func updateItems(_ newItems: [String]) {
        items = newItems
        selectedIndex = 0
        tableView?.reloadData()
        if !items.isEmpty {
            tableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
}

extension TransliterationCandidatesVC: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowView = NSView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 26))

        // Number prefix
        let numberLabel = NSTextField(labelWithString: "\(row + 1)")
        numberLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        numberLabel.textColor = ScreenplayFormatting.sceneNumberColor
        numberLabel.frame = NSRect(x: 8, y: 3, width: 16, height: 20)
        numberLabel.alignment = .right
        rowView.addSubview(numberLabel)

        // Malayalam candidate
        let candidateLabel = NSTextField(labelWithString: items[row])
        candidateLabel.font = ScreenplayFormatting.font
        candidateLabel.textColor = ScreenplayFormatting.textColor
        candidateLabel.backgroundColor = .clear
        candidateLabel.drawsBackground = false
        candidateLabel.lineBreakMode = .byTruncatingTail
        candidateLabel.frame = NSRect(x: 30, y: 3, width: tableView.bounds.width - 38, height: 20)
        rowView.addSubview(candidateLabel)

        return rowView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return TypewriterTableRowView()
    }
}
