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

    // MARK: - Constants

    private static let dotGridSpacing: CGFloat = 40
    private static let dotSize: CGFloat = 2
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
            .onTapGesture {
                viewModel.clearSelection()
            }
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
        .background(Color(hex: "#1A1A1A"))
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
    private var canvasBackground: some View {
        // Screen-space grid: dots at world-grid positions projected through
        // the transform, culled to the viewport. The grid CONSUMES the
        // transform; it owns none of it.
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(hex: "#1E1E1E"))
            )

            let transform = viewModel.transform
            let spacing = Self.dotGridSpacing * transform.zoom
            guard spacing >= 6 else { return }   // grid too dense to be useful
            let dotRadius = max(0.5, Self.dotSize * transform.zoom / 2)

            // Screen positions of world grid lines: offset modulo spacing.
            let phaseX = transform.offset.x.truncatingRemainder(dividingBy: spacing)
            let phaseY = transform.offset.y.truncatingRemainder(dividingBy: spacing)

            var x = phaseX - spacing
            while x < size.width + spacing {
                var y = phaseY - spacing
                while y < size.height + spacing {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - dotRadius, y: y - dotRadius,
                                               width: dotRadius * 2,
                                               height: dotRadius * 2)),
                        with: .color(Color(hex: "#3A3A3A"))
                    )
                    y += spacing
                }
                x += spacing
            }

            // World-origin crosshair (projected).
            let origin = transform.toScreen(.zero)
            let arm: CGFloat = 20 * transform.zoom
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: origin.x - arm, y: origin.y))
                    path.addLine(to: CGPoint(x: origin.x + arm, y: origin.y))
                    path.move(to: CGPoint(x: origin.x, y: origin.y - arm))
                    path.addLine(to: CGPoint(x: origin.x, y: origin.y + arm))
                },
                with: .color(Color(hex: "#4A4A4A")),
                lineWidth: 1
            )
        }
    }

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
        }
        // The ONE place zoom and offset touch the render tree.
        .scaleEffect(viewModel.transform.zoom, anchor: .topLeading)
        .offset(x: viewModel.transform.offset.x, y: viewModel.transform.offset.y)
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
