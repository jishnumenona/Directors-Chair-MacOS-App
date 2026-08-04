// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardViewModel.swift
//
// Vision Board ViewModel - State Management for Vision Board Canvas
// Manages vision cards, canvas state, zoom, and selection.

import SwiftUI
import DirectorsChairCore
import Combine

// MARK: - Vision Board ViewModel

@MainActor
public class VisionBoardViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All vision cards on the board
    @Published public var cards: [VisionCard] = []

    /// Currently selected card IDs
    @Published public var selectedCardIds: Set<String> = []

    /// The single canvas transform: screen = world × zoom + offset (Slice 1).
    @Published public var transform = CanvasTransform()

    /// Viewport size, published by the canvas view; used by zoom/fit anchors.
    public var viewportSize: CGSize = .zero

    /// Compatibility accessor over `transform` — existing callers and tests
    /// keep working; state has ONE owner.
    public var zoomLevel: CGFloat {
        get { transform.zoom }
        set { transform.zoom = min(max(newValue, Self.minZoom), Self.maxZoom) }
    }

    /// Compatibility accessor over `transform`.
    public var canvasOffset: CGPoint {
        get { transform.offset }
        set { transform.offset = newValue }
    }

    /// Current board ID being displayed
    @Published public var currentBoardId: String = "master"

    /// Current filter by card type
    @Published public var filterByType: VisionCardType?

    /// Current filter by department
    @Published public var filterByDepartment: String?

    /// Search query for filtering cards
    @Published public var searchQuery: String = ""

    /// Space held on the wall while a picture is being imagined. Nothing
    /// blocks: you keep working, and the sheet fills itself in when it
    /// arrives. Several can be in flight at once.
    @Published public private(set) var pendingImagines: [PendingImagine] = []

    /// Elements with work in flight. Named for the state, not the task,
    /// so anything slow done TO an element (redrawing it from marks today,
    /// whatever comes next) says so in the same place: a turning badge in
    /// that element's own corner.
    @Published public private(set) var working: Set<String> = []

    public func isWorking(_ cardId: String) -> Bool { working.contains(cardId) }

    /// Something that was asked for didn't happen, said plainly. Cleared
    /// by the wall a few seconds after it is shown.
    @Published public var lastWorkProblem: String?

    /// Marks an element as busy for the duration of some work — and for a
    /// beat longer if the work was quick. A badge that flashes for eighty
    /// milliseconds is a badge nobody sees, which reads as nothing having
    /// happened at all.
    public func whileWorking<T>(_ cardId: String,
                                minimumVisible: Duration = .milliseconds(650),
                                _ body: () async -> T) async -> T {
        working.insert(cardId)
        let clock = ContinuousClock()
        let started = clock.now
        let result = await body()
        let elapsed = clock.now - started
        if elapsed < minimumVisible {
            try? await Task.sleep(for: minimumVisible - elapsed)
        }
        working.remove(cardId)
        return result
    }

    /// Anything at all in flight (the hint note stays down while so).
    public var isGenerating: Bool {
        !pendingImagines.isEmpty || !working.isEmpty
    }

    /// Whether grid snapping is enabled. OFF by default (The Wall): a wall
    /// of scraps that self-aligns to a grid is a slide deck. Snap stays
    /// available for the rare moment someone wants to tidy a row.
    @Published public var gridSnapEnabled: Bool = false

    /// Grid snap size in points
    @Published public var gridSnapSize: CGFloat = 20.0

    /// Show card labels
    @Published public var showLabels: Bool = true

    /// Card being edited (for editor sheet)
    /// Slice 2: project-scoped asset store backing the editor's image
    /// pipeline. Configured by the hosting view whenever the project base
    /// changes; nil when no project is on disk (saves then commit paths
    /// unchanged). Not @Published — it never drives rendering.
    public var assetStore: VisionBoardAssetStore?

    /// Published mirror of the store's project base. Cards resolve their
    /// relative image paths against this, and card views appear BEFORE
    /// the hosting view's onAppear configures the store — so the base
    /// must drive rendering (the store itself deliberately doesn't) and
    /// cards re-load when it lands.
    @Published public private(set) var projectBase: URL?

    /// Slice 4: the persisted board registry (empty boards survive).
    @Published public var boardRegistry: [VisionBoardMeta]

    /// Roadmap #5: labeled arrows between cards.
    @Published public var connectors: [VisionConnector] = []
    public var onConnectorsChanged: (([VisionConnector]) -> Void)?
    /// Card armed by "Connect to…" — the next card click completes.
    @Published public var pendingConnectorSource: String?
    /// Connector whose label the host view is editing (drives an alert).
    @Published public var editingConnectorId: String?

    /// Persistence callback for the board registry.
    public var onBoardsChanged: (([VisionBoardMeta]) -> Void)?

    @Published public var editingCard: VisionCard?

    /// Show card editor sheet
    @Published public var showingCardEditor: Bool = false

    // MARK: - Callbacks

    /// Callback when cards change (for persistence)
    public var onCardsChanged: (([VisionCard]) -> Void)?

    /// Callback for AI image generation
    public var onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)?

    // MARK: - Constants

    /// Far enough out to take in a whole wall of work at once. Zooming
    /// stopped at 10%, which is roughly one screenful — not an overview.
    public static let minZoom: CGFloat = 0.02
    public static let maxZoom: CGFloat = 5.0
    public static let zoomStep: CGFloat = 0.25
    public static let defaultCardWidth: CGFloat = 200.0
    public static let defaultCardHeight: CGFloat = 200.0

    // MARK: - Computed Properties

    /// Cards filtered by current criteria
    public var filteredCards: [VisionCard] {
        var result = cards.filter { $0.boardId == currentBoardId }

        if let typeFilter = filterByType {
            result = result.filter { $0.cardType == typeFilter.rawValue }
        }

        if let deptFilter = filterByDepartment, !deptFilter.isEmpty {
            result = result.filter { $0.department == deptFilter }
        }

        if !searchQuery.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.description.localizedCaseInsensitiveContains(searchQuery) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            }
        }

        // Draw order: section frames render UNDER everything, then
        // (pinned, zOrder) ascending — pinned cards render after (above)
        // everything unpinned, honoring "Pin to Top".
        return result.sorted {
            let leftFrame = $0.cardType == VisionCardType.frame.rawValue
            let rightFrame = $1.cardType == VisionCardType.frame.rawValue
            if leftFrame != rightFrame { return leftFrame }
            if $0.pinned != $1.pinned { return !$0.pinned }
            return $0.zOrder < $1.zOrder
        }
    }

    /// Available boards: the persisted registry UNION boards derived from
    /// cards (legacy projects have no registry), plus the default board —
    /// an empty board no longer vanishes from the picker (Slice 4).
    public var boardIds: [String] {
        let ids = Set(cards.map { $0.boardId })
            .union(boardRegistry.map(\.id))
            .union(["master"])
        return Array(ids).sorted()
    }

    /// All departments used in cards
    public var departments: [String] {
        let depts = Set(cards.compactMap { $0.department })
        return Array(depts).sorted()
    }

    /// Maximum z-order in current board
    public var maxZOrder: Double {
        filteredCards.map { $0.zOrder }.max() ?? 0
    }

    /// Total cards on current board
    public var cardCount: Int {
        filteredCards.count
    }

    /// Currently selected cards
    public var selectedCards: [VisionCard] {
        cards.filter { selectedCardIds.contains($0.id) }
    }

    // MARK: - Initialization

    public init(cards: [VisionCard] = [], boards: [VisionBoardMeta] = [],
                connectors: [VisionConnector] = []) {
        self.cards = cards
        self.boardRegistry = boards
        self.connectors = connectors
        // Note: Don't select cards in init as filteredCards depends on currentBoardId
    }

    // MARK: - Card CRUD Operations

    /// Add a new card to the board
    public func addCard(_ card: VisionCard) {
        var newCard = card
        newCard.boardId = currentBoardId

        // Set z-order to top if not specified
        if newCard.zOrder == 0 {
            newCard.zOrder = maxZOrder + 1
        }

        // Set default position if not specified: centered in the visible
        // world, cascading away from existing cards (Slice 1).
        if newCard.canvasX == nil || newCard.canvasY == nil {
            let origin = defaultPlacement(
                for: CGSize(width: newCard.canvasWidth ?? Double(Self.defaultCardWidth),
                            height: newCard.canvasHeight ?? Double(Self.defaultCardHeight)))
            newCard.canvasX = newCard.canvasX ?? origin.x
            newCard.canvasY = newCard.canvasY ?? origin.y
        }

        // Set default size if not specified
        if newCard.canvasWidth == nil {
            newCard.canvasWidth = Double(Self.defaultCardWidth)
        }
        if newCard.canvasHeight == nil {
            newCard.canvasHeight = Double(Self.defaultCardHeight)
        }

        cards.append(newCard)
        notifyChange()
    }

    /// Update an existing card
    public func updateCard(_ card: VisionCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
            notifyChange()
        }
    }

    /// Remove a card by ID
    public func removeCard(_ cardId: String) {
        let removed = cards.filter { $0.id == cardId }
        cards.removeAll { $0.id == cardId }
        selectedCardIds.remove(cardId)
        cleanupAssets(for: removed)
        removeConnectors(touching: [cardId])
        notifyChange()
    }

    /// Remove selected cards
    public func removeSelectedCards() {
        let removed = cards.filter { selectedCardIds.contains($0.id) }
        cards.removeAll { selectedCardIds.contains($0.id) }
        let removedIds = Set(removed.map(\.id))
        selectedCardIds.removeAll()
        cleanupAssets(for: removed)
        removeConnectors(touching: removedIds)
        notifyChange()
    }

    /// Slice 4: trash-first, ref-counted asset cleanup — only files no
    /// remaining card references, and only inside assets/visionboard/
    /// (the store's guard refuses legacy absolute paths that point at the
    /// user's own files).
    private func cleanupAssets(for removed: [VisionCard]) {
        guard let store = assetStore else { return }
        for path in VisionBoardAssetStore.unreferencedImagePaths(
            removed: removed, remaining: cards) {
            try? store.removeAsset(relativePath: path)
        }
    }

    /// Duplicate selected cards
    public func duplicateSelectedCards() {
        let toDuplicate = selectedCards
        var newIds: Set<String> = []

        for card in toDuplicate {
            var newCard = card
            newCard.id = UUID().uuidString
            newCard.canvasX = (newCard.canvasX ?? 0) + 20
            newCard.canvasY = (newCard.canvasY ?? 0) + 20
            newCard.zOrder = maxZOrder + 1
            cards.append(newCard)
            newIds.insert(newCard.id)
        }

        selectedCardIds = newIds
        notifyChange()
    }

    // MARK: - Selection

    /// Select a card (optionally adding to selection)
    public func selectCard(_ cardId: String, addToSelection: Bool = false) {
        if addToSelection {
            selectedCardIds.insert(cardId)
        } else {
            selectedCardIds = [cardId]
        }
    }

    /// Deselect a card
    public func deselectCard(_ cardId: String) {
        selectedCardIds.remove(cardId)
    }

    /// Toggle card selection
    public func toggleCardSelection(_ cardId: String) {
        if selectedCardIds.contains(cardId) {
            selectedCardIds.remove(cardId)
        } else {
            selectedCardIds.insert(cardId)
        }
    }

    /// Clear all selection. Deliberately does NOT disarm a pending
    /// connector: selection changes constantly, and having it silently
    /// cancel the tool made "Connect" look broken — you'd click the second
    /// scrap and merely select it. Only esc, a bare-wall click, or
    /// completing the link puts the tool down.
    public func clearSelection() {
        selectedCardIds.removeAll()
    }

    /// Select all cards on current board
    public func selectAllCards() {
        selectedCardIds = Set(filteredCards.map { $0.id })
    }

    // MARK: - Z-Order Management

    /// Bring selected cards to front
    public func bringToFront() {
        var currentMax = maxZOrder
        for id in selectedCardIds {
            if let index = cards.firstIndex(where: { $0.id == id }) {
                currentMax += 1
                cards[index].zOrder = currentMax
            }
        }
        notifyChange()
    }

    /// Send selected cards to back
    public func sendToBack() {
        let minZ = filteredCards.map { $0.zOrder }.min() ?? 0
        var currentZ = minZ - Double(selectedCardIds.count)

        for id in selectedCardIds {
            if let index = cards.firstIndex(where: { $0.id == id }) {
                cards[index].zOrder = currentZ
                currentZ += 1
            }
        }
        notifyChange()
    }

    // MARK: - Position & Size Updates

    /// Update card position (with optional grid snapping)
    public func updateCardPosition(_ cardId: String, x: Double, y: Double) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }

        var newX = x
        var newY = y

        if gridSnapEnabled {
            newX = round(x / Double(gridSnapSize)) * Double(gridSnapSize)
            newY = round(y / Double(gridSnapSize)) * Double(gridSnapSize)
        }

        cards[index].canvasX = newX
        cards[index].canvasY = newY
        notifyChange()
    }

    /// Update card size
    public func updateCardSize(_ cardId: String, width: Double, height: Double) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }

        var newWidth = max(100, width)
        var newHeight = max(80, height)

        if gridSnapEnabled {
            newWidth = round(newWidth / Double(gridSnapSize)) * Double(gridSnapSize)
            newHeight = round(newHeight / Double(gridSnapSize)) * Double(gridSnapSize)
        }

        cards[index].canvasWidth = newWidth
        cards[index].canvasHeight = newHeight
        notifyChange()
    }

    /// Move selected cards by delta
    public func moveSelectedCards(deltaX: Double, deltaY: Double) {
        for id in selectedCardIds {
            if let index = cards.firstIndex(where: { $0.id == id }) {
                let currentX = cards[index].canvasX ?? 0
                let currentY = cards[index].canvasY ?? 0
                cards[index].canvasX = currentX + deltaX
                cards[index].canvasY = currentY + deltaY
            }
        }
        notifyChange()
    }

    // MARK: - Gesture Sessions (Slice 1 — anchored, commit-on-end)

    private var panSessionStartOffset: CGPoint?
    private var pinchSessionStart: CanvasTransform?
    private var dragSessionOrigins: [String: CGPoint] = [:]
    private var dragSessionAnchorId: String?
    private var resizeSession: (cardId: String, corner: ResizeCorner, startRect: CGRect)?
    /// Rotate session: the scrap and the tilt it started at.
    private var rotateSession: (cardId: String, startRotation: Double)?

    /// True while a drag/resize gesture or the editor sheet is active
    /// (Slice 3 uses this to defer external reconciliation).
    public var interactionInProgress: Bool {
        panSessionStartOffset != nil || pinchSessionStart != nil
            || dragSessionAnchorId != nil || resizeSession != nil
            || showingCardEditor
    }

    public func beginPan() {
        panSessionStartOffset = transform.offset
    }

    /// DragGesture has no "began" phase — the first onChanged anchors.
    public func beginPanIfNeeded() {
        if panSessionStartOffset == nil { beginPan() }
    }

    public func updatePan(translation: CGSize) {
        guard let start = panSessionStartOffset else { return }
        transform.offset = VisionCanvasGeometry.pannedOffset(
            startOffset: start, translation: translation)
    }

    public func endPan() {
        panSessionStartOffset = nil
        applyPendingExternalCards()
    }

    /// Anchored pinch: magnification is relative to the gesture start.
    public func pinchZoom(magnification: CGFloat, focus: CGPoint) {
        if pinchSessionStart == nil { pinchSessionStart = transform }
        guard let start = pinchSessionStart else { return }
        transform = VisionCanvasGeometry.zoomed(
            start, toZoom: start.zoom * magnification, about: focus,
            minZoom: Self.minZoom, maxZoom: Self.maxZoom)
    }

    public func endPinch() {
        pinchSessionStart = nil
        applyPendingExternalCards()
    }

    /// Trackpad two-finger scroll pans the canvas directly — each event
    /// already carries a delta, so no anchored session is needed.
    /// Natural-scrolling deltas move content with the fingers (the
    /// NSScrollView convention).
    public func scrollPan(deltaX: CGFloat, deltaY: CGFloat) {
        transform.offset.x += deltaX
        transform.offset.y += deltaY
    }

    /// ⌘-scroll zooms about the cursor (the Audacity/Figma convention:
    /// scroll up zooms in). Exponential, so zoom speed feels constant at
    /// any level; clamped like every other zoom path.
    public func scrollZoom(deltaY: CGFloat, focus: CGPoint) {
        guard deltaY != 0 else { return }
        let factor = pow(1.0035, -deltaY)
        transform = VisionCanvasGeometry.zoomed(
            transform, toZoom: transform.zoom * factor, about: focus,
            minZoom: Self.minZoom, maxZoom: Self.maxZoom)
    }

    /// Captures the whole selection's origins so multi-drag stays rigid.
    /// A section frame carries its contents: cards whose CENTER lies
    /// inside the frame at drag start move rigidly with it (membership is
    /// computed once per gesture, not re-evaluated mid-drag).
    public func beginCardDrag(anchor cardId: String) {
        guard !isPinned(cardId) else { return }   // pinned = stuck to the wall
        dragSessionAnchorId = cardId
        var ids = selectedCardIds.contains(cardId) ? selectedCardIds : [cardId]
        if let anchor = cards.first(where: { $0.id == cardId }),
           anchor.cardType == VisionCardType.frame.rawValue {
            let rect = CGRect(x: anchor.canvasX ?? 0, y: anchor.canvasY ?? 0,
                              width: anchor.canvasWidth ?? 0,
                              height: anchor.canvasHeight ?? 0)
            for card in cards where card.boardId == anchor.boardId
                && card.id != anchor.id
                && card.cardType != VisionCardType.frame.rawValue {
                let center = CGPoint(
                    x: (card.canvasX ?? 0) + (card.canvasWidth ?? 200) / 2,
                    y: (card.canvasY ?? 0) + (card.canvasHeight ?? 200) / 2)
                if rect.contains(center) { ids.insert(card.id) }
            }
        }
        dragSessionOrigins = [:]
        for id in ids {
            if let card = cards.first(where: { $0.id == id }) {
                dragSessionOrigins[id] = CGPoint(x: card.canvasX ?? 0,
                                                 y: card.canvasY ?? 0)
            }
        }
    }

    public func updateCardDrag(translation: CGSize) {
        applyDrag(translation: translation, snap: nil)
    }

    public func endCardDrag(translation: CGSize) {
        applyDrag(translation: translation,
                  snap: gridSnapEnabled ? gridSnapSize : nil)
        dragSessionOrigins = [:]
        dragSessionAnchorId = nil
        notifyChange()
    }

    private func applyDrag(translation: CGSize, snap: CGFloat?) {
        guard let anchorId = dragSessionAnchorId,
              let anchorStart = dragSessionOrigins[anchorId] else { return }
        // Snap the anchor card; move companions by the identical world delta.
        let anchorNew = VisionCanvasGeometry.draggedOrigin(
            startOrigin: anchorStart, translation: translation,
            zoom: transform.zoom, snap: snap)
        let delta = CGPoint(x: anchorNew.x - anchorStart.x,
                            y: anchorNew.y - anchorStart.y)
        for (id, start) in dragSessionOrigins {
            if let index = cards.firstIndex(where: { $0.id == id }) {
                cards[index].canvasX = start.x + delta.x
                cards[index].canvasY = start.y + delta.y
            }
        }
    }

    public func beginResize(cardId: String, corner: ResizeCorner) {
        guard !isPinned(cardId),
              let card = cards.first(where: { $0.id == cardId }) else { return }
        resizeSession = (cardId, corner, CGRect(
            x: card.canvasX ?? 0, y: card.canvasY ?? 0,
            width: card.canvasWidth ?? Double(Self.defaultCardWidth),
            height: card.canvasHeight ?? Double(Self.defaultCardHeight)))
    }

    public func updateResize(translation: CGSize) {
        applyResize(translation: translation, snap: nil)
    }

    public func endResize(translation: CGSize) {
        applyResize(translation: translation,
                    snap: gridSnapEnabled ? gridSnapSize : nil)
        resizeSession = nil
        notifyChange()
    }

    private func applyResize(translation: CGSize, snap: CGFloat?) {
        guard let session = resizeSession,
              let index = cards.firstIndex(where: { $0.id == session.cardId }) else { return }
        let rect = VisionCanvasGeometry.resizedRect(
            startRect: session.startRect, corner: session.corner,
            translation: translation, zoom: transform.zoom,
            minSize: CGSize(width: 100, height: 80), snap: snap)
        cards[index].canvasX = rect.origin.x
        cards[index].canvasY = rect.origin.y
        cards[index].canvasWidth = rect.width
        cards[index].canvasHeight = rect.height
    }

    // MARK: - Zoom Operations

    /// Zoom about the viewport center (plain zoom when no viewport known,
    /// e.g. in unit tests).
    private func setZoom(_ newZoom: CGFloat) {
        guard viewportSize != .zero else {
            zoomLevel = newZoom
            return
        }
        transform = VisionCanvasGeometry.zoomed(
            transform, toZoom: newZoom,
            about: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2),
            minZoom: Self.minZoom, maxZoom: Self.maxZoom)
    }

    /// Zoom in by step
    public func zoomIn() {
        setZoom(min(Self.maxZoom, zoomLevel * 1.25))
    }

    /// Zoom out by step
    /// Proportional, not a fixed 0.25: subtracting a quarter is a single
    /// step from 25% to the floor, and a crawl coming back from 400%.
    public func zoomOut() {
        setZoom(max(Self.minZoom, zoomLevel / 1.25))
    }

    /// Reset zoom to 100%
    public func resetZoom() {
        setZoom(1.0)
    }

    /// Jump straight to a level — the zoom readout offers the useful ones
    /// (a 10% overview through 400%) so getting back is one click, not
    /// twenty presses of the minus button.
    public static let zoomPresets: [CGFloat] = [0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 4.0]

    public func setZoomLevel(_ level: CGFloat) {
        setZoom(min(max(level, Self.minZoom), Self.maxZoom))
    }

    /// Fit the current board's cards in the viewport (one formula for
    /// fit / first-appear / board switch — Slice 1).
    public func fitToView(viewSize: CGSize) {
        transform = VisionCanvasGeometry.fitTransform(
            contentBounds: VisionCanvasGeometry.boundingBox(of: filteredCards),
            viewport: viewSize, padding: 50,
            minZoom: Self.minZoom, maxZoom: Self.maxZoom)
    }

    // MARK: - Board Operations

    /// Switch to a different board
    public func switchBoard(_ boardId: String) {
        currentBoardId = boardId
        clearSelection()
        fitToView(viewSize: viewportSize)
    }

    /// Create a new board: slugged id deduped against existing boards,
    /// PERSISTED via the registry so an empty board survives reload.
    public func createBoard(_ name: String) -> String {
        let base = name.lowercased().replacingOccurrences(of: " ", with: "_")
        var boardId = base
        var counter = 2
        while boardIds.contains(boardId) {
            boardId = "\(base)-\(counter)"
            counter += 1
        }
        boardRegistry.append(VisionBoardMeta(id: boardId, name: name))
        onBoardsChanged?(boardRegistry)
        switchBoard(boardId)
        return boardId
    }

    // MARK: - Card Editor

    /// Deterministic default placement: the visible-world center (legacy
    /// top-left+100 when no viewport is known, e.g. unit tests), cascaded
    /// off existing cards so stacks never hide each other.
    private func defaultPlacement(for size: CGSize) -> CGPoint {
        let preferred: CGPoint
        if viewportSize == .zero {
            let topLeft = transform.toWorld(.zero)
            preferred = CGPoint(x: topLeft.x + 100, y: topLeft.y + 100)
        } else {
            let center = transform.toWorld(CGPoint(x: viewportSize.width / 2,
                                                   y: viewportSize.height / 2))
            preferred = CGPoint(x: center.x - size.width / 2,
                                y: center.y - size.height / 2)
        }
        let existing = filteredCards.map {
            CGRect(x: $0.canvasX ?? 0, y: $0.canvasY ?? 0,
                   width: $0.canvasWidth ?? 200, height: $0.canvasHeight ?? 200)
        }
        var origin = VisionCanvasGeometry.dropOrigin(
            for: size, over: existing, preferredOrigin: preferred)
        if gridSnapEnabled {
            origin.x = (origin.x / gridSnapSize).rounded() * gridSnapSize
            origin.y = (origin.y / gridSnapSize).rounded() * gridSnapSize
        }
        return origin
    }

    /// Open editor for a new card
    /// Sticky last-used text preset (research: tldraw's pattern — serial
    /// creation stays fast).
    static let lastTextStyleKey = "visionBoardLastTextStyle"

    /// Opens the editor for a fresh card. `origin` (world space) places
    /// it under a right-click; nil falls back to the visible-center
    /// cascade placement. `textStyle` picks a preset for text cards
    /// (nil = last used).
    public func createNewCard(type: VisionCardType = .image,
                              at origin: CGPoint? = nil,
                              textStyle: String? = nil) {
        var card = VisionCard()
        card.cardType = type.rawValue
        card.boardId = currentBoardId
        if type == .frame {
            card.canvasWidth = 480
            card.canvasHeight = 360
        }
        if type == .shotStrip {
            card.canvasWidth = 560
            card.canvasHeight = 140
        }
        if type == .text {
            let style = textStyle
                ?? UserDefaults.standard.string(forKey: Self.lastTextStyleKey)
            card.textStyle = style
            if let style {
                UserDefaults.standard.set(style, forKey: Self.lastTextStyleKey)
            }
        }
        var placement = origin ?? defaultPlacement(
            for: CGSize(width: Self.defaultCardWidth, height: Self.defaultCardHeight))
        if origin != nil, gridSnapEnabled {
            placement = CGPoint(
                x: (placement.x / gridSnapSize).rounded() * gridSnapSize,
                y: (placement.y / gridSnapSize).rounded() * gridSnapSize)
        }
        card.canvasX = placement.x
        card.canvasY = placement.y
        card.canvasWidth = card.canvasWidth ?? Double(Self.defaultCardWidth)
        card.canvasHeight = card.canvasHeight ?? Double(Self.defaultCardHeight)
        card.zOrder = maxZOrder + 1

        editingCard = card
        showingCardEditor = true
    }

    /// Roadmap #2: one-click palette from an image card. Places the
    /// palette card immediately to the source card's right, top z.
    public func extractPalette(fromCardId cardId: String) {
        guard let source = cards.first(where: { $0.id == cardId }),
              let url = VisionBoardImagePath.resolveImageURL(
                source.imagePath, projectBase: projectBase),
              let image = NSImage(contentsOf: url) else { return }
        let colors = VisionPaletteExtractor.extract(from: image, count: 5)
        guard !colors.isEmpty else { return }

        var palette = VisionCard(
            title: source.title.isEmpty ? "Palette" : "\(source.title) palette")
        palette.cardType = VisionCardType.colorPalette.rawValue
        palette.boardId = source.boardId
        palette.colorPalette = colors
        palette.canvasX = (source.canvasX ?? 0) + (source.canvasWidth ?? 200) + 24
        palette.canvasY = source.canvasY
        palette.canvasWidth = 200
        palette.canvasHeight = 100
        palette.zOrder = maxZOrder + 1
        cards.append(palette)
        notifyChange()
    }

    /// True while at least one of the current board's cards intersects
    /// the visible world (or there is nothing/nowhere to show). The
    /// infinite canvas is unbounded by design — this drives the
    /// "Back to content" rescue when the user scrolls into empty space.
    public var contentVisible: Bool {
        guard viewportSize != .zero else { return true }
        let board = cards.filter { $0.boardId == currentBoardId }
        guard !board.isEmpty else { return true }
        let visible = transform.visibleWorldRect(viewport: viewportSize)
        return board.contains { card in
            visible.intersects(CGRect(
                x: card.canvasX ?? 0, y: card.canvasY ?? 0,
                width: card.canvasWidth ?? 200,
                height: card.canvasHeight ?? 200))
        }
    }

    // MARK: - Connectors (roadmap #5)

    public var boardConnectors: [VisionConnector] {
        connectors.filter { $0.boardId == currentBoardId }
    }

    public func beginConnector(from cardId: String) {
        pendingConnectorSource = cardId
    }

    /// Completes a pending connector. Self-links and duplicates are
    /// silently ignored; either way the pending state clears.
    public func completeConnector(to cardId: String) {
        guard let source = pendingConnectorSource else { return }
        pendingConnectorSource = nil
        guard source != cardId,
              cards.contains(where: { $0.id == cardId }),
              !connectors.contains(where: {
                  $0.boardId == currentBoardId
                      && $0.fromCardId == source && $0.toCardId == cardId
              }) else { return }
        connectors.append(VisionConnector(boardId: currentBoardId,
                                          fromCardId: source,
                                          toCardId: cardId))
        onConnectorsChanged?(connectors)
    }

    public func removeConnector(_ id: String) {
        connectors.removeAll { $0.id == id }
        onConnectorsChanged?(connectors)
    }

    public func setConnectorLabel(_ id: String, label: String) {
        guard let index = connectors.firstIndex(where: { $0.id == id }) else { return }
        connectors[index].label = label
        onConnectorsChanged?(connectors)
    }

    /// Deleting cards severs their arrows.
    private func removeConnectors(touching ids: Set<String>) {
        let before = connectors.count
        connectors.removeAll { ids.contains($0.fromCardId) || ids.contains($0.toCardId) }
        if connectors.count != before { onConnectorsChanged?(connectors) }
    }

    // MARK: - Right-Click Context Menu

    /// World position of the last right-click on empty canvas, captured
    /// by the canvas event catcher so "add card" lands under the cursor.
    private var lastRightClickWorldPoint: CGPoint?

    /// Converts and stores a right-click's canvas-space point. World
    /// conversion happens NOW — the menu blocks pan/zoom, so the
    /// transform can't drift before the user picks an item.
    public func recordRightClick(atScreenPoint point: CGPoint) {
        lastRightClickWorldPoint = transform.toWorld(point)
    }

    /// Hands the captured point to the menu action and clears it.
    public func consumeRightClickPoint() -> CGPoint? {
        defer { lastRightClickWorldPoint = nil }
        return lastRightClickWorldPoint
    }

    // MARK: - Absorb (The Wall, pass 1)

    /// One gesture, no questions: drop or paste anything and it lands on
    /// the wall. Files are imported, clipboard pixels staged, remote images
    /// downloaded — all through the existing asset pipeline
    /// (`normalizedForSave`) — and words become text scraps. Several items
    /// at once scatter into a loose pile around the drop point.
    ///
    /// `worldPoint` is where the cursor was; nil falls back to the visible
    /// centre. Returns the ids of the scraps that landed.
    @discardableResult
    public func absorb(_ payloads: [AbsorbPayload],
                       at worldPoint: CGPoint? = nil) async -> [String] {
        guard !payloads.isEmpty else { return [] }

        var drafts: [VisionCard] = []
        for payload in payloads {
            if let draft = await scrap(from: payload) { drafts.append(draft) }
        }
        guard !drafts.isEmpty else { return [] }

        let centre = worldPoint ?? absorbCentre()
        let sizes = drafts.map {
            CGSize(width: $0.canvasWidth ?? Double(Self.defaultCardWidth),
                   height: $0.canvasHeight ?? Double(Self.defaultCardHeight))
        }
        let origins = VisionCanvasGeometry.pileOrigins(sizes: sizes, around: centre)

        var top = maxZOrder
        var landed: [String] = []
        for (index, var draft) in drafts.enumerated() {
            draft.boardId = currentBoardId
            draft.canvasX = origins[index].x
            draft.canvasY = origins[index].y
            draft.rotation = VisionBoardAbsorb.settleAngle(seed: draft.id)
            top += 1
            draft.zOrder = top
            cards.append(draft)
            landed.append(draft.id)
        }
        selectedCardIds = Set(landed)
        notifyChange()
        return landed
    }

    /// Turns one payload into an unplaced scrap. Images ride the tested
    /// asset pipeline: whatever reference the payload gives us is handed to
    /// `normalizedForSave`, which imports, finalizes, or downloads as
    /// needed and leaves the project self-contained.
    private func scrap(from payload: AbsorbPayload) async -> VisionCard? {
        var card = VisionCard()
        card.boardId = currentBoardId

        switch payload {
        case .text(let words):
            let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            card.cardType = VisionCardType.text.rawValue
            card.text = trimmed
            card.textStyle = UserDefaults.standard.string(forKey: Self.lastTextStyleKey)
            card.canvasWidth = 260
            card.canvasHeight = 140
            return card

        case .fileURL(let url):
            card.cardType = VisionCardType.image.rawValue
            card.imagePath = url.path

        case .remoteURL(let url):
            card.cardType = VisionCardType.image.rawValue
            card.imagePath = url.absoluteString

        case .imageData(let data):
            card.cardType = VisionCardType.image.rawValue
            guard let store = assetStore,
                  let staged = try? store.stagePastedPNG(data) else { return nil }
            card.imagePath = staged.path
        }

        if let store = assetStore {
            card.imagePath = await store.normalizedForSave(card.imagePath)
        }
        let size = VisionBoardAbsorb.scrapSize(aspectRatio: scrapAspectRatio(card.imagePath))
        card.canvasWidth = Double(size.width)
        card.canvasHeight = Double(size.height)
        return card
    }

    private func scrapAspectRatio(_ imagePath: String?) -> CGFloat? {
        #if canImport(AppKit)
        guard let url = VisionBoardImagePath.resolveImageURL(imagePath,
                                                             projectBase: projectBase)
        else { return nil }
        return VisionBoardAbsorb.aspectRatio(ofImageAt: url)
        #else
        return nil
        #endif
    }

    /// Where a pile lands when the gesture didn't carry a point (menu
    /// paste, tests): the middle of what the user is looking at.
    private func absorbCentre() -> CGPoint {
        guard viewportSize != .zero else { return transform.toWorld(.zero) }
        return transform.toWorld(CGPoint(x: viewportSize.width / 2,
                                         y: viewportSize.height / 2))
    }

    /// A pushpin holds a scrap where it is: no dragging, resizing or
    /// rotating until it comes out.
    public func isPinned(_ cardId: String) -> Bool {
        cards.first(where: { $0.id == cardId })?.pinned ?? false
    }

    public func togglePin(_ cardId: String) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        cards[index].pinned.toggle()
        notifyChange()
    }

    // MARK: Rotate (The Wall, pass 2)

    public func beginRotate(cardId: String) {
        guard !isPinned(cardId),
              let card = cards.first(where: { $0.id == cardId }) else { return }
        rotateSession = (cardId, card.rotation ?? 0)
    }

    public func updateRotate(delta: Double) {
        applyRotate(delta: delta)
    }

    public func endRotate(delta: Double) {
        applyRotate(delta: delta)
        rotateSession = nil
        notifyChange()
    }

    private func applyRotate(delta: Double) {
        guard let session = rotateSession,
              let index = cards.firstIndex(where: { $0.id == session.cardId })
        else { return }
        cards[index].rotation = session.startRotation + delta
    }

    // MARK: Keyboard (The Wall, pass 2)

    /// Arrow-key nudge, in world points.
    public func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard !selectedCardIds.isEmpty else { return }
        var moved = false
        for id in selectedCardIds where !isPinned(id) {
            guard let index = cards.firstIndex(where: { $0.id == id }) else { continue }
            cards[index].canvasX = (cards[index].canvasX ?? 0) + Double(dx)
            cards[index].canvasY = (cards[index].canvasY ?? 0) + Double(dy)
            moved = true
        }
        if moved { notifyChange() }
    }

    // MARK: - Wall tools (The Wall, pass 2)

    /// AI image generation, back on the wall itself. The generated file
    /// rides the same absorb pipeline as anything you drop, so it lands as
    /// an ordinary scrap — tilted, sized to its picture, imported into the
    /// project.
    public func imagine(_ description: String, at worldPoint: CGPoint?) async {
        let prompt = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, let generate = onGenerateImage else { return }

        // Hold the space immediately: a blank sheet goes up where the
        // picture will land, and the wall stays usable while it works.
        let size = CGSize(width: 260, height: 146)
        let centre = worldPoint ?? absorbCentre()
        let held = PendingImagine(
            id: UUID().uuidString, prompt: prompt,
            origin: CGPoint(x: centre.x - size.width / 2,
                            y: centre.y - size.height / 2),
            size: size)
        pendingImagines.append(held)

        let url: URL? = await withCheckedContinuation { continuation in
            generate(prompt) { generated in
                continuation.resume(returning: generated)
            }
        }
        pendingImagines.removeAll { $0.id == held.id }
        guard let url else { return }

        let landed = await absorb([.fileURL(url)], at: centre)
        // The prompt is worth keeping — it is how the picture came to exist.
        if let id = landed.first,
           let index = cards.firstIndex(where: { $0.id == id }) {
            cards[index].description = prompt
            notifyChange()
        }
    }

    /// Redrawing a picture from marks made on it. The current image goes
    /// along as the reference, so the result is an EDIT of what is there
    /// rather than a fresh invention — the same contract the shot and
    /// scene surfaces use.
    public var onEditImage: ((VisionImageEdit, @escaping (URL?) -> Void) -> Void)?

    /// Applies annotation instructions to an element's picture, replacing
    /// it in place and keeping the words that made it.
    public func redraw(_ cardId: String, instructions: String,
                       baseImage: Data) async {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        guard let edit = onEditImage else {
            // Silence here reads as "the tool is broken". Say so instead.
            lastWorkProblem = "Redrawing isn't available in this window."
            return
        }
        let original = cards[index].description
        let combined = original.isEmpty
            ? instructions
            : instructions + "\n\nOriginal prompt: " + original

        let url: URL? = await whileWorking(cardId) {
            await withCheckedContinuation { continuation in
                edit(VisionImageEdit(prompt: combined, baseImage: baseImage)) {
                    continuation.resume(returning: $0)
                }
            }
        }
        guard let url else {
            lastWorkProblem = "The picture couldn't be redrawn. Try again."
            return
        }
        guard let store = assetStore else {
            lastWorkProblem = "Save the project first — there's nowhere to "
                            + "keep the new picture yet."
            return
        }
        guard let stored = await store.normalizedForSave(url.path),
              let target = cards.firstIndex(where: { $0.id == cardId })
        else {
            lastWorkProblem = "The new picture couldn't be saved into the project."
            return
        }
        cards[target].imagePath = stored
        cards[target].description = combined
        notifyChange()
    }

    /// A link pinned to the wall. YouTube and Vimeo become video scraps;
    /// a YouTube still is fetched as the scrap's face so the wall shows
    /// the frame, not a URL.
    public func pinLink(_ raw: String, at worldPoint: CGPoint?) async {
        guard let url = VisionLink.normalized(raw) else { return }
        let kind = VisionLink.classify(url)

        var card = VisionCard()
        card.boardId = currentBoardId
        card.title = VisionLink.displayName(for: url)
        card.sourceUrl = url.absoluteString

        if kind.isVideo {
            card.cardType = VisionCardType.video.rawValue
            card.videoUrl = url.absoluteString
            card.canvasWidth = 280
            card.canvasHeight = 158
            if let thumbnail = kind.thumbnailURL, let store = assetStore {
                card.imagePath = await store.normalizedForSave(thumbnail.absoluteString)
            }
        } else {
            card.cardType = VisionCardType.link.rawValue
            card.canvasWidth = 260
            card.canvasHeight = 96
        }

        let centre = worldPoint ?? absorbCentre()
        let size = CGSize(width: card.canvasWidth ?? 260,
                          height: card.canvasHeight ?? 96)
        let origin = VisionCanvasGeometry.pileOrigins(sizes: [size],
                                                      around: centre)[0]
        card.canvasX = origin.x
        card.canvasY = origin.y
        card.rotation = VisionBoardAbsorb.settleAngle(seed: card.id)
        card.zOrder = maxZOrder + 1
        cards.append(card)
        selectedCardIds = [card.id]
        notifyChange()
    }

    /// Rewrites a word clipping in place (The Wall, pass 2). Empty text
    /// removes the scrap — a clipping with nothing on it is litter.
    public func rewriteClipping(_ cardId: String, words: String) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeCard(cardId)
            return
        }
        cards[index].text = trimmed
        notifyChange()
    }

    /// Put the connector tool down without drawing anything.
    public func cancelConnector() {
        pendingConnectorSource = nil
    }

    /// Writes (or erases) the slip of paper stuck under an element.
    public func setNote(_ cardId: String, text: String) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cards[index].referenceNote = trimmed.isEmpty ? nil : trimmed
        notifyChange()
    }

    /// Cuts this scrap from a different stock.
    public func setPaper(_ cardId: String, paper: VisionPaper) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        cards[index].paper = paper.rawValue
        notifyChange()
    }

    /// Cycles a clipping through the cuts (poster → torn strip → editorial
    /// → caption → note → label).
    public func cycleClippingCut(_ cardId: String) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }),
              cards[index].cardType == VisionCardType.text.rawValue else { return }
        let next = VisionTextStyle.resolve(cards[index].textStyle).next
        cards[index].textStyle = next.rawValue
        UserDefaults.standard.set(next.rawValue, forKey: Self.lastTextStyleKey)
        notifyChange()
    }

    /// Open editor for existing card
    public func editCard(_ card: VisionCard) {
        editingCard = card
        showingCardEditor = true
    }

    /// Creates/replaces the asset store when the project base changes
    /// (idempotent per base — the staging root must stay stable across a
    /// single editing session).
    public func configureAssetStore(projectBase: URL?) {
        guard let projectBase else {
            assetStore = nil
            self.projectBase = nil
            return
        }
        if assetStore?.projectBase != projectBase {
            assetStore = VisionBoardAssetStore(projectBase: projectBase)
        }
        if self.projectBase != projectBase {
            self.projectBase = projectBase
        }
    }

    /// Save edited card. With an asset store configured this is the
    /// Slice-2 pipeline: the image path is normalized (staged→finalized,
    /// absolute-inside→relativized, outside→imported, remote→downloaded)
    /// BEFORE the single commit, and leftover staged files are reaped after.
    /// Only references the SESSION introduced are normalized — an unchanged
    /// legacy path must not re-import a duplicate copy on every save. The
    /// exception is relativizing an unchanged in-project absolute path:
    /// idempotent, no file operations, migrates old projects as they save.
    public func saveEditedCard() {
        guard let card = editingCard else { return }
        editingCard = nil
        showingCardEditor = false

        guard let store = assetStore else {
            commitEditedCard(card)
            return
        }
        let original = cards.first(where: { $0.id == card.id })
        let imageChanged = original == nil || original?.imagePath != card.imagePath

        Task { @MainActor [weak self] in
            var card = card
            if imageChanged {
                card.imagePath = await store.normalizedForSave(card.imagePath)
            } else if case .legacyAbsolute(let absolute) =
                        VisionImageRef.classify(card.imagePath),
                      let relative = VisionBoardImagePath.relativized(
                        absolute, projectBase: store.projectBase) {
                card.imagePath = relative
            }
            self?.commitEditedCard(card)
            store.discardStaging()
        }
    }

    private func commitEditedCard(_ card: VisionCard) {
        if cards.contains(where: { $0.id == card.id }) {
            updateCard(card)
        } else {
            addCard(card)
        }
    }

    /// Cancel editing
    public func cancelEditing() {
        editingCard = nil
        showingCardEditor = false
        applyPendingExternalCards()
    }

    /// The editor sheet's onDismiss. It fires after Save too — by then
    /// `editingCard` is already nil and the save Task owns staging — so
    /// only a true dismissal (Cancel, Esc, window close) discards the
    /// session and its staged files. Nothing orphans into the project.
    public func editorDismissed() {
        guard editingCard != nil else { return }
        cancelEditing()
        assetStore?.discardStaging()
    }

    // MARK: - External Reconciliation (Slice 3)

    /// Snapshot deferred while a gesture or the editor session is active.
    private var pendingExternalCards: [VisionCard]?

    /// Adopts a cards snapshot that changed OUTSIDE the board (assistant
    /// actions, project reload). Echoes of our own commits are suppressed;
    /// snapshots arriving mid-gesture or mid-edit apply at session end; a
    /// local commit drops any pending snapshot (last writer wins — this is
    /// a single-user app).
    public func reconcileExternalCards(_ newCards: [VisionCard]) {
        guard newCards != cards else { return }
        guard !interactionInProgress else {
            pendingExternalCards = newCards
            return
        }
        setCards(newCards)
    }

    private func applyPendingExternalCards() {
        guard let pending = pendingExternalCards, !interactionInProgress else { return }
        pendingExternalCards = nil
        if pending != cards { setCards(pending) }
    }

    // MARK: - Bulk Operations

    /// Set all cards
    public func setCards(_ newCards: [VisionCard]) {
        cards = newCards
        // Clear invalid selections
        selectedCardIds = selectedCardIds.filter { id in
            cards.contains { $0.id == id }
        }
    }

    /// Clear all cards
    public func clearAllCards() {
        let removed = cards
        cards.removeAll()
        selectedCardIds.removeAll()
        cleanupAssets(for: removed)
        notifyChange()
    }

    // MARK: - Private Helpers

    private func notifyChange() {
        // A local commit supersedes any snapshot that arrived mid-session.
        pendingExternalCards = nil
        onCardsChanged?(cards)
    }
}

// MARK: - Vision Card Type Enum

public enum VisionCardType: String, CaseIterable, Identifiable {
    case image = "image"
    case text = "text"
    case colorPalette = "color_palette"
    case video = "video"
    case texture = "texture"
    case lighting = "lighting"
    case location = "location"
    case frame = "frame"
    case shotStrip = "shot_strip"
    case link = "link"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .link: return "Link"
        case .image: return "Image"
        case .text: return "Text"
        case .colorPalette: return "Color Palette"
        case .video: return "Video"
        case .texture: return "Texture"
        case .lighting: return "Lighting"
        case .location: return "Location"
        case .frame: return "Frame"
        case .shotStrip: return "Shot Strip"
        }
    }

    public var systemImage: String {
        switch self {
        case .link: return "link"
        case .image: return "photo"
        case .text: return "textformat"
        case .colorPalette: return "paintpalette"
        case .video: return "video"
        case .texture: return "square.grid.3x3"
        case .lighting: return "lightbulb"
        case .location: return "mappin"
        case .frame: return "rectangle.dashed"
        case .shotStrip: return "film.stack"
        }
    }
}

// MARK: - Vision Department Enum

public enum VisionDepartment: String, CaseIterable, Identifiable {
    case cinematography = "cinematography"
    case productionDesign = "production_design"
    case costume = "costume"
    case makeup = "makeup"
    case lighting = "lighting"
    case vfx = "vfx"
    case sound = "sound"
    case general = "general"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cinematography: return "Cinematography"
        case .productionDesign: return "Production Design"
        case .costume: return "Costume"
        case .makeup: return "Makeup"
        case .lighting: return "Lighting"
        case .vfx: return "VFX"
        case .sound: return "Sound"
        case .general: return "General"
        }
    }
}
