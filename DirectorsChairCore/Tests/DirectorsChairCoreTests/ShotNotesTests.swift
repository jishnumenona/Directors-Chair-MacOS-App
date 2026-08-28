import XCTest
@testable import DirectorsChairCore

/// DC-0074: a shot carries the user's own notes beside its description,
/// and older files still decode the way they always did.
final class ShotNotesTests: XCTestCase {
    func testNotesRoundTripBesideTheDescription() throws {
        var shot = Shot(shotId: 3, description: "Wide on the gallery")
        shot.notes = "Ask for the fog machine before the take."
        let data = try JSONEncoder().encode(shot)
        let back = try JSONDecoder().decode(Shot.self, from: data)
        XCTAssertEqual(back.description, "Wide on the gallery")
        XCTAssertEqual(back.notes, "Ask for the fog machine before the take.")
        XCTAssertEqual(Shot(shotId: 1).notes, "", "a new shot has no notes")
    }

    func testAFileWithoutNotesDecodesToEmptyNotes() throws {
        let json = #"{"uuid":"a","shot_id":1,"description":"Two-shot at the ladder"}"#
        let shot = try JSONDecoder().decode(Shot.self, from: Data(json.utf8))
        XCTAssertEqual(shot.description, "Two-shot at the ladder")
        XCTAssertEqual(shot.notes, "")
    }

    func testAPythonEraNotesFieldStillBecomesTheDescription() throws {
        // Old files carried the description under "notes" and no description.
        let json = #"{"uuid":"a","shot_id":1,"notes":"Legacy description text"}"#
        let shot = try JSONDecoder().decode(Shot.self, from: Data(json.utf8))
        XCTAssertEqual(shot.description, "Legacy description text")
        XCTAssertEqual(shot.notes, "", "the legacy field is not doubled into notes")
    }

    func testBothFieldsPresentKeepTheirOwnMeaning() throws {
        let json = #"{"uuid":"a","shot_id":1,"description":"Insert on the logbook","notes":"Cotton gloves between takes"}"#
        let shot = try JSONDecoder().decode(Shot.self, from: Data(json.utf8))
        XCTAssertEqual(shot.description, "Insert on the logbook")
        XCTAssertEqual(shot.notes, "Cotton gloves between takes")
    }
}
