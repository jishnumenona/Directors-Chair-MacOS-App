// SyncAPIClient.swift
//
// Wire client for the first-party sync API (platform-service /api/v1, server
// spec §19.8 / Webapp architecture §4.2). Bearer-authenticated with the same
// tokenProvider/tokenRefresher + retry-once-on-401 convention as
// AIServiceClient; transport is fakeable via URLProtocol injection like
// GiteaClient. Blob bytes go DIRECT to storage via presigned URLs — never
// through the API with an auth header attached.

import Foundation

// MARK: - Wire DTOs (snake_case keys per the platform contract)

public struct SyncProject: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let headRevision: Int
    public let bytesTotal: Int
    public let archivedAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case headRevision = "head_revision"
        case bytesTotal = "bytes_total"
        case archivedAt = "archived_at"
        case updatedAt = "updated_at"
    }
}

public struct SyncManifestAsset: Codable, Sendable, Equatable {
    public let path: String
    public let sha256: String
    public let size: Int

    public init(path: String, sha256: String, size: Int) {
        self.path = path
        self.sha256 = sha256
        self.size = size
    }
}

public struct SyncBlobRef: Codable, Sendable, Equatable {
    public let sha256: String
    public let size: Int

    public init(sha256: String, size: Int) {
        self.sha256 = sha256
        self.size = size
    }
}

public struct SyncManifest: Codable, Sendable, Equatable {
    public let schema: Int
    public let projectBlob: SyncBlobRef
    public let assets: [SyncManifestAsset]
    public let deleted: [String]

    public init(schema: Int = 1, projectBlob: SyncBlobRef,
                assets: [SyncManifestAsset], deleted: [String]) {
        self.schema = schema
        self.projectBlob = projectBlob
        self.assets = assets
        self.deleted = deleted
    }

    enum CodingKeys: String, CodingKey {
        case schema, assets, deleted
        case projectBlob = "project_blob"
    }
}

public struct SyncRevision: Codable, Sendable {
    public let revision: Int
    public let parentRevision: Int
    public let mergedFrom: Int?
    public let manifest: SyncManifest
    public let deviceName: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case revision, manifest
        case parentRevision = "parent_revision"
        case mergedFrom = "merged_from"
        case deviceName = "device_name"
        case createdAt = "created_at"
    }
}

public struct SyncRevisionFeed: Codable, Sendable {
    public let revisions: [SyncRevision]
    public let cursor: Int
}

public struct SyncCommitResult: Codable, Sendable {
    public let revision: Int
    public let cursor: Int
}

struct PresignedUpload: Codable {
    let uploadURL: String
    let headers: [String: String]

    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case headers
    }
}

struct PresignedDownload: Codable {
    let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case downloadURL = "download_url"
    }
}

// MARK: - Errors

public enum SyncAPIError: Error, Sendable, Equatable {
    case notAuthenticated
    /// Someone else moved the head — pull, merge, retry (Webapp §5.4).
    case staleBase(headRevision: Int)
    /// Not found OR not yours (the server never distinguishes — IDOR posture).
    case notFound
    case payloadTooLarge
    case uncommittedBlobs([String])
    case serviceUnavailable
    case server(status: Int)
    case transport(String)
    case malformedResponse
}

// MARK: - Client

public actor SyncAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private var tokenProvider: (() -> String?)?
    private var tokenRefresher: (() async -> String?)?
    private let deviceName: String

    public init(baseURL: URL = ServiceEnvironment.syncBaseURL,
                deviceName: String = Host.current().localizedName ?? "Mac",
                protocolClasses: [AnyClass]? = nil) {
        self.baseURL = baseURL
        self.deviceName = deviceName
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        self.session = URLSession(configuration: configuration)
    }

    public func setTokenProvider(_ provider: @escaping () -> String?,
                                 refresher: @escaping () async -> String?) {
        self.tokenProvider = provider
        self.tokenRefresher = refresher
    }

    // MARK: Projects

    public func listProjects() async throws -> [SyncProject] {
        try await request("GET", "api/v1/projects")
    }

    public func createProject(id: String, name: String) async throws -> SyncProject {
        try await request("POST", "api/v1/projects", body: ["id": id, "name": name])
    }

    public func deleteProject(id: String) async throws {
        _ = try await requestRaw("DELETE", "api/v1/projects/\(id)")
    }

    // MARK: Revisions

    public func revisions(projectID: String, since: Int) async throws -> SyncRevisionFeed {
        try await request("GET", "api/v1/projects/\(projectID)/revisions?since=\(since)")
    }

    public func revision(projectID: String, number: Int) async throws -> SyncRevision {
        try await request("GET", "api/v1/projects/\(projectID)/revisions/\(number)")
    }

    public func commit(projectID: String, baseRevision: Int, manifest: SyncManifest,
                       mergedFrom: Int? = nil) async throws -> SyncCommitResult {
        var body: [String: Any] = [
            "base_revision": baseRevision,
            "manifest": try manifest.asJSONObject(),
            "device_name": deviceName,
        ]
        if let mergedFrom { body["merged_from"] = mergedFrom }
        return try await request("POST", "api/v1/projects/\(projectID)/revisions", body: body)
    }

    // MARK: Blobs

    public func missingBlobs(projectID: String, refs: [SyncBlobRef]) async throws -> [String] {
        struct Missing: Codable { let missing: [String] }
        let payload = refs.map { ["sha256": $0.sha256, "size": $0.size] }
        let result: Missing = try await request(
            "POST", "api/v1/projects/\(projectID)/blobs/lookup", bodyArray: payload)
        return result.missing
    }

    /// Stage + presigned PUT + commit: the full upload of one blob.
    public func uploadBlob(projectID: String, sha256: String, data: Data,
                           contentType: String = "application/octet-stream") async throws {
        let staged: PresignedUpload = try await request(
            "POST", "api/v1/projects/\(projectID)/blobs",
            body: ["sha256": sha256, "size": data.count, "content_type": contentType])
        guard let url = URL(string: staged.uploadURL) else {
            throw SyncAPIError.malformedResponse
        }
        var put = URLRequest(url: url)
        put.httpMethod = "PUT"
        for (key, value) in staged.headers {
            put.setValue(value, forHTTPHeaderField: key)
        }
        let (_, response) = try await session.upload(for: put, from: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncAPIError.transport("presigned upload failed")
        }
        struct Done: Codable { let state: String }
        let done: Done = try await request(
            "POST", "api/v1/projects/\(projectID)/blobs/\(sha256)/complete")
        guard done.state == "committed" else { throw SyncAPIError.malformedResponse }
    }

    public func downloadBlob(projectID: String, sha256: String) async throws -> Data {
        let presigned: PresignedDownload = try await request(
            "GET", "api/v1/projects/\(projectID)/blobs/\(sha256)")
        guard let url = URL(string: presigned.downloadURL) else {
            throw SyncAPIError.malformedResponse
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SyncAPIError.transport("presigned download failed")
        }
        // Verify what came back is what the manifest promised (Webapp §5.2).
        guard SyncHashing.sha256Hex(data) == sha256 else {
            throw SyncAPIError.transport("blob hash mismatch on download")
        }
        return data
    }

    // MARK: Core request machinery

    private func request<T: Decodable>(_ method: String, _ path: String,
                                       body: [String: Any]? = nil,
                                       bodyArray: [[String: Any]]? = nil) async throws -> T {
        let data = try await requestRaw(method, path, body: body, bodyArray: bodyArray)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SyncAPIError.malformedResponse
        }
    }

    private func requestRaw(_ method: String, _ path: String,
                            body: [String: Any]? = nil,
                            bodyArray: [[String: Any]]? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw SyncAPIError.transport("bad path")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if let bodyArray {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyArray)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        guard let token = tokenProvider?() else { throw SyncAPIError.notAuthenticated }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var (data, response) = try await perform(request)
        if (response as? HTTPURLResponse)?.statusCode == 401, let refresher = tokenRefresher {
            if let fresh = await refresher() {
                request.setValue("Bearer \(fresh)", forHTTPHeaderField: "Authorization")
                (data, response) = try await perform(request)
            }
        }
        guard let http = response as? HTTPURLResponse else {
            throw SyncAPIError.transport("no HTTP response")
        }
        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw SyncAPIError.notAuthenticated
        case 404:
            throw SyncAPIError.notFound
        case 409:
            if let detail = Self.detailObject(data),
               let head = detail["head_revision"] as? Int {
                throw SyncAPIError.staleBase(headRevision: head)
            }
            throw SyncAPIError.server(status: 409)
        case 413:
            throw SyncAPIError.payloadTooLarge
        case 422:
            if let detail = Self.detailObject(data),
               let missing = detail["missing"] as? [String] {
                throw SyncAPIError.uncommittedBlobs(missing)
            }
            throw SyncAPIError.server(status: 422)
        case 503:
            throw SyncAPIError.serviceUnavailable
        default:
            throw SyncAPIError.server(status: http.statusCode)
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw SyncAPIError.transport(error.localizedDescription)
        }
    }

    private static func detailObject(_ data: Data) -> [String: Any]? {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["detail"] as? [String: Any]
    }
}

private extension SyncManifest {
    func asJSONObject() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SyncAPIError.malformedResponse
        }
        return object
    }
}
