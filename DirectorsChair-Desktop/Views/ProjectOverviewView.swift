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

final class OverviewImageCache {
    static let shared = OverviewImageCache()
    private let cache = NSCache<NSString, NSImage>()

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

    private var allShotsWithImages: [(shot: Shot, sceneName: String)] {
        allScenes.flatMap { scene in
            scene.shots.compactMap { shot in
                guard let _ = shot.previewImage, !shot.previewImage!.isEmpty else { return nil }
                return (shot: shot, sceneName: scene.name)
            }
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
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
                        sceneCount: allScenes.count,
                        characterCount: project.characters.count,
                        shotCount: allScenes.flatMap(\.shots).count,
                        locationCount: project.locations.count
                    )

                    // 4. Scene Gallery
                    if !allScenes.isEmpty {
                        OverviewSceneGallery(
                            scenes: allScenes,
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
                    if !allShotsWithImages.isEmpty {
                        OverviewShotBoard(
                            shots: allShotsWithImages,
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
