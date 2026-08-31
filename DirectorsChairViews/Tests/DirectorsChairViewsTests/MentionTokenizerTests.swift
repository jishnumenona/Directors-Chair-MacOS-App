// DC-0095: inline mentions — token ranges in plain text.
import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class MentionTokenizerTests: XCTestCase {
    func testFindsEveryOccurrenceLongestNameFirstWithoutOverlap() {
        let susan = Character(name: "Susan")
        let susanLee = Character(name: "Susan Lee")
        var van = Prop(name: "Mini van"); van.thumbnail = "assets/props/van.png"
        let text = "$Mini van waits. @Susan Lee looks at @Susan; the $Mini van idles."
        let tokens = MentionTokenizer.tokens(in: text, characters: [susan, susanLee], locations: [], props: [van], shots: [])
        XCTAssertEqual(tokens.map { String(text[$0.range]) }, ["$Mini van", "@Susan Lee", "@Susan", "$Mini van"])
        XCTAssertEqual(tokens.map(\.mention.name), ["Mini van", "Susan Lee", "Susan", "Mini van"])
        XCTAssertEqual(tokens[0].mention.imagePath, "assets/props/van.png")
    }

    func testNoTokensInPlainProse() {
        XCTAssertTrue(MentionTokenizer.tokens(in: "Nothing here", characters: [Character(name: "Alex")],
                                              locations: [], props: [], shots: []).isEmpty)
    }
}
