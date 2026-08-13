// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionCardEditor.swift
//
// Vision Card Editor - Dialog for Creating and Editing Vision Cards
// Supports all card types: image, text, color palette, video, etc.
// Redesigned 2026-07: layered dark surfaces, card-type chip grid, sliding
// pill tabs, focus-ring fields, image well — same data flow underneath
// (Slice-2 staging pipeline, AI generation, palette/tag editing).

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import UniformTypeIdentifiers

// MARK: - Editor Theme

private enum EditorTheme {
    static let window = Color(hex: "#151517")
    static let panel = Color(hex: "#1B1B1E")
    static let field = Color(hex: "#232327")
    static let stroke = Color.white.opacity(0.07)
    static let secondary = Color(hex: "#9B9BA3")

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [.accentColor, .accentColor.opacity(0.72)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Building blocks

private struct FieldLabel: View {
    let text: String
    var icon: String?

    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.9)
        }
        .foregroundColor(EditorTheme.secondary)
    }
}

private struct EditorTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(EditorTheme.field))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focused ? Color.accentColor.opacity(0.8)
                                    : EditorTheme.stroke, lineWidth: 1)
            )
            .focused($focused)
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}

private struct EditorTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 84
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .focused($focused)
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundColor(EditorTheme.secondary.opacity(0.55))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 8).fill(EditorTheme.field))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(focused ? Color.accentColor.opacity(0.8)
                                : EditorTheme.stroke, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

/// Grouped panel that gives related fields one shared surface.
private struct EditorGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(EditorTheme.stroke, lineWidth: 1))
    }
}

// MARK: - Vision Card Editor

public struct VisionCardEditor: View {
    // MARK: - Properties

    @Binding public var card: VisionCard
    @Binding public var isPresented: Bool

    /// Callback when save is pressed
    public var onSave: (() -> Void)?

    /// Callback for AI image generation
    public var onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)?

    /// Slice 2: staging + path resolution. Nil when the project has never
    /// been saved (paste falls back to the OS temp dir; relative paths
    /// can't be previewed).
    public var assetStore: VisionBoardAssetStore?

    /// Whether this session creates a card (VisionCard ids are never
    /// empty, so the old `card.id.isEmpty` check could not distinguish).
    public var isNew: Bool

    /// Project locations — lets a Location card link to a real entity
    /// (name, primary image, description) instead of starting blank.
    public var locations: [Location]

    // MARK: - State

    /// Progressive disclosure (owner request): the editor opens in a
    /// simple single-column mode with only the essentials for the card's
    /// type; Advanced reveals the full sidebar+tabs UI. Sticky across
    /// sessions so power users stay where they like.
    @State private var showAdvanced: Bool =
        UserDefaults.standard.bool(forKey: Self.advancedModeKey)
    static let advancedModeKey = "visionCardEditorAdvancedMode"

    @State private var selectedTab: EditorTab = .general
    /// Transient style under the cursor in the style picker — drives the
    /// live preview without committing.
    @State private var hoveredStyle: VisionTextStyle?
    @State private var isLoadingImage: Bool = false
    @State private var imageLoadError: String?
    @State private var newColorHex: String = "#"
    @State private var showColorPicker: Bool = false
    @State private var aiPrompt: String = ""
    @State private var isGeneratingImage: Bool = false
    @State private var previewImage: NSImage?
    @Namespace private var tabNamespace

    /// Pro-toolkit gating (Product-Versions §3.4): the frame, palette,
    /// and shot-strip card types are Creator. Their chips stay visible
    /// with a lock; picking one below tier opens the "coming soon" sheet.
    @Environment(\.productTier) private var productTier
    @State private var tierPrompt: TierPromptRequest?
    private static let proToolkitTypes: Set<VisionCardType> =
        [.frame, .colorPalette, .shotStrip]

    private func typeIsLocked(_ type: VisionCardType) -> Bool {
        Self.proToolkitTypes.contains(type) && productTier < .creator
    }

    private func selectType(_ type: VisionCardType) {
        guard !typeIsLocked(type) else {
            tierPrompt = TierPromptRequest(
                feature: "\(type.displayName) cards (Pro toolkit)",
                requiredTier: .creator)
            return
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            card.cardType = type.rawValue
        }
    }

    // MARK: - Init

    public init(
        card: Binding<VisionCard>,
        isPresented: Binding<Bool>,
        onSave: (() -> Void)? = nil,
        onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)? = nil,
        assetStore: VisionBoardAssetStore? = nil,
        isNew: Bool = false,
        locations: [Location] = [],
        availableSize: CGSize? = nil
    ) {
        self._card = card
        self._isPresented = isPresented
        self.onSave = onSave
        self.onGenerateImage = onGenerateImage
        self.assetStore = assetStore
        self.isNew = isNew
        self.locations = locations
        self.availableSize = availableSize
    }

    // MARK: - Fitting the window

    /// How big the sheet may be. A macOS sheet is CLIPPED to its
    /// presenting window rather than shrunk to fit, so a fixed size that
    /// happens to exceed the window loses its header and its Save button
    /// off both ends — which is exactly what the owner hit.
    ///
    /// Pure, so the arithmetic can be tested without a window.
    static func fittedSize(ideal: CGSize, available: CGSize?) -> CGSize {
        guard let available, available.width > 0, available.height > 0 else {
            return ideal
        }
        // A sheet never sits flush to the window edge.
        let margin: CGFloat = 40
        return CGSize(
            width: max(360, min(ideal.width, available.width - margin)),
            height: max(280, min(ideal.height, available.height - margin)))
    }

    /// The presenting view's size, so the sheet can fit inside it.
    public var availableSize: CGSize?

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            editorHeader

            Divider().overlay(EditorTheme.stroke)

            if showAdvanced {
                HStack(spacing: 0) {
                    leftSidebar
                        .frame(width: 224)

                    Divider().overlay(EditorTheme.stroke)

                    mainEditorArea
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            } else {
                simpleEditor
                    .frame(maxHeight: .infinity)
            }

            Divider().overlay(EditorTheme.stroke)

            editorFooter
        }
        .frame(width: fitted.width, height: fitted.height)
        .background(EditorTheme.window)
        .animation(.spring(response: 0.3, dampingFraction: 0.9),
                   value: showAdvanced)
        .tierPromptSheet($tierPrompt)
        .onAppear {
            loadPreviewImage()
        }
    }

    private var fitted: CGSize {
        Self.fittedSize(
            ideal: CGSize(width: showAdvanced ? 760 : 540,
                          height: showAdvanced ? 600 : 560),
            available: availableSize)
    }

    // MARK: - Header

    @ViewBuilder
    private var editorHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(EditorTheme.accentGradient)
                Image(systemName: cardType.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 34, height: 34)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(isNew ? "New Vision Card" : "Edit Vision Card")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(cardType.displayName) card")
                    .font(.system(size: 11))
                    .foregroundColor(EditorTheme.secondary)
            }

            Spacer()

            if card.pinned {
                Label("Pinned", systemImage: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }

            Button {
                showAdvanced.toggle()
                UserDefaults.standard.set(showAdvanced,
                                          forKey: Self.advancedModeKey)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 9, weight: .semibold))
                    Text(showAdvanced ? "Simple" : "Advanced")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(EditorTheme.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(EditorTheme.field))
                .overlay(Capsule().stroke(EditorTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help(showAdvanced
                  ? "Back to the essentials"
                  : "Tags, scene links, department, and every option")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(EditorTheme.panel)
    }

    // MARK: - Simple Mode

    /// The essentials only: pick a type (when creating), then the one
    /// input that type actually needs. Everything else lives behind
    /// Advanced.
    @ViewBuilder
    private var simpleEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isNew {
                    simpleTypePicker
                }

                switch cardType {
                case .text:
                    textPreviewPanel
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("Text", icon: "text.alignleft")
                        EditorTextEditor(placeholder: "The words on the card…",
                                         text: $card.text, height: 90)
                    }
                    textStylePicker
                    HStack {
                        FieldLabel("Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: card.textColor) },
                            set: { card.textColor = $0.hexString }
                        ))
                        .labelsHidden()
                    }

                case .colorPalette:
                    colorPaletteEditor

                case .frame:
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("Section name", icon: "rectangle.dashed")
                        EditorTextField(placeholder: "e.g. ACT I, LIGHTING, THE HOUSE",
                                        text: $card.title)
                    }
                    HStack {
                        FieldLabel("Tint")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: card.textColor) },
                            set: { card.textColor = $0.hexString }
                        ))
                        .labelsHidden()
                    }

                case .shotStrip:
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("Frames — in order", icon: "film.stack")
                        ForEach(Array(card.imagePaths.enumerated()),
                                id: \.offset) { index, path in
                            HStack(spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(EditorTheme.secondary)
                                Text((path as NSString).lastPathComponent)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(.white)
                                Spacer()
                                Button {
                                    card.imagePaths.swapAt(index, index - 1)
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(EditorTheme.secondary)
                                .disabled(index == 0)
                                Button {
                                    card.imagePaths.swapAt(index, index + 1)
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(EditorTheme.secondary)
                                .disabled(index == card.imagePaths.count - 1)
                                Button {
                                    card.imagePaths.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(EditorTheme.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(EditorTheme.field))
                        }
                        mediaButton("Add Frames…", icon: "plus") {
                            addStripFrames()
                        }
                        // Editing an existing strip (example projects
                        // ship some) is still Pro toolkit (§3.4).
                        .requiresTier(.creator, feature: "Image strips")
                    }
                    simpleTitleField

                case .video:
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("Video URL", icon: "video")
                        EditorTextField(placeholder: "YouTube or video URL",
                                        text: optionalBinding(\.videoUrl))
                    }
                    simpleTitleField

                default:  // image, texture, lighting, location
                    if cardType == .location && !locations.isEmpty {
                        locationPicker
                    }
                    imageWell
                    HStack(spacing: 8) {
                        mediaButton("Browse…", icon: "folder") {
                            browseForImage()
                        }
                        mediaButton("Paste", icon: "doc.on.clipboard") {
                            pasteFromClipboard()
                        }
                        Spacer()
                    }
                    if let error = imageLoadError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    aiGenerateRow
                    simpleTitleField
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel("Reference note", icon: "camera.metering.spot")
                        EditorTextField(
                            placeholder: "35mm anamorphic · backlit · dusk",
                            text: optionalBinding(\.referenceNote))
                    }
                }
            }
            .padding(20)
        }
    }

    /// Live preview of the user's actual words in the active style —
    /// hovering a style chip previews that style before committing.
    private var textPreviewPanel: some View {
        let content = [card.text, card.description, card.title]
            .first { !$0.isEmpty } ?? "Your text"
        let style = hoveredStyle ?? VisionTextStyle.resolve(card.textStyle)
        return VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Preview", icon: "eye")
            ZStack {
                Color(hex: "#101012")
                VisionTextCardFace(content: content, style: style,
                                   colorHex: card.textColor,
                                seedID: card.id)
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(EditorTheme.stroke, lineWidth: 1))
            .animation(.easeOut(duration: 0.12), value: style)
        }
    }

    /// Six semantic presets, each chip rendered IN its own style —
    /// recognition over recall (research 2026-07). Whole-card styling;
    /// size always comes from resizing the card.
    private var textStylePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Style", icon: "textformat")
            HStack(spacing: 6) {
                ForEach(VisionTextStyle.allCases) { style in
                    textStyleChip(style)
                }
            }
        }
    }

    private func textStyleChip(_ style: VisionTextStyle) -> some View {
        let selected = VisionTextStyle.resolve(card.textStyle) == style
        return Button {
            card.textStyle = style.rawValue
            UserDefaults.standard.set(
                style.rawValue, forKey: VisionBoardViewModel.lastTextStyleKey)
        } label: {
            VStack(spacing: 4) {
                VisionTextCardFace(content: "Aa", style: style,
                                   colorHex: card.textColor,
                                seedID: card.id)
                    .frame(height: 34)
                Text(style.displayName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(selected ? .accentColor
                                             : EditorTheme.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color.accentColor.opacity(0.14)
                               : EditorTheme.field))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.accentColor.opacity(0.85)
                                 : EditorTheme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(style.displayName)
        .onHover { hovering in
            if hovering {
                hoveredStyle = style
            } else if hoveredStyle == style {
                hoveredStyle = nil
            }
        }
    }

    private var simpleTitleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Title")
            EditorTextField(placeholder: "Optional caption", text: $card.title)
        }
    }

    /// Compact one-row type chooser for new cards.
    private var simpleTypePicker: some View {
        HStack(spacing: 6) {
            ForEach(VisionCardType.allCases) { type in
                let selected = cardType == type
                Button {
                    selectType(type)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 13, weight: .medium))
                        Text(type.displayName)
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? Color.accentColor.opacity(0.16)
                                       : EditorTheme.field))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.accentColor.opacity(0.85)
                                         : EditorTheme.stroke, lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        if typeIsLocked(type) { TierLockBadge() }
                    }
                    .foregroundColor(selected ? .accentColor
                                             : EditorTheme.secondary)
                }
                .buttonStyle(.plain)
                .help(type.displayName)
            }
        }
    }

    // MARK: - Left Sidebar

    @ViewBuilder
    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Card Type")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6),
                                    GridItem(.flexible(), spacing: 6)],
                          spacing: 6) {
                    ForEach(VisionCardType.allCases) { type in
                        typeChip(type)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Preview")

                previewArea
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
                    .background(Color(hex: "#101012"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(EditorTheme.stroke, lineWidth: 1))
            }

            HStack(spacing: 8) {
                Image(systemName: card.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundColor(card.pinned ? .accentColor : EditorTheme.secondary)
                Text("Pin to Top")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $card.pinned)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .tint(.accentColor)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 9).fill(EditorTheme.field))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(EditorTheme.stroke, lineWidth: 1))

            Spacer()
        }
        .padding(16)
        .background(EditorTheme.panel)
    }

    private func typeChip(_ type: VisionCardType) -> some View {
        let selected = cardType == type
        return Button {
            selectType(type)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(type.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(selected ? Color.accentColor.opacity(0.16) : EditorTheme.field))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(selected ? Color.accentColor.opacity(0.85)
                                 : EditorTheme.stroke, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if typeIsLocked(type) { TierLockBadge() }
            }
            .foregroundColor(selected ? .accentColor : EditorTheme.secondary)
        }
        .buttonStyle(.plain)
        .help(type.displayName)
    }

    // MARK: - Preview Area

    @ViewBuilder
    private var previewArea: some View {
        switch cardType {
        case .link:
            // Links are pinned from the wall's tool ring, not this editor
            // (which retires in DC-0030).
            Text(card.sourceUrl ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .padding()

        case .image, .texture, .lighting, .location:
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoadingImage {
                ProgressView()
                    .controlSize(.small)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: cardType.systemImage)
                        .font(.system(size: 22))
                    Text("No image")
                        .font(.system(size: 10))
                }
                .foregroundColor(EditorTheme.secondary)
            }

        case .colorPalette:
            if card.colorPalette.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 22))
                    Text("No colors")
                        .font(.system(size: 10))
                }
                .foregroundColor(EditorTheme.secondary)
            } else {
                HStack(spacing: 0) {
                    ForEach(card.colorPalette.prefix(6), id: \.self) { hex in
                        Rectangle()
                            .fill(Color(hex: hex))
                    }
                }
            }

        case .text:
            // Mirrors the canvas card, including its text→description→
            // title fallback and the semantic style preset.
            let posterText = [card.text, card.description, card.title]
                .first { !$0.isEmpty } ?? ""
            if posterText.isEmpty {
                Text("Enter text…")
                    .font(.system(size: 11))
                    .foregroundColor(EditorTheme.secondary)
            } else {
                VisionTextCardFace(
                    content: posterText,
                    style: VisionTextStyle.resolve(card.textStyle),
                    colorHex: card.textColor,
                                seedID: card.id)
            }

        case .frame:
            ZStack(alignment: .topLeading) {
                Color(hex: card.textColor).opacity(0.07)
                Text((card.title.isEmpty ? "Section" : card.title).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(Color(hex: card.textColor).opacity(0.85))
                    .padding(8)
            }

        case .shotStrip:
            VStack(spacing: 6) {
                Image(systemName: "film.stack")
                    .font(.system(size: 22))
                    .foregroundColor(EditorTheme.secondary)
                Text("\(card.imagePaths.count) frame\(card.imagePaths.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(EditorTheme.secondary)
            }

        case .video:
            VStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 22))
                    .foregroundColor(EditorTheme.secondary)
                if let url = card.videoUrl, !url.isEmpty {
                    Text(url)
                        .font(.system(size: 9))
                        .foregroundColor(EditorTheme.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 10)
                }
            }
        }
    }

    // MARK: - Main Editor Area

    @ViewBuilder
    private var mainEditorArea: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(EditorTab.allCases, id: \.self) { tab in
                        tabButton(tab)
                    }
                }
                .padding(3)
                .background(Capsule().fill(EditorTheme.field))
                .overlay(Capsule().stroke(EditorTheme.stroke, lineWidth: 1))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .media:
                        mediaTab
                    case .tags:
                        tagsTab
                    case .scene:
                        sceneTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func tabButton(_ tab: EditorTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 12,
                              weight: selectedTab == tab ? .semibold : .medium))
                .foregroundColor(selectedTab == tab ? .white : EditorTheme.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background {
                    if selectedTab == tab {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.85))
                            .matchedGeometryEffect(id: "tabpill", in: tabNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        // A text card IS its text — that field leads, everything else
        // follows.
        if cardType == .text {
            EditorGroup {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Text Content", icon: "text.alignleft")
                    EditorTextEditor(placeholder: "The words on the card…",
                                     text: $card.text, height: 110)
                }

                textStylePicker

                HStack {
                    FieldLabel("Text Color")
                    Spacer()
                    Text(card.textColor)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(EditorTheme.secondary)
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: card.textColor) },
                        set: { card.textColor = $0.hexString }
                    ))
                    .labelsHidden()
                }
            }
        }

        EditorGroup {
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Title")
                EditorTextField(placeholder: "Card title", text: $card.title)
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Description")
                EditorTextEditor(placeholder: "What is this reference for?",
                                 text: $card.description)
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Department")
                Picker("", selection: Binding(
                    get: { card.department ?? "" },
                    set: { card.department = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    ForEach(VisionDepartment.allCases) { dept in
                        Text(dept.displayName).tag(dept.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 220)
            }

            if cardType == .location && !locations.isEmpty {
                locationPicker
            }

            if cardType == .image || cardType == .texture || cardType == .lighting {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Credit / Source")
                    EditorTextField(placeholder: "Photographer or artist credit",
                                    text: optionalBinding(\.credit))
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Reference note", icon: "camera.metering.spot")
                    EditorTextField(
                        placeholder: "35mm anamorphic · backlit · dusk",
                        text: optionalBinding(\.referenceNote))
                }
            }
        }

        if cardType == .colorPalette {
            EditorGroup {
                colorPaletteEditor
            }
        }
    }

    // MARK: - Color Palette Editor

    @ViewBuilder
    private var colorPaletteEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel("Color Palette", icon: "paintpalette")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 10) {
                ForEach(card.colorPalette, id: \.self) { hexColor in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: hexColor))
                            .frame(height: 46)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1))
                            .overlay(
                                Button {
                                    card.colorPalette.removeAll { $0 == hexColor }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(4),
                                alignment: .topTrailing
                            )
                        Text(hexColor)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(EditorTheme.secondary)
                    }
                }

                Button {
                    showColorPicker = true
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundColor(EditorTheme.secondary.opacity(0.6))
                            .frame(height: 46)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(EditorTheme.secondary)
                            )
                        Text("Add")
                            .font(.system(size: 9))
                            .foregroundColor(EditorTheme.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            if showColorPicker {
                HStack(spacing: 8) {
                    EditorTextField(placeholder: "#RRGGBB", text: $newColorHex)
                        .frame(width: 110)

                    ColorPicker("", selection: Binding(
                        get: { Color(hex: newColorHex) },
                        set: { newColorHex = $0.hexString }
                    ))
                    .labelsHidden()

                    Button("Add") {
                        if !newColorHex.isEmpty && !card.colorPalette.contains(newColorHex) {
                            card.colorPalette.append(newColorHex)
                        }
                        newColorHex = "#"
                        showColorPicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Media Tab

    @ViewBuilder
    private var mediaTab: some View {
        if cardType != .colorPalette && cardType != .text {
            EditorGroup {
                FieldLabel("Image", icon: "photo")

                imageWell

                HStack(spacing: 8) {
                    mediaButton("Browse…", icon: "folder") { browseForImage() }
                    mediaButton("Paste", icon: "doc.on.clipboard") {
                        pasteFromClipboard()
                    }
                    Spacer()
                }

                EditorTextField(placeholder: "Image path or URL",
                                text: optionalBinding(\.imagePath))

                if let error = imageLoadError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }

            EditorGroup {
                FieldLabel("Generate with AI", icon: "sparkles")
                aiGenerateRow
            }
        }

        if cardType == .video {
            EditorGroup {
                FieldLabel("Video URL", icon: "video")
                EditorTextField(placeholder: "YouTube or video URL",
                                text: optionalBinding(\.videoUrl))
                Text("Supports YouTube, Vimeo, and direct video URLs")
                    .font(.system(size: 10))
                    .foregroundColor(EditorTheme.secondary)
            }
        }

        EditorGroup {
            FieldLabel("Source URL", icon: "link")
            EditorTextField(placeholder: "Original source URL",
                            text: optionalBinding(\.sourceUrl))
        }
    }

    /// Prompt + Generate button; shared by simple mode and the Media tab.
    @ViewBuilder
    private var aiGenerateRow: some View {
        HStack(spacing: 8) {
            EditorTextField(placeholder: "Describe an image to generate…",
                            text: $aiPrompt)

            Button {
                generateAIImage()
            } label: {
                HStack(spacing: 5) {
                    if isGeneratingImage {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(isGeneratingImage ? "Generating…" : "Generate")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(EditorTheme.accentGradient)
                    .opacity(aiPrompt.isEmpty || isGeneratingImage
                             || onGenerateImage == nil ? 0.4 : 1))
            }
            .buttonStyle(.plain)
            .disabled(aiPrompt.isEmpty || isGeneratingImage
                      || onGenerateImage == nil)
        }

        Text("Renders a cinematic 16:9 reference straight onto this card.")
            .font(.system(size: 10))
            .foregroundColor(EditorTheme.secondary)
    }

    private var imageWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#101012"))

            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoadingImage {
                ProgressView()
                    .controlSize(.small)
            } else {
                VStack(spacing: 7) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 26))
                    Text("Browse, paste, or generate an image")
                        .font(.system(size: 11))
                }
                .foregroundColor(EditorTheme.secondary)
            }
        }
        .frame(height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            if previewImage == nil {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundColor(EditorTheme.secondary.opacity(0.4))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(EditorTheme.stroke, lineWidth: 1)
            }
        }
    }

    private func mediaButton(_ title: String, icon: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(EditorTheme.field))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(EditorTheme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tags Tab

    @ViewBuilder
    private var tagsTab: some View {
        tagEditor(title: "Tags", icon: "tag", tags: $card.tags)
        tagEditor(title: "Props", icon: "shippingbox", tags: $card.props)
        tagEditor(title: "Costumes", icon: "tshirt", tags: $card.costumes)
        tagEditor(title: "Effects", icon: "wand.and.stars", tags: $card.effects)
    }

    @ViewBuilder
    private func tagEditor(title: String, icon: String,
                           tags: Binding<[String]>) -> some View {
        EditorGroup {
            FieldLabel(title, icon: icon)

            CardEditorFlowLayout(spacing: 6) {
                ForEach(tags.wrappedValue, id: \.self) { tag in
                    HStack(spacing: 5) {
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                        Button {
                            tags.wrappedValue.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .overlay(Capsule()
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                    .foregroundColor(.accentColor)
                }

                AddTagField { newTag in
                    if !newTag.isEmpty && !tags.wrappedValue.contains(newTag) {
                        tags.wrappedValue.append(newTag)
                    }
                }
            }
        }
    }

    // MARK: - Scene Tab

    @ViewBuilder
    private var sceneTab: some View {
        EditorGroup {
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Sequence", icon: "film.stack")
                EditorTextField(placeholder: "Sequence name",
                                text: optionalBinding(\.sequenceName))
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Scene", icon: "film")
                EditorTextField(placeholder: "Scene name",
                                text: optionalBinding(\.sceneName))
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Character", icon: "person")
                EditorTextField(placeholder: "Character name",
                                text: optionalBinding(\.character))
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var editorFooter: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(EditorTheme.field))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(EditorTheme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                onSave?()
                isPresented = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text(isNew ? "Create Card" : "Save Changes")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(EditorTheme.accentGradient))
                .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(EditorTheme.panel)
    }

    // MARK: - Computed

    private var cardType: VisionCardType {
        VisionCardType(rawValue: card.cardType) ?? .image
    }

    /// Binding into an optional string field — empty text stores nil.
    private func optionalBinding(
        _ keyPath: WritableKeyPath<VisionCard, String?>
    ) -> Binding<String> {
        Binding(
            get: { card[keyPath: keyPath] ?? "" },
            set: { card[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Actions

    /// Owner request: pick an existing project location — fills title,
    /// primary image, and description in one step.
    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("Project location", icon: "mappin")
            Picker("", selection: Binding(
                get: { locations.first { $0.name == card.title }?.name ?? "" },
                set: { name in applyLocation(named: name) }
            )) {
                Text("Choose a location…").tag("")
                ForEach(locations, id: \.name) { location in
                    Text(location.name).tag(location.name)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 240)
        }
    }

    private func applyLocation(named name: String) {
        guard let location = locations.first(where: { $0.name == name }) else {
            return
        }
        card.title = location.name
        if let image = location.primaryImage, !image.isEmpty {
            card.imagePath = image
        }
        if card.description.isEmpty {
            card.description = location.description
        }
        loadPreviewImage()
    }

    /// Roadmap #4: multi-select add for shot-strip frames. Files are
    /// imported into the project immediately when a store exists so the
    /// stored paths are relative; absolute otherwise (legacy-resolvable).
    private func addStripFrames() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let store = assetStore,
               let relative = try? store.importExternal(url) {
                card.imagePaths.append(relative)
            } else {
                card.imagePaths.append(url.path)
            }
        }
    }

    private func browseForImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            card.imagePath = url.path
            loadPreviewImage()
        }
    }

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general

        // Try to get image directly
        if let image = NSImage(pasteboard: pasteboard),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {

            // Staged (finalized into the project only on Save); OS temp
            // fallback when the project has never been saved to disk.
            do {
                let fileURL: URL
                if let store = assetStore {
                    fileURL = try store.stagePastedPNG(pngData)
                } else {
                    fileURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("pasted_\(UUID().uuidString).png")
                    try pngData.write(to: fileURL)
                }
                card.imagePath = fileURL.path
                loadPreviewImage()
            } catch {
                imageLoadError = "Failed to save pasted image"
            }
        }
        // Try to get URL
        else if let urlString = pasteboard.string(forType: .string),
                urlString.hasPrefix("http") {
            card.imagePath = urlString
            loadPreviewImage()
        }
    }

    private func loadPreviewImage() {
        guard let path = card.imagePath, !path.isEmpty else {
            previewImage = nil
            return
        }

        isLoadingImage = true
        imageLoadError = nil

        switch VisionImageRef.classify(path) {
        case .none:
            previewImage = nil
            isLoadingImage = false
        case .remote(let url):
            // Async fetch — the old sync Data(contentsOf:) blocked a
            // worker thread for the full network timeout.
            Task {
                let data = try? await URLSession.shared.data(from: url).0
                await MainActor.run {
                    finishPreviewLoad(data.flatMap { NSImage(data: $0) })
                }
            }
        case .legacyAbsolute, .relative:
            if let url = VisionBoardImagePath.resolveImageURL(
                path, projectBase: assetStore?.projectBase) {
                Task.detached(priority: .userInitiated) {
                    let data = try? Data(contentsOf: url)
                    await MainActor.run {
                        finishPreviewLoad(data.flatMap { NSImage(data: $0) })
                    }
                }
            } else {
                finishPreviewLoad(nil)
            }
        }
    }

    private func finishPreviewLoad(_ image: NSImage?) {
        previewImage = image
        isLoadingImage = false
        imageLoadError = image == nil ? "Could not load image" : nil
    }

    private func generateAIImage() {
        guard let generator = onGenerateImage else { return }

        isGeneratingImage = true

        generator(aiPrompt) { url in
            DispatchQueue.main.async {
                isGeneratingImage = false
                if let url = url {
                    card.imagePath = url.path
                    loadPreviewImage()
                }
            }
        }
    }
}

// MARK: - Editor Tab

private enum EditorTab: String, CaseIterable {
    case general = "General"
    case media = "Media"
    case tags = "Tags"
    case scene = "Scene"
}

// MARK: - Add Tag Field

private struct AddTagField: View {
    @State private var newTag: String = ""
    var onAdd: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField("Add…", text: $newTag)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(width: 64)
                .onSubmit {
                    onAdd(newTag)
                    newTag = ""
                }

            if !newTag.isEmpty {
                Button {
                    onAdd(newTag)
                    newTag = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(
            Color.white.opacity(0.1),
            style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

// MARK: - Card Editor Flow Layout

private struct CardEditorFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }

            height = y + rowHeight
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VisionCardEditor_Previews: PreviewProvider {
    @State static var card = VisionCard(
        title: "Test Card",
        description: "A test vision card",
        cardType: "image"
    )
    @State static var isPresented = true

    static var previews: some View {
        VisionCardEditor(card: $card, isPresented: $isPresented)
    }
}
#endif
