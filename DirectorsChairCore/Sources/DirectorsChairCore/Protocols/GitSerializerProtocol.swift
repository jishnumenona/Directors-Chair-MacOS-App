// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/GitSerializerProtocol.swift
//
// Protocol interfaces for Git serialization and remote repository operations (Module 7)
// Complements GitServiceProtocol defined in ExportServiceProtocol.swift

import Foundation

// MARK: - Git Serialization Protocol

/// Protocol for serializing DirectorsChair projects to Git-friendly structure
public protocol GitSerializerProtocol: Sendable {

    /// Serialize entire project to Git-friendly modular structure
    /// - Parameters:
    ///   - project: Project to serialize
    ///   - repoPath: Path to Git repository
    /// - Returns: Serialization statistics
    func serializeProject(
        _ project: Project,
        to repoPath: URL
    ) async throws -> GitSerializationStats

    /// Deserialize Git repository to DirectorsChair project
    /// - Parameter repoPath: Path to Git repository
    /// - Returns: Reconstructed project
    func deserializeProject(from repoPath: URL) async throws -> Project

    /// Update specific entity in Git structure
    /// - Parameters:
    ///   - entity: Entity to update (Character, Scene, etc.)
    ///   - repoPath: Path to Git repository
    func updateEntity<T: Codable & Identifiable>(
        _ entity: T,
        at repoPath: URL
    ) async throws
}

// MARK: - Remote Repository Protocol

/// Protocol for remote repository operations (Gitea, GitHub, etc.)
public protocol RemoteRepositoryProtocol: Sendable {

    // MARK: - Authentication

    /// Login with credentials
    /// - Parameters:
    ///   - username: Username
    ///   - password: Password
    /// - Returns: Authentication token
    func login(username: String, password: String) async throws -> String

    /// Logout
    func logout() async

    /// Get current user info
    /// - Returns: User information
    func getCurrentUser() async throws -> RemoteUser

    // MARK: - Repository Operations

    /// Create a new repository
    /// - Parameters:
    ///   - name: Repository name
    ///   - description: Repository description
    ///   - isPrivate: Whether repository is private
    /// - Returns: Repository information
    func createRepository(
        name: String,
        description: String,
        isPrivate: Bool
    ) async throws -> RemoteRepository

    /// Get repository info
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - name: Repository name
    /// - Returns: Repository information
    func getRepository(owner: String, name: String) async throws -> RemoteRepository

    /// Delete a repository
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - name: Repository name
    func deleteRepository(owner: String, name: String) async throws

    /// List repositories for current user
    /// - Returns: List of repositories
    func listRepositories() async throws -> [RemoteRepository]

    // MARK: - Collaboration

    /// Add collaborator to repository
    /// - Parameters:
    ///   - username: Collaborator username
    ///   - permission: Permission level
    ///   - owner: Repository owner
    ///   - repo: Repository name
    func addCollaborator(
        username: String,
        permission: CollaboratorPermission,
        toRepo owner: String,
        _ repo: String
    ) async throws

    /// Get repository branches
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    /// - Returns: List of branches
    func getBranches(owner: String, repo: String) async throws -> [RemoteBranch]

    /// Create a branch
    /// - Parameters:
    ///   - name: Branch name
    ///   - from: Source branch
    ///   - owner: Repository owner
    ///   - repo: Repository name
    func createBranch(
        named name: String,
        from: String,
        owner: String,
        repo: String
    ) async throws

    // MARK: - Issues & Pull Requests

    /// Create an issue
    /// - Parameters:
    ///   - title: Issue title
    ///   - body: Issue body
    ///   - labels: Issue labels
    ///   - owner: Repository owner
    ///   - repo: Repository name
    /// - Returns: Issue information
    func createIssue(
        title: String,
        body: String,
        labels: [String],
        owner: String,
        repo: String
    ) async throws -> RemoteIssue

    /// Create a pull request
    /// - Parameters:
    ///   - title: PR title
    ///   - body: PR body
    ///   - head: Source branch
    ///   - base: Target branch
    ///   - owner: Repository owner
    ///   - repo: Repository name
    /// - Returns: Pull request information
    func createPullRequest(
        title: String,
        body: String,
        head: String,
        base: String,
        owner: String,
        repo: String
    ) async throws -> RemotePullRequest

    // MARK: - Connection

    /// Test connection to remote server
    /// - Returns: True if connection successful
    func testConnection() async -> Bool

    /// Get clone URL for repository
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    ///   - useSSH: Use SSH instead of HTTPS
    /// - Returns: Clone URL
    func getCloneURL(owner: String, repo: String, useSSH: Bool) async throws -> URL
}

// MARK: - Git Serialization Types

/// Git serialization statistics
public struct GitSerializationStats: Sendable, Codable {
    public var characters: Int
    public var scenes: Int
    public var sequences: Int
    public var beats: Int
    public var locations: Int
    public var props: Int
    public var costumes: Int
    public var lighting: Int
    public var effects: Int

    public init(
        characters: Int = 0,
        scenes: Int = 0,
        sequences: Int = 0,
        beats: Int = 0,
        locations: Int = 0,
        props: Int = 0,
        costumes: Int = 0,
        lighting: Int = 0,
        effects: Int = 0
    ) {
        self.characters = characters
        self.scenes = scenes
        self.sequences = sequences
        self.beats = beats
        self.locations = locations
        self.props = props
        self.costumes = costumes
        self.lighting = lighting
        self.effects = effects
    }

    public var totalFiles: Int {
        characters + scenes + sequences + beats + locations + props + costumes + lighting + effects
    }
}

// MARK: - Remote Types

/// Remote user information
public struct RemoteUser: Sendable, Codable, Identifiable {
    public var id: Int
    public var username: String
    public var email: String
    public var fullName: String
    public var avatarURL: URL?

    public init(id: Int, username: String, email: String, fullName: String, avatarURL: URL? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.fullName = fullName
        self.avatarURL = avatarURL
    }
}

/// Remote repository information
public struct RemoteRepository: Sendable, Codable, Identifiable {
    public var id: Int
    public var name: String
    public var fullName: String
    public var description: String
    public var isPrivate: Bool
    public var cloneURL: URL
    public var sshURL: URL?
    public var defaultBranch: String
    public var owner: RemoteUser

    public init(
        id: Int,
        name: String,
        fullName: String,
        description: String,
        isPrivate: Bool,
        cloneURL: URL,
        sshURL: URL? = nil,
        defaultBranch: String = "main",
        owner: RemoteUser
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.description = description
        self.isPrivate = isPrivate
        self.cloneURL = cloneURL
        self.sshURL = sshURL
        self.defaultBranch = defaultBranch
        self.owner = owner
    }
}

/// Remote branch information
public struct RemoteBranch: Sendable, Codable {
    public var name: String
    public var commitHash: String
    public var isProtected: Bool

    public init(name: String, commitHash: String, isProtected: Bool = false) {
        self.name = name
        self.commitHash = commitHash
        self.isProtected = isProtected
    }
}

/// Collaborator permission levels
public enum CollaboratorPermission: String, Sendable, Codable {
    case read
    case write
    case admin
}

/// Remote issue
public struct RemoteIssue: Sendable, Codable, Identifiable {
    public var id: Int
    public var number: Int
    public var title: String
    public var body: String
    public var state: String
    public var labels: [String]
    public var author: RemoteUser
    public var createdAt: Date

    public init(
        id: Int,
        number: Int,
        title: String,
        body: String,
        state: String,
        labels: [String],
        author: RemoteUser,
        createdAt: Date
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.state = state
        self.labels = labels
        self.author = author
        self.createdAt = createdAt
    }
}

/// Remote pull request
public struct RemotePullRequest: Sendable, Codable, Identifiable {
    public var id: Int
    public var number: Int
    public var title: String
    public var body: String
    public var state: String
    public var headBranch: String
    public var baseBranch: String
    public var author: RemoteUser
    public var createdAt: Date
    public var isMergeable: Bool

    public init(
        id: Int,
        number: Int,
        title: String,
        body: String,
        state: String,
        headBranch: String,
        baseBranch: String,
        author: RemoteUser,
        createdAt: Date,
        isMergeable: Bool
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.state = state
        self.headBranch = headBranch
        self.baseBranch = baseBranch
        self.author = author
        self.createdAt = createdAt
        self.isMergeable = isMergeable
    }
}

// MARK: - Additional Git Types

/// Git file change status
public enum GitFileStatus: String, Sendable, Codable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case unmerged = "U"
}

/// Git file change information
public struct GitFileChange: Sendable, Codable {
    public var path: String
    public var status: GitFileStatus

    public init(path: String, status: GitFileStatus) {
        self.path = path
        self.status = status
    }
}

/// Git author information
public struct GitAuthor: Sendable, Codable {
    public var name: String
    public var email: String

    public init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}

/// Git remote information
public struct GitRemote: Sendable, Codable {
    public var name: String
    public var fetchURL: URL
    public var pushURL: URL

    public init(name: String, fetchURL: URL, pushURL: URL) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL
    }
}

/// Git branch list
public struct GitBranchList: Sendable, Codable {
    public var current: String
    public var local: [String]
    public var remote: [String]

    public init(current: String = "main", local: [String] = [], remote: [String] = []) {
        self.current = current
        self.local = local
        self.remote = remote
    }
}

/// Git pull result
public struct GitPullResult: Sendable, Codable {
    public var success: Bool
    public var message: String
    public var commitsReceived: Int
    public var conflicts: [String]

    public init(success: Bool, message: String, commitsReceived: Int = 0, conflicts: [String] = []) {
        self.success = success
        self.message = message
        self.commitsReceived = commitsReceived
        self.conflicts = conflicts
    }
}

/// Git diff information
public struct GitDiff: Sendable, Codable {
    public var files: [GitDiffFile]
    public var additions: Int
    public var deletions: Int

    public init(files: [GitDiffFile] = [], additions: Int = 0, deletions: Int = 0) {
        self.files = files
        self.additions = additions
        self.deletions = deletions
    }
}

/// Git diff file
public struct GitDiffFile: Sendable, Codable {
    public var path: String
    public var status: GitFileStatus
    public var additions: Int
    public var deletions: Int

    public init(path: String, status: GitFileStatus, additions: Int = 0, deletions: Int = 0) {
        self.path = path
        self.status = status
        self.additions = additions
        self.deletions = deletions
    }
}

// MARK: - Git Serialization Errors

/// Errors specific to Git serialization operations
public enum GitSerializationError: LocalizedError, Sendable {
    case serializationFailed(String)
    case deserializationFailed(String)
    case invalidProjectStructure(String)
    case missingManifest
    case unsupportedSchemaVersion(String)
    case assetCopyFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serializationFailed(let reason):
            return "Project serialization failed: \(reason)"
        case .deserializationFailed(let reason):
            return "Project deserialization failed: \(reason)"
        case .invalidProjectStructure(let reason):
            return "Invalid project structure: \(reason)"
        case .missingManifest:
            return "Missing .directorschair/manifest.json"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported schema version: \(version)"
        case .assetCopyFailed(let asset):
            return "Failed to copy asset: \(asset)"
        }
    }
}

/// Errors for remote repository operations
public enum RemoteRepositoryError: LocalizedError, Sendable {
    case authenticationFailed
    case repositoryNotFound(String)
    case repositoryAlreadyExists(String)
    case permissionDenied
    case networkError(String)
    case rateLimitExceeded
    case invalidCredentials
    case serverError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Remote authentication failed"
        case .repositoryNotFound(let name):
            return "Repository not found: \(name)"
        case .repositoryAlreadyExists(let name):
            return "Repository already exists: \(name)"
        case .permissionDenied:
            return "Permission denied"
        case .networkError(let message):
            return "Network error: \(message)"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .invalidCredentials:
            return "Invalid credentials"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
