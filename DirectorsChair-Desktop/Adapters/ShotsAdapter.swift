//
//  ShotsAdapter.swift
//  DirectorsChair-Desktop
//
//  Phase 9: Architecture Fixes
//  Adapter for CinematographyView to work with scene-based shots
//

import Foundation
import DirectorsChairCore

/// Adapter that bridges CinematographyView (expects flat array) with the actual model (shots in scenes)
@MainActor
class ShotsAdapter: ObservableObject {
    /// Flattened array of all shots across all scenes
    @Published private(set) var allShots: [Shot] = []

    /// Reference to the project
    private var project: Project

    /// Callback when shots are modified
    private var onShotsChanged: (Project) -> Void

    init(project: Project, onShotsChanged: @escaping (Project) -> Void) {
        self.project = project
        self.onShotsChanged = onShotsChanged
        self.allShots = flattenShots(from: project)
    }

    /// Flatten all shots from all scenes into a single array
    private func flattenShots(from project: Project) -> [Shot] {
        project.sequences.flatMap { sequence in
            sequence.scenes.flatMap { scene in
                scene.shots
            }
        }
    }

    /// Update shots - syncs changes back to the correct scenes
    func updateShots(_ updatedShots: [Shot]) {
        // Create a map of shot ID to updated shot for quick lookup
        let shotMap = Dictionary(updatedShots.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })

        // Update the project's sequences/scenes with modified shots
        var updatedProject = project

        for (seqIdx, sequence) in updatedProject.sequences.enumerated() {
            for (sceneIdx, scene) in sequence.scenes.enumerated() {
                var updatedScene = scene
                var updatedSceneShots: [Shot] = []

                // `updatedShots` is the authoritative complete set of shots. A
                // scene shot present in it is updated; one ABSENT from it was
                // deleted and must be dropped. Previously such shots were "kept
                // as-is", so deletions never persisted and resurrected on reload
                // (zombie shots).
                for shot in scene.shots {
                    if let updatedShot = shotMap[shot.id] {
                        updatedSceneShots.append(updatedShot)
                    }
                    // else: deleted from the update set — do not carry it forward.
                }

                updatedScene.shots = updatedSceneShots
                updatedProject.sequences[seqIdx].scenes[sceneIdx] = updatedScene
            }
        }

        // Check for any new shots (not in any existing scene)
        let existingShotIds = Set(allShots.map { $0.id })
        let newShots = updatedShots.filter { !existingShotIds.contains($0.id) }

        // Add new shots to the first scene of first sequence (or create a default scene)
        if !newShots.isEmpty {
            if updatedProject.sequences.isEmpty {
                // Create default sequence and scene
                let defaultScene = DirectorsChairCore.Scene(
                    name: "Scene 1",
                    description: "INT. LOCATION - DAY",
                    dialogues: [],
                    actions: [],
                    soundNotes: [],
                    shots: newShots,
                    locationImages: []
                )
                let defaultSequence = DirectorsChairCore.Sequence(
                    name: "Sequence 1",
                    description: "",
                    scenes: [defaultScene]
                )
                updatedProject.sequences.append(defaultSequence)
            } else if updatedProject.sequences[0].scenes.isEmpty {
                // Add default scene to first sequence
                let defaultScene = DirectorsChairCore.Scene(
                    name: "Scene 1",
                    description: "INT. LOCATION - DAY",
                    dialogues: [],
                    actions: [],
                    soundNotes: [],
                    shots: newShots,
                    locationImages: []
                )
                updatedProject.sequences[0].scenes.append(defaultScene)
            } else {
                // Add to first scene of first sequence
                updatedProject.sequences[0].scenes[0].shots.append(contentsOf: newShots)
            }
        }

        // Update local state
        self.project = updatedProject
        self.allShots = flattenShots(from: updatedProject)

        // Notify parent
        onShotsChanged(updatedProject)
    }

    /// Refresh the flattened shots from the project (call when project changes externally)
    func refresh(from project: Project) {
        self.project = project
        self.allShots = flattenShots(from: project)
    }
}
