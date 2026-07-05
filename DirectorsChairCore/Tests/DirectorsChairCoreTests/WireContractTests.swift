// WireContractTests.swift
//
// WS2.8 — pins the on-disk wire contract for the versioned schema. Guards
// against silent format drift (the contract a future iPad/Kit consumer relies
// on): snake_case keys, a stable uuid + schema_version, no device-local
// base_path, and a byte-stable encode → decode → re-encode round-trip.

import XCTest
@testable import DirectorsChairCore

final class WireContractTests: XCTestCase {

    /// A deterministic project: fixed uuid, no Date-typed fields set, so the
    /// canonical encoder output is byte-stable.
    private func canonicalProject() -> Project {
        var p = Project(name: "Golden Project")
        p.uuid = "00000000-0000-0000-0000-000000000001"
        p.director = "Ada Lovelace"
        p.genre = "Drama"
        return p
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func testWireFormatKeysAndIdentity() throws {
        let json = String(decoding: try encoder.encode(canonicalProject()), as: UTF8.self)
        // Identity + version present, snake_case, device-local path absent.
        XCTAssertTrue(json.contains("\"uuid\" : \"00000000-0000-0000-0000-000000000001\""))
        XCTAssertTrue(json.contains("\"schema_version\" : 1"))
        XCTAssertTrue(json.contains("\"production_company\""))
        XCTAssertFalse(json.contains("\"base_path\""), "base_path is device-local, not part of the wire format")
    }

    func testByteStableRoundTrip() throws {
        let original = canonicalProject()
        let bytes1 = try encoder.encode(original)
        let decoded = try decoder.decode(Project.self, from: bytes1)
        let bytes2 = try encoder.encode(decoded)
        XCTAssertEqual(bytes1, bytes2, "encode → decode → re-encode must be byte-stable (no wire drift)")
    }

    func testIdentityAndVersionSurviveRoundTrip() throws {
        let decoded = try decoder.decode(Project.self, from: try encoder.encode(canonicalProject()))
        XCTAssertEqual(decoded.uuid, "00000000-0000-0000-0000-000000000001")
        XCTAssertEqual(decoded.schemaVersion, Project.currentSchemaVersion)
        XCTAssertEqual(decoded.name, "Golden Project")
        XCTAssertEqual(decoded.id, decoded.uuid)
    }
}
