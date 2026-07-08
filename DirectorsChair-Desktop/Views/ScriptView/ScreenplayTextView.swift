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
    var onAutocompleteInsert: ((String, Int, Int) -> RebuildInstruction)?  // (text, elementIndex, cursorOffsetInElement) -> instruction
    var onPlaceholderEdit: ((Int, String) -> RebuildInstruction)?  // (elementIndex, newText) -> instruction
    /// WS7.1 — multi-line paste / multi-paragraph delete as one model op:
    /// (startElement, startUTF16Offset, endElement, endUTF16Offset, replacement)
    var onRangeReplace: ((Int, Int, Int, Int, String) -> RebuildInstruction)?
    /// WS7.2 — model-level undo/redo (built-in NSTextView undo is disabled).
    var onUndo: (() -> RebuildInstruction)?
    var onRedo: (() -> RebuildInstruction)?
    /// Editor v2 — direct element switching (⌃1–6): (elementIndex, digit)
    var onSetElementType: ((Int, Int) -> RebuildInstruction)?
    /// ⌘[ / ⌘] — app-level navigation history (back / forward)
    var onNavigateBack: (() -> Void)?
    var onNavigateForward: (() -> Void)?
    var onAutocompleteFilter: ((String) -> Void)?  // (prefix) -> Void

    // Wizard mode
    var isWizardActive: Bool = false
    /// Return/Tab during the wizard with no popover selection — accept the
    /// text the user typed as the current wizard step's value.
    var onWizardCommitTyped: (() -> Void)?
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
        // WS7.2: built-in undo is DISABLED — it would restore raw text without
        // the model and break the paragraph==element invariant. Cmd+Z/Cmd+Shift+Z
        // route to the model-level snapshot undo instead.
        textView.allowsUndo = false
        textView.onUndoRequested = { [weak coordinator = context.coordinator] in
            guard let coordinator, let instruction = coordinator.parent.onUndo?() else { return }
            coordinator.applyRebuildInstruction(instruction)
        }
        textView.onRedoRequested = { [weak coordinator = context.coordinator] in
            guard let coordinator, let instruction = coordinator.parent.onRedo?() else { return }
            coordinator.applyRebuildInstruction(instruction)
        }
        textView.onSetElementTypeRequested = { [weak coordinator = context.coordinator] digit in
            guard let coordinator, let textView = coordinator.textView else { return }
            let index = coordinator.elementIndexForCursor(textView.selectedRange().location)
            if let instruction = coordinator.parent.onSetElementType?(index, digit) {
                coordinator.applyRebuildInstruction(instruction)
            }
        }
        textView.onNavigateBackRequested = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onNavigateBack?()
        }
        textView.onNavigateForwardRequested = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onNavigateForward?()
        }
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

        // Handle focus element (wizard steps / wizard completion).
        // Deduplicated by a stamp so a focus request is applied exactly once —
        // re-applying on every SwiftUI update would fight the user's cursor.
        if let focusId = focusElementId {
            let stamp = "\(focusId.uuidString):\(focusCursorOffset)"
            if context.coordinator.lastAppliedFocusStamp != stamp {
                context.coordinator.lastAppliedFocusStamp = stamp
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
        } else {
            context.coordinator.lastAppliedFocusStamp = nil
        }

        // Scene numbers are margin decorations — repaint so toggling
        // visibility or renumbering shows up without a text rebuild.
        textView.needsDisplay = true
    }

    // Helper to access parent elements from updateNSView
    private var parent: ScreenplayTextView { self }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScreenplayTextView
        /// Focus-request dedup stamp (see updateNSView) — a focus is applied once.
        var lastAppliedFocusStamp: String?
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
                // INVARIANT: the paragraph text in the NSTextView is EXACTLY
                // element.text (modulo display uppercasing, which is
                // length-preserving). Scene numbers are NOT part of the text
                // stream — they are drawn as margin decorations by the text
                // view (drawSceneNumberMargins), so typing can never
                // interleave with them.
                var displayText = element.text

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

                if element.type != .blankLine {
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

            // WS7.1 — multi-line paste, or any edit whose range spans a
            // paragraph boundary, is a STRUCTURAL operation: route it through
            // the model so elements[] stays 1:1 with paragraphs. (Previously a
            // multi-line paste went straight to NSTextView while the model
            // synced only the paragraph under the cursor — silent data loss.)
            let replacementText = replacementString ?? ""
            let fullNSText = textView.string as NSString
            let safeRange = NSIntersectionRange(affectedCharRange, NSRange(location: 0, length: fullNSText.length))
            let affectedText = safeRange.length > 0 ? fullNSText.substring(with: safeRange) : ""
            let isMultiLinePaste = replacementText.contains("\n") && replacementText != "\n"
            let spansParagraphs = affectedText.contains("\n")

            if (isMultiLinePaste || spansParagraphs) && autocompletePanel == nil {
                let starts = paragraphStarts()
                let startIndex = elementIndexForCursor(safeRange.location)
                let endIndex = elementIndexForCursor(safeRange.location + safeRange.length)
                guard startIndex >= 0, endIndex < parent.elements.count,
                      startIndex < starts.count, endIndex < starts.count else { return true }
                let startOffset = safeRange.location - starts[startIndex]
                let endOffset = safeRange.location + safeRange.length - starts[endIndex]
                if let instruction = parent.onRangeReplace?(startIndex, max(0, startOffset),
                                                            endIndex, max(0, endOffset),
                                                            replacementText) {
                    applyRebuildInstruction(instruction)
                }
                return false // handled as a model operation
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
            // Paragraph text == element text (scene numbers live in the margins).
            let newText = textForParagraph(elementIndex)

            // Notify the ViewModel (no @Published mutation — just shadow buffer)
            parent.onTextChanged?(elementIndex, newText)

            // Autocomplete inline filtering. Also fires while the wizard is
            // active with the panel hidden (filter emptied it) so continued
            // typing can bring the suggestion list back.
            if autocompletePanel != nil || parent.isWizardActive {
                parent.onAutocompleteFilter?(newText)
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

            // Wizard mode with the popover hidden (filter emptied it, or the
            // project has no suggestions): Esc exits the wizard, Return/Tab
            // accept whatever the user typed, and EVERYTHING ELSE is normal
            // editing — Backspace and arrows must keep working.
            if parent.isWizardActive {
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                    parent.onAutocompleteDismissed?()
                    return true
                }
                if commandSelector == #selector(NSResponder.insertNewline(_:)) ||
                   commandSelector == #selector(NSResponder.insertTab(_:)) {
                    parent.onWizardCommitTyped?()
                    return true
                }
                return false
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
            let paragraphRange = rangeForParagraph(elementIndex)
            let offsetInElement = max(0, cursorLocation - paragraphRange.location)

            // Use the model-authoritative callback
            if let instruction = parent.onAutocompleteInsert?(text, elementIndex, offsetInElement) {
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
            // Paragraph text == element text (scene numbers live in the margins).
            let elementIndex = elementIndexForCursor(newPos)
            let newText = textForParagraph(elementIndex)
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

extension NSColor {
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
