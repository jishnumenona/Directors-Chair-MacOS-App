// UUIDIdentityExtendedTests.swift
//
// WS2.5 — extends the stored-UUID identity acceptance suite to the five
// entities that previously used name-based identity (id == name): Project,
// Location, Lighting, EffectDef, Costume. Mirrors UUIDIdentityTests' contract
// for Shot/Scene/Sequence:
//   - id returns the stored uuid, not the name
//   - default uuid is a valid RFC-4122 string
//   - two entities with the same name have different ids
//   - id is stable across a name change
//   - uuid survives encode/decode; legacy JSON without uuid gets a fresh one

import XCTest
@testable import DirectorsChairCore

final class UUIDIdentityExtendedTests: XCTestCase {

    // MARK: - Project

    func testProjectIdReturnsUUID() {
        let p = Project(name: "My Film")
        XCTAssertEqual(p.id, p.uuid)
        XCTAssertNotEqual(p.id, p.name)
        XCTAssertEqual(p.uuid.count, 36)
        XCTAssertNotNil(UUID(uuidString: p.uuid))
    }

    func testTwoProjectsWithSameNameHaveDifferentIds() {
        XCTAssertNotEqual(Project(name: "Untitled").id, Project(name: "Untitled").id)
    }

    func testProjectIdStableAcrossNameChange() {
        var p = Project(name: "Working Title")
        let original = p.id
        p.name = "Final Title"
        XCTAssertEqual(p.id, original)
    }

    func testProjectUUIDSurvivesRoundTripAndLegacyGetsFreshUUID() throws {
        let original = Project(name: "RoundTrip")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(decoded.uuid, original.uuid)

        // Legacy file with no uuid key still loads, with a generated uuid.
        let legacy = try JSONDecoder().decode(Project.self, from: Data(#"{ "name": "Legacy" }"#.utf8))
        XCTAssertNotNil(UUID(uuidString: legacy.uuid))
    }

    // MARK: - Location

    func testLocationIdentity() throws {
        let loc = Location(name: "Warehouse")
        XCTAssertEqual(loc.id, loc.uuid)
        XCTAssertNotEqual(loc.id, loc.name)
        XCTAssertNotNil(UUID(uuidString: loc.uuid))
        XCTAssertNotEqual(Location(name: "Set A").id, Location(name: "Set A").id)

        var mutable = loc
        let original = mutable.id
        mutable.name = "Renamed Warehouse"
        XCTAssertEqual(mutable.id, original)

        let decoded = try JSONDecoder().decode(Location.self,
                                                from: JSONEncoder().encode(loc))
        XCTAssertEqual(decoded.uuid, loc.uuid)
    }

    // MARK: - Lighting

    func testLightingIdentity() throws {
        let light = Lighting(name: "Key Light")
        XCTAssertEqual(light.id, light.uuid)
        XCTAssertNotEqual(light.id, light.name)
        XCTAssertNotNil(UUID(uuidString: light.uuid))
        XCTAssertNotEqual(Lighting(name: "Fill").id, Lighting(name: "Fill").id)
        let decoded = try JSONDecoder().decode(Lighting.self,
                                               from: JSONEncoder().encode(light))
        XCTAssertEqual(decoded.uuid, light.uuid)
    }

    // MARK: - EffectDef

    func testEffectDefIdentity() throws {
        let fx = EffectDef(name: "Smoke")
        XCTAssertEqual(fx.id, fx.uuid)
        XCTAssertNotEqual(fx.id, fx.name)
        XCTAssertNotNil(UUID(uuidString: fx.uuid))
        XCTAssertNotEqual(EffectDef(name: "Fog").id, EffectDef(name: "Fog").id)
        let decoded = try JSONDecoder().decode(EffectDef.self,
                                               from: JSONEncoder().encode(fx))
        XCTAssertEqual(decoded.uuid, fx.uuid)
    }

    // MARK: - Costume

    func testCostumeIdentity() throws {
        let costume = Costume(name: "Detective Coat")
        XCTAssertEqual(costume.id, costume.uuid)
        XCTAssertNotEqual(costume.id, costume.name)
        XCTAssertNotNil(UUID(uuidString: costume.uuid))
        XCTAssertNotEqual(Costume(name: "Uniform").id, Costume(name: "Uniform").id)
        let decoded = try JSONDecoder().decode(Costume.self,
                                               from: JSONEncoder().encode(costume))
        XCTAssertEqual(decoded.uuid, costume.uuid)
    }
}
