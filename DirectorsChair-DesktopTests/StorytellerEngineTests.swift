// DirectorsChair-DesktopTests/StorytellerEngineTests.swift
//
// Storyteller mode: engine chunking + estimate math + cache-key stability
// + PREVIOUSLY threading through injected seams (no network), the
// no-network-before-confirm invariant, and the pure playhead/slideshow
// mapping math. Speech data is header-wrapped PCM so the REAL duration
// measurement path (AVAudioPlayer) is exercised offline.

import XCTest
import AVFoundation
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class StorytellerEngineTests: XCTestCase {

    private var tempDir: URL!
    private var transformCalls: [(system: String, user: String)] = []
    private var speechTexts: [String] = []
    private var transcriptQueue: [String] = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-storyteller-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir,
                                                 withIntermediateDirectories: true)
        transformCalls = []
        speechTexts = []
        transcriptQueue = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Fixture

    /// Three scenes: two with content, one empty (must be skipped). The
    /// middle position of the empty scene proves chunk sceneIndex stays a
    /// GLOBAL index, not a chunk ordinal.
    private static func makeFixtureProject() -> Project {
        var project = Project(name: "Storyteller Fixture")
        let opening = Scene(
            name: "Opening",
            description: "Rain hammers the skylight.",
            dialogues: [
                Dialogue(character: "Mara", text: "<p>Run. <b>Now.</b></p>",
                         chronologyNumber: 1),
                Dialogue(character: "Ilya", text: "Where?", chronologyNumber: 3),
            ],
            actions: [Action(description: "Mara grabs the brass key.",
                             chronologyNumber: 2)],
            location: "INT. KITCHEN - NIGHT",
            timeOfDay: "Night",
            weather: "Rain")
        let empty = Scene(name: "Empty Interlude")
        let finale = Scene(
            name: "Finale",
            narrations: [Narration(text: "It began with rain.",
                                   chronologyNumber: 1)])
        project.sequences = [Sequence(name: "Act 1",
                                      scenes: [opening, empty, finale])]
        project.characters = [Character(name: "Mara"), Character(name: "Ilya")]
        return project
    }

    /// 24 kHz 16-bit mono PCM wrapped to a decodable WAV — 48,000 bytes of
    /// samples = exactly 1.0 s, so measured durations are asserted for real.
    private nonisolated static func oneSecondWAV() -> Data {
        PCMWAVWrapper.wrapIfNeeded(Data(count: 48_000))
    }

    /// Offline engine: the seams record their inputs on the test class and
    /// replay scripted transcripts (VoiceConversationController seam style).
    private func makeEngine(transcripts: [String]) -> StorytellerEngine {
        transcriptQueue = transcripts
        return StorytellerEngine(
            transformText: { [weak self] system, user in
                await MainActor.run {
                    self?.transformCalls.append((system, user))
                    guard let self, !self.transcriptQueue.isEmpty else { return "" }
                    return self.transcriptQueue.removeFirst()
                }
            },
            synthesizeSpeech: { [weak self] request in
                await MainActor.run { self?.speechTexts.append(request.text) }
                return Self.oneSecondWAV()
            },
            cacheRoot: tempDir)
    }

    // MARK: - Chunk building

    func testBuildChunksSkipsEmptyScenesAndRendersPlainText() {
        let chunks = StorytellerEngine.buildChunks(from: Self.makeFixtureProject())

        XCTAssertEqual(chunks.count, 2, "the empty scene is skipped")
        XCTAssertEqual(chunks[0].sceneName, "Opening")
        XCTAssertEqual(chunks[0].sceneIndex, 0)
        XCTAssertEqual(chunks[1].sceneName, "Finale")
        XCTAssertEqual(chunks[1].sceneIndex, 2,
                       "sceneIndex is GLOBAL — it maps onto playback boundaries")

        let opening = chunks[0].scriptText
        XCTAssertTrue(opening.hasPrefix("INT. KITCHEN - NIGHT"),
                      "the slug line leads (the prompt turns it into atmosphere)")
        XCTAssertTrue(opening.contains("Rain hammers the skylight."))
        XCTAssertTrue(opening.contains("Run. Now."), "dialogue HTML is stripped")
        XCTAssertFalse(opening.contains("<p>"))
        XCTAssertTrue(opening.contains("MARA"), "speaker cues survive")
        // Chronology order: Mara's line, then the action, then Ilya's.
        let maraIdx = opening.range(of: "Run. Now.")!.lowerBound
        let actionIdx = opening.range(of: "brass key")!.lowerBound
        let ilyaIdx = opening.range(of: "Where?")!.lowerBound
        XCTAssertTrue(maraIdx < actionIdx && actionIdx < ilyaIdx)

        // Atmosphere-derived delivery vs. the spec fallback.
        XCTAssertEqual(chunks[0].emotion, "a night scene, rain")
        XCTAssertEqual(chunks[1].emotion, StorytellerVoice.fallbackEmotion)
    }

    // MARK: - Estimate math

    func testEstimateMatchesSpecFormulaAndRateCard() {
        // 4000 script chars → 1000 tokens in; narration ≈ 3000 chars →
        // 750 tokens out; TTS bills the narration chars.
        let rates = AIUsageStats.rateCard
        let expected = AIUsageStats.textCallCost(promptTokens: 1000,
                                                 completionTokens: 750)
            + 3.0 * rates.speechPer1kChars
        XCTAssertEqual(StorytellerEngine.estimatedCost(scriptCharacters: 4000),
                       expected, accuracy: 1e-9)
        XCTAssertEqual(StorytellerEngine.estimatedCost(scriptCharacters: 0), 0)
        // TTS dominates: sanity that the estimate is in real-money territory
        // for a long scene (the reason the cost sheet always gates first use).
        XCTAssertGreaterThan(StorytellerEngine.estimatedCost(scriptCharacters: 4000),
                             0.04)
    }

    // MARK: - Cache key

    func testCacheKeyIsStableAndSensitiveToEveryInput() {
        let a = StorytellerEngine.cacheKey(scriptText: "Scene text", emotion: "calm")
        let b = StorytellerEngine.cacheKey(scriptText: "Scene text", emotion: "calm")
        XCTAssertEqual(a, b, "same inputs → same key (cache hits survive relaunch)")
        XCTAssertEqual(a.count, 64, "sha256 hex")

        XCTAssertNotEqual(a, StorytellerEngine.cacheKey(scriptText: "Scene text.",
                                                        emotion: "calm"))
        XCTAssertNotEqual(a, StorytellerEngine.cacheKey(scriptText: "Scene text",
                                                        emotion: "tense"))
        XCTAssertNotEqual(a, StorytellerEngine.cacheKey(scriptText: "Scene text",
                                                        emotion: "calm",
                                                        promptVersion: "v999"),
                          "prompt-version bumps deliberately invalidate caches")
    }

    // MARK: - No network before confirm

    func testPrepareNeverTouchesTheGenerationSeams() {
        let engine = makeEngine(transcripts: ["should never be requested"])

        engine.prepare(project: Self.makeFixtureProject())

        XCTAssertEqual(engine.chunks.count, 2)
        XCTAssertTrue(engine.chunks.allSatisfy { $0.state == .pending })
        XCTAssertGreaterThan(engine.totalEstimatedCost, 0,
                             "the estimate exists before any call")
        XCTAssertEqual(transformCalls.count, 0,
                       "prepare() must not spend — the cost sheet gates generation")
        XCTAssertEqual(speechTexts.count, 0)
    }

    // MARK: - PREVIOUSLY threading + cache round-trip

    func testGenerationThreadsPreviouslyStripsMarkerAndCaches() async throws {
        // One fixture instance: cache filenames embed the persistent
        // project/scene UUIDs, so the same document must be reused.
        let project = Self.makeFixtureProject()
        let engine = makeEngine(transcripts: [
            "Night settles over the kitchen.\nNEXT-PREVIOUSLY: Mara fled with the key.",
            "It ends where it began.\nNEXT-PREVIOUSLY: The story is told.",
        ])

        engine.prepare(project: project)
        await engine.runGeneration()

        // Prompt threading: chunk 1 opens the story; chunk 2 receives
        // chunk 1's NEXT-PREVIOUSLY line.
        XCTAssertEqual(transformCalls.count, 2)
        XCTAssertEqual(transformCalls[0].system, StorytellerPrompt.systemPrompt)
        XCTAssertTrue(transformCalls[0].user.hasPrefix(
            "PREVIOUSLY: \(StorytellerEngine.openingPreviously)"))
        XCTAssertTrue(transformCalls[0].user.contains("SCENE:\nINT. KITCHEN - NIGHT"))
        XCTAssertTrue(transformCalls[1].user.hasPrefix(
            "PREVIOUSLY: Mara fled with the key."))

        // The marker never reaches TTS.
        XCTAssertEqual(speechTexts, ["Night settles over the kitchen.",
                                     "It ends where it began."])

        // Ready chunks carry REAL measured durations (1.0 s of wrapped PCM)
        // and zero remaining cost.
        for chunk in engine.chunks {
            XCTAssertEqual(chunk.state, .ready)
            XCTAssertEqual(chunk.duration, 1.0, accuracy: 0.05)
            XCTAssertEqual(chunk.estimatedCost, 0)
            XCTAssertNotNil(chunk.audioURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: chunk.audioURL!.path))
        }
        XCTAssertEqual(engine.chunkStartOffset(at: 1), 1.0, accuracy: 0.05)
        XCTAssertEqual(engine.storyDuration, 2.0, accuracy: 0.1)

        // Second engine over the same cache: everything cached, $0, and a
        // full generation pass makes ZERO seam calls.
        transformCalls = []
        speechTexts = []
        let engine2 = makeEngine(transcripts: [])
        engine2.prepare(project: project)
        XCTAssertTrue(engine2.chunks.allSatisfy { $0.state == .cached })
        XCTAssertEqual(engine2.totalEstimatedCost, 0)
        XCTAssertEqual(engine2.chunks[0].narrationText,
                       "Night settles over the kitchen.", "sidecar round-trips")
        XCTAssertEqual(engine2.chunks[0].previouslyLine, "Mara fled with the key.")
        XCTAssertEqual(engine2.chunks[0].duration, 1.0, accuracy: 0.05)

        await engine2.runGeneration()
        XCTAssertEqual(transformCalls.count, 0, "cached chunks skip the network")
        XCTAssertEqual(speechTexts.count, 0)
    }

    func testMissingNextPreviouslyFallsBackToClosingSentence() async throws {
        let engine = makeEngine(transcripts: [
            "The kitchen holds its breath. Mara turns the key.",
            "Done.\nNEXT-PREVIOUSLY: Over.",
        ])

        engine.prepare(project: Self.makeFixtureProject())
        await engine.runGeneration()

        XCTAssertTrue(transformCalls[1].user.hasPrefix("PREVIOUSLY: Mara turns the key"),
                      "without the marker, the closing sentence carries the story")
    }

    func testFailureStopsTheChainAndClearCacheResetsEstimates() async throws {
        struct Boom: Error {}
        let engine = StorytellerEngine(
            transformText: { _, _ in throw Boom() },
            synthesizeSpeech: { [weak self] request in
                await MainActor.run { self?.speechTexts.append(request.text) }
                return Self.oneSecondWAV()
            },
            cacheRoot: tempDir)

        engine.prepare(project: Self.makeFixtureProject())
        await engine.runGeneration()

        guard case .failed = engine.chunks[0].state else {
            return XCTFail("chunk 1 should be failed, got \(engine.chunks[0].state)")
        }
        XCTAssertEqual(engine.chunks[1].state, .pending,
                       "a broken PREVIOUSLY chain stops — later chunks stay pending")
        XCTAssertEqual(speechTexts.count, 0)
        XCTAssertNotNil(engine.lastError)

        // Clear-cache affordance: everything back to pending with fresh estimates.
        engine.clearCache()
        XCTAssertTrue(engine.chunks.allSatisfy { $0.state == .pending })
        XCTAssertGreaterThan(engine.totalEstimatedCost, 0)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent(engine.projectUUID).path))
    }

    // MARK: - Narration parsing

    func testParseNarrationStripsMarkerAnywhereAndTrims() {
        let (n1, p1) = StorytellerEngine.parseNarration(
            "Line one.\nLine two.\nNEXT-PREVIOUSLY: Carried forward.")
        XCTAssertEqual(n1, "Line one.\nLine two.")
        XCTAssertEqual(p1, "Carried forward.")

        let (n2, p2) = StorytellerEngine.parseNarration("Just narration.")
        XCTAssertEqual(n2, "Just narration.")
        XCTAssertEqual(p2, "")

        let (n3, p3) = StorytellerEngine.parseNarration(
            "  next-previously: lowercase still stripped\nBody.")
        XCTAssertEqual(n3, "Body.")
        XCTAssertEqual(p3, "lowercase still stripped")
    }
}

// MARK: - Playhead + slideshow mapping (pure math)

final class StorytellerMappingTests: XCTestCase {

    func testTimelineTimeMapsNarrationProgressOntoSceneSpan() {
        // Scene spans 10…40 on the timeline; narration is 20 s long.
        XCTAssertEqual(StorytellerMapping.timelineTime(
            narrationTime: 0, narrationDuration: 20, sceneStart: 10, sceneEnd: 40), 10)
        XCTAssertEqual(StorytellerMapping.timelineTime(
            narrationTime: 10, narrationDuration: 20, sceneStart: 10, sceneEnd: 40), 25)
        XCTAssertEqual(StorytellerMapping.timelineTime(
            narrationTime: 20, narrationDuration: 20, sceneStart: 10, sceneEnd: 40), 40)
        // Clamped: audio clock past the measured duration can't overshoot.
        XCTAssertEqual(StorytellerMapping.timelineTime(
            narrationTime: 25, narrationDuration: 20, sceneStart: 10, sceneEnd: 40), 40)
        // Degenerate inputs park at the scene start.
        XCTAssertEqual(StorytellerMapping.timelineTime(
            narrationTime: 5, narrationDuration: 0, sceneStart: 10, sceneEnd: 40), 10)
    }

    func testBuildSlidesOverviewGetsThePreFirstShotSpan() {
        let slides = StorytellerMapping.buildSlides(
            sceneStart: 0, sceneEnd: 30,
            overviewImagePath: "overview.png",
            shots: [(imagePath: "shot1.png", startTime: 10),
                    (imagePath: "shot2.png", startTime: 20)])
        XCTAssertEqual(slides, [
            StorytellerSlide(imagePath: "overview.png", start: 0, end: 10),
            StorytellerSlide(imagePath: "shot1.png", start: 10, end: 20),
            StorytellerSlide(imagePath: "shot2.png", start: 20, end: 30),
        ])
    }

    func testBuildSlidesNoGapSplitsTheFirstShotWindow() {
        // First shot starts at the scene start — the overview still leads,
        // the colliding shot is pushed to the midpoint of its window.
        let slides = StorytellerMapping.buildSlides(
            sceneStart: 0, sceneEnd: 20,
            overviewImagePath: "overview.png",
            shots: [(imagePath: "shot1.png", startTime: 0),
                    (imagePath: "shot2.png", startTime: 10)])
        XCTAssertEqual(slides.count, 3)
        XCTAssertEqual(slides[0].imagePath, "overview.png")
        XCTAssertEqual(slides[0].start, 0)
        XCTAssertEqual(slides[1], StorytellerSlide(imagePath: "shot1.png",
                                                   start: 5, end: 10))
        XCTAssertEqual(slides[2], StorytellerSlide(imagePath: "shot2.png",
                                                   start: 10, end: 20))
    }

    func testBuildSlidesSkipsMissingImagesAndAbsorbsTheirSpans() {
        let slides = StorytellerMapping.buildSlides(
            sceneStart: 0, sceneEnd: 30,
            overviewImagePath: nil,
            shots: [(imagePath: "shot1.png", startTime: 0),
                    (imagePath: nil, startTime: 10),        // no still → skipped
                    (imagePath: "shot3.png", startTime: 20)])
        XCTAssertEqual(slides, [
            StorytellerSlide(imagePath: "shot1.png", start: 0, end: 20),
            StorytellerSlide(imagePath: "shot3.png", start: 20, end: 30),
        ], "the missing shot's window folds into the previous slide")
    }

    func testBuildSlidesEdgeCases() {
        XCTAssertTrue(StorytellerMapping.buildSlides(
            sceneStart: 0, sceneEnd: 10, overviewImagePath: nil, shots: []).isEmpty)
        XCTAssertTrue(StorytellerMapping.buildSlides(
            sceneStart: 10, sceneEnd: 10, overviewImagePath: "o.png",
            shots: []).isEmpty, "zero-width scenes have no slides")
        // Overview only: covers the whole scene.
        XCTAssertEqual(StorytellerMapping.buildSlides(
            sceneStart: 5, sceneEnd: 15, overviewImagePath: "o.png", shots: []),
            [StorytellerSlide(imagePath: "o.png", start: 5, end: 15)])
    }

    func testSlideIndexSelectsTheActiveWindow() {
        let slides = [
            StorytellerSlide(imagePath: "a.png", start: 0, end: 10),
            StorytellerSlide(imagePath: "b.png", start: 10, end: 20),
            StorytellerSlide(imagePath: "c.png", start: 20, end: 30),
        ]
        XCTAssertEqual(StorytellerMapping.slideIndex(at: 0, in: slides), 0)
        XCTAssertEqual(StorytellerMapping.slideIndex(at: 9.9, in: slides), 0)
        XCTAssertEqual(StorytellerMapping.slideIndex(at: 10, in: slides), 1)
        XCTAssertEqual(StorytellerMapping.slideIndex(at: 25, in: slides), 2)
        XCTAssertEqual(StorytellerMapping.slideIndex(at: 99, in: slides), 2,
                       "past the end holds the last frame")
        XCTAssertNil(StorytellerMapping.slideIndex(at: 5, in: []))
    }
}
