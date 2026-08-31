// Owner 2026-08-29: thumbnails for everything a description mentions.
import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class MentionParserTests: XCTestCase {
    func testFindsEveryKindInOrderPreferringLongerNames() {
        var susan = Character(name: "Susan"); susan.baseImage = "assets/characters/Susan/base.png"
        var susanLee = Character(name: "Susan Lee"); susanLee.baseImage = "assets/characters/SusanLee/base.png"
        var van = Location(name: "Inside the van"); van.primaryImage = "assets/locations/van/primary.png"
        var lantern = Prop(name: "Lantern"); lantern.thumbnail = "assets/props/lantern.png"
        var three = Shot(shotId: 3, description: "Reverse"); three.previewImage = "assets/shots/shot_3/latest.png"
        let text = "$Lantern glows as @Susan Lee looks back — #Inside the van, matching &Shot #3"
        let found = MentionParser.mentions(in: text, characters: [susan, susanLee], locations: [van],
                                           props: [lantern], shots: [three])
        XCTAssertEqual(found.map(\.name), ["Lantern", "Susan Lee", "Inside the van", "Shot #3"])
        XCTAssertEqual(found.map(\.imagePath), ["assets/props/lantern.png", "assets/characters/SusanLee/base.png",
                                                "assets/locations/van/primary.png", "assets/shots/shot_3/latest.png"])
    }

    func testIgnoresUnknownNamesAndIsCaseInsensitive() {
        let alex = Character(name: "Alex")
        let found = MentionParser.mentions(in: "@alex waves at @Nobody", characters: [alex], locations: [], props: [], shots: [])
        XCTAssertEqual(found.map(\.name), ["Alex"])
        XCTAssertTrue(MentionParser.mentions(in: "no mentions here", characters: [alex], locations: [], props: [], shots: []).isEmpty)
    }
}
