// DirectorsChairServices/Sources/DirectorsChairServices/ServiceEnvironment.swift
//
// Single source of truth for service endpoints (WS3.5). Base URLs live here
// instead of scattered string literals, and the built-in URLs are parsed once
// through a guarded closure so no call site needs a force-unwrap (`URL(string:)!`).

import Foundation

public enum ServiceEnvironment {
    /// Production Gitea / cloud-sync server.
    public static let giteaBaseURLString = "https://git.directorschair.app"
    /// Production AI proxy.
    public static let aiProxyURLString = "https://directorschair.app/ai"
    /// First-party sync API (platform-service, server spec §19.8 / Webapp §4.2).
    public static let syncBaseURLString = "https://directorschair.app"

    /// Non-optional URLs for the built-in endpoints. The force-unwrap risk is
    /// confined to this one audited spot: these are compile-time constants that
    /// are guaranteed to parse, and a build/test would trip the precondition
    /// immediately if a literal above were ever malformed.
    public static let giteaBaseURL = requireURL(giteaBaseURLString)
    public static let aiProxyURL = requireURL(aiProxyURLString)
    public static let syncBaseURL = requireURL(syncBaseURLString)

    /// Parse a trusted, non-user-supplied URL string. Use ONLY for built-in
    /// constants — never for user or network input (use `URL(string:)` + guard
    /// for those).
    static func requireURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("ServiceEnvironment: built-in URL failed to parse: \(string)")
        }
        return url
    }
}
