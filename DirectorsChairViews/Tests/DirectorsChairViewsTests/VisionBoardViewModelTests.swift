// VisionBoardViewModelTests.swift
// Tests for VisionBoardViewModel: card CRUD, selection, filtering, zoom, z-order, boards

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

@MainActor
final class VisionBoardViewModelTests: XCTestCase {

    var viewModel: VisionBoardViewModel!

    override func setUp() {
        super.setUp()
        viewModel = VisionBoardViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeCard(title: String = "Test Card", type: String = "image", boardId: String = "master") -> VisionCard {
        var card = VisionCard()
        card.title = title
        card.cardType = type
        card.boardId = boardId
        return card
    }



    // MARK: - Card CRUD

    func testAddCard() {
        let card = makeCard(title: "New Card")
        viewModel.addCard(card)

        XCTAssertEqual(viewModel.cards.count, 1)
        XCTAssertEqual(viewModel.cards.first?.title, "New Card")
    }

    func testAddCardSetsBoardId() {
        viewModel.currentBoardId = "storyboard"
        let card = makeCard()
        viewModel.addCard(card)

        XCTAssertEqual(viewModel.cards.first?.boardId, "storyboard")
    }

    func testAddCardSetsDefaultPosition() {
        var card = makeCard()
        card.canvasX = nil
        card.canvasY = nil
        viewModel.addCard(card)

        XCTAssertNotNil(viewModel.cards.first?.canvasX)
        XCTAssertNotNil(viewModel.cards.first?.canvasY)
    }

    func testAddCardSetsDefaultSize() {
        var card = makeCard()
        card.canvasWidth = nil
        card.canvasHeight = nil
        viewModel.addCard(card)

        XCTAssertNotNil(viewModel.cards.first?.canvasWidth)
        XCTAssertNotNil(viewModel.cards.first?.canvasHeight)
    }

    func testAddCardSetsZOrder() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))

        let zOrders = viewModel.cards.map { $0.zOrder }
        XCTAssertEqual(zOrders.count, 2)
        XCTAssertGreaterThan(zOrders[1], zOrders[0], "Later card should be on top")
    }

    func testUpdateCard() {
        var card = makeCard(title: "Original")
        viewModel.addCard(card)

        let id = viewModel.cards.first!.id
        var updated = viewModel.cards.first!
        updated.title = "Updated"
        viewModel.updateCard(updated)

        XCTAssertEqual(viewModel.cards.first?.title, "Updated")
        XCTAssertEqual(viewModel.cards.first?.id, id)
    }

    func testRemoveCard() {
        let card = makeCard()
        viewModel.addCard(card)
        let id = viewModel.cards.first!.id

        viewModel.removeCard(id)
        XCTAssertTrue(viewModel.cards.isEmpty)
    }

    func testRemoveCardClearsSelection() {
        let card = makeCard()
        viewModel.addCard(card)
        let id = viewModel.cards.first!.id
        viewModel.selectCard(id)

        viewModel.removeCard(id)
        XCTAssertFalse(viewModel.selectedCardIds.contains(id))
    }

    func testRemoveSelectedCards() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))
        viewModel.addCard(makeCard(title: "C"))

        let ids = viewModel.cards.map { $0.id }
        viewModel.selectCard(ids[0])
        viewModel.selectCard(ids[1], addToSelection: true)

        viewModel.removeSelectedCards()
        XCTAssertEqual(viewModel.cards.count, 1)
        XCTAssertEqual(viewModel.cards.first?.title, "C")
    }

    func testDuplicateSelectedCards() {
        let card = makeCard(title: "Original")
        viewModel.addCard(card)
        let originalId = viewModel.cards.first!.id
        viewModel.selectCard(originalId)

        viewModel.duplicateSelectedCards()

        XCTAssertEqual(viewModel.cards.count, 2)
        XCTAssertNotEqual(viewModel.cards[0].id, viewModel.cards[1].id)
        // The duplicate should be offset
        let originalX = viewModel.cards[0].canvasX ?? 0
        let duplicateX = viewModel.cards[1].canvasX ?? 0
        XCTAssertNotEqual(originalX, duplicateX)
    }

    // MARK: - Selection

    func testSelectCard() {
        viewModel.addCard(makeCard())
        let id = viewModel.cards.first!.id

        viewModel.selectCard(id)
        XCTAssertEqual(viewModel.selectedCardIds, [id])
    }

    func testSelectCardReplacesSelection() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))
        let ids = viewModel.cards.map { $0.id }

        viewModel.selectCard(ids[0])
        viewModel.selectCard(ids[1])

        XCTAssertEqual(viewModel.selectedCardIds, [ids[1]])
    }

    func testSelectCardAddToSelection() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))
        let ids = viewModel.cards.map { $0.id }

        viewModel.selectCard(ids[0])
        viewModel.selectCard(ids[1], addToSelection: true)

        XCTAssertEqual(viewModel.selectedCardIds, Set(ids))
    }

    func testDeselectCard() {
        viewModel.addCard(makeCard())
        let id = viewModel.cards.first!.id
        viewModel.selectCard(id)

        viewModel.deselectCard(id)
        XCTAssertTrue(viewModel.selectedCardIds.isEmpty)
    }

    func testToggleCardSelection() {
        viewModel.addCard(makeCard())
        let id = viewModel.cards.first!.id

        viewModel.toggleCardSelection(id)
        XCTAssertTrue(viewModel.selectedCardIds.contains(id))

        viewModel.toggleCardSelection(id)
        XCTAssertFalse(viewModel.selectedCardIds.contains(id))
    }

    func testClearSelection() {
        viewModel.addCard(makeCard())
        viewModel.selectCard(viewModel.cards.first!.id)

        viewModel.clearSelection()
        XCTAssertTrue(viewModel.selectedCardIds.isEmpty)
    }

    func testSelectAllCards() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))
        viewModel.addCard(makeCard(title: "C"))

        viewModel.selectAllCards()
        XCTAssertEqual(viewModel.selectedCardIds.count, 3)
    }

    // MARK: - Filtering

    func testFilterByType() {
        viewModel.addCard(makeCard(type: "image"))
        viewModel.addCard(makeCard(type: "text"))
        viewModel.addCard(makeCard(type: "image"))

        viewModel.filterByType = .image
        XCTAssertEqual(viewModel.filteredCards.count, 2)

        viewModel.filterByType = .text
        XCTAssertEqual(viewModel.filteredCards.count, 1)
    }

    func testFilterByDepartment() {
        var card1 = makeCard(title: "A")
        card1.department = "cinematography"
        var card2 = makeCard(title: "B")
        card2.department = "costume"

        viewModel.addCard(card1)
        viewModel.addCard(card2)

        viewModel.filterByDepartment = "cinematography"
        XCTAssertEqual(viewModel.filteredCards.count, 1)
        XCTAssertEqual(viewModel.filteredCards.first?.title, "A")
    }

    func testFilterBySearchQuery() {
        viewModel.addCard(makeCard(title: "Hero Shot"))
        viewModel.addCard(makeCard(title: "Wide Angle"))

        viewModel.searchQuery = "Hero"
        XCTAssertEqual(viewModel.filteredCards.count, 1)
        XCTAssertEqual(viewModel.filteredCards.first?.title, "Hero Shot")
    }

    func testFilterByBoardId() {
        viewModel.addCard(makeCard(title: "Board A", boardId: "master"))
        var cardB = makeCard(title: "Board B")
        cardB.boardId = "storyboard"
        viewModel.cards.append(cardB)

        viewModel.currentBoardId = "master"
        XCTAssertEqual(viewModel.filteredCards.count, 1)

        viewModel.currentBoardId = "storyboard"
        XCTAssertEqual(viewModel.filteredCards.count, 1)
    }

    // MARK: - Z-Order

    func testBringToFront() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))
        let ids = viewModel.cards.map { $0.id }

        viewModel.selectCard(ids[0])
        viewModel.bringToFront()

        let cardA = viewModel.cards.first { $0.id == ids[0] }!
        let cardB = viewModel.cards.first { $0.id == ids[1] }!
        XCTAssertGreaterThan(cardA.zOrder, cardB.zOrder)
    }

    func testSendToBack() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))
        let ids = viewModel.cards.map { $0.id }

        viewModel.selectCard(ids[1])
        viewModel.sendToBack()

        let cardA = viewModel.cards.first { $0.id == ids[0] }!
        let cardB = viewModel.cards.first { $0.id == ids[1] }!
        XCTAssertLessThan(cardB.zOrder, cardA.zOrder)
    }

    // MARK: - Position & Size

    func testUpdateCardPosition() {
        viewModel.gridSnapEnabled = false
        viewModel.addCard(makeCard())
        let id = viewModel.cards.first!.id

        viewModel.updateCardPosition(id, x: 100, y: 200)

        XCTAssertEqual(viewModel.cards.first?.canvasX, 100)
        XCTAssertEqual(viewModel.cards.first?.canvasY, 200)
    }

    func testUpdateCardPositionWithGridSnap() {
        viewModel.gridSnapEnabled = true
        viewModel.gridSnapSize = 20
        viewModel.addCard(makeCard())
        let id = viewModel.cards.first!.id

        viewModel.updateCardPosition(id, x: 105, y: 213)

        XCTAssertEqual(viewModel.cards.first?.canvasX, 100) // Snapped to 20 grid
        XCTAssertEqual(viewModel.cards.first?.canvasY, 220) // Snapped to 20 grid
    }

    func testUpdateCardSizeEnforcesMinimum() {
        viewModel.gridSnapEnabled = false
        viewModel.addCard(makeCard())
        let id = viewModel.cards.first!.id

        viewModel.updateCardSize(id, width: 50, height: 30)

        XCTAssertGreaterThanOrEqual(viewModel.cards.first!.canvasWidth!, 100)
        XCTAssertGreaterThanOrEqual(viewModel.cards.first!.canvasHeight!, 80)
    }

    func testMoveSelectedCards() {
        viewModel.gridSnapEnabled = false
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))

        // Set known positions
        viewModel.cards[0].canvasX = 100
        viewModel.cards[0].canvasY = 100
        viewModel.cards[1].canvasX = 200
        viewModel.cards[1].canvasY = 200

        viewModel.selectAllCards()
        viewModel.moveSelectedCards(deltaX: 50, deltaY: -25)

        XCTAssertEqual(viewModel.cards[0].canvasX, 150)
        XCTAssertEqual(viewModel.cards[0].canvasY, 75)
        XCTAssertEqual(viewModel.cards[1].canvasX, 250)
        XCTAssertEqual(viewModel.cards[1].canvasY, 175)
    }

    // MARK: - Zoom

    func testZoomIn() {
        let originalZoom = viewModel.zoomLevel
        viewModel.zoomIn()
        XCTAssertGreaterThan(viewModel.zoomLevel, originalZoom)
    }

    func testZoomOut() {
        viewModel.zoomLevel = 2.0
        viewModel.zoomOut()
        XCTAssertLessThan(viewModel.zoomLevel, 2.0)
    }

    func testZoomInClampsToMax() {
        viewModel.zoomLevel = VisionBoardViewModel.maxZoom
        viewModel.zoomIn()
        XCTAssertEqual(viewModel.zoomLevel, VisionBoardViewModel.maxZoom)
    }

    func testZoomOutClampsToMin() {
        viewModel.zoomLevel = VisionBoardViewModel.minZoom
        viewModel.zoomOut()
        XCTAssertEqual(viewModel.zoomLevel, VisionBoardViewModel.minZoom)
    }

    func testResetZoom() {
        viewModel.zoomLevel = 3.0
        viewModel.resetZoom()
        XCTAssertEqual(viewModel.zoomLevel, 1.0)
    }

    // MARK: - Board Operations

    func testSwitchBoard() {
        viewModel.addCard(makeCard())
        viewModel.selectCard(viewModel.cards.first!.id)
        viewModel.zoomLevel = 2.0

        viewModel.switchBoard("storyboard")

        XCTAssertEqual(viewModel.currentBoardId, "storyboard")
        XCTAssertTrue(viewModel.selectedCardIds.isEmpty)
        XCTAssertEqual(viewModel.zoomLevel, 1.0)
    }

    func testCreateBoard() {
        let boardId = viewModel.createBoard("My Board")
        XCTAssertEqual(boardId, "my_board")
        XCTAssertEqual(viewModel.currentBoardId, "my_board")
    }

    // MARK: - Card Editor

    func testCreateNewCardOpensEditor() {
        viewModel.createNewCard(type: .image)

        XCTAssertTrue(viewModel.showingCardEditor)
        XCTAssertNotNil(viewModel.editingCard)
        XCTAssertEqual(viewModel.editingCard?.cardType, "image")
    }

    func testEditCardOpensEditor() {
        viewModel.addCard(makeCard(title: "Existing"))
        let card = viewModel.cards.first!

        viewModel.editCard(card)

        XCTAssertTrue(viewModel.showingCardEditor)
        XCTAssertEqual(viewModel.editingCard?.id, card.id)
    }

    func testSaveEditedCardUpdatesExisting() {
        viewModel.addCard(makeCard(title: "Original"))
        var card = viewModel.cards.first!
        card.title = "Edited"

        viewModel.editingCard = card
        viewModel.saveEditedCard()

        XCTAssertEqual(viewModel.cards.first?.title, "Edited")
        XCTAssertFalse(viewModel.showingCardEditor)
        XCTAssertNil(viewModel.editingCard)
    }

    func testCancelEditing() {
        viewModel.editingCard = makeCard()
        viewModel.showingCardEditor = true

        viewModel.cancelEditing()

        XCTAssertNil(viewModel.editingCard)
        XCTAssertFalse(viewModel.showingCardEditor)
    }

    // MARK: - Bulk Operations

    func testSetCards() {
        let cards = [makeCard(title: "A"), makeCard(title: "B")]
        viewModel.setCards(cards)
        XCTAssertEqual(viewModel.cards.count, 2)
    }

    func testSetCardsClearsInvalidSelections() {
        viewModel.addCard(makeCard())
        let oldId = viewModel.cards.first!.id
        viewModel.selectCard(oldId)

        viewModel.setCards([makeCard(title: "New")])

        XCTAssertFalse(viewModel.selectedCardIds.contains(oldId))
    }

    func testClearAllCards() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))
        viewModel.selectAllCards()

        viewModel.clearAllCards()

        XCTAssertTrue(viewModel.cards.isEmpty)
        XCTAssertTrue(viewModel.selectedCardIds.isEmpty)
    }

    // MARK: - Computed Properties

    func testMaxZOrder() {
        XCTAssertEqual(viewModel.maxZOrder, 0)

        viewModel.addCard(makeCard())
        viewModel.addCard(makeCard())

        XCTAssertGreaterThan(viewModel.maxZOrder, 0)
    }

    func testCardCount() {
        XCTAssertEqual(viewModel.cardCount, 0)

        viewModel.addCard(makeCard())
        viewModel.addCard(makeCard())

        XCTAssertEqual(viewModel.cardCount, 2)
    }

    func testSelectedCards() {
        viewModel.addCard(makeCard(title: "A"))
        viewModel.addCard(makeCard(title: "B"))

        viewModel.selectCard(viewModel.cards.first!.id)
        XCTAssertEqual(viewModel.selectedCards.count, 1)
        XCTAssertEqual(viewModel.selectedCards.first?.title, "A")
    }

    // MARK: - VisionCardType Enum

    func testVisionCardTypeAllCases() {
        XCTAssertEqual(VisionCardType.allCases.count, 7)
    }

    func testVisionCardTypeDisplayNames() {
        XCTAssertEqual(VisionCardType.image.displayName, "Image")
        XCTAssertEqual(VisionCardType.text.displayName, "Text")
        XCTAssertEqual(VisionCardType.colorPalette.displayName, "Color Palette")
    }

    func testVisionCardTypeSystemImages() {
        XCTAssertFalse(VisionCardType.image.systemImage.isEmpty)
        XCTAssertFalse(VisionCardType.video.systemImage.isEmpty)
    }

    // MARK: - VisionDepartment Enum

    func testVisionDepartmentAllCases() {
        XCTAssertEqual(VisionDepartment.allCases.count, 8)
    }

    func testVisionDepartmentDisplayNames() {
        XCTAssertEqual(VisionDepartment.cinematography.displayName, "Cinematography")
        XCTAssertEqual(VisionDepartment.costume.displayName, "Costume")
        XCTAssertEqual(VisionDepartment.vfx.displayName, "VFX")
    }

    // MARK: - Callback Notification

    func testOnCardsChangedCallback() {
        var callbackCards: [VisionCard]?
        viewModel.onCardsChanged = { cards in
            callbackCards = cards
        }

        viewModel.addCard(makeCard())
        XCTAssertNotNil(callbackCards)
        XCTAssertEqual(callbackCards?.count, 1)
    }
}
