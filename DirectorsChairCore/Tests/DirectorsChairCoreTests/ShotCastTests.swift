//
//  ShotCastTests.swift — the shot's explicit cast (usability batch 2026-08-29).
//

import XCTest
@testable import DirectorsChairCore

final class ShotCastTests: XCTestCase {

    func testAShotWithoutTheKeyDecodesWithNoCast() throws {
        let json = #"{"shot_id": 4, "description": "Wide on the cottage"}"#
        let shot = try JSONDecoder().decode(Shot.self, from: Data(json.utf8))
        XCTAssertEqual(shot.characters, [])
    }

    func testTheCastRoundTripsInOrder() throws {
        let shot = Shot(shotId: 4, description: "Two at the wall", characters: ["Teo", "Noor"])
        let data = try JSONEncoder().encode(shot)
        let back = try JSONDecoder().decode(Shot.self, from: data)
        XCTAssertEqual(back.characters, ["Teo", "Noor"])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["characters"] as? [String], ["Teo", "Noor"])
    }

    // DC-0091: continuity references persist and default to none.
    func testReferenceShotIdsRoundTripAndDefaultEmpty() throws {
        var shot = Shot(shotId: 2, description: "Reverse angle")
        XCTAssertEqual(shot.referenceShotIds, [])
        shot.referenceShotIds = ["shot-1-uuid"]
        let data = try JSONEncoder().encode(shot)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["reference_shot_ids"] as? [String], ["shot-1-uuid"])
        XCTAssertEqual(try JSONDecoder().decode(Shot.self, from: data).referenceShotIds, ["shot-1-uuid"])
        var legacy = json
        legacy.removeValue(forKey: "reference_shot_ids")
        let decoded = try JSONDecoder().decode(Shot.self, from: try JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(decoded.referenceShotIds, [])
    }

    // An edited cast persists as explicit; older files decode as not explicit.
    func testCastIsExplicitRoundTripsAndDefaultsFalse() throws {
        var shot = Shot(shotId: 5, description: "Empty room")
        XCTAssertFalse(shot.castIsExplicit)
        shot.castIsExplicit = true
        shot.characters = []
        let data = try JSONEncoder().encode(shot)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["cast_is_explicit"] as? Bool, true)
        XCTAssertTrue(try JSONDecoder().decode(Shot.self, from: data).castIsExplicit)
        var legacy = json
        legacy.removeValue(forKey: "cast_is_explicit")
        XCTAssertFalse(try JSONDecoder().decode(Shot.self, from: try JSONSerialization.data(withJSONObject: legacy)).castIsExplicit)
    }
}
