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
                    VStack(alignment: .leading, spacing: 20) {
                        basicInfoSection
                        hairSection
                        eyesSection
                        skinSection
                        distinguishingFeaturesSection
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            // Discover images from filesystem
            discoveredImages = DiscoveredCharacterImages.discover(
                for: character.name,
                basePath: projectBasePath
            )
        }
        .onChange(of: character.name) { newName in
            // Re-discover when character changes
            discoveredImages = DiscoveredCharacterImages.discover(
                for: newName,
                basePath: projectBasePath
            )
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
                // Generate base image
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
        // Load the image data
        guard let imageData = try? Data(contentsOf: url) else {
            return
        }

        // Show save panel
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

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        GroupBox("Basic Information") {
            VStack(spacing: 12) {
                HStack {
                    LabeledContent("Age") {
                        TextField("", value: $character.age, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    LabeledContent("Gender") {
                        Picker("", selection: $character.gender) {
                            Text("Male").tag("male")
                            Text("Female").tag("female")
                            Text("Neutral").tag("neutral")
                            Text("Other").tag("other")
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }

                HStack {
                    LabeledContent("Height (cm)") {
                        TextField("", value: $character.heightCm, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    LabeledContent("Weight (kg)") {
                        TextField("", value: $character.weightKg, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                LabeledContent("Build") {
                    Picker("", selection: $character.build) {
                        Text("Slim").tag("Slim")
                        Text("Athletic").tag("Athletic")
                        Text("Average").tag("Average")
                        Text("Stocky").tag("Stocky")
                        Text("Heavy").tag("Heavy")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: - Hair Section

    private var hairSection: some View {
        GroupBox("Hair") {
            VStack(spacing: 12) {
                HStack {
                    LabeledContent("Color") {
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: character.hairColor) },
                            set: { character.hairColor = $0.hexString }
                        ))
                        .labelsHidden()
                    }

                    TextField("Color name", text: $character.hairColor)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                LabeledContent("Length") {
                    Picker("", selection: $character.hairLength) {
                        Text("Bald").tag("Bald")
                        Text("Short").tag("Short")
                        Text("Medium").tag("Medium")
                        Text("Long").tag("Long")
                        Text("Very Long").tag("Very Long")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                LabeledContent("Style") {
                    TextField("e.g., Short and Spiky", text: $character.hairStyle)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Eyes Section

    private var eyesSection: some View {
        GroupBox("Eyes") {
            VStack(spacing: 12) {
                HStack {
                    LabeledContent("Color") {
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: character.eyeColor) },
                            set: { character.eyeColor = $0.hexString }
                        ))
                        .labelsHidden()
                    }

                    TextField("Color description", text: $character.eyeColorDescription)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Shape") {
                    Picker("", selection: $character.eyeShape) {
                        Text("Almond").tag("Almond")
                        Text("Round").tag("Round")
                        Text("Hooded").tag("Hooded")
                        Text("Monolid").tag("Monolid")
                        Text("Deep-set").tag("Deep-set")
                        Text("Upturned").tag("Upturned")
                        Text("Downturned").tag("Downturned")
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }
        }
    }

    // MARK: - Skin Section

    private var skinSection: some View {
        GroupBox("Skin") {
            VStack(spacing: 12) {
                HStack {
                    LabeledContent("Tone") {
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: character.skinTone) },
                            set: { character.skinTone = $0.hexString }
                        ))
                        .labelsHidden()
                    }

                    TextField("Skin tone name", text: $character.skinTone)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                LabeledContent("Ethnicity") {
                    TextField("Ethnic background", text: $character.ethnicity)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Facial Structure") {
                    Picker("", selection: $character.facialStructure) {
                        Text("Oval").tag("Oval")
                        Text("Round").tag("Round")
                        Text("Square").tag("Square")
                        Text("Heart").tag("Heart")
                        Text("Oblong").tag("Oblong")
                        Text("Diamond").tag("Diamond")
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }
        }
    }

    // MARK: - Distinguishing Features Section

    private var distinguishingFeaturesSection: some View {
        GroupBox("Distinguishing Features") {
            TextEditor(text: $character.distinguishingFeatures)
                .frame(minHeight: 80)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
        }
    }

    // MARK: - Build Image Prompt

    private func buildImagePrompt() -> String {
        var parts: [String] = []

        // Basic info
        parts.append("\(character.gender) character")
        if character.age > 0 {
            parts.append("age \(character.age)")
        }

        // Build
        if !character.build.isEmpty {
            parts.append("\(character.build.lowercased()) build")
        }

        // Hair
        if !character.hairColor.isEmpty && !character.hairStyle.isEmpty {
            parts.append("\(character.hairColor) \(character.hairStyle) hair")
        }

        // Eyes
        if !character.eyeColorDescription.isEmpty {
            parts.append("\(character.eyeColorDescription) eyes")
        }

        // Skin
        if !character.ethnicity.isEmpty {
            parts.append("\(character.ethnicity) ethnicity")
        }

        // Distinguishing features
        if !character.distinguishingFeatures.isEmpty {
            parts.append(character.distinguishingFeatures)
        }

        return parts.joined(separator: ", ")
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
                        // Return relative path from basePath
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
