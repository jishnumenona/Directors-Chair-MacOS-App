// DirectorsChairServices/Sources/DirectorsChairServices/Auth/Entitlements.swift
//
// Product-tiering Phase 2 (EntitlementManager scaffold): the client half of
// the "one build, three versions" design (server Docs/architecture/
// Product-Versions.html §5). The session's ProductTier derives from the auth
// JWT's `tier` claim and feeds SwiftUI via `EnvironmentValues.productTier`.
//
// FAIL CLOSED (free launch, owner decision 2026-08-12 — Product-Versions
// §5.3/§6): unknown/missing/legacy claims resolve to `.free` in
// `ProductTier(claim:)`, and the SwiftUI environment default is `.free`.
// Existing accounts were grandfathered to creator/studio server-side
// (migration 0007), so only new signups and signed-out sessions land here.
// Locked surfaces read "<Tier> — coming soon" with no purchase CTA until
// billing (DC-0011) ships.

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Product Tier

/// The three product versions — runtime states of the single build, never
/// separate binaries (Product-Versions §1). Ordered: `free < creator < studio`.
public enum ProductTier: String, Sendable, Codable, CaseIterable, Comparable {
    case free
    case creator
    case studio

    /// Rank used for gating comparisons (`requiredTier <= sessionTier`).
    private var rank: Int {
        switch self {
        case .free: return 0
        case .creator: return 1
        case .studio: return 2
        }
    }

    public static func < (lhs: ProductTier, rhs: ProductTier) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Marketing name shown in lock badges and upgrade prompts.
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .creator: return "Creator"
        case .studio: return "Studio"
        }
    }

    /// Maps the JWT `tier` claim to a product tier.
    ///
    /// FAIL CLOSED (Product-Versions §5.3, live since the free launch):
    /// a missing claim, a stale pre-migration legacy value ("standard",
    /// "pro", "tester", "owner"), and anything unknown ALL resolve to
    /// `.free`. The server mints only free/creator/studio since migration
    /// 0007; a grandfathered account holding a stale legacy token shows
    /// Free only until its next refresh.
    public init(claim: String?) {
        switch claim?.lowercased() {
        case "free": self = .free
        case "creator": self = .creator
        case "studio": self = .studio
        default: self = .free
        }
    }

    /// Derives the tier from an access token's unverified `tier` claim.
    /// A nil/undecodable token fails closed to `.free` via `init(claim:)`.
    public init(fromJWT token: String?) {
        self.init(claim: token.flatMap {
            UnverifiedJWT.stringClaim("tier", in: $0)
        })
    }
}

// MARK: - Unverified JWT payload decoding

/// Reads claims out of a JWT WITHOUT verifying its signature.
///
/// This is deliberate and safe for its one purpose: the SERVER verifies
/// signatures on every request and stays authoritative for anything that
/// spends money or touches shared data — the client-side decode feeds
/// display and UX gating only (Product-Versions §5.3: "client gating is UX,
/// not security"). Never use this for a security decision.
public enum UnverifiedJWT {

    /// Decodes the payload (middle) segment of a JWT into a JSON object.
    /// Returns nil for anything that is not a three-segment token with a
    /// base64url-encoded JSON object payload.
    public static func payload(of token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3,
              let data = base64URLDecode(String(segments[1])),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any] else {
            return nil
        }
        return payload
    }

    /// Convenience: one string claim from the payload, nil if absent or
    /// the token is undecodable.
    public static func stringClaim(_ name: String, in token: String) -> String? {
        payload(of: token)?[name] as? String
    }

    /// base64url → Data, restoring the padding JWTs strip.
    private static func base64URLDecode(_ segment: String) -> Data? {
        var base64 = segment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

// MARK: - SwiftUI environment

#if canImport(SwiftUI)
private struct ProductTierEnvironmentKey: EnvironmentKey {
    /// Fail-closed default (Product-Versions §5.3): any view hierarchy that
    /// is not explicitly wired to the session — previews, tests, package
    /// components — behaves as Free and renders its locks. Inject
    /// `.environment(\.productTier, .studio)` where a preview or test
    /// needs the unlocked rendering.
    static let defaultValue: ProductTier = .free
}

public extension EnvironmentValues {
    /// The session's product tier, injected at the app root from
    /// `AuthManager.tier`. Defaults to `.free` (fail-closed) when unset.
    var productTier: ProductTier {
        get { self[ProductTierEnvironmentKey.self] }
        set { self[ProductTierEnvironmentKey.self] = newValue }
    }
}
#endif
