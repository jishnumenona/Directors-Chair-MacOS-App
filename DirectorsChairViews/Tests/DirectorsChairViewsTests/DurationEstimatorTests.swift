// DurationEstimatorTests.swift
// Tests for WPM-based duration estimation, HTML parsing, time formatting, bubble width

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class DurationEstimatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DurationEstimator.clearCaches()
    }

    // MARK: - htmlToPlainText Tests

    func testPlainTextPassthrough() {
        let text = "Hello, this is plain text."
        XCTAssertEqual(DurationEstimator.htmlToPlainText(text), text)
    }

    func testHtmlTagStripping() {
        let html = "<p>Hello <b>world</b></p>"
        let result = DurationEstimator.htmlToPlainText(html)
        XCTAssertEqual(result, "Hello world")
    }

    func testHtmlEntityDecoding() {
        let html = "<p>Tom &amp; Jerry &lt;3&gt;</p>"
        let result = DurationEstimator.htmlToPlainText(html)
        XCTAssertTrue(result.contains("Tom & Jerry"))
        XCTAssertTrue(result.contains("<3>"))
    }

    func testNbspEntityDecoding() {
        let html = "<div>Hello&nbsp;World</div>"
        let result = DurationEstimator.htmlToPlainText(html)
        XCTAssertTrue(result.contains("Hello World"))
    }

    func testQuoteEntityDecoding() {
        let html = "<span>&quot;Hello&quot; he said, &#39;goodbye&#39;</span>"
        let result = DurationEstimator.htmlToPlainText(html)
        XCTAssertTrue(result.contains("\"Hello\""))
        XCTAssertTrue(result.contains("'goodbye'"))
    }

    func testEmptyAndNilInput() {
        XCTAssertEqual(DurationEstimator.htmlToPlainText(nil), "")
        XCTAssertEqual(DurationEstimator.htmlToPlainText(""), "")
    }

    func testNonHtmlTextNotStripped() {
        // Text that starts with < but isn't HTML
        let text = "2 < 3 and 5 > 4"
        XCTAssertEqual(DurationEstimator.htmlToPlainText(text), text)
    }

    func testCachingReturnsSameResult() {
        let text = "Cached text test"
        let first = DurationEstimator.htmlToPlainText(text)
        let second = DurationEstimator.htmlToPlainText(text)
        XCTAssertEqual(first, second)
    }

    // MARK: - Word Count Tests

    func testCountWordsBasic() {
        XCTAssertEqual(DurationEstimator.countWords(in: "Hello world"), 2)
        XCTAssertEqual(DurationEstimator.countWords(in: "One two three four five"), 5)
    }

    func testCountWordsEmpty() {
        XCTAssertEqual(DurationEstimator.countWords(in: nil), 0)
        XCTAssertEqual(DurationEstimator.countWords(in: ""), 0)
    }

    func testCountWordsWithContractions() {
        // "don't" counts as one word because of \\b[\\w']+\\b
        XCTAssertEqual(DurationEstimator.countWords(in: "I don't know"), 3)
    }

    func testCountWordsWithHtml() {
        let html = "<p>Hello <b>beautiful</b> world</p>"
        XCTAssertEqual(DurationEstimator.countWords(in: html), 3)
    }

    // MARK: - Duration Estimation Tests

    func testEstimateDialogueDurationBasic() {
        // 150 WPM = 2.5 words/sec → 10 words ≈ 4 seconds base
        let text = "one two three four five six seven eight nine ten"
        let duration = DurationEstimator.estimateDialogueDuration(text: text, wpm: 150)
        XCTAssertGreaterThan(duration, 3.0)
        XCTAssertLessThan(duration, 8.0) // Base + pause bonuses
    }

    func testEstimateDialogueDurationEmpty() {
        let duration = DurationEstimator.estimateDialogueDuration(text: nil, wpm: 150)
        XCTAssertEqual(duration, TimelineWPMConstants.minDuration)
    }

    func testEstimateDialogueDurationMinimum() {
        // Very short text should still hit minimum duration
        let duration = DurationEstimator.estimateDialogueDuration(text: "Hi", wpm: 150)
        XCTAssertGreaterThanOrEqual(duration, TimelineWPMConstants.minDuration)
    }

    func testEstimateDialogueDurationWithPauses() {
        // Text with commas, periods, ellipsis should be longer
        let withPauses = "Hello, world. How are you... I wonder—maybe not."
        let withoutPauses = "Hello world How are you I wonder maybe not"

        let durationWithPauses = DurationEstimator.estimateDialogueDuration(text: withPauses, wpm: 150)
        let durationWithout = DurationEstimator.estimateDialogueDuration(text: withoutPauses, wpm: 150)

        XCTAssertGreaterThan(durationWithPauses, durationWithout,
            "Text with punctuation pauses should have longer duration")
    }

    func testEstimateDialogueDurationWithStageDirection() {
        let text = "Hello (pauses nervously) how are you?"
        let textNoDirection = "Hello how are you?"

        let durationWithDirection = DurationEstimator.estimateDialogueDuration(text: text, wpm: 150)
        let durationWithout = DurationEstimator.estimateDialogueDuration(text: textNoDirection, wpm: 150)

        XCTAssertGreaterThan(durationWithDirection, durationWithout,
            "Stage direction should add pause bonus")
    }

    func testEstimateDialogueDurationZeroWPM() {
        // WPM of 0 should be clamped to 1 (via max(1, wpm))
        let duration = DurationEstimator.estimateDialogueDuration(text: "Test text", wpm: 0)
        XCTAssertGreaterThan(duration, 0)
    }

    func testSlowerWPMProducesLongerDuration() {
        let text = "This is a reasonably long piece of dialogue for testing"
        let slow = DurationEstimator.estimateDialogueDuration(text: text, wpm: 80)
        let fast = DurationEstimator.estimateDialogueDuration(text: text, wpm: 260)
        XCTAssertGreaterThan(slow, fast, "Slower WPM should produce longer duration")
    }

    // MARK: - Effective Duration Priority Tests

    func testEffectiveDurationManualFirst() {
        let duration = DurationEstimator.getEffectiveDuration(
            manualDuration: 5.0,
            audioDuration: 3.0,
            text: "Some text",
            wpm: 150
        )
        XCTAssertEqual(duration, 5.0, "Manual duration should take priority")
    }

    func testEffectiveDurationAudioSecond() {
        let duration = DurationEstimator.getEffectiveDuration(
            manualDuration: nil,
            audioDuration: 3.5,
            text: "Some text",
            wpm: 150
        )
        XCTAssertEqual(duration, 3.5, "Audio duration should be second priority")
    }

    func testEffectiveDurationWPMFallback() {
        let duration = DurationEstimator.getEffectiveDuration(
            manualDuration: nil,
            audioDuration: nil,
            text: "Some text for estimation",
            wpm: 150
        )
        let estimated = DurationEstimator.estimateDialogueDuration(text: "Some text for estimation", wpm: 150)
        XCTAssertEqual(duration, estimated, "Should fall back to WPM estimation")
    }

    func testEffectiveDurationSkipsZeroManual() {
        let duration = DurationEstimator.getEffectiveDuration(
            manualDuration: 0.0,
            audioDuration: 4.0,
            text: "Text",
            wpm: 150
        )
        XCTAssertEqual(duration, 4.0, "Zero manual duration should be skipped")
    }

    func testEffectiveDurationSkipsNegativeAudio() {
        let duration = DurationEstimator.getEffectiveDuration(
            manualDuration: nil,
            audioDuration: -1.0,
            text: "Some words here now",
            wpm: 150
        )
        // Should fall through to WPM
        XCTAssertGreaterThan(duration, 0)
    }

    // MARK: - Time Formatting Tests

    func testFormatTimeSeconds() {
        XCTAssertEqual(DurationEstimator.formatTime(5), "00:05")
        XCTAssertEqual(DurationEstimator.formatTime(59), "00:59")
    }

    func testFormatTimeMinutes() {
        XCTAssertEqual(DurationEstimator.formatTime(60), "01:00")
        XCTAssertEqual(DurationEstimator.formatTime(90), "01:30")
        XCTAssertEqual(DurationEstimator.formatTime(3599), "59:59")
    }

    func testFormatTimeHours() {
        XCTAssertEqual(DurationEstimator.formatTime(3600), "01:00:00")
        XCTAssertEqual(DurationEstimator.formatTime(3661), "01:01:01")
        XCTAssertEqual(DurationEstimator.formatTime(7200), "02:00:00")
    }

    func testFormatTimeZero() {
        XCTAssertEqual(DurationEstimator.formatTime(0), "00:00")
    }

    func testFormatTimeReadableSeconds() {
        let result = DurationEstimator.formatTimeReadable(5.5)
        XCTAssertTrue(result.contains("5.5s"))
    }

    func testFormatTimeReadableMinutes() {
        let result = DurationEstimator.formatTimeReadable(90.5)
        XCTAssertTrue(result.contains("1m"))
        XCTAssertTrue(result.contains("30.5s"))
    }

    func testFormatTimeReadableHours() {
        let result = DurationEstimator.formatTimeReadable(3661.5)
        XCTAssertTrue(result.contains("1h"))
        XCTAssertTrue(result.contains("1m"))
    }

    // MARK: - Bubble Width Tests

    func testBubbleWidthMinimum() {
        let segment = TimelineSegment(
            start: 0, duration: 0.1, character: "A", color: "#FFF",
            text: "Hi", sceneName: "S1", contentType: .dialogue
        )
        let width = DurationEstimator.bubbleWidth(for: segment, pxPerSec: 60, showThumbs: false)
        XCTAssertGreaterThanOrEqual(width, TimelineLayoutConstants.minBubbleWidth)
    }

    func testBubbleWidthIncreasesWithDuration() {
        let shortSegment = TimelineSegment(
            start: 0, duration: 1.0, character: "A", color: "#FFF",
            text: "Short", sceneName: "S1", contentType: .dialogue
        )
        let longSegment = TimelineSegment(
            start: 0, duration: 10.0, character: "A", color: "#FFF",
            text: "Short", sceneName: "S1", contentType: .dialogue
        )
        let shortWidth = DurationEstimator.bubbleWidth(for: shortSegment, pxPerSec: 60, showThumbs: false)
        let longWidth = DurationEstimator.bubbleWidth(for: longSegment, pxPerSec: 60, showThumbs: false)
        XCTAssertGreaterThan(longWidth, shortWidth)
    }

    func testBubbleWidthWithThumbs() {
        let segment = TimelineSegment(
            start: 0, duration: 2.0, character: "A", color: "#FFF",
            text: "Test text", sceneName: "S1", contentType: .dialogue
        )
        let withoutThumbs = DurationEstimator.bubbleWidth(for: segment, pxPerSec: 60, showThumbs: false)
        let withThumbs = DurationEstimator.bubbleWidth(for: segment, pxPerSec: 60, showThumbs: true)
        XCTAssertGreaterThanOrEqual(withThumbs, withoutThumbs)
    }

    // MARK: - WPM Constants Tests

    func testWPMConstantsValid() {
        XCTAssertGreaterThan(TimelineWPMConstants.defaultWPM, 0)
        XCTAssertGreaterThan(TimelineWPMConstants.minWPM, 0)
        XCTAssertGreaterThan(TimelineWPMConstants.maxWPM, TimelineWPMConstants.minWPM)
        XCTAssertGreaterThan(TimelineWPMConstants.minDuration, 0)
    }

    func testPauseConstantsPositive() {
        XCTAssertGreaterThan(TimelineWPMConstants.commaPause, 0)
        XCTAssertGreaterThan(TimelineWPMConstants.sentencePause, 0)
        XCTAssertGreaterThan(TimelineWPMConstants.ellipsisPause, 0)
        XCTAssertGreaterThan(TimelineWPMConstants.stageDirectionPause, 0)
    }

    func testSentencePauseLongerThanComma() {
        XCTAssertGreaterThan(TimelineWPMConstants.sentencePause, TimelineWPMConstants.commaPause)
    }
}
