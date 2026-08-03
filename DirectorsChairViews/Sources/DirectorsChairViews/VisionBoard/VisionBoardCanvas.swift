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

    // MARK: - State

    @State private var viewSize: CGSize = .zero
    /// A drag is hovering over the wall (The Wall, pass 1).
    @State private var isDropTargeted = false
    /// Double-click-to-type: where the caret is, and what's being typed.
    @State private var typingAt: CGPoint?
    @State private var draftWords = ""
    @FocusState private var draftFocused: Bool

    // MARK: - Constants

    private static let canvasSpaceName = "visionCanvas"

    // MARK: - Init

    public init(
        viewModel: VisionBoardViewModel,
        onCardEdit: ((VisionCard) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onCardEdit = onCardEdit
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
                viewModel.clearSelection()
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
            .onPasteCommand(of: VisionBoardAbsorb.acceptedTypes) { providers in
                absorb(providers, atScreenPoint: nil)
            }
            .overlay {
                if let caret = typingAt {
                    TextField("", text: $draftWords, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .frame(width: 280)
                        .padding(10)
                        .background(.thinMaterial,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .focused($draftFocused)
                        .position(caret)
                        .onSubmit { commitTypedWords() }
                        .onExitCommand { typingAt = nil; draftWords = "" }
                }
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 3)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.12), value: isDropTargeted)
            .contextMenu {
                Section("Add to board") {
                    ForEach(VisionCardType.allCases) { type in
                        if type == .text {
                            // Presets discoverable at creation time
                            // (research 2026-07).
                            Menu {
                                ForEach(VisionTextStyle.allCases) { style in
                                    Button(style.displayName) {
                                        viewModel.createNewCard(
                                            type: .text,
                                            at: viewModel.consumeRightClickPoint(),
                                            textStyle: style.rawValue)
                                    }
                                }
                            } label: {
                                Label(type.displayName,
                                      systemImage: type.systemImage)
                            }
                        } else {
                            Button {
                                viewModel.createNewCard(
                                    type: type,
                                    at: viewModel.consumeRightClickPoint())
                            } label: {
                                Label(type.displayName,
                                      systemImage: type.systemImage)
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewSize = geometry.size
                viewModel.viewportSize = geometry.size
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
            await viewModel.absorb(payloads, at: world)
        }
    }

    private func cardCenter(_ cardId: String) -> CGPoint? {
        guard let card = viewModel.cards.first(where: { $0.id == cardId }) else {
            return nil
        }
        return CGPoint(x: (card.canvasX ?? 0) + (card.canvasWidth ?? 200) / 2,
                       y: (card.canvasY ?? 0) + (card.canvasHeight ?? 200) / 2)
    }

    // MARK: - Canvas Background with Dot Grid

    @ViewBuilder
    /// The wall (The Wall, pass 2). A dot grid and a world-origin crosshair
    /// told the user this was a CAD canvas; a vision board is a surface you
    /// pin things to. Warm plaster, a faint grain so the light isn't flat,
    /// and a soft vignette that keeps the eye in the middle — no rulers, no
    /// origin, nothing to align to.
    private var canvasBackground: some View {
        ZStack {
            LinearGradient(colors: VisionWallPalette.surface,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(nsImage: Self.grain)
                .resizable(resizingMode: .tile)
                .opacity(0.17)
                .blendMode(.multiply)
                .allowsHitTesting(false)
            RadialGradient(colors: [.clear, Color(hex: "#4A3B26").opacity(0.18)],
                           center: .center, startRadius: 240, endRadius: 900)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    /// One tileable grain swatch, generated once. Deterministic (a fixed
    /// FNV walk, never `random`) so the wall looks identical every launch.
    private static let grain: NSImage = {
        let side = 96
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        var hash: UInt64 = 1469598103934665603
        for y in 0..<side {
            for x in 0..<side {
                hash = (hash ^ UInt64(truncatingIfNeeded: x &* 31 &+ y)) &* 1099511628211
                guard hash % 7 == 0 else { continue }
                let alpha = Double((hash >> 8) % 40) / 400.0
                NSColor(white: 0.35, alpha: alpha).setFill()
                NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1).fill()
            }
        }
        image.unlockFocus()
        return image
    }()

    // MARK: - Cards Layer

    @ViewBuilder
    private var cardsLayer: some View {
        ZStack(alignment: .topLeading) {
            // Arrows render under cards; endpoints are card centers, so
            // the cards themselves occlude the line ends naturally.
            ForEach(viewModel.boardConnectors) { connector in
                if let from = cardCenter(connector.fromCardId),
                   let to = cardCenter(connector.toCardId) {
                    ConnectorArrow(
                        from: from, to: to, label: connector.label,
                        onEditLabel: {
                            viewModel.editingConnectorId = connector.id
                        },
                        onDelete: {
                            viewModel.removeConnector(connector.id)
                        })
                }
            }

            ForEach(viewModel.filteredCards) { card in
                scrapView(card)
            }
        }
        // The ONE place zoom and offset touch the render tree.
        .scaleEffect(viewModel.transform.zoom, anchor: .topLeading)
        .offset(x: viewModel.transform.offset.x, y: viewModel.transform.offset.y)
    }

    /// One scrap on the wall. Split out of `cardsLayer` because the
    /// closure list defeats the type-checker when inlined.
    @ViewBuilder
    private func scrapView(_ card: VisionCard) -> some View {
            VisionCardItem(
                card: card,
                isSelected: viewModel.selectedCardIds.contains(card.id),
                zoomLevel: viewModel.zoomLevel,
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
private struct ConnectorArrow: View {
    let from: CGPoint
    let to: CGPoint
    let label: String
    var onEditLabel: () -> Void
    var onDelete: () -> Void

    var body: some View {
        let minX = min(from.x, to.x) - 24
        let minY = min(from.y, to.y) - 24
        let width = abs(from.x - to.x) + 48
        let height = abs(from.y - to.y) + 48
        let localFrom = CGPoint(x: from.x - minX, y: from.y - minY)
        let localTo = CGPoint(x: to.x - minX, y: to.y - minY)
        let angle = atan2(to.y - from.y, to.x - from.x)
        let mid = CGPoint(x: (localFrom.x + localTo.x) / 2,
                          y: (localFrom.y + localTo.y) / 2)

        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: localFrom)
                path.addLine(to: localTo)
            }
            .stroke(Color.white.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.55))
                .rotationEffect(.radians(angle))
                .position(x: localTo.x - cos(angle) * 14,
                          y: localTo.y - sin(angle) * 14)

            HStack(spacing: 3) {
                if label.isEmpty {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.system(size: 8))
                } else {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: "#2A2A2A")))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            .position(mid)
            .onTapGesture(count: 2, perform: onEditLabel)
            .contextMenu {
                Button("Edit Label…", action: onEditLabel)
                Divider()
                Button("Delete Connector", role: .destructive, action: onDelete)
            }
        }
        .frame(width: width, height: height)
        .position(x: minX + width / 2, y: minY + height / 2)
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
