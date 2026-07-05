//
// CostumeTab+Cards.swift
//
// Extracted from CostumeTab.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

extension CostumeTab {

    // MARK: - Costume Selector Strip

    var costumeStrip: some View {
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

    func costumeImageGallery(costume: Binding<CharacterCostume>) -> some View {
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

    func descriptionCard(costume: Binding<CharacterCostume>) -> some View {
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

    func classificationCard(costume: Binding<CharacterCostume>) -> some View {
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

    func colorPaletteCard(costume: Binding<CharacterCostume>) -> some View {
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

    func garmentBreakdownCard(costume: Binding<CharacterCostume>) -> some View {
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

    func materialsCard(costume: Binding<CharacterCostume>) -> some View {
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

    func productionCard(costume: Binding<CharacterCostume>) -> some View {
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

    func scenesCard(costume: Binding<CharacterCostume>) -> some View {
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

    func scenePickerPopover(costume: Binding<CharacterCostume>) -> some View {
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

    func garmentField(label: String, icon: String, text: Binding<String>) -> some View {
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

    var costumePlaceholder: some View {
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

    func costumeAngleThumbnail(label: String, angleKey: String, imagePath: String?, costume: CharacterCostume, anglePrompt: String) -> some View {
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
}
