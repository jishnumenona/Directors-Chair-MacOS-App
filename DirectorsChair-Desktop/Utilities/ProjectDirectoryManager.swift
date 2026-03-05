//
//  ProjectDirectoryManager.swift
//  DirectorsChair-Desktop
//
//  Manages project directory structure in ~/Directors Chair/
//

import Foundation

/// Manages the Directors Chair project directory structure
/// Creates and maintains folders at ~/Directors Chair/{username}/{ProjectName}/
struct ProjectDirectoryManager {

    // MARK: - User Isolation

    /// Current username for per-user project isolation. Defaults to "local" for offline mode.
    static var currentUsername: String = "local"

    /// Set the current user for project isolation.
    /// Pass nil to reset to offline "local" namespace.
    static func setCurrentUser(_ username: String?) {
        currentUsername = username ?? "local"
    }

    // MARK: - Directory Structure

    /// Base directory shared across all users: ~/Directors Chair/
    static var baseRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Directors Chair")
    }

    /// Root directory for the current user's projects: ~/Directors Chair/{username}/
    static var directorsChairRoot: URL {
        baseRoot.appendingPathComponent(currentUsername)
    }

    /// Asset subdirectory names within each project
    enum AssetFolder: String, CaseIterable {
        case characters = "characters"
        case locations = "locations"
        case props = "props"
        case costumes = "costumes"
        case visionBoard = "vision_board"
        case posters = "posters"
        case audio = "audio"
        case exports = "exports"
        case backups = ".backups"
        case footage = "footage"

        /// Subfolders for character assets
        static var characterSubfolders: [String] {
            ["face", "body", "reference"]
        }
    }

    // MARK: - Directory Operations

    /// Creates the root Directors Chair folder if it doesn't exist
    /// - Returns: URL to the root folder
    /// - Throws: Error if creation fails
    @discardableResult
    static func ensureRootExists() throws -> URL {
        let root = directorsChairRoot

        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return root
    }

    /// Creates a project directory with all required subfolders
    /// - Parameter projectName: Name of the project (will be sanitized for filesystem)
    /// - Returns: URL to the project folder
    /// - Throws: Error if creation fails
    @discardableResult
    static func createProjectDirectory(named projectName: String) throws -> URL {
        // Ensure root exists
        try ensureRootExists()

        // Sanitize project name for filesystem
        let sanitizedName = sanitizeDirectoryName(projectName)
        let projectDir = directorsChairRoot.appendingPathComponent(sanitizedName)

        // Create project folder
        if !FileManager.default.fileExists(atPath: projectDir.path) {
            try FileManager.default.createDirectory(
                at: projectDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Create asset subfolders
        for folder in AssetFolder.allCases {
            let folderURL = projectDir.appendingPathComponent(folder.rawValue)
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(
                    at: folderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        }

        return projectDir
    }

    /// Creates character asset subfolders for a specific character
    /// - Parameters:
    ///   - characterName: Name of the character
    ///   - projectDir: URL to the project directory
    /// - Returns: URL to the character's asset folder
    /// - Throws: Error if creation fails
    @discardableResult
    static func createCharacterAssetFolder(
        named characterName: String,
        in projectDir: URL
    ) throws -> URL {
        let sanitizedName = sanitizeDirectoryName(characterName)
        let characterDir = projectDir
            .appendingPathComponent(AssetFolder.characters.rawValue)
            .appendingPathComponent(sanitizedName)

        // Create character folder and subfolders
        for subfolder in AssetFolder.characterSubfolders {
            let subfolderURL = characterDir.appendingPathComponent(subfolder)
            if !FileManager.default.fileExists(atPath: subfolderURL.path) {
                try FileManager.default.createDirectory(
                    at: subfolderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        }

        return characterDir
    }

    /// Creates location asset folder for a specific location
    /// - Parameters:
    ///   - locationName: Name of the location
    ///   - projectDir: URL to the project directory
    /// - Returns: URL to the location's asset folder
    /// - Throws: Error if creation fails
    @discardableResult
    static func createLocationAssetFolder(
        named locationName: String,
        in projectDir: URL
    ) throws -> URL {
        let sanitizedName = sanitizeDirectoryName(locationName)
        let locationDir = projectDir
            .appendingPathComponent(AssetFolder.locations.rawValue)
            .appendingPathComponent(sanitizedName)

        if !FileManager.default.fileExists(atPath: locationDir.path) {
            try FileManager.default.createDirectory(
                at: locationDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return locationDir
    }

    /// Gets the project.json file URL for a project directory
    /// - Parameter projectDir: URL to the project directory
    /// - Returns: URL to project.json
    static func projectFileURL(in projectDir: URL) -> URL {
        projectDir.appendingPathComponent("project.json")
    }

    /// Gets the project directory for a given project name
    /// - Parameter projectName: Name of the project
    /// - Returns: URL to the project directory
    static func projectDirectory(named projectName: String) -> URL {
        let sanitizedName = sanitizeDirectoryName(projectName)
        return directorsChairRoot.appendingPathComponent(sanitizedName)
    }

    /// Lists all existing project directories
    /// - Returns: Array of project directory URLs
    static func listProjects() -> [URL] {
        guard FileManager.default.fileExists(atPath: directorsChairRoot.path) else {
            return []
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directorsChairRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )

            return contents.filter { url in
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                return isDirectory.boolValue
            }
        } catch {
            return []
        }
    }

    /// Checks if a project with the given name already exists
    /// - Parameter projectName: Name of the project
    /// - Returns: true if project exists
    static func projectExists(named projectName: String) -> Bool {
        let projectDir = projectDirectory(named: projectName)
        return FileManager.default.fileExists(atPath: projectDir.path)
    }

    /// Generates a unique project name by appending a number if needed
    /// - Parameter baseName: Base name for the project
    /// - Returns: Unique project name
    static func uniqueProjectName(baseName: String) -> String {
        var name = baseName
        var counter = 1

        while projectExists(named: name) {
            counter += 1
            name = "\(baseName) \(counter)"
        }

        return name
    }

    // MARK: - Helper Methods

    /// Sanitizes a name for use as a directory name
    /// - Parameter name: Original name
    /// - Returns: Filesystem-safe name
    static func sanitizeDirectoryName(_ name: String) -> String {
        // Replace invalid characters with underscores
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")

        // Trim whitespace and dots from ends
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // Ensure non-empty
        if sanitized.isEmpty {
            sanitized = "Untitled"
        }

        return sanitized
    }

    // MARK: - Footage Directory Operations

    /// Creates a footage directory for a specific scene and shot
    /// - Parameters:
    ///   - sceneName: Name of the scene (e.g. "Scene_01_INT_OFFICE")
    ///   - shotId: Shot ID number
    ///   - projectDir: URL to the project directory
    /// - Returns: URL to the shot's footage folder
    @discardableResult
    static func createFootageDirectory(
        sceneName: String,
        shotId: Int,
        in projectDir: URL
    ) throws -> URL {
        let sanitizedScene = sanitizeDirectoryName(sceneName)
        let shotFolder = String(format: "Shot_%03d", shotId)
        let footageDir = projectDir
            .appendingPathComponent(AssetFolder.footage.rawValue)
            .appendingPathComponent(sanitizedScene)
            .appendingPathComponent(shotFolder)

        if !FileManager.default.fileExists(atPath: footageDir.path) {
            try FileManager.default.createDirectory(
                at: footageDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return footageDir
    }

    /// Returns the file path for a take video within the footage directory
    /// - Parameters:
    ///   - sceneName: Name of the scene
    ///   - shotId: Shot ID number
    ///   - takeNumber: Take number
    ///   - fileExtension: File extension (default: "mov")
    ///   - projectDir: URL to the project directory
    /// - Returns: URL to the take video file
    static func footageFilePath(
        sceneName: String,
        shotId: Int,
        takeNumber: Int,
        fileExtension: String = "mov",
        in projectDir: URL
    ) -> URL {
        let sanitizedScene = sanitizeDirectoryName(sceneName)
        let shotFolder = String(format: "Shot_%03d", shotId)
        let fileName = String(format: "Take_%03d.\(fileExtension)", takeNumber)
        return projectDir
            .appendingPathComponent(AssetFolder.footage.rawValue)
            .appendingPathComponent(sanitizedScene)
            .appendingPathComponent(shotFolder)
            .appendingPathComponent(fileName)
    }

    /// Generates a _best_takes/ folder with symlinks to all circled takes
    /// - Parameters:
    ///   - scenes: Array of (sceneName, shots) tuples
    ///   - projectDir: URL to the project directory
    static func generateBestTakesFolder(
        scenes: [(name: String, shots: [(shotId: Int, takes: [(takeNumber: Int, rating: String, videoPath: String?)])])],
        in projectDir: URL
    ) throws {
        let bestTakesDir = projectDir
            .appendingPathComponent(AssetFolder.footage.rawValue)
            .appendingPathComponent("_best_takes")

        // Clean and recreate
        if FileManager.default.fileExists(atPath: bestTakesDir.path) {
            try FileManager.default.removeItem(at: bestTakesDir)
        }
        try FileManager.default.createDirectory(at: bestTakesDir, withIntermediateDirectories: true)

        let fm = FileManager.default

        for scene in scenes {
            let sanitizedScene = sanitizeDirectoryName(scene.name)
            for shot in scene.shots {
                for take in shot.takes {
                    guard take.rating == "Circle", let videoPath = take.videoPath else { continue }

                    let sourceURL = projectDir.appendingPathComponent(videoPath)
                    guard fm.fileExists(atPath: sourceURL.path) else { continue }

                    let ext = sourceURL.pathExtension
                    let linkName = String(format: "%@_Shot_%03d_Take_%03d.%@",
                                          sanitizedScene, shot.shotId, take.takeNumber, ext)
                    let linkURL = bestTakesDir.appendingPathComponent(linkName)

                    // Create relative symlink
                    let relativePath = "../\(sanitizedScene)/\(String(format: "Shot_%03d", shot.shotId))/\(sourceURL.lastPathComponent)"
                    try fm.createSymbolicLink(atPath: linkURL.path, withDestinationPath: relativePath)
                }
            }
        }
    }

    /// Creates a curated structure with symlinks from camera source files
    /// - Parameters:
    ///   - scenes: Scene/shot/take hierarchy
    ///   - projectDir: URL to the project directory
    ///   - cameraSourceDir: URL to the camera's source directory (e.g., SD card)
    static func createCuratedStructure(
        scenes: [(name: String, shots: [(shotId: Int, takes: [(takeNumber: Int, cameraFileName: String?)])])],
        in projectDir: URL,
        cameraSourceDir: URL
    ) throws {
        let curatedDir = projectDir
            .appendingPathComponent(AssetFolder.footage.rawValue)
            .appendingPathComponent("_curated")

        // Clean and recreate
        if FileManager.default.fileExists(atPath: curatedDir.path) {
            try FileManager.default.removeItem(at: curatedDir)
        }
        try FileManager.default.createDirectory(at: curatedDir, withIntermediateDirectories: true)

        let fm = FileManager.default

        for scene in scenes {
            let sanitizedScene = sanitizeDirectoryName(scene.name)
            for shot in scene.shots {
                let shotFolder = String(format: "Shot_%03d", shot.shotId)
                let shotDir = curatedDir
                    .appendingPathComponent(sanitizedScene)
                    .appendingPathComponent(shotFolder)

                for take in shot.takes {
                    guard let cameraFile = take.cameraFileName, !cameraFile.isEmpty else { continue }

                    let sourceURL = cameraSourceDir.appendingPathComponent(cameraFile)
                    guard fm.fileExists(atPath: sourceURL.path) else { continue }

                    try fm.createDirectory(at: shotDir, withIntermediateDirectories: true)
                    let linkURL = shotDir.appendingPathComponent(cameraFile)
                    try fm.createSymbolicLink(atPath: linkURL.path, withDestinationPath: sourceURL.path)
                }
            }
        }
    }
}
