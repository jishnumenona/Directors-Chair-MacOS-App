// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/PhysicalAppearanceTab.swift
//
// Physical appearance editor tab - game character customizer style

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

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
    var onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)?  // (angle, prompt, progressHandler)
    var onAnalyzeTraits: (() -> Void)?
    var onUploadReferenceImage: ((Data, @escaping @MainActor (Double) -> Void) -> Void)?

    // State for full screen image viewer
    @State var showingFullScreenImage = false
    @State var fullScreenImageURL: URL?
    @State var fullScreenImageTitle: String = ""

    // State for discovered images (auto-detect from filesystem)
    @State var discoveredImages: DiscoveredCharacterImages = DiscoveredCharacterImages()

    // Per-angle generation progress (nil = idle, 0.0-1.0 = generating)
    @State var generatingProgress: [String: Double] = [:]
    // Cache-busting IDs to force AsyncImage reload after regeneration
    @State var imageRefreshIds: [String: UUID] = [:]

    // Hover state for base image overlay
    @State var isHoveringBaseImage = false

    // Reference image upload state
    @State var isAnalyzingUpload = false
    @State var analysisProgress: Double = 0

    // Annotation editor state
    @State var showingAnnotationEditor = false
    @State var annotationEditorImage: NSImage?
    @State var annotationEditorAngle: String = ""
    @State var annotationEditorTitle: String = ""
    @State var annotationEditorImageType: ImageType = .base

    public init(
        character: Binding<Character>,
        projectBasePath: URL? = nil,
        onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil,
        onAnalyzeTraits: (() -> Void)? = nil,
        onUploadReferenceImage: ((Data, @escaping @MainActor (Double) -> Void) -> Void)? = nil
    ) {
        self._character = character
        self.projectBasePath = projectBasePath
        self.onGenerateImage = onGenerateImage
        self.onAnalyzeTraits = onAnalyzeTraits
        self.onUploadReferenceImage = onUploadReferenceImage
    }

    /// Get effective image path - uses character property if set, otherwise discovered image
    func effectiveImagePath(for type: ImageType) -> String? {
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

    enum ImageType {
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
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = annotationEditorImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT CHARACTER — \(annotationEditorTitle.uppercased())",
                    subtitle: character.name,
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generateAngleWithAnnotations(angle: annotationEditorAngle, annotations: annotations)
                    }
                )
            }
        }
    }
}
