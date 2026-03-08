// DirectorsChairServices/Sources/DirectorsChairServices/Git/GiteaClient.swift
//
// Gitea API Client for DirectorsChair
// Handles all communication with the Gitea server for project collaboration

import Foundation
import CryptoKit
import DirectorsChairCore

// MARK: - Gitea Client

/// Gitea API client for DirectorsChair project synchronization
/// Provides methods for user authentication, repository operations,
/// issues, pull requests, and webhooks
public actor GiteaClient: RemoteRepositoryProtocol {

    // MARK: - Properties

    private let baseURL: URL
    private let apiURL: URL
    private var token: String?
    private let verifySSL: Bool
    private let timeout: TimeInterval

    private let session: URLSession
    private let lfsSession: URLSession

    // MARK: - Initialization

    /// Initialize Gitea client
    /// - Parameters:
    ///   - baseURL: Gitea server URL (e.g., https://git.example.com)
    ///   - token: Personal access token for authentication
    ///   - verifySSL: Whether to verify SSL certificates
    ///   - timeout: Request timeout in seconds
    public init(
        baseURL: URL,
        token: String? = nil,
        verifySSL: Bool = true,
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.apiURL = baseURL.appendingPathComponent("api/v1")
        self.token = token
        self.verifySSL = verifySSL
        self.timeout = timeout

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)

        let lfsConfig = URLSessionConfiguration.default
        lfsConfig.timeoutIntervalForRequest = 300
        lfsConfig.timeoutIntervalForResource = 600
        self.lfsSession = URLSession(configuration: lfsConfig)
    }

    // MARK: - RemoteRepositoryProtocol Implementation

    /// Login with credentials
    public func login(username: String, password: String) async throws -> String {
        // Create token via basic auth
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .prefix(15)

        let tokenData: [String: Any] = [
            "name": "DirectorsChair-\(username)-\(timestamp)",
            "scopes": [
                "write:repository",
                "write:user",
                "write:issue",
                "write:organization"
            ]
        ]

        let endpoint = "users/\(username)/tokens"
        let url = apiURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Basic auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: tokenData)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteRepositoryError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw RemoteRepositoryError.invalidCredentials
        }

        guard httpResponse.statusCode == 201 else {
            throw RemoteRepositoryError.serverError(httpResponse.statusCode, "Token creation failed")
        }

        let tokenInfo = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let newToken = tokenInfo["sha1"] as? String else {
            throw RemoteRepositoryError.authenticationFailed
        }

        self.token = newToken
        return newToken
    }

    /// Logout
    public func logout() async {
        self.token = nil
    }

    /// Get current user info
    public func getCurrentUser() async throws -> RemoteUser {
        let response: [String: Any] = try await request(method: "GET", endpoint: "user")
        return parseUser(from: response)
    }

    /// Create a new repository
    public func createRepository(
        name: String,
        description: String,
        isPrivate: Bool
    ) async throws -> RemoteRepository {
        let data: [String: Any] = [
            "name": name,
            "description": description,
            "private": isPrivate,
            "auto_init": true,
            "default_branch": "main"
        ]

        let response: [String: Any] = try await request(
            method: "POST",
            endpoint: "user/repos",
            body: data
        )

        return try parseRepository(from: response)
    }

    /// Get repository info
    public func getRepository(owner: String, name: String) async throws -> RemoteRepository {
        let response: [String: Any] = try await request(
            method: "GET",
            endpoint: "repos/\(owner)/\(name)"
        )

        return try parseRepository(from: response)
    }

    /// Delete a repository
    public func deleteRepository(owner: String, name: String) async throws {
        let _: [String: Any]? = try await request(
            method: "DELETE",
            endpoint: "repos/\(owner)/\(name)"
        )
    }

    /// List repositories for current user
    public func listRepositories() async throws -> [RemoteRepository] {
        let response: [[String: Any]] = try await request(
            method: "GET",
            endpoint: "user/repos"
        )

        return response.compactMap { try? parseRepository(from: $0) }
    }

    /// Add collaborator to repository
    public func addCollaborator(
        username: String,
        permission: CollaboratorPermission,
        toRepo owner: String,
        _ repo: String
    ) async throws {
        let data: [String: Any] = [
            "permission": permission.rawValue
        ]

        let _: [String: Any]? = try await request(
            method: "PUT",
            endpoint: "repos/\(owner)/\(repo)/collaborators/\(username)",
            body: data
        )
    }

    /// Get repository branches
    public func getBranches(owner: String, repo: String) async throws -> [RemoteBranch] {
        let response: [[String: Any]] = try await request(
            method: "GET",
            endpoint: "repos/\(owner)/\(repo)/branches"
        )

        return response.map { json in
            let commit = json["commit"] as? [String: Any] ?? [:]
            return RemoteBranch(
                name: json["name"] as? String ?? "",
                commitHash: commit["id"] as? String ?? "",
                isProtected: json["protected"] as? Bool ?? false
            )
        }
    }

    /// Create a branch
    public func createBranch(
        named name: String,
        from sourceBranch: String,
        owner: String,
        repo: String
    ) async throws {
        let data: [String: Any] = [
            "new_branch_name": name,
            "old_branch_name": sourceBranch
        ]

        let _: [String: Any]? = try await request(
            method: "POST",
            endpoint: "repos/\(owner)/\(repo)/branches",
            body: data
        )
    }

    /// Create an issue
    public func createIssue(
        title: String,
        body: String,
        labels: [String],
        owner: String,
        repo: String
    ) async throws -> RemoteIssue {
        let data: [String: Any] = [
            "title": title,
            "body": body,
            "labels": labels
        ]

        let response: [String: Any] = try await request(
            method: "POST",
            endpoint: "repos/\(owner)/\(repo)/issues",
            body: data
        )

        return try parseIssue(from: response)
    }

    /// Create a pull request
    public func createPullRequest(
        title: String,
        body: String,
        head: String,
        base: String,
        owner: String,
        repo: String
    ) async throws -> RemotePullRequest {
        let data: [String: Any] = [
            "title": title,
            "body": body,
            "head": head,
            "base": base
        ]

        let response: [String: Any] = try await request(
            method: "POST",
            endpoint: "repos/\(owner)/\(repo)/pulls",
            body: data
        )

        return try parsePullRequest(from: response)
    }

    /// Test connection to remote server
    public nonisolated func testConnection() async -> Bool {
        do {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 5

            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200 || httpResponse.statusCode == 403
            }
            return false
        } catch {
            return false
        }
    }

    /// Get clone URL for repository
    public func getCloneURL(owner: String, repo: String, useSSH: Bool) async throws -> URL {
        let repoInfo = try await getRepository(owner: owner, name: repo)

        if useSSH {
            if let sshURL = repoInfo.sshURL {
                return sshURL
            }
        }
        return repoInfo.cloneURL
    }

    // MARK: - Extended API Methods

    /// List issues for a repository
    public func listIssues(
        owner: String,
        repo: String,
        state: String = "open"
    ) async throws -> [RemoteIssue] {
        let response: [[String: Any]] = try await request(
            method: "GET",
            endpoint: "repos/\(owner)/\(repo)/issues",
            queryParams: ["state": state]
        )

        return response.compactMap { try? parseIssue(from: $0) }
    }

    /// Get commit history
    public func getCommits(
        owner: String,
        repo: String,
        sha: String? = nil,
        path: String? = nil
    ) async throws -> [GitCommit] {
        var params: [String: String] = [:]
        if let sha = sha { params["sha"] = sha }
        if let path = path { params["path"] = path }

        let response: [[String: Any]] = try await request(
            method: "GET",
            endpoint: "repos/\(owner)/\(repo)/commits",
            queryParams: params
        )

        return response.map { json in
            let commit = json["commit"] as? [String: Any] ?? [:]
            let author = commit["author"] as? [String: Any] ?? [:]
            let stats = json["stats"] as? [String: Any] ?? [:]

            return GitCommit(
                hash: json["sha"] as? String ?? "",
                message: commit["message"] as? String ?? "",
                author: author["name"] as? String ?? "Unknown",
                date: parseDate(from: author["date"] as? String ?? ""),
                filesChanged: stats["total"] as? Int ?? 0
            )
        }
    }

    /// Create a webhook for real-time updates
    public func createWebhook(
        owner: String,
        repo: String,
        url: URL,
        events: [String] = ["push", "pull_request", "issues", "issue_comment"]
    ) async throws -> [String: Any] {
        let data: [String: Any] = [
            "type": "gitea",
            "config": [
                "url": url.absoluteString,
                "content_type": "json"
            ],
            "events": events,
            "active": true
        ]

        return try await request(
            method: "POST",
            endpoint: "repos/\(owner)/\(repo)/hooks",
            body: data
        )
    }

    // MARK: - Organization Methods

    /// Get organization information
    public func getOrganization(name: String) async throws -> [String: Any] {
        return try await request(method: "GET", endpoint: "orgs/\(name)")
    }

    /// Create an organization
    public func createOrganization(
        name: String,
        fullName: String,
        description: String = ""
    ) async throws -> [String: Any] {
        let data: [String: Any] = [
            "username": name,
            "full_name": fullName,
            "description": description,
            "visibility": "private"
        ]

        return try await request(method: "POST", endpoint: "orgs", body: data)
    }

    /// Create a repository under an organization
    public func createOrgRepository(
        orgName: String,
        repoName: String,
        description: String = "",
        isPrivate: Bool = true
    ) async throws -> RemoteRepository {
        let data: [String: Any] = [
            "name": repoName,
            "description": description,
            "private": isPrivate,
            "auto_init": false,
            "default_branch": "main"
        ]

        let response: [String: Any] = try await request(
            method: "POST",
            endpoint: "org/\(orgName)/repos",
            body: data
        )

        return try parseRepository(from: response)
    }

    // MARK: - Private Helper Methods

    private func request<T>(
        method: String,
        endpoint: String,
        body: [String: Any]? = nil,
        queryParams: [String: String] = [:]
    ) async throws -> T {
        var urlComponents = URLComponents(
            url: apiURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )

        if !queryParams.isEmpty {
            urlComponents?.queryItems = queryParams.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        guard let url = urlComponents?.url else {
            throw RemoteRepositoryError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = token {
            let prefix = useBearer ? "Bearer" : "token"
            request.setValue("\(prefix) \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteRepositoryError.networkError("Invalid response")
        }

        // Handle errors
        switch httpResponse.statusCode {
        case 200, 201, 204:
            break
        case 401:
            throw RemoteRepositoryError.authenticationFailed
        case 403:
            throw RemoteRepositoryError.permissionDenied
        case 404:
            throw RemoteRepositoryError.repositoryNotFound(endpoint)
        case 409:
            throw RemoteRepositoryError.repositoryAlreadyExists(endpoint)
        case 429:
            throw RemoteRepositoryError.rateLimitExceeded
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RemoteRepositoryError.serverError(httpResponse.statusCode, message)
        }

        // Return empty result for DELETE requests
        if method == "DELETE" || data.isEmpty {
            if T.self == [String: Any]?.self {
                return (nil as [String: Any]?) as! T
            }
        }

        // Parse JSON response
        let json = try JSONSerialization.jsonObject(with: data)

        if let result = json as? T {
            return result
        }

        throw RemoteRepositoryError.networkError("Unexpected response type")
    }

    private func parseUser(from json: [String: Any]) -> RemoteUser {
        let avatarURLString = json["avatar_url"] as? String ?? ""

        return RemoteUser(
            id: json["id"] as? Int ?? 0,
            username: json["login"] as? String ?? json["username"] as? String ?? "",
            email: json["email"] as? String ?? "",
            fullName: json["full_name"] as? String ?? "",
            avatarURL: URL(string: avatarURLString)
        )
    }

    private func parseRepository(from json: [String: Any]) throws -> RemoteRepository {
        guard let cloneURLString = json["clone_url"] as? String,
              let cloneURL = URL(string: cloneURLString) else {
            throw RemoteRepositoryError.networkError("Invalid clone URL")
        }

        let ownerJson = json["owner"] as? [String: Any] ?? [:]
        let owner = parseUser(from: ownerJson)

        let sshURLString = json["ssh_url"] as? String ?? ""

        return RemoteRepository(
            id: json["id"] as? Int ?? 0,
            name: json["name"] as? String ?? "",
            fullName: json["full_name"] as? String ?? "",
            description: json["description"] as? String ?? "",
            isPrivate: json["private"] as? Bool ?? true,
            cloneURL: cloneURL,
            sshURL: URL(string: sshURLString),
            defaultBranch: json["default_branch"] as? String ?? "main",
            owner: owner
        )
    }

    private func parseIssue(from json: [String: Any]) throws -> RemoteIssue {
        let userJson = json["user"] as? [String: Any] ?? [:]
        let author = parseUser(from: userJson)

        let labelsJson = json["labels"] as? [[String: Any]] ?? []
        let labels = labelsJson.compactMap { $0["name"] as? String }

        let createdAtString = json["created_at"] as? String ?? ""

        return RemoteIssue(
            id: json["id"] as? Int ?? 0,
            number: json["number"] as? Int ?? 0,
            title: json["title"] as? String ?? "",
            body: json["body"] as? String ?? "",
            state: json["state"] as? String ?? "open",
            labels: labels,
            author: author,
            createdAt: parseDate(from: createdAtString)
        )
    }

    private func parsePullRequest(from json: [String: Any]) throws -> RemotePullRequest {
        let userJson = json["user"] as? [String: Any] ?? [:]
        let author = parseUser(from: userJson)

        let createdAtString = json["created_at"] as? String ?? ""

        return RemotePullRequest(
            id: json["id"] as? Int ?? 0,
            number: json["number"] as? Int ?? 0,
            title: json["title"] as? String ?? "",
            body: json["body"] as? String ?? "",
            state: json["state"] as? String ?? "open",
            headBranch: json["head"] as? String ?? "",
            baseBranch: json["base"] as? String ?? "main",
            author: author,
            createdAt: parseDate(from: createdAtString),
            isMergeable: json["mergeable"] as? Bool ?? true
        )
    }

    private func parseDate(from string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string) ?? Date()
    }

    // MARK: - Token Management (OAuth2)

    /// Whether the current token is an OAuth2 token (use Bearer auth).
    private var useBearer = false

    /// Set an OAuth2 access token directly (instead of using login).
    public func setToken(_ newToken: String) {
        self.token = newToken
        self.useBearer = true
    }

    // MARK: - Contents API (Cloud Sync)

    /// File content entry returned by the Gitea Contents API.
    public struct FileContent: Sendable {
        public let name: String
        public let path: String
        public let sha: String
        public let size: Int
        public let type: String // "file" or "dir"
        public let content: String? // base64 for files
        public let downloadURL: String?
    }

    /// Git tree entry.
    public struct TreeEntry: Sendable {
        public let path: String
        public let mode: String
        public let type: String // "blob" or "tree"
        public let sha: String
        public let size: Int?
    }

    /// Get file contents at a path.
    public func getFileContents(
        owner: String,
        repo: String,
        path: String,
        ref: String? = nil
    ) async throws -> FileContent {
        var query: [String: String] = [:]
        if let ref = ref { query["ref"] = ref }

        let response: [String: Any] = try await request(
            method: "GET",
            endpoint: "repos/\(owner)/\(repo)/contents/\(path)",
            queryParams: query
        )

        return FileContent(
            name: response["name"] as? String ?? "",
            path: response["path"] as? String ?? path,
            sha: response["sha"] as? String ?? "",
            size: response["size"] as? Int ?? 0,
            type: response["type"] as? String ?? "file",
            content: response["content"] as? String,
            downloadURL: response["download_url"] as? String
        )
    }

    /// List directory contents.
    public func listContents(
        owner: String,
        repo: String,
        path: String = "",
        ref: String? = nil
    ) async throws -> [FileContent] {
        var query: [String: String] = [:]
        if let ref = ref { query["ref"] = ref }

        let response: [[String: Any]] = try await request(
            method: "GET",
            endpoint: "repos/\(owner)/\(repo)/contents/\(path)",
            queryParams: query
        )

        return response.map { item in
            FileContent(
                name: item["name"] as? String ?? "",
                path: item["path"] as? String ?? "",
                sha: item["sha"] as? String ?? "",
                size: item["size"] as? Int ?? 0,
                type: item["type"] as? String ?? "file",
                content: item["content"] as? String,
                downloadURL: item["download_url"] as? String
            )
        }
    }

    /// Create a file in the repository.
    public func createFile(
        owner: String,
        repo: String,
        path: String,
        content: Data,
        message: String,
        branch: String = "main"
    ) async throws {
        let body: [String: Any] = [
            "content": content.base64EncodedString(),
            "message": message,
            "branch": branch,
        ]

        let _: [String: Any] = try await request(
            method: "POST",
            endpoint: "repos/\(owner)/\(repo)/contents/\(path)",
            body: body
        )
    }

    /// Update an existing file in the repository (requires current SHA).
    public func updateFile(
        owner: String,
        repo: String,
        path: String,
        content: Data,
        sha: String,
        message: String,
        branch: String = "main"
    ) async throws {
        let body: [String: Any] = [
            "content": content.base64EncodedString(),
            "sha": sha,
            "message": message,
            "branch": branch,
        ]

        let _: [String: Any] = try await request(
            method: "PUT",
            endpoint: "repos/\(owner)/\(repo)/contents/\(path)",
            body: body
        )
    }

    /// Delete a file from the repository (requires current SHA).
    public func deleteFile(
        owner: String,
        repo: String,
        path: String,
        sha: String,
        message: String,
        branch: String = "main"
    ) async throws {
        let body: [String: Any] = [
            "sha": sha,
            "message": message,
            "branch": branch,
        ]

        let _: [String: Any]? = try await request(
            method: "DELETE",
            endpoint: "repos/\(owner)/\(repo)/contents/\(path)",
            body: body
        )
    }

    /// Get the git tree for a ref (recursive for full listing).
    public func getTree(
        owner: String,
        repo: String,
        ref: String = "main",
        recursive: Bool = true
    ) async throws -> [TreeEntry] {
        var query: [String: String] = [:]
        if recursive { query["recursive"] = "true" }

        let response: [String: Any] = try await request(
            method: "GET",
            endpoint: "repos/\(owner)/\(repo)/git/trees/\(ref)",
            queryParams: query
        )

        guard let tree = response["tree"] as? [[String: Any]] else {
            return []
        }

        return tree.map { item in
            TreeEntry(
                path: item["path"] as? String ?? "",
                mode: item["mode"] as? String ?? "",
                type: item["type"] as? String ?? "blob",
                sha: item["sha"] as? String ?? "",
                size: item["size"] as? Int
            )
        }
    }

    /// Get raw file content by path.
    public func getRawFile(
        owner: String,
        repo: String,
        path: String,
        ref: String? = nil
    ) async throws -> Data {
        var urlComponents = URLComponents(
            url: apiURL.appendingPathComponent("repos/\(owner)/\(repo)/raw/\(path)"),
            resolvingAgainstBaseURL: false
        )

        if let ref = ref {
            urlComponents?.queryItems = [URLQueryItem(name: "ref", value: ref)]
        }

        guard let url = urlComponents?.url else {
            throw RemoteRepositoryError.networkError("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        if let token = token {
            urlRequest.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw RemoteRepositoryError.networkError("Failed to fetch raw file")
        }

        return data
    }

    // MARK: - Git LFS Support

    /// Check if a file path matches LFS-tracked extensions.
    public nonisolated static func isLFSFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        let lfsExts = ["png", "jpg", "jpeg", "gif", "bmp",
                       "mp4", "mov", "avi", "mkv",
                       "mp3", "wav", "aiff", "flac",
                       "psd", "ai", "blend", "fbx"]
        return lfsExts.contains(ext)
    }

    /// Upload binary data via Git LFS batch API and return the LFS pointer string.
    ///
    /// 1. Compute SHA-256 of the data
    /// 2. POST to `/{owner}/{repo}.git/info/lfs/objects/batch` with operation "upload"
    /// 3. If an upload action is returned, PUT the binary data to the provided href
    /// 4. Return the LFS pointer string for the Contents API
    public func lfsUpload(owner: String, repo: String, data: Data) async throws -> String {
        let hash = SHA256.hash(data: data)
        let oid = hash.compactMap { String(format: "%02x", $0) }.joined()
        let size = data.count

        // 1. Batch request to negotiate upload
        let batchURL = baseURL
            .appendingPathComponent("\(owner)/\(repo).git")
            .appendingPathComponent("info/lfs/objects/batch")

        var batchRequest = URLRequest(url: batchURL)
        batchRequest.httpMethod = "POST"
        batchRequest.setValue("application/vnd.git-lfs+json", forHTTPHeaderField: "Content-Type")
        batchRequest.setValue("application/vnd.git-lfs+json", forHTTPHeaderField: "Accept")

        if let token = token {
            let prefix = useBearer ? "Bearer" : "token"
            batchRequest.setValue("\(prefix) \(token)", forHTTPHeaderField: "Authorization")
        }

        let batchBody: [String: Any] = [
            "operation": "upload",
            "transfers": ["basic"],
            "objects": [
                ["oid": oid, "size": size]
            ]
        ]
        batchRequest.httpBody = try JSONSerialization.data(withJSONObject: batchBody)

        let (batchData, batchResponse) = try await lfsSession.data(for: batchRequest)

        guard let batchHTTP = batchResponse as? HTTPURLResponse,
              (200...299).contains(batchHTTP.statusCode) else {
            let statusCode = (batchResponse as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: batchData, encoding: .utf8) ?? ""
            throw RemoteRepositoryError.serverError(statusCode, "LFS batch failed: \(body)")
        }

        let batchJSON = try JSONSerialization.jsonObject(with: batchData) as? [String: Any] ?? [:]
        let objects = batchJSON["objects"] as? [[String: Any]] ?? []

        // 2. Upload binary if server requests it
        if let obj = objects.first,
           let actions = obj["actions"] as? [String: Any],
           let uploadAction = actions["upload"] as? [String: Any],
           let hrefString = uploadAction["href"] as? String,
           let uploadURL = URL(string: hrefString) {

            var uploadRequest = URLRequest(url: uploadURL)
            uploadRequest.httpMethod = "PUT"
            uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

            // Forward any headers the server specified
            if let headers = uploadAction["header"] as? [String: String] {
                for (key, value) in headers {
                    uploadRequest.setValue(value, forHTTPHeaderField: key)
                }
            }

            // If no auth header was set by the server, add ours
            if uploadRequest.value(forHTTPHeaderField: "Authorization") == nil, let token = token {
                let prefix = useBearer ? "Bearer" : "token"
                uploadRequest.setValue("\(prefix) \(token)", forHTTPHeaderField: "Authorization")
            }

            uploadRequest.httpBody = data

            let (_, uploadResponse) = try await lfsSession.data(for: uploadRequest)
            guard let uploadHTTP = uploadResponse as? HTTPURLResponse,
                  (200...299).contains(uploadHTTP.statusCode) else {
                let code = (uploadResponse as? HTTPURLResponse)?.statusCode ?? 0
                throw RemoteRepositoryError.serverError(code, "LFS upload PUT failed")
            }
        }
        // If no upload action → object already exists on server (deduplication)

        // 3. Return LFS pointer content
        let pointer = """
            version https://git-lfs.github.com/spec/v1
            oid sha256:\(oid)
            size \(size)

            """
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        return pointer
    }
}

// MARK: - Convenience Factory

/// Create a Gitea client instance
/// - Parameters:
///   - serverURL: Gitea server URL
///   - token: Authentication token
/// - Returns: GiteaClient instance
public func createGiteaClient(
    serverURL: URL = URL(string: "https://git.directorschair.app")!,
    token: String? = nil
) -> GiteaClient {
    return GiteaClient(baseURL: serverURL, token: token)
}
