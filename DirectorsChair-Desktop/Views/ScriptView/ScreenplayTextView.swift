//
//  ScreenplayTextView.swift
//  DirectorsChair-Desktop
//
//  Script View: NSViewRepresentable wrapping NSTextView for screenplay rendering and editing.
//  Architecture: Model-authoritative. Paragraph N == elements[N]. No range tracking.
//

import SwiftUI
import AppKit

/// NSViewRepresentable wrapping NSTextView for professional screenplay rendering
struct ScreenplayTextView: NSViewRepresentable {
    @Binding var elements: [ScriptElement]
    var elementsVersion: Int = 0
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
    var onDoubleClickScene: ((ScriptElement) -> Void)?  // Double-click scene heading

    // Structural edit callbacks (model-authoritative)
    var onReturn: ((Int, Int) -> RebuildInstruction)?  // (elementIndex, cursorOffset) -> instruction
    var onBackspace: ((Int, Int) -> RebuildInstruction)?  // (elementIndex, cursorOffset) -> instruction
    var onTabCycle: ((Int) -> RebuildInstruction)?  // (elementIndex) -> instruction
    var onAutocompleteInsert: ((String, Int) -> RebuildInstruction)?  // (text, elementIndex) -> instruction
    var onPlaceholderEdit: ((Int, String) -> RebuildInstruction)?  // (elementIndex, newText) -> instruction
    var onAutocompleteFilter: ((String) -> Void)?  // (prefix) -> Void

    // Wizard mode
    var isWizardActive: Bool = false
    var focusElementId: UUID?
    var focusCursorOffset: Int = 0

    // Pages mode
    var showPagesMode: Bool = false

    // Title page metadata (used in pages mode)
    var projectName: String = ""
    var directorName: String = ""
    var productionCompany: String = ""
    var genre: String = ""

    // Spell check
    var spellCheckEnabled: Bool = false

    // Typewriter mode
    var typewriterMode: Bool = false

    // Transliteration
    var transliterationEnabled: Bool = false
    var transliterationService: TransliterationService?

    // Character image lookup for Cmd+highlight badges: [uppercased name -> (imagePath, color)]
    var characterImageMap: [String: (imagePath: String?, color: String?)] = [:]

    // Zoom
    @Binding var magnification: CGFloat

    // Scroll position tracking & restoration
    var onScrollYChanged: ((CGFloat) -> Void)?
    var restoreScrollY: CGFloat?

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
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        // Force light appearance for typewriter aesthetic
        textView.appearance = NSAppearance(named: .aqua)
        scrollView.appearance = NSAppearance(named: .aqua)

        textView.backgroundColor = ScreenplayFormatting.backgroundColor
        textView.insertionPointColor = ScreenplayFormatting.textColor
        textView.drawsBackground = false

        // Text container sizing - centered screenplay "page"
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: ScreenplayFormatting.contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.lineFragmentPadding = 0

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

        // Wire double-click scene heading handler
        textView.onDoubleClickSceneHandler = { [weak coordinator = context.coordinator] element in
            coordinator?.parent.onDoubleClickScene?(element)
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

        // Track scroll position changes for back/forward navigation restoration
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.clipViewBoundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // Build initial content
        context.coordinator.rebuildAttributedString()

        // Auto-focus
        DispatchQueue.main.async {
            scrollView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ScreenplayNSTextView else { return }

        // CRITICAL: Update coordinator's parent reference so it sees current elements
        context.coordinator.parent = self

        // Update pages mode on the NSTextView and trigger redraw if changed
        if textView.showPagesMode != showPagesMode {
            textView.showPagesMode = showPagesMode
            textView.drawsBackground = false
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
        let availableWidth = scrollView.frame.width - 20
        let horizontalInset: CGFloat
        let verticalInset: CGFloat
        if showPagesMode {
            let pageX = max(20, (availableWidth - ScreenplayFormatting.pageWidth) / 2)
            horizontalInset = pageX + ScreenplayFormatting.marginLeft
            let lineH: CGFloat = ScreenplayFormatting.lineHeight + 2
            let pageH: CGFloat = 55 * lineH
            let pageTopMargin: CGFloat = 5 * lineH
            verticalInset = pageH + pageTopMargin
        } else {
            horizontalInset = max(20, (availableWidth - ScreenplayFormatting.contentWidth) / 2)
            verticalInset = ScreenplayNSTextView.continuousTitleBlockHeight + ScreenplayFormatting.marginTop
        }
        textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)

        // Toggle spell check
        if textView.isContinuousSpellCheckingEnabled != spellCheckEnabled {
            textView.isContinuousSpellCheckingEnabled = spellCheckEnabled
            textView.isGrammarCheckingEnabled = spellCheckEnabled
        }

        // Toggle typewriter mode
        textView.typewriterModeEnabled = typewriterMode

        // Apply magnification from binding
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
        if context.coordinator.lastElementsVersion != elementsVersion ||
           context.coordinator.needsRebuild {
            context.coordinator.rebuildAttributedString()
            context.coordinator.lastElementsVersion = elementsVersion
            context.coordinator.needsRebuild = false
        }

        // Scroll to element if requested
        if let targetId = scrollToElementId {
            let targetIndex = parent.elements.firstIndex(where: { $0.id == targetId })
            if let idx = targetIndex {
                let range = context.coordinator.rangeForParagraph(idx)
                DispatchQueue.main.async {
                    textView.scrollRangeToVisible(range)
                    textView.showFindIndicator(for: range)
                }
            }
        }

        // Restore scroll position from back/forward navigation
        if !context.coordinator.hasRestoredScrollPosition,
           scrollToElementId == nil,
           let restoreY = restoreScrollY {
            context.coordinator.hasRestoredScrollPosition = true
            DispatchQueue.main.async {
                let clipView = scrollView.contentView
                var origin = clipView.bounds.origin
                origin.y = restoreY
                clipView.setBoundsOrigin(origin)
                scrollView.reflectScrolledClipView(clipView)
            }
        }

        // Handle autocomplete panel
        if showingAutocomplete && !autocompleteItems.isEmpty {
            context.coordinator.showAutocompletePopover(items: autocompleteItems, trigger: autocompleteTrigger)
        } else {
            context.coordinator.hideAutocompletePanel()
        }

        // Handle focus element (wizard steps / wizard completion)
        if let focusId = focusElementId {
            context.coordinator.rebuildAttributedString()
            if let idx = parent.elements.firstIndex(where: { $0.id == focusId }) {
                let range = context.coordinator.rangeForParagraph(idx)
                let offset = focusCursorOffset
                let cursorPos = min(range.location + offset, range.location + range.length)
                textView.setSelectedRange(NSRange(location: cursorPos, length: 0))
                textView.scrollRangeToVisible(NSRange(location: cursorPos, length: 0))
                let elementType = parent.elements[idx].type
                textView.typingAttributes = ScreenplayFormatting.attributes(for: elementType == .sceneHeading ? .sceneHeading : .action)
            }
        }
    }

    // Helper to access parent elements from updateNSView
    private var parent: ScreenplayTextView { self }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScreenplayTextView
        weak var textView: ScreenplayNSTextView?
        weak var scrollView: NSScrollView?

        var lastElementsVersion = -1
        var needsRebuild = false
        var isUpdating = false
        var hasCenteredOnFirstLayout = false
        var hasRestoredScrollPosition = false

        private var autocompletePanel: NSPanel?
        private var autocompleteVC: AutocompleteViewController?

        // Wizard autocomplete filter prefix (typing filters without modifying placeholder text)
        var wizardFilterPrefix = ""

        // Transliteration state
        private var transliterationPanel: NSPanel?
        private var transliterationVC: TransliterationCandidatesVC?
        private var transliterationTask: Task<Void, Never>?
        private var transliterationCandidates: [String] = []
        private var transliterationSelectedIndex: Int = 0
        private var transliterationBufferRange: NSRange?

        // MARK: - Cached Paragraph Starts (Performance)
        // Computed once per edit cycle, invalidated on rebuild.
        // Avoids O(n) text scan on every keystroke.
        private var cachedStarts: [Int]?

        /// Invalidate the cached paragraph starts (call after text changes or rebuild).
        private func invalidateCache() {
            cachedStarts = nil
        }

        init(_ parent: ScreenplayTextView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            hideAutocompletePanel()
            hideTransliterationPopup()
            transliterationTask?.cancel()
        }

        // MARK: - Paragraph Utilities (Optimized)

        /// Compute paragraph starts using UTF-16 for NSString compatibility.
        /// Cached per edit cycle — only recomputed when invalidated.
        func paragraphStarts() -> [Int] {
            if let cached = cachedStarts { return cached }
            guard let textView = textView else { return [] }
            let nsString = textView.string as NSString
            let length = nsString.length
            var starts: [Int] = [0]
            starts.reserveCapacity(parent.elements.count + 1)
            for i in 0..<length {
                if nsString.character(at: i) == 0x0A {
                    starts.append(i + 1)
                }
            }
            cachedStarts = starts
            return starts
        }

        /// Find element index for cursor position using binary search on cached paragraph starts.
        func elementIndexForCursor(_ pos: Int) -> Int {
            let starts = paragraphStarts()
            guard !starts.isEmpty else { return 0 }

            // Binary search: find largest start <= pos
            var lo = 0, hi = starts.count - 1
            while lo < hi {
                let mid = lo + (hi - lo + 1) / 2
                if starts[mid] <= pos {
                    lo = mid
                } else {
                    hi = mid - 1
                }
            }
            return min(lo, max(0, parent.elements.count - 1))
        }

        /// Get the NSRange for paragraph at the given element index.
        func rangeForParagraph(_ index: Int) -> NSRange {
            guard let textView = textView else { return NSRange(location: 0, length: 0) }
            let starts = paragraphStarts()
            guard index >= 0, index < starts.count else { return NSRange(location: 0, length: 0) }
            let start = starts[index]
            let end: Int
            if index + 1 < starts.count {
                end = starts[index + 1] - 1
            } else {
                end = (textView.string as NSString).length
            }
            return NSRange(location: start, length: max(0, end - start))
        }

        /// Extract the text of a specific paragraph. Uses cached starts.
        func textForParagraph(_ index: Int) -> String {
            guard let textView = textView else { return "" }
            let range = rangeForParagraph(index)
            guard range.length > 0 else { return "" }
            return (textView.string as NSString).substring(with: range)
        }

        /// Get the cursor offset within the current paragraph. Uses cached starts.
        func cursorOffsetInParagraph(_ paragraphIndex: Int) -> Int {
            guard let textView = textView else { return 0 }
            let cursorPos = textView.selectedRange().location
            let starts = paragraphStarts()
            guard paragraphIndex >= 0, paragraphIndex < starts.count else { return 0 }
            return max(0, cursorPos - starts[paragraphIndex])
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

        @objc func clipViewBoundsChanged(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView else { return }
            parent.onScrollYChanged?(clipView.bounds.origin.y)
        }

        func centerHorizontallyDeferred() {
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
                let pageTopMargin: CGFloat = 5 * lineH
                verticalInset = pageH + pageTopMargin
            } else {
                horizontalInset = max(20, (availableWidth - ScreenplayFormatting.contentWidth) / 2)
                verticalInset = ScreenplayNSTextView.continuousTitleBlockHeight + ScreenplayFormatting.marginTop
            }
            textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        }

        // MARK: - Build Attributed String

        func rebuildAttributedString() {
            guard let textView = textView else { return }

            isUpdating = true
            // Save cursor position so the second rebuild (from updateNSView) doesn't lose it
            let savedSelection = textView.selectedRange()
            defer {
                isUpdating = false
                invalidateCache() // paragraph positions changed
                // Restore cursor position (clamped to valid range)
                let maxPos = (textView.string as NSString).length
                let restoredLoc = min(savedSelection.location, maxPos)
                let restoredLen = min(savedSelection.length, max(0, maxPos - restoredLoc))
                textView.setSelectedRange(NSRange(location: restoredLoc, length: restoredLen))
            }

            let fullString = NSMutableAttributedString()

            for (index, element) in parent.elements.enumerated() {
                var displayText = element.text
                if element.type == .sceneHeading && parent.showSceneNumbers {
                    if let num = element.sceneNumber {
                        displayText = "\(num)    \(element.text)    \(num)"
                    }
                }

                if element.type == .blankLine {
                    displayText = ""
                }

                // Auto-capitalize
                if element.type == .sceneHeading || element.type == .character || element.type == .transition {
                    displayText = displayText.uppercased()
                }

                // Placeholder styling
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
                    // Blank line: empty string with blank line paragraph style
                    let attributed = NSAttributedString(string: "", attributes: [
                        .font: ScreenplayFormatting.font,
                        .paragraphStyle: ScreenplayFormatting.paragraphStyle(for: .blankLine)
                    ])
                    fullString.append(attributed)
                }

                // Add newline between elements (maintaining paragraph invariant)
                if index < parent.elements.count - 1 {
                    fullString.append(NSAttributedString(string: "\n"))
                }
            }

            textView.textStorage?.setAttributedString(fullString)
        }

        // MARK: - Apply Rebuild Instruction

        func applyRebuildInstruction(_ instruction: RebuildInstruction) {
            switch instruction {
            case .none:
                break

            case .updateParagraph(let index):
                // Re-style a single paragraph without full rebuild
                rebuildAttributedString()
                if let textView = textView, index < parent.elements.count {
                    let range = rangeForParagraph(index)
                    textView.setSelectedRange(NSRange(location: range.location + range.length, length: 0))
                }

            case .insertParagraph(_, let focusId):
                rebuildAttributedString()
                if let textView = textView,
                   let idx = parent.elements.firstIndex(where: { $0.id == focusId }) {
                    let range = rangeForParagraph(idx)
                    textView.setSelectedRange(NSRange(location: range.location, length: 0))
                    textView.scrollRangeToVisible(NSRange(location: range.location, length: 0))
                }

            case .removeParagraph(_):
                rebuildAttributedString()

            case .fullRebuild(let focusId, let cursorOffset):
                rebuildAttributedString()
                if let textView = textView, let focusId = focusId,
                   let idx = parent.elements.firstIndex(where: { $0.id == focusId }) {
                    let range = rangeForParagraph(idx)
                    let offset = cursorOffset ?? 0
                    let cursorPos = min(range.location + offset, range.location + range.length)
                    textView.setSelectedRange(NSRange(location: cursorPos, length: 0))
                    textView.scrollRangeToVisible(NSRange(location: cursorPos, length: 0))

                    // Set typing attributes for the focused element
                    let element = parent.elements[idx]
                    textView.typingAttributes = ScreenplayFormatting.attributes(for: element.type)
                }
            }
        }

        // MARK: - NSTextViewDelegate

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard !isUpdating else { return false }

            // TRANSLITERATION: Intercept Space/punctuation/digits when transliteration popup is showing
            if transliterationPanel != nil, let replacement = replacementString {
                // Space → commit selected candidate + space
                if replacement == " " {
                    commitTransliteration(appendString: " ")
                    return false
                }
                // Punctuation → commit candidate + punctuation
                if replacement.count == 1, ".!?,;:".contains(replacement) {
                    commitTransliteration(appendString: replacement)
                    return false
                }
                // Digit 1-5 → select nth candidate and commit
                if replacement.count == 1, let digit = Int(replacement), digit >= 1, digit <= 5 {
                    if digit - 1 < transliterationCandidates.count {
                        transliterationSelectedIndex = digit - 1
                        transliterationVC?.setSelectedIndex(digit - 1)
                        commitTransliteration(appendString: " ")
                    }
                    return false
                }
            }

            // PHASE 1: Detect structural operations and intercept them

            // Detect newline insertion (Return key handled by doCommandBy, but paste could insert newlines)
            if let replacement = replacementString, replacement.contains("\n") && replacement != "\n" {
                // Multi-line paste — allow it, textDidChange will handle
                return true
            }

            // Detect backspace that would delete a newline (merge two paragraphs)
            if let replacement = replacementString, replacement.isEmpty,
               affectedCharRange.length == 1 {
                let fullText = textView.string as NSString
                if affectedCharRange.location < fullText.length {
                    let charBeingDeleted = fullText.character(at: affectedCharRange.location)
                    if charBeingDeleted == 0x0A { // newline
                        // If autocomplete is open, allow backspace through without structural merge
                        if autocompletePanel != nil {
                            return true
                        }
                        debugLog("🔑 shouldChangeTextIn: BACKSPACE across line boundary at \(affectedCharRange.location)")
                        let elementIndex = elementIndexForCursor(affectedCharRange.location)
                        // The newline being deleted is at the end of elementIndex, so we're merging elementIndex+1 into elementIndex
                        let mergeIndex = elementIndex + 1
                        if mergeIndex < parent.elements.count {
                            if let instruction = parent.onBackspace?(mergeIndex, 0) {
                                applyRebuildInstruction(instruction)
                            }
                        }
                        return false // we handled it
                    }
                }
            }

            // PHASE 2: Handle placeholder elements — typing replaces placeholder
            // Skip when autocomplete is active (wizard mode) so chars go through for filtering
            if autocompletePanel == nil {
                if let replacement = replacementString, !replacement.isEmpty, replacement != "\n" {
                    let elementIndex = elementIndexForCursor(affectedCharRange.location)
                    if elementIndex >= 0, elementIndex < parent.elements.count,
                       parent.elements[elementIndex].isPlaceholder {
                        if let instruction = parent.onPlaceholderEdit?(elementIndex, replacement) {
                            applyRebuildInstruction(instruction)
                        }
                        return false // we handled it
                    }
                }
            }

            // PHASE 3: Check for smart shortcut triggers (skip if autocomplete already active)
            guard let replacement = replacementString, replacement.count == 1 else { return true }

            if autocompletePanel != nil {
                // Autocomplete is active — let characters through for inline filtering
                return true
            }

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
                DispatchQueue.main.async {
                    self.parent.onAutocompleteSelected?(replacement)
                }
                return false // consume the trigger character
            }

            return true
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = textView else { return }

            // Invalidate cache since text changed
            invalidateCache()

            // Find which paragraph changed — uses cached binary search
            let cursorLocation = textView.selectedRange().location
            let elementIndex = elementIndexForCursor(cursorLocation)

            guard elementIndex >= 0, elementIndex < parent.elements.count else {
                updateTypingAttributes(at: cursorLocation)
                return
            }

            // Extract the current text for this paragraph (uses same cached starts)
            var newText = textForParagraph(elementIndex)

            // Strip scene numbers if this is a scene heading with numbers displayed
            let element = parent.elements[elementIndex]
            if element.type == .sceneHeading, parent.showSceneNumbers, let num = element.sceneNumber {
                let prefix = "\(num)    "
                let suffix = "    \(num)"
                if newText.hasPrefix(prefix) && newText.hasSuffix(suffix) {
                    let startIdx = newText.index(newText.startIndex, offsetBy: prefix.count)
                    let endIdx = newText.index(newText.endIndex, offsetBy: -suffix.count)
                    if startIdx <= endIdx {
                        newText = String(newText[startIdx..<endIdx])
                    }
                }
            }

            // Notify the ViewModel (no @Published mutation — just shadow buffer)
            parent.onTextChanged?(elementIndex, newText)

            // Autocomplete inline filtering
            if autocompletePanel != nil {
                let prefix = newText
                parent.onAutocompleteFilter?(prefix)
            }

            // Transliteration: extract current word and query API
            if parent.transliterationEnabled && autocompletePanel == nil {
                handleTransliterationInput(cursorLocation: cursorLocation)
            }

            // Update typing attributes using the already-known element index
            updateTypingAttributesFast(elementIndex: elementIndex, cursorLocation: cursorLocation)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating, let textView = textView else { return }
            updateTypingAttributes(at: textView.selectedRange().location)
            scrollToInsertionPointIfTypewriterMode()
        }

        private func scrollToInsertionPointIfTypewriterMode() {
            guard let textView = textView as? ScreenplayNSTextView,
                  textView.typewriterModeEnabled,
                  let scrollView = scrollView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let insertionPoint = textView.selectedRange().location
            let glyphCount = layoutManager.numberOfGlyphs
            guard glyphCount > 0 else { return }

            let safeIndex = min(insertionPoint, glyphCount - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: safeIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            let lineY = lineRect.origin.y + textView.textContainerOrigin.y
            let visibleHeight = scrollView.contentView.bounds.height
            let targetY = lineY - visibleHeight / 2 + lineRect.height / 2

            let clipView = scrollView.contentView
            var origin = clipView.bounds.origin
            origin.y = max(0, targetY)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                clipView.setBoundsOrigin(origin)
            }
        }

        /// Update typing attributes given a cursor location. Computes element index internally.
        private func updateTypingAttributes(at cursorLocation: Int) {
            let elementIndex = elementIndexForCursor(cursorLocation)
            updateTypingAttributesFast(elementIndex: elementIndex, cursorLocation: cursorLocation)
        }

        /// Fast path: update typing attributes when element index is already known.
        /// Avoids redundant paragraph counting.
        private func updateTypingAttributesFast(elementIndex: Int, cursorLocation: Int) {
            guard let textView = textView,
                  elementIndex >= 0, elementIndex < parent.elements.count else {
                textView?.typingAttributes = ScreenplayFormatting.attributes(for: .action)
                return
            }

            let element = parent.elements[elementIndex]

            // Check if cursor is at end of paragraph (uses cached starts)
            let pRange = rangeForParagraph(elementIndex)
            let atEnd = (cursorLocation >= pRange.location + pRange.length)

            let targetType: ScriptElementType
            if atEnd {
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
        }

        // MARK: - New Scene (Cmd+Shift+N)

        func handleNewScene() {
            guard let textView = textView else { return }
            let cursorLocation = textView.selectedRange().location
            let currentIndex = elementIndexForCursor(cursorLocation)
            parent.onNewScene?(currentIndex)

            DispatchQueue.main.async {
                self.needsRebuild = true
                self.rebuildAttributedString()
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle transliteration keyboard interaction
            if transliterationPanel != nil {
                if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    commitTransliteration(appendString: "")
                    // Defer Return to next run loop so textStorage + model state settle
                    DispatchQueue.main.async { [weak self] in
                        self?.handleReturnKey()
                    }
                    return true
                }
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                    hideTransliterationPopup()
                    return true
                }
                if commandSelector == #selector(NSResponder.moveUp(_:)) {
                    transliterationVC?.moveSelectionUp()
                    transliterationSelectedIndex = transliterationVC?.selectedIndex ?? 0
                    return true
                }
                if commandSelector == #selector(NSResponder.moveDown(_:)) {
                    transliterationVC?.moveSelectionDown()
                    transliterationSelectedIndex = transliterationVC?.selectedIndex ?? 0
                    return true
                }
            }

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

            // During wizard mode, block structural keys (Return/Tab/Escape) when
            // autocomplete is hidden (e.g. filter returned no matches)
            if parent.isWizardActive {
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                    parent.onAutocompleteDismissed?()
                    return true
                }
                return true // consume all other commands during wizard
            }

            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                handleReturnKey()
                return true
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
                parent.onAutocompleteSelected?(selected)
                hideAutocompletePanel()
            } else {
                insertAutocompleteText(selected)
            }
        }

        func insertAutocompleteText(_ text: String) {
            guard let textView = textView else { return }

            let cursorLocation = textView.selectedRange().location
            let elementIndex = elementIndexForCursor(cursorLocation)

            // Use the model-authoritative callback
            if let instruction = parent.onAutocompleteInsert?(text, elementIndex) {
                // Dismiss autocomplete
                parent.onAutocompleteSelected?(text)
                hideAutocompletePanel()

                // Apply the instruction synchronously to prevent race conditions
                applyRebuildInstruction(instruction)
            } else {
                // Fallback: insert text via model path to stay model-authoritative
                isUpdating = true
                let range = textView.selectedRange()
                let attrs = ScreenplayFormatting.attributes(for: .character)
                let insertStr = NSAttributedString(string: text.uppercased(), attributes: attrs)
                textView.textStorage?.replaceCharacters(in: range, with: insertStr)
                textView.setSelectedRange(NSRange(location: range.location + text.count, length: 0))
                textView.typingAttributes = ScreenplayFormatting.attributes(for: .dialogue)
                isUpdating = false

                invalidateCache()

                // Notify model of the text change
                let newText = textForParagraph(elementIndex)
                parent.onTextChanged?(elementIndex, newText)

                parent.onAutocompleteSelected?(text)
                hideAutocompletePanel()
            }
        }

        // MARK: - Tab Key

        private func handleTabKey() {
            guard let textView = textView else { return }
            let cursorLocation = textView.selectedRange().location
            let elementIndex = elementIndexForCursor(cursorLocation)

            if let instruction = parent.onTabCycle?(elementIndex) {
                applyRebuildInstruction(instruction)
            }
        }

        // MARK: - Return Key

        private func handleReturnKey() {
            guard let textView = textView else { return }
            let cursorLocation = textView.selectedRange().location
            let elementIndex = elementIndexForCursor(cursorLocation)
            let cursorOffset = cursorOffsetInParagraph(elementIndex)

            if let instruction = parent.onReturn?(elementIndex, cursorOffset) {
                applyRebuildInstruction(instruction)
            }
        }

        // MARK: - Autocomplete

        private func autocompleteScreenPosition() -> NSPoint? {
            guard let textView = textView, let window = textView.window else { return nil }

            let charIndex = textView.selectedRange().location
            var actualRange = NSRange(location: 0, length: 0)
            let screenRect = textView.firstRect(forCharacterRange: NSRange(location: charIndex, length: 0), actualRange: &actualRange)

            if screenRect != .zero {
                return NSPoint(x: screenRect.origin.x, y: screenRect.origin.y)
            }

            // Fallback: glyph-based calculation
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return nil }

            let glyphCount = layoutManager.numberOfGlyphs
            guard glyphCount > 0 else { return nil }
            let safeCharIndex = min(charIndex, glyphCount - 1)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: safeCharIndex)
            var glyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: textContainer
            )
            glyphRect.origin.x += textView.textContainerOrigin.x
            glyphRect.origin.y += textView.textContainerOrigin.y

            let windowRect = textView.convert(glyphRect, to: nil)
            let fallbackScreenRect = window.convertToScreen(windowRect)
            return NSPoint(x: fallbackScreenRect.origin.x, y: fallbackScreenRect.origin.y)
        }

        func showAutocompletePopover(items: [AutocompleteItem], trigger: String) {
            guard let textView = textView,
                  let window = textView.window else { return }

            // Reset wizard filter when new autocomplete items are provided (new wizard step)
            wizardFilterPrefix = ""

            let rowHeight: CGFloat = 32
            let panelWidth: CGFloat = 240
            let panelHeight = min(CGFloat(items.count) * rowHeight + 8, 200)

            // If panel already exists, just update items and reposition
            if let panel = autocompletePanel, let vc = autocompleteVC {
                vc.updateItems(items)
                // Resize panel
                var frame = panel.frame
                frame.size.height = panelHeight
                if let pos = autocompleteScreenPosition() {
                    frame.origin.x = pos.x
                    frame.origin.y = pos.y - panelHeight - 2
                } else {
                    frame.origin.y = frame.origin.y + frame.size.height - panelHeight
                }
                panel.setFrame(frame, display: true)
                if let wrapper = panel.contentView {
                    wrapper.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
                    vc.view.frame = wrapper.bounds
                }
                return
            }

            guard let pos = autocompleteScreenPosition() else { return }
            let panelX = pos.x
            let panelY = pos.y - panelHeight - 2

            let vc = AutocompleteViewController()
            vc.items = items
            vc.projectBasePath = parent.projectBasePath
            vc.onSelect = { [weak self] selected in
                guard let self = self else { return }
                if self.parent.isWizardActive {
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

            let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
            wrapper.wantsLayer = true
            wrapper.layer?.backgroundColor = ScreenplayFormatting.backgroundColor.cgColor
            wrapper.layer?.cornerRadius = 4
            wrapper.layer?.borderColor = ScreenplayFormatting.sceneNumberColor.withAlphaComponent(0.25).cgColor
            wrapper.layer?.borderWidth = 0.5
            wrapper.layer?.masksToBounds = true

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

        // MARK: - Transliteration

        private func handleTransliterationInput(cursorLocation: Int) {
            guard let textView = textView else { return }

            let nsString = textView.string as NSString
            let length = nsString.length
            guard cursorLocation <= length else { return }

            // Scan backward from cursor to find the current ASCII word
            var wordStart = cursorLocation
            while wordStart > 0 {
                let prevChar = nsString.character(at: wordStart - 1)
                guard let scalar = Unicode.Scalar(prevChar) else { break }
                // Stop at space, newline, or non-ASCII
                if scalar == " " || scalar == "\n" || !scalar.isASCII {
                    break
                }
                // Stop at punctuation
                let ch = Character(scalar)
                if ".!?,;:@#$%^~/\"'()[]{}".contains(ch) {
                    break
                }
                wordStart -= 1
            }

            let wordRange = NSRange(location: wordStart, length: cursorLocation - wordStart)
            let word = nsString.substring(with: wordRange)

            // Only transliterate if it's pure ASCII letters
            let isAsciiLetters = !word.isEmpty && word.allSatisfy { $0.isASCII && $0.isLetter }

            if !isAsciiLetters || word.isEmpty {
                hideTransliterationPopup()
                transliterationBufferRange = nil
                transliterationTask?.cancel()
                return
            }

            transliterationBufferRange = wordRange

            // Debounced API query
            transliterationTask?.cancel()
            let currentWord = word
            let service = parent.transliterationService
            transliterationTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms debounce
                guard !Task.isCancelled else { return }
                guard let self = self, let service = service else { return }

                do {
                    let candidates = try await service.transliterate(currentWord)
                    guard !Task.isCancelled else { return }
                    if !candidates.isEmpty {
                        self.transliterationCandidates = candidates
                        self.transliterationSelectedIndex = 0
                        self.showTransliterationPopup(candidates: candidates)
                    } else {
                        self.hideTransliterationPopup()
                    }
                } catch {
                    // API error — just don't show popup
                    if !Task.isCancelled {
                        self.hideTransliterationPopup()
                    }
                }
            }
        }

        func commitTransliteration(appendString: String = "") {
            guard let textView = textView,
                  let range = transliterationBufferRange,
                  transliterationSelectedIndex < transliterationCandidates.count else {
                hideTransliterationPopup()
                return
            }

            isUpdating = true
            let candidate = transliterationCandidates[transliterationSelectedIndex] + appendString
            textView.textStorage?.replaceCharacters(in: range, with: candidate)
            let newPos = range.location + (candidate as NSString).length
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
            isUpdating = false

            invalidateCache()
            hideTransliterationPopup()

            // Notify model of the text change
            let elementIndex = elementIndexForCursor(newPos)
            var newText = textForParagraph(elementIndex)

            // Strip scene numbers if needed
            let element = parent.elements[elementIndex]
            if element.type == .sceneHeading, parent.showSceneNumbers, let num = element.sceneNumber {
                let prefix = "\(num)    "
                let suffix = "    \(num)"
                if newText.hasPrefix(prefix) && newText.hasSuffix(suffix) {
                    let startIdx = newText.index(newText.startIndex, offsetBy: prefix.count)
                    let endIdx = newText.index(newText.endIndex, offsetBy: -suffix.count)
                    if startIdx <= endIdx {
                        newText = String(newText[startIdx..<endIdx])
                    }
                }
            }

            parent.onTextChanged?(elementIndex, newText)
        }

        func showTransliterationPopup(candidates: [String]) {
            guard let textView = textView,
                  let window = textView.window else { return }

            let rowHeight: CGFloat = 26
            let panelWidth: CGFloat = 220
            let panelHeight = min(CGFloat(candidates.count) * rowHeight + 8, 160)

            // If panel already exists, just update
            if let panel = transliterationPanel, let vc = transliterationVC {
                vc.updateItems(candidates)
                vc.setSelectedIndex(0)
                var frame = panel.frame
                frame.size.height = panelHeight
                if let pos = autocompleteScreenPosition() {
                    frame.origin.x = pos.x
                    frame.origin.y = pos.y - panelHeight - 2
                } else {
                    frame.origin.y = frame.origin.y + frame.size.height - panelHeight
                }
                panel.setFrame(frame, display: true)
                if let wrapper = panel.contentView {
                    wrapper.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
                    vc.view.frame = wrapper.bounds
                }
                return
            }

            guard let pos = autocompleteScreenPosition() else { return }
            let panelX = pos.x
            let panelY = pos.y - panelHeight - 2

            let vc = TransliterationCandidatesVC()
            vc.items = candidates
            vc.onSelect = { [weak self] selected in
                guard let self = self else { return }
                if let idx = self.transliterationCandidates.firstIndex(of: selected) {
                    self.transliterationSelectedIndex = idx
                }
                self.commitTransliteration(appendString: " ")
            }

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

            let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
            wrapper.wantsLayer = true
            wrapper.layer?.backgroundColor = ScreenplayFormatting.backgroundColor.cgColor
            wrapper.layer?.cornerRadius = 4
            wrapper.layer?.borderColor = ScreenplayFormatting.sceneNumberColor.withAlphaComponent(0.25).cgColor
            wrapper.layer?.borderWidth = 0.5
            wrapper.layer?.masksToBounds = true

            vc.loadView()
            vc.view.frame = wrapper.bounds
            vc.view.autoresizingMask = [.width, .height]
            wrapper.addSubview(vc.view)

            panel.contentView = wrapper

            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)

            self.transliterationPanel = panel
            self.transliterationVC = vc
        }

        func hideTransliterationPopup() {
            transliterationTask?.cancel()
            if let panel = transliterationPanel {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            transliterationPanel = nil
            transliterationVC = nil
            transliterationCandidates = []
            transliterationSelectedIndex = 0
            transliterationBufferRange = nil
        }
    }
}

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

// MARK: - NSColor Hex Helper

extension NSColor {
    static func fromHexStr(_ hex: String) -> NSColor {
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
