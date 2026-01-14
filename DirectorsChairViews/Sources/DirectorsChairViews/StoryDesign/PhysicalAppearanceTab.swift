// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/PhysicalAppearanceTab.swift
//
// Physical appearance editor tab - game character customizer style

import SwiftUI
import DirectorsChairCore

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

    public var body: some View {
        HSplitView {
            // Left: Character image gallery
            imageGallerySection
                .frame(minWidth: 300, maxWidth: 400)

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

                if let imagePath = character.baseImage,
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

            // Angle thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    AngleThumbnail(label: "Front", imagePath: character.imageFront, projectBasePath: projectBasePath)
                    AngleThumbnail(label: "3/4 Left", imagePath: character.imageThreeQuarterLeft, projectBasePath: projectBasePath)
                    AngleThumbnail(label: "3/4 Right", imagePath: character.imageThreeQuarterRight, projectBasePath: projectBasePath)
                    AngleThumbnail(label: "Profile L", imagePath: character.imageProfileLeft, projectBasePath: projectBasePath)
                    AngleThumbnail(label: "Profile R", imagePath: character.imageProfileRight, projectBasePath: projectBasePath)
                    AngleThumbnail(label: "Back", imagePath: character.imageBack, projectBasePath: projectBasePath)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
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

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)

                if let path = imagePath, let basePath = projectBasePath {
                    AsyncImage(url: basePath.appendingPathComponent(path)) { phase in
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
                } else {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
