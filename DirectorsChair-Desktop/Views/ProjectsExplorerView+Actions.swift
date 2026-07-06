//
// ProjectsExplorerView+Actions.swift
//
// Extracted from ProjectsExplorerView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

extension ProjectsExplorerView {

    // MARK: - Actions

    /// Ensures ProjectDirectoryManager.currentUsername matches authManager,
    /// then triggers project discovery.
    func syncUsernameAndDiscover() {
        let expected = authManager.currentUser?.username ?? "local"
        if ProjectDirectoryManager.currentUsername != expected {
            NSLog("[ProjectsExplorer] sync: correcting username %@ -> %@", ProjectDirectoryManager.currentUsername, expected)
            ProjectDirectoryManager.setCurrentUser(authManager.currentUser?.username)
        }
        discoverProjects()
    }

    func discoverProjects() {
        isLoading = true

        let username = ProjectDirectoryManager.currentUsername
        let root = ProjectDirectoryManager.directorsChairRoot
        NSLog("[ProjectsExplorer] discoverProjects — username=%@, root=%@, exists=%d", username, root.path, FileManager.default.fileExists(atPath: root.path) ? 1 : 0)

        // Run discovery on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let projectDirs = ProjectDirectoryManager.listProjects()
            NSLog("[ProjectsExplorer] found %d project dirs", projectDirs.count)

            let discoveredProjects: [ProjectInfo] = projectDirs.compactMap { dir in
                let projectFile = ProjectDirectoryManager.projectFileURL(in: dir)

                // Skip if no project.json
                guard FileManager.default.fileExists(atPath: projectFile.path) else {
                    return nil
                }

                // Check for .example marker
                let markerFile = dir.appendingPathComponent(".example")
                let isExample = FileManager.default.fileExists(atPath: markerFile.path)

                // Get file attributes
                let attrs = try? FileManager.default.attributesOfItem(atPath: projectFile.path)
                let modified = attrs?[.modificationDate] as? Date

                // Quick parse project.json for metadata
                var projectName = dir.lastPathComponent
                var sceneCount = 0
                var characterCount = 0
                var shotCount = 0
                var iconPath: URL? = nil
                var genre = ""
                var status = ""
                var tagline = ""
                var projectType = ""
                var posterPath: URL? = nil

                if let data = try? Data(contentsOf: projectFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    if let name = json["name"] as? String, !name.isEmpty {
                        projectName = name
                    }

                    // Genre
                    if let g = json["genre"] as? String, !g.isEmpty {
                        genre = g
                    }

                    // Status
                    if let s = json["status"] as? String, !s.isEmpty {
                        status = s
                    }

                    // Tagline
                    if let t = json["overview_tagline"] as? String, !t.isEmpty {
                        tagline = t
                    }

                    // Project type
                    if let pt = json["project_type"] as? String, !pt.isEmpty {
                        projectType = pt
                    }

                    // Poster path — first entry from overview_poster_paths
                    if let paths = json["overview_poster_paths"] as? [String], let first = paths.first, !first.isEmpty {
                        let possiblePoster = dir.appendingPathComponent(first)
                        if FileManager.default.fileExists(atPath: possiblePoster.path) {
                            posterPath = possiblePoster
                        }
                    }

                    // Count scenes and shots from sequences
                    if let sequences = json["sequences"] as? [[String: Any]] {
                        for seq in sequences {
                            if let scenes = seq["scenes"] as? [[String: Any]] {
                                sceneCount += scenes.count
                                for scene in scenes {
                                    if let shots = scene["shots"] as? [[String: Any]] {
                                        shotCount += shots.count
                                    }
                                }
                            }
                        }
                    }

                    // Count characters
                    if let characters = json["characters"] as? [[String: Any]] {
                        characterCount = characters.count
                    }

                    // Check for project icon (JSON uses snake_case)
                    if let iconRelativePath = json["project_icon"] as? String, !iconRelativePath.isEmpty {
                        let possibleIconPath = dir.appendingPathComponent(iconRelativePath)
                        if FileManager.default.fileExists(atPath: possibleIconPath.path) {
                            iconPath = possibleIconPath
                        }
                    }
                }

                return ProjectInfo(
                    id: UUID(),
                    name: projectName,
                    path: dir,
                    lastModified: modified,
                    iconPath: iconPath,
                    sceneCount: sceneCount,
                    characterCount: characterCount,
                    genre: genre,
                    status: status,
                    tagline: tagline,
                    projectType: projectType,
                    posterPath: posterPath,
                    shotCount: shotCount,
                    isExample: isExample
                )
            }

            // Sort by last modified (most recent first)
            let sortedProjects = discoveredProjects.sorted { p1, p2 in
                guard let d1 = p1.lastModified else { return false }
                guard let d2 = p2.lastModified else { return true }
                return d1 > d2
            }

            DispatchQueue.main.async {
                self.projects = sortedProjects
                self.isLoading = false
            }
        }
    }

    /// Move the project's folder to the Trash (recoverable) and refresh the
    /// list. If the deleted project is currently open, close it first so the
    /// app isn't pointed at a trashed directory.
    func deleteProject(_ project: ProjectInfo) {
        if projectViewModel.projectPath?.deletingLastPathComponent() == project.path {
            projectViewModel.projectPath = nil
            projectViewModel.hasProject = false
            projectViewModel.project = Project.empty()
        }
        do {
            try FileManager.default.trashItem(at: project.path, resultingItemURL: nil)
            discoverProjects()
        } catch {
            ErrorPresenter.shared.present(error, context: "Deleting project")
        }
    }

    func openProject(_ project: ProjectInfo) {
        let projectFile = ProjectDirectoryManager.projectFileURL(in: project.path)

        Task {
            do {
                try await projectViewModel.load(from: projectFile)
                // Navigate to Overview after opening
                coordinator.navigateTo(.overview)
            } catch {
                debugLog("Failed to open project: \(error)")
            }
        }
    }

    func createNewProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        projectViewModel.createNew(named: name)
        newProjectName = ""
        showingNewProjectSheet = false

        // Navigate to Overview after creating
        coordinator.navigateTo(.overview)
    }

    // MARK: - Example Download

    func downloadExample(_ example: ExampleProjectDefinition) {
        exampleDownloadStates[example.id] = .downloading

        Task {
            do {
                _ = try await ExampleProjectManager.shared.downloadAndInstall(example)
                exampleDownloadStates[example.id] = .downloaded
                // Refresh project list to show the new example
                discoverProjects()
            } catch {
                exampleDownloadStates[example.id] = .failed(error.localizedDescription)
                exampleErrorMessage = error.localizedDescription
                showingExampleError = true
            }
        }
    }

    // MARK: - Screenplay Import

    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importScreenplay(from: url)
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        }
    }

    func importScreenplay(from url: URL) {
        isImporting = true
        importProgress.progress = 0
        importProgress.stepLabel = "Preparing..."
        importProgress.logMessages = []

        Task {
            do {
                // Derive project name from filename, stripping common suffixes iteratively
                var baseName = url.deletingPathExtension().lastPathComponent
                let suffixPatterns = [" - Screenplay", " - screenplay", " Screenplay", " screenplay", " - Script", " - script", " Script", " script", " - Draft", " - draft", " Draft", " draft", " - Final", " - final", " Final", " final", " - Latest", " - latest", " Latest", " latest"]
                var didStrip = true
                while didStrip {
                    didStrip = false
                    for suffix in suffixPatterns {
                        if baseName.hasSuffix(suffix) {
                            baseName = String(baseName.dropLast(suffix.count))
                            didStrip = true
                            break
                        }
                    }
                }
                baseName = baseName.trimmingCharacters(in: .whitespaces)
                let uniqueName = ProjectDirectoryManager.uniqueProjectName(baseName: baseName)

                // Parse the screenplay PDF using AI
                let importResult = try await ScreenplayImporter.importFromPDF(url: url, projectName: uniqueName, progress: importProgress)

                // Create project directory
                let projectDir = try ProjectDirectoryManager.createProjectDirectory(named: uniqueName)
                let projectFileURL = ProjectDirectoryManager.projectFileURL(in: projectDir)

                // Update project with basePath
                var project = importResult.project
                project.basePath = projectDir.path

                // Save project.json
                let persistence = ProjectPersistence()
                try await persistence.save(project, to: projectFileURL)

                isImporting = false
                importStats = importResult.stats
                showingImportSuccess = true

                // Open the imported project
                try await projectViewModel.load(from: projectFileURL)
                coordinator.navigateTo(.overview)
            } catch {
                isImporting = false
                importError = error.localizedDescription
                showingImportError = true
            }
        }
    }
}
