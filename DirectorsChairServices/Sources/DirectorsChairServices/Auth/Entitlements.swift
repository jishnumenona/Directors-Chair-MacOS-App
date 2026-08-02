// DirectorsChairServices/Sources/DirectorsChairServices/Auth/Entitlements.swift
//
// Product-tiering Phase 2 (EntitlementManager scaffold): the client half of
// the "one build, three versions" design (server Docs/architecture/
// Product-Versions.html §5). The session's ProductTier derives from the auth
// JWT's `tier` claim and feeds SwiftUI via `EnvironmentValues.productTier`.
//
// STRUCTURE NOW, MONETIZE LATER (Product-Versions §1, §5.3): until billing
// exists, EVERY account must behave as the top tier. That is guaranteed here
// twice over — unknown/legacy claims resolve to `.studio` in
// `ProductTier(claim:)`, and the SwiftUI environment default is `.studio` —
// so tier gating ships dark with zero user-visible change. When billing
// lands (Phase 3), flip the fail-open default to `.free` (fail closed).

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
    /// FAIL-OPEN (the structure-now rule, Product-Versions §1/§5.3): legacy
    /// values minted today ("standard", "pro", "tester", "owner"), a missing
    /// claim, and anything unknown ALL resolve to `.studio`, so every current
    /// account behaves as the top tier and no lock badge ever shows. Flip
    /// this default to `.free` when billing ships (Phase 3 — fail closed).
    public init(claim: String?) {
        switch claim?.lowercased() {
        case "free": self = .free
        case "creator": self = .creator
        case "studio": self = .studio
        default: self = .studio
        }
    }

    /// Derives the tier from an access token's unverified `tier` claim.
    /// A nil/undecodable token fails open to `.studio` via `init(claim:)`.
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
    /// Fail-open default (structure-now rule): any view hierarchy that is
    /// not explicitly wired to the session — previews, tests, package
    /// components — behaves as the top tier and shows no locks.
    static let defaultValue: ProductTier = .studio
}

public extension EnvironmentValues {
    /// The session's product tier, injected at the app root from
    /// `AuthManager.tier`. Defaults to `.studio` (fail-open) when unset.
    var productTier: ProductTier {
        get { self[ProductTierEnvironmentKey.self] }
        set { self[ProductTierEnvironmentKey.self] = newValue }
    }
}
#endif
