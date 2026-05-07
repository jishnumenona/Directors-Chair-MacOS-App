// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/PhysicalAppearanceTab.swift
//
// Physical appearance editor tab - game character customizer style

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

/// Physical appearance tab - game character customizer style
///
/// Displays:
/// - Height, weight, build
/// - Hair (color, style, length)
/// - Eyes (color, shape)
/// - Skin tone, ethnicity
/// - Distinguishing features
/// - Character images (multiple angles)
public struct PhysicalAppearanceTab: View {
    @Binding var character: Character
    let projectBasePath: URL?

    // Callbacks for AI operations
    var onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)?  // (angle, prompt, progressHandler)
    var onAnalyzeTraits: (() -> Void)?
    var onUploadReferenceImage: ((Data, @escaping @MainActor (Double) -> Void) -> Void)?

    // State for full screen image viewer
    @State private var showingFullScreenImage = false
    @State private var fullScreenImageURL: URL?
    @State private var fullScreenImageTitle: String = ""

    // State for discovered images (auto-detect from filesystem)
    @State private var discoveredImages: DiscoveredCharacterImages = DiscoveredCharacterImages()

    // Per-angle generation progress (nil = idle, 0.0-1.0 = generating)
    @State private var generatingProgress: [String: Double] = [:]
    // Cache-busting IDs to force AsyncImage reload after regeneration
    @State private var imageRefreshIds: [String: UUID] = [:]

    // Hover state for base image overlay
    @State private var isHoveringBaseImage = false

    // Reference image upload state
    @State private var isAnalyzingUpload = false
    @State private var analysisProgress: Double = 0

    // Annotation editor state
    @State private var showingAnnotationEditor = false
    @State private var annotationEditorImage: NSImage?
    @State private var annotationEditorAngle: String = ""
    @State private var annotationEditorTitle: String = ""
    @State private var annotationEditorImageType: ImageType = .base

    public init(
        character: Binding<Character>,
        projectBasePath: URL? = nil,
        onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil,
        onAnalyzeTraits: (() -> Void)? = nil,
        onUploadReferenceImage: ((Data, @escaping @MainActor (Double) -> Void) -> Void)? = nil
    ) {
        self._character = character
        self.projectBasePath = projectBasePath
        self.onGenerateImage = onGenerateImage
        self.onAnalyzeTraits = onAnalyzeTraits
        self.onUploadReferenceImage = onUploadReferenceImage
    }

    /// Get effective image path - uses character property if set, otherwise discovered image
    private func effectiveImagePath(for type: ImageType) -> String? {
        switch type {
        case .base:
            return character.baseImage ?? discoveredImages.baseImage
        case .front:
            return character.imageFront ?? discoveredImages.front
        case .threeQuarterLeft:
            return character.imageThreeQuarterLeft ?? discoveredImages.threeQuarterLeft
        case .threeQuarterRight:
            return character.imageThreeQuarterRight ?? discoveredImages.threeQuarterRight
        case .profileLeft:
            return character.imageProfileLeft ?? discoveredImages.profileLeft
        case .profileRight:
            return character.imageProfileRight ?? discoveredImages.profileRight
        case .back:
            return character.imageBack ?? discoveredImages.back
        }
    }

    private enum ImageType {
        case base, front, threeQuarterLeft, threeQuarterRight, profileLeft, profileRight, back
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left: Character image gallery
                imageGallerySection
                    .frame(width: min(350, geometry.size.width * 0.35))

                Divider()

                // Right: Attribute editors
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        identityHeader

                        bodyMeasurementsSection

                        HStack(alignment: .top, spacing: 16) {
                            hairSection
                            eyesSection
                        }

                        HStack(alignment: .top, spacing: 16) {
                            skinSection
                            faceStructureSection
                        }

                        distinguishingFeaturesSection
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            discoveredImages = DiscoveredCharacterImages.discover(
                for: character.name,
                basePath: projectBasePath
            )
        }
        .onChange(of: character.name) { newName in
            discoveredImages = DiscoveredCharacterImages.discover(
                for: newName,
                basePath: projectBasePath
            )
        }
        .sheet(isPresented: $showingFullScreenImage) {
            FullScreenImageViewer(
                imageURL: fullScreenImageURL,
                title: fullScreenImageTitle,
                onDownload: {
                    if let url = fullScreenImageURL {
                        downloadImage(from: url, suggestedName: "\(character.name)_image.png")
                    }
                }
            )
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = annotationEditorImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT CHARACTER — \(annotationEditorTitle.uppercased())",
                    subtitle: character.name,
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generateAngleWithAnnotations(angle: annotationEditorAngle, annotations: annotations)
                    }
                )
            }
        }
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        HStack(spacing: 16) {
            // Age badge
            VStack(spacing: 2) {
                Text("AGE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                TextField("", value: $character.age, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
            )

            // Gender selector
            VStack(alignment: .leading, spacing: 6) {
                Text("GENDER")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                HStack(spacing: 6) {
                    GenderChip(label: "Male", icon: "figure.stand", isSelected: character.gender == "male") {
                        character.gender = "male"
                    }
                    GenderChip(label: "Female", icon: "figure.stand.dress", isSelected: character.gender == "female") {
                        character.gender = "female"
                    }
                    GenderChip(label: "Neutral", icon: "figure.wave", isSelected: character.gender == "neutral") {
                        character.gender = "neutral"
                    }
                    GenderChip(label: "Other", icon: "person.fill.questionmark", isSelected: character.gender == "other") {
                        character.gender = "other"
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Body Measurements

    private var bodyMeasurementsSection: some View {
        AttributeCard(title: "BODY", icon: "figure.arms.open") {
            VStack(spacing: 16) {
                // Height and Weight side by side
                HStack(spacing: 16) {
                    // Height
                    MeasurementField(
                        label: "Height",
                        unit: "cm",
                        value: $character.heightCm,
                        icon: "ruler",
                        range: 100...250
                    )

                    // Weight
                    MeasurementField(
                        label: "Weight",
                        unit: "kg",
                        value: $character.weightKg,
                        icon: "scalemass",
                        range: 30...200
                    )
                }

                // Build selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Build")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        BuildChip(label: "Slim", icon: "figure.stand", isSelected: character.build == "Slim") {
                            character.build = "Slim"
                        }
                        BuildChip(label: "Athletic", icon: "figure.run", isSelected: character.build == "Athletic") {
                            character.build = "Athletic"
                        }
                        BuildChip(label: "Average", icon: "figure.stand", isSelected: character.build == "Average") {
                            character.build = "Average"
                        }
                        BuildChip(label: "Stocky", icon: "figure.strengthtraining.traditional", isSelected: character.build == "Stocky") {
                            character.build = "Stocky"
                        }
                        BuildChip(label: "Heavy", icon: "figure.arms.open", isSelected: character.build == "Heavy") {
                            character.build = "Heavy"
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hair Section

    private var hairSection: some View {
        AttributeCard(title: "HAIR", icon: "comb") {
            VStack(spacing: 14) {
                // Color row
                HStack(spacing: 10) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: character.hairColor) },
                        set: { character.hairColor = $0.hexString }
                    ))
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Color")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(character.hairColor.isEmpty ? "Not set" : character.hairColor)
                            .font(.system(size: 12))
                            .foregroundColor(character.hairColor.isEmpty ? .secondary : .primary)
                    }

                    Spacer()
                }

                Divider().opacity(0.5)

                // Length
                VStack(alignment: .leading, spacing: 6) {
                    Text("Length")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        ForEach(["Bald", "Short", "Medium", "Long", "Very Long"], id: \.self) { length in
                            CompactChip(label: length, isSelected: character.hairLength == length) {
                                character.hairLength = length
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Style
                VStack(alignment: .leading, spacing: 6) {
                    Text("Style")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g., Wavy, tied up", text: $character.hairStyle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Eyes Section

    private var eyesSection: some View {
        AttributeCard(title: "EYES", icon: "eye") {
            VStack(spacing: 14) {
                // Color row
                HStack(spacing: 10) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: character.eyeColor) },
                        set: { character.eyeColor = $0.hexString }
                    ))
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Color")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("e.g., Brown, Hazel", text: $character.eyeColorDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                    }

                    Spacer()
                }

                Divider().opacity(0.5)

                // Shape
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shape")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    let shapes = ["Almond", "Round", "Hooded", "Monolid", "Deep-set", "Upturned", "Downturned"]
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 72), spacing: 4)
                    ], spacing: 4) {
                        ForEach(shapes, id: \.self) { shape in
                            CompactChip(label: shape, isSelected: character.eyeShape == shape) {
                                character.eyeShape = shape
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Skin Section

    private var skinSection: some View {
        AttributeCard(title: "SKIN", icon: "hand.raised") {
            VStack(spacing: 14) {
                // Tone row
                HStack(spacing: 10) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: character.skinTone) },
                        set: { character.skinTone = $0.hexString }
                    ))
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tone")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(character.skinTone.isEmpty ? "Not set" : character.skinTone)
                            .font(.system(size: 12))
                            .foregroundColor(character.skinTone.isEmpty ? .secondary : .primary)
                    }

                    Spacer()
                }

                Divider().opacity(0.5)

                // Ethnicity
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ethnicity")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g., South Asian, Caucasian", text: $character.ethnicity)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Face Structure Section

    private var faceStructureSection: some View {
        AttributeCard(title: "FACE", icon: "face.dashed") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Facial Structure")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    let structures = ["Oval", "Round", "Square", "Heart", "Oblong", "Diamond"]
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 68), spacing: 4)
                    ], spacing: 4) {
                        ForEach(structures, id: \.self) { structure in
                            FaceShapeChip(
                                label: structure,
                                isSelected: character.facialStructure == structure
                            ) {
                                character.facialStructure = structure
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Distinguishing Features Section

    private var distinguishingFeaturesSection: some View {
        AttributeCard(title: "DISTINGUISHING FEATURES", icon: "sparkle") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scars, tattoos, birthmarks, or other notable physical features")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                TextEditor(text: $character.distinguishingFeatures)
                    .font(.system(size: 12))
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Image Style Section

    private static let imageStyles: [(name: String, icon: String, description: String)] = [
        ("Photorealistic", "camera.fill", "Photo-quality realistic rendering"),
        ("Cinematic", "film", "Dramatic movie-style lighting and composition"),
        ("Illustration", "paintbrush.pointed.fill", "Hand-drawn digital illustration"),
        ("Anime", "sparkles", "Japanese anime / manga style"),
        ("Comic Book", "book.fill", "Bold outlines, comic panel style"),
        ("Watercolor", "drop.fill", "Soft watercolor painting"),
        ("Oil Painting", "paintpalette.fill", "Classical oil painting style"),
        ("3D Render", "cube.fill", "3D CGI rendered character"),
    ]

    private var imageStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("IMAGE STYLE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], spacing: 6) {
                ForEach(Self.imageStyles, id: \.name) { style in
                    let isSelected = character.imageStyle == style.name
                    Button {
                        character.imageStyle = style.name
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: style.icon)
                                .font(.system(size: 12))
                            Text(style.name)
                                .font(.system(size: 8, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(style.description)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Image Gallery Section

    private var imageGallerySection: some View {
        ScrollView {
        VStack(spacing: 12) {
            // Image style selector
            imageStyleSection

            // Main image display
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 300)

                if let imagePath = effectiveImagePath(for: .base),
                   let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(imagePath)
                    AsyncImage(url: fullPath) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            placeholderImage
                        case .empty:
                            ProgressView()
                        @unknown default:
                            placeholderImage
                        }
                    }
                    .id(imageRefreshIds["base"] ?? UUID())

                    // Hover overlay with icon buttons
                    if isHoveringBaseImage || generatingProgress["base"] != nil {
                        VStack {
                            HStack {
                                Spacer()
                                if generatingProgress["base"] == nil {
                                    Button(action: {
                                        fullScreenImageURL = fullPath
                                        fullScreenImageTitle = "\(character.name) - Base Image"
                                        showingFullScreenImage = true
                                    }) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("View full size")

                                    Button(action: {
                                        openAnnotationEditor(angle: "base", label: "Base Image", imageType: .base)
                                    }) {
                                        Image(systemName: "pencil.and.outline")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Annotate & edit image")

                                    Button(action: {
                                        downloadImage(from: fullPath, suggestedName: "\(character.name)_base.png")
                                    }) {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Download image")

                                    Button(action: {
                                        deleteBaseImage(at: fullPath)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.red.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete base image")
                                }

                                Button(action: {
                                    generateAngleImage(angle: "base", prompt: buildImagePrompt())
                                }) {
                                    ZStack {
                                        if generatingProgress["base"] != nil {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.6)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: 27, height: 27)
                                    .background(generatingProgress["base"] != nil ? Color.accentColor.opacity(0.8) : Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(generatingProgress["base"] != nil)
                                .help(generatingProgress["base"] != nil ? "Generating..." : "Regenerate base image")
                            }
                            .padding(12)
                            Spacer()
                        }
                    }
                } else {
                    placeholderImage
                }

                // Base image generation progress overlay
                if let progress = generatingProgress["base"] {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 300)
                    GenerationProgressRing(progress: progress)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringBaseImage = hovering
                }
            }

            // Analysis overlay when processing uploaded image
            if isAnalyzingUpload {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 300)
                    VStack(spacing: 12) {
                        GenerationProgressRing(progress: analysisProgress)
                        Text("Analyzing image...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }

            // Generate / Upload buttons
            if effectiveImagePath(for: .base) == nil {
                // No base image: show Generate + upload options
                GalleryButton(
                    label: generatingProgress["base"] != nil ? "Generating..." : "Generate Base Image",
                    icon: generatingProgress["base"] != nil ? "hourglass" : "wand.and.stars",
                    color: .accentColor,
                    isProminent: true
                ) {
                    generateAngleImage(angle: "base", prompt: buildImagePrompt())
                }
                .disabled(generatingProgress["base"] != nil)
                .help("AI: Generate a base character image")

                // Divider with "or upload"
                HStack(spacing: 8) {
                    Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 1)
                    Text("or upload")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 1)
                }

                HStack(spacing: 8) {
                    GalleryButton(
                        label: "Browse Image...",
                        icon: "folder",
                        color: .accentColor
                    ) {
                        browseForImage()
                    }
                    .disabled(isAnalyzingUpload)

                    GalleryButton(
                        label: "Paste from Clipboard",
                        icon: "doc.on.clipboard",
                        color: .accentColor
                    ) {
                        pasteFromClipboard()
                    }
                    .disabled(isAnalyzingUpload)
                }
            } else {
                // Base image exists: compact upload row
                HStack(spacing: 8) {
                    GalleryButton(
                        label: "Browse",
                        icon: "folder",
                        color: .secondary
                    ) {
                        browseForImage()
                    }
                    .disabled(isAnalyzingUpload)

                    GalleryButton(
                        label: "Paste",
                        icon: "doc.on.clipboard",
                        color: .secondary
                    ) {
                        pasteFromClipboard()
                    }
                    .disabled(isAnalyzingUpload)

                    Spacer()
                }
            }

            // Angle section header
            HStack(spacing: 6) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("CHARACTER ANGLES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                Spacer()
                Text("\(angleImageCount)/6")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(nsColor: .quaternarySystemFill)))
            }
            .padding(.top, 4)

            // Angle thumbnails grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 10) {
                AngleThumbnail(
                    label: "Front",
                    imagePath: effectiveImagePath(for: .front),
                    projectBasePath: projectBasePath,
                    characterName: character.name,
                    generationProgress: generatingProgress["front"],
                    refreshId: imageRefreshIds["front"],
                    onView: { url in
                        fullScreenImageURL = url
                        fullScreenImageTitle = "\(character.name) - Front"
                        showingFullScreenImage = true
                    },
                    onDownload: { url in
                        downloadImage(from: url, suggestedName: "\(character.name)_front.png")
                    },
                    onGenerate: {
                        generateAngleImage(angle: "front", prompt: buildAnglePrompt(angle: "front facing view, looking directly at camera"))
                    },
                    onEditAnnotate: {
                        openAnnotationEditor(angle: "front", label: "Front", imageType: .front)
                    }
                )
                AngleThumbnail(
                    label: "3/4 Left",
                    imagePath: effectiveImagePath(for: .threeQuarterLeft),
                    projectBasePath: projectBasePath,
                    characterName: character.name,
                    generationProgress: generatingProgress["three_quarter_left"],
                    refreshId: imageRefreshIds["three_quarter_left"],
                    onView: { url in
                        fullScreenImageURL = url
                        fullScreenImageTitle = "\(character.name) - Three Quarter Left"
                        showingFullScreenImage = true
                    },
                    onDownload: { url in
                        downloadImage(from: url, suggestedName: "\(character.name)_3q_left.png")
                    },
                    onGenerate: {
                        generateAngleImage(angle: "three_quarter_left", prompt: buildAnglePrompt(angle: "three-quarter view from the left side, head turned slightly left"))
                    },
                    onEditAnnotate: {
                        openAnnotationEditor(angle: "three_quarter_left", label: "3/4 Left", imageType: .threeQuarterLeft)
                    }
                )
                AngleThumbnail(
                    label: "3/4 Right",
                    imagePath: effectiveImagePath(for: .threeQuarterRight),
                    projectBasePath: projectBasePath,
                    characterName: character.name,
                    generationProgress: generatingProgress["three_quarter_right"],
                    refreshId: imageRefreshIds["three_quarter_right"],
                    onView: { url in
                        fullScreenImageURL = url
                        fullScreenImageTitle = "\(character.name) - Three Quarter Right"
                        showingFullScreenImage = true
                    },
                    onDownload: { url in
                        downloadImage(from: url, suggestedName: "\(character.name)_3q_right.png")
                    },
                    onGenerate: {
                        generateAngleImage(angle: "three_quarter_right", prompt: buildAnglePrompt(angle: "three-quarter view from the right side, head turned slightly right"))
                    },
                    onEditAnnotate: {
                        openAnnotationEditor(angle: "three_quarter_right", label: "3/4 Right", imageType: .threeQuarterRight)
                    }
                )
                AngleThumbnail(
                    label: "Profile Left",
                    imagePath: effectiveImagePath(for: .profileLeft),
                    projectBasePath: projectBasePath,
                    characterName: character.name,
                    generationProgress: generatingProgress["profile_left"],
                    refreshId: imageRefreshIds["profile_left"],
                    onView: { url in
                        fullScreenImageURL = url
                        fullScreenImageTitle = "\(character.name) - Profile Left"
                        showingFullScreenImage = true
                    },
                    onDownload: { url in
                        downloadImage(from: url, suggestedName: "\(character.name)_profile_left.png")
                    },
                    onGenerate: {
                        generateAngleImage(angle: "profile_left", prompt: buildAnglePrompt(angle: "left side profile view, face in complete profile"))
                    },
                    onEditAnnotate: {
                        openAnnotationEditor(angle: "profile_left", label: "Profile Left", imageType: .profileLeft)
                    }
                )
                AngleThumbnail(
                    label: "Profile Right",
                    imagePath: effectiveImagePath(for: .profileRight),
                    projectBasePath: projectBasePath,
                    characterName: character.name,
                    generationProgress: generatingProgress["profile_right"],
                    refreshId: imageRefreshIds["profile_right"],
                    onView: { url in
                        fullScreenImageURL = url
                        fullScreenImageTitle = "\(character.name) - Profile Right"
                        showingFullScreenImage = true
                    },
                    onDownload: { url in
                        downloadImage(from: url, suggestedName: "\(character.name)_profile_right.png")
                    },
                    onGenerate: {
                        generateAngleImage(angle: "profile_right", prompt: buildAnglePrompt(angle: "right side profile view, face in complete profile"))
                    },
                    onEditAnnotate: {
                        openAnnotationEditor(angle: "profile_right", label: "Profile Right", imageType: .profileRight)
                    }
                )
                AngleThumbnail(
                    label: "Back",
                    imagePath: effectiveImagePath(for: .back),
                    projectBasePath: projectBasePath,
                    characterName: character.name,
                    generationProgress: generatingProgress["back"],
                    refreshId: imageRefreshIds["back"],
                    onView: { url in
                        fullScreenImageURL = url
                        fullScreenImageTitle = "\(character.name) - Back"
                        showingFullScreenImage = true
                    },
                    onDownload: { url in
                        downloadImage(from: url, suggestedName: "\(character.name)_back.png")
                    },
                    onGenerate: {
                        generateAngleImage(angle: "back", prompt: buildAnglePrompt(angle: "back view, showing back of head and shoulders"))
                    },
                    onEditAnnotate: {
                        openAnnotationEditor(angle: "back", label: "Back", imageType: .back)
                    }
                )
            }

        }
        .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Delete Base Image

    private func deleteBaseImage(at url: URL) {
        guard let basePath = projectBasePath else { return }

        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to delete base image: \(error)")
            return
        }

        character.baseImage = nil
        imageRefreshIds["base"] = UUID()

        discoveredImages = DiscoveredCharacterImages.discover(
            for: character.name,
            basePath: projectBasePath
        )
    }

    // MARK: - Annotation Editor

    private func openAnnotationEditor(angle: String, label: String, imageType: ImageType) {
        guard let imagePath = effectiveImagePath(for: imageType),
              let basePath = projectBasePath else { return }
        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let image = NSImage(contentsOf: fullPath) else { return }
        annotationEditorImage = image
        annotationEditorAngle = angle
        annotationEditorTitle = label
        annotationEditorImageType = imageType
        showingAnnotationEditor = true
    }

    private func generateAngleWithAnnotations(angle: String, annotations: [KeyframeAnnotation]) {
        guard let imagePath = effectiveImagePath(for: annotationEditorImageType),
              let basePath = projectBasePath else { return }

        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let imageData = try? Data(contentsOf: fullPath) else { return }

        // Build edit prompt (same pattern as shot annotation)
        var promptParts: [String] = []
        promptParts.append("Edit this image by making the following changes while keeping everything else identical:")
        for ann in annotations.sorted(by: { $0.number < $1.number }) {
            let xPercent = Int(ann.normalizedX * 100)
            let yPercent = Int(ann.normalizedY * 100)
            promptParts.append("\(ann.number). \(ann.text) at position (\(xPercent)%, \(yPercent)%)")
        }
        let editPrompt = promptParts.joined(separator: "\n")

        let referenceBase64 = imageData.base64EncodedString()
        let request = ImageGenerationRequest(
            prompt: editPrompt,
            provider: .googleImagen,
            aspectRatio: "1:1",
            referenceImageBase64: referenceBase64,
            referenceMimeType: "image/png"
        )

        // Show progress
        generatingProgress[angle] = 0.0

        Task {
            do {
                let response = try await AIServiceClient.shared.generateImage(request)

                guard let newImageData = response.images.first else {
                    await MainActor.run {
                        generatingProgress.removeValue(forKey: angle)
                    }
                    return
                }

                // Save edited image back to the same path
                _ = basePath.startAccessingSecurityScopedResource()
                defer { basePath.stopAccessingSecurityScopedResource() }
                try newImageData.write(to: fullPath)

                await MainActor.run {
                    imageRefreshIds[angle] = UUID()
                    if angle == "base" {
                        imageRefreshIds["base"] = UUID()
                    }
                    withAnimation(.easeOut(duration: 0.3)) {
                        generatingProgress.removeValue(forKey: angle)
                    }
                    discoveredImages = DiscoveredCharacterImages.discover(
                        for: character.name,
                        basePath: projectBasePath
                    )
                }
            } catch {
                await MainActor.run {
                    generatingProgress.removeValue(forKey: angle)
                }
                print("Annotation edit failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Download Image

    private func downloadImage(from url: URL, suggestedName: String) {
        guard let imageData = try? Data(contentsOf: url) else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = suggestedName
        savePanel.title = "Save Image"
        savePanel.message = "Choose a location to save the image"

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                do {
                    try imageData.write(to: saveURL)
                } catch {
                    print("Failed to save image: \(error)")
                }
            }
        }
    }

    private var placeholderImage: some View {
        VStack {
            Image(systemName: "person.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Generate Angle Image (Background)

    private func generateAngleImage(angle: String, prompt: String) {
        guard generatingProgress[angle] == nil else { return } // Already generating
        generatingProgress[angle] = 0.0

        onGenerateImage?(angle, prompt) { progress in
            if progress >= 1.0 {
                // Generation complete — bust cache and clear progress
                self.imageRefreshIds[angle] = UUID()
                // Also refresh base image display if it was the base
                if angle == "base" {
                    self.imageRefreshIds["base"] = UUID()
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    self.generatingProgress.removeValue(forKey: angle)
                }
                // Re-discover images from filesystem
                self.discoveredImages = DiscoveredCharacterImages.discover(
                    for: self.character.name,
                    basePath: self.projectBasePath
                )
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.generatingProgress[angle] = progress
                }
            }
        }
    }

    // MARK: - Angle Image Count

    private var angleImageCount: Int {
        let angles: [ImageType] = [.front, .threeQuarterLeft, .threeQuarterRight, .profileLeft, .profileRight, .back]
        return angles.filter { effectiveImagePath(for: $0) != nil }.count
    }

    // MARK: - Build Image Prompt

    private func buildAnglePrompt(angle: String) -> String {
        let hasBaseImage = effectiveImagePath(for: .base) != nil
        var base = buildImagePrompt()
        base += ", \(angle)"
        if hasBaseImage {
            base += ". IMPORTANT: Generate the EXACT SAME person as shown in the reference image. Match the face, skin tone, hair, clothing, and art style precisely. This is a different angle of the same character, not a new character."
        }
        base += ", character turnaround sheet, consistent character appearance across all angles"
        return base
    }

    private func buildImagePrompt() -> String {
        var parts: [String] = []

        // Art style — prepend for strongest influence on generation
        let styleDirective: String
        switch character.imageStyle {
        case "Photorealistic":
            styleDirective = "photorealistic, ultra-realistic photograph, natural lighting"
        case "Cinematic":
            styleDirective = "cinematic still frame, dramatic movie lighting, film grain, shallow depth of field"
        case "Illustration":
            styleDirective = "digital illustration, hand-drawn style, detailed line art with color"
        case "Anime":
            styleDirective = "anime style, Japanese animation, cel-shaded, large expressive eyes"
        case "Comic Book":
            styleDirective = "comic book art, bold ink outlines, halftone dots, vibrant colors"
        case "Watercolor":
            styleDirective = "watercolor painting, soft washes, visible brush strokes, paper texture"
        case "Oil Painting":
            styleDirective = "classical oil painting, rich textures, museum quality, fine brush work"
        case "3D Render":
            styleDirective = "3D rendered character, CGI, Pixar-quality, subsurface scattering"
        default:
            styleDirective = "photorealistic"
        }
        parts.append(styleDirective)

        // Basic identity
        parts.append("\(character.gender) character")
        if character.age > 0 {
            parts.append("age \(character.age)")
        }

        // Physical build & body
        if !character.build.isEmpty {
            parts.append("\(character.build.lowercased()) build")
        }
        if let h = character.heightCm, h > 0 {
            let ft = Int(h / 30.48)
            let inches = Int((h / 2.54).truncatingRemainder(dividingBy: 12))
            parts.append("\(ft)'\(inches)\" tall")
        }

        // Facial structure
        if !character.facialStructure.isEmpty {
            parts.append("\(character.facialStructure.lowercased()) face shape")
        }

        // Skin
        if !character.skinTone.isEmpty {
            parts.append("\(character.skinTone) skin tone")
        }
        if !character.ethnicity.isEmpty {
            parts.append("\(character.ethnicity) ethnicity")
        }

        // Hair
        if !character.hairColor.isEmpty || !character.hairStyle.isEmpty || !character.hairLength.isEmpty {
            var hairParts: [String] = []
            if !character.hairColor.isEmpty { hairParts.append(character.hairColor) }
            if !character.hairLength.isEmpty { hairParts.append(character.hairLength.lowercased()) }
            if !character.hairStyle.isEmpty { hairParts.append(character.hairStyle.lowercased()) }
            parts.append(hairParts.joined(separator: " ") + " hair")
        }

        // Eyes
        if !character.eyeColorDescription.isEmpty || !character.eyeShape.isEmpty {
            var eyeParts: [String] = []
            if !character.eyeColorDescription.isEmpty { eyeParts.append(character.eyeColorDescription) }
            if !character.eyeShape.isEmpty { eyeParts.append(character.eyeShape.lowercased()) }
            parts.append(eyeParts.joined(separator: " ") + " eyes")
        }

        // Distinguishing features
        if !character.distinguishingFeatures.isEmpty {
            parts.append(character.distinguishingFeatures)
        }

        // Costume/attire — use active costume or general costume description
        if let costumes = character.costumes,
           let activeIdx = character.activeCostumeIndex,
           activeIdx < costumes.count {
            let c = costumes[activeIdx]
            var attire: [String] = []
            if let top = c.garmentTop, !top.isEmpty { attire.append(top) }
            if let bottom = c.garmentBottom, !bottom.isEmpty { attire.append(bottom) }
            if let outer = c.outerwear, !outer.isEmpty { attire.append(outer) }
            if let head = c.headwear, !head.isEmpty { attire.append(head) }
            if let foot = c.footwear, !foot.isEmpty { attire.append(foot) }
            if !attire.isEmpty {
                parts.append("wearing " + attire.joined(separator: ", "))
            }
        } else if let costume = character.costume, !costume.isEmpty {
            parts.append("wearing \(costume)")
        }

        // Occupation — influences visual portrayal
        if let occupation = character.occupation, !occupation.isEmpty {
            parts.append("occupation: \(occupation)")
        }

        // Personality — top distinctive traits influence expression/demeanor
        let dominantTraits = character.traits
            .filter { abs($0.value - 50.0) > 15 }
            .sorted { abs($0.value - 50.0) > abs($1.value - 50.0) }
            .prefix(3)
        if !dominantTraits.isEmpty {
            let traitDescs = dominantTraits.map { trait -> String in
                let level = trait.value > 50 ? "high" : "low"
                return "\(level) \(trait.key.lowercased())"
            }
            parts.append("personality: \(traitDescs.joined(separator: ", "))")
        }

        // Character role context
        if !character.role.isEmpty {
            parts.append("\(character.role.lowercased()) character")
        }

        // Brief description if available
        if !character.about.isEmpty {
            parts.append(character.about)
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Reference Image Upload

    private func browseForImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a reference image for \(character.name)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url) else { return }
        handleImageUpload(data: data)
    }

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        var imageData: Data?

        if let pngData = pasteboard.data(forType: .png) {
            imageData = pngData
        } else if let tiffData = pasteboard.data(forType: .tiff) {
            if let image = NSImage(data: tiffData), let tiffRep = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffRep),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                imageData = pngData
            }
        }

        guard let data = imageData else { return }
        handleImageUpload(data: data)
    }

    private func handleImageUpload(data: Data) {
        guard let basePath = projectBasePath else { return }

        let sanitizedName = DiscoveredCharacterImages.sanitizedName(for: character.name)
        let imageDir = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("face")

        let imagePath = imageDir.appendingPathComponent("base.png")

        // Ensure PNG format
        let pngData: Data
        if let nsImage = NSImage(data: data), let tiffRep = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRep),
           let converted = bitmap.representation(using: .png, properties: [:]) {
            pngData = converted
        } else {
            pngData = data
        }

        // Create directory and save
        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }

            try FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
            try pngData.write(to: imagePath)
        } catch {
            print("Failed to save uploaded image: \(error)")
            return
        }

        // Update character base image path
        character.baseImage = "assets/characters/\(sanitizedName)/face/base.png"
        imageRefreshIds["base"] = UUID()

        // Re-discover filesystem images
        discoveredImages = DiscoveredCharacterImages.discover(
            for: character.name,
            basePath: projectBasePath
        )

        // Trigger AI analysis
        isAnalyzingUpload = true
        analysisProgress = 0
        onUploadReferenceImage?(pngData) { progress in
            self.analysisProgress = progress
            if progress >= 1.0 {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isAnalyzingUpload = false
                }
            }
        }
    }
}

// MARK: - Reusable Components

/// Card container for attribute groups
private struct AttributeCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

/// Gender selection chip with icon
private struct GenderChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Build type selection chip
private struct BuildChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Compact selection chip for options like hair length, eye shape
private struct CompactChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Face shape chip with visual shape indicator
private struct FaceShapeChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private var shapeIcon: String {
        switch label {
        case "Oval": return "oval"
        case "Round": return "circle"
        case "Square": return "square"
        case "Heart": return "heart"
        case "Oblong": return "rectangle"
        case "Diamond": return "diamond"
        default: return "circle"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: shapeIcon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Measurement input with label, unit, icon, and optional slider
private struct MeasurementField: View {
    let label: String
    let unit: String
    @Binding var value: Double?
    let icon: String
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                TextField("—", value: $value, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(width: 52)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(8)

                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                Spacer()
            }

            // Subtle slider
            Slider(
                value: Binding(
                    get: { value ?? range.lowerValue(range) },
                    set: { value = $0 }
                ),
                in: range,
                step: 1
            )
            .controlSize(.mini)
            .tint(.accentColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Gallery action button with icon + label, hover effect, optional prominent style
private struct GalleryButton: View {
    let label: String
    let icon: String
    let color: Color
    var isProminent: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isProminent ? .white : color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isProminent ? .white : (isHovered ? .primary : .secondary))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: isProminent ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isProminent
                        ? color.opacity(isHovered ? 0.9 : 0.8)
                        : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color(nsColor: .quaternarySystemFill).opacity(0.5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isProminent ? Color.clear : color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private extension ClosedRange where Bound == Double {
    func lowerValue(_ range: ClosedRange<Double>) -> Double {
        let mid = (range.lowerBound + range.upperBound) / 2
        return mid
    }
}

// MARK: - Angle Thumbnail

private struct AngleThumbnail: View {
    let label: String
    let imagePath: String?
    let projectBasePath: URL?
    let characterName: String
    var generationProgress: Double?  // nil = idle, 0.0-1.0 = generating
    var refreshId: UUID?             // Changes to force AsyncImage reload
    var onView: ((URL) -> Void)?
    var onDownload: ((URL) -> Void)?
    var onGenerate: (() -> Void)?
    var onEditAnnotate: (() -> Void)?

    @State private var isHovering = false

    private var hasImage: Bool { imagePath != nil }
    private var isGenerating: Bool { generationProgress != nil }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .quaternarySystemFill))
                    .frame(width: 80, height: 80)

                if let path = imagePath, let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(path)
                    AsyncImage(url: fullPath) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "person.crop.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .id(refreshId ?? UUID())

                    // Hover overlay with action buttons (only when not generating)
                    if isHovering && !isGenerating {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 80, height: 80)

                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Button {
                                    onView?(fullPath)
                                } label: {
                                    Image(systemName: "eye")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("View full screen")

                                Button {
                                    onEditAnnotate?()
                                } label: {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("Annotate & edit image")

                                Button {
                                    onDownload?(fullPath)
                                } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("Download image")
                            }

                            HStack(spacing: 4) {
                                Button {
                                    onGenerate?()
                                } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 7))
                                        Text("Redo")
                                            .font(.system(size: 7, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.8)))
                                }
                                .buttonStyle(.plain)
                                .help("Regenerate this angle")
                            }
                        }
                    }
                } else if !isGenerating {
                    // Empty state — clickable to generate
                    Button {
                        onGenerate?()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: isHovering ? "wand.and.stars" : "plus")
                                .font(.system(size: isHovering ? 18 : 16))
                                .foregroundColor(isHovering ? .accentColor : Color(nsColor: .tertiaryLabelColor))
                            if isHovering {
                                Text("Generate")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .frame(width: 80, height: 80)
                    }
                    .buttonStyle(.plain)
                    .help("Generate \(label) image")
                }

                // Generation progress overlay
                if let progress = generationProgress {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 80, height: 80)

                    GenerationProgressRing(progress: progress, size: 44)
                }

                // Accent border when hovering on empty
                if !hasImage && !isGenerating && isHovering {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 80, height: 80)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isGenerating ? .accentColor : (isHovering ? .primary : .secondary))
        }
    }
}

// MARK: - Generation Progress Ring

private struct GenerationProgressRing: View {
    let progress: Double
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Percentage text
            VStack(spacing: 1) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if size > 50 {
                    Text("Generating")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Full Screen Image Viewer

private struct FullScreenImageViewer: View {
    let imageURL: URL?
    let title: String
    var onDownload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Button {
                    onDownload?()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("Download")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Save image to your computer")

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                        Text("Close")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Image
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        ScrollView([.horizontal, .vertical]) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text("Failed to load image")
                                .foregroundColor(.secondary)
                        }
                    case .empty:
                        ProgressView("Loading...")
                    @unknown default:
                        ProgressView()
                    }
                }
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No image selected")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.black)
    }
}

// MARK: - Discovered Character Images

/// Auto-discovered images from the character folder structure
struct DiscoveredCharacterImages {
    var baseImage: String?
    var front: String?
    var threeQuarterLeft: String?
    var threeQuarterRight: String?
    var profileLeft: String?
    var profileRight: String?
    var back: String?

    /// Discover images from the character folder
    /// Looks in: assets/characters/{CharacterName}/face/ and assets/characters/{CharacterName}/body/
    static func discover(for characterName: String, basePath: URL?) -> DiscoveredCharacterImages {
        guard let basePath = basePath else { return DiscoveredCharacterImages() }

        var result = DiscoveredCharacterImages()
        let fileManager = FileManager.default

        // Sanitize character name for folder lookup
        let sanitizedName = sanitizeName(characterName)

        // Check face folder
        let faceFolder = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("face")

        // Check body folder
        let bodyFolder = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("body")

        // Helper to find first image matching patterns
        func findImage(in folder: URL, patterns: [String]) -> String? {
            guard fileManager.fileExists(atPath: folder.path) else { return nil }
            guard let contents = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return nil }

            // Sort by modification date descending to get most recent
            let files = contents.compactMap { filename -> (String, Date)? in
                let path = folder.appendingPathComponent(filename).path
                guard let attrs = try? fileManager.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date else { return nil }
                return (filename, modDate)
            }.sorted { $0.1 > $1.1 }

            for (filename, _) in files {
                let lower = filename.lowercased()
                for pattern in patterns {
                    if lower.contains(pattern.lowercased()) && (lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")) {
                        let relativePath = "assets/characters/\(sanitizedName)/\(folder.lastPathComponent)/\(filename)"
                        return relativePath
                    }
                }
            }
            return nil
        }

        // Discover face images
        result.baseImage = findImage(in: faceFolder, patterns: ["base", "front"])
        result.front = findImage(in: faceFolder, patterns: ["front", "face_front"])
        result.threeQuarterLeft = findImage(in: faceFolder, patterns: ["three_quarter_left", "3_4_left", "3/4_left"])
        result.threeQuarterRight = findImage(in: faceFolder, patterns: ["three_quarter_right", "3_4_right", "3/4_right"])
        result.profileLeft = findImage(in: faceFolder, patterns: ["profile_left", "profile"])
        result.profileRight = findImage(in: faceFolder, patterns: ["profile_right"])

        // Discover body images (can also serve as front/back)
        if result.front == nil {
            result.front = findImage(in: bodyFolder, patterns: ["front"])
        }
        result.back = findImage(in: bodyFolder, patterns: ["back"])

        // If no specific base image, use any front image
        if result.baseImage == nil {
            result.baseImage = result.front
        }

        return result
    }

    static func sanitizedName(for name: String) -> String {
        return sanitizeName(name)
    }

    private static func sanitizeName(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")

        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

#Preview {
    PhysicalAppearanceTab(
        character: .constant(Character(
            name: "John",
            role: "Protagonist",
            color: "#4A90D9",
            age: 30,
            hairColor: "#8B4513",
            hairStyle: "Short and wavy",
            hairLength: "Short",
            eyeColor: "#4169E1",
            eyeColorDescription: "Royal blue",
            eyeShape: "Almond",
            skinTone: "#DEB887",
            ethnicity: "Caucasian",
            facialStructure: "Oval"
        ))
    )
    .frame(width: 800, height: 600)
}
