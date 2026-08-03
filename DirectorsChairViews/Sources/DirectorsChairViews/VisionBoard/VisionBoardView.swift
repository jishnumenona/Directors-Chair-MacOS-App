// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardView.swift
//
// Vision Board View - Main Vision Board Interface
// Pinterest/Milanote-style mood board for visual pre-production planning.

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Vision Board View

public struct VisionBoardView: View {
    // MARK: - Properties

    @StateObject private var viewModel: VisionBoardViewModel

    /// The project's cards as the host currently knows them (Slice 3):
    /// seeds the view model once, then feeds external reconciliation so
    /// assistant actions and project reloads show up on an open board.
    public var cards: [VisionCard]

    /// Callback when vision cards change (for persistence)
    public var onCardsChanged: (([VisionCard]) -> Void)?

    /// Callback when the board registry changes (Slice 4 persistence)
    public var onBoardsChanged: (([VisionBoardMeta]) -> Void)?

    /// Callback when connectors change (roadmap #5 persistence)
    public var onConnectorsChanged: (([VisionConnector]) -> Void)?

    /// Callback for AI image generation
    public var onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)?

    /// Project locations for the Location-card picker.
    public var locations: [Location]

    /// The project directory (Slice 2) — base for resolving relative image
    /// paths and home of the managed assets/visionboard/ folder. Nil when
    /// the project has never been saved to disk.
    public var projectBasePath: URL?

    // MARK: - State

    @State private var showingBoardPicker: Bool = false
    @State private var newBoardName: String = ""
    @State private var showingNewBoardAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var showingExportOptions: Bool = false
    @State private var exportError: String?
    @State private var connectorLabelDraft: String = ""


    // MARK: - Init

    public init(
        cards: [VisionCard] = [],
        boards: [VisionBoardMeta] = [],
        connectors: [VisionConnector] = [],
        onCardsChanged: (([VisionCard]) -> Void)? = nil,
        onBoardsChanged: (([VisionBoardMeta]) -> Void)? = nil,
        onConnectorsChanged: (([VisionConnector]) -> Void)? = nil,
        onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)? = nil,
        projectBasePath: URL? = nil,
        locations: [Location] = []
    ) {
        self._viewModel = StateObject(wrappedValue: VisionBoardViewModel(
            cards: cards, boards: boards, connectors: connectors))
        self.cards = cards
        self.onCardsChanged = onCardsChanged
        self.onBoardsChanged = onBoardsChanged
        self.onConnectorsChanged = onConnectorsChanged
        self.onGenerateImage = onGenerateImage
        self.projectBasePath = projectBasePath
        self.locations = locations
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Main canvas
            VisionBoardCanvas(
                viewModel: viewModel,
                onCardEdit: { card in
                    viewModel.editCard(card)
                }
            )

            // Floating toolbar at top
            VStack {
                toolbar
                Spacer()
            }

            // Zoom controls at bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    zoomControls
                        .foregroundStyle(VisionWallPalette.ink)
                        .environment(\.colorScheme, .light)
                }
            }
            .padding()

            // Infinite-canvas rescue: appears when every card is
            // off-screen and jumps back to the content.
            if !viewModel.contentVisible {
                VStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35,
                                              dampingFraction: 0.85)) {
                            viewModel.fitToView(viewSize: viewModel.viewportSize)
                        }
                    } label: {
                        Label("Back to content",
                              systemImage: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.accentColor))
                            .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 56)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }

            // Selection info at bottom left
            if !viewModel.selectedCardIds.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        selectionInfo
                            .foregroundStyle(VisionWallPalette.ink)
                            .environment(\.colorScheme, .light)
                        Spacer()
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $viewModel.showingCardEditor,
               onDismiss: { viewModel.editorDismissed() }) {
            if let card = viewModel.editingCard {
                VisionCardEditor(
                    card: Binding(
                        get: { viewModel.editingCard ?? card },
                        set: { viewModel.editingCard = $0 }
                    ),
                    isPresented: $viewModel.showingCardEditor,
                    onSave: {
                        viewModel.saveEditedCard()
                    },
                    onGenerateImage: onGenerateImage,
                    assetStore: viewModel.assetStore,
                    isNew: !viewModel.cards.contains { $0.id == card.id },
                    locations: locations
                )
            }
        }
        .onAppear {
            viewModel.configureAssetStore(projectBase: projectBasePath)
        }
        .onChange(of: projectBasePath) { _, newBase in
            viewModel.configureAssetStore(projectBase: newBase)
        }
        .onChange(of: cards) { _, newCards in
            viewModel.reconcileExternalCards(newCards)
        }
        .alert("Connector Label", isPresented: Binding(
            get: { viewModel.editingConnectorId != nil },
            set: { if !$0 { viewModel.editingConnectorId = nil } })) {
            TextField("Label", text: $connectorLabelDraft)
            Button("Save") {
                if let id = viewModel.editingConnectorId {
                    viewModel.setConnectorLabel(id, label: connectorLabelDraft)
                }
                viewModel.editingConnectorId = nil
                connectorLabelDraft = ""
            }
            Button("Cancel", role: .cancel) {
                viewModel.editingConnectorId = nil
                connectorLabelDraft = ""
            }
        } message: {
            Text("Name the relationship, e.g. \"this palette → night exteriors\"")
        }
        .onChange(of: viewModel.editingConnectorId) { _, id in
            connectorLabelDraft = viewModel.connectors
                .first { $0.id == id }?.label ?? ""
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .alert("New Board", isPresented: $showingNewBoardAlert) {
            TextField("Board name", text: $newBoardName)
            Button("Create") {
                if !newBoardName.isEmpty {
                    _ = viewModel.createBoard(newBoardName)
                    newBoardName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newBoardName = ""
            }
        }
        .alert("Delete Cards", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                viewModel.removeSelectedCards()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \(viewModel.selectedCardIds.count) selected card(s)?")
        }
        .onAppear {
            viewModel.onCardsChanged = onCardsChanged
            viewModel.onBoardsChanged = onBoardsChanged
            viewModel.onConnectorsChanged = onConnectorsChanged
            viewModel.onGenerateImage = onGenerateImage
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        // The Wall, pass 2: the board carried ~13 controls — an add-card
        // menu, search, type filter, department filter, labels, snap,
        // select-all, export. Everything that structured the wall is gone.
        // Capture is the drop/paste/type gesture, so there is no Add
        // button; filters belong to a database, not a wall. What's left is
        // which wall you're looking at, and how to get work off it.
        // Two small things resting ON the wall, not a chrome bar across
        // it. Paper-toned and forced light, because the wall is always
        // plaster — dark-mode chrome floating on it looked like the CAD
        // canvas we just removed.
        HStack(spacing: 12) {
            boardSelector
                .fixedSize()
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(wallPill)

            Spacer()

            actionButtons
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(wallPill)
        }
        .foregroundStyle(VisionWallPalette.ink)
        .tint(VisionWallPalette.greasePencil)
        .environment(\.colorScheme, .light)
        .padding()
    }

    /// A scrap of paper the controls sit on.
    private var wallPill: some View {
        Capsule()
            .fill(VisionWallPalette.clipping.opacity(0.93))
            .shadow(color: VisionWallPalette.scrapShadow, radius: 6, y: 2)
    }

    // MARK: - Board Selector

    @ViewBuilder
    private var boardSelector: some View {
        Menu {
            ForEach(viewModel.boardIds, id: \.self) { boardId in
                Button {
                    viewModel.switchBoard(boardId)
                } label: {
                    HStack {
                        Text(boardId.replacingOccurrences(of: "_", with: " ").capitalized)
                        if boardId == viewModel.currentBoardId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                showingNewBoardAlert = true
            } label: {
                Label("New Board...", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                Text(viewModel.currentBoardId.replacingOccurrences(of: "_", with: " ").capitalized)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#3A3A3A"))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .foregroundColor(.white)
    }

    // MARK: - Add Card Buttons

    @ViewBuilder
    private var addCardButtons: some View {
        Menu {
            ForEach(VisionCardType.allCases) { type in
                Button {
                    viewModel.createNewCard(type: type)
                } label: {
                    Label(type.displayName, systemImage: type.systemImage)
                }
            }
        } label: {
            Label("Add Card", systemImage: "plus.rectangle")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Filter Controls

    @ViewBuilder
    private var filterControls: some View {
        HStack(spacing: 8) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .frame(width: 120)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(6)

            // Type filter
            Menu {
                Button {
                    viewModel.filterByType = nil
                } label: {
                    HStack {
                        Text("All Types")
                        if viewModel.filterByType == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(VisionCardType.allCases) { type in
                    Button {
                        viewModel.filterByType = type
                    } label: {
                        HStack {
                            Label(type.displayName, systemImage: type.systemImage)
                            if viewModel.filterByType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.filterByType?.systemImage ?? "square.grid.2x2")
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.filterByType != nil ? Color.accentColor.opacity(0.3) : Color(hex: "#3A3A3A"))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .foregroundColor(.white)

            // Department filter
            if !viewModel.departments.isEmpty {
                Menu {
                    Button {
                        viewModel.filterByDepartment = nil
                    } label: {
                        HStack {
                            Text("All Departments")
                            if viewModel.filterByDepartment == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    ForEach(viewModel.departments, id: \.self) { dept in
                        Button {
                            viewModel.filterByDepartment = dept
                        } label: {
                            HStack {
                                Text(dept.replacingOccurrences(of: "_", with: " ").capitalized)
                                if viewModel.filterByDepartment == dept {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.filterByDepartment != nil ? Color.accentColor.opacity(0.3) : Color(hex: "#3A3A3A"))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .foregroundColor(.white)
            }
        }
    }

    // MARK: - View Options

    @ViewBuilder
    private var viewOptions: some View {
        HStack(spacing: 8) {
            // Show labels toggle
            Button {
                viewModel.showLabels.toggle()
            } label: {
                Image(systemName: viewModel.showLabels ? "tag.fill" : "tag")
            }
            .buttonStyle(.plain)
            .foregroundColor(viewModel.showLabels ? .accentColor : .gray)
            .help("Show/Hide Labels")

            // Grid snap toggle
            Button {
                viewModel.gridSnapEnabled.toggle()
            } label: {
                Image(systemName: viewModel.gridSnapEnabled ? "grid" : "grid.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(viewModel.gridSnapEnabled ? .accentColor : .gray)
            .help("Grid Snap")
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Select-all moved to ⌘A; the wall shows one tool.
            Button {
                showingExportOptions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help("Export")
            .popover(isPresented: $showingExportOptions) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Board")
                        .font(.headline)
                    Text("Renders every card on this board into one PNG.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Button("Export as PNG…") {
                        showingExportOptions = false
                        exportBoardPNG()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Export Lookbook as PDF…") {
                        showingExportOptions = false
                        exportLookbookPDF()
                    }
                    // Creator feature (Product-Versions §3.9). Fail-open:
                    // every account is .studio until billing, so no lock
                    // renders today — this exercises the gating pattern.
                    .requiresTier(.creator, feature: "Lookbook PDF export")
                }
                .padding()
                .frame(width: 240)
            }
        }
    }

    /// Roadmap #6: paginated per-section lookbook.
    private func exportLookbookPDF() {
        let boardCards = viewModel.cards.filter {
            $0.boardId == viewModel.currentBoardId
        }
        guard !boardCards.isEmpty else {
            exportError = "This board has no cards to export."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Lookbook-\(viewModel.currentBoardId).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = VisionBoardLookbook.renderPDF(
            cards: boardCards, projectBase: projectBasePath) else {
            exportError = "Could not render the lookbook."
            return
        }
        do {
            try data.write(to: url)
        } catch {
            exportError = "Could not save the PDF: \(error.localizedDescription)"
        }
    }

    private func exportBoardPNG() {
        let boardCards = viewModel.cards.filter {
            $0.boardId == viewModel.currentBoardId
        }
        guard !boardCards.isEmpty else {
            exportError = "This board has no cards to export."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "VisionBoard-\(viewModel.currentBoardId).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = VisionBoardExporter.renderPNG(
            cards: boardCards, projectBase: projectBasePath) else {
            exportError = "Could not render the board."
            return
        }
        do {
            try data.write(to: url)
        } catch {
            exportError = "Could not save the PNG: \(error.localizedDescription)"
        }
    }

    // MARK: - Zoom Controls

    @ViewBuilder
    private var zoomControls: some View {
        VStack(spacing: 4) {
            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(VisionWallPalette.clipping.opacity(0.93))
            .cornerRadius(4)

            Text("\(Int(viewModel.zoomLevel * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(VisionWallPalette.ink.opacity(0.55))

            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(VisionWallPalette.clipping.opacity(0.93))
            .cornerRadius(4)

            Divider()
                .frame(width: 20)

            Button {
                viewModel.resetZoom()
            } label: {
                Text("1:1")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(VisionWallPalette.clipping.opacity(0.93))
            .cornerRadius(4)
            .help("Reset to 100%")

            Button {
                viewModel.fitToView(viewSize: viewModel.viewportSize)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(VisionWallPalette.clipping.opacity(0.93))
            .cornerRadius(4)
            .help("Fit all cards in view")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VisionWallPalette.clipping.opacity(0.93))
        )
        .foregroundColor(VisionWallPalette.ink)
    }

    // MARK: - Selection Info

    @ViewBuilder
    private var selectionInfo: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.selectedCardIds.count) selected")
                .font(.caption)
                .foregroundColor(VisionWallPalette.ink)

            Divider()
                .frame(height: 16)

            Button {
                viewModel.duplicateSelectedCards()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(VisionWallPalette.ink)

            Button {
                viewModel.bringToFront()
            } label: {
                Label("Bring Front", systemImage: "square.3.layers.3d.top.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(VisionWallPalette.ink)

            Button {
                viewModel.sendToBack()
            } label: {
                Label("Send Back", systemImage: "square.3.layers.3d.bottom.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(VisionWallPalette.ink)

            Divider()
                .frame(height: 16)

            Button {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(VisionWallPalette.clipping.opacity(0.93).opacity(0.95))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct VisionBoardView_Previews: PreviewProvider {
    static var previews: some View {
        VisionBoardView(cards: [
            VisionCard(
                id: "1",
                title: "Hero Shot Reference",
                description: "Main character intro",
                cardType: "image",
                department: "cinematography",
                canvasX: 100,
                canvasY: 100,
                canvasWidth: 200,
                canvasHeight: 200
            ),
            VisionCard(
                id: "2",
                title: "Color Palette",
                cardType: "color_palette",
                colorPalette: ["#FF5733", "#33FF57", "#3357FF"],
                canvasX: 350,
                canvasY: 100,
                canvasWidth: 180,
                canvasHeight: 150
            )
        ])
        .frame(width: 1200, height: 800)
    }
}
#endif
