// CurationViewModel.swift
// DirectorsChair-Desktop
//
// ViewModel for the Curation tab — footage organization and symlink generation

import Foundation
import DirectorsChairCore
import DirectorsChairViews
import AppKit
import UniformTypeIdentifiers

/// Represents a file found on a camera source (SD card, external drive)
struct CameraFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var fileName: String { url.lastPathComponent }
    var fileSize: Int64
    var creationDate: Date?
    var mappedToTakeId: String?
}

@MainActor
class CurationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var selectedScene: DCScene?
    @Published var selectedShot: Shot?
    @Published var selectedTake: Take?
    @Published var cameraSourceDirectory: URL?
    @Published var cameraFiles: [CameraFile] = []
    @Published var filterRating: TakeRating?
    @Published var isGeneratingLinks: Bool = false
    @Published var searchQuery: String = ""

    // MARK: - Camera Source Directory

    /// Opens an NSOpenPanel to select the camera source directory
    func selectCameraSourceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the camera source folder (e.g., SD card DCIM folder)"

        if panel.runModal() == .OK, let url = panel.url {
            cameraSourceDirectory = url
            scanCameraFiles()
        }
    }

    /// Scans the camera source directory for video files
    func scanCameraFiles() {
        guard let sourceDir = cameraSourceDirectory else { return }
        let fm = FileManager.default

        var files: [CameraFile] = []

        let videoExtensions = Set(["mov", "mp4", "m4v", "mxf", "avi", "mkv", "mts", "m2ts"])

        if let enumerator = fm.enumerator(at: sourceDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard videoExtensions.contains(ext) else { continue }

                let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let file = CameraFile(
                    url: fileURL,
                    fileSize: Int64(resourceValues?.fileSize ?? 0),
                    creationDate: resourceValues?.creationDate,
                    mappedToTakeId: nil
                )
                files.append(file)
            }
        }

        cameraFiles = files.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// Maps a camera file to a take
    func mapCameraFile(_ file: CameraFile, toTake take: Take, inShot shot: Shot, project: inout Project) {
        // Find and update the take in the project
        for seqIdx in project.sequences.indices {
            for sceneIdx in project.sequences[seqIdx].scenes.indices {
                for shotIdx in project.sequences[seqIdx].scenes[sceneIdx].shots.indices {
                    let s = project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx]
                    if s.shotId == shot.shotId {
                        for takeIdx in project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes.indices {
                            if project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].id == take.id {
                                project.sequences[seqIdx].scenes[sceneIdx].shots[shotIdx].takes[takeIdx].cameraSourceFileName = file.fileName
                            }
                        }
                    }
                }
            }
        }

        // Update mapping state
        if let idx = cameraFiles.firstIndex(where: { $0.id == file.id }) {
            cameraFiles[idx].mappedToTakeId = take.id
        }
    }

    /// Generates the _best_takes/ folder with symlinks to circled takes
    func generateBestTakesFolder(project: Project, projectDir: URL) {
        isGeneratingLinks = true

        let scenes: [(name: String, shots: [(shotId: Int, takes: [(takeNumber: Int, rating: String, videoPath: String?)])])] =
            project.sequences.flatMap { sequence in
                sequence.scenes.map { scene in
                    let shots = scene.shots.map { shot in
                        let takes = shot.takes.map { take in
                            (takeNumber: take.takeNumber, rating: take.rating.rawValue, videoPath: take.capturedVideoPath)
                        }
                        return (shotId: shot.shotId, takes: takes)
                    }
                    return (name: scene.name, shots: shots)
                }
            }

        do {
            try ProjectDirectoryManager.generateBestTakesFolder(scenes: scenes, in: projectDir)
        } catch {
            print("Failed to generate best takes folder: \(error)")
        }

        isGeneratingLinks = false
    }

    /// Generates the full curated structure with symlinks from camera source
    func generateCuratedStructure(project: Project, projectDir: URL) {
        guard let cameraDir = cameraSourceDirectory else { return }
        isGeneratingLinks = true

        let scenes: [(name: String, shots: [(shotId: Int, takes: [(takeNumber: Int, cameraFileName: String?)])])] =
            project.sequences.flatMap { sequence in
                sequence.scenes.map { scene in
                    let shots = scene.shots.map { shot in
                        let takes = shot.takes.map { take in
                            (takeNumber: take.takeNumber, cameraFileName: take.cameraSourceFileName)
                        }
                        return (shotId: shot.shotId, takes: takes)
                    }
                    return (name: scene.name, shots: shots)
                }
            }

        do {
            try ProjectDirectoryManager.createCuratedStructure(scenes: scenes, in: projectDir, cameraSourceDir: cameraDir)
        } catch {
            print("Failed to generate curated structure: \(error)")
        }

        isGeneratingLinks = false
    }

    // MARK: - Filtering

    /// All takes from the project matching current filter
    func filteredScenes(from project: Project) -> [DCScene] {
        let allScenes = project.sequences.flatMap { $0.scenes }

        if searchQuery.isEmpty && filterRating == nil {
            return allScenes
        }

        return allScenes.compactMap { scene in
            var filteredScene = scene
            filteredScene.shots = scene.shots.compactMap { shot in
                var filteredShot = shot
                filteredShot.takes = shot.takes.filter { take in
                    var matchesRating = true
                    var matchesSearch = true

                    if let rating = filterRating {
                        matchesRating = take.rating == rating
                    }
                    if !searchQuery.isEmpty {
                        matchesSearch = take.notes.localizedCaseInsensitiveContains(searchQuery)
                            || take.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
                            || scene.name.localizedCaseInsensitiveContains(searchQuery)
                    }

                    return matchesRating && matchesSearch
                }
                return filteredShot.takes.isEmpty ? nil : filteredShot
            }
            return filteredScene.shots.isEmpty ? nil : filteredScene
        }
    }

    // MARK: - Helpers

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "--:--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
