// DirectorsChairCore — remote repository (Gitea) client surface
//
// Extracted from the deleted GitSerializerProtocol.swift during WS2.1 dead-code removal:
// these types are live (referenced by shipped code); the rest of that file was dead.

import Foundation

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
