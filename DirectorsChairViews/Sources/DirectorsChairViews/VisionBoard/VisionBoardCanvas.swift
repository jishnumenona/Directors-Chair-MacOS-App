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
    @State private var isPanning: Bool = false
    @State private var lastPanLocation: CGPoint = .zero
    @State private var magnification: CGFloat = 1.0

    // MARK: - Constants

    private static let canvasSize: CGFloat = 10000  // 10000x10000 virtual canvas
    private static let dotGridSpacing: CGFloat = 40
    private static let dotSize: CGFloat = 2

    // MARK: - Init

    public init(
        viewModel: VisionBoardViewModel,
        onCardEdit: ((VisionCard) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onCardEdit = onCardEdit
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with dot grid
                canvasBackground
                    .frame(
                        width: Self.canvasSize * viewModel.zoomLevel,
                        height: Self.canvasSize * viewModel.zoomLevel
                    )

                // Cards layer
                cardsLayer
                    .frame(
                        width: Self.canvasSize * viewModel.zoomLevel,
                        height: Self.canvasSize * viewModel.zoomLevel
                    )

                // Selection rectangle (if multi-selecting)
                // TODO: Add rubber-band selection
            }
            .offset(x: viewModel.canvasOffset.x, y: viewModel.canvasOffset.y)
            // Use simultaneousGesture to not block other event handlers
            .simultaneousGesture(panGesture)
            .simultaneousGesture(magnificationGesture)
            // Use high priority gesture for tap to not interfere with parent views
            .onTapGesture {
                // Click on empty space clears selection
                viewModel.clearSelection()
            }
            .clipped()
            // Limit hit testing to actual visible content
            .contentShape(Rectangle())
            .onAppear {
                viewSize = geometry.size
                // Center the canvas initially
                viewModel.canvasOffset = CGPoint(
                    x: geometry.size.width / 2 - (Self.canvasSize * viewModel.zoomLevel) / 2,
                    y: geometry.size.height / 2 - (Self.canvasSize * viewModel.zoomLevel) / 2
                )
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
        }
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - Canvas Background with Dot Grid

    @ViewBuilder
    private var canvasBackground: some View {
        Canvas { context, size in
            // Fill background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(hex: "#1E1E1E"))
            )

            // Draw dot grid
            let spacing = Self.dotGridSpacing * viewModel.zoomLevel
            let dotRadius = Self.dotSize * viewModel.zoomLevel / 2

            // Only draw visible dots (viewport culling)
            let visibleStartX = max(0, -viewModel.canvasOffset.x - spacing)
            let visibleStartY = max(0, -viewModel.canvasOffset.y - spacing)
            let visibleEndX = min(size.width, -viewModel.canvasOffset.x + viewSize.width + spacing)
            let visibleEndY = min(size.height, -viewModel.canvasOffset.y + viewSize.height + spacing)

            // Align to grid
            let startX = (visibleStartX / spacing).rounded(.down) * spacing
            let startY = (visibleStartY / spacing).rounded(.down) * spacing

            for x in stride(from: startX, to: visibleEndX, by: spacing) {
                for y in stride(from: startY, to: visibleEndY, by: spacing) {
                    let dotRect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(Color(hex: "#3A3A3A"))
                    )
                }
            }

            // Draw center crosshair
            let centerX = size.width / 2
            let centerY = size.height / 2
            let crosshairLength: CGFloat = 20 * viewModel.zoomLevel

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: centerX - crosshairLength, y: centerY))
                    path.addLine(to: CGPoint(x: centerX + crosshairLength, y: centerY))
                },
                with: .color(Color(hex: "#4A4A4A")),
                lineWidth: 1
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: centerY - crosshairLength))
                    path.addLine(to: CGPoint(x: centerX, y: centerY + crosshairLength))
                },
                with: .color(Color(hex: "#4A4A4A")),
                lineWidth: 1
            )
        }
    }

    // MARK: - Cards Layer

    @ViewBuilder
    private var cardsLayer: some View {
        ZStack {
            ForEach(viewModel.filteredCards) { card in
                VisionCardItem(
                    card: card,
                    isSelected: viewModel.selectedCardIds.contains(card.id),
                    zoomLevel: viewModel.zoomLevel,
                    showLabel: viewModel.showLabels,
                    onSelect: { addToSelection in
                        if addToSelection {
                            viewModel.toggleCardSelection(card.id)
                        } else {
                            viewModel.selectCard(card.id)
                        }
                    },
                    onDoubleClick: {
                        onCardEdit?(card)
                    },
                    onDrag: { newPosition in
                        // If multiple cards selected, move all of them
                        if viewModel.selectedCardIds.contains(card.id) && viewModel.selectedCardIds.count > 1 {
                            let deltaX = Double(newPosition.x) - (card.canvasX ?? 0)
                            let deltaY = Double(newPosition.y) - (card.canvasY ?? 0)
                            viewModel.moveSelectedCards(deltaX: deltaX, deltaY: deltaY)
                        } else {
                            viewModel.updateCardPosition(
                                card.id,
                                x: Double(newPosition.x),
                                y: Double(newPosition.y)
                            )
                        }
                    },
                    onDragEnd: {
                        // Position finalized
                    },
                    onResize: { newSize in
                        viewModel.updateCardSize(
                            card.id,
                            width: Double(newSize.width),
                            height: Double(newSize.height)
                        )
                    },
                    onResizeEnd: {
                        // Size finalized
                    }
                )
                // Position is handled inside VisionCardItem
            }
        }
        // Offset to account for card positions being from canvas origin (center)
        .offset(
            x: Self.canvasSize * viewModel.zoomLevel / 2,
            y: Self.canvasSize * viewModel.zoomLevel / 2
        )
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only pan if clicking on empty space (not on a card)
                if !isPanning {
                    isPanning = true
                    lastPanLocation = value.startLocation
                }

                let delta = CGPoint(
                    x: value.location.x - lastPanLocation.x,
                    y: value.location.y - lastPanLocation.y
                )

                viewModel.canvasOffset = CGPoint(
                    x: viewModel.canvasOffset.x + delta.x,
                    y: viewModel.canvasOffset.y + delta.y
                )

                lastPanLocation = value.location
            }
            .onEnded { _ in
                isPanning = false
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / magnification
                magnification = value

                // Calculate new zoom level
                let newZoom = viewModel.zoomLevel * delta
                let clampedZoom = max(
                    VisionBoardViewModel.minZoom,
                    min(VisionBoardViewModel.maxZoom, newZoom)
                )

                // Zoom toward center of view
                let zoomRatio = clampedZoom / viewModel.zoomLevel

                // Adjust offset to zoom toward center
                let centerX = viewSize.width / 2
                let centerY = viewSize.height / 2

                let newOffsetX = centerX - (centerX - viewModel.canvasOffset.x) * zoomRatio
                let newOffsetY = centerY - (centerY - viewModel.canvasOffset.y) * zoomRatio

                viewModel.zoomLevel = clampedZoom
                viewModel.canvasOffset = CGPoint(x: newOffsetX, y: newOffsetY)
            }
            .onEnded { _ in
                magnification = 1.0
            }
    }
}

// MARK: - Canvas Text Field

/// Resizable text field for the canvas (used for standalone text items)
public struct CanvasTextField: View {
    @Binding public var text: String
    public var font: Font = .body
    public var textColor: Color = .white
    public var backgroundColor: Color = .clear
    public var isEditing: Bool = false

    public var body: some View {
        if isEditing {
            TextEditor(text: $text)
                .font(font)
                .foregroundColor(textColor)
                .scrollContentBackground(.hidden)
                .background(backgroundColor.opacity(0.1))
                .cornerRadius(4)
        } else {
            Text(text)
                .font(font)
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Canvas Box

/// Border-only box for grouping items on the canvas
public struct CanvasBox: View {
    public var width: CGFloat
    public var height: CGFloat
    public var borderColor: Color = .gray
    public var borderWidth: CGFloat = 2
    public var label: String?

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(borderColor, lineWidth: borderWidth)
                .frame(width: width, height: height)

            if let label = label, !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundColor(borderColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#1E1E1E"))
                    .offset(x: 12, y: -10)
            }
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
