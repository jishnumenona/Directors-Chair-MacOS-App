//
// PhysicalAppearanceTab+Sections.swift
//
// Extracted from PhysicalAppearanceTab.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

extension PhysicalAppearanceTab {

    // MARK: - Identity Header

    var identityHeader: some View {
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

    var bodyMeasurementsSection: some View {
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

    var hairSection: some View {
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

    var eyesSection: some View {
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

    var skinSection: some View {
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

    var faceStructureSection: some View {
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

    var distinguishingFeaturesSection: some View {
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

    static let imageStyles: [(name: String, icon: String, description: String)] = [
        ("Photorealistic", "camera.fill", "Photo-quality realistic rendering"),
        ("Cinematic", "film", "Dramatic movie-style lighting and composition"),
        ("Illustration", "paintbrush.pointed.fill", "Hand-drawn digital illustration"),
        ("Anime", "sparkles", "Japanese anime / manga style"),
        ("Comic Book", "book.fill", "Bold outlines, comic panel style"),
        ("Watercolor", "drop.fill", "Soft watercolor painting"),
        ("Oil Painting", "paintpalette.fill", "Classical oil painting style"),
        ("3D Render", "cube.fill", "3D CGI rendered character"),
    ]

    var imageStyleSection: some View {
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

    var imageGallerySection: some View {
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
                    },
                    onUpload: {
                        uploadAngleImage(angle: "front", label: "Front")
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
                    },
                    onUpload: {
                        uploadAngleImage(angle: "three_quarter_left", label: "3/4 Left")
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
                    },
                    onUpload: {
                        uploadAngleImage(angle: "three_quarter_right", label: "3/4 Right")
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
                    },
                    onUpload: {
                        uploadAngleImage(angle: "profile_left", label: "Profile Left")
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
                    },
                    onUpload: {
                        uploadAngleImage(angle: "profile_right", label: "Profile Right")
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
                    },
                    onUpload: {
                        uploadAngleImage(angle: "back", label: "Back")
                    }
                )
            }

        }
        .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}
