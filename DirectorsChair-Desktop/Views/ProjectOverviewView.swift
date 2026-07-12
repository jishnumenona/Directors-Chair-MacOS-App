//
//  ProjectOverviewView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Cinematic Pitch Deck — investor/stakeholder-ready overview
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Image Cache

final class OverviewImageCache: @unchecked Sendable {
    static let shared = OverviewImageCache()
    private let cache = NSCache<NSString, NSImage>()  // NSCache is thread-safe

    private init() {
        cache.countLimit = 200
    }

    func image(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: NSImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// Loads the first existing image among `paths` (relative to `base`) WITHOUT
    /// blocking the main thread: a cache hit calls `assign` immediately; a miss
    /// decodes off-main and calls `assign` back on the main actor. Overview cards
    /// previously decoded synchronously in `.onAppear`, so mounting a tab full of
    /// cards stalled the main thread for seconds (perf: tab first-mount).
    @MainActor
    func loadAsync(paths: [String], base: URL?, assign: @escaping @MainActor (NSImage) -> Void) {
        guard let base else { return }
        let urls = paths.filter { !$0.isEmpty }.map { base.appendingPathComponent($0) }
        for url in urls where image(forKey: url.path) != nil {
            if let cached = image(forKey: url.path) { assign(cached); return }
        }
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            for url in urls {
                if let img = NSImage(contentsOf: url) {
                    Self.shared.setImage(img, forKey: url.path)
                    await MainActor.run { assign(img) }
                    return
                }
            }
        }
    }
}

// MARK: - Main View

struct ProjectOverviewView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var isEditingPitch = false

    private var project: Project { projectViewModel.project }

    private var projectDir: URL? {
        projectViewModel.projectPath?.deletingLastPathComponent()
    }

    private var allScenes: [DirectorsChairCore.Scene] {
        project.sequences.flatMap(\.scenes)
    }

    /// Shots with a non-empty preview image, given an already-computed scene
    /// list. Takes `scenes` as a parameter so a single `body` pass walks the
    /// project once instead of recomputing `allScenes` inside this getter.
    private func shotsWithImages(in scenes: [DirectorsChairCore.Scene]) -> [(shot: Shot, sceneName: String)] {
        scenes.flatMap { scene in
            scene.shots.compactMap { shot in
                guard let preview = shot.previewImage, !preview.isEmpty else { return nil }
                return (shot: shot, sceneName: scene.name)
            }
        }
    }

    var body: some View {
        // Walk the project once per body pass. Previously `allScenes` (O(scenes))
        // was recomputed ~4× and the shot list (O(scenes×shots)) twice per body,
        // and every whole-project publish re-ran all of it (audit A8).
        let scenes = allScenes
        let shotsWithImages = shotsWithImages(in: scenes)
        let totalShotCount = scenes.reduce(0) { $0 + $1.shots.count }
        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Hero Banner
                OverviewHeroBanner(
                    project: $projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    projectDir: projectDir,
                    onProjectChanged: { projectViewModel.isDirty = true }
                )

                VStack(alignment: .leading, spacing: 32) {
                    // 2. Logline & Pitch
                    OverviewLoglineSection(
                        project: $projectViewModel.project,
                        isEditing: $isEditingPitch,
                        onProjectChanged: { projectViewModel.isDirty = true }
                    )

                    // 3. Stats Bar
                    OverviewStatsBar(
                        sequenceCount: project.sequences.count,
                        sceneCount: scenes.count,
                        characterCount: project.characters.count,
                        shotCount: totalShotCount,
                        locationCount: project.locations.count
                    )

                    // 4. Scene Gallery
                    if !scenes.isEmpty {
                        OverviewSceneGallery(
                            scenes: scenes,
                            sequences: project.sequences,
                            projectDir: projectDir,
                            onSceneSelected: { scene in
                                coordinator.selectScene(scene)
                                coordinator.navigateTo(.scenes)
                            }
                        )
                    }

                    // 5. Characters Strip
                    if !project.characters.isEmpty {
                        OverviewCharacterStrip(
                            characters: project.characters,
                            projectDir: projectDir,
                            onCharacterSelected: { character in
                                coordinator.selectCharacter(character)
                            }
                        )
                    }

                    // 6. Shot Board
                    if !shotsWithImages.isEmpty {
                        OverviewShotBoard(
                            shots: shotsWithImages,
                            projectDir: projectDir,
                            onShotSelected: { shot in
                                coordinator.selectedShot = shot
                                coordinator.navigateTo(.shotList)
                            }
                        )
                    }

                    // 7. Locations Gallery
                    if !project.locations.isEmpty {
                        OverviewLocationGallery(
                            locations: project.locations,
                            projectDir: projectDir,
                            onLocationSelected: { location in
                                coordinator.selectLocation(location)
                            }
                        )
                    }

                    // 8. Quick Actions
                    OverviewQuickActions()
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
