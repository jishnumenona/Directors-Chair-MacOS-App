//
// CostumeTab+References.swift
//
// Extracted from CostumeTab.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

extension CostumeTab {

    // MARK: - Outfit References Card

    func outfitReferencesCard(costume: Binding<CharacterCostume>) -> some View {
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

    func outfitReferenceThumbnail(ref: CostumeReferenceImage, index: Int, costume: Binding<CharacterCostume>) -> some View {
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

    var refPlaceholder: some View {
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

    func browseReferenceImage(costume: Binding<CharacterCostume>) {
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

    func pasteReferenceImage(costume: Binding<CharacterCostume>) {
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

    func addReferenceImage(data: Data, label: String, costume: Binding<CharacterCostume>) {
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

    func deleteReferenceImage(at index: Int, costume: Binding<CharacterCostume>) {
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

    func generateFromReferences(costume: Binding<CharacterCostume>) {
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

    func generateCostumeImage(costume: CharacterCostume, angle: String, angleDescription: String? = nil) {
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

    func buildCostumePrompt(costume: CharacterCostume) -> String {
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

    var costumeAngleCount: Int {
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

    func refreshDiscoveredImages() {
        guard let costume = selectedCostume else { return }
        discoveredImages = DiscoveredCostumeImages.discover(
            for: character.name,
            costumeName: costume.name,
            basePath: projectBasePath
        )
    }

    func downloadImage(from url: URL, suggestedName: String) {
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
