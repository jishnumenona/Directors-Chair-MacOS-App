//
// LocationDetailView+Cards.swift
//
// Extracted from LocationDetailView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import AppKit

extension LocationDetailView {

    // MARK: - Effective Image Path

    func effectiveImagePath(for variation: String) -> String? {
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

    /// Commit the rename popover. Assigning through the (cascading) binding
    /// rewrites every reference before the new value lands (WS2.5b).
    func commitLocationRename() {
        let newName = renameDraft.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else {
            showingRenamePopover = false
            return
        }
        location.name = newName
        showingRenamePopover = false
    }

    var locationIdentityHeader: some View {
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

    var descriptionCard: some View {
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

    var atmosphereCard: some View {
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

    var cinematographyCard: some View {
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

    var scriptContextCard: some View {
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

    var technicalDetailsCard: some View {
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

    var directorsNotesCard: some View {
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

    var imageGallerySection: some View {
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
                            HStack(spacing: 6) {
                                Text(location.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                // Rename: assigning through the binding runs the
                                // WS2.5b cascade (scene/sequence locations,
                                // schedule rows, gantt tasks follow).
                                Button {
                                    renameDraft = location.name
                                    showingRenamePopover = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Rename location — all scene and schedule references follow automatically")
                                .accessibilityLabel("Rename location")
                                .popover(isPresented: $showingRenamePopover) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Rename Location")
                                            .font(.headline)
                                        TextField("Location name", text: $renameDraft)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 240)
                                            .onSubmit { commitLocationRename() }
                                        Text("All scenes, schedule items, and gantt tasks using this location will follow the new name.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 240, alignment: .leading)
                                        HStack {
                                            Spacer()
                                            Button("Cancel") { showingRenamePopover = false }
                                            Button("Rename") { commitLocationRename() }
                                                .keyboardShortcut(.defaultAction)
                                                .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                                        }
                                    }
                                    .padding(14)
                                }
                            }
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
}
