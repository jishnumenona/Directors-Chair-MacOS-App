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
}
