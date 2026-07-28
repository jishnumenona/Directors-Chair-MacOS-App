// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionCardItem.swift
//
// Vision Card Item - Draggable, Resizable Card on Vision Board Canvas
// Renders different card types: image, text, color palette, video, etc.

import SwiftUI
import DirectorsChairCore

// MARK: - Vision Card Item View

public struct VisionCardItem: View {
    // MARK: - Properties

    public let card: VisionCard
    public let isSelected: Bool
    public let zoomLevel: CGFloat
    public let showLabel: Bool
    /// Named coordinate space of the canvas container — drag translations
    /// arrive in unscaled screen points so the VM's `translation / zoom`
    /// math is exact (Slice 1).
    public var canvasSpaceName: String = "visionCanvas"

    /// Base for resolving project-relative image paths (Slice 2); nil
    /// means only legacy absolute paths can load.
    public var projectBase: URL?

    // Callbacks — raw gesture phases; ALL math lives in the view model's
    // anchored sessions (Slice 1).
    public var onSelect: ((Bool) -> Void)?  // Bool = add to selection (shift-click)
    public var onDoubleClick: (() -> Void)?
    public var onDuplicate: (() -> Void)?
    public var onDelete: (() -> Void)?
    public var onDragBegan: (() -> Void)?
    public var onDragChanged: ((CGSize) -> Void)?
    public var onDragEnded: ((CGSize) -> Void)?
    public var onResizeBegan: ((ResizeCorner) -> Void)?
    public var onResizeChanged: ((CGSize) -> Void)?
    public var onResizeEnded: ((CGSize) -> Void)?

    // MARK: - State

    @State private var isDragging: Bool = false
    @State private var isResizing: Bool = false
    @State private var isHovering: Bool = false
    @State private var loadedImage: NSImage?
    @State private var imageLoadFailed: Bool = false

    // MARK: - Computed Properties

    private var cardWidth: CGFloat {
        CGFloat(card.canvasWidth ?? 200)
    }

    private var cardHeight: CGFloat {
        CGFloat(card.canvasHeight ?? 200)
    }

    private var cardPosition: CGPoint {
        CGPoint(
            x: CGFloat(card.canvasX ?? 0),
            y: CGFloat(card.canvasY ?? 0)
        )
    }

    private var cardType: VisionCardType {
        VisionCardType(rawValue: card.cardType) ?? .image
    }

    // MARK: - Init

    public init(
        card: VisionCard,
        isSelected: Bool = false,
        zoomLevel: CGFloat = 1.0,
        showLabel: Bool = true,
        canvasSpaceName: String = "visionCanvas",
        projectBase: URL? = nil,
        onSelect: ((Bool) -> Void)? = nil,
        onDoubleClick: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onDragBegan: (() -> Void)? = nil,
        onDragChanged: ((CGSize) -> Void)? = nil,
        onDragEnded: ((CGSize) -> Void)? = nil,
        onResizeBegan: ((ResizeCorner) -> Void)? = nil,
        onResizeChanged: ((CGSize) -> Void)? = nil,
        onResizeEnded: ((CGSize) -> Void)? = nil
    ) {
        self.card = card
        self.isSelected = isSelected
        self.zoomLevel = zoomLevel
        self.showLabel = showLabel
        self.canvasSpaceName = canvasSpaceName
        self.projectBase = projectBase
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onDragBegan = onDragBegan
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onResizeBegan = onResizeBegan
        self.onResizeChanged = onResizeChanged
        self.onResizeEnded = onResizeEnded
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Main card content
            cardContent
                .frame(width: cardWidth, height: cardHeight)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contextMenu {
                    Button {
                        onDoubleClick?()
                    } label: {
                        Label("Edit Card", systemImage: "pencil")
                    }
                    Button {
                        onDuplicate?()
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete Card", systemImage: "trash")
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.2),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: 2
                )

            // Resize handles (visible when selected)
            if isSelected {
                resizeHandles
            }

            // Label overlay at bottom. Text cards ARE their text — the
            // poster face already shows it, so no duplicate footer label.
            if showLabel && !card.title.isEmpty && cardType != .text {
                labelOverlay
            }

            // Pinned indicator
            if card.pinned {
                pinnedIndicator
            }
        }
        // World coordinates only — the cards layer applies zoom+offset once.
        .position(x: cardPosition.x + cardWidth / 2, y: cardPosition.y + cardHeight / 2)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .onTapGesture {
            onSelect?(NSEvent.modifierFlags.contains(.shift))
        }
        .gesture(dragGesture)
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: card.imagePath) { _, _ in
            loadImageIfNeeded()
        }
        .onChange(of: projectBase) { _, _ in
            // The base lands AFTER first appear (the hosting view's
            // onAppear configures it) — retry the resolve.
            loadImageIfNeeded()
        }
    }

    // MARK: - Card Content by Type

    @ViewBuilder
    private var cardContent: some View {
        switch cardType {
        case .image:
            imageCardContent
        case .text:
            textCardContent
        case .colorPalette:
            colorPaletteContent
        case .video:
            videoCardContent
        case .texture:
            textureCardContent
        case .lighting:
            lightingCardContent
        case .location:
            locationCardContent
        }
    }

    // MARK: - Image Card

    @ViewBuilder
    private var imageCardContent: some View {
        if let image = loadedImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
        } else if case .remote = VisionImageRef.classify(card.imagePath) {
            // Remote refs are never fetched while rendering (Slice 2) —
            // static placeholder instead of the old forever-spinner.
            ZStack {
                Color(hex: "#2A2A2A")
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text(urlHost(from: card.imagePath ?? ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        } else if imageLoadFailed {
            ZStack {
                Color(hex: "#2A2A2A")
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("Missing Image")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } else if let imagePath = card.imagePath, !imagePath.isEmpty {
            // Loading placeholder
            ZStack {
                Color(hex: "#2A2A2A")
                ProgressView()
                    .scaleEffect(0.8)
            }
        } else {
            // Empty image placeholder
            ZStack {
                Color(hex: "#2A2A2A")
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No Image")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Text Card

    /// Poster-style title text (owner request): bold display type that
    /// fills the card and scales as the card is resized. No inner scroll
    /// (it hijacked canvas gestures) and no zoom font math — the cards
    /// layer already applies the one true zoom.
    @ViewBuilder
    private var textCardContent: some View {
        // Whatever the user typed shows as the poster — text first, but a
        // card that only has a title still displays it large.
        let content = [card.text, card.description, card.title]
            .first { !$0.isEmpty } ?? ""
        ZStack {
            Color(hex: card.textColor).opacity(0.06)

            if content.isEmpty {
                Text("Double-click to edit")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                Text(content)
                    .font(.system(size: 400, weight: .bold))
                    .minimumScaleFactor(0.01)
                    .foregroundColor(Color(hex: card.textColor))
                    .multilineTextAlignment(.center)
                    .padding(12)
            }
        }
    }

    // MARK: - Color Palette Card

    @ViewBuilder
    private var colorPaletteContent: some View {
        if card.colorPalette.isEmpty {
            ZStack {
                Color(hex: "#2A2A2A")
                VStack(spacing: 8) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No Colors")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } else {
            VStack(spacing: 0) {
                // Color swatches
                HStack(spacing: 0) {
                    ForEach(card.colorPalette.prefix(5), id: \.self) { hexColor in
                        Rectangle()
                            .fill(Color(hex: hexColor))
                            .overlay(
                                Text(hexColor.uppercased())
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1)
                                    .rotationEffect(.degrees(-90))
                                    .opacity(cardHeight > 100 ? 1 : 0)
                            )
                    }
                }
                .frame(height: cardHeight * 0.7)

                // Color hex codes list
                if card.colorPalette.count > 5 {
                    HStack(spacing: 0) {
                        ForEach(card.colorPalette.dropFirst(5).prefix(5), id: \.self) { hexColor in
                            Rectangle()
                                .fill(Color(hex: hexColor))
                        }
                    }
                    .frame(height: cardHeight * 0.3)
                }
            }
        }
    }

    // MARK: - Video Card

    @ViewBuilder
    private var videoCardContent: some View {
        ZStack {
            // Video thumbnail (if available from YouTube)
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            } else {
                Color(hex: "#1A1A1A")
            }

            // Play button overlay
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .offset(x: 2)
                )

            // Video URL indicator
            if let url = card.videoUrl, !url.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(urlHost(from: url))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Texture Card

    @ViewBuilder
    private var textureCardContent: some View {
        if let image = loadedImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
                .overlay(
                    // Texture pattern indicator
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "square.grid.3x3")
                                .font(.caption)
                                .padding(6)
                                .background(Color.black.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding(8)
                        }
                        Spacer()
                    }
                )
        } else {
            ZStack {
                // Procedural texture placeholder
                GeometryReader { geo in
                    Path { path in
                        let step: CGFloat = 20
                        for x in stride(from: 0, to: geo.size.width, by: step) {
                            for y in stride(from: 0, to: geo.size.height, by: step) {
                                path.addRect(CGRect(x: x, y: y, width: step / 2, height: step / 2))
                            }
                        }
                    }
                    .fill(Color.gray.opacity(0.3))
                }
                .background(Color(hex: "#2A2A2A"))

                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("Texture")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Lighting Card

    @ViewBuilder
    private var lightingCardContent: some View {
        ZStack {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            } else {
                // Lighting reference placeholder with gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#1A1A1A"),
                        Color(hex: "#3A3A3A"),
                        Color(hex: "#FFD700").opacity(0.3)
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            }

            // Lighting icon overlay
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .padding(6)
                        .background(Color.yellow.opacity(0.8))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .padding(8)
                }
                Spacer()
            }
        }
    }

    // MARK: - Location Card

    @ViewBuilder
    private var locationCardContent: some View {
        ZStack {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            } else {
                Color(hex: "#2A2A2A")
            }

            // Location pin overlay
            VStack {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .padding(6)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(8)
                    Spacer()
                }
                Spacer()
            }

            // Location description at bottom
            if !card.description.isEmpty {
                VStack {
                    Spacer()
                    Text(card.description)
                        .font(.caption)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var cardBackground: some View {
        Color(hex: "#1E1E1E")
    }

    // MARK: - Label Overlay

    @ViewBuilder
    private var labelOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Text(card.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.white)
                Spacer()
                if let dept = card.department, !dept.isEmpty {
                    Text(dept)
                        .font(.system(size: 9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    // MARK: - Pinned Indicator

    @ViewBuilder
    private var pinnedIndicator: some View {
        VStack {
            HStack {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(45))
                    .padding(4)
                Spacer()
            }
            Spacer()
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    // MARK: - Resize Handles

    @ViewBuilder
    private var resizeHandles: some View {
        ForEach(ResizeCorner.allCases, id: \.self) { corner in
            resizeHandle(for: corner)
        }
    }

    @ViewBuilder
    private func resizeHandle(for corner: ResizeCorner) -> some View {
        let handleSize: CGFloat = 12
        let offset = corner.offset(for: CGSize(width: cardWidth, height: cardHeight))

        Circle()
            .fill(Color.accentColor)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            // Counter-scale so handles stay 12pt on screen at any zoom.
            .scaleEffect(zoomLevel > 0 ? 1 / zoomLevel : 1)
            // CARD-LOCAL coordinates — the ZStack is the card's own space.
            .position(x: offset.x, y: offset.y)
            .gesture(
                DragGesture(minimumDistance: 1,
                            coordinateSpace: .named(canvasSpaceName))
                    .onChanged { value in
                        if !isResizing {
                            isResizing = true
                            onResizeBegan?(corner)
                        }
                        onResizeChanged?(value.translation)
                    }
                    .onEnded { value in
                        isResizing = false
                        onResizeEnded?(value.translation)
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.crosshair.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Gestures

    /// Raw phases only; the VM's anchored session does the math. The named
    /// coordinate space keeps translations in unscaled screen points.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3,
                    coordinateSpace: .named(canvasSpaceName))
            .onChanged { value in
                guard !isResizing else { return }
                if !isDragging {
                    isDragging = true
                    onDragBegan?()
                }
                onDragChanged?(value.translation)
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                onDragEnded?(value.translation)
            }
    }

    private func loadImageIfNeeded() {
        imageLoadFailed = false
        // Resolve-on-load (Slice 2): relative paths against the project
        // base, legacy absolute paths as-is; remote refs return nil and
        // render a static placeholder (never fetched in the render path).
        guard let url = VisionBoardImagePath.resolveImageURL(
            card.imagePath, projectBase: projectBase) else {
            loadedImage = nil
            if case .relative = VisionImageRef.classify(card.imagePath) {
                imageLoadFailed = true  // relative path with no project base
            }
            return
        }

        // Perf Tier 3 (audit C3): downsample to ~2.5× the card's point size
        // instead of holding each mood-board card's full-resolution source in
        // memory (many high-res references × per-card full bitmaps was the
        // resident-memory + GPU-rescale-on-zoom cost).
        let maxPixel = Int(max(cardWidth, cardHeight) * 2.5)
        if let cached = ThumbnailImageCache.shared.cached(url, maxPixel: maxPixel) {
            loadedImage = cached
            return
        }
        Task {
            let image = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: maxPixel)
            await MainActor.run {
                self.loadedImage = image
                self.imageLoadFailed = image == nil
            }
        }
    }

    private func urlHost(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

// MARK: - Resize Corner Enum

public enum ResizeCorner: CaseIterable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    func offset(for size: CGSize) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: 0, y: 0)
        case .topRight: return CGPoint(x: size.width, y: 0)
        case .bottomLeft: return CGPoint(x: 0, y: size.height)
        case .bottomRight: return CGPoint(x: size.width, y: size.height)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VisionCardItem_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: "#1A1A1A").ignoresSafeArea()

            VisionCardItem(
                card: VisionCard(
                    id: "1",
                    title: "Hero Shot Reference",
                    description: "Main character introduction",
                    cardType: "image",
                    department: "cinematography"
                ),
                isSelected: true,
                zoomLevel: 1.0,
                showLabel: true
            )
        }
        .frame(width: 400, height: 400)
    }
}
#endif
