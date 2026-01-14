// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardView.swift
//
// Vision Board View - Main Vision Board Interface
// Pinterest/Milanote-style mood board for visual pre-production planning.

import SwiftUI
import DirectorsChairCore

// MARK: - Vision Board View

public struct VisionBoardView: View {
    // MARK: - Properties

    @StateObject private var viewModel: VisionBoardViewModel

    /// Callback when vision cards change (for persistence)
    public var onCardsChanged: (([VisionCard]) -> Void)?

    /// Callback for AI image generation
    public var onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)?

    // MARK: - State

    @State private var showingBoardPicker: Bool = false
    @State private var newBoardName: String = ""
    @State private var showingNewBoardAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var showingExportOptions: Bool = false

    // MARK: - Init

    public init(
        cards: [VisionCard] = [],
        onCardsChanged: (([VisionCard]) -> Void)? = nil,
        onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: VisionBoardViewModel(cards: cards))
        self.onCardsChanged = onCardsChanged
        self.onGenerateImage = onGenerateImage
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
                }
            }
            .padding()

            // Selection info at bottom left
            if !viewModel.selectedCardIds.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        selectionInfo
                        Spacer()
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $viewModel.showingCardEditor) {
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
                    onGenerateImage: onGenerateImage
                )
            }
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
            viewModel.onGenerateImage = onGenerateImage
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 12) {
            // Board selector
            boardSelector

            Divider()
                .frame(height: 24)

            // Add card buttons
            addCardButtons

            Divider()
                .frame(height: 24)

            // Filter controls
            filterControls

            Spacer()

            // View options
            viewOptions

            Divider()
                .frame(height: 24)

            // Actions
            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#2A2A2A").opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
        .padding()
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

            // Fullscreen
            Button {
                viewModel.isFullscreen.toggle()
            } label: {
                Image(systemName: viewModel.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help("Toggle Fullscreen")
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Select all
            Button {
                viewModel.selectAllCards()
            } label: {
                Image(systemName: "checkmark.square")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help("Select All")

            // Export
            Button {
                showingExportOptions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .help("Export")
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
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(4)

            Text("\(Int(viewModel.zoomLevel * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)

            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(Color(hex: "#2A2A2A"))
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
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(4)
            .help("Reset to 100%")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#1E1E1E").opacity(0.9))
        )
        .foregroundColor(.white)
    }

    // MARK: - Selection Info

    @ViewBuilder
    private var selectionInfo: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.selectedCardIds.count) selected")
                .font(.caption)
                .foregroundColor(.white)

            Divider()
                .frame(height: 16)

            Button {
                viewModel.duplicateSelectedCards()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

            Button {
                viewModel.bringToFront()
            } label: {
                Label("Bring Front", systemImage: "square.3.layers.3d.top.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

            Button {
                viewModel.sendToBack()
            } label: {
                Label("Send Back", systemImage: "square.3.layers.3d.bottom.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

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
                .fill(Color(hex: "#2A2A2A").opacity(0.95))
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
