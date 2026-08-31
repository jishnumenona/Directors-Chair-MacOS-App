// SpokenLengthTests.swift
//
// "Reset to spoken length" (owner 2026-08-29): the pure reading-rate
// estimate, how a character's voice pace becomes a WPM, and that the reset
// is stored the way a trim is (manualDuration) with the block flowing back
// into place.

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class SpokenLengthEstimateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DurationEstimator.clearCaches()
    }

    func testWordsOverWPMPlusAPausePerSentence() {
        // 5 words at 150 wpm = 2.0 s, two sentences = 2 × 0.3 s
        let seconds = SpokenLength.seconds(forText: "Hello there. How are you?", wordsPerMinute: 150)
        XCTAssertEqual(seconds, 2.6, accuracy: 1e-6)
    }

    func testAFasterSpeakerTakesLess() {
        let text = "One two three four five six seven eight nine ten"
        XCTAssertEqual(SpokenLength.seconds(forText: text, wordsPerMinute: 150), 4.0, accuracy: 1e-6)
        XCTAssertEqual(SpokenLength.seconds(forText: text, wordsPerMinute: 300), 2.0, accuracy: 1e-6)
    }

    func testEllipsisAndStackedPunctuationAreOnePause() {
        // 2 words at 150 wpm = 0.8 s + 2 sentence pauses
        XCTAssertEqual(SpokenLength.seconds(forText: "Wait... what?!", wordsPerMinute: 150), 1.4, accuracy: 1e-6)
        XCTAssertEqual(SpokenLength.sentenceCount(in: "Wait... what?!"), 2)
        XCTAssertEqual(SpokenLength.sentenceCount(in: "No punctuation at all"), 0)
        XCTAssertEqual(SpokenLength.sentenceCount(in: "One. Two! Three? Four\u{2026}"), 4)
    }

    func testNeverShorterThanHalfASecond() {
        XCTAssertEqual(SpokenLength.seconds(forText: "", wordsPerMinute: 150), 0.5)
        XCTAssertEqual(SpokenLength.seconds(forText: nil, wordsPerMinute: 150), 0.5)
        XCTAssertEqual(SpokenLength.seconds(forText: "Hi", wordsPerMinute: 260), 0.5, "0.23 s of speech floors at 0.5")
        XCTAssertEqual(SpokenLength.minimumSeconds, TimelineTrim.minimumDuration)
    }

    func testHTMLIsStrippedBeforeCounting() {
        // 3 words, no sentence end → 1.2 s
        XCTAssertEqual(SpokenLength.seconds(forText: "<p>One <b>two</b> three</p>", wordsPerMinute: 150), 1.2, accuracy: 1e-6)
    }

    func testNonPositiveWPMFallsBackToTheTimelineDefault() {
        let text = "One two three four five six"
        let expected = SpokenLength.seconds(forText: text, wordsPerMinute: TimelineWPMConstants.defaultWPM)
        XCTAssertEqual(SpokenLength.seconds(forText: text, wordsPerMinute: 0), expected, accuracy: 1e-9)
        XCTAssertEqual(SpokenLength.seconds(forText: text, wordsPerMinute: -5), expected, accuracy: 1e-9)
    }

    // MARK: Voice pace → WPM

    func testVoicePaceScalesTheTimelineWPM() {
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Very Slow", timelineWPM: 150), 105)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Slow", timelineWPM: 150), 128)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Normal", timelineWPM: 150), 150)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Moderate", timelineWPM: 150), 165)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Fast", timelineWPM: 150), 188)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Rapid", timelineWPM: 150), 218)
    }

    func testEveryVoiceTabPaceHasAMultiplier() {
        // The Voice tab's pace chips (VoiceOption.paces in VoiceTab.swift)
        for pace in ["Very Slow", "Slow", "Normal", "Moderate", "Fast", "Rapid"] {
            XCTAssertNotNil(SpokenLength.paceMultipliers[pace.lowercased()], "\(pace) has no WPM multiplier")
        }
        XCTAssertEqual(SpokenLength.paceMultipliers["normal"], 1.0, "Normal is the timeline WPM itself")
    }

    func testNoPaceOrUnknownPaceReadsAtTheTimelineWPM() {
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: nil, timelineWPM: 170), 170)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "", timelineWPM: 170), 170)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Varied", timelineWPM: 170), 170)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "  fast ", timelineWPM: 100), 125,
                       "case- and whitespace-insensitive")
    }

    func testScaledWPMStaysInsideTheTimelineRange() {
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Very Slow", timelineWPM: TimelineWPMConstants.minWPM),
                       TimelineWPMConstants.minWPM)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Rapid", timelineWPM: TimelineWPMConstants.maxWPM),
                       TimelineWPMConstants.maxWPM)
        XCTAssertEqual(SpokenLength.wordsPerMinute(voicePace: "Normal", timelineWPM: 0),
                       TimelineWPMConstants.defaultWPM, "a missing timeline WPM falls back to the default")
    }
}

@MainActor
final class SpokenLengthResetTests: XCTestCase {

    private var viewModel: TimelineViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TimelineViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    private static let line = "Hello there. How are you today?"

    private func makeProject(pace: String?) -> Project {
        let scene = Scene(
            uuid: "scene-1",
            name: "Scene 1 - INT. KITCHEN - NIGHT",
            dialogues: [
                // Trimmed and dragged by hand before the reset
                Dialogue(uuid: "d-1", character: "Alice", text: Self.line, chronologyNumber: 1,
                         manualDuration: 9.0, manualStartTime: 20.0),
                Dialogue(uuid: "d-2", character: "Alice", text: "Fine.", chronologyNumber: 3)
            ],
            actions: [Action(uuid: "a-1", description: "Alice pours the tea", chronologyNumber: 2)],
            narrations: [],
            soundNotes: [],
            shots: []
        )
        var alice = Character(name: "Alice")
        alice.voicePace = pace
        return Project(name: "Spoken", characters: [alice],
                       sequences: [Sequence(name: "Act 1", scenes: [scene])])
    }

    private func show(_ project: Project) {
        viewModel.setProject(project)
        viewModel.showScene(project.sequences[0].scenes[0])
    }

    private func segment(_ sourceId: String) -> TimelineSegment {
        guard let seg = viewModel.segments.first(where: { $0.sourceItemId == sourceId }) else {
            XCTFail("no segment for \(sourceId)")
            return TimelineSegment(start: 0, duration: 0, character: "", color: "", text: "", sceneName: "", contentType: .note)
        }
        return seg
    }

    private func scene() -> Scene { viewModel.getProject()!.sequences[0].scenes[0] }

    func testSpokenWPMComesFromTheSpeakersVoicePace() {
        show(makeProject(pace: "Fast"))
        viewModel.wpm = 150
        XCTAssertEqual(viewModel.spokenWordsPerMinute(for: segment("d-1")), 188)
        viewModel.wpm = 100
        XCTAssertEqual(viewModel.spokenWordsPerMinute(for: segment("d-1")), 125, "follows the timeline WPM")
    }

    func testWithoutAPaceTheTimelineWPMIsUsed() {
        show(makeProject(pace: nil))
        viewModel.wpm = 120
        XCTAssertEqual(viewModel.spokenWordsPerMinute(for: segment("d-1")), 120)
        XCTAssertEqual(viewModel.spokenLength(for: segment("d-1")),
                       TimelineTrim.snap(SpokenLength.seconds(forText: Self.line, wordsPerMinute: 120)),
                       accuracy: 1e-9)
    }

    func testSpokenLengthSitsOnTheTrimGridAndNeverBelowTheFloor() {
        show(makeProject(pace: "Rapid"))
        for id in ["d-1", "d-2"] {
            let length = viewModel.spokenLength(for: segment(id))
            XCTAssertGreaterThanOrEqual(length, TimelineTrim.minimumDuration)
            XCTAssertEqual(length, TimelineTrim.snap(length), accuracy: 1e-9, "\(id) is on the 0.1 s grid")
        }
    }

    func testResetStoresTheEstimateAsManualDurationAndClearsTheStartOffset() {
        show(makeProject(pace: "Slow"))
        let before = segment("d-1")
        XCTAssertEqual(before.start, 20, accuracy: 1e-6, "the manual start offset applies before the reset")
        XCTAssertEqual(before.duration, 9, accuracy: 1e-6)

        let expected = viewModel.spokenLength(for: before)
        let placement = viewModel.resetToSpokenLength(id: before.id)

        XCTAssertEqual(scene().dialogues[0].manualDuration ?? -1, Double(expected), accuracy: 1e-9)
        XCTAssertNil(scene().dialogues[0].manualStartTime)
        XCTAssertEqual(placement?.start ?? -1, 0, accuracy: 1e-6, "first in chronology → flows back to the scene start")
        XCTAssertEqual(placement?.duration ?? -1, expected, accuracy: 1e-6)
        XCTAssertEqual(segment("d-1").start, 0, accuracy: 1e-6)
        XCTAssertEqual(segment("d-1").duration, expected, accuracy: 1e-6)

        // Everything after it re-flows too
        XCTAssertEqual(segment("a-1").start, expected, accuracy: 1e-6)
        XCTAssertEqual(segment("d-2").start, expected + TimelineWPMConstants.actionDuration, accuracy: 1e-6)

        // And the value survives a rebuild from the persisted row, like a trim does
        viewModel.setProject(viewModel.getProject()!)
        viewModel.refresh()
        XCTAssertEqual(segment("d-1").duration, expected, accuracy: 1e-6)
    }

    func testResetIgnoresNonDialogueBlocks() {
        show(makeProject(pace: nil))
        let action = segment("a-1")
        XCTAssertNil(viewModel.resetToSpokenLength(id: action.id))
        XCTAssertNil(scene().actions[0].manualDuration)
        XCTAssertNil(viewModel.resetToSpokenLength(id: UUID()), "unknown segment")
    }
}
