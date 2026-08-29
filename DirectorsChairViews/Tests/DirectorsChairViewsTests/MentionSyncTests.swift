// Owner 2026-08-29: mentions in a description feed the shot's lists.
import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class MentionSyncTests: XCTestCase {
    func testMentionsJoinTheListsWithoutOverwritingALocation() {
        let susan = Character(name: "Susan")
        let desert = Location(name: "Outside the mini van")
        let van = Prop(name: "Mini van")
        let shot = Shot(shotId: 5, description: "")
        let empty = Scene(name: "Intro")
        let text = "$Mini van moving towards the camera in #Outside the mini van, @Susan at the wheel"
        let synced = MentionSync.apply(description: text, shot: shot, scene: empty,
                                       characters: [susan], locations: [desert], props: [van])
        XCTAssertEqual(synced.shot.characters, ["Susan"])
        XCTAssertEqual(synced.scene?.location, "Outside the mini van")
        XCTAssertEqual(synced.scene?.props, ["Mini van"])
        XCTAssertTrue(synced.shotChanged && synced.sceneChanged)

        var placed = Scene(name: "Diner"); placed.location = "Roadside diner"; placed.props = ["Mini van"]
        var cast = shot; cast.characters = ["Susan"]
        let again = MentionSync.apply(description: text, shot: cast, scene: placed,
                                      characters: [susan], locations: [desert], props: [van])
        XCTAssertEqual(again.scene?.location, "Roadside diner", "an existing location is kept")
        XCTAssertFalse(again.shotChanged)
        XCTAssertFalse(again.sceneChanged)
    }
}
