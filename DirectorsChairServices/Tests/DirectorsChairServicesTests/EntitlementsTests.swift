// DirectorsChairServices/Tests/DirectorsChairServicesTests/EntitlementsTests.swift
//
// Product-tiering Phase 2: the ProductTier lattice, the claim mapping with
// its fail-open legacy rule (structure now, monetize later), the unverified
// JWT payload decode, and the SwiftUI environment default. The scaffold's
// contract is "zero user-visible change until billing" — several tests here
// pin exactly that.

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

    func testLegacyAndUnknownClaimsFailOpenToStudio() {
        // The structure-now rule (Product-Versions §1): every claim the auth
        // service mints today, plus nil and garbage, resolves to the top
        // tier so no account loses anything before billing exists. When
        // billing ships this default flips to .free (fail closed).
        for legacy in ["standard", "tester", "owner", "pro"] {
            XCTAssertEqual(ProductTier(claim: legacy), .studio, legacy)
        }
        XCTAssertEqual(ProductTier(claim: nil), .studio)
        XCTAssertEqual(ProductTier(claim: ""), .studio)
        XCTAssertEqual(ProductTier(claim: "enterprise-mega"), .studio)
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

    func testMalformedTokensFailOpenToStudio() throws {
        // Not a JWT at all, wrong segment count, non-base64 payload,
        // non-JSON payload, nil — every failure mode must resolve to the
        // top tier today (never lock a paying-nothing-yet account out).
        XCTAssertEqual(ProductTier(fromJWT: nil), .studio)
        XCTAssertEqual(ProductTier(fromJWT: "cached-token"), .studio)
        XCTAssertEqual(ProductTier(fromJWT: "a.b"), .studio)
        XCTAssertEqual(ProductTier(fromJWT: "a.!!!not-base64!!!.c"), .studio)
        let notJSON = Data("plain text".utf8).base64EncodedString()
        XCTAssertEqual(ProductTier(fromJWT: "a.\(notJSON).c"), .studio)
        XCTAssertNil(UnverifiedJWT.payload(of: "no-dots-here"))
    }

    func testTokenWithoutTierClaimFailsOpenToStudio() throws {
        let token = try fixtureJWT(payload: ["sub": "42"])
        XCTAssertEqual(ProductTier(fromJWT: token), .studio)
    }

    // MARK: - SwiftUI environment

    func testEnvironmentDefaultIsStudioFailOpen() {
        // Any hierarchy not wired to the session (previews, tests, package
        // components) must behave as the top tier — no lock ever renders
        // by accident.
        XCTAssertEqual(EnvironmentValues().productTier, .studio)
    }
}
