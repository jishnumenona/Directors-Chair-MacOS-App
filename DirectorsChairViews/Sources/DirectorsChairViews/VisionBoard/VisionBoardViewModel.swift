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

    /// Whether the canvas is in fullscreen mode
    @Published public var isFullscreen: Bool = false

    /// Current filter by card type
    @Published public var filterByType: VisionCardType?

    /// Current filter by department
    @Published public var filterByDepartment: String?

    /// Search query for filtering cards
    @Published public var searchQuery: String = ""

    /// Whether grid snapping is enabled
    @Published public var gridSnapEnabled: Bool = true

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

    @Published public var editingCard: VisionCard?

    /// Show card editor sheet
    @Published public var showingCardEditor: Bool = false

    // MARK: - Callbacks

    /// Callback when cards change (for persistence)
    public var onCardsChanged: (([VisionCard]) -> Void)?

    /// Callback for AI image generation
    public var onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)?

    // MARK: - Constants

    public static let minZoom: CGFloat = 0.1
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

        // Sort by z-order (lower values first, higher on top)
        return result.sorted { $0.zOrder < $1.zOrder }
    }

    /// Available boards in the project
    public var boardIds: [String] {
        let ids = Set(cards.map { $0.boardId })
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

    public init(cards: [VisionCard] = []) {
        self.cards = cards
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
        cards.removeAll { $0.id == cardId }
        selectedCardIds.remove(cardId)
        notifyChange()
    }

    /// Remove selected cards
    public func removeSelectedCards() {
        cards.removeAll { selectedCardIds.contains($0.id) }
        selectedCardIds.removeAll()
        notifyChange()
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

    /// Clear all selection
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

    /// Captures the whole selection's origins so multi-drag stays rigid.
    public func beginCardDrag(anchor cardId: String) {
        dragSessionAnchorId = cardId
        let ids = selectedCardIds.contains(cardId) ? selectedCardIds : [cardId]
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
        guard let card = cards.first(where: { $0.id == cardId }) else { return }
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
        setZoom(min(Self.maxZoom, zoomLevel + Self.zoomStep))
    }

    /// Zoom out by step
    public func zoomOut() {
        setZoom(max(Self.minZoom, zoomLevel - Self.zoomStep))
    }

    /// Reset zoom to 100%
    public func resetZoom() {
        setZoom(1.0)
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

    /// Create a new board
    public func createBoard(_ name: String) -> String {
        let boardId = name.lowercased().replacingOccurrences(of: " ", with: "_")
        currentBoardId = boardId
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
        var origin = VisionCanvasGeometry.placement(
            for: size, avoiding: existing, preferredOrigin: preferred)
        if gridSnapEnabled {
            origin.x = (origin.x / gridSnapSize).rounded() * gridSnapSize
            origin.y = (origin.y / gridSnapSize).rounded() * gridSnapSize
        }
        return origin
    }

    /// Open editor for a new card
    public func createNewCard(type: VisionCardType = .image) {
        var card = VisionCard()
        card.cardType = type.rawValue
        card.boardId = currentBoardId
        let origin = defaultPlacement(
            for: CGSize(width: Self.defaultCardWidth, height: Self.defaultCardHeight))
        card.canvasX = origin.x
        card.canvasY = origin.y
        card.canvasWidth = Double(Self.defaultCardWidth)
        card.canvasHeight = Double(Self.defaultCardHeight)
        card.zOrder = maxZOrder + 1

        editingCard = card
        showingCardEditor = true
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
            return
        }
        if assetStore?.projectBase != projectBase {
            assetStore = VisionBoardAssetStore(projectBase: projectBase)
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
        cards.removeAll()
        selectedCardIds.removeAll()
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

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .image: return "Image"
        case .text: return "Text"
        case .colorPalette: return "Color Palette"
        case .video: return "Video"
        case .texture: return "Texture"
        case .lighting: return "Lighting"
        case .location: return "Location"
        }
    }

    public var systemImage: String {
        switch self {
        case .image: return "photo"
        case .text: return "textformat"
        case .colorPalette: return "paintpalette"
        case .video: return "video"
        case .texture: return "square.grid.3x3"
        case .lighting: return "lightbulb"
        case .location: return "mappin"
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
