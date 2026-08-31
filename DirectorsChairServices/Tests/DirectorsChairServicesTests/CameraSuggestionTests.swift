// DC-0094: the suggested camera direction — prompt facts and reply cleaning.
import XCTest
import DirectorsChairCore
@testable import DirectorsChairServices

final class CameraSuggestionTests: XCTestCase {
    func testPromptCarriesTheShotsFacts() {
        var shot = Shot(shotId: 2, description: "@Susan is driving the mini van, Alex in the passenger seat")
        shot.shotType = "MS"; shot.cameraAngle = "Low"; shot.lensMm = 35; shot.movement = "Dolly In"
        var scene = Scene(name: "Inside the van"); scene.timeOfDay = "Day"
        var location = Location(name: "Outside the mini van"); location.description = "Wide open desert road"
        let prompt = CameraSuggestion.prompt(shot: shot, scene: scene, location: location,
                                             characters: [Character(name: "Susan"), Character(name: "Alex")])
        XCTAssertTrue(prompt.contains("Shot: @Susan is driving"))
        XCTAssertTrue(prompt.contains("MS shot, Low angle, 35mm lens, camera movement: dolly in"), prompt)
        XCTAssertTrue(prompt.contains("Scene: Inside the van, Day"))
        XCTAssertTrue(prompt.contains("Location: Outside the mini van — Wide open desert road"))
        XCTAssertTrue(prompt.contains("Characters in the shot: Susan, Alex"))
        XCTAssertTrue(CameraSuggestion.systemPrompt.contains("ONE sentence"))
    }

    func testCleanKeepsOneBareLine() {
        XCTAssertEqual(CameraSuggestion.clean("Camera: \"Low on the road, looking up past the wheel.\"\nSecond line"),
                       "Low on the road, looking up past the wheel.")
        XCTAssertEqual(CameraSuggestion.clean("\n\n  From the back seat, over Susan's shoulder.  "),
                       "From the back seat, over Susan's shoulder.")
        XCTAssertEqual(CameraSuggestion.clean(""), "")
    }

    func testCacheKeyFollowsTheFacts() {
        var shot = Shot(shotId: 1, description: "A")
        let before = CameraSuggestion.cacheKey(shot: shot)
        shot.description = "B"
        XCTAssertNotEqual(before, CameraSuggestion.cacheKey(shot: shot))
        shot.description = "A"
        XCTAssertEqual(before, CameraSuggestion.cacheKey(shot: shot))
    }
}
