// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/CostumeTab.swift
//
// Costume Design tab - industry-standard costume breakdown with AI visualization

import SwiftUI
import DirectorsChairCore
import AppKit

// MARK: - CostumeTab

public struct CostumeTab: View {
    @Binding var character: Character
    let projectBasePath: URL?
    let project: Project

    var onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)?

    @State private var selectedCostumeIndex: Int = 0
    @State private var showingFullScreenImage = false
    @State private var fullScreenImageURL: URL?
    @State private var fullScreenImageTitle = ""
    @State private var generatingProgress: [String: Double] = [:]
    @State private var imageRefreshIds: [String: UUID] = [:]
    @State private var discoveredImages: DiscoveredCostumeImages = DiscoveredCostumeImages()
    @State private var newAccessoryText = ""
    @State private var showScenePicker = false

    public init(
        character: Binding<Character>,
        projectBasePath: URL? = nil,
        project: Project = Project(name: ""),
        onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil
    ) {
        self._character = character
        self.projectBasePath = projectBasePath
        self.project = project
        self.onGenerateImage = onGenerateImage
    }

    private var costumes: [CharacterCostume] {
        character.costumes ?? []
    }

    private var selectedCostume: CharacterCostume? {
        guard !costumes.isEmpty, selectedCostumeIndex < costumes.count else { return nil }
        return costumes[selectedCostumeIndex]
    }

    private var selectedCostumeBinding: Binding<CharacterCostume>? {
        guard !costumes.isEmpty, selectedCostumeIndex < costumes.count else { return nil }
        return Binding(
            get: { character.costumes![selectedCostumeIndex] },
            set: { character.costumes![selectedCostumeIndex] = $0 }
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Costume selector strip
            costumeStrip

            Divider()

            if let costumeBinding = selectedCostumeBinding {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left: Image gallery
                        costumeImageGallery(costume: costumeBinding)
                            .frame(width: min(350, geometry.size.width * 0.35))

                        Divider()

                        // Right: Attribute editors
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                descriptionCard(costume: costumeBinding)
                                classificationCard(costume: costumeBinding)
                                colorPaletteCard(costume: costumeBinding)
                                garmentBreakdownCard(costume: costumeBinding)
                                materialsCard(costume: costumeBinding)
                                productionCard(costume: costumeBinding)
                                scenesCard(costume: costumeBinding)
                            }
                            .padding(24)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "tshirt")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Costumes")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Create a costume to start designing wardrobe for this character")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Button {
                        addCostume()
                    } label: {
                        Label("Create First Costume", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if costumes.isEmpty {
                selectedCostumeIndex = 0
            } else {
                selectedCostumeIndex = min(selectedCostumeIndex, costumes.count - 1)
                refreshDiscoveredImages()
            }
        }
        .onChange(of: character.name) { _ in
            refreshDiscoveredImages()
        }
        .sheet(isPresented: $showingFullScreenImage) {
            CostumeFullScreenViewer(
                imageURL: fullScreenImageURL,
                title: fullScreenImageTitle,
                onDownload: {
                    if let url = fullScreenImageURL {
                        downloadImage(from: url, suggestedName: "\(character.name)_costume.png")
                    }
                }
            )
        }
    }

    // MARK: - Costume Selector Strip

    private var costumeStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(costumes.enumerated()), id: \.element.costumeId) { index, costume in
                    CostumeCardView(
                        costume: costume,
                        isSelected: index == selectedCostumeIndex,
                        projectBasePath: projectBasePath,
                        characterName: character.name
                    )
                    .onTapGesture {
                        selectedCostumeIndex = index
                        refreshDiscoveredImages()
                    }
                    .contextMenu {
                        Button("Duplicate") {
                            duplicateCostume(at: index)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteCostume(at: index)
                        }
                    }
                }

                // Add button
                Button {
                    addCostume()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 16))
                        Text("Add")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .frame(width: 60, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Image Gallery (Left Panel)

    private func costumeImageGallery(costume: Binding<CharacterCostume>) -> some View {
        VStack(spacing: 12) {
            // Hero image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 300)

                if let imagePath = costume.wrappedValue.imageFront ?? discoveredImages.front,
                   let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(imagePath)
                    AsyncImage(url: fullPath) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            costumePlaceholder
                        case .empty:
                            ProgressView()
                        @unknown default:
                            costumePlaceholder
                        }
                    }
                    .id(imageRefreshIds["front"] ?? UUID())
                } else {
                    costumePlaceholder
                }

                if let progress = generatingProgress["costume_front"] {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 300)
                    CostumeProgressRing(progress: progress)
                }
            }

            // View and Download for hero
            if let imagePath = costume.wrappedValue.imageFront ?? discoveredImages.front,
               let basePath = projectBasePath {
                let fullPath = basePath.appendingPathComponent(imagePath)
                HStack(spacing: 8) {
                    CostumeGalleryButton(label: "View", icon: "eye", color: .accentColor) {
                        fullScreenImageURL = fullPath
                        fullScreenImageTitle = "\(character.name) - \(costume.wrappedValue.name)"
                        showingFullScreenImage = true
                    }
                    CostumeGalleryButton(label: "Download", icon: "arrow.down.circle", color: .green) {
                        downloadImage(from: fullPath, suggestedName: "\(character.name)_\(costume.wrappedValue.name)_front.png")
                    }
                }
            }

            // Generate button
            CostumeGalleryButton(
                label: generatingProgress["costume_front"] != nil ? "Generating..." : "Generate Costume Image",
                icon: generatingProgress["costume_front"] != nil ? "hourglass" : "wand.and.stars",
                color: .accentColor,
                isProminent: true
            ) {
                generateCostumeImage(costume: costume.wrappedValue, angle: "front")
            }
            .disabled(generatingProgress["costume_front"] != nil)

            // Angle section header
            HStack(spacing: 6) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("COSTUME ANGLES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                Spacer()
                Text("\(costumeAngleCount)/6")
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
                costumeAngleThumbnail(label: "Front", angleKey: "front", imagePath: costume.wrappedValue.imageFront ?? discoveredImages.front, costume: costume.wrappedValue, anglePrompt: "front facing view, full body, looking directly at camera")
                costumeAngleThumbnail(label: "3/4 Left", angleKey: "three_quarter_left", imagePath: costume.wrappedValue.imageThreeQuarterLeft ?? discoveredImages.threeQuarterLeft, costume: costume.wrappedValue, anglePrompt: "three-quarter view from the left side, full body")
                costumeAngleThumbnail(label: "3/4 Right", angleKey: "three_quarter_right", imagePath: costume.wrappedValue.imageThreeQuarterRight ?? discoveredImages.threeQuarterRight, costume: costume.wrappedValue, anglePrompt: "three-quarter view from the right side, full body")
                costumeAngleThumbnail(label: "Profile", angleKey: "profile", imagePath: costume.wrappedValue.imageProfile ?? discoveredImages.profile, costume: costume.wrappedValue, anglePrompt: "side profile view, full body")
                costumeAngleThumbnail(label: "Back", angleKey: "back", imagePath: costume.wrappedValue.imageBack ?? discoveredImages.back, costume: costume.wrappedValue, anglePrompt: "back view, showing back of costume, full body")
                costumeAngleThumbnail(label: "Full Body", angleKey: "full_body", imagePath: costume.wrappedValue.imageFullBody ?? discoveredImages.fullBody, costume: costume.wrappedValue, anglePrompt: "full body shot, head to toe, costume design reference sheet")
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Description Card

    private func descriptionCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "DESCRIPTION", icon: "text.alignleft") {
            VStack(alignment: .leading, spacing: 14) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("e.g., Business Suit, Casual Wear", text: costume.name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                Divider().opacity(0.5)

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    TextEditor(text: costume.description)
                        .font(.system(size: 12))
                        .frame(minHeight: 64)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                Divider().opacity(0.5)

                // AI Prompt Preview
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("AI Prompt Preview")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Text(buildCostumePrompt(costume: costume.wrappedValue))
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .quaternarySystemFill).opacity(0.5))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Classification Card

    private func classificationCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "CLASSIFICATION", icon: "tag") {
            VStack(alignment: .leading, spacing: 14) {
                // Era
                VStack(alignment: .leading, spacing: 6) {
                    Text("Era / Period")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    let eras = ["Contemporary", "1900s", "1920s", "1940s", "1960s", "1980s", "Victorian", "Medieval", "Futuristic", "Fantasy"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                        ForEach(eras, id: \.self) { era in
                            CostumeChip(label: era, isSelected: costume.wrappedValue.era == era) {
                                costume.wrappedValue.era = costume.wrappedValue.era == era ? nil : era
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Style
                VStack(alignment: .leading, spacing: 6) {
                    Text("Style Category")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    let styles = ["Formal", "Casual", "Business", "Uniform", "Athletic", "Fantasy", "Period", "Streetwear", "Evening", "Military"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 4)], spacing: 4) {
                        ForEach(styles, id: \.self) { style in
                            CostumeChip(label: style, isSelected: costume.wrappedValue.styleCategory == style) {
                                costume.wrappedValue.styleCategory = costume.wrappedValue.styleCategory == style ? nil : style
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Color Palette Card

    private func colorPaletteCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "COLOR PALETTE", icon: "paintpalette") {
            VStack(alignment: .leading, spacing: 10) {
                let palette = costume.wrappedValue.colorPalette ?? []
                HStack(spacing: 10) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { index, hex in
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 4) {
                                ColorPicker("", selection: Binding(
                                    get: { Color(hex: hex) },
                                    set: { newColor in
                                        var p = costume.wrappedValue.colorPalette ?? []
                                        if index < p.count {
                                            p[index] = newColor.hexString
                                            costume.wrappedValue.colorPalette = p
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .frame(width: 28, height: 28)

                                Text(hex)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Button {
                                var p = costume.wrappedValue.colorPalette ?? []
                                if index < p.count {
                                    p.remove(at: index)
                                    costume.wrappedValue.colorPalette = p
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                        }
                    }

                    if palette.count < 5 {
                        Button {
                            var p = costume.wrappedValue.colorPalette ?? []
                            p.append("#808080")
                            costume.wrappedValue.colorPalette = p
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "plus")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                }
                                Text("Add")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Garment Breakdown Card

    private func garmentBreakdownCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "GARMENT BREAKDOWN", icon: "tshirt") {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    // Left column
                    VStack(spacing: 12) {
                        garmentField(label: "Top", icon: "tshirt", text: Binding(
                            get: { costume.wrappedValue.garmentTop ?? "" },
                            set: { costume.wrappedValue.garmentTop = $0.isEmpty ? nil : $0 }
                        ))
                        garmentField(label: "Outerwear", icon: "cloud.sun", text: Binding(
                            get: { costume.wrappedValue.outerwear ?? "" },
                            set: { costume.wrappedValue.outerwear = $0.isEmpty ? nil : $0 }
                        ))
                        garmentField(label: "Headwear", icon: "crown", text: Binding(
                            get: { costume.wrappedValue.headwear ?? "" },
                            set: { costume.wrappedValue.headwear = $0.isEmpty ? nil : $0 }
                        ))
                    }

                    // Right column
                    VStack(spacing: 12) {
                        garmentField(label: "Bottom", icon: "figure.walk", text: Binding(
                            get: { costume.wrappedValue.garmentBottom ?? "" },
                            set: { costume.wrappedValue.garmentBottom = $0.isEmpty ? nil : $0 }
                        ))
                        garmentField(label: "Footwear", icon: "shoe", text: Binding(
                            get: { costume.wrappedValue.footwear ?? "" },
                            set: { costume.wrappedValue.footwear = $0.isEmpty ? nil : $0 }
                        ))
                    }
                }

                Divider().opacity(0.5)

                // Accessories
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Accessories")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    let accessories = costume.wrappedValue.accessories ?? []
                    CostumeFlowLayout(spacing: 6) {
                        ForEach(Array(accessories.enumerated()), id: \.offset) { index, accessory in
                            HStack(spacing: 4) {
                                Text(accessory)
                                    .font(.system(size: 10, weight: .medium))
                                Button {
                                    var acc = costume.wrappedValue.accessories ?? []
                                    acc.remove(at: index)
                                    costume.wrappedValue.accessories = acc
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color(nsColor: .quaternarySystemFill))
                            )
                        }

                        // Add accessory inline
                        HStack(spacing: 4) {
                            TextField("Add...", text: $newAccessoryText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10))
                                .frame(width: 60)
                                .onSubmit {
                                    guard !newAccessoryText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                    var acc = costume.wrappedValue.accessories ?? []
                                    acc.append(newAccessoryText.trimmingCharacters(in: .whitespaces))
                                    costume.wrappedValue.accessories = acc
                                    newAccessoryText = ""
                                }
                            Image(systemName: "plus")
                                .font(.system(size: 8))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().stroke(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Materials Card

    private func materialsCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "MATERIALS", icon: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 14) {
                garmentField(label: "Primary Fabric", icon: "square.stack.3d.up", text: Binding(
                    get: { costume.wrappedValue.primaryFabric ?? "" },
                    set: { costume.wrappedValue.primaryFabric = $0.isEmpty ? nil : $0 }
                ))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Select")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    let fabrics = ["Cotton", "Linen", "Silk", "Wool", "Leather", "Denim", "Velvet", "Satin", "Polyester", "Tweed"]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 4)], spacing: 4) {
                        ForEach(fabrics, id: \.self) { fabric in
                            CostumeChip(label: fabric, isSelected: costume.wrappedValue.primaryFabric == fabric) {
                                costume.wrappedValue.primaryFabric = costume.wrappedValue.primaryFabric == fabric ? nil : fabric
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Production Card

    private func productionCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "PRODUCTION", icon: "gearshape") {
            VStack(alignment: .leading, spacing: 14) {
                // Status chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("Status")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        ForEach(CostumeStatus.allCases, id: \.self) { statusOption in
                            CostumeStatusChip(
                                label: statusOption.rawValue,
                                color: statusOption.color,
                                isSelected: costume.wrappedValue.status == statusOption.rawValue
                            ) {
                                costume.wrappedValue.status = costume.wrappedValue.status == statusOption.rawValue ? nil : statusOption.rawValue
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Change Number and Script Day
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Change #")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        TextField("", value: Binding(
                            get: { costume.wrappedValue.changeNumber ?? 0 },
                            set: { costume.wrappedValue.changeNumber = $0 == 0 ? nil : $0 }
                        ), format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(width: 52)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(8)
                    }

                    garmentField(label: "Script Day", icon: "calendar", text: Binding(
                        get: { costume.wrappedValue.scriptDay ?? "" },
                        set: { costume.wrappedValue.scriptDay = $0.isEmpty ? nil : $0 }
                    ))
                }

                Divider().opacity(0.5)

                // SFX Requirements
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.rays")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("SFX Requirements")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    TextEditor(text: Binding(
                        get: { costume.wrappedValue.sfxRequirements ?? "" },
                        set: { costume.wrappedValue.sfxRequirements = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.system(size: 12))
                    .frame(minHeight: 48)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
                }

                // Director's Notes
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Director's Notes")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    TextEditor(text: Binding(
                        get: { costume.wrappedValue.directorNotes ?? "" },
                        set: { costume.wrappedValue.directorNotes = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.system(size: 12))
                    .frame(minHeight: 48)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Scenes Card

    private func scenesCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "SCENES", icon: "film") {
            VStack(alignment: .leading, spacing: 10) {
                let linkedIds = costume.wrappedValue.sceneIds ?? []
                let allScenes = project.sequences.flatMap { seq in
                    seq.scenes.map { scene in (seq.name, scene) }
                }

                if linkedIds.isEmpty {
                    Text("No scenes linked to this costume")
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .padding(.vertical, 4)
                } else {
                    ForEach(linkedIds, id: \.self) { sceneId in
                        if let match = allScenes.first(where: { $0.1.id == sceneId }) {
                            HStack(spacing: 8) {
                                Image(systemName: "film")
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(match.1.name)
                                        .font(.system(size: 11, weight: .medium))
                                    Text(match.0)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    var ids = costume.wrappedValue.sceneIds ?? []
                                    ids.removeAll { $0 == sceneId }
                                    costume.wrappedValue.sceneIds = ids
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Button {
                    showScenePicker = true
                } label: {
                    Label("Link Scene", systemImage: "link")
                        .font(.system(size: 11, weight: .medium))
                }
                .popover(isPresented: $showScenePicker) {
                    scenePickerPopover(costume: costume)
                }
            }
        }
    }

    private func scenePickerPopover(costume: Binding<CharacterCostume>) -> some View {
        VStack(spacing: 0) {
            Text("Link Scene")
                .font(.headline)
                .padding()

            Divider()

            let linkedIds = Set(costume.wrappedValue.sceneIds ?? [])
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(project.sequences) { sequence in
                        ForEach(sequence.scenes) { scene in
                            let isLinked = linkedIds.contains(scene.id)
                            Button {
                                var ids = costume.wrappedValue.sceneIds ?? []
                                if isLinked {
                                    ids.removeAll { $0 == scene.id }
                                } else {
                                    ids.append(scene.id)
                                }
                                costume.wrappedValue.sceneIds = ids
                            } label: {
                                HStack {
                                    Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isLinked ? .accentColor : .secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(scene.name)
                                            .font(.system(size: 11, weight: .medium))
                                        Text(sequence.name)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isLinked ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(8)
            }
            .frame(width: 280, height: 300)
        }
    }

    // MARK: - Helper Views

    private func garmentField(label: String, icon: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
    }

    private var costumePlaceholder: some View {
        VStack {
            Image(systemName: "tshirt")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Angle Thumbnails

    private func costumeAngleThumbnail(label: String, angleKey: String, imagePath: String?, costume: CharacterCostume, anglePrompt: String) -> some View {
        CostumeAngleThumbnailView(
            label: label,
            imagePath: imagePath,
            projectBasePath: projectBasePath,
            generationProgress: generatingProgress["costume_\(angleKey)"],
            refreshId: imageRefreshIds[angleKey],
            onView: { url in
                fullScreenImageURL = url
                fullScreenImageTitle = "\(character.name) - \(costume.name) - \(label)"
                showingFullScreenImage = true
            },
            onDownload: { url in
                downloadImage(from: url, suggestedName: "\(character.name)_\(costume.name)_\(angleKey).png")
            },
            onGenerate: {
                generateCostumeImage(costume: costume, angle: angleKey, angleDescription: anglePrompt)
            }
        )
    }

    // MARK: - Actions

    private func addCostume() {
        var costumes = character.costumes ?? []
        let name = "Costume \(costumes.count + 1)"
        costumes.append(CharacterCostume(name: name))
        character.costumes = costumes
        selectedCostumeIndex = costumes.count - 1
    }

    private func duplicateCostume(at index: Int) {
        guard let costumes = character.costumes, index < costumes.count else { return }
        let original = costumes[index]
        let duplicate = CharacterCostume(
            name: "\(original.name) Copy",
            description: original.description,
            era: original.era,
            styleCategory: original.styleCategory,
            colorPalette: original.colorPalette,
            garmentTop: original.garmentTop,
            garmentBottom: original.garmentBottom,
            footwear: original.footwear,
            outerwear: original.outerwear,
            headwear: original.headwear,
            accessories: original.accessories,
            primaryFabric: original.primaryFabric,
            status: "Concept"
        )
        character.costumes?.append(duplicate)
        selectedCostumeIndex = (character.costumes?.count ?? 1) - 1
    }

    private func deleteCostume(at index: Int) {
        guard character.costumes != nil, index < character.costumes!.count else { return }
        character.costumes!.remove(at: index)
        if character.costumes!.isEmpty {
            selectedCostumeIndex = 0
        } else {
            selectedCostumeIndex = min(selectedCostumeIndex, character.costumes!.count - 1)
        }
    }

    // MARK: - Image Generation

    private func generateCostumeImage(costume: CharacterCostume, angle: String, angleDescription: String? = nil) {
        let progressKey = "costume_\(angle)"
        guard generatingProgress[progressKey] == nil else { return }
        generatingProgress[progressKey] = 0.0

        var prompt = buildCostumePrompt(costume: costume)
        if let desc = angleDescription {
            prompt += ", \(desc)"
        }
        prompt += ", costume design reference, full body shot"

        let costumeAngle = "costume:\(costume.name):\(angle)"

        onGenerateImage?(costumeAngle, prompt) { progress in
            if progress >= 1.0 {
                self.imageRefreshIds[angle] = UUID()
                withAnimation(.easeOut(duration: 0.3)) {
                    self.generatingProgress.removeValue(forKey: progressKey)
                }
                self.refreshDiscoveredImages()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.generatingProgress[progressKey] = progress
                }
            }
        }
    }

    private func buildCostumePrompt(costume: CharacterCostume) -> String {
        var parts: [String] = []

        // Character physical description
        parts.append("\(character.gender) character")
        if character.age > 0 { parts.append("age \(character.age)") }
        if !character.build.isEmpty { parts.append("\(character.build.lowercased()) build") }
        if !character.hairColor.isEmpty { parts.append("\(character.hairColor) hair") }
        if !character.ethnicity.isEmpty { parts.append("\(character.ethnicity) ethnicity") }

        // Costume description
        parts.append("wearing \(costume.name)")
        if !costume.description.isEmpty { parts.append(costume.description) }

        // Garment details
        var garments: [String] = []
        if let top = costume.garmentTop, !top.isEmpty { garments.append("top: \(top)") }
        if let bottom = costume.garmentBottom, !bottom.isEmpty { garments.append("bottom: \(bottom)") }
        if let foot = costume.footwear, !foot.isEmpty { garments.append("footwear: \(foot)") }
        if let outer = costume.outerwear, !outer.isEmpty { garments.append("outerwear: \(outer)") }
        if let head = costume.headwear, !head.isEmpty { garments.append("headwear: \(head)") }
        if !garments.isEmpty { parts.append(garments.joined(separator: ", ")) }

        if let era = costume.era { parts.append("\(era) period") }
        if let style = costume.styleCategory { parts.append("\(style) style") }

        if let palette = costume.colorPalette, !palette.isEmpty {
            parts.append("color palette: \(palette.joined(separator: ", "))")
        }
        if let fabric = costume.primaryFabric, !fabric.isEmpty {
            parts.append("\(fabric) fabric")
        }

        return parts.joined(separator: ", ")
    }

    private var costumeAngleCount: Int {
        guard let costume = selectedCostume else { return 0 }
        let paths: [String?] = [
            costume.imageFront ?? discoveredImages.front,
            costume.imageThreeQuarterLeft ?? discoveredImages.threeQuarterLeft,
            costume.imageThreeQuarterRight ?? discoveredImages.threeQuarterRight,
            costume.imageProfile ?? discoveredImages.profile,
            costume.imageBack ?? discoveredImages.back,
            costume.imageFullBody ?? discoveredImages.fullBody
        ]
        return paths.compactMap { $0 }.count
    }

    private func refreshDiscoveredImages() {
        guard let costume = selectedCostume else { return }
        discoveredImages = DiscoveredCostumeImages.discover(
            for: character.name,
            costumeName: costume.name,
            basePath: projectBasePath
        )
    }

    private func downloadImage(from url: URL, suggestedName: String) {
        guard let imageData = try? Data(contentsOf: url) else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = suggestedName
        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                try? imageData.write(to: saveURL)
            }
        }
    }
}

// MARK: - Costume Card View (Selector Strip)

private struct CostumeCardView: View {
    let costume: CharacterCostume
    let isSelected: Bool
    let projectBasePath: URL?
    let characterName: String

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .quaternarySystemFill))
                    .frame(width: 40, height: 40)

                if let imagePath = costume.imageFront, let basePath = projectBasePath {
                    AsyncImage(url: basePath.appendingPathComponent(imagePath)) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: "tshirt")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "tshirt")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(costume.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if let status = costume.status {
                    Text(status)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .quaternarySystemFill).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Costume Attribute Card

private struct CostumeAttributeCard<Content: View>: View {
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

// MARK: - Costume Chip

private struct CostumeChip: View {
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

// MARK: - Costume Status Chip

private enum CostumeStatus: String, CaseIterable {
    case concept = "Concept"
    case sourcing = "Sourcing"
    case fitting = "Fitting"
    case ready = "Ready"
    case retired = "Retired"

    var color: Color {
        switch self {
        case .concept: return .gray
        case .sourcing: return .orange
        case .fitting: return .blue
        case .ready: return .green
        case .retired: return .red
        }
    }
}

private struct CostumeStatusChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color.opacity(0.2) : Color(nsColor: .quaternarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Costume Gallery Button

private struct CostumeGalleryButton: View {
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

// MARK: - Costume Progress Ring

private struct CostumeProgressRing: View {
    let progress: Double
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
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

// MARK: - Costume Angle Thumbnail

private struct CostumeAngleThumbnailView: View {
    let label: String
    let imagePath: String?
    let projectBasePath: URL?
    var generationProgress: Double?
    var refreshId: UUID?
    var onView: ((URL) -> Void)?
    var onDownload: ((URL) -> Void)?
    var onGenerate: (() -> Void)?

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
                            image.resizable().scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "tshirt")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                        }
                    }
                    .id(refreshId ?? UUID())

                    if isHovering && !isGenerating {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 80, height: 80)

                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Button { onView?(fullPath) } label: {
                                    Image(systemName: "eye")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)

                                Button { onDownload?(fullPath) } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                            }

                            Button { onGenerate?() } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 8))
                                    Text("Redo")
                                        .font(.system(size: 8, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if !isGenerating {
                    Button { onGenerate?() } label: {
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
                }

                if let progress = generationProgress {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 80, height: 80)
                    CostumeProgressRing(progress: progress, size: 44)
                }

                if !hasImage && !isGenerating && isHovering {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 80, height: 80)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isGenerating ? .accentColor : (isHovering ? .primary : .secondary))
        }
    }
}

// MARK: - Full Screen Image Viewer

private struct CostumeFullScreenViewer: View {
    let imageURL: URL?
    let title: String
    var onDownload: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button { onDownload?() } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                Button { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.8)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        ScrollView([.horizontal, .vertical]) {
                            image.resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        VStack {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 48)).foregroundColor(.orange)
                            Text("Failed to load image").foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.black)
    }
}

// MARK: - Flow Layout (for accessories)

private struct CostumeFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
            totalHeight = max(totalHeight, currentY + size.height)
        }

        return (CGSize(width: width, height: totalHeight), positions)
    }
}

// MARK: - Discovered Costume Images

struct DiscoveredCostumeImages {
    var front: String?
    var threeQuarterLeft: String?
    var threeQuarterRight: String?
    var profile: String?
    var back: String?
    var fullBody: String?

    static func discover(for characterName: String, costumeName: String, basePath: URL?) -> DiscoveredCostumeImages {
        guard let basePath = basePath else { return DiscoveredCostumeImages() }

        var result = DiscoveredCostumeImages()
        let fileManager = FileManager.default

        let sanitizedCharName = sanitizeName(characterName)
        let sanitizedCostumeName = sanitizeName(costumeName)

        let costumeFolder = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedCharName)
            .appendingPathComponent("costumes")
            .appendingPathComponent(sanitizedCostumeName)

        func findImage(patterns: [String]) -> String? {
            guard fileManager.fileExists(atPath: costumeFolder.path) else { return nil }
            guard let contents = try? fileManager.contentsOfDirectory(atPath: costumeFolder.path) else { return nil }

            let files = contents.compactMap { filename -> (String, Date)? in
                let path = costumeFolder.appendingPathComponent(filename).path
                guard let attrs = try? fileManager.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date else { return nil }
                return (filename, modDate)
            }.sorted { $0.1 > $1.1 }

            for (filename, _) in files {
                let lower = filename.lowercased()
                for pattern in patterns {
                    if lower.contains(pattern.lowercased()) && (lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")) {
                        return "assets/characters/\(sanitizedCharName)/costumes/\(sanitizedCostumeName)/\(filename)"
                    }
                }
            }
            return nil
        }

        result.front = findImage(patterns: ["front"])
        result.threeQuarterLeft = findImage(patterns: ["three_quarter_left", "3_4_left"])
        result.threeQuarterRight = findImage(patterns: ["three_quarter_right", "3_4_right"])
        result.profile = findImage(patterns: ["profile"])
        result.back = findImage(patterns: ["back"])
        result.fullBody = findImage(patterns: ["full_body", "fullbody"])

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
