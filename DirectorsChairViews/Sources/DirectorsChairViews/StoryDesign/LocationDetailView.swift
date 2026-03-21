// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/LocationDetailView.swift
//
// Cinematic location visualization with AI-generated images and rich metadata

import SwiftUI
import DirectorsChairCore
import AppKit

/// Cinematic location detail view with image gallery and rich attribute editing
///
/// Layout: Left/Right split
/// - Left (35%, max 400): Hero image, variation grid, generate buttons
/// - Right (scrollable): Description, atmosphere, cinematography, script context, technical, notes
public struct LocationDetailView: View {
    @Binding var location: Location
    let project: Project
    let projectBasePath: URL?

    // Callback for AI image generation: (variation, prompt, progressHandler)
    var onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)?

    // State for full screen image viewer
    @State private var showingFullScreenImage = false
    @State private var fullScreenImageURL: URL?
    @State private var fullScreenImageTitle: String = ""

    // State for discovered images
    @State private var discoveredImages: DiscoveredLocationImages = DiscoveredLocationImages()

    // Which variation is shown in the hero preview ("primary", "day", "night", etc.)
    @State private var selectedPreviewVariation: String = "primary"

    // Prompt editor state
    @State private var showingPromptEditor = false
    @State private var promptEditorVariation: String = ""
    @State private var promptEditorText: String = ""

    // Per-variation generation progress (nil = idle, 0.0-1.0 = generating)
    @State private var generatingProgress: [String: Double] = [:]
    // Cache-busting IDs to force AsyncImage reload
    @State private var imageRefreshIds: [String: UUID] = [:]

    // Annotation editor state
    // Hover state for hero image overlay
    @State private var isHoveringHeroImage = false

    @State private var showingAnnotationEditor = false
    @State private var annotationEditorImage: NSImage?
    @State private var annotationEditorVariation: String = ""
    @State private var annotationEditorTitle: String = ""

    public init(
        location: Binding<Location>,
        project: Project,
        projectBasePath: URL? = nil,
        onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil
    ) {
        self._location = location
        self.project = project
        self.projectBasePath = projectBasePath
        self.onGenerateImage = onGenerateImage
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left: Image gallery
                imageGallerySection
                    .frame(width: min(400, geometry.size.width * 0.35))

                Divider()

                // Right: Attribute editors
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        locationIdentityHeader
                        descriptionCard
                        atmosphereCard
                        cinematographyCard
                        scriptContextCard

                        HStack(alignment: .top, spacing: 16) {
                            technicalDetailsCard
                            directorsNotesCard
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            discoveredImages = DiscoveredLocationImages.discover(
                for: location.name,
                basePath: projectBasePath
            )
        }
        .onChange(of: location.name) { newName in
            selectedPreviewVariation = "primary"
            discoveredImages = DiscoveredLocationImages.discover(
                for: newName,
                basePath: projectBasePath
            )
        }
    }

    // MARK: - Effective Image Path

    private func effectiveImagePath(for variation: String) -> String? {
        switch variation {
        case "primary":
            return location.primaryImage ?? discoveredImages.primary
        case "day":
            return discoveredImages.day
        case "night":
            return discoveredImages.night
        case "golden_hour":
            return discoveredImages.goldenHour
        case "overcast":
            return discoveredImages.overcast
        case "wide":
            return discoveredImages.wide
        case "detail":
            return discoveredImages.detail
        default:
            return nil
        }
    }

    // MARK: - Location Identity Header

    private var locationIdentityHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Type selector
            VStack(alignment: .leading, spacing: 6) {
                Text("TYPE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                HStack(spacing: 6) {
                    LocationTypeChip(label: "Indoor", icon: "building.2.fill", isSelected: location.locationType == "indoor") {
                        location.locationType = "indoor"
                    }
                    LocationTypeChip(label: "Outdoor", icon: "sun.max.fill", isSelected: location.locationType == "outdoor") {
                        location.locationType = "outdoor"
                    }
                    LocationTypeChip(label: "Mixed", icon: "map.fill", isSelected: location.locationType == "mixed") {
                        location.locationType = "mixed"
                    }

                    Spacer()

                    // Scene count badge
                    VStack(spacing: 2) {
                        Text("SCENES")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1)
                        Text("\(scenesAtLocation.count)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.accentColor)
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
                }
            }

            // Tags
            if !location.tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 4)], spacing: 4) {
                    ForEach(location.tags, id: \.self) { tag in
                        LocationCompactChip(label: tag, isSelected: true) {}
                    }
                }
            }
        }
    }

    // MARK: - Description Card

    private var descriptionCard: some View {
        LocationAttributeCard(title: "DESCRIPTION", icon: "text.alignleft") {
            TextEditor(text: $location.description)
                .font(.system(size: 12))
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(8)
        }
    }

    // MARK: - Atmosphere & Style Card

    private var atmosphereCard: some View {
        LocationAttributeCard(title: "ATMOSPHERE", icon: "sparkles") {
            VStack(spacing: 16) {
                // Mood
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mood")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    let moods = ["Tense", "Romantic", "Mysterious", "Chaotic", "Serene", "Foreboding", "Joyful", "Melancholy"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                        ForEach(moods, id: \.self) { mood in
                            LocationCompactChip(label: mood, isSelected: location.styleAttributes["mood"] == mood) {
                                location.styleAttributes["mood"] = mood
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Color Palette
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color Palette")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g., Warm amber tones, cool blues", text: styleBinding("color_palette"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                Divider().opacity(0.5)

                // Architecture
                VStack(alignment: .leading, spacing: 6) {
                    Text("Architecture")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    let styles = ["Modern", "Classical", "Industrial", "Gothic", "Art Deco", "Minimalist", "Rustic", "Futuristic"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                        ForEach(styles, id: \.self) { style in
                            LocationCompactChip(label: style, isSelected: location.styleAttributes["architectural_style"] == style) {
                                location.styleAttributes["architectural_style"] = style
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Texture
                VStack(alignment: .leading, spacing: 6) {
                    Text("Texture")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g., Rough stone, polished marble", text: styleBinding("texture"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Cinematography Card

    private var cinematographyCard: some View {
        LocationAttributeCard(title: "CINEMATOGRAPHY", icon: "camera.fill") {
            VStack(spacing: 16) {
                // Angle
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred Angle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    let angles = ["Wide", "Medium", "Close-Up", "Over-Shoulder", "High Angle", "Low Angle", "Bird's Eye", "Dutch"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                        ForEach(angles, id: \.self) { angle in
                            LocationCompactChip(label: angle, isSelected: location.cinematographyDefaults["preferred_angle"] == angle) {
                                location.cinematographyDefaults["preferred_angle"] = angle
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Lighting
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lighting")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    let lightingOptions = ["Natural", "Studio", "Dramatic", "Low-key", "High-key", "Neon", "Candlelight", "Moonlight"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                        ForEach(lightingOptions, id: \.self) { lighting in
                            LocationCompactChip(label: lighting, isSelected: location.cinematographyDefaults["lighting"] == lighting) {
                                location.cinematographyDefaults["lighting"] = lighting
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Time of Day
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time of Day")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    let times = ["Dawn", "Morning", "Midday", "Afternoon", "Golden Hour", "Dusk", "Night", "Late Night"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                        ForEach(times, id: \.self) { time in
                            LocationCompactChip(label: time, isSelected: location.cinematographyDefaults["time_of_day"] == time) {
                                location.cinematographyDefaults["time_of_day"] = time
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Script Context Card

    private var scriptContextCard: some View {
        LocationAttributeCard(title: "SCRIPT CONTEXT", icon: "doc.text") {
            let scenes = scenesAtLocationDetailed
            if scenes.isEmpty {
                Text("No scenes reference this location yet.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .italic()
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(scenes) { info in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "film")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                Text(info.sceneName)
                                    .font(.system(size: 12, weight: .semibold))

                                Spacer()

                                // Dialogue count
                                HStack(spacing: 3) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 9))
                                    Text("\(info.dialogueCount)")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                                .foregroundColor(.blue)

                                // Action count
                                HStack(spacing: 3) {
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 9))
                                    Text("\(info.actionCount)")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                                .foregroundColor(.orange)
                            }

                            // Sample dialogues
                            ForEach(info.sampleDialogues, id: \.self) { dialogue in
                                HStack(alignment: .top, spacing: 4) {
                                    Text(dialogue.character)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("\"\(dialogue.text)\"")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                        .italic()
                                        .lineLimit(2)
                                }
                                .padding(.leading, 20)
                            }

                            // Sample action
                            ForEach(info.sampleActions, id: \.self) { action in
                                Text(action)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                    .italic()
                                    .lineLimit(2)
                                    .padding(.leading, 20)
                            }

                            if info != scenes.last {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Technical Details Card

    private var technicalDetailsCard: some View {
        LocationAttributeCard(title: "TECHNICAL", icon: "ruler") {
            VStack(spacing: 14) {
                // Address
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Address")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    TextField("Physical address", text: $location.address)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                // GPS
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("GPS")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    TextField("Latitude, Longitude", text: $location.gpsCoordinates)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                // Parent Location
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Parent Location")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    TextField("e.g., New York City", text: parentLocationBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Director's Notes Card

    private var directorsNotesCard: some View {
        LocationAttributeCard(title: "NOTES", icon: "note.text") {
            TextEditor(text: $location.notes)
                .font(.system(size: 12))
                .frame(minHeight: 72)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(8)
        }
    }

    // MARK: - Image Gallery Section

    private var imageGallerySection: some View {
        ScrollView {
        VStack(spacing: 12) {
            // Hero image — shows selected variation
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))

                if let imagePath = effectiveImagePath(for: selectedPreviewVariation),
                   let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(imagePath)
                    AsyncImage(url: fullPath) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            locationPlaceholder
                        case .empty:
                            ProgressView()
                        @unknown default:
                            locationPlaceholder
                        }
                    }
                    .id(imageRefreshIds[selectedPreviewVariation] ?? UUID())
                } else {
                    locationPlaceholder
                }

                // Gradient overlay with name + type + variation label
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            HStack(spacing: 6) {
                                Text(location.locationType.capitalized)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.2)))
                                if selectedPreviewVariation != "primary" {
                                    Text(variationDisplayName(selectedPreviewVariation))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.7)))
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )
                    )
                }

                // Hover overlay with icon buttons
                if (isHoveringHeroImage || generatingProgress[selectedPreviewVariation] != nil) && effectiveImagePath(for: selectedPreviewVariation) != nil {
                    VStack {
                        HStack {
                            Spacer()
                            if let imagePath = effectiveImagePath(for: selectedPreviewVariation),
                               let basePath = projectBasePath {
                                let fullPath = basePath.appendingPathComponent(imagePath)

                                if generatingProgress[selectedPreviewVariation] == nil {
                                    Button(action: {
                                        fullScreenImageURL = fullPath
                                        fullScreenImageTitle = "\(location.name) - \(variationDisplayName(selectedPreviewVariation))"
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
                                        openAnnotationEditor(variation: selectedPreviewVariation, label: variationDisplayName(selectedPreviewVariation))
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
                                        downloadImage(from: fullPath, suggestedName: "\(location.name)_\(selectedPreviewVariation).png")
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
                                }

                                Button(action: {
                                    generateVariationImage(variation: selectedPreviewVariation, prompt: selectedPreviewVariation == "primary" ? buildLocationPrompt() : buildVariationPrompt(override: variationDefaultOverride(selectedPreviewVariation)))
                                }) {
                                    ZStack {
                                        if generatingProgress[selectedPreviewVariation] != nil {
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
                                    .background(generatingProgress[selectedPreviewVariation] != nil ? Color.accentColor.opacity(0.8) : Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(generatingProgress[selectedPreviewVariation] != nil)
                                .help(generatingProgress[selectedPreviewVariation] != nil ? "Generating..." : "Regenerate image")
                            }
                        }
                        .padding(12)
                        Spacer()
                    }
                }

                // Progress ring overlay for whichever variation is previewed
                if let progress = generatingProgress[selectedPreviewVariation] {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.5))
                    LocationProgressRing(progress: progress)
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringHeroImage = hovering
                }
            }
            .onTapGesture {
                // Click hero to reset back to primary
                if selectedPreviewVariation != "primary" {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPreviewVariation = "primary"
                    }
                }
            }

            // Generate Primary Image button (shown when no primary image exists)
            if effectiveImagePath(for: "primary") == nil {
                LocationGalleryButton(
                    label: generatingProgress["primary"] != nil ? "Generating..." : "Generate Primary Image",
                    icon: generatingProgress["primary"] != nil ? "hourglass" : "wand.and.stars",
                    color: .accentColor,
                    isProminent: true
                ) {
                    generateVariationImage(variation: "primary", prompt: buildLocationPrompt())
                }
                .disabled(generatingProgress["primary"] != nil)
            }

            // Variations section header
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("LOCATION VARIATIONS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                Spacer()
                Text("\(variationImageCount)/6")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(nsColor: .quaternarySystemFill)))
            }
            .padding(.top, 4)

            // Variation thumbnails grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 10) {
                variationThumbnail("day", label: "Day")
                variationThumbnail("night", label: "Night")
                variationThumbnail("golden_hour", label: "Golden Hour")
                variationThumbnail("overcast", label: "Overcast")
                variationThumbnail("wide", label: "Wide Shot")
                variationThumbnail("detail", label: "Detail")
            }

        }
        .padding()
        } // ScrollView
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingFullScreenImage) {
            LocationFullScreenViewer(
                imageURL: fullScreenImageURL,
                title: fullScreenImageTitle,
                onDownload: {
                    if let url = fullScreenImageURL {
                        downloadImage(from: url, suggestedName: "\(location.name)_image.png")
                    }
                }
            )
        }
        .sheet(isPresented: $showingPromptEditor) {
            LocationPromptEditor(
                variation: promptEditorVariation,
                variationLabel: variationDisplayName(promptEditorVariation),
                prompt: $promptEditorText,
                onGenerate: {
                    showingPromptEditor = false
                    generateVariationImage(variation: promptEditorVariation, prompt: promptEditorText)
                }
            )
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = annotationEditorImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT LOCATION — \(annotationEditorTitle.uppercased())",
                    subtitle: location.name,
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generateVariationWithAnnotations(variation: annotationEditorVariation, annotations: annotations)
                    }
                )
            }
        }
    }

    // MARK: - Placeholder

    private var locationPlaceholder: some View {
        VStack {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Generate Variation Image

    private func generateVariationImage(variation: String, prompt: String) {
        guard generatingProgress[variation] == nil else { return }
        generatingProgress[variation] = 0.0

        onGenerateImage?(variation, prompt) { progress in
            if progress >= 1.0 {
                self.imageRefreshIds[variation] = UUID()
                if variation == "primary" {
                    self.imageRefreshIds["primary"] = UUID()
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    self.generatingProgress.removeValue(forKey: variation)
                }
                self.discoveredImages = DiscoveredLocationImages.discover(
                    for: self.location.name,
                    basePath: self.projectBasePath
                )
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.generatingProgress[variation] = progress
                }
            }
        }
    }

    // MARK: - Variation Image Count

    private var variationImageCount: Int {
        let variations = ["day", "night", "golden_hour", "overcast", "wide", "detail"]
        return variations.filter { effectiveImagePath(for: $0) != nil }.count
    }

    // MARK: - Build Prompts

    private func buildLocationPrompt() -> String {
        var parts: [String] = []

        parts.append(location.name)

        if !location.description.isEmpty {
            parts.append(location.description)
        }

        parts.append("\(location.locationType) location")

        if let style = location.styleAttributes["architectural_style"], !style.isEmpty {
            parts.append("\(style) architecture")
        }

        if let mood = location.styleAttributes["mood"], !mood.isEmpty {
            parts.append("\(mood) mood")
        }

        if let palette = location.styleAttributes["color_palette"], !palette.isEmpty {
            parts.append(palette)
        }

        if let lighting = location.cinematographyDefaults["lighting"], !lighting.isEmpty {
            parts.append("\(lighting) lighting")
        }

        if let timeOfDay = location.cinematographyDefaults["time_of_day"], !timeOfDay.isEmpty {
            parts.append(timeOfDay)
        }

        parts.append("professional film production design, photorealistic")

        return parts.joined(separator: ", ")
    }

    private func buildVariationPrompt(override: String) -> String {
        var base = buildLocationPrompt()
        base += ", \(override)"
        if effectiveImagePath(for: "primary") != nil {
            base += ". EXACT SAME location as reference, maintain architectural details and environment precisely."
        }
        return base
    }

    // MARK: - Variation Thumbnail Builder

    private func variationThumbnail(_ variation: String, label: String) -> some View {
        let override = variationDefaultOverride(variation)
        return LocationVariationThumbnail(
            label: label,
            imagePath: effectiveImagePath(for: variation),
            projectBasePath: projectBasePath,
            isSelected: selectedPreviewVariation == variation,
            generationProgress: generatingProgress[variation],
            refreshId: imageRefreshIds[variation],
            onSelect: { withAnimation(.easeInOut(duration: 0.2)) { selectedPreviewVariation = variation } },
            onView: { url in
                fullScreenImageURL = url
                fullScreenImageTitle = "\(location.name) - \(label)"
                showingFullScreenImage = true
            },
            onDownload: { url in downloadImage(from: url, suggestedName: "\(location.name)_\(variation).png") },
            onGenerate: {
                generateVariationImage(variation: variation, prompt: buildVariationPrompt(override: override))
            },
            onEditGenerate: {
                if effectiveImagePath(for: variation) != nil {
                    openAnnotationEditor(variation: variation, label: label)
                } else {
                    openPromptEditor(variation: variation, defaultPrompt: buildVariationPrompt(override: override))
                }
            }
        )
    }

    // MARK: - Open Prompt Editor

    private func openPromptEditor(variation: String, defaultPrompt: String) {
        promptEditorVariation = variation
        promptEditorText = defaultPrompt
        showingPromptEditor = true
    }

    private func openAnnotationEditor(variation: String, label: String) {
        guard let imagePath = effectiveImagePath(for: variation),
              let basePath = projectBasePath else { return }
        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let image = NSImage(contentsOf: fullPath) else { return }
        annotationEditorImage = image
        annotationEditorVariation = variation
        annotationEditorTitle = label
        showingAnnotationEditor = true
    }

    private func generateVariationWithAnnotations(variation: String, annotations: [KeyframeAnnotation]) {
        let editPrompt = ImageAnnotationEditor.buildEditPrompt(from: annotations, context: "location \(variation) image")
        let override = variationDefaultOverride(variation)
        let basePrompt = buildVariationPrompt(override: override)
        let combinedPrompt = editPrompt + "\n\nOriginal prompt: " + basePrompt
        generateVariationImage(variation: variation, prompt: combinedPrompt)
    }

    private func variationDefaultOverride(_ variation: String) -> String {
        switch variation {
        case "day": return "bright daylight, clear sky, midday sun"
        case "night": return "nighttime, moonlit, artificial lighting, dark shadows"
        case "golden_hour": return "golden hour, warm sunset, long shadows, amber tones"
        case "overcast": return "overcast sky, diffused light, muted colors, fog or rain"
        case "wide": return "wide establishing shot, full environment, 14mm ultra-wide"
        case "detail": return "extreme close-up, texture and material focus, 100mm macro"
        default: return ""
        }
    }

    // MARK: - Variation Display Name

    private func variationDisplayName(_ variation: String) -> String {
        switch variation {
        case "primary": return "Primary"
        case "day": return "Day"
        case "night": return "Night"
        case "golden_hour": return "Golden Hour"
        case "overcast": return "Overcast"
        case "wide": return "Wide Shot"
        case "detail": return "Detail"
        default: return variation.capitalized
        }
    }

    // MARK: - Download Image

    private func downloadImage(from url: URL, suggestedName: String) {
        guard let imageData = try? Data(contentsOf: url) else { return }

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

    // MARK: - Bindings

    private func styleBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { location.styleAttributes[key] ?? "" },
            set: { location.styleAttributes[key] = $0.isEmpty ? nil : $0 }
        )
    }

    private var parentLocationBinding: Binding<String> {
        Binding(
            get: { location.parentLocation ?? "" },
            set: { location.parentLocation = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Scene Data

    private var scenesAtLocation: [String] {
        var names: [String] = []
        for sequence in project.sequences {
            for scene in sequence.scenes {
                let sceneLocation = (scene.location ?? "").uppercased()
                if sceneLocation.contains(location.name.uppercased()) {
                    names.append(scene.name)
                }
            }
        }
        return names
    }

    private var scenesAtLocationDetailed: [LocationSceneInfo] {
        var scenes: [LocationSceneInfo] = []
        for sequence in project.sequences {
            for scene in sequence.scenes {
                let sceneLocation = (scene.location ?? "").uppercased()
                if sceneLocation.contains(location.name.uppercased()) {
                    let dialogues = scene.dialogues
                    let actions = scene.actions

                    let sampleDialogues = dialogues.prefix(2).map { d in
                        LocationDialogueSample(character: d.character, text: d.text)
                    }
                    let sampleActions = actions.prefix(1).map { $0.description }

                    scenes.append(LocationSceneInfo(
                        sceneName: scene.name,
                        dialogueCount: dialogues.count,
                        actionCount: actions.count,
                        sampleDialogues: Array(sampleDialogues),
                        sampleActions: Array(sampleActions)
                    ))
                }
            }
        }
        return scenes
    }
}

// MARK: - Data Types

private struct LocationDialogueSample: Hashable {
    let character: String
    let text: String
}

private struct LocationSceneInfo: Identifiable, Equatable {
    let id = UUID()
    let sceneName: String
    let dialogueCount: Int
    let actionCount: Int
    let sampleDialogues: [LocationDialogueSample]
    let sampleActions: [String]

    static func == (lhs: LocationSceneInfo, rhs: LocationSceneInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AttributeCard (Location variant)

private struct LocationAttributeCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

// MARK: - LocationTypeChip

private struct LocationTypeChip: View {
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

// MARK: - LocationCompactChip

private struct LocationCompactChip: View {
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

// MARK: - LocationGalleryButton

private struct LocationGalleryButton: View {
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

// MARK: - LocationVariationThumbnail

private struct LocationVariationThumbnail: View {
    let label: String
    let imagePath: String?
    let projectBasePath: URL?
    var isSelected: Bool = false
    var generationProgress: Double?
    var refreshId: UUID?
    var onSelect: (() -> Void)?
    var onView: ((URL) -> Void)?
    var onDownload: ((URL) -> Void)?
    var onGenerate: (() -> Void)?
    var onEditGenerate: (() -> Void)?

    @State private var isHovering = false

    private var hasImage: Bool { imagePath != nil }
    private var isGenerating: Bool { generationProgress != nil }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .quaternarySystemFill))
                    .frame(height: 70)

                if let path = imagePath, let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(path)
                    AsyncImage(url: fullPath) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    .id(refreshId ?? UUID())

                    // Hover overlay with actions
                    if isHovering && !isGenerating {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 70)

                        VStack(spacing: 5) {
                            HStack(spacing: 6) {
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
                                .help("Regenerate with same prompt")

                                Button {
                                    onEditGenerate?()
                                } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: "pencil.and.outline")
                                            .font(.system(size: 7))
                                        Text("Edit")
                                            .font(.system(size: 7, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.orange.opacity(0.8)))
                                }
                                .buttonStyle(.plain)
                                .help("Annotate & edit image")
                            }
                        }
                    }
                } else if !isGenerating {
                    // Empty state — clickable to generate
                    Button {
                        onGenerate?()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: isHovering ? "wand.and.stars" : "plus")
                                .font(.system(size: isHovering ? 16 : 14))
                                .foregroundColor(isHovering ? .accentColor : Color(nsColor: .tertiaryLabelColor))
                            if isHovering {
                                Text("Generate")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                    }
                    .buttonStyle(.plain)
                }

                // Generation progress overlay
                if let progress = generationProgress {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 70)

                    LocationProgressRing(progress: progress, size: 36)
                }

                // Selected or hover border
                if isSelected && hasImage {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(height: 70)
                } else if !hasImage && !isGenerating && isHovering {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                        .frame(height: 70)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if hasImage {
                    onSelect?()
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .accentColor : (isGenerating ? .accentColor : (isHovering ? .primary : .secondary)))
        }
    }
}

// MARK: - LocationProgressRing

private struct LocationProgressRing: View {
    let progress: Double
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

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

// MARK: - LocationFullScreenViewer

private struct LocationFullScreenViewer: View {
    let imageURL: URL?
    let title: String
    var onDownload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
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

// MARK: - Location Prompt Editor

private struct LocationPromptEditor: View {
    let variation: String
    let variationLabel: String
    @Binding var prompt: String
    var onGenerate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("EDIT PROMPT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(variationLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Prompt editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Generation Prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                TextEditor(text: $prompt)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(8)
                    .frame(minHeight: 140)

                Text("Describe the location, mood, lighting, time of day, and camera angle. The AI will generate a photorealistic image based on this prompt.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(2)
            }
            .padding(20)

            Divider()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: onGenerate) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Generate")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Discovered Location Images

struct DiscoveredLocationImages {
    var primary: String?
    var day: String?
    var night: String?
    var goldenHour: String?
    var overcast: String?
    var wide: String?
    var detail: String?

    static func discover(for locationName: String, basePath: URL?) -> DiscoveredLocationImages {
        guard let basePath = basePath else { return DiscoveredLocationImages() }

        var result = DiscoveredLocationImages()
        let fileManager = FileManager.default
        let sanitizedName = sanitizeName(locationName)

        let locationFolder = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("locations")
            .appendingPathComponent(sanitizedName)

        func findImage(patterns: [String]) -> String? {
            guard fileManager.fileExists(atPath: locationFolder.path) else { return nil }
            guard let contents = try? fileManager.contentsOfDirectory(atPath: locationFolder.path) else { return nil }

            let files = contents.compactMap { filename -> (String, Date)? in
                let path = locationFolder.appendingPathComponent(filename).path
                guard let attrs = try? fileManager.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date else { return nil }
                return (filename, modDate)
            }.sorted { $0.1 > $1.1 }

            for (filename, _) in files {
                let lower = filename.lowercased()
                for pattern in patterns {
                    if lower.contains(pattern.lowercased()) && (lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")) {
                        return "assets/locations/\(sanitizedName)/\(filename)"
                    }
                }
            }
            return nil
        }

        result.primary = findImage(patterns: ["primary", "main", "hero"])
        result.day = findImage(patterns: ["day"])
        result.night = findImage(patterns: ["night"])
        result.goldenHour = findImage(patterns: ["golden_hour", "golden", "sunset"])
        result.overcast = findImage(patterns: ["overcast", "rain", "fog"])
        result.wide = findImage(patterns: ["wide", "establishing"])
        result.detail = findImage(patterns: ["detail", "close", "macro"])

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
