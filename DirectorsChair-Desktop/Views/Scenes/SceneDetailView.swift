//
//  SceneDetailView.swift
//  DirectorsChair-Desktop
//
//  Magazine-style scene detail with hero image, stats bar, and two-column layout
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices

struct SceneDetailView: View {
    let scene: DirectorsChairCore.Scene
    let characters: [Character]
    let projectBasePath: URL?
    let onBack: () -> Void
    let onOpenBubble: (DirectorsChairCore.Scene) -> Void
    let onOpenShotList: (DirectorsChairCore.Scene) -> Void
    var onSelectShot: ((DirectorsChairCore.Scene, Shot) -> Void)? = nil
    var onJumpShotToScript: ((DirectorsChairCore.Scene, Shot) -> Void)? = nil
    var onImageGenerated: ((String) -> Void)? = nil
    var onPromptUsed: ((String) -> Void)? = nil
    var onSceneAboutChanged: ((String) -> Void)? = nil
    var onSceneDescriptionChanged: ((String) -> Void)? = nil
    var onSceneNotesChanged: ((String) -> Void)? = nil

    @State var heroImage: NSImage?
    @State var isGeneratingImage = false
    @State var isHoveringHero = false
    @State var showingFullSize = false
    @State var showingPromptEditor = false
    @State var showingAnnotationEditor = false
    @State var editablePrompt = ""
    @State var lastUsedPrompt = ""
    @State var allOverviewImages: [URL] = []
    @State var currentImageIndex: Int = -1

    var parsed: (prefix: String?, location: String, time: String?) {
        SceneCardHelpers.parseSceneLocation(scene.location)
    }

    var duration: Double {
        SceneCardHelpers.estimateSceneDuration(scene: scene)
    }

    // Inline about/description/notes editing (used by SceneDetailView+Cards)
    @State var editAbout: String = ""
    @State var editDescription: String = ""
    @State var editNotes: String = ""
    @State var aboutFieldsInitialized = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                statsBar
                mainContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .top, spacing: 0) { backBar }
        .onAppear {
            loadHeroImage()
            lastUsedPrompt = scene.sceneOverviewPrompt ?? ""
            discoverOverviewImages()
        }
        .onChange(of: scene.id) { _ in
            heroImage = nil
            isGeneratingImage = false
            allOverviewImages = []
            currentImageIndex = -1
            loadHeroImage()
            lastUsedPrompt = scene.sceneOverviewPrompt ?? ""
            discoverOverviewImages()
        }
        .sheet(isPresented: $showingFullSize) {
            ScenePreviewFullSizeSheet(
                image: heroImage,
                sceneName: scene.name,
                isPresented: $showingFullSize,
                onDownload: { downloadImage() }
            )
        }
        .sheet(isPresented: $showingPromptEditor) {
            ScenePromptEditorSheet(
                prompt: $editablePrompt,
                isPresented: $showingPromptEditor,
                onGenerate: { prompt in
                    generateOverviewImage(with: prompt)
                }
            )
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = heroImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT SCENE PREVIEW",
                    subtitle: scene.name,
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generateOverviewWithAnnotations(annotations)
                    }
                )
            }
        }
    }
}
