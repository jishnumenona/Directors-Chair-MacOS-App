//
//  ExampleProjectManager.swift
//  DirectorsChair-Desktop
//
//  Manages downloading and installing example projects from the server.
//

import Foundation
import DirectorsChairCore

// MARK: - Example Project Definition

/// Metadata for an example project available for download
struct ExampleProjectDefinition: Identifiable {
    let id: String          // slug, e.g., "the-last-frame"
    let name: String        // display name, e.g., "The Last Frame"
    let projectType: String // e.g., "Short Film", "Music Video"
    let genre: String       // e.g., "Drama/Thriller"
    let tagline: String     // one-line description
    let sceneCount: Int
    let characterCount: Int
    let shotCount: Int
    let fileSizeKB: Int     // approximate download size
    let iconName: String    // SF Symbol for poster fallback

    var downloadURL: URL {
        URL(string: "https://directorschair.app/static/downloads/examples/\(id).json")!
    }
}

// MARK: - Example Project Error

enum ExampleProjectError: LocalizedError {
    case downloadFailed(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .installFailed(let reason):
            return "Installation failed: \(reason)"
        }
    }
}

// MARK: - Example Project Manager

/// Singleton managing example project downloads and installation
final class ExampleProjectManager {
    static let shared = ExampleProjectManager()

    private init() {}

    /// All available example projects
    let examples: [ExampleProjectDefinition] = [
        ExampleProjectDefinition(
            id: "the-last-frame",
            name: "The Last Frame",
            projectType: "Short Film",
            genre: "Drama/Thriller",
            tagline: "A vintage camera that photographs the future",
            sceneCount: 12,
            characterCount: 5,
            shotCount: 45,
            fileSizeKB: 119,
            iconName: "camera.aperture"
        ),
        ExampleProjectDefinition(
            id: "neon-pulse",
            name: "Neon Pulse",
            projectType: "Music Video",
            genre: "Electronic/Sci-Fi",
            tagline: "A neon-drenched musical journey through the city",
            sceneCount: 8,
            characterCount: 3,
            shotCount: 35,
            fileSizeKB: 87,
            iconName: "music.note.tv"
        ),
        ExampleProjectDefinition(
            id: "brewed-awakening",
            name: "Brewed Awakening",
            projectType: "Commercial",
            genre: "Lifestyle",
            tagline: "The perfect cup of coffee, told cinematically",
            sceneCount: 5,
            characterCount: 2,
            shotCount: 20,
            fileSizeKB: 44,
            iconName: "cup.and.saucer"
        ),
        ExampleProjectDefinition(
            id: "behind-the-build",
            name: "Behind the Build",
            projectType: "YouTube",
            genre: "Documentary",
            tagline: "From blueprint to reality, one frame at a time",
            sceneCount: 6,
            characterCount: 3,
            shotCount: 28,
            fileSizeKB: 59,
            iconName: "hammer"
        ),
        ExampleProjectDefinition(
            id: "echoes-of-tomorrow",
            name: "Echoes of Tomorrow",
            projectType: "Feature Film",
            genre: "Sci-Fi/Drama",
            tagline: "In a world where memories can be shared",
            sceneCount: 24,
            characterCount: 8,
            shotCount: 90,
            fileSizeKB: 198,
            iconName: "sparkles.tv"
        ),
    ]

    // MARK: - Installation Check

    /// Checks whether an example project is already installed
    func isInstalled(_ example: ExampleProjectDefinition) -> Bool {
        let projectDir = ProjectDirectoryManager.projectDirectory(named: example.name)
        let markerFile = projectDir.appendingPathComponent(".example")
        let projectFile = ProjectDirectoryManager.projectFileURL(in: projectDir)
        return FileManager.default.fileExists(atPath: markerFile.path)
            && FileManager.default.fileExists(atPath: projectFile.path)
    }

    // MARK: - Download & Install

    /// Downloads an example project JSON and installs it locally
    /// - Returns: URL to the installed project directory
    func downloadAndInstall(_ example: ExampleProjectDefinition) async throws -> URL {
        // 1. Download JSON from server
        let (data, response) = try await URLSession.shared.data(from: example.downloadURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExampleProjectError.downloadFailed(
                "Server returned status \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            )
        }

        // 2. Validate it decodes as a Project
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let project: Project
        do {
            project = try decoder.decode(Project.self, from: data)
        } catch {
            throw ExampleProjectError.downloadFailed("Invalid project data: \(error.localizedDescription)")
        }

        // 3. Create project directory
        let projectDir: URL
        do {
            projectDir = try ProjectDirectoryManager.createProjectDirectory(named: example.name)
        } catch {
            throw ExampleProjectError.installFailed("Could not create directory: \(error.localizedDescription)")
        }

        // 4. Update basePath and write project.json
        do {
            var updatedProject = project
            updatedProject.basePath = projectDir.path

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(updatedProject)

            let projectFile = ProjectDirectoryManager.projectFileURL(in: projectDir)
            try encodedData.write(to: projectFile, options: .atomic)
        } catch {
            throw ExampleProjectError.installFailed("Could not save project: \(error.localizedDescription)")
        }

        // 5. Drop .example marker file
        let markerFile = projectDir.appendingPathComponent(".example")
        FileManager.default.createFile(atPath: markerFile.path, contents: nil)

        return projectDir
    }

    // MARK: - Uninstall

    /// Removes an installed example project
    func uninstall(_ example: ExampleProjectDefinition) throws {
        let projectDir = ProjectDirectoryManager.projectDirectory(named: example.name)
        if FileManager.default.fileExists(atPath: projectDir.path) {
            try FileManager.default.removeItem(at: projectDir)
        }
    }
}
