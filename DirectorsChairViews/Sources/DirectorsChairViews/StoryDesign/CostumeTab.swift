// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/CostumeTab.swift
//
// Costume Design tab - industry-standard costume breakdown with AI visualization

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

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
    @State private var isGeneratingFromReferences = false
    @State private var referenceGenProgress: Double = 0
    @State private var referenceImageRefreshIds: [String: UUID] = [:]
    // Annotation editor state
    @State private var showingAnnotationEditor = false
    @State private var annotationEditorImage: NSImage?
    @State private var annotationEditorAngle: String = ""
    @State private var annotationEditorTitle: String = ""
    // Set as base image state
    @State private var showingSetAsBaseConfirmation = false
    @State private var pendingBaseImagePath: String?

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
                                outfitReferencesCard(costume: costumeBinding)
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
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = annotationEditorImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT COSTUME — \(annotationEditorTitle.uppercased())",
                    subtitle: character.name,
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generateCostumeAngleWithAnnotations(angle: annotationEditorAngle, annotations: annotations)
                    }
                )
            }
        }
        .alert("Replace Base Image?", isPresented: $showingSetAsBaseConfirmation) {
            Button("Replace", role: .destructive) {
                if let path = pendingBaseImagePath {
                    applyCostumeAsBaseImage(imagePath: path)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This character already has a base image. Do you want to replace it with this costume image?")
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

            // View, Edit, and Download for hero
            if let imagePath = costume.wrappedValue.imageFront ?? discoveredImages.front,
               let basePath = projectBasePath {
                let fullPath = basePath.appendingPathComponent(imagePath)
                HStack(spacing: 8) {
                    CostumeGalleryButton(label: "View", icon: "eye", color: .accentColor) {
                        fullScreenImageURL = fullPath
                        fullScreenImageTitle = "\(character.name) - \(costume.wrappedValue.name)"
                        showingFullScreenImage = true
                    }
                    CostumeGalleryButton(label: "Edit", icon: "pencil.and.outline", color: .orange) {
                        openCostumeAnnotationEditor(angleKey: "front", label: "Front", imagePath: imagePath)
                    }
                    CostumeGalleryButton(label: "Download", icon: "arrow.down.circle", color: .green) {
                        downloadImage(from: fullPath, suggestedName: "\(character.name)_\(costume.wrappedValue.name)_front.png")
                    }
                }
                CostumeGalleryButton(label: "Set as Character Base Image", icon: "person.crop.rectangle", color: .purple) {
                    setAsBaseImage(imagePath: imagePath)
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
            },
            onEditAnnotate: imagePath != nil ? {
                openCostumeAnnotationEditor(angleKey: angleKey, label: label, imagePath: imagePath!)
            } : nil
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

    // MARK: - Set as Base Image

    private func setAsBaseImage(imagePath: String) {
        let hasExistingBase = character.baseImage != nil ||
            DiscoveredCharacterImages.discover(for: character.name, basePath: projectBasePath).baseImage != nil

        if hasExistingBase {
            pendingBaseImagePath = imagePath
            showingSetAsBaseConfirmation = true
        } else {
            applyCostumeAsBaseImage(imagePath: imagePath)
        }
    }

    private func applyCostumeAsBaseImage(imagePath: String) {
        guard let basePath = projectBasePath else { return }

        let sourcePath = basePath.appendingPathComponent(imagePath)
        guard let imageData = try? Data(contentsOf: sourcePath) else { return }

        let sanitizedName = DiscoveredCharacterImages.sanitizedName(for: character.name)
        let destDir = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("face")
        let destPath = destDir.appendingPathComponent("base.png")

        // Convert to PNG
        let pngData: Data
        if let nsImage = NSImage(data: imageData), let tiffRep = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRep),
           let converted = bitmap.representation(using: .png, properties: [:]) {
            pngData = converted
        } else {
            pngData = imageData
        }

        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }

            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            try pngData.write(to: destPath)
        } catch {
            print("Failed to set costume as base image: \(error)")
            return
        }

        character.baseImage = "assets/characters/\(sanitizedName)/face/base.png"
    }

    // MARK: - Annotation Editor

    private func costumeImagePath(for angleKey: String) -> String? {
        guard let costume = selectedCostume else { return nil }
        switch angleKey {
        case "front": return costume.imageFront ?? discoveredImages.front
        case "three_quarter_left": return costume.imageThreeQuarterLeft ?? discoveredImages.threeQuarterLeft
        case "three_quarter_right": return costume.imageThreeQuarterRight ?? discoveredImages.threeQuarterRight
        case "profile": return costume.imageProfile ?? discoveredImages.profile
        case "back": return costume.imageBack ?? discoveredImages.back
        case "full_body": return costume.imageFullBody ?? discoveredImages.fullBody
        default: return nil
        }
    }

    private func openCostumeAnnotationEditor(angleKey: String, label: String, imagePath: String) {
        guard let basePath = projectBasePath else { return }
        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let image = NSImage(contentsOf: fullPath) else { return }
        annotationEditorImage = image
        annotationEditorAngle = angleKey
        annotationEditorTitle = label
        showingAnnotationEditor = true
    }

    private func generateCostumeAngleWithAnnotations(angle: String, annotations: [KeyframeAnnotation]) {
        guard let imagePath = costumeImagePath(for: angle),
              let basePath = projectBasePath else { return }

        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let imageData = try? Data(contentsOf: fullPath) else { return }

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

        let progressKey = "costume_\(angle)"
        generatingProgress[progressKey] = 0.0

        Task {
            do {
                let response = try await AIServiceClient.shared.generateImage(request)

                guard let newImageData = response.images.first else {
                    await MainActor.run {
                        generatingProgress.removeValue(forKey: progressKey)
                    }
                    return
                }

                _ = basePath.startAccessingSecurityScopedResource()
                defer { basePath.stopAccessingSecurityScopedResource() }
                try newImageData.write(to: fullPath)

                await MainActor.run {
                    imageRefreshIds[angle] = UUID()
                    withAnimation(.easeOut(duration: 0.3)) {
                        generatingProgress.removeValue(forKey: progressKey)
                    }
                    refreshDiscoveredImages()
                }
            } catch {
                await MainActor.run {
                    generatingProgress.removeValue(forKey: progressKey)
                }
                print("Costume annotation edit failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Outfit References Card

    private func outfitReferencesCard(costume: Binding<CharacterCostume>) -> some View {
        CostumeAttributeCard(title: "OUTFIT REFERENCES", icon: "paperclip") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Upload photos of clothing or accessories to dress the character.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                let refs = costume.wrappedValue.referenceImages ?? []

                // Reference images grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                    ForEach(Array(refs.enumerated()), id: \.element.id) { index, ref in
                        outfitReferenceThumbnail(ref: ref, index: index, costume: costume)
                    }

                    // Add placeholder
                    Button {
                        browseReferenceImage(costume: costume)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Browse & Paste buttons
                HStack(spacing: 8) {
                    CostumeGalleryButton(label: "Browse...", icon: "folder", color: .accentColor) {
                        browseReferenceImage(costume: costume)
                    }
                    CostumeGalleryButton(label: "Paste from Clipboard", icon: "doc.on.clipboard", color: .accentColor) {
                        pasteReferenceImage(costume: costume)
                    }
                }

                // Generate button
                ZStack {
                    CostumeGalleryButton(
                        label: isGeneratingFromReferences ? "Generating..." : "Generate Character in This Outfit",
                        icon: isGeneratingFromReferences ? "hourglass" : "wand.and.stars",
                        color: .accentColor,
                        isProminent: true
                    ) {
                        generateFromReferences(costume: costume)
                    }
                    .disabled(refs.isEmpty || isGeneratingFromReferences)
                    .opacity(refs.isEmpty ? 0.5 : 1)

                    if isGeneratingFromReferences {
                        ProgressView(value: referenceGenProgress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .padding(.horizontal, 12)
                            .offset(y: 14)
                    }
                }
            }
        }
    }

    private func outfitReferenceThumbnail(ref: CostumeReferenceImage, index: Int, costume: Binding<CharacterCostume>) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let basePath = projectBasePath {
                    let fullPath = basePath.appendingPathComponent(ref.imagePath)
                    AsyncImage(url: fullPath) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            refPlaceholder
                        case .empty:
                            ProgressView().frame(width: 80, height: 80)
                        @unknown default:
                            refPlaceholder
                        }
                    }
                    .id(referenceImageRefreshIds[ref.id] ?? UUID())
                } else {
                    refPlaceholder
                }

                // Delete button overlay
                Button {
                    deleteReferenceImage(at: index, costume: costume)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.red).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            .frame(width: 80, height: 80)

            // Editable label
            TextField("Label", text: Binding(
                get: {
                    guard let refs = costume.wrappedValue.referenceImages, index < refs.count else { return ref.label }
                    return refs[index].label
                },
                set: { newVal in
                    if costume.wrappedValue.referenceImages != nil, index < costume.wrappedValue.referenceImages!.count {
                        costume.wrappedValue.referenceImages![index].label = newVal
                    }
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 10))
            .multilineTextAlignment(.center)
            .frame(width: 80)
        }
    }

    private var refPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternarySystemFill))
                .frame(width: 80, height: 80)
            Image(systemName: "photo")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Reference Image Upload

    private func browseReferenceImage(costume: Binding<CharacterCostume>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select outfit or accessory photos"

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let label = url.deletingPathExtension().lastPathComponent
            addReferenceImage(data: data, label: label, costume: costume)
        }
    }

    private func pasteReferenceImage(costume: Binding<CharacterCostume>) {
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
        addReferenceImage(data: data, label: "Pasted Item", costume: costume)
    }

    private func addReferenceImage(data: Data, label: String, costume: Binding<CharacterCostume>) {
        guard let basePath = projectBasePath else { return }

        // Convert to PNG
        let pngData: Data
        if let nsImage = NSImage(data: data), let tiffRep = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRep),
           let converted = bitmap.representation(using: .png, properties: [:]) {
            pngData = converted
        } else {
            pngData = data
        }

        let sanitizedCharName = DiscoveredCostumeImages.sanitizedName(for: character.name)
        let sanitizedCostumeName = DiscoveredCostumeImages.sanitizedName(for: costume.wrappedValue.name)
        let refId = UUID().uuidString.prefix(8)
        let relativePath = "assets/characters/\(sanitizedCharName)/costumes/\(sanitizedCostumeName)/references/ref_\(refId).png"
        let fullPath = basePath.appendingPathComponent(relativePath)
        let dirPath = fullPath.deletingLastPathComponent()

        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }

            try FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: true)
            try pngData.write(to: fullPath)
        } catch {
            print("Failed to save reference image: \(error)")
            return
        }

        let ref = CostumeReferenceImage(label: label, imagePath: relativePath)
        if costume.wrappedValue.referenceImages == nil {
            costume.wrappedValue.referenceImages = [ref]
        } else {
            costume.wrappedValue.referenceImages!.append(ref)
        }
    }

    private func deleteReferenceImage(at index: Int, costume: Binding<CharacterCostume>) {
        guard var refs = costume.wrappedValue.referenceImages, index < refs.count else { return }

        // Delete file from disk
        if let basePath = projectBasePath {
            let fullPath = basePath.appendingPathComponent(refs[index].imagePath)
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }
            try? FileManager.default.removeItem(at: fullPath)
        }

        refs.remove(at: index)
        costume.wrappedValue.referenceImages = refs.isEmpty ? nil : refs
    }

    // MARK: - Generate From References

    private func generateFromReferences(costume: Binding<CharacterCostume>) {
        guard let basePath = projectBasePath,
              let refs = costume.wrappedValue.referenceImages, !refs.isEmpty else { return }
        guard !isGeneratingFromReferences else { return }

        isGeneratingFromReferences = true
        referenceGenProgress = 0

        Task {
            do {
                _ = basePath.startAccessingSecurityScopedResource()
                defer { basePath.stopAccessingSecurityScopedResource() }

                var allRefs: [ReferenceImage] = []

                // Load character base image as reference
                let baseImagePath = character.baseImage ?? DiscoveredCharacterImages.discover(
                    for: character.name,
                    basePath: projectBasePath
                ).baseImage
                if let bip = baseImagePath {
                    let fullBasePath = basePath.appendingPathComponent(bip)
                    if let baseData = try? Data(contentsOf: fullBasePath) {
                        allRefs.append(ReferenceImage(
                            base64: baseData.base64EncodedString(),
                            mimeType: "image/png",
                            label: "character"
                        ))
                    }
                }

                // Load each reference image
                var labels: [String] = []
                for ref in refs {
                    let refFullPath = basePath.appendingPathComponent(ref.imagePath)
                    guard let refData = try? Data(contentsOf: refFullPath) else { continue }
                    allRefs.append(ReferenceImage(
                        base64: refData.base64EncodedString(),
                        mimeType: "image/png",
                        label: ref.label
                    ))
                    labels.append(ref.label)
                }

                await MainActor.run { referenceGenProgress = 0.2 }

                // Build prompt with style directive
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

                let prompt = """
                \(styleDirective). Generate a full-body portrait of this exact character \
                (shown in the "character" reference image) wearing ALL of the following items \
                from the reference images: \(labels.joined(separator: ", ")). \
                Match the character's face, body, and skin tone exactly from the "character" reference. \
                Full body view, costume design reference sheet.
                """

                let request = ImageGenerationRequest(
                    prompt: prompt,
                    provider: .googleImagen,
                    aspectRatio: "1:1",
                    referenceImages: allRefs
                )

                await MainActor.run { referenceGenProgress = 0.4 }

                let response = try await AIServiceClient.shared.generateImage(request)

                await MainActor.run { referenceGenProgress = 0.8 }

                guard let newImageData = response.images.first else {
                    await MainActor.run {
                        isGeneratingFromReferences = false
                        referenceGenProgress = 0
                    }
                    return
                }

                // Save to costume front image
                let sanitizedCharName = DiscoveredCostumeImages.sanitizedName(for: character.name)
                let sanitizedCostumeName = DiscoveredCostumeImages.sanitizedName(for: costume.wrappedValue.name)
                let relativePath = "assets/characters/\(sanitizedCharName)/costumes/\(sanitizedCostumeName)/front.png"
                let savePath = basePath.appendingPathComponent(relativePath)
                let saveDir = savePath.deletingLastPathComponent()

                try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
                try newImageData.write(to: savePath)

                await MainActor.run {
                    costume.wrappedValue.imageFront = relativePath
                    imageRefreshIds["front"] = UUID()
                    referenceGenProgress = 1.0
                    withAnimation(.easeOut(duration: 0.3)) {
                        isGeneratingFromReferences = false
                        referenceGenProgress = 0
                    }
                    refreshDiscoveredImages()
                }
            } catch {
                await MainActor.run {
                    isGeneratingFromReferences = false
                    referenceGenProgress = 0
                }
                print("Generate from references failed: \(error.localizedDescription)")
            }
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

        // Art style directive
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

                                Button { onEditAnnotate?() } label: {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(Color.orange.opacity(0.6)))
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
