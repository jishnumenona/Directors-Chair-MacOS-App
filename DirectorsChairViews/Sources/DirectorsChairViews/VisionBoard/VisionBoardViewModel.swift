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

    /// Current zoom level (1.0 = 100%)
    @Published public var zoomLevel: CGFloat = 1.0

    /// Canvas offset for panning
    @Published public var canvasOffset: CGPoint = .zero

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

        // Set default position if not specified
        if newCard.canvasX == nil {
            newCard.canvasX = Double(-canvasOffset.x / zoomLevel + 100)
        }
        if newCard.canvasY == nil {
            newCard.canvasY = Double(-canvasOffset.y / zoomLevel + 100)
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

    // MARK: - Zoom Operations

    /// Zoom in by step
    public func zoomIn() {
        zoomLevel = min(Self.maxZoom, zoomLevel + Self.zoomStep)
    }

    /// Zoom out by step
    public func zoomOut() {
        zoomLevel = max(Self.minZoom, zoomLevel - Self.zoomStep)
    }

    /// Reset zoom to 100%
    public func resetZoom() {
        zoomLevel = 1.0
    }

    /// Fit all cards in view
    public func fitToView(viewSize: CGSize) {
        guard !filteredCards.isEmpty else {
            resetZoom()
            canvasOffset = .zero
            return
        }

        // Calculate bounding box of all cards
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        for card in filteredCards {
            let x = card.canvasX ?? 0
            let y = card.canvasY ?? 0
            let w = card.canvasWidth ?? Self.defaultCardWidth
            let h = card.canvasHeight ?? Self.defaultCardHeight

            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x + w)
            maxY = max(maxY, y + h)
        }

        let contentWidth = maxX - minX + 100  // Add padding
        let contentHeight = maxY - minY + 100

        // Calculate zoom to fit
        let zoomX = viewSize.width / CGFloat(contentWidth)
        let zoomY = viewSize.height / CGFloat(contentHeight)
        zoomLevel = min(min(zoomX, zoomY), 1.0)  // Don't zoom above 100%

        // Center the content
        canvasOffset = CGPoint(
            x: -CGFloat(minX - 50) * zoomLevel,
            y: -CGFloat(minY - 50) * zoomLevel
        )
    }

    // MARK: - Board Operations

    /// Switch to a different board
    public func switchBoard(_ boardId: String) {
        currentBoardId = boardId
        clearSelection()
        resetZoom()
        canvasOffset = .zero
    }

    /// Create a new board
    public func createBoard(_ name: String) -> String {
        let boardId = name.lowercased().replacingOccurrences(of: " ", with: "_")
        currentBoardId = boardId
        return boardId
    }

    // MARK: - Card Editor

    /// Open editor for a new card
    public func createNewCard(type: VisionCardType = .image) {
        var card = VisionCard()
        card.cardType = type.rawValue
        card.boardId = currentBoardId
        card.canvasX = Double(-canvasOffset.x / zoomLevel + 100)
        card.canvasY = Double(-canvasOffset.y / zoomLevel + 100)
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

    /// Save edited card
    public func saveEditedCard() {
        guard let card = editingCard else { return }

        if cards.contains(where: { $0.id == card.id }) {
            updateCard(card)
        } else {
            addCard(card)
        }

        editingCard = nil
        showingCardEditor = false
    }

    /// Cancel editing
    public func cancelEditing() {
        editingCard = nil
        showingCardEditor = false
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
