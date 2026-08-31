// DC-0100: story references — identity as text and back.
import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class StoryReferenceTests: XCTestCase {
    func testRoundTripsThroughItsURLForm() {
        let costume = CharacterCostume(name: "Tweed")
        let reference = StoryReference.costume(costume, of: Character(name: "Eli Voss"))
        let text = reference.urlString
        XCTAssertTrue(text.hasPrefix("directorschair://ref/costume/"), text)
        XCTAssertEqual(StoryReference(urlString: text), reference)
        XCTAssertEqual(reference.label, "Tweed · Eli Voss's costume")
        let location = StoryReference.location(Location(name: "Outside the mini van"))
        XCTAssertEqual(StoryReference(urlString: location.urlString)?.name, "Outside the mini van")
        XCTAssertEqual(location.label, "Outside the mini van · location")
    }

    func testRejectsOtherText() {
        XCTAssertNil(StoryReference(urlString: "https://example.com/ref/prop/1"))
        XCTAssertNil(StoryReference(urlString: "directorschair://ref/spaceship/1"))
        XCTAssertNil(StoryReference(urlString: "just words"))
    }
}
