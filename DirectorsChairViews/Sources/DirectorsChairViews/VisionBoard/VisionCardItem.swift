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
    /// A connector is looking for its other end: this scrap is a target,
    /// so it highlights and takes a plain click instead of a drag.
    public let isConnectTarget: Bool
    /// This element's picture is being redrawn right now.
    public var isRedrawing: Bool = false
    /// Tapping the tag opens the scene or shot this element belongs to.
    public var onOpenLink: (() -> Void)?
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
    /// Commits inline-edited words (The Wall, pass 2 — a clipping is
    /// rewritten on the wall, never in a sheet).
    public var onCommitText: ((String) -> Void)?
    /// Cycles a clipping's cut.
    public var onCycleCut: (() -> Void)?
    /// Corner-rotate: begin/update/end carry degrees of change.
    public var onRotateBegan: (() -> Void)?
    public var onRotateChanged: ((Double) -> Void)?
    public var onRotateEnded: ((Double) -> Void)?
    /// Pushpin: hold this scrap where it is.
    public var onTogglePin: (() -> Void)?
    public var onDuplicate: (() -> Void)?
    public var onDelete: (() -> Void)?
    public var onExtractPalette: (() -> Void)?
    public var onBeginConnector: (() -> Void)?
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
        isConnectTarget: Bool = false,
        isRedrawing: Bool = false,
        onOpenLink: (() -> Void)? = nil,
        zoomLevel: CGFloat = 1.0,
        showLabel: Bool = true,
        canvasSpaceName: String = "visionCanvas",
        projectBase: URL? = nil,
        onSelect: ((Bool) -> Void)? = nil,
        onDoubleClick: (() -> Void)? = nil,
        onCommitText: ((String) -> Void)? = nil,
        onCycleCut: (() -> Void)? = nil,
        onRotateBegan: (() -> Void)? = nil,
        onRotateChanged: ((Double) -> Void)? = nil,
        onRotateEnded: ((Double) -> Void)? = nil,
        onTogglePin: (() -> Void)? = nil,
        onDuplicate: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onExtractPalette: (() -> Void)? = nil,
        onBeginConnector: (() -> Void)? = nil,
        onDragBegan: (() -> Void)? = nil,
        onDragChanged: ((CGSize) -> Void)? = nil,
        onDragEnded: ((CGSize) -> Void)? = nil,
        onResizeBegan: ((ResizeCorner) -> Void)? = nil,
        onResizeChanged: ((CGSize) -> Void)? = nil,
        onResizeEnded: ((CGSize) -> Void)? = nil
    ) {
        self.card = card
        self.isSelected = isSelected
        self.isConnectTarget = isConnectTarget
        self.isRedrawing = isRedrawing
        self.onOpenLink = onOpenLink
        self.zoomLevel = zoomLevel
        self.showLabel = showLabel
        self.canvasSpaceName = canvasSpaceName
        self.projectBase = projectBase
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
        self.onCommitText = onCommitText
        self.onCycleCut = onCycleCut
        self.onRotateBegan = onRotateBegan
        self.onRotateChanged = onRotateChanged
        self.onRotateEnded = onRotateEnded
        self.onTogglePin = onTogglePin
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onExtractPalette = onExtractPalette
        self.onBeginConnector = onBeginConnector
        self.onDragBegan = onDragBegan
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onResizeBegan = onResizeBegan
        self.onResizeChanged = onResizeChanged
        self.onResizeEnded = onResizeEnded
    }

    /// The pendulum: how far the paper currently hangs off its own tilt,
    /// its angular velocity, and the frame clock that settles it.
    @State private var swing: Double = 0
    @State private var swingVelocity: Double = 0
    @State private var settling = false
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastDragTime: Date?
    @State private var isRotating = false
    @State private var isEditingInline = false
    @State private var draftWords = ""
    @FocusState private var inlineFocused: Bool

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Main card content
            cardContent
                .frame(width: cardWidth, height: cardHeight)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                // The Wall, pass 2: a scrap IS the picture. No border, no
                // header, no badge — only the shadow of a thing lying on a
                // surface. Selection is a grease-pencil ring, the one
                // accent the wall allows.
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(VisionWallPalette.greasePencil,
                                      lineWidth: isSelected ? 2 : 0)
                        .opacity(isSelected ? 1 : 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(VisionWallPalette.greasePencil,
                                      style: StrokeStyle(lineWidth: isHovering ? 3 : 2,
                                                         dash: [6, 4]))
                        .opacity(isConnectTarget ? (isHovering ? 1 : 0.55) : 0)
                )
                .shadow(color: VisionWallPalette.scrapShadow,
                        radius: isSelected ? 11 : 7,
                        x: 0, y: isSelected ? 5 : 3)

            if isEditingInline {
                // Editing must not shrink the words: the face auto-fits
                // huge type to the scrap, so the field matches the scrap's
                // own scale instead of a fixed point size.
                TextField("", text: $draftWords, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: max(13, min(cardWidth, cardHeight) * 0.26),
                                  weight: .black))
                    .minimumScaleFactor(0.15)
                    .multilineTextAlignment(.center)
                    .foregroundColor(VisionPaper.resolve(card.paper).ink)
                    .padding(12)
                    .frame(width: cardWidth, height: cardHeight)
                    .background(VisionPaper.resolve(card.paper).base)
                    .focused($inlineFocused)
                    .onAppear { inlineFocused = true }
                    .onSubmit {
                        onCommitText?(draftWords)
                        isEditingInline = false
                    }
                    .onExitCommand { isEditingInline = false }
            }

            // A scene or shot pinned here shows as a filing tab on the
            // top edge — and the tab is the way back to it, so the link
            // reads in both directions rather than being a label you
            // can't do anything with.
            if let linked = card.linkedRef {
                Button(action: { onOpenLink?() }) {
                    HStack(spacing: 3 / max(zoomLevel, 0.01)) {
                        Image(systemName: linked.kind == .shot
                              ? "camera.fill" : "film.fill")
                            .symbolRenderingMode(.monochrome)
                            .font(.system(size: 8 / max(zoomLevel, 0.01),
                                          weight: .bold))
                        Text(linked.label.isEmpty ? "Linked" : linked.label)
                            .font(.system(size: 10 / max(zoomLevel, 0.01),
                                          weight: .heavy))
                            .fontWidth(.condensed)
                            .lineLimit(1)
                    }
                    .foregroundStyle(VisionWallPalette.clipping)
                    .padding(.horizontal, 7 / max(zoomLevel, 0.01))
                    .padding(.vertical, 3.5 / max(zoomLevel, 0.01))
                    .background(VisionWallPalette.greasePencil,
                                in: RoundedRectangle(
                                    cornerRadius: 3 / max(zoomLevel, 0.01)))
                    .shadow(color: VisionWallPalette.scrapShadow,
                            radius: 2.5 / max(zoomLevel, 0.01),
                            y: 1.5 / max(zoomLevel, 0.01))
                }
                .buttonStyle(.plain)
                .offset(x: 8 / max(zoomLevel, 0.01),
                        y: -9 / max(zoomLevel, 0.01))
                .help(linked.kind == .shot ? "Open this shot"
                                           : "Open this scene")
                .accessibilityLabel("Open \(linked.label)")
            }

            if isRedrawing {
                VisionWorkingBadge(size: 30 / max(zoomLevel, 0.01))
                    .offset(x: cardWidth - 19 / max(zoomLevel, 0.01),
                            y: cardHeight - 19 / max(zoomLevel, 0.01))
            }

            // A note is a slip of paper taped under the element, not
            // metadata behind an inspector.
            if let note = card.referenceNote, !note.isEmpty, !isEditingInline {
                VisionNoteSlip(text: note)
                    .frame(width: min(max(cardWidth * 0.5, 96), 168))
                    .offset(x: cardWidth * 0.5, y: cardHeight * 0.56)
                    .allowsHitTesting(false)
            }

            // The tack that holds this scrap to the wall. Offset, never
            // .position — a positioned child claims all available space and
            // would resize the scrap's own frame.
            VisionThumbtack(size: tackSize, pressed: card.pinned,
                            tint: card.pinned ? Color(hex: "#B08A3C")
                                              : VisionWallPalette.greasePencil)
                .offset(x: cardWidth * tackAnchor.x - tackSize / 2,
                        y: cardHeight * tackAnchor.y - tackSize / 2)
                .allowsHitTesting(false)

            // Resize handles (visible when selected)
            if isSelected {
                resizeHandles
                if !card.pinned { rotateHandle }
            }

            // No label bar, no department badge: nothing on the wall
            // announces its own metadata (The Wall, pass 2). Titles and
            // notes live in the details popover (DC-0027); what you see
            // is the thing itself.

            // Pinned indicator
            if card.pinned {
                pinnedIndicator
            }
        }
        // The tack is the pivot: paper turns around the pin that holds it,
        // never around its own middle (The Wall, pass 2).
        .rotationEffect(.degrees((card.rotation ?? 0) + swing),
                        anchor: UnitPoint(x: tackAnchor.x, y: tackAnchor.y))
        // World coordinates only — the cards layer applies zoom+offset once.
        .position(x: cardPosition.x + cardWidth / 2, y: cardPosition.y + cardHeight / 2)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            if cardType == .text {
                draftWords = card.text
                isEditingInline = true
            } else {
                onDoubleClick?()
            }
        }
        .onTapGesture {
            onSelect?(NSEvent.modifierFlags.contains(.shift))
        }
        .gesture(isConnectTarget ? nil : dragGesture)
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
        case .link:
            linkFace

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
        case .frame:
            frameCardContent
        case .shotStrip:
            shotStripContent
        }
    }

    // MARK: - Shot Strip

    /// Ordered filmstrip (roadmap #4): expresses progression — a scene's
    /// beat arc, a color script across acts.
    @ViewBuilder
    private var shotStripContent: some View {
        if card.imagePaths.isEmpty {
            ZStack {
                VisionWallPalette.clipping
                VStack(spacing: 6) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("Add frames in the editor")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        } else {
            HStack(spacing: 3) {
                ForEach(Array(card.imagePaths.enumerated()), id: \.offset) { _, path in
                    ShotStripFrame(path: path, projectBase: projectBase)
                }
            }
            .padding(4)
            .background(Color.black)
        }
    }

    // MARK: - Section Frame

    /// A named, tinted region (research roadmap #1): renders under all
    /// cards; dragging it carries cards whose centers lie inside.
    @ViewBuilder
    private var frameCardContent: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: card.textColor).opacity(0.07)
            Text((card.title.isEmpty ? "Section" : card.title).uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.4)
                .foregroundColor(Color(hex: card.textColor).opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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
                VisionWallPalette.clipping
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
                VisionWallPalette.clipping
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
                VisionWallPalette.clipping
                ProgressView()
                    .scaleEffect(0.8)
            }
        } else {
            // Empty image placeholder
            ZStack {
                VisionWallPalette.clipping
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

    /// Semantic preset text (Title/Section/Quote/Caption/Note/Tag):
    /// display type that fills the card and scales as the card is
    /// resized. No inner scroll (it hijacked canvas gestures) and no
    /// zoom font math — the cards layer already applies the one true
    /// zoom.
    @ViewBuilder
    private var textCardContent: some View {
        // Whatever the user typed shows on the face — text first, but a
        // card that only has a title still displays it large.
        let content = [card.text, card.description, card.title]
            .first { !$0.isEmpty } ?? ""
        ZStack {
            Color(hex: card.textColor).opacity(0.04)

            if content.isEmpty {
                Text("Double-click to edit")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                VisionTextCardFace(
                    content: content,
                    style: VisionTextStyle.resolve(card.textStyle),
                    colorHex: card.textColor,
                                seedID: card.id,
                                paper: VisionPaper.resolve(card.paper))
            }
        }
    }

    // MARK: - Color Palette Card

    @ViewBuilder
    private var colorPaletteContent: some View {
        if card.colorPalette.isEmpty {
            ZStack {
                VisionWallPalette.clipping
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
                VisionWallPalette.clipping
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
                .background(VisionWallPalette.clipping)

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
                        VisionWallPalette.clipping,
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
                VisionWallPalette.clipping
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
    /// What shows behind a scrap that doesn't fill its own frame: paper,
    /// not a black tile (The Wall, pass 2).
    private var cardBackground: some View {
        VisionWallPalette.clipping
    }

    /// A link on the wall reads as a clipping with the site written on
    /// it — a torn strip of a page, not a browser chrome preview.
    private var linkFace: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "link")
                    .font(.system(size: 9, weight: .bold))
                Text((card.sourceUrl.flatMap(URL.init(string:))?.host ?? "link")
                        .replacingOccurrences(of: "www.", with: "")
                        .uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
            }
            .foregroundColor(VisionWallPalette.greasePencil)

            Text(card.title.isEmpty ? (card.sourceUrl ?? "") : card.title)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(VisionWallPalette.ink)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ZStack {
            VisionPaper.resolve(card.paper).base
            VisionPaperTexture(paper: VisionPaper.resolve(card.paper))
        })
        .clipShape(VisionTornPaper(torn: [.bottom],
                                   seed: VisionTornPaper.seed(for: card.id)))
    }

    // MARK: - Rotate Handle

    /// Grab above the scrap and turn it. Counter-scaled like the resize
    /// dots so it stays the same size at any zoom.
    private var rotateHandle: some View {
        let gap: CGFloat = 26 / max(zoomLevel, 0.01)
        let offset = CGPoint(x: 0, y: -(cardHeight / 2 + gap))
        return Image(systemName: "arrow.trianglehead.counterclockwise.rotate.90")
            .font(.system(size: 10 / max(zoomLevel, 0.01), weight: .bold))
            .foregroundColor(.white)
            .padding(5 / max(zoomLevel, 0.01))
            .background(Circle().fill(VisionWallPalette.greasePencil))
            .position(x: cardWidth / 2, y: -gap)
            .gesture(
                DragGesture(coordinateSpace: .named(canvasSpaceName))
                    .onChanged { value in
                        if !isRotating {
                            isRotating = true
                            onRotateBegan?()
                        }
                        onRotateChanged?(VisionCanvasGeometry.rotationDelta(
                            handleOffset: offset, translation: value.translation,
                            zoom: zoomLevel))
                    }
                    .onEnded { value in
                        isRotating = false
                        onRotateEnded?(VisionCanvasGeometry.rotationDelta(
                            handleOffset: offset, translation: value.translation,
                            zoom: zoomLevel))
                    }
            )
            .help("Drag to turn this element")
    }

    // MARK: - Label Overlay

    @ViewBuilder
    private var labelOverlay: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    if !card.title.isEmpty {
                        Text(card.title)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(.white)
                    }
                    // ShotDeck-style reference caption (roadmap #3).
                    if let note = card.referenceNote, !note.isEmpty {
                        Text(note.uppercased())
                            .font(.system(size: 8, weight: .medium))
                            .tracking(0.8)
                            .lineLimit(1)
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
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
                    settling = false
                    lastDragTranslation = .zero
                    lastDragTime = nil
                    onDragBegan?()
                }
                trackSwing(translation: value.translation)
                onDragChanged?(value.translation)
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                onDragEnded?(value.translation)
                startSettling()
            }
    }

    /// Head size, counter-scaled so the tack looks the same at any zoom.
    private var tackSize: CGFloat { 15 / max(zoomLevel, 0.01) }

    /// Where the tack goes through this particular sheet.
    private var tackAnchor: CGPoint {
        VisionScrapPhysics.tackAnchor(seed: card.id)
    }

    /// While the hand moves the tack, the paper trails behind it.
    private func trackSwing(translation: CGSize) {
        let now = Date()
        defer {
            lastDragTranslation = translation
            lastDragTime = now
        }
        guard let last = lastDragTime else { return }
        let dt = now.timeIntervalSince(last)
        guard dt > 0.001 else { return }
        let dx = (translation.width - lastDragTranslation.width) / max(zoomLevel, 0.01)
        let velocity = CGFloat(Double(dx) / dt)
        // Ease toward the target lag so a jittery trackpad doesn't buzz.
        let target = VisionScrapPhysics.swing(horizontalVelocity: velocity)
        swing += (target - swing) * 0.35
        swingVelocity = 0
    }

    /// Let go and the paper swings a couple of times around the tack, then
    /// friction in the pin holds it at the tilt it already had.
    private func startSettling() {
        guard !settling else { return }
        settling = true
        Task { @MainActor in
            let frame = Duration.milliseconds(16)
            let dt = 1.0 / 60.0
            var guardCounter = 0
            while settling, guardCounter < 240 {
                guardCounter += 1
                let next = VisionScrapPhysics.step(
                    angle: swing, velocity: swingVelocity, target: 0, dt: dt)
                swing = next.angle
                swingVelocity = next.velocity
                if VisionScrapPhysics.atRest(angle: swing,
                                             velocity: swingVelocity, target: 0) {
                    break
                }
                try? await Task.sleep(for: frame)
            }
            swing = 0
            swingVelocity = 0
            settling = false
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


// MARK: - Shot Strip Frame

/// One filmstrip cell: thumbnail-cached, resolve-on-load like every
/// other board image.
private struct ShotStripFrame: View {
    let path: String
    let projectBase: URL?

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color(hex: "#1A1A1A")
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onAppear(perform: load)
        .onChange(of: projectBase) { _, _ in load() }
    }

    private func load() {
        guard let url = VisionBoardImagePath.resolveImageURL(
            path, projectBase: projectBase) else { return }
        if let cached = ThumbnailImageCache.shared.cached(url, maxPixel: 320) {
            image = cached
            return
        }
        Task {
            let thumbnail = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 320)
            await MainActor.run { image = thumbnail }
        }
    }
}
