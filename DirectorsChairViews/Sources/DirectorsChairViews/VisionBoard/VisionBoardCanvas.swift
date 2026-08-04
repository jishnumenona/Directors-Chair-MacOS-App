// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardCanvas.swift
//
// Vision Board Canvas - Infinite Freeform Canvas with Pan/Zoom
// Pinterest/Milanote-style canvas for mood board visualization.

import SwiftUI
import DirectorsChairCore

// MARK: - Vision Board Canvas

public struct VisionBoardCanvas: View {
    // MARK: - Properties

    @ObservedObject public var viewModel: VisionBoardViewModel

    /// Callback when a card is double-clicked for editing
    public var onCardEdit: ((VisionCard) -> Void)?
    /// Tapping an element's tag opens the scene or shot it belongs to.
    public var onOpenLink: ((VisionCardLinkRef) -> Void)?

    // MARK: - State

    @State private var viewSize: CGSize = .zero
    /// A drag is hovering over the wall (The Wall, pass 1).
    @State private var isDropTargeted = false
    /// Double-click-to-type: where the caret is, and what's being typed.
    @State private var typingAt: CGPoint?
    @State private var draftWords = ""
    @FocusState private var draftFocused: Bool
    /// The wall itself must hold focus or no key ever reaches it —
    /// .focusable() alone doesn't make a view first responder.
    @FocusState private var wallFocused: Bool
    /// The tool ring, and which tool is waiting on words.
    @State private var toolRingAt: CGPoint?
    @State private var awaitingTool: VisionWallTool?
    /// Non-nil when the ring belongs to a scrap rather than the wall.
    @State private var ringScrap: VisionCard?
    /// Non-nil when the right-click landed on a cord: the thread's own
    /// ring opens instead, and nothing else does.
    @State private var ringThread: VisionConnector?
    /// The scrap whose paper is being chosen, and where to show the stock.
    @State private var paperFor: VisionCard?
    /// The element whose note is being written at the caret.
    @State private var noteFor: VisionCard?
    /// The picture being marked up, and the words that made it.
    @State private var annotating: (card: VisionCard, image: NSImage)?
    @State private var promptFor: VisionCard?
    @State private var paperAt: CGPoint = .zero

    // MARK: - Constants

    private static let canvasSpaceName = "visionCanvas"

    // MARK: - Init

    public init(
        viewModel: VisionBoardViewModel,
        onCardEdit: ((VisionCard) -> Void)? = nil,
        onOpenLink: ((VisionCardLinkRef) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onCardEdit = onCardEdit
        self.onOpenLink = onOpenLink
    }

    // MARK: - Body
    //
    // Slice 1: one transform owner. The grid draws in SCREEN space on a
    // viewport-sized Canvas; the cards layer applies zoom+offset exactly
    // once. Card gestures are attached deeper in the hierarchy, so the
    // container's plain pan gesture yields to them — dragging a card no
    // longer pans the canvas.

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                canvasBackground

                cardsLayer
                    .frame(width: geometry.size.width,
                           height: geometry.size.height,
                           alignment: .topLeading)

                // TODO: rubber-band selection (tracked flaw, out of scope)
            }
            .clipped()
            .contentShape(Rectangle())
            .coordinateSpace(name: Self.canvasSpaceName)
            .background(
                TrackpadScrollCatcher(
                    onPan: { deltaX, deltaY in
                        viewModel.scrollPan(deltaX: deltaX, deltaY: deltaY)
                    },
                    onZoom: { deltaY, focus in
                        viewModel.scrollZoom(deltaY: deltaY, focus: focus)
                    },
                    onRightClick: { point in
                        viewModel.recordRightClick(atScreenPoint: point)
                        typingAt = nil
                        awaitingTool = nil
                        // What the click landed on decides the ring — a
                        // scrap gets its own tools, bare wall gets the
                        // making tools. Never both menus at once.
                        let world = viewModel.transform.toWorld(point)
                        // A cord is thin and usually crosses the very
                        // sheets it connects, so it is asked first — and
                        // when it answers, neither other ring opens.
                        ringThread = VisionWallHitTest.thread(
                            at: world,
                            connectors: viewModel.boardConnectors,
                            tack: { tackPoint($0) },
                            tolerance: 13 / max(viewModel.transform.zoom, 0.05))
                        ringScrap = ringThread == nil
                            ? VisionWallHitTest.scrap(at: world,
                                                      cards: viewModel.filteredCards)
                            : nil
                        toolRingAt = VisionRadialGeometry.anchor(
                            for: point, in: viewSize,
                            radius: ringThread != nil ? 116 : 78)
                    }
                )
            )
            .gesture(panGesture)
            .gesture(magnificationGesture)
            // Double-click bare wall and type — the words land where the
            // caret was. Registered before the single tap so it wins.
            .onTapGesture(count: 2,
                          coordinateSpace: .named(Self.canvasSpaceName)) { point in
                draftWords = ""
                typingAt = point
                draftFocused = true
            }
            .onTapGesture {
                if typingAt != nil { commitTypedWords() }
                // Clicking bare wall is how you put the connector tool
                // down — clicking a scrap is how you finish the link.
                if viewModel.pendingConnectorSource != nil {
                    viewModel.cancelConnector()
                }
                viewModel.clearSelection()
                wallFocused = true
            }
            // The Wall, pass 1: drop anything and it lands where you let
            // go of it — no dialog, no type picker, nothing asked.
            .onDrop(of: VisionBoardAbsorb.acceptedTypes,
                    isTargeted: $isDropTargeted) { providers, location in
                absorb(providers, atScreenPoint: location)
                return true
            }
            // ⌘V puts the clipboard on the wall at the centre of the view.
            .focusable()
            .focusEffectDisabled()
            .focused($wallFocused)
            .onPasteCommand(of: VisionBoardAbsorb.acceptedTypes) { providers in
                absorb(providers, atScreenPoint: nil)
            }
            // Hands on the wall: the board had no keyboard at all.
            .onKeyPress(.delete) { deleteSelection() }
            .onKeyPress(.deleteForward) { deleteSelection() }
            .onKeyPress(KeyEquivalent("a"), phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                viewModel.selectAllCards()
                return .handled
            }
            .onKeyPress(.escape) {
                // Escape backs out of whatever is open — a half-typed
                // word, the tool ring, the paper strip — and only clears
                // the selection when nothing else is in the way.
                if typingAt != nil || awaitingTool != nil || noteFor != nil {
                    typingAt = nil
                    awaitingTool = nil
                    noteFor = nil
                    draftWords = ""
                    wallFocused = true
                    return .handled
                }
                if toolRingAt != nil { dismissRing(); return .handled }
                if viewModel.pendingConnectorSource != nil {
                    viewModel.cancelConnector()
                    return .handled
                }
                if paperFor != nil { paperFor = nil; return .handled }
                viewModel.clearSelection()
                return .handled
            }
            .onKeyPress(.leftArrow) { nudge(dx: -1, dy: 0) }
            .onKeyPress(.rightArrow) { nudge(dx: 1, dy: 0) }
            .onKeyPress(.upArrow) { nudge(dx: 0, dy: -1) }
            .onKeyPress(.downArrow) { nudge(dx: 0, dy: 1) }
            .overlay {
                if let caret = typingAt {
                    TextField(awaitingTool?.prompt ?? "", text: $draftWords,
                              axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .frame(width: 280)
                        .padding(10)
                        .background(.thinMaterial,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .focused($draftFocused)
                        .position(caret)
                        .onSubmit { commitCaret(at: caret) }
                        .onExitCommand { typingAt = nil; draftWords = "" }
                }
            }
            .overlay { wallOverlays }
            .sheet(isPresented: Binding(
                get: { annotating != nil },
                set: { if !$0 { annotating = nil } })) {
                if let session = annotating {
                    ImageAnnotationEditor(
                        image: session.image,
                        title: "EDIT THIS PICTURE",
                        subtitle: "Drop a pin on what should change, and say how.",
                        isPresented: Binding(
                            get: { annotating != nil },
                            set: { if !$0 { annotating = nil } }),
                        onApplyEdits: { marks in
                            applyMarks(marks, to: session.card,
                                       image: session.image)
                        })
                }
            }
            .overlay { dropOverlay }
            .animation(.easeOut(duration: 0.12), value: isDropTargeted)
            .animation(.easeOut(duration: 0.22), value: viewModel.filteredCards.isEmpty)
            .onAppear {
                viewSize = geometry.size
                viewModel.viewportSize = geometry.size
                // Take focus so Delete, arrows and ⌘V work without the
                // user having to guess that the wall needs clicking first.
                DispatchQueue.main.async { wallFocused = true }
                // First appearance: fit the board's content.
                viewModel.fitToView(viewSize: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
                viewModel.viewportSize = newSize
            }
        }
        .background(LinearGradient(colors: VisionWallPalette.surface,
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }


    /// Everything drawn over the wall, in one place: the modifier chain
    /// defeats the type-checker once it grows past a handful.
    @ViewBuilder
    private var wallOverlays: some View {
        ZStack {
            hintOverlay
            ringOverlay
            generatingOverlay
            caretOverlay
            connectingOverlay
            paperOverlay
            promptOverlay
            problemOverlay
        }
    }

    // MARK: - Overlays
    //
    // Split out of `body`: inline, the modifier chain defeats the
    // type-checker.

    /// A bare wall says nothing on its own — this is the note already
    /// pinned to it, which comes down by itself once anything is up.
    @ViewBuilder
    private var hintOverlay: some View {
        if viewModel.filteredCards.isEmpty && !viewModel.isGenerating {
            VisionWallHint()
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    @ViewBuilder
    private var ringOverlay: some View {
        if let ring = toolRingAt, let cord = ringThread {
            // A cord gets its own tools. The wall's making tools have
            // nothing to say about a piece of string, and showing both
            // rings at once — which is what used to happen — says the
            // app doesn't know what you clicked.
            VisionThreadRing(
                anchor: ring,
                connector: viewModel.boardConnectors
                    .first { $0.id == cord.id } ?? cord,
                // Picking a colour is a finished choice, so the ring
                // closes on it — you see the cord change instead of
                // staring at the tools that changed it. Weight keeps the
                // ring open, because stepping through it is a dial.
                onPickThread: {
                    viewModel.setThread(cord.id, to: $0)
                    dismissRing()
                },
                onSetThickness: { viewModel.setThreadThickness(cord.id, to: $0) },
                onSetName: { viewModel.setConnectorLabel(cord.id, label: $0) },
                onCut: {
                    dismissRing()
                    viewModel.removeConnector(cord.id)
                },
                onDismiss: dismissRing)
        } else if let ring = toolRingAt {
            VisionRadialMenu(anchor: ring, items: ringItems,
                             onPick: { pickTool($0, at: ring) },
                             onDismiss: dismissRing)
        }
    }

    /// Nothing blocks the wall any more: a picture being imagined holds
    /// its own space (VisionPendingSheet) and a picture being redrawn says
    /// so on itself. This is only the quiet count when several are in
    /// flight at once and some are off-screen.
    @ViewBuilder
    private var generatingOverlay: some View {
        if viewModel.pendingImagines.count > 1 {
            VStack {
                Spacer()
                Text("Imagining \(viewModel.pendingImagines.count) pictures…")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VisionWallPalette.ink.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(VisionWallPalette.clipping, in: Capsule())
                    .shadow(color: VisionWallPalette.scrapShadow, radius: 5, y: 2)
                    .environment(\.colorScheme, .light)
                    .padding(.bottom, 18)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var caretOverlay: some View {
        if let caret = typingAt {
            TextField(noteFor != nil ? "Write a note…" : (awaitingTool?.prompt ?? ""),
                      text: $draftWords, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(width: 300)
                .padding(11)
                .background(VisionWallPalette.clipping,
                            in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: VisionWallPalette.scrapShadow, radius: 8, y: 3)
                .environment(\.colorScheme, .light)
                .focused($draftFocused)
                .position(caret)
                .onSubmit { commitCaret(at: caret) }
                .onExitCommand {
                    typingAt = nil
                    awaitingTool = nil
                    noteFor = nil
                    draftWords = ""
                    wallFocused = true
                }
        }
    }

    /// Connect arms a mode that waits for a second click. Without this it
    /// looked like the tool did nothing at all.
    @ViewBuilder
    private var connectingOverlay: some View {
        if viewModel.pendingConnectorSource != nil {
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                    Text("Click the element to connect it to")
                        .font(.system(size: 12, weight: .semibold))
                    Text("esc")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(VisionWallPalette.ink.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 3))
                }
                .foregroundStyle(VisionWallPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(VisionWallPalette.clipping,
                            in: Capsule())
                .shadow(color: VisionWallPalette.scrapShadow, radius: 7, y: 3)
                .environment(\.colorScheme, .light)
                .padding(.top, 64)
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// When something asked for doesn't happen, the wall says so rather
    /// than leaving you watching an element that never changes.
    @ViewBuilder
    private var problemOverlay: some View {
        if let problem = viewModel.lastWorkProblem {
            VStack {
                Spacer()
                Text(problem)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(VisionWallPalette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(VisionWallPalette.clipping, in: Capsule())
                    .overlay(Capsule().strokeBorder(
                        VisionWallPalette.greasePencil.opacity(0.5), lineWidth: 1))
                    .shadow(color: VisionWallPalette.scrapShadow, radius: 7, y: 3)
                    .environment(\.colorScheme, .light)
                    .padding(.bottom, 24)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
            .task(id: problem) {
                try? await Task.sleep(for: .seconds(4))
                viewModel.lastWorkProblem = nil
            }
        }
    }

    /// The words that made a picture, kept with it — read them, copy
    /// them, or use them as the starting point for another.
    @ViewBuilder
    private var promptOverlay: some View {
        if let element = promptFor {
            ZStack {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { promptFor = nil }

                VStack(alignment: .leading, spacing: 10) {
                    Text("The words that made this")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(VisionWallPalette.ink.opacity(0.55))
                    Text(element.description)
                        .font(.system(size: 12.5, design: .serif))
                        .foregroundStyle(VisionWallPalette.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(element.description,
                                                           forType: .string)
                        }
                        Button("Imagine another") {
                            promptFor = nil
                            awaitingTool = .imagine
                            draftWords = element.description
                            typingAt = viewModel.transform.toScreen(
                                CGPoint(x: (element.canvasX ?? 0)
                                            + (element.canvasWidth ?? 200) / 2,
                                        y: (element.canvasY ?? 0)
                                            + (element.canvasHeight ?? 200) + 40))
                            draftFocused = true
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .padding(16)
                .frame(width: 340, alignment: .leading)
                .background(VisionWallPalette.clipping,
                            in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: VisionWallPalette.scrapShadow, radius: 10, y: 4)
                .environment(\.colorScheme, .light)
                .position(paperAt)
            }
            .ignoresSafeArea()
            .onExitCommand { promptFor = nil }
        }
    }

    /// Marks become instructions, and the picture is redrawn from them
    /// with the current image as the reference.
    private func applyMarks(_ marks: [KeyframeAnnotation],
                            to card: VisionCard, image: NSImage) {
        annotating = nil
        let instructions = ImageAnnotationEditor.buildEditPrompt(
            from: marks, context: "image")
        guard !instructions.isEmpty else {
            viewModel.lastWorkProblem = "Add a mark and say what to change there."
            return
        }
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?
                  .representation(using: .png, properties: [:]) else {
            viewModel.lastWorkProblem = "This picture couldn't be read for redrawing."
            return
        }
        Task { @MainActor in
            await viewModel.redraw(card.id, instructions: instructions,
                                   baseImage: png)
        }
    }

    /// The stock this scrap could be cut from — real swatches, so you
    /// pick by eye rather than by name.
    @ViewBuilder
    private var paperOverlay: some View {
        if let scrap = paperFor {
            ZStack {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { paperFor = nil }

                VStack(spacing: 8) {
                    Text("Paper")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(VisionWallPalette.ink.opacity(0.55))
                    HStack(spacing: 7) {
                        ForEach(VisionPaper.allCases) { stock in
                            paperSwatch(stock, for: scrap)
                        }
                    }
                }
                .padding(12)
                .background(VisionWallPalette.clipping,
                            in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: VisionWallPalette.scrapShadow, radius: 10, y: 4)
                .environment(\.colorScheme, .light)
                .position(paperAt)
            }
            .ignoresSafeArea()
            .onExitCommand { paperFor = nil }
        }
    }

    private func paperSwatch(_ stock: VisionPaper, for scrap: VisionCard) -> some View {
        let chosen = VisionPaper.resolve(scrap.paper) == stock
        return VStack(spacing: 4) {
            ZStack {
                stock.base
                VisionPaperTexture(paper: stock)
                Text("Aa")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(stock.ink)
            }
            .frame(width: 40, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(chosen ? VisionWallPalette.greasePencil : .clear,
                                  lineWidth: 2)
            )
            .shadow(color: VisionWallPalette.scrapShadow, radius: 3, y: 1)

            Text(stock.displayName)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(VisionWallPalette.ink.opacity(0.6))
        }
        .onTapGesture {
            viewModel.setPaper(scrap.id, paper: stock)
            paperFor = nil
        }
        .accessibilityLabel(stock.displayName)
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(VisionWallPalette.greasePencil.opacity(0.5), lineWidth: 3)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Which ring

    /// The wall's ring makes things; a scrap's ring acts on the thing you
    /// clicked. One right-click, one menu — never both.
    private var ringItems: [VisionRingItem] {
        guard let scrap = ringScrap else {
            return VisionWallTool.ringOrder.map {
                VisionRingItem(id: $0.rawValue, title: $0.title,
                               systemImage: $0.systemImage)
            }
        }
        let isText = scrap.cardType == VisionCardType.text.rawValue
        let hasPicture = !(scrap.imagePath ?? "").isEmpty
        let isPaper = isText || scrap.cardType == VisionCardType.link.rawValue
        return VisionScrapTool.ring(isText: isText, hasPicture: hasPicture,
                                    isPaper: isPaper,
                                    hasPrompt: !scrap.description.isEmpty).map {
            VisionRingItem(id: $0.rawValue,
                           title: $0.title(pinned: scrap.pinned, isText: isText),
                           systemImage: $0.systemImage(pinned: scrap.pinned,
                                                       isText: isText),
                           destructive: $0 == .remove)
        }
    }

    private func dismissRing() {
        ringThread = nil
        toolRingAt = nil
        ringScrap = nil
    }

    private func pickTool(_ id: String, at point: CGPoint) {
        let scrap = ringScrap
        paperAt = point
        dismissRing()
        if let scrap, let tool = VisionScrapTool(rawValue: id) {
            reachFor(tool, on: scrap)
        } else if let tool = VisionWallTool(rawValue: id) {
            reachFor(tool, at: point)
        }
    }

    /// Tools that act on the scrap you right-clicked.
    private func reachFor(_ tool: VisionScrapTool, on scrap: VisionCard) {
        switch tool {
        case .connect:
            viewModel.beginConnector(from: scrap.id)
        case .duplicate:
            viewModel.selectCard(scrap.id)
            viewModel.duplicateSelectedCards()
        case .pin:
            viewModel.togglePin(scrap.id)
        case .restyle:
            if scrap.cardType == VisionCardType.text.rawValue {
                viewModel.cycleClippingCut(scrap.id)
            } else {
                viewModel.extractPalette(fromCardId: scrap.id)
            }
        case .paper:
            paperFor = scrap
        case .annotate:
            if let url = VisionBoardImagePath.resolveImageURL(
                scrap.imagePath, projectBase: viewModel.projectBase),
               let image = NSImage(contentsOf: url) {
                annotating = (scrap, image)
            }
        case .prompt:
            promptFor = scrap
        case .note:
            // The caret opens with whatever is already written there.
            noteFor = scrap
            draftWords = scrap.referenceNote ?? ""
            typingAt = viewModel.transform.toScreen(
                CGPoint(x: (scrap.canvasX ?? 0) + (scrap.canvasWidth ?? 200) / 2,
                        y: (scrap.canvasY ?? 0) + (scrap.canvasHeight ?? 200)))
            draftFocused = true
        case .details:
            onCardEdit?(scrap)
        case .remove:
            viewModel.removeCard(scrap.id)
        }
    }

    /// Menu paste: read the clipboard directly (the menu carries no
    /// providers) and drop it where the click was.
    private func pasteFromClipboard() {
        let payloads = VisionBoardAbsorb.payloads(from: .general)
        guard !payloads.isEmpty else { return }
        Task { @MainActor in
            await viewModel.absorb(payloads, at: nil)
        }
    }

    private func deleteSelection() -> KeyPress.Result {
        guard !viewModel.selectedCardIds.isEmpty, typingAt == nil else {
            return .ignored
        }
        viewModel.removeSelectedCards()
        return .handled
    }

    /// Arrow keys walk a scrap across the wall; Shift strides.
    private func nudge(dx: CGFloat, dy: CGFloat) -> KeyPress.Result {
        guard !viewModel.selectedCardIds.isEmpty, typingAt == nil else {
            return .ignored
        }
        let stride: CGFloat = NSEvent.modifierFlags.contains(.shift) ? 10 : 1
        viewModel.nudgeSelection(dx: dx * stride, dy: dy * stride)
        return .handled
    }

    /// A tool was picked off the ring. Some act at once; the ones that
    /// need words open a caret right where the ring was.
    private func reachFor(_ tool: VisionWallTool, at point: CGPoint) {
        switch tool {
        case .paste:
            pasteFromClipboard()
        case .picture:
            importPictureFromDisk(at: point)
        case .write, .imagine, .link, .video:
            awaitingTool = tool
            draftWords = ""
            typingAt = point
            draftFocused = true
        }
    }

    /// Whatever the caret was asking for, delivered.
    private func commitCaret(at caret: CGPoint) {
        let words = draftWords
        // A note commits to the element it belongs to — including an empty
        // one, which takes the slip back off.
        if let element = noteFor {
            noteFor = nil
            typingAt = nil
            draftWords = ""
            viewModel.setNote(element.id, text: words)
            wallFocused = true
            return
        }
        let tool = awaitingTool ?? .write
        let world = viewModel.transform.toWorld(caret)
        typingAt = nil
        awaitingTool = nil
        draftWords = ""
        guard !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        Task { @MainActor in
            switch tool {
            case .write:
                await viewModel.absorb([.text(words)], at: world)
            case .imagine:
                await viewModel.imagine(words, at: world)
            case .link, .video:
                await viewModel.pinLink(words, at: world)
            case .paste, .picture:
                break
            }
        }
    }

    /// A picture off the disk — the one place a file panel still belongs.
    private func importPictureFromDisk(at point: CGPoint) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Pin to the wall"
        guard panel.runModal() == .OK else { return }
        let payloads = panel.urls.compactMap(VisionBoardAbsorb.payload(forFile:))
        let world = viewModel.transform.toWorld(point)
        Task { @MainActor in
            await viewModel.absorb(payloads, at: world)
        }
    }

    /// Commits whatever was typed on the bare wall as a word scrap, at the
    /// caret. Empty input just closes the caret — typing nothing costs
    /// nothing.
    private func commitTypedWords() {
        guard let caret = typingAt else { return }
        let words = draftWords
        typingAt = nil
        draftWords = ""
        guard !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        let world = viewModel.transform.toWorld(caret)
        Task { @MainActor in
            await viewModel.absorb([.text(words)], at: world)
        }
    }

    /// Reads dropped/pasted providers and hands the payloads to the board.
    /// `screenPoint` is nil for a paste (no cursor to land under), which
    /// the view model resolves to the centre of the view.
    private func absorb(_ providers: [NSItemProvider], atScreenPoint screenPoint: CGPoint?) {
        let world = screenPoint.map { viewModel.transform.toWorld($0) }
        Task { @MainActor in
            var payloads: [AbsorbPayload] = []
            for provider in providers {
                if let payload = await VisionBoardAbsorb.payload(from: provider) {
                    payloads.append(payload)
                }
            }
            // A scene or shot dragged from the outline is a LINK, never
            // words. Handled here rather than on a drop target per
            // element: nested targets meant the wall answered first and
            // pinned up a clipping of the raw dcref:// text.
            if let world, let ref = linkRef(in: payloads) {
                if let target = VisionWallHitTest.scrap(
                    at: world, cards: viewModel.filteredCards) {
                    viewModel.link(target.id, to: ref)
                } else {
                    viewModel.lastWorkProblem =
                        "Drop \(ref.label) onto an element to connect them."
                }
                return
            }
            await viewModel.absorb(payloads, at: world)
        }
    }

    /// The first payload that is really a scene or a shot rather than text.
    private func linkRef(in payloads: [AbsorbPayload]) -> VisionCardLinkRef? {
        for payload in payloads {
            // The same drag can arrive classified as words OR as a URL,
            // depending on what the pasteboard decided it was.
            if case .text(let text) = payload,
               let ref = VisionCardLinkRef.parse(text) {
                return ref
            }
            if case .remoteURL(let url) = payload,
               let ref = VisionCardLinkRef.parse(url.absoluteString) {
                return ref
            }
        }
        return nil
    }

    /// Where an element's tack sits in the world. Thread is wound around
    /// pins, not tied to the middle of a sheet — and because the tack is
    /// the pivot the paper turns about, this point holds still however far
    /// the element swings.
    private func tackPoint(_ cardId: String) -> CGPoint? {
        guard let card = viewModel.cards.first(where: { $0.id == cardId }) else {
            return nil
        }
        let anchor = VisionScrapPhysics.tackAnchor(seed: card.id)
        return CGPoint(
            x: (card.canvasX ?? 0) + (card.canvasWidth ?? 200) * anchor.x,
            y: (card.canvasY ?? 0) + (card.canvasHeight ?? 200) * anchor.y)
    }

    // MARK: - Canvas Background with Dot Grid

    @ViewBuilder
    /// The wall itself — a surface that goes on forever
    /// (VisionWallSurface: grain that scrolls with the pan, marks
    /// generated per world cell, light that stays with the viewer).
    /// Observes the camera by itself so a pan repaints the plaster
    /// without re-evaluating the rest of the canvas.
    private var canvasBackground: some View {
        WallSurfaceLayer(camera: viewModel.camera)
            .ignoresSafeArea()
    }

    // MARK: - Cards Layer

    @ViewBuilder
    private var cardsLayer: some View {
        // This body must never READ the camera: reading it would put the
        // whole ForEach back on the 120Hz invalidation path that made the
        // wall stutter. The wrapper below observes it alone, applies the
        // transform, and feeds zoom to the few screen-constant adornments
        // through the environment.
        WallCameraApplied(camera: viewModel.camera) {
            ZStack(alignment: .topLeading) {
                ForEach(viewModel.filteredCards) { card in
                    scrapView(card).equatable()
                }

                // Space held while a picture is imagined — on the wall,
                // in the world, never over the top of your work.
                ForEach(viewModel.pendingImagines) { pending in
                    VisionPendingSheet(pending: pending)
                        .position(x: pending.origin.x + pending.size.width / 2,
                                  y: pending.origin.y + pending.size.height / 2)
                }

                // Thread lies ON the wall over the paper — string wound
                // round a pin sits on top of the sheet, it doesn't run
                // beneath it. The layer observes the camera itself (cord
                // weight is zoom-boosted) — a handful of cords, not the
                // whole wall.
                WallCordsLayer(
                    camera: viewModel.camera,
                    strands: viewModel.boardConnectors.compactMap { connector in
                        guard let from = tackPoint(connector.fromCardId),
                              let to = tackPoint(connector.toCardId)
                        else { return nil }
                        return WallCordsLayer.Strand(connector: connector,
                                                     from: from, to: to)
                    },
                    onEditLabel: { connector, from, to in
                        ringThread = connector
                        toolRingAt = VisionRadialGeometry.anchor(
                            for: viewModel.transform.toScreen(
                                VisionWallHitTest.cordMidpoint(from: from,
                                                               to: to)),
                            in: viewSize, radius: 116)
                    },
                    onDelete: { viewModel.removeConnector($0.id) })
            }
        }
    }

    /// One scrap on the wall, wrapped so SwiftUI can SKIP it.
    ///
    /// The twenty closures below defeat structural diffing — closures
    /// are never equal, so before this wrapper every publish re-rendered
    /// every element on the wall: 28ms per tick on a 150-element board,
    /// for a selection change. WallScrap's == compares only what draws
    /// (the card and its flags), so an untouched element is skipped
    /// wholesale, shadows and all.
    private func scrapView(_ card: VisionCard) -> WallScrap<some View> {
        WallScrap(
            card: card,
            isSelected: viewModel.selectedCardIds.contains(card.id),
            isConnectTarget: viewModel.pendingConnectorSource != nil
                && viewModel.pendingConnectorSource != card.id,
            isWorking: viewModel.isWorking(card.id),
            showLabel: viewModel.showLabels,
            item: { buildItem(for: $0) })
    }

    /// The fully-wired element — built only when its WallScrap decides
    /// something visible changed.
    @ViewBuilder
    private func buildItem(for card: VisionCard) -> some View {
            VisionCardItem(
                card: card,
                isSelected: viewModel.selectedCardIds.contains(card.id),
                // The badge is only ever as good as this line: the element
                // has always been able to show it, and for three reports
                // running nobody passed it.
                isRedrawing: viewModel.isWorking(card.id),
                onOpenLink: {
                    if let ref = card.linkedRef { onOpenLink?(ref) }
                },
                showLabel: viewModel.showLabels,
                canvasSpaceName: Self.canvasSpaceName,
                projectBase: viewModel.projectBase,
                onSelect: { addToSelection in
                    if viewModel.pendingConnectorSource != nil {
                        viewModel.completeConnector(to: card.id)
                    } else if addToSelection {
                        viewModel.toggleCardSelection(card.id)
                    } else {
                        viewModel.selectCard(card.id)
                    }
                },
                onDoubleClick: {
                    onCardEdit?(card)
                },
                onCommitText: { words in
                    viewModel.rewriteClipping(card.id, words: words)
                },
                onCycleCut: {
                    viewModel.cycleClippingCut(card.id)
                },
                onDuplicate: {
                    viewModel.selectCard(card.id)
                    viewModel.duplicateSelectedCards()
                },
                onDelete: {
                    viewModel.removeCard(card.id)
                },
                onExtractPalette: {
                    viewModel.extractPalette(fromCardId: card.id)
                },
                onBeginConnector: {
                    viewModel.beginConnector(from: card.id)
                },
                onDragBegan: {
                    viewModel.beginCardDrag(anchor: card.id)
                },
                onDragChanged: { translation in
                    viewModel.updateCardDrag(translation: translation)
                },
                onDragEnded: { translation in
                    viewModel.endCardDrag(translation: translation)
                },
                onResizeBegan: { corner in
                    viewModel.beginResize(cardId: card.id, corner: corner)
                },
                onResizeChanged: { translation in
                    viewModel.updateResize(translation: translation)
                },
                onResizeEnded: { translation in
                    viewModel.endResize(translation: translation)
                }
            )
    }

    // MARK: - Gestures (moved marker)


    // MARK: - Gestures

    /// Plain gesture (not simultaneous): card-attached gestures are deeper
    /// in the hierarchy and win — dragging a card never pans the canvas.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                viewModel.beginPanIfNeeded()
                viewModel.updatePan(translation: value.translation)
            }
            .onEnded { _ in
                viewModel.endPan()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                viewModel.pinchZoom(magnification: value.magnification,
                                    focus: value.startLocation)
            }
            .onEnded { _ in
                viewModel.endPinch()
            }
    }
}

// MARK: - Connector Arrow (roadmap #5)

/// A labeled dashed arrow between two world-space points. The label pill
/// at the midpoint is the interaction target (edit label / delete).
/// Thread strung between two pins, wound at each end.
///
/// It began as a dashed white arrow between element centres — invisible on
/// plaster, and tied to the wrong place. Real string is thick enough to
/// see across a room, hangs under its own weight, is twisted from strands,
/// and is wound around the tacks rather than the paper.
// MARK: - The camera's own views
//
// Pan and zoom arrive at up to 120Hz. Everything in this section exists
// so that those ticks touch ONLY: the plaster (which must scroll), the
// transform modifiers (which Core Animation applies to cached layer
// content), the cords (whose weight is zoom-boosted), and the few
// screen-constant adornments (fed through \.wallZoom). The elements
// themselves — shadows, textures, torn edges — are not re-rendered by
// moving the viewer.

private struct WallZoomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    /// The camera's zoom, for adornments that keep a constant screen
    /// size (working badge, link tag, rotate handle). Reading this — and
    /// only this — is what re-lays them out during a pinch.
    var wallZoom: CGFloat {
        get { self[WallZoomKey.self] }
        set { self[WallZoomKey.self] = newValue }
    }
}

/// The one view that puts the camera's transform on the world.
struct WallCameraApplied<Content: View>: View {
    @ObservedObject var camera: VisionWallCamera
    @ViewBuilder let content: Content

    var body: some View {
        content
            .scaleEffect(camera.transform.zoom, anchor: .topLeading)
            .offset(x: camera.transform.offset.x,
                    y: camera.transform.offset.y)
            .environment(\.wallZoom, camera.transform.zoom)
    }
}

/// The plaster follows the camera by itself.
struct WallSurfaceLayer: View {
    @ObservedObject var camera: VisionWallCamera
    var body: some View {
        #if DEBUG
        RenderProbe.surface()
        #endif
        return VisionWallSurface(transform: camera.transform)
    }
}

/// Temporary diagnostics — how many bodies run per publish.
public enum RenderProbe {
    nonisolated(unsafe) public static var onItem: (() -> Void)?
    nonisolated(unsafe) public static var onCord: (() -> Void)?
    nonisolated(unsafe) public static var onSurface: (() -> Void)?
    public static func item() { onItem?() }
    public static func cord() { onCord?() }
    public static func surface() { onSurface?() }
}

/// Every cord on the wall. Endpoints arrive as data (they move when
/// cards move, which the canvas body already re-evaluates for); the
/// camera is observed here for the zoom-boosted weight.
struct WallCordsLayer: View {
    struct Strand: Identifiable {
        let connector: VisionConnector
        let from: CGPoint
        let to: CGPoint
        var id: String { connector.id }
    }

    @ObservedObject var camera: VisionWallCamera
    let strands: [Strand]
    let onEditLabel: (VisionConnector, CGPoint, CGPoint) -> Void
    let onDelete: (VisionConnector) -> Void

    var body: some View {
        #if DEBUG
        RenderProbe.cord()
        #endif
        // drawn() folds zoom into the weight, so during a pan (offset
        // only) every strand's inputs are unchanged and its == skips the
        // eight stroked paths; a zoom re-strokes them, which is real work
        // the boost genuinely requires.
        return ForEach(strands) { strand in
            WallCordStrand(
                connector: strand.connector,
                from: strand.from, to: strand.to,
                thickness: VisionCordStrokes.drawn(
                    strand.connector.thickness ?? 5,
                    zoom: camera.transform.zoom),
                onEditLabel: {
                    onEditLabel(strand.connector, strand.from, strand.to)
                },
                onDelete: { onDelete(strand.connector) })
            .equatable()
        }
    }
}

/// One cord, skippable. Equality is over the drawn inputs; the closures
/// are excluded for the same reason as WallScrap's.
struct WallCordStrand: View, Equatable {
    let connector: VisionConnector
    let from: CGPoint
    let to: CGPoint
    let thickness: CGFloat
    let onEditLabel: () -> Void
    let onDelete: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.connector == rhs.connector
            && lhs.from == rhs.from && lhs.to == rhs.to
            && lhs.thickness == rhs.thickness
    }

    var body: some View {
        ConnectorArrow(
            from: from, to: to, label: connector.label,
            onEditLabel: onEditLabel,
            onDelete: onDelete,
            thickness: thickness,
            thread: VisionThread.resolve(connector.thread))
    }
}

/// One element plus everything SwiftUI needs to decide whether to skip
/// re-rendering it. Equality is over what DRAWS; the `item` closure is
/// deliberately excluded — it is never equal, and including it is what
/// used to force every element to re-render on every publish.
struct WallScrap<Item: View>: View, Equatable {
    let card: VisionCard
    let isSelected: Bool
    let isConnectTarget: Bool
    let isWorking: Bool
    let showLabel: Bool
    let item: (VisionCard) -> Item

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.card == rhs.card
            && lhs.isSelected == rhs.isSelected
            && lhs.isConnectTarget == rhs.isConnectTarget
            && lhs.isWorking == rhs.isWorking
            && lhs.showLabel == rhs.showLabel
    }

    var body: some View {
        item(card)
    }
}

/// How a cord LOOKS, in one place. The arrow on the wall and the swatch
/// in the picker both draw through this — a picker that drew its own
/// approximation of twine would be a third renderer of the same thing,
/// which is the drift that has already cost this board its pins and its
/// thread in export once.
struct VisionCordStrokes: View {
    let cord: Path
    let thickness: CGFloat
    let thread: VisionThread

    /// How thick to DRAW a cord of a given weight at a given zoom.
    ///
    /// Cords live in world points, so standing back from the wall shrinks
    /// them with everything else — and past a point every weight collapses
    /// into the same hairline, which is what the owner saw: rope and twine
    /// drawn identically because both were under a pixel.
    ///
    /// So the whole set is scaled up together once the thinnest would stop
    /// reading, which keeps every weight visible AND keeps the ratios
    /// between them intact. Zoomed in, where they are already legible,
    /// nothing is touched and a cord scales like the physical thing it is.
    static func drawn(_ stored: Double, zoom: CGFloat) -> CGFloat {
        let thinnest = VisionThreadRing.weights.first ?? 2.5
        let readable: CGFloat = 2.4        // screen points
        let boost = max(1, readable / (CGFloat(thinnest) * max(zoom, 0.02)))
        return CGFloat(stored) * boost
    }

    var body: some View {
        let t = thickness
        ZStack(alignment: .topLeading) {
            // Cast on the wall, offset the way the light falls. Two
            // nested strokes fake the soft edge a .blur used to give —
            // every blur is an offscreen render pass PER CORD, and they
            // were a measurable share of the zoom cost.
            cord
                .stroke(Color.black.opacity(thread.castOpacity * 0.45),
                        style: StrokeStyle(lineWidth: t * 1.9, lineCap: .round))
                .offset(x: 1.5, y: 3.5)
            cord
                .stroke(Color.black.opacity(thread.castOpacity * 0.6),
                        style: StrokeStyle(lineWidth: t * 1.15, lineCap: .round))
                .offset(x: 1.5, y: 3.5)

            // The dyed fibre.
            cord.stroke(thread.cord,
                        style: StrokeStyle(lineWidth: t, lineCap: .round))

            // Shaded underside and lit top edge give it a round body.
            // Sub-point blurs on these thin strokes were invisible at
            // any zoom; the strokes alone read the same.
            cord
                .stroke(Color.black.opacity(0.30),
                        style: StrokeStyle(lineWidth: t * 0.38, lineCap: .round))
                .offset(y: t * 0.28)
            cord
                .stroke(thread.lit.opacity(0.75),
                        style: StrokeStyle(lineWidth: t * 0.3, lineCap: .round))
                .offset(y: -t * 0.28)

            // Twist: short dashes running along the cord read as strands
            // wound together, at a fraction of the cost of drawing fibres.
            cord
                .stroke(thread.twistShade.opacity(0.55),
                        style: StrokeStyle(lineWidth: t * 0.72, lineCap: .butt,
                                           dash: [1.6, 4.4]))
            cord
                .stroke(thread.twistLight.opacity(0.45),
                        style: StrokeStyle(lineWidth: t * 0.5, lineCap: .butt,
                                           dash: [1.4, 4.6], dashPhase: 2.6))
                .offset(y: -t * 0.18)
        }
    }
}

struct ConnectorArrow: View {
    let from: CGPoint
    let to: CGPoint
    let label: String
    var onEditLabel: () -> Void
    var onDelete: () -> Void

    /// Twine, in world points — thick enough to read as cord, not a
    /// hairline. Exports of a large board scale everything down, so the
    /// exporter passes a bigger value to keep the cord legible.
    var thickness: CGFloat = 5.0

    /// Which twine this cord is strung with.
    var thread: VisionThread = .crimson

    /// Longer runs hang lower, the way string does under its own weight.
    private var sag: CGFloat {
        min(58, hypot(to.x - from.x, to.y - from.y) * 0.15)
    }

    var body: some View {
        let pad: CGFloat = 80
        let minX = min(from.x, to.x) - pad
        let minY = min(from.y, to.y) - pad
        let width = abs(from.x - to.x) + pad * 2
        let height = abs(from.y - to.y) + pad * 2
        let a = CGPoint(x: from.x - minX, y: from.y - minY)
        let b = CGPoint(x: to.x - minX, y: to.y - minY)
        let control = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + sag * 2)
        // The hanging point of a quadratic curve, where the tag rides.
        let mid = CGPoint(x: (a.x + 2 * control.x + b.x) / 4,
                          y: (a.y + 2 * control.y + b.y) / 4)

        let cord = Path { path in
            path.move(to: a)
            path.addQuadCurve(to: b, control: control)
        }
        let t = thickness

        ZStack(alignment: .topLeading) {
            VisionCordStrokes(cord: cord, thickness: t, thread: thread)

            // The whole length of cord is a target, not just the tag —
            // an invisible fat stroke over it takes the right-click.
            cord
                .stroke(Color.white.opacity(0.001),
                        style: StrokeStyle(lineWidth: max(16, t * 3.4),
                                           lineCap: .round))
                .contentShape(
                    cord.strokedPath(StrokeStyle(lineWidth: max(16, t * 3.4),
                                                   lineCap: .round)))
                .onTapGesture(count: 2, perform: onEditLabel)
                .help("Double-click to name it · right-click for thread and weight")

            knot.position(a)
            knot.position(b)

            tag
                .position(mid)
                .onTapGesture(count: 2, perform: onEditLabel)
        }
        .frame(width: width, height: height)
        .position(x: minX + width / 2, y: minY + height / 2)
    }

    /// Where the cord is wound round the pin: a couple of turns, sitting
    /// under the tack head that is drawn on the element itself.
    private var knot: some View {
        // The turns round the pin are the same cord, so they grow with
        // it — but only so far. Boosted rope at a distance would wind a
        // knot wider than the elements it ties together.
        let wind = min(thickness, 9)
        return ZStack {
            // Sized to sit UNDER the tack head, so the cord reads as
            // wound round the pin's shaft rather than covering the pin.
            Circle()
                .strokeBorder(thread.twistShade,
                              lineWidth: wind * 0.8)
                .frame(width: wind * 2.3, height: wind * 2.3)
            Circle()
                .strokeBorder(thread.twistLight.opacity(0.45),
                              lineWidth: wind * 0.26)
                .frame(width: wind * 2.7, height: wind * 2.7)
        }
        .shadow(color: Color.black.opacity(0.25), radius: 1.5, y: 1.5)
    }

    /// A luggage tag of paper knotted onto the thread.
    private var tag: some View {
        HStack(spacing: 3) {
            if label.isEmpty {
                Image(systemName: "pencil")
                    .font(.system(size: 8, weight: .bold))
            } else {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundColor(VisionWallPalette.ink.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(VisionPaper.cream.base)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8)
        )
        .shadow(color: VisionWallPalette.scrapShadow, radius: 2.5, y: 1.5)
        .rotationEffect(.degrees(-1.5))
    }
}

// MARK: - Trackpad Scroll Capture

/// SwiftUI has no scroll-wheel gesture on macOS, so this transparent
/// background view installs a local NSEvent monitor and forwards
/// two-finger scroll deltas that land over the canvas: plain scroll pans,
/// ⌘-scroll zooms about the cursor. Events over scrollable content (a
/// text card's inner ScrollView) pass through untouched so the canvas
/// never fights a card's own scrolling.
private struct TrackpadScrollCatcher: NSViewRepresentable {
    let onPan: (CGFloat, CGFloat) -> Void
    let onZoom: (CGFloat, CGPoint) -> Void
    var onRightClick: ((CGPoint) -> Void)?

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onPan = onPan
        view.onZoom = onZoom
        view.onRightClick = onRightClick
        view.installMonitor()
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onPan = onPan
        view.onZoom = onZoom
        view.onRightClick = onRightClick
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        view.removeMonitor()
    }

    final class CatcherView: NSView {
        var onPan: ((CGFloat, CGFloat) -> Void)?
        var onZoom: ((CGFloat, CGPoint) -> Void)?
        var onRightClick: ((CGPoint) -> Void)?
        private var monitor: Any?

        // Flipped so converted points share SwiftUI's top-left origin —
        // the same space the zoom focus math expects.
        override var isFlipped: Bool { true }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.scrollWheel, .rightMouseDown]) {
                [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit {
            removeMonitor()
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window else { return event }
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.contains(point) else { return event }

            // Right-click: record where, pass through — SwiftUI's
            // contextMenu still presents; the recorded point places the
            // added card under the cursor.
            if event.type == .rightMouseDown {
                onRightClick?(point)
                return event
            }

            guard !isOverScrollableContent(event) else { return event }

            // Physical mouse wheels deliver line-based deltas; scale them
            // to feel like points.
            let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
            if event.modifierFlags.contains(.command) {
                onZoom?(event.scrollingDeltaY * scale, point)
            } else {
                onPan?(event.scrollingDeltaX * scale,
                       event.scrollingDeltaY * scale)
            }
            return event
        }

        /// True when the event lands on content that scrolls by itself
        /// (SwiftUI ScrollViews are NSScrollView-backed).
        private func isOverScrollableContent(_ event: NSEvent) -> Bool {
            guard let contentView = window?.contentView else { return false }
            var view = contentView.hitTest(
                contentView.convert(event.locationInWindow, from: nil))
            while let current = view {
                if current is NSScrollView { return true }
                view = current.superview
            }
            return false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VisionBoardCanvas_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = VisionBoardViewModel(cards: [
            VisionCard(
                id: "1",
                title: "Hero Shot",
                cardType: "image",
                canvasX: 100,
                canvasY: 100,
                canvasWidth: 200,
                canvasHeight: 200
            ),
            VisionCard(
                id: "2",
                title: "Color Palette",
                cardType: "color_palette",
                colorPalette: ["#FF5733", "#33FF57", "#3357FF", "#F3FF33"],
                canvasX: 350,
                canvasY: 100,
                canvasWidth: 180,
                canvasHeight: 150
            ),
            VisionCard(
                id: "3",
                title: "Notes",
                text: "Key visual themes:\n- Dark and moody\n- High contrast\n- Neon accents",
                cardType: "text",
                canvasX: 100,
                canvasY: 350,
                canvasWidth: 250,
                canvasHeight: 150
            )
        ])

        VisionBoardCanvas(viewModel: viewModel)
            .frame(width: 800, height: 600)
    }
}
#endif
