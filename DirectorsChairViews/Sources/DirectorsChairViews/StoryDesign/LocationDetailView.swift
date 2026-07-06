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
    @State var showingFullScreenImage = false
    @State var fullScreenImageURL: URL?
    @State var fullScreenImageTitle: String = ""

    // State for discovered images
    @State var discoveredImages: DiscoveredLocationImages = DiscoveredLocationImages()

    // Which variation is shown in the hero preview ("primary", "day", "night", etc.)
    @State var selectedPreviewVariation: String = "primary"

    // Prompt editor state
    @State var showingPromptEditor = false
    @State var promptEditorVariation: String = ""
    @State var promptEditorText: String = ""

    // Per-variation generation progress (nil = idle, 0.0-1.0 = generating)
    @State var generatingProgress: [String: Double] = [:]
    // Cache-busting IDs to force AsyncImage reload
    @State var imageRefreshIds: [String: UUID] = [:]

    // Annotation editor state
    // Hover state for hero image overlay
    @State var isHoveringHeroImage = false

    @State var showingAnnotationEditor = false
    @State var annotationEditorImage: NSImage?
    @State var annotationEditorVariation: String = ""
    @State var annotationEditorTitle: String = ""

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
}
