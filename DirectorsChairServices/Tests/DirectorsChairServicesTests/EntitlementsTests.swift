// DirectorsChairServices/Tests/DirectorsChairServicesTests/EntitlementsTests.swift
//
// The ProductTier lattice, the claim mapping with its fail-closed rule
// (free launch, owner decision 2026-08-12), the unverified JWT payload
// decode, and the SwiftUI environment default. The contract is "unknown
// resolves to Free" (Product-Versions §5.3) — several tests here pin
// exactly that.

import XCTest
import SwiftUI
@testable import DirectorsChairServices

final class EntitlementsTests: XCTestCase {

    // MARK: - Ordering

    func testTierOrderingFreeCreatorStudio() {
        XCTAssertLessThan(ProductTier.free, ProductTier.creator)
        XCTAssertLessThan(ProductTier.creator, ProductTier.studio)
        XCTAssertLessThan(ProductTier.free, ProductTier.studio)
        XCTAssertGreaterThan(ProductTier.studio, ProductTier.free)
        // Gating predicate shape: requiredTier <= sessionTier
        XCTAssertTrue(ProductTier.creator <= ProductTier.studio)
        XCTAssertTrue(ProductTier.creator <= ProductTier.creator)
        XCTAssertFalse(ProductTier.creator <= ProductTier.free)
    }

    // MARK: - Claim mapping

    func testExactClaimsMapToTheirTiers() {
        XCTAssertEqual(ProductTier(claim: "free"), .free)
        XCTAssertEqual(ProductTier(claim: "creator"), .creator)
        XCTAssertEqual(ProductTier(claim: "studio"), .studio)
        XCTAssertEqual(ProductTier(claim: "Creator"), .creator,
                       "claim matching is case-insensitive")
    }

    func testLegacyAndUnknownClaimsFailClosedToFree() {
        // Fail closed (Product-Versions §5.3, live since the free launch):
        // stale pre-migration legacy values, nil, and garbage all resolve
        // to Free. The server mints only free/creator/studio since
        // migration 0007, so a legacy claim only means a stale cached
        // token — Free until the next refresh.
        for legacy in ["standard", "tester", "owner", "pro"] {
            XCTAssertEqual(ProductTier(claim: legacy), .free, legacy)
        }
        XCTAssertEqual(ProductTier(claim: nil), .free)
        XCTAssertEqual(ProductTier(claim: ""), .free)
        XCTAssertEqual(ProductTier(claim: "enterprise-mega"), .free)
    }

    func testDisplayNames() {
        XCTAssertEqual(ProductTier.free.displayName, "Free")
        XCTAssertEqual(ProductTier.creator.displayName, "Creator")
        XCTAssertEqual(ProductTier.studio.displayName, "Studio")
    }

    // MARK: - Unverified JWT decode

    /// Builds an unsigned fixture JWT: base64url(header).base64url(payload).sig
    private func fixtureJWT(payload: [String: Any]) throws -> String {
        func base64url(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = try JSONSerialization.data(
            withJSONObject: ["alg": "RS256", "typ": "JWT"])
        let body = try JSONSerialization.data(withJSONObject: payload)
        return "\(base64url(header)).\(base64url(body)).signature-not-checked"
    }

    func testJWTPayloadDecodeReadsTierClaim() throws {
        let token = try fixtureJWT(payload: [
            "sub": "42", "tier": "creator", "exp": 4_000_000_000,
        ])
        XCTAssertEqual(UnverifiedJWT.stringClaim("tier", in: token), "creator")
        XCTAssertEqual(UnverifiedJWT.stringClaim("sub", in: token), "42")
        XCTAssertNil(UnverifiedJWT.stringClaim("missing", in: token))
        XCTAssertEqual(ProductTier(fromJWT: token), .creator)
    }

    func testJWTDecodeHandlesBase64URLAlphabetAndPadding() throws {
        // A claim value chosen so the base64url payload needs padding
        // restored and exercises the -/_ alphabet.
        let token = try fixtureJWT(payload: [
            "tier": "free", "name": "Ana>Işık?~", "n": 7,
        ])
        XCTAssertEqual(ProductTier(fromJWT: token), .free)
    }

    func testMalformedTokensFailClosedToFree() throws {
        // Not a JWT at all, wrong segment count, non-base64 payload,
        // non-JSON payload, nil — every failure mode must resolve to Free
        // (a token we cannot read earns nothing).
        XCTAssertEqual(ProductTier(fromJWT: nil), .free)
        XCTAssertEqual(ProductTier(fromJWT: "cached-token"), .free)
        XCTAssertEqual(ProductTier(fromJWT: "a.b"), .free)
        XCTAssertEqual(ProductTier(fromJWT: "a.!!!not-base64!!!.c"), .free)
        let notJSON = Data("plain text".utf8).base64EncodedString()
        XCTAssertEqual(ProductTier(fromJWT: "a.\(notJSON).c"), .free)
        XCTAssertNil(UnverifiedJWT.payload(of: "no-dots-here"))
    }

    func testTokenWithoutTierClaimFailsClosedToFree() throws {
        let token = try fixtureJWT(payload: ["sub": "42"])
        XCTAssertEqual(ProductTier(fromJWT: token), .free)
    }

    // MARK: - SwiftUI environment

    func testEnvironmentDefaultIsFreeFailClosed() {
        // Any hierarchy not wired to the session (previews, tests, package
        // components) behaves as Free and renders its locks — a gate can
        // never fail open by accident.
        XCTAssertEqual(EnvironmentValues().productTier, .free)
    }
}
