// PropMentionTests.swift
//
// DC-0079: which props a shot line names — the rule that decides which
// Prop Shop pictures ride along as references.

import XCTest
@testable import DirectorsChairServices

final class PropMentionTests: XCTestCase {

    func testFullNameMatchesWholeWordCaseInsensitive() {
        XCTAssertTrue(StoryboardSubjects.mentionsProp("She opens the LOGBOOK at the last page", name: "Logbook"))
        XCTAssertTrue(StoryboardSubjects.mentionsProp("She opens the logbooks", name: "Logbook"),
                      "a plural still names the prop")
        XCTAssertFalse(StoryboardSubjects.mentionsProp("Noor reads by the window", name: "Logbook"))
    }

    func testHeadNounOfAMultiWordNameCounts() {
        XCTAssertTrue(StoryboardSubjects.mentionsProp("Teo lifts the brass storm lantern", name: "Storm Lantern"))
        XCTAssertTrue(StoryboardSubjects.mentionsProp("two lanterns on the sill", name: "Storm Lantern"))
    }

    func testTheFirstWordNeverCounts() {
        XCTAssertFalse(StoryboardSubjects.mentionsProp("the wind rises over the cliff", name: "The Letter"),
                       "\"The Letter\" must not match every \"the\"")
        XCTAssertFalse(StoryboardSubjects.mentionsProp("a storm rolls in", name: "Storm Lantern"),
                       "the qualifier alone is not the prop")
    }

    func testShortHeadNounsNeedTheFullName() {
        XCTAssertTrue(StoryboardSubjects.mentionsProp("a tin of tea on the shelf", name: "Tin of Tea"))
        XCTAssertFalse(StoryboardSubjects.mentionsProp("tea on the shelf", name: "Tin of Tea"))
    }

    func testNamesTooShortToBeWordsNeverMatch() {
        XCTAssertFalse(StoryboardSubjects.mentionsProp("a b c", name: "b"))
        XCTAssertFalse(StoryboardSubjects.mentionsProp("anything", name: ""))
    }
}
