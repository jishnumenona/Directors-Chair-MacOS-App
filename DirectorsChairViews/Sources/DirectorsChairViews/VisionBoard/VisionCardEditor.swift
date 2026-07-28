// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionCardEditor.swift
//
// Vision Card Editor - Dialog for Creating and Editing Vision Cards
// Supports all card types: image, text, color palette, video, etc.
// Redesigned 2026-07: layered dark surfaces, card-type chip grid, sliding
// pill tabs, focus-ring fields, image well — same data flow underneath
// (Slice-2 staging pipeline, AI generation, palette/tag editing).

import SwiftUI
import DirectorsChairCore
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

    // MARK: - State

    @State private var selectedTab: EditorTab = .general
    @State private var isLoadingImage: Bool = false
    @State private var imageLoadError: String?
    @State private var newColorHex: String = "#"
    @State private var showColorPicker: Bool = false
    @State private var aiPrompt: String = ""
    @State private var isGeneratingImage: Bool = false
    @State private var previewImage: NSImage?
    @Namespace private var tabNamespace

    // MARK: - Init

    public init(
        card: Binding<VisionCard>,
        isPresented: Binding<Bool>,
        onSave: (() -> Void)? = nil,
        onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)? = nil,
        assetStore: VisionBoardAssetStore? = nil,
        isNew: Bool = false
    ) {
        self._card = card
        self._isPresented = isPresented
        self.onSave = onSave
        self.onGenerateImage = onGenerateImage
        self.assetStore = assetStore
        self.isNew = isNew
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            editorHeader

            Divider().overlay(EditorTheme.stroke)

            HStack(spacing: 0) {
                leftSidebar
                    .frame(width: 224)

                Divider().overlay(EditorTheme.stroke)

                mainEditorArea
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider().overlay(EditorTheme.stroke)

            editorFooter
        }
        .frame(width: 760, height: 600)
        .background(EditorTheme.window)
        .onAppear {
            loadPreviewImage()
        }
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(EditorTheme.panel)
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
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                card.cardType = type.rawValue
            }
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
            .foregroundColor(selected ? .accentColor : EditorTheme.secondary)
        }
        .buttonStyle(.plain)
        .help(type.displayName)
    }

    // MARK: - Preview Area

    @ViewBuilder
    private var previewArea: some View {
        switch cardType {
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
            // title fallback.
            let posterText = [card.text, card.description, card.title]
                .first { !$0.isEmpty } ?? ""
            if posterText.isEmpty {
                Text("Enter text…")
                    .font(.system(size: 11))
                    .foregroundColor(EditorTheme.secondary)
            } else {
                Text(posterText)
                    .font(.system(size: 80, weight: .bold))
                    .minimumScaleFactor(0.05)
                    .foregroundColor(Color(hex: card.textColor))
                    .multilineTextAlignment(.center)
                    .padding(10)
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

            if cardType == .image || cardType == .texture || cardType == .lighting {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Credit / Source")
                    EditorTextField(placeholder: "Photographer or artist credit",
                                    text: optionalBinding(\.credit))
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

                HStack(spacing: 8) {
                    EditorTextField(placeholder: "Describe the image…",
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
