//
//  ProjectDirectoryManager.swift
//  DirectorsChair-Desktop
//
//  Manages project directory structure in ~/Directors Chair/
//

import Foundation

/// Manages the Directors Chair project directory structure
/// Creates and maintains folders at ~/Directors Chair/{ProjectName}/
struct ProjectDirectoryManager {

    // MARK: - Directory Structure

    /// Root directory for all Directors Chair projects
    static var directorsChairRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Directors Chair")
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
}
