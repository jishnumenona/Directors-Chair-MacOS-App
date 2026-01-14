// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionCardEditor.swift
//
// Vision Card Editor - Dialog for Creating and Editing Vision Cards
// Supports all card types: image, text, color palette, video, etc.

import SwiftUI
import DirectorsChairCore
import UniformTypeIdentifiers

// MARK: - Vision Card Editor

public struct VisionCardEditor: View {
    // MARK: - Properties

    @Binding public var card: VisionCard
    @Binding public var isPresented: Bool

    /// Callback when save is pressed
    public var onSave: (() -> Void)?

    /// Callback for AI image generation
    public var onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)?

    // MARK: - State

    @State private var selectedTab: EditorTab = .general
    @State private var isLoadingImage: Bool = false
    @State private var imageLoadError: String?
    @State private var newColorHex: String = "#"
    @State private var showColorPicker: Bool = false
    @State private var aiPrompt: String = ""
    @State private var isGeneratingImage: Bool = false
    @State private var previewImage: NSImage?

    // MARK: - Init

    public init(
        card: Binding<VisionCard>,
        isPresented: Binding<Bool>,
        onSave: (() -> Void)? = nil,
        onGenerateImage: ((String, @escaping (URL?) -> Void) -> Void)? = nil
    ) {
        self._card = card
        self._isPresented = isPresented
        self.onSave = onSave
        self.onGenerateImage = onGenerateImage
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            editorHeader

            Divider()

            // Content
            HStack(spacing: 0) {
                // Left sidebar - card type selection and preview
                leftSidebar
                    .frame(width: 200)

                Divider()

                // Main editor area
                mainEditorArea
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Footer with actions
            editorFooter
        }
        .frame(width: 700, height: 550)
        .background(Color(hex: "#252525"))
        .onAppear {
            loadPreviewImage()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var editorHeader: some View {
        HStack {
            Text(card.id.isEmpty ? "New Vision Card" : "Edit Vision Card")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Card type badge
            Label(cardType.displayName, systemImage: cardType.systemImage)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.2))
                .foregroundColor(.accentColor)
                .cornerRadius(4)
        }
        .padding()
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Left Sidebar

    @ViewBuilder
    private var leftSidebar: some View {
        VStack(spacing: 16) {
            // Card type picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Type")
                    .font(.caption)
                    .foregroundColor(.gray)

                Picker("Type", selection: $card.cardType) {
                    ForEach(VisionCardType.allCases) { type in
                        Label(type.displayName, systemImage: type.systemImage)
                            .tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Divider()

            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.gray)

                previewArea
                    .frame(height: 150)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
            }

            Divider()

            // Size options
            VStack(alignment: .leading, spacing: 8) {
                Text("Size")
                    .font(.caption)
                    .foregroundColor(.gray)

                Picker("Size", selection: $card.size) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
            }

            // Pinned toggle
            Toggle("Pin to Top", isOn: $card.pinned)
                .font(.caption)

            Spacer()
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
    }

    // MARK: - Preview Area

    @ViewBuilder
    private var previewArea: some View {
        switch cardType {
        case .image, .texture, .lighting, .location:
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let imagePath = card.imagePath, !imagePath.isEmpty {
                ProgressView()
            } else {
                VStack {
                    Image(systemName: cardType.systemImage)
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No image")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

        case .colorPalette:
            if card.colorPalette.isEmpty {
                Text("No colors")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                HStack(spacing: 2) {
                    ForEach(card.colorPalette.prefix(5), id: \.self) { hex in
                        Rectangle()
                            .fill(Color(hex: hex))
                    }
                }
            }

        case .text:
            Text(card.text.isEmpty ? "Enter text..." : card.text)
                .font(.caption)
                .foregroundColor(Color(hex: card.textColor))
                .lineLimit(5)
                .padding(8)

        case .video:
            VStack {
                Image(systemName: "video.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                if let url = card.videoUrl, !url.isEmpty {
                    Text(url)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    // MARK: - Main Editor Area

    @ViewBuilder
    private var mainEditorArea: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(EditorTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                            .foregroundColor(selectedTab == tab ? .accentColor : .gray)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding()
            }
        }
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Card title", text: $card.title)
                    .textFieldStyle(.roundedBorder)
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextEditor(text: $card.description)
                    .frame(height: 80)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(hex: "#1E1E1E"))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }

            // Department
            VStack(alignment: .leading, spacing: 4) {
                Text("Department")
                    .font(.caption)
                    .foregroundColor(.gray)
                Picker("Department", selection: Binding(
                    get: { card.department ?? "" },
                    set: { card.department = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    ForEach(VisionDepartment.allCases) { dept in
                        Text(dept.displayName).tag(dept.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            // Credit (for images)
            if cardType == .image || cardType == .texture || cardType == .lighting {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Credit / Source")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Photographer or artist credit", text: Binding(
                        get: { card.credit ?? "" },
                        set: { card.credit = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            // Text content (for text cards)
            if cardType == .text {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text Content")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextEditor(text: $card.text)
                        .frame(height: 120)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(Color(hex: "#1E1E1E"))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                // Text color
                HStack {
                    Text("Text Color")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: card.textColor) },
                        set: { card.textColor = $0.toHex() ?? "#FFFFFF" }
                    ))
                    .labelsHidden()
                    Text(card.textColor)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Color palette (for color cards)
            if cardType == .colorPalette {
                colorPaletteEditor
            }
        }
    }

    // MARK: - Color Palette Editor

    @ViewBuilder
    private var colorPaletteEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Palette")
                .font(.caption)
                .foregroundColor(.gray)

            // Color swatches
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                ForEach(card.colorPalette, id: \.self) { hexColor in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(Color(hex: hexColor))
                            .frame(height: 40)
                            .cornerRadius(4)
                            .overlay(
                                Button {
                                    card.colorPalette.removeAll { $0 == hexColor }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(4),
                                alignment: .topTrailing
                            )
                        Text(hexColor)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }

                // Add color button
                Button {
                    showColorPicker = true
                } label: {
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.gray)
                            .frame(height: 40)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundColor(.gray)
                            )
                        Text("Add")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(.plain)
            }

            // Color picker popover
            if showColorPicker {
                HStack {
                    TextField("#RRGGBB", text: $newColorHex)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    ColorPicker("", selection: Binding(
                        get: { Color(hex: newColorHex) },
                        set: { newColorHex = $0.toHex() ?? "#FFFFFF" }
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
                }
            }
        }
    }

    // MARK: - Media Tab

    @ViewBuilder
    private var mediaTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Image path
            if cardType != .colorPalette && cardType != .text {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack {
                        TextField("Image path or URL", text: Binding(
                            get: { card.imagePath ?? "" },
                            set: { card.imagePath = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            browseForImage()
                        }

                        Button("Paste") {
                            pasteFromClipboard()
                        }
                    }

                    if let error = imageLoadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // AI Image Generation
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Generate")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack {
                        TextField("Describe the image...", text: $aiPrompt)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            generateAIImage()
                        } label: {
                            if isGeneratingImage {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Generate")
                            }
                        }
                        .disabled(aiPrompt.isEmpty || isGeneratingImage || onGenerateImage == nil)
                    }
                }
            }

            // Video URL
            if cardType == .video {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video URL")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("YouTube or video URL", text: Binding(
                        get: { card.videoUrl ?? "" },
                        set: { card.videoUrl = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Text("Supports YouTube, Vimeo, and direct video URLs")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            // Source URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Source URL")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Original source URL", text: Binding(
                    get: { card.sourceUrl ?? "" },
                    set: { card.sourceUrl = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Tags Tab

    @ViewBuilder
    private var tagsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tags
            tagEditor(title: "Tags", tags: $card.tags)

            Divider()

            // Props (for production reference)
            tagEditor(title: "Props", tags: $card.props)

            Divider()

            // Costumes
            tagEditor(title: "Costumes", tags: $card.costumes)

            Divider()

            // Effects
            tagEditor(title: "Effects", tags: $card.effects)
        }
    }

    @ViewBuilder
    private func tagEditor(title: String, tags: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            // Tag pills
            CardEditorFlowLayout(spacing: 4) {
                ForEach(tags.wrappedValue, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                        Button {
                            tags.wrappedValue.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(12)
                }

                // Add tag field
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
        VStack(alignment: .leading, spacing: 16) {
            // Sequence
            VStack(alignment: .leading, spacing: 4) {
                Text("Sequence")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Sequence name", text: Binding(
                    get: { card.sequenceName ?? "" },
                    set: { card.sequenceName = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Scene
            VStack(alignment: .leading, spacing: 4) {
                Text("Scene")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Scene name", text: Binding(
                    get: { card.sceneName ?? "" },
                    set: { card.sceneName = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Character
            VStack(alignment: .leading, spacing: 4) {
                Text("Character")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Character name", text: Binding(
                    get: { card.character ?? "" },
                    set: { card.character = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var editorFooter: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save") {
                onSave?()
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Computed

    private var cardType: VisionCardType {
        VisionCardType(rawValue: card.cardType) ?? .image
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

            // Save to temp location
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "pasted_\(UUID().uuidString).png"
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try pngData.write(to: fileURL)
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

        DispatchQueue.global(qos: .userInitiated).async {
            var image: NSImage?

            if path.hasPrefix("http") {
                // Load from URL
                if let url = URL(string: path),
                   let data = try? Data(contentsOf: url) {
                    image = NSImage(data: data)
                }
            } else {
                // Load from file
                image = NSImage(contentsOfFile: path)
            }

            DispatchQueue.main.async {
                self.previewImage = image
                self.isLoadingImage = false
                if image == nil && !path.isEmpty {
                    self.imageLoadError = "Could not load image"
                }
            }
        }
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
            TextField("Add...", text: $newTag)
                .textFieldStyle(.plain)
                .frame(width: 60)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
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

// MARK: - Color Extension for Hex Conversion

extension Color {
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components else {
            return nil
        }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
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
