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

    @State var selectedCostumeIndex: Int = 0
    @State var showingFullScreenImage = false
    @State var fullScreenImageURL: URL?
    @State var fullScreenImageTitle = ""
    @State var generatingProgress: [String: Double] = [:]
    @State var imageRefreshIds: [String: UUID] = [:]
    @State var discoveredImages: DiscoveredCostumeImages = DiscoveredCostumeImages()
    @State var newAccessoryText = ""
    @State var showScenePicker = false
    @State var isGeneratingFromReferences = false
    @State var referenceGenProgress: Double = 0
    @State var referenceImageRefreshIds: [String: UUID] = [:]
    // DC-0112: the Studio replaces the annotation editor.
    @State var showingStudio = false
    @State var studioAngle: String = ""
    @State var studioTitle: String = ""
    // Set as base image state
    @State var showingSetAsBaseConfirmation = false
    @State var pendingBaseImagePath: String?

    public init(
        character: Binding<Character>,
        projectBasePath: URL? = nil,
        project: Project = Project(name: ""),
        initialCostumeIndex: Int? = nil,
        onGenerateImage: ((String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil
    ) {
        self._character = character
        self.projectBasePath = projectBasePath
        self.project = project
        if let initialCostumeIndex {
            self._selectedCostumeIndex = State(initialValue: initialCostumeIndex)
        }
        self.onGenerateImage = onGenerateImage
    }

    var costumes: [CharacterCostume] {
        character.costumes ?? []
    }

    var selectedCostume: CharacterCostume? {
        guard !costumes.isEmpty, selectedCostumeIndex < costumes.count else { return nil }
        return costumes[selectedCostumeIndex]
    }

    var selectedCostumeBinding: Binding<CharacterCostume>? {
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
        .sheet(isPresented: $showingStudio) {
            ShotSketchStudio(
                characters: project.characters, locations: project.locations,
                props: project.props, shots: project.studioShots,
                subjectLibraryId: "costume-\(character.name)-\(selectedCostume?.name ?? "")",
                title: "\(character.name) — \(selectedCostume?.name ?? "costume") — \(studioTitle)",
                keepLabel: "costume picture",
                targetSize: ImageTargetSize(width: 1024, height: 1024),
                projectDirectory: projectBasePath,
                seedPrompt: "",
                currentPreviewPath: costumeImagePath(for: studioAngle),
                documentURL: ShotSketchStudio.documentURL(
                    projectDirectory: projectBasePath,
                    subject: "costume-\(character.name)-\(selectedCostume?.name ?? "")-\(studioAngle)"),
                onKeep: { data in keepStudioResult(data, angle: studioAngle) },
                onSketchSaved: { _ in })
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
}
