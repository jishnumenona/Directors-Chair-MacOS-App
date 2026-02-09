// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/PhysicalAppearanceTab.swift
//
// Physical appearance editor tab - game character customizer style

import SwiftUI
import DirectorsChairCore
import AppKit

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
    var onGenerateImage: ((String, String) -> Void)?  // (angle, prompt)
    var onAnalyzeTraits: (() -> Void)?

    // State for full screen image viewer
    @State private var showingFullScreenImage = false
    @State private var fullScreenImageURL: URL?
    @State private var fullScreenImageTitle: String = ""

    // State for discovered images (auto-detect from filesystem)
    @State private var discoveredImages: DiscoveredCharacterImages = DiscoveredCharacterImages()

    public init(
        character: Binding<Character>,
        projectBasePath: URL? = nil,
        onGenerateImage: ((String, String) -> Void)? = nil,
        onAnalyzeTraits: (() -> Void)? = nil
    ) {
        self._character = character
        self.projectBasePath = projectBasePath
        self.onGenerateImage = onGenerateImage
        self.onAnalyzeTraits = onAnalyzeTraits
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

    // MARK: - Image Gallery Section

    private var imageGallerySection: some View {
        VStack(spacing: 12) {
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
                } else {
                    placeholderImage
                }
            }

            // View and Download buttons for base image
            if let imagePath = effectiveImagePath(for: .base),
               let basePath = projectBasePath {
                let fullPath = basePath.appendingPathComponent(imagePath)
                HStack(spacing: 8) {
                    Button {
                        fullScreenImageURL = fullPath
                        fullScreenImageTitle = "\(character.name) - Base Image"
                        showingFullScreenImage = true
                    } label: {
                        Label("View", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .help("View image in full screen")

                    Button {
                        downloadImage(from: fullPath, suggestedName: "\(character.name)_base.png")
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .help("Save image to your computer")
                }
            }

            // Generate button
            Button {
                let prompt = buildImagePrompt()
                onGenerateImage?("base", prompt)
            } label: {
                Label("Generate Base Image", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .help("AI: Generate a base character image")

            // Angle thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AngleThumbnail(
                        label: "Front",
                        imagePath: effectiveImagePath(for: .front),
                        projectBasePath: projectBasePath,
                        characterName: character.name,
                        onView: { url in
                            fullScreenImageURL = url
                            fullScreenImageTitle = "\(character.name) - Front"
                            showingFullScreenImage = true
                        },
                        onDownload: { url in
                            downloadImage(from: url, suggestedName: "\(character.name)_front.png")
                        }
                    )
                    AngleThumbnail(
                        label: "3/4 Left",
                        imagePath: effectiveImagePath(for: .threeQuarterLeft),
                        projectBasePath: projectBasePath,
                        characterName: character.name,
                        onView: { url in
                            fullScreenImageURL = url
                            fullScreenImageTitle = "\(character.name) - Three Quarter Left"
                            showingFullScreenImage = true
                        },
                        onDownload: { url in
                            downloadImage(from: url, suggestedName: "\(character.name)_3q_left.png")
                        }
                    )
                    AngleThumbnail(
                        label: "3/4 Right",
                        imagePath: effectiveImagePath(for: .threeQuarterRight),
                        projectBasePath: projectBasePath,
                        characterName: character.name,
                        onView: { url in
                            fullScreenImageURL = url
                            fullScreenImageTitle = "\(character.name) - Three Quarter Right"
                            showingFullScreenImage = true
                        },
                        onDownload: { url in
                            downloadImage(from: url, suggestedName: "\(character.name)_3q_right.png")
                        }
                    )
                    AngleThumbnail(
                        label: "Profile L",
                        imagePath: effectiveImagePath(for: .profileLeft),
                        projectBasePath: projectBasePath,
                        characterName: character.name,
                        onView: { url in
                            fullScreenImageURL = url
                            fullScreenImageTitle = "\(character.name) - Profile Left"
                            showingFullScreenImage = true
                        },
                        onDownload: { url in
                            downloadImage(from: url, suggestedName: "\(character.name)_profile_left.png")
                        }
                    )
                    AngleThumbnail(
                        label: "Profile R",
                        imagePath: effectiveImagePath(for: .profileRight),
                        projectBasePath: projectBasePath,
                        characterName: character.name,
                        onView: { url in
                            fullScreenImageURL = url
                            fullScreenImageTitle = "\(character.name) - Profile Right"
                            showingFullScreenImage = true
                        },
                        onDownload: { url in
                            downloadImage(from: url, suggestedName: "\(character.name)_profile_right.png")
                        }
                    )
                    AngleThumbnail(
                        label: "Back",
                        imagePath: effectiveImagePath(for: .back),
                        projectBasePath: projectBasePath,
                        characterName: character.name,
                        onView: { url in
                            fullScreenImageURL = url
                            fullScreenImageTitle = "\(character.name) - Back"
                            showingFullScreenImage = true
                        },
                        onDownload: { url in
                            downloadImage(from: url, suggestedName: "\(character.name)_back.png")
                        }
                    )
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
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

    // MARK: - Build Image Prompt

    private func buildImagePrompt() -> String {
        var parts: [String] = []

        parts.append("\(character.gender) character")
        if character.age > 0 {
            parts.append("age \(character.age)")
        }

        if !character.build.isEmpty {
            parts.append("\(character.build.lowercased()) build")
        }

        if !character.hairColor.isEmpty && !character.hairStyle.isEmpty {
            parts.append("\(character.hairColor) \(character.hairStyle) hair")
        }

        if !character.eyeColorDescription.isEmpty {
            parts.append("\(character.eyeColorDescription) eyes")
        }

        if !character.ethnicity.isEmpty {
            parts.append("\(character.ethnicity) ethnicity")
        }

        if !character.distinguishingFeatures.isEmpty {
            parts.append(character.distinguishingFeatures)
        }

        return parts.joined(separator: ", ")
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
    var onView: ((URL) -> Void)?
    var onDownload: ((URL) -> Void)?

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)

                if let path = imagePath, let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(path)
                    AsyncImage(url: fullPath) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: "person.crop.rectangle")
                                .foregroundColor(.gray)
                        }
                    }

                    // Hover overlay with buttons
                    if isHovering {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 60, height: 60)

                        HStack(spacing: 4) {
                            Button {
                                onView?(fullPath)
                            } label: {
                                Image(systemName: "eye")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .help("View full screen")

                            Button {
                                onDownload?(fullPath)
                            } label: {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .help("Download image")
                        }
                    }
                } else {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering && imagePath != nil
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .help(imagePath != nil ? "\(label) - Click to view/download" : "\(label) - No image")
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
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .help("Save image to your computer")

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
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
