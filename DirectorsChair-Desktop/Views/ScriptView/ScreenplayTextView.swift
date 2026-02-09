//
//  ScreenplayTextView.swift
//  DirectorsChair-Desktop
//
//  Script View: NSViewRepresentable wrapping NSTextView for screenplay rendering and editing
//

import SwiftUI
import AppKit

/// NSViewRepresentable wrapping NSTextView for professional screenplay rendering
struct ScreenplayTextView: NSViewRepresentable {
    @Binding var elements: [ScriptElement]
    var showSceneNumbers: Bool
    var scrollToElementId: UUID?
    var onTextChanged: ((Int, String) -> Void)?  // (elementIndex, newText)

    // Autocomplete
    var autocompleteItems: [AutocompleteItem]
    var showingAutocomplete: Bool
    var autocompleteTrigger: String
    var projectBasePath: URL?
    var onAutocompleteSelected: ((String) -> Void)?
    var onAutocompleteDismissed: (() -> Void)?
    var onNewScene: ((Int) -> Void)?  // (afterElementIndex)
    var onDeleteScene: ((UUID) -> Void)?  // (elementId of scene heading)
    var onCommandClick: ((ScriptElement) -> Void)?  // Cmd+Click navigation

    // Wizard mode
    var isWizardActive: Bool = false
    var focusElementId: UUID?

    // Pages mode
    var showPagesMode: Bool = false

    // Title page metadata (used in pages mode)
    var projectName: String = ""
    var directorName: String = ""
    var productionCompany: String = ""
    var genre: String = ""

    // Zoom
    @Binding var magnification: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = ScreenplayFormatting.backgroundColor

        // Pinch-to-zoom support
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.5
        scrollView.maxMagnification = 3.0
        scrollView.magnification = 1.0

        let textView = ScreenplayNSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Force light appearance for typewriter aesthetic (cream bg + dark text)
        textView.appearance = NSAppearance(named: .aqua)
        scrollView.appearance = NSAppearance(named: .aqua)

        // Typewriter aesthetic
        textView.backgroundColor = ScreenplayFormatting.backgroundColor
        textView.insertionPointColor = ScreenplayFormatting.textColor
        textView.drawsBackground = true

        // Text container sizing - centered screenplay "page"
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: ScreenplayFormatting.contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.lineFragmentPadding = 0

        // Center the text container within the scroll view
        textView.textContainerInset = NSSize(
            width: max(0, (scrollView.frame.width - ScreenplayFormatting.contentWidth) / 2),
            height: ScreenplayFormatting.marginTop
        )

        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: ScreenplayFormatting.contentWidth, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        // Wire Cmd+Shift+N shortcut
        textView.onNewSceneShortcut = { [weak coordinator = context.coordinator] in
            coordinator?.handleNewScene()
        }

        // Wire delete scene handler
        textView.onDeleteSceneHandler = { [weak coordinator = context.coordinator] elementId in
            coordinator?.parent.onDeleteScene?(elementId)
        }

        // Wire Cmd+Click navigation handler
        textView.onCommandClickHandler = { [weak coordinator = context.coordinator] element in
            coordinator?.parent.onCommandClick?(element)
        }

        textView.coordinatorRef = context.coordinator

        // Observe frame changes to re-center text container on layout/resize
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        // Observe live magnification changes from pinch gestures
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.magnificationChanged(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )

        // Build initial content
        context.coordinator.rebuildAttributedString()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ScreenplayNSTextView else { return }

        // CRITICAL: Update coordinator's parent reference so it sees current elements
        context.coordinator.parent = self

        // Update pages mode on the NSTextView and trigger redraw if changed
        if textView.showPagesMode != showPagesMode {
            textView.showPagesMode = showPagesMode
            // In pages mode: disable NSTextView background so our custom draw shows through
            textView.drawsBackground = !showPagesMode
            scrollView.drawsBackground = true
            scrollView.backgroundColor = showPagesMode
                ? NSColor(calibratedRed: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
                : ScreenplayFormatting.backgroundColor
            textView.needsDisplay = true
        }

        // Pass title page metadata
        textView.projectName = projectName
        textView.directorName = directorName
        textView.productionCompany = productionCompany
        textView.genre = genre

        // Re-center text container when scroll view resizes
        let availableWidth = scrollView.frame.width - 20 // account for scroller
        let horizontalInset: CGFloat
        let verticalInset: CGFloat
        if showPagesMode {
            // In pages mode, position text within the centered US Letter page
            let pageX = max(20, (availableWidth - ScreenplayFormatting.pageWidth) / 2)
            horizontalInset = pageX + ScreenplayFormatting.marginLeft
            // Push text down by one page height (title page) + top margin
            // Top margin must be a multiple of lineHeight (16pt) so page breaks
            // always fall between lines, never mid-line.
            let lineH: CGFloat = ScreenplayFormatting.lineHeight + 2 // 16pt
            let pageH: CGFloat = 55 * lineH // 880pt
            let pageTopMargin: CGFloat = 5 * lineH // 80pt (multiple of 16)
            verticalInset = pageH + pageTopMargin
        } else {
            horizontalInset = max(20, (availableWidth - ScreenplayFormatting.contentWidth) / 2)
            verticalInset = ScreenplayFormatting.marginTop
        }
        textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)

        // Apply magnification from binding (e.g. restore saved zoom)
        if abs(scrollView.magnification - magnification) > 0.01 {
            scrollView.magnification = magnification
            context.coordinator.centerHorizontallyDeferred()
        }

        // Center on first layout when zoom != 1.0
        if !context.coordinator.hasCenteredOnFirstLayout && scrollView.frame.width > 0 {
            context.coordinator.hasCenteredOnFirstLayout = true
            if magnification > 1.01 {
                context.coordinator.centerHorizontallyDeferred()
            }
        }

        // Rebuild content if elements changed
        if context.coordinator.lastElementCount != elements.count ||
           context.coordinator.needsRebuild {
            context.coordinator.rebuildAttributedString()
            context.coordinator.needsRebuild = false
        }

        // Scroll to element if requested
        if let targetId = scrollToElementId,
           let range = context.coordinator.elementRanges[targetId] {
            textView.scrollRangeToVisible(range)
            // Brief highlight
            textView.showFindIndicator(for: range)
        }

        // Handle autocomplete panel
        if showingAutocomplete && !autocompleteItems.isEmpty {
            context.coordinator.showAutocompletePopover(items: autocompleteItems, trigger: autocompleteTrigger)
        } else {
            context.coordinator.hideAutocompletePanel()
        }

        // Handle focus element (wizard completion — position cursor at description)
        if let focusId = focusElementId {
            // Need to rebuild first so element ranges are up to date
            context.coordinator.rebuildAttributedString()
            if let range = context.coordinator.elementRanges[focusId] {
                textView.setSelectedRange(NSRange(location: range.location, length: 0))
                textView.scrollRangeToVisible(range)
                textView.typingAttributes = ScreenplayFormatting.attributes(for: .action)
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScreenplayTextView
        weak var textView: ScreenplayNSTextView?
        weak var scrollView: NSScrollView?

        var elementRanges: [UUID: NSRange] = [:]
        var lastElementCount = 0
        var needsRebuild = false
        var isUpdating = false
        var hasCenteredOnFirstLayout = false

        private var autocompletePanel: NSPanel?
        private var autocompleteVC: AutocompleteViewController?

        init(_ parent: ScreenplayTextView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            hideAutocompletePanel()
        }

        // MARK: - Frame Change Handling

        @objc func scrollViewFrameChanged(_ notification: Notification) {
            recenterTextContainer()
        }

        @objc func magnificationChanged(_ notification: Notification) {
            guard let scrollView = notification.object as? NSScrollView else { return }
            parent.magnification = scrollView.magnification
            centerHorizontallyDeferred()
        }

        func centerHorizontallyDeferred() {
            // Defer to next run loop so the scroll view has finished layout
            DispatchQueue.main.async { [weak self] in
                self?.centerHorizontallyNow()
            }
        }

        func centerHorizontallyNow() {
            guard let scrollView = scrollView,
                  let documentView = scrollView.documentView else { return }
            let docWidth = documentView.frame.width
            let visibleWidth = scrollView.contentView.bounds.width
            if docWidth > visibleWidth {
                let centeredX = (docWidth - visibleWidth) / 2
                var origin = scrollView.contentView.bounds.origin
                origin.x = centeredX
                scrollView.contentView.setBoundsOrigin(origin)
            }
        }

        func recenterTextContainer() {
            guard let textView = textView as? ScreenplayNSTextView,
                  let scrollView = scrollView else { return }
            let availableWidth = scrollView.frame.width - 20
            let horizontalInset: CGFloat
            let verticalInset: CGFloat
            if textView.showPagesMode {
                let pageX = max(20, (availableWidth - ScreenplayFormatting.pageWidth) / 2)
                horizontalInset = pageX + ScreenplayFormatting.marginLeft
                let lineH: CGFloat = ScreenplayFormatting.lineHeight + 2
                let pageH: CGFloat = 55 * lineH
                let pageTopMargin: CGFloat = 5 * lineH // 80pt, multiple of lineHeight
                verticalInset = pageH + pageTopMargin
            } else {
                horizontalInset = max(20, (availableWidth - ScreenplayFormatting.contentWidth) / 2)
                verticalInset = ScreenplayFormatting.marginTop
            }
            textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        }

        // MARK: - Build Attributed String

        func rebuildAttributedString() {
            guard let textView = textView else { return }

            isUpdating = true
            defer { isUpdating = false }

            let fullString = NSMutableAttributedString()
            elementRanges.removeAll()

            for (index, element) in parent.elements.enumerated() {
                let startLocation = fullString.length

                var displayText = element.text
                if element.type == .sceneHeading && parent.showSceneNumbers {
                    if let num = element.sceneNumber {
                        displayText = "\(num)    \(element.text)    \(num)"
                    }
                }

                if element.type == .blankLine {
                    displayText = "\n"
                }

                // Auto-capitalize scene headings and character names
                if element.type == .sceneHeading || element.type == .character || element.type == .transition {
                    displayText = displayText.uppercased()
                }

                // Placeholder elements get gray italic styling
                let attrs: [NSAttributedString.Key: Any]
                if element.isPlaceholder {
                    attrs = [
                        .font: ScreenplayFormatting.italicFont,
                        .foregroundColor: ScreenplayFormatting.placeholderColor,
                        .paragraphStyle: ScreenplayFormatting.paragraphStyle(for: element.type)
                    ]
                } else {
                    attrs = ScreenplayFormatting.attributes(for: element.type)
                }

                // Scene number styling
                if element.type == .sceneHeading && parent.showSceneNumbers, let num = element.sceneNumber {
                    let sceneNumAttrs: [NSAttributedString.Key: Any] = [
                        .font: ScreenplayFormatting.font,
                        .foregroundColor: ScreenplayFormatting.sceneNumberColor,
                        .paragraphStyle: ScreenplayFormatting.paragraphStyle(for: .sceneHeading)
                    ]
                    let attributed = NSMutableAttributedString(string: displayText, attributes: sceneNumAttrs)
                    // Bold the heading part (between scene numbers)
                    let prefix = "\(num)    "
                    let suffix = "    \(num)"
                    let headingRange = NSRange(
                        location: prefix.count,
                        length: max(0, displayText.count - prefix.count - suffix.count)
                    )
                    if headingRange.location + headingRange.length <= displayText.count {
                        attributed.setAttributes(attrs, range: headingRange)
                    }
                    fullString.append(attributed)
                } else if element.type != .blankLine {
                    let attributed = NSAttributedString(string: displayText, attributes: attrs)
                    fullString.append(attributed)
                } else {
                    let attributed = NSAttributedString(string: "\n", attributes: [
                        .font: ScreenplayFormatting.font,
                        .paragraphStyle: ScreenplayFormatting.paragraphStyle(for: .blankLine)
                    ])
                    fullString.append(attributed)
                }

                // Add newline between elements (except blank lines which already have one)
                if element.type != .blankLine && index < parent.elements.count - 1 {
                    fullString.append(NSAttributedString(string: "\n"))
                }

                let endLocation = fullString.length
                elementRanges[element.id] = NSRange(location: startLocation, length: endLocation - startLocation)
            }

            lastElementCount = parent.elements.count
            textView.textStorage?.setAttributedString(fullString)
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = textView else { return }

            // Find which element was edited based on cursor position
            let cursorLocation = textView.selectedRange().location

            for (index, element) in parent.elements.enumerated() {
                if let range = elementRanges[element.id],
                   cursorLocation >= range.location && cursorLocation <= range.location + range.length {

                    // Clear placeholder if user is editing one
                    if element.isPlaceholder {
                        parent.elements[index].isPlaceholder = false
                    }

                    // Extract the new text for this element
                    let storage = textView.textStorage!
                    let clampedRange = NSRange(
                        location: range.location,
                        length: min(range.length, storage.length - range.location)
                    )
                    if clampedRange.length > 0 {
                        let newText = storage.attributedSubstring(from: clampedRange).string
                            .trimmingCharacters(in: .newlines)
                        parent.onTextChanged?(index, newText)
                    }
                    break
                }
            }

            // Update typing attributes for the current position
            updateTypingAttributes()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating else { return }
            updateTypingAttributes()
        }

        /// Set typing attributes based on the element the cursor is currently in.
        /// This prevents bold from "bleeding" into normal text when typing after
        /// a bold element (e.g. character name → dialogue).
        private func updateTypingAttributes() {
            guard let textView = textView else { return }
            let cursorLocation = textView.selectedRange().location

            // Find which element the cursor is in
            for element in parent.elements {
                if let range = elementRanges[element.id],
                   cursorLocation >= range.location && cursorLocation <= range.location + range.length {
                    // If cursor is at the very end of this element, the user is about
                    // to type the NEXT element. Use default (action) attributes so text
                    // doesn't inherit bold/italic from the current element.
                    let atEnd = (cursorLocation == range.location + range.length)
                    let targetType: ScriptElementType
                    if atEnd {
                        // After character name → dialogue; after scene heading → action; etc.
                        switch element.type {
                        case .character: targetType = .dialogue
                        case .sceneHeading: targetType = .action
                        case .transition: targetType = .action
                        case .sectionHeading: targetType = .action
                        default: targetType = element.type
                        }
                    } else {
                        targetType = element.type
                    }
                    textView.typingAttributes = ScreenplayFormatting.attributes(for: targetType)
                    return
                }
            }

            // Fallback: default action attributes
            textView.typingAttributes = ScreenplayFormatting.attributes(for: .action)
        }

        // MARK: - New Scene (Cmd+Shift+N)

        func handleNewScene() {
            guard let textView = textView else { return }
            let cursorLocation = textView.selectedRange().location

            // Find which element the cursor is in
            var currentIndex = parent.elements.count - 1
            for (index, element) in parent.elements.enumerated() {
                if let range = elementRanges[element.id],
                   cursorLocation >= range.location && cursorLocation <= range.location + range.length {
                    currentIndex = index
                    break
                }
            }

            parent.onNewScene?(currentIndex)

            // Rebuild after insertion
            DispatchQueue.main.async {
                self.needsRebuild = true
                self.rebuildAttributedString()
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle autocomplete keyboard interaction
            if autocompletePanel != nil {
                if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    selectCurrentAutocompleteItem()
                    return true
                }
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                    parent.onAutocompleteDismissed?()
                    hideAutocompletePanel()
                    return true
                }
                if commandSelector == #selector(NSResponder.moveUp(_:)) {
                    autocompleteVC?.moveSelectionUp()
                    return true
                }
                if commandSelector == #selector(NSResponder.moveDown(_:)) {
                    autocompleteVC?.moveSelectionDown()
                    return true
                }
            }

            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                handleTabKey()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                return false
            }
            return false
        }

        private func selectCurrentAutocompleteItem() {
            guard let vc = autocompleteVC, let selected = vc.selectedItemText() else { return }
            if parent.isWizardActive {
                // During wizard, don't insert text into NSTextView — the ViewModel
                // updates element text directly. Just notify and dismiss.
                parent.onAutocompleteSelected?(selected)
                hideAutocompletePanel()
            } else {
                insertAutocompleteText(selected)
            }
        }

        func insertAutocompleteText(_ text: String) {
            guard let textView = textView else { return }

            // Insert the text at the current cursor position
            let range = textView.selectedRange()
            let attrs = ScreenplayFormatting.attributes(for: .character)
            let insertStr = NSAttributedString(string: text.uppercased(), attributes: attrs)
            textView.textStorage?.replaceCharacters(in: range, with: insertStr)
            textView.setSelectedRange(NSRange(location: range.location + text.count, length: 0))

            // Set typing attributes to dialogue (normal weight) so the next
            // typed text after a character name is not bold
            textView.typingAttributes = ScreenplayFormatting.attributes(for: .dialogue)

            // Dismiss autocomplete
            parent.onAutocompleteSelected?(text)
            hideAutocompletePanel()

            // Notify of text change
            textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString, replacement.count == 1 else { return true }

            // Check for smart shortcut triggers
            let triggers: [String: String] = [
                "@": "character",
                "%": "location",
                "$": "time",
                "#": "transition",
                "~": "sound",
                "^": "prop",
                "/": "note"
            ]

            if let triggerType = triggers[replacement] {
                parent.autocompleteTrigger = triggerType
                // Let the parent handle showing autocomplete
                DispatchQueue.main.async {
                    self.parent.onAutocompleteSelected?(replacement)
                }
                return false // consume the trigger character
            }

            return true
        }

        // MARK: - Tab Key Cycling

        private func handleTabKey() {
            guard let textView = textView else { return }
            let cursorLocation = textView.selectedRange().location

            for (index, element) in parent.elements.enumerated() {
                if let range = elementRanges[element.id],
                   cursorLocation >= range.location && cursorLocation <= range.location + range.length {
                    // Cycle element type: Action -> Character -> Dialogue -> Parenthetical -> Action
                    let nextType: ScriptElementType
                    switch element.type {
                    case .action: nextType = .character
                    case .character: nextType = .dialogue
                    case .dialogue: nextType = .parenthetical
                    case .parenthetical: nextType = .action
                    default: return
                    }

                    parent.elements[index].type = nextType
                    needsRebuild = true

                    // Force update
                    DispatchQueue.main.async {
                        self.rebuildAttributedString()
                    }
                    break
                }
            }
        }

        // MARK: - Autocomplete

        func showAutocompletePopover(items: [AutocompleteItem], trigger: String) {
            guard let textView = textView,
                  let window = textView.window,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            // Don't recreate if already showing
            if autocompletePanel != nil { return }

            let rowHeight: CGFloat = 32
            let panelWidth: CGFloat = 240
            let panelHeight = min(CGFloat(items.count) * rowHeight + 8, 200)

            // Calculate cursor screen position
            let charIndex = textView.selectedRange().location
            let glyphCount = layoutManager.numberOfGlyphs
            guard glyphCount > 0 else { return }
            let safeCharIndex = min(charIndex, glyphCount - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: safeCharIndex)
            var glyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: textContainer
            )
            // Offset by text container origin to get text view coordinates
            glyphRect.origin.x += textView.textContainerOrigin.x
            glyphRect.origin.y += textView.textContainerOrigin.y

            // Convert text view coords → window coords → screen coords
            let windowRect = textView.convert(glyphRect, to: nil)
            let screenRect = window.convertToScreen(windowRect)

            // Position panel just below the cursor line
            let panelX = screenRect.origin.x
            let panelY = screenRect.origin.y - panelHeight - 2

            // Create the view controller
            let vc = AutocompleteViewController()
            vc.items = items
            vc.projectBasePath = parent.projectBasePath
            vc.onSelect = { [weak self] selected in
                guard let self = self else { return }
                if self.parent.isWizardActive {
                    // During wizard, don't insert text — ViewModel handles element updates
                    self.parent.onAutocompleteSelected?(selected)
                    self.hideAutocompletePanel()
                } else {
                    self.insertAutocompleteText(selected)
                }
            }
            vc.onDismiss = { [weak self] in
                self?.parent.onAutocompleteDismissed?()
                self?.hideAutocompletePanel()
            }

            // Create borderless panel (no arrow, clean flat rectangle)
            let panel = NSPanel(
                contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.hasShadow = true
            panel.level = .popUpMenu
            panel.appearance = NSAppearance(named: .aqua)
            panel.isMovable = false
            panel.backgroundColor = ScreenplayFormatting.backgroundColor

            // Set content view with cream styling
            let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
            wrapper.wantsLayer = true
            wrapper.layer?.backgroundColor = ScreenplayFormatting.backgroundColor.cgColor
            wrapper.layer?.cornerRadius = 4
            wrapper.layer?.borderColor = ScreenplayFormatting.sceneNumberColor.withAlphaComponent(0.25).cgColor
            wrapper.layer?.borderWidth = 0.5
            wrapper.layer?.masksToBounds = true

            // Load the VC's view and add it to wrapper
            vc.loadView()
            vc.view.frame = wrapper.bounds
            vc.view.autoresizingMask = [.width, .height]
            wrapper.addSubview(vc.view)

            panel.contentView = wrapper

            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)

            self.autocompletePanel = panel
            self.autocompleteVC = vc
        }

        func hideAutocompletePanel() {
            if let panel = autocompletePanel {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            autocompletePanel = nil
            autocompleteVC = nil
        }
    }
}

// MARK: - Custom NSTextView Subclass

/// Custom NSTextView that can draw page break indicators and handle key shortcuts
class ScreenplayNSTextView: NSTextView {

    /// Callback for Cmd+Shift+N (new scene)
    var onNewSceneShortcut: (() -> Void)?

    /// Callback for deleting a scene (elementId of scene heading)
    var onDeleteSceneHandler: ((UUID) -> Void)?

    /// Callback for Cmd+Click navigation (element)
    var onCommandClickHandler: ((ScriptElement) -> Void)?

    /// Reference to coordinator for accessing element ranges
    weak var coordinatorRef: ScreenplayTextView.Coordinator?

    /// Whether to show paginated "pages" view with gaps between pages
    var showPagesMode: Bool = false

    // Title page metadata
    var projectName: String = ""
    var directorName: String = ""
    var productionCompany: String = ""
    var genre: String = ""

    // MARK: - Cmd+Hover State

    /// The element range currently highlighted for Cmd+hover
    private var hoveredLinkRange: NSRange?
    /// Original attributes saved before applying hover styling
    private var hoveredOriginalAttrs: [NSAttributedString.Key: Any]?
    /// Whether Cmd is currently held
    private var isCmdHeld = false

    /// Link hover color (accent blue that works on cream background)
    private static let linkHoverColor = NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.75, alpha: 1.0)

    // MARK: - Cmd Bulk Highlight State (characters + locations)

    /// Ranges highlighted for characters/locations with their original background color
    private var bulkHighlightedRanges: [(range: NSRange, originalBg: Any?)] = []

    /// Yellow highlighter for character names
    private static let characterHighlightColor = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.40, alpha: 0.50)
    /// Blue highlighter for locations (scene headings)
    private static let locationHighlightColor = NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 0.40)

    // MARK: - Tracking Area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Remove old tracking areas we own
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
            // Cmd just pressed
            isCmdHeld = true
            highlightCharactersAndLocations()
            // Use current mouse location for hover underline
            if let window = self.window {
                let mouseInWindow = window.mouseLocationOutsideOfEventStream
                updateHoverHighlight(at: mouseInWindow)
            }
        } else if !cmdNow && isCmdHeld {
            // Cmd just released — clear hover first, then bulk highlights
            isCmdHeld = false
            clearHoverHighlight()
            clearCharacterAndLocationHighlights()
            NSCursor.iBeam.set()
        }
    }

    /// Check if a ScriptElement type is navigable via Cmd+Click
    private func isNavigableElement(_ element: ScriptElement) -> Bool {
        switch element.type {
        case .character, .sceneHeading:
            return true
        case .dialogue, .parenthetical:
            return element.sourceItemId != nil
        case .action:
            // Scene description (no sourceItemId) is navigable
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

        // Find element at this position
        var foundRange: NSRange?
        for element in coordinator.parent.elements {
            if let range = coordinator.elementRanges[element.id],
               charIndex >= range.location && charIndex < range.location + range.length,
               isNavigableElement(element) {
                foundRange = range
                break
            }
        }

        // If same range already highlighted, nothing to do
        if foundRange == hoveredLinkRange { return }

        // Clear old highlight
        clearHoverHighlight()

        // Apply new highlight
        if let range = foundRange,
           range.location + range.length <= textStorage.length {
            // Save original attributes
            hoveredOriginalAttrs = textStorage.attributes(at: range.location, effectiveRange: nil)
            hoveredLinkRange = range

            // Apply underline + color
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

        // Restore original foreground color and remove underline
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
              let coordinator = coordinatorRef else { return }

        clearCharacterAndLocationHighlights()

        for element in coordinator.parent.elements {
            guard let range = coordinator.elementRanges[element.id],
                  range.location + range.length <= textStorage.length else { continue }

            let highlightColor: NSColor
            switch element.type {
            case .character:
                highlightColor = Self.characterHighlightColor
            case .sceneHeading:
                highlightColor = Self.locationHighlightColor
            default:
                continue
            }

            // Save original background so we can restore it
            let originalBg = textStorage.attribute(.backgroundColor, at: range.location, effectiveRange: nil)
            textStorage.addAttribute(.backgroundColor, value: highlightColor, range: range)
            bulkHighlightedRanges.append((range: range, originalBg: originalBg))
        }
    }

    private func clearCharacterAndLocationHighlights() {
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
        // Cmd+Click → Navigate to element's source page
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

            for element in coordinator.parent.elements {
                if let range = coordinator.elementRanges[element.id],
                   charIndex >= range.location && charIndex < range.location + range.length {
                    onCommandClickHandler?(element)
                    return
                }
            }
        }
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd+Shift+N → New Scene
        if event.modifierFlags.contains([.command, .shift]),
           event.charactersIgnoringModifiers?.lowercased() == "n" {
            onNewSceneShortcut?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        // Hit-test click location to find if it's on a scene heading
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

        // Check if the clicked character is within a scene heading element
        for element in coordinator.parent.elements {
            guard element.type == .sceneHeading,
                  let range = coordinator.elementRanges[element.id],
                  charIndex >= range.location && charIndex < range.location + range.length else { continue }

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
            break
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

        // Style the Delete button as destructive
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
        let lineHeight: CGFloat = ScreenplayFormatting.lineHeight + 2 // line + spacing
        let pageHeight = linesPerPage * lineHeight
        let contentHeight = layoutManager.usedRect(for: textContainer).height
        let insetY = textContainerInset.height
        let insetX = textContainerInset.width

        if showPagesMode {
            // --- Pages Mode ---
            // Gray desk with a single continuous cream page column + shadow + title page
            // Pages are stacked flush — no gaps — so text is never clipped mid-line.
            // Shadow is drawn only on the outer edges of the column (not between pages).

            let deskColor = NSColor(calibratedRed: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
            let fullPageWidth = ScreenplayFormatting.pageWidth // 612pt (8.5")

            // Center the page horizontally in the view
            let pageX = max(10, (bounds.width - fullPageWidth) / 2)

            // Fill entire rect with desk color
            deskColor.setFill()
            dirtyRect.fill()

            // Calculate total pages from content height (insetY includes title page offset)
            let totalContentHeight = contentHeight + insetY * 2
            let totalPages = max(1, Int(ceil(totalContentHeight / pageHeight)))
            let totalHeight = CGFloat(totalPages) * pageHeight

            // Draw one continuous cream column with shadow on outer edges only
            let columnRect = NSRect(x: pageX, y: 0, width: fullPageWidth, height: totalHeight)
            let drawableColumn = columnRect.intersection(dirtyRect.insetBy(dx: -16, dy: -16))

            if !drawableColumn.isNull {
                // Shadow (only visible on left/right/bottom edges of column)
                NSGraphicsContext.current?.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0.20)
                shadow.shadowOffset = NSSize(width: 3, height: 3)
                shadow.shadowBlurRadius = 8
                shadow.set()
                ScreenplayFormatting.backgroundColor.setFill()
                NSBezierPath(rect: drawableColumn).fill()
                NSGraphicsContext.current?.restoreGraphicsState()

                // Clean cream fill (no shadow)
                ScreenplayFormatting.backgroundColor.setFill()
                NSBezierPath(rect: drawableColumn).fill()
            }

            // Page break separator lines
            let separatorColor = NSColor(calibratedRed: 0.70, green: 0.68, blue: 0.65, alpha: 0.6)
            for pageIndex in 1..<totalPages {
                let breakY = CGFloat(pageIndex) * pageHeight
                let lineArea = NSRect(x: pageX, y: breakY - 1, width: fullPageWidth, height: 2)
                if dirtyRect.intersects(lineArea) {
                    separatorColor.setFill()
                    NSBezierPath(rect: NSRect(x: pageX, y: breakY - 0.5, width: fullPageWidth, height: 1)).fill()
                }
            }

            // Draw title page content on page 0
            let titlePageRect = NSRect(x: pageX, y: 0, width: fullPageWidth, height: pageHeight)
            if dirtyRect.intersects(titlePageRect) {
                drawTitlePage(in: titlePageRect)
            }

            // super.draw() renders text only (drawsBackground is false in pages mode)
            // Text is offset by one pageHeight via textContainerInset, so starts on page 2
            super.draw(dirtyRect)
        } else {
            // --- Continuous Mode ---
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
        let titleFont = NSFont(name: "Courier-Bold", size: 24) ?? NSFont.monospacedSystemFont(ofSize: 24, weight: .bold)
        let byFont = NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let smallFont = NSFont(name: "Courier", size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)

        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center
        centerStyle.lineSpacing = 4

        let leftStyle = NSMutableParagraphStyle()
        leftStyle.alignment = .left
        leftStyle.lineSpacing = 2

        let textColor = ScreenplayFormatting.textColor
        let subtleColor = ScreenplayFormatting.sceneNumberColor

        let contentInsetX: CGFloat = 108 // 1.5" left margin
        let contentRight: CGFloat = 72   // 1" right margin
        let contentWidth = pageRect.width - contentInsetX - contentRight

        // --- Title block: centered vertically in upper 60% of page ---
        let titleBlockTop = pageRect.origin.y + pageRect.height * 0.33

        // Project name (large, bold, centered)
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

        // Calculate how tall the title actually rendered
        let titleSize = (displayName as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: 80),
            options: [.usesLineFragmentOrigin],
            attributes: titleAttrs
        )

        // "written by" (centered, normal weight)
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

            // Director name (centered)
            let directorRect = NSRect(
                x: pageRect.origin.x + contentInsetX,
                y: byY + 24,
                width: contentWidth,
                height: 20
            )
            (directorName as NSString).draw(in: directorRect, withAttributes: byAttrs)
        }

        // --- Bottom-left block: production company, genre ---
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

        // Pre-select first row
        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    @objc func itemClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < items.count else { return }
        onSelect?(items[row].text)
    }

    // Keyboard navigation from text view delegate
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

        // Character avatar (circular)
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
                // Initials fallback
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

        // Text label in Courier
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

// MARK: - NSColor Hex Helper

private extension NSColor {
    static func fromHex(_ hex: String) -> NSColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }
}
