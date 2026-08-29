// DirectorsChairViews/Cinematography/MentionTextView.swift
//
// DC-0095: a description editor that draws its mentions inline. The MODEL
// stays plain text with tokens ("@Susan", "#Outside the mini van",
// "$Mini van", "&Shot #3") — prompts, sync and older builds read it as
// before. The VIEW shows each token as a pill with the thing's picture:
// one click selects the pill (delete or move it like any text), a
// double-click opens the thing's page (owner request 2026-08-29). Built
// on NSTextView because SwiftUI's TextEditor cannot draw pictures inline.

import AppKit
import DirectorsChairCore
import SwiftUI

extension NSAttributedString.Key {
    /// The plain token a pill stands for ("$Mini van").
    static let mentionToken = NSAttributedString.Key("dc.mentionToken")
}

/// Token → resolved thing, with the token's range in a plain string.
enum MentionTokenizer {
    /// Every token in `text` with its range, longest names first so
    /// "Susan Lee" beats "Susan", non-overlapping, in text order.
    static func tokens(in text: String, characters: [Character], locations: [Location],
                       props: [Prop], shots: [Shot]) -> [(range: Range<String.Index>, mention: ResolvedMention)] {
        var names: [(String, ResolvedMention)] = []
        names += characters.map { ("@" + $0.name, ResolvedMention(kind: .character, id: $0.id, name: $0.name,
                                                                 imagePath: $0.representativeImage, symbol: "person.fill", color: .blue)) }
        names += locations.map { ("#" + $0.name, ResolvedMention(kind: .location, id: $0.id, name: $0.name,
                                                                imagePath: $0.primaryImage ?? $0.images.first, symbol: "mappin.and.ellipse", color: .green)) }
        names += props.map { ("$" + $0.name, ResolvedMention(kind: .prop, id: $0.id, name: $0.name,
                                                            imagePath: $0.thumbnail ?? $0.referencePhotos.first, symbol: "shippingbox.fill", color: .orange)) }
        names += shots.map { ("&" + MentionNames.shot($0), ResolvedMention(kind: .shot, id: $0.id, name: MentionNames.shot($0),
                                                                          imagePath: $0.previewImage, symbol: "film.stack", color: .purple)) }
        names.sort { $0.0.count > $1.0.count }
        var taken: [Range<String.Index>] = []
        var found: [(Range<String.Index>, ResolvedMention)] = []
        for (token, mention) in names where token.count > 1 {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: token, options: .caseInsensitive, range: searchStart..<text.endIndex) {
                if !taken.contains(where: { $0.overlaps(range) }) {
                    taken.append(range)
                    found.append((range, mention))
                }
                searchStart = range.upperBound
            }
        }
        return found.sorted { $0.0.lowerBound < $1.0.lowerBound }.map { (range: $0.0, mention: $0.1) }
    }
}

struct MentionTextView: NSViewRepresentable {
    @Binding var text: String
    let characters: [Character]
    let locations: [Location]
    let props: [Prop]
    let continuityShots: [Shot]
    let projectDirectory: URL?
    var placeholder: String = "Write a description…"
    var onOpenMention: ((ResolvedMention) -> Void)?
    /// Return confirms instead of inserting a newline (short notes, e.g. a
    /// pin's instruction in the annotation editor).
    var submitsOnReturn: Bool = false
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MentionNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = Coordinator.font
        textView.textColor = NSColor.white.withAlphaComponent(0.9)
        textView.insertionPointColor = .white
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.textContainer?.lineFragmentPadding = 2
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.placeholderText = placeholder
        textView.onDoubleClickToken = { [weak coordinator = context.coordinator] token in
            coordinator?.open(token: token)
        }
        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        context.coordinator.textView = textView
        context.coordinator.render(text)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        textView.placeholderText = placeholder
        // Re-render only when the model moved under us (a reload, an
        // outside edit) — never while the user is typing.
        if context.coordinator.plainText(of: textView.attributedString()) != text {
            context.coordinator.render(text)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        static let font = NSFont.systemFont(ofSize: 14)
        var parent: MentionTextView
        weak var textView: MentionNSTextView?
        private var isRendering = false
        private var thumbnails: [String: NSImage] = [:]

        // Mention popup state (view-string offsets)
        private var popover: NSPopover?
        private var popupKind: MentionKind?
        private var triggerLocation: Int?
        private var query = ""
        private var selectedIndex = 0

        init(_ parent: MentionTextView) { self.parent = parent }

        // MARK: Model ↔ view

        /// Plain text with tokens from the view's attributed string.
        func plainText(of attributed: NSAttributedString) -> String {
            var out = ""
            attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
                if let token = attrs[.mentionToken] as? String {
                    out += token
                } else {
                    out += attributed.attributedSubstring(from: range).string
                }
            }
            return out
        }

        /// Draw `plain` into the view: text, with every token as a pill.
        func render(_ plain: String) {
            guard let textView else { return }
            isRendering = true
            defer { isRendering = false }
            let selection = textView.selectedRange()
            let result = NSMutableAttributedString()
            let base: [NSAttributedString.Key: Any] = [.font: Self.font,
                                                       .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
            let tokens = MentionTokenizer.tokens(in: plain, characters: parent.characters, locations: parent.locations,
                                                 props: parent.props, shots: parent.continuityShots)
            var cursor = plain.startIndex
            for token in tokens {
                if cursor < token.range.lowerBound {
                    result.append(NSAttributedString(string: String(plain[cursor..<token.range.lowerBound]), attributes: base))
                }
                result.append(pill(for: token.mention, token: String(plain[token.range])))
                cursor = token.range.upperBound
            }
            if cursor < plain.endIndex {
                result.append(NSAttributedString(string: String(plain[cursor...]), attributes: base))
            }
            textView.textStorage?.setAttributedString(result)
            let length = result.length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
            textView.needsDisplay = true
        }

        /// A pill: the thing's picture and name, as one attachment character.
        private func pill(for mention: ResolvedMention, token: String) -> NSAttributedString {
            let attachment = NSTextAttachment()
            let image = pillImage(for: mention)
            attachment.image = image
            attachment.bounds = NSRect(x: 0, y: -6, width: image.size.width, height: image.size.height)
            let piece = NSMutableAttributedString(attachment: attachment)
            piece.addAttributes([.mentionToken: token, .font: Self.font], range: NSRange(location: 0, length: piece.length))
            return piece
        }

        private func pillImage(for mention: ResolvedMention) -> NSImage {
            let height: CGFloat = 24
            let thumbSize: CGFloat = 20
            let nameFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
            let name = mention.name as NSString
            let nameWidth = ceil(name.size(withAttributes: [.font: nameFont]).width)
            let width = 6 + thumbSize + 6 + nameWidth + 8
            let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
                let tint = NSColor(mention.color)
                let background = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
                tint.withAlphaComponent(0.16).setFill(); background.fill()
                tint.withAlphaComponent(0.35).setStroke(); background.lineWidth = 1; background.stroke()
                let thumbRect = NSRect(x: 6, y: (height - thumbSize) / 2, width: thumbSize, height: thumbSize)
                let clip = mention.kind == .character
                    ? NSBezierPath(ovalIn: thumbRect)
                    : NSBezierPath(roundedRect: thumbRect, xRadius: 4, yRadius: 4)
                NSGraphicsContext.saveGraphicsState()
                clip.addClip()
                if let thumb = self.thumbnail(for: mention) {
                    thumb.draw(in: thumbRect, from: .zero, operation: .sourceOver, fraction: 1)
                } else {
                    tint.withAlphaComponent(0.35).setFill(); thumbRect.fill()
                    if let symbol = NSImage(systemSymbolName: mention.symbol, accessibilityDescription: nil) {
                        symbol.draw(in: thumbRect.insetBy(dx: 4, dy: 4), from: .zero, operation: .sourceOver, fraction: 0.9)
                    }
                }
                NSGraphicsContext.restoreGraphicsState()
                name.draw(at: NSPoint(x: 6 + thumbSize + 6, y: (height - nameFont.ascender + nameFont.descender) / 2 - 1),
                          withAttributes: [.font: nameFont, .foregroundColor: NSColor.white.withAlphaComponent(0.95)])
                return true
            }
            return image
        }

        /// The thing's picture, downscaled once and kept for this editor.
        private func thumbnail(for mention: ResolvedMention) -> NSImage? {
            guard let path = mention.imagePath, !path.isEmpty, let base = parent.projectDirectory else { return nil }
            if let cached = thumbnails[path] { return cached }
            guard let full = NSImage(contentsOf: base.appendingPathComponent(path)) else { return nil }
            let target: CGFloat = 40
            let scale = target / max(full.size.width, full.size.height, 1)
            let size = NSSize(width: max(1, full.size.width * scale), height: max(1, full.size.height * scale))
            let small = NSImage(size: size, flipped: false) { rect in
                full.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1); return true
            }
            thumbnails[path] = small
            return small
        }

        // MARK: Editing

        func textDidChange(_ notification: Notification) {
            guard !isRendering, let textView else { return }
            let plain = plainText(of: textView.attributedString())
            if plain != parent.text { parent.text = plain }
            trackMention(in: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isRendering, let textView, popover != nil, let trigger = triggerLocation else { return }
            // The caret left the query: close the list.
            let caret = textView.selectedRange().location
            if caret <= trigger || caret > trigger + 1 + query.count { closePopup() }
        }

        /// Open, refine or close the mention list from the text around the caret.
        private func trackMention(in textView: NSTextView) {
            let string = textView.string as NSString
            let caret = textView.selectedRange().location
            guard caret > 0 else { closePopup(); return }
            let last = string.substring(with: NSRange(location: caret - 1, length: 1))
            if popover == nil {
                guard let kind = MentionKind.kind(for: last.first) else { return }
                popupKind = kind
                triggerLocation = caret - 1
                query = ""
                selectedIndex = 0
                showPopup()
                return
            }
            guard let trigger = triggerLocation, let kind = popupKind,
                  trigger < string.length,
                  string.substring(with: NSRange(location: trigger, length: 1)).first == kind.trigger,
                  caret > trigger
            else { closePopup(); return }
            let typed = string.substring(with: NSRange(location: trigger + 1, length: caret - trigger - 1))
            if typed.contains("\n") { closePopup(); return }
            query = typed
            if candidates().isEmpty { closePopup() } else { selectedIndex = min(selectedIndex, max(candidates().count - 1, 0)); showPopup() }
        }

        private func candidates() -> [MentionCandidate] {
            guard let kind = popupKind else { return [] }
            let all: [MentionCandidate]
            switch kind {
            case .character:
                all = parent.characters.map { MentionCandidate(id: $0.id, name: $0.name, detail: $0.role,
                                                               color: Color(hex: $0.color.isEmpty ? "#666666" : $0.color), symbol: nil) }
            case .location:
                all = parent.locations.map { MentionCandidate(id: $0.id, name: $0.name, detail: $0.locationType.capitalized,
                                                              color: .green, symbol: "mappin.and.ellipse") }
            case .prop:
                all = parent.props.map { MentionCandidate(id: $0.id, name: $0.name, detail: $0.category,
                                                          color: .orange, symbol: "shippingbox.fill") }
            case .shot:
                all = parent.continuityShots.map { MentionCandidate(id: $0.id, name: MentionNames.shot($0),
                                                                    detail: String($0.description.prefix(40)),
                                                                    color: .purple, symbol: "film.stack") }
            }
            let filtered = query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return Array(filtered.prefix(6))
        }

        private func showPopup() {
            guard let textView, let kind = popupKind, let trigger = triggerLocation else { return }
            let list = MentionCandidateList(title: kind.title, candidates: candidates(), selectedIndex: selectedIndex) { [weak self] pick in
                self?.insert(pick)
            }
            if popover == nil {
                let popover = NSPopover()
                popover.behavior = .transient
                popover.animates = false
                popover.contentViewController = NSHostingController(rootView: list)
                self.popover = popover
            } else if let host = popover?.contentViewController as? NSHostingController<MentionCandidateList> {
                host.rootView = list
            }
            // Anchor under the trigger character.
            var rect = textView.firstRect(forCharacterRange: NSRange(location: trigger, length: 1), actualRange: nil)
            if let window = textView.window {
                rect = window.convertFromScreen(rect)
                rect = textView.convert(rect, from: nil)
            }
            if rect.isEmpty { rect = NSRect(x: 0, y: 0, width: 1, height: 20) }
            if popover?.isShown == false {
                popover?.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
                textView.window?.makeFirstResponder(textView)
            }
        }

        private func closePopup() {
            popover?.performClose(nil)
            popover = nil
            popupKind = nil
            triggerLocation = nil
            query = ""
            selectedIndex = 0
        }

        /// Replace "<trigger><query>" with the pill for the picked thing, then a space.
        private func insert(_ pick: MentionCandidate) {
            guard let textView, let kind = popupKind, let trigger = triggerLocation else { return }
            let mention = resolved(pick, kind: kind)
            let token = "\(kind.trigger)\(pick.name)"
            let replaceRange = NSRange(location: trigger, length: 1 + query.count)
            let piece = NSMutableAttributedString()
            piece.append(pill(for: mention, token: token))
            piece.append(NSAttributedString(string: " ", attributes: [.font: Self.font,
                                                                       .foregroundColor: NSColor.white.withAlphaComponent(0.9)]))
            if textView.shouldChangeText(in: replaceRange, replacementString: token + " ") {
                isRendering = true
                textView.textStorage?.replaceCharacters(in: replaceRange, with: piece)
                textView.didChangeText()
                isRendering = false
                textView.setSelectedRange(NSRange(location: trigger + piece.length, length: 0))
            }
            closePopup()
            parent.text = plainText(of: textView.attributedString())
        }

        private func resolved(_ pick: MentionCandidate, kind: MentionKind) -> ResolvedMention {
            switch kind {
            case .character:
                let c = parent.characters.first { $0.id == pick.id }
                return ResolvedMention(kind: .character, id: pick.id, name: pick.name, imagePath: c?.representativeImage,
                                       symbol: "person.fill", color: .blue)
            case .location:
                let l = parent.locations.first { $0.id == pick.id }
                return ResolvedMention(kind: .location, id: pick.id, name: pick.name, imagePath: l?.primaryImage ?? l?.images.first,
                                       symbol: "mappin.and.ellipse", color: .green)
            case .prop:
                let p = parent.props.first { $0.id == pick.id }
                return ResolvedMention(kind: .prop, id: pick.id, name: pick.name, imagePath: p?.thumbnail ?? p?.referencePhotos.first,
                                       symbol: "shippingbox.fill", color: .orange)
            case .shot:
                let s = parent.continuityShots.first { $0.id == pick.id }
                return ResolvedMention(kind: .shot, id: pick.id, name: pick.name, imagePath: s?.previewImage,
                                       symbol: "film.stack", color: .purple)
            }
        }

        // Keyboard while the list is up: arrows move, return picks, escape closes.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard popover != nil else {
                if parent.submitsOnReturn, commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    parent.onSubmit?()
                    return true
                }
                return false
            }
            let items = candidates()
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                selectedIndex = min(selectedIndex + 1, max(items.count - 1, 0)); showPopup(); return true
            case #selector(NSResponder.moveUp(_:)):
                selectedIndex = max(selectedIndex - 1, 0); showPopup(); return true
            case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
                if selectedIndex < items.count { insert(items[selectedIndex]) }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                closePopup(); return true
            default:
                return false
            }
        }

        // MARK: Opening a mention

        func open(token: String) {
            guard let mention = MentionTokenizer.tokens(in: token, characters: parent.characters, locations: parent.locations,
                                                        props: parent.props, shots: parent.continuityShots).first?.mention
            else { return }
            parent.onOpenMention?(mention)
        }
    }
}

/// NSTextView with a placeholder and double-click on a pill.
final class MentionNSTextView: NSTextView {
    var placeholderText: String = "" { didSet { needsDisplay = true } }
    var onDoubleClickToken: ((String) -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty, !placeholderText.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 14),
                                                        .foregroundColor: NSColor.gray.withAlphaComponent(0.4)]
            (placeholderText as NSString).draw(at: NSPoint(x: textContainerInset.width + 2, y: textContainerInset.height),
                                               withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            let index = characterIndexForInsertion(at: point)
            let candidates = [index, index - 1].filter { $0 >= 0 && $0 < attributedString().length }
            for i in candidates {
                if let token = attributedString().attribute(.mentionToken, at: i, effectiveRange: nil) as? String {
                    onDoubleClickToken?(token)
                    return
                }
            }
        }
        super.mouseDown(with: event)
    }
}

extension MentionKind {
    var title: String {
        switch self {
        case .character: return "Characters"
        case .location: return "Locations"
        case .prop: return "Props"
        case .shot: return "Continuity shots"
        }
    }
}

/// The list shown under the caret.
struct MentionCandidateList: View {
    let title: String
    let candidates: [MentionCandidate]
    let selectedIndex: Int
    let onPick: (MentionCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).textCase(.uppercase)
                Spacer()
                Text("↑↓ · return").font(.system(size: 9)).foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            Divider()
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                Button { onPick(candidate) } label: {
                    HStack(spacing: 8) {
                        if let symbol = candidate.symbol {
                            Image(systemName: symbol).font(.system(size: 10)).foregroundColor(candidate.color).frame(width: 12)
                        } else {
                            Circle().fill(candidate.color).frame(width: 12, height: 12)
                        }
                        Text(candidate.name).font(.system(size: 12)).foregroundColor(.primary)
                        if !candidate.detail.isEmpty {
                            Text("(\(candidate.detail))").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                if index < candidates.count - 1 { Divider() }
            }
        }
        .frame(width: 260)
    }
}
