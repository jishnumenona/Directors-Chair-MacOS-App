// DirectorsChair-DesktopTests/StorytellerModeTests.swift
//
// Storyteller as a first-class MODE of PlaybackViewModel:
// - the storyteller-timed playlist builder (pure): scene span == narration
//   span, proportional shot sub-spans, pending-chunk boundaries, and
//   restoration of the normal playlist on exit;
// - clock uniformity: the tick READS the narration player (mocked here) —
//   1 s of audio is exactly 1 s of currentTime, never dt integration;
// - transport routing: play/seek during the mode never reaches the normal
//   dialogue/soundtrack engines (asserted via seams);
// - sidebar-driving: currentItem / linked script items / currentScene
//   resolve at a storyteller time through the NORMAL view-model paths;
// - the per-scene linear story ↔ edit-timeline mapping (and its inverse).

import XCTest
import AVFoundation
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

// MARK: - Seams

/// Records normal-engine transport calls; storyteller-mode playback must
/// NEVER reach any of them.
@MainActor
private final class SpyPlaybackAudioEngine: PlaybackAudioEngine {
    private(set) var resumeCalls = 0
    private(set) var soundtrackResumeCalls = 0
    private(set) var syncCalls = 0
    private(set) var seekCalls = 0

    override func resumeAll(speed: Double) { resumeCalls += 1 }
    override func resumeAllSoundtracks(speed: Double) { soundtrackResumeCalls += 1 }
    override func syncAudio(to currentTime: CGFloat, speed: Double, volume: Double,
                            mutedCharacters: Set<String>) { syncCalls += 1 }
    override func syncSoundtracks(to currentTime: CGFloat, speed: Double,
                                  volume: Double) { syncCalls += 1 }
    override func seek(to currentTime: CGFloat, speed: Double, volume: Double) {
        seekCalls += 1
    }
    override func seekSoundtracks(to currentTime: CGFloat, speed: Double,
                                  volume: Double) { seekCalls += 1 }
}

/// Narration player with a scriptable master clock; transport calls are
/// recorded instead of touching AVAudioPlayer.
@MainActor
private final class MockNarrationPlayer: StorytellerNarrationPlayer {
    var mockTime: TimeInterval = 0
    private(set) var playCalls = 0
    private(set) var pauseCalls = 0
    private(set) var storySeeks: [TimeInterval] = []

    override var narrationTime: TimeInterval { mockTime }
    override func play() { playCalls += 1 }
    override func pause() { pauseCalls += 1 }
    override func seek(toStoryTime time: TimeInterval) { storySeeks.append(time) }
    override func refreshVolume() {}
}

// MARK: - Tests

@MainActor
final class StorytellerModeTests: XCTestCase {

    private var tempDir: URL!
    private var transcriptQueue: [String] = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-storyteller-mode-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir,
                                                 withIntermediateDirectories: true)
        transcriptQueue = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: Fixtures

    /// Three scenes: "Opening" (two dialogues, two linked shots), an empty
    /// interlude (no chunk — skipped on the story clock), and "Finale"
    /// (one narration, one shot). Mirrors the engine-test fixture but with
    /// shots so the retimed playlist and sidebar resolution are exercised.
    private func makeProject() -> (project: Project, maraId: String, ilyaId: String) {
        let mara = Dialogue(character: "Mara", text: "Run. Now.", chronologyNumber: 1)
        let ilya = Dialogue(character: "Ilya", text: "Where?", chronologyNumber: 2)
        let opening = Scene(
            name: "Opening",
            description: "Rain hammers the skylight.",
            dialogues: [mara, ilya],
            shots: [
                Shot(shotId: 1, previewImage: "shots/1.png",
                     linkedDialogueIds: [mara.id]),
                Shot(shotId: 2, previewImage: "shots/2.png",
                     linkedDialogueIds: [ilya.id]),
            ],
            location: "INT. KITCHEN - NIGHT",
            timeOfDay: "Night")
        let interlude = Scene(name: "Empty Interlude")
        let narration = Narration(text: "It began with rain.", chronologyNumber: 1)
        let finale = Scene(
            name: "Finale",
            narrations: [narration],
            shots: [Shot(shotId: 3, linkedNarrationIds: [narration.id])])
        var project = Project(name: "Storyteller Mode Fixture")
        project.sequences = [Sequence(name: "Act 1",
                                      scenes: [opening, interlude, finale])]
        project.characters = [Character(name: "Mara"), Character(name: "Ilya")]
        return (project, mara.id, ilya.id)
    }

    /// 24 kHz 16-bit mono PCM wrapped to a decodable WAV — exactly 1.0 s,
    /// so retimed spans are asserted against REAL measured durations.
    private nonisolated static func oneSecondWAV() -> Data {
        PCMWAVWrapper.wrapIfNeeded(Data(count: 48_000))
    }

    /// Engine whose seams never touch the network: pending-only unless
    /// transcripts are queued for an offline generation pass.
    private func makeEngine(transcripts: [String] = []) -> StorytellerEngine {
        transcriptQueue = transcripts
        return StorytellerEngine(
            transformText: { [weak self] _, _ in
                await MainActor.run {
                    guard let self, !self.transcriptQueue.isEmpty else { return "" }
                    return self.transcriptQueue.removeFirst()
                }
            },
            synthesizeSpeech: { _ in Self.oneSecondWAV() },
            cacheRoot: tempDir)
    }

    private func makeItem(shotId: Int, scene: String, sceneIndex: Int,
                          start: CGFloat, duration: CGFloat,
                          linkedDialogueIds: [String] = []) -> PlaybackItem {
        PlaybackItem(id: UUID(), shotId: shotId, sceneName: scene,
                     sequenceName: "Act 1", startTime: start, duration: duration,
                     previewImagePath: nil, videoPath: nil, shotType: "Standard",
                     cameraAngle: "Medium", lensMm: 50, movement: "Static",
                     description: "", linkedDialogueIds: linkedDialogueIds,
                     linkedActionIds: [], linkedNarrationIds: [], shot: nil,
                     sceneIndex: sceneIndex)
    }

    /// Fully wired mode view model: spy normal engine + the given narration
    /// player, normal playlist built from the fixture.
    private func makeModeViewModel(narration: StorytellerNarrationPlayer,
                                   project: Project)
    -> (vm: PlaybackViewModel, spy: SpyPlaybackAudioEngine) {
        let vm = PlaybackViewModel(narrationPlayer: narration)
        let spy = SpyPlaybackAudioEngine()
        vm.audioEngine = spy
        vm.buildPlaylist(from: project, basePath: nil)
        return (vm, spy)
    }

    // MARK: - Retime (pure playlist builder)

    func testRetimeGivesScenesNarrationSpansAndShotsProportionalSubSpans() {
        // Edit timeline: scene A [0,20) with two 10 s shots, scene B [20,30)
        // (no chunk — nothing to narrate), scene C [30,40) with one shot.
        let normalItems = [
            makeItem(shotId: 1, scene: "A", sceneIndex: 0, start: 0, duration: 10,
                     linkedDialogueIds: ["d1"]),
            makeItem(shotId: 2, scene: "A", sceneIndex: 0, start: 10, duration: 10),
            makeItem(shotId: 3, scene: "C", sceneIndex: 2, start: 30, duration: 10),
        ]
        let boundaries = [SceneBoundary(time: 0, name: "A"),
                          SceneBoundary(time: 20, name: "B"),
                          SceneBoundary(time: 30, name: "C")]

        let retimed = StorytellerTimeline.retime(
            normalItems: normalItems, normalBoundaries: boundaries,
            normalTotalDuration: 40,
            chunkSpans: [(sceneIndex: 0, duration: 8), (sceneIndex: 2, duration: 4)])

        // totalDuration == total narration time; boundaries == chunk starts.
        XCTAssertEqual(retimed.totalDuration, 12)
        XCTAssertEqual(retimed.boundaries.map(\.time), [0, 8])
        XCTAssertEqual(retimed.boundaries.map(\.name), ["A", "C"],
                       "the chunk-less scene contributes no boundary")

        // Proportional sub-spans: shot fractions of the scene are kept.
        XCTAssertEqual(retimed.items.map(\.startTime), [0, 4, 8])
        XCTAssertEqual(retimed.items.map(\.duration), [4, 4, 4])

        // Metadata rides along untouched — the sidebar cards key off it.
        XCTAssertEqual(retimed.items[0].id, normalItems[0].id)
        XCTAssertEqual(retimed.items[0].linkedDialogueIds, ["d1"])
        XCTAssertEqual(retimed.items[2].sceneIndex, 2)

        // Scene maps carry both clocks for the per-scene linear mapping.
        XCTAssertEqual(retimed.sceneMaps, [
            StorytellerTimeline.SceneMap(sceneIndex: 0, storyStart: 0, storyEnd: 8,
                                         editStart: 0, editEnd: 20),
            StorytellerTimeline.SceneMap(sceneIndex: 2, storyStart: 8, storyEnd: 12,
                                         editStart: 30, editEnd: 40),
        ])
    }

    func testRetimePendingChunksWaitAsZeroWidthBoundaries() {
        let normalItems = [
            makeItem(shotId: 1, scene: "A", sceneIndex: 0, start: 0, duration: 20),
            makeItem(shotId: 3, scene: "C", sceneIndex: 2, start: 30, duration: 10),
        ]
        let boundaries = [SceneBoundary(time: 0, name: "A"),
                          SceneBoundary(time: 20, name: "B"),
                          SceneBoundary(time: 30, name: "C")]

        let retimed = StorytellerTimeline.retime(
            normalItems: normalItems, normalBoundaries: boundaries,
            normalTotalDuration: 40,
            chunkSpans: [(sceneIndex: 0, duration: 8), (sceneIndex: 2, duration: 0)])

        XCTAssertEqual(retimed.totalDuration, 8, "ungenerated audio adds no time")
        XCTAssertEqual(retimed.boundaries.map(\.time), [0, 8],
                       "the pending scene still marks its boundary (waiting point)")
        XCTAssertEqual(retimed.items.map(\.shotId), [1],
                       "no items until the pending chunk's audio lands")
        XCTAssertEqual(retimed.sceneMaps[1].storyStart, retimed.sceneMaps[1].storyEnd)

        // The waiting boundary resolves to the pending chunk, not past it.
        XCTAssertEqual(StorytellerTimeline.spanIndex(
            at: 8, spans: retimed.sceneMaps.map { ($0.storyStart, $0.storyEnd) }), 1)
    }

    // MARK: - Story ↔ edit-timeline mapping (per-scene linear)

    func testEditTimeMapsStoryTimeLinearlyPerScene() {
        let maps = [
            StorytellerTimeline.SceneMap(sceneIndex: 0, storyStart: 0, storyEnd: 8,
                                         editStart: 0, editEnd: 20),
            StorytellerTimeline.SceneMap(sceneIndex: 2, storyStart: 8, storyEnd: 12,
                                         editStart: 30, editEnd: 40),
        ]
        XCTAssertEqual(StorytellerTimeline.editTime(forStoryTime: 0, maps: maps), 0)
        XCTAssertEqual(StorytellerTimeline.editTime(forStoryTime: 4, maps: maps), 10,
                       "midway through the narration is midway through the WPM scene")
        XCTAssertEqual(StorytellerTimeline.editTime(forStoryTime: 8, maps: maps), 30,
                       "scene boundaries jump the skipped chunk-less scene")
        XCTAssertEqual(StorytellerTimeline.editTime(forStoryTime: 10, maps: maps), 35)
        XCTAssertEqual(StorytellerTimeline.editTime(forStoryTime: 99, maps: maps), 40,
                       "past the end parks at the last scene's edit end")

        // A pending (zero-width) scene parks the playhead at its edit start.
        let pending = [
            StorytellerTimeline.SceneMap(sceneIndex: 0, storyStart: 0, storyEnd: 8,
                                         editStart: 0, editEnd: 20),
            StorytellerTimeline.SceneMap(sceneIndex: 2, storyStart: 8, storyEnd: 8,
                                         editStart: 30, editEnd: 40),
        ]
        XCTAssertEqual(StorytellerTimeline.editTime(forStoryTime: 8, maps: pending), 30)
    }

    func testStoryTimeIsTheInverseMappingAndSnapsUnnarratedGaps() {
        let maps = [
            StorytellerTimeline.SceneMap(sceneIndex: 0, storyStart: 0, storyEnd: 8,
                                         editStart: 0, editEnd: 20),
            StorytellerTimeline.SceneMap(sceneIndex: 2, storyStart: 8, storyEnd: 12,
                                         editStart: 30, editEnd: 40),
        ]
        XCTAssertEqual(StorytellerTimeline.storyTime(forEditTime: 0, maps: maps), 0)
        XCTAssertEqual(StorytellerTimeline.storyTime(forEditTime: 10, maps: maps), 4)
        XCTAssertEqual(StorytellerTimeline.storyTime(forEditTime: 35, maps: maps), 10)
        XCTAssertEqual(StorytellerTimeline.storyTime(forEditTime: 25, maps: maps), 8,
                       "an edit time inside the skipped scene snaps to the next chunk")
    }

    // MARK: - Clock uniformity (the tick READS the narration player)

    func testStorytellerClockFollowsTheNarrationPlayerOneToOne() {
        let (project, _, _) = makeProject()
        let mock = MockNarrationPlayer(engine: makeEngine())
        let (vm, _) = makeModeViewModel(narration: mock, project: project)

        vm.enterStorytellerMode()
        XCTAssertTrue(vm.storytellerActive)
        vm.play()

        for expected in [0.25, 0.5, 1.0, 2.5, 2.6] {
            mock.mockTime = expected
            // currentTime is throttled to every 5th frame; 5 ticks always
            // cross one publish. The value must equal the AUDIO clock
            // exactly — dt integration would accumulate 5/60 s per burst.
            for _ in 0..<5 { vm.performTick() }
            XCTAssertEqual(vm.currentTime, CGFloat(expected), accuracy: 1e-9,
                           "1 s of narration audio == 1 s of playhead")
        }
    }

    // MARK: - Transport routing (normal engines stay silent)

    func testStorytellerTransportNeverTouchesTheNormalEngines() {
        let (project, _, _) = makeProject()
        let mock = MockNarrationPlayer(engine: makeEngine())
        let (vm, spy) = makeModeViewModel(narration: mock, project: project)

        vm.enterStorytellerMode()
        vm.play()
        XCTAssertEqual(mock.playCalls, 1, "play routes to the narration")
        XCTAssertEqual(vm.storytellerPlayArmRequests, 1,
                       "ungenerated chunks arm the cost gate")
        for _ in 0..<20 { vm.performTick() }
        vm.seekTo(time: 0.5)
        XCTAssertFalse(mock.storySeeks.isEmpty, "scrubbing routes to the narration")
        vm.pause()
        XCTAssertEqual(mock.pauseCalls, 1)

        XCTAssertEqual(spy.resumeCalls, 0,
                       "the normal dialogue engine never starts in storyteller mode")
        XCTAssertEqual(spy.soundtrackResumeCalls, 0)
        XCTAssertEqual(spy.syncCalls, 0)
        XCTAssertEqual(spy.seekCalls, 0)

        // After exit the normal transport is whole again.
        vm.exitStorytellerMode()
        vm.play()
        XCTAssertEqual(spy.resumeCalls, 1)
        XCTAssertEqual(mock.playCalls, 1, "the narration stays parked in normal mode")
    }

    // MARK: - Sidebar driving (current item at a storyteller time)

    func testSidebarStateTracksTheNarratedShotAtAStorytellerTime() async throws {
        let (project, _, ilyaId) = makeProject()
        let engine = makeEngine(transcripts: [
            "Night settles over the kitchen.\nNEXT-PREVIOUSLY: Mara fled.",
            "It ends where it began.\nNEXT-PREVIOUSLY: Told.",
        ])
        let narration = StorytellerNarrationPlayer(engine: engine)
        narration.volumeProvider = { 0 }
        let (vm, spy) = makeModeViewModel(narration: narration, project: project)

        engine.prepare(project: project)
        await engine.runGeneration()   // both scenes → REAL 1.0 s WAVs
        vm.enterStorytellerMode()

        // Story clock: Opening 0…1 (two shots), Finale 1…2 (one shot).
        XCTAssertEqual(vm.totalDuration, 2.0, accuracy: 0.1)

        vm.seekTo(time: 0.99)
        XCTAssertEqual(vm.currentItem?.shotId, 2)
        XCTAssertEqual(vm.currentScene?.name, "Opening")
        XCTAssertEqual(vm.currentLinkedDialogues.map(\.id), [ilyaId],
                       "the Script card resolves the narrated shot's linked lines")

        vm.seekTo(time: 1.5)
        XCTAssertEqual(vm.currentItem?.shotId, 3)
        XCTAssertEqual(vm.currentSceneName, "Finale")
        XCTAssertEqual(vm.currentLinkedNarrations.count, 1)

        XCTAssertEqual(spy.seekCalls, 0,
                       "sidebar-driving seeks never touch the dialogue engine")
    }

    func testSceneSkipsSnapToChunkBoundaries() async throws {
        let (project, _, _) = makeProject()
        let engine = makeEngine(transcripts: ["Opening told.", "Finale told."])
        let narration = StorytellerNarrationPlayer(engine: engine)
        narration.volumeProvider = { 0 }
        let (vm, _) = makeModeViewModel(narration: narration, project: project)

        engine.prepare(project: project)
        await engine.runGeneration()
        vm.enterStorytellerMode()

        vm.seekTo(time: 0.2)
        vm.skipToNextScene()
        XCTAssertEqual(vm.currentTime, 1.0, accuracy: 0.01,
                       "next scene == next chunk boundary on the story clock")
        XCTAssertEqual(vm.currentSceneName, "Finale")

        // At the chunk's very start (< 1 s in): previous-scene snaps to the
        // PREVIOUS chunk boundary (standard transport convention).
        vm.skipToPreviousScene()
        XCTAssertEqual(vm.currentTime, 0.0, accuracy: 0.01)
        XCTAssertEqual(vm.currentSceneName, "Opening")
    }

    // MARK: - Restoration

    func testExitRestoresTheNormalPlaylistIntact() async throws {
        let (project, _, _) = makeProject()
        let engine = makeEngine(transcripts: ["Opening told.", "Finale told."])
        let narration = StorytellerNarrationPlayer(engine: engine)
        narration.volumeProvider = { 0 }
        let (vm, _) = makeModeViewModel(narration: narration, project: project)

        engine.prepare(project: project)
        await engine.runGeneration()

        let originalIds = vm.playlistItems.map(\.id)
        let originalStarts = vm.playlistItems.map(\.startTime)
        let originalDurations = vm.playlistItems.map(\.duration)
        let originalBoundaries = vm.sceneBoundaries.map(\.time)
        let originalTotal = vm.totalDuration

        vm.enterStorytellerMode()
        XCTAssertNotEqual(vm.totalDuration, originalTotal,
                          "the storyteller playlist runs on the narration clock")

        vm.exitStorytellerMode()
        XCTAssertFalse(vm.storytellerActive)
        XCTAssertEqual(vm.playlistItems.map(\.id), originalIds)
        XCTAssertEqual(vm.playlistItems.map(\.startTime), originalStarts)
        XCTAssertEqual(vm.playlistItems.map(\.duration), originalDurations)
        XCTAssertEqual(vm.sceneBoundaries.map(\.time), originalBoundaries)
        XCTAssertEqual(vm.totalDuration, originalTotal)
    }

    // MARK: - Waiting boundary auto-resume

    func testWaitingChunkAutoResumesWhenTheAudioLands() async throws {
        let (project, _, _) = makeProject()
        let engine = makeEngine(transcripts: ["Opening told.", "Finale told."])
        let narration = StorytellerNarrationPlayer(engine: engine)
        narration.volumeProvider = { 0 }

        engine.prepare(project: project)
        narration.play()   // chunk 0 has no audio yet
        XCTAssertTrue(narration.isWaitingForChunk,
                      "playback parks at the boundary with the waiting affordance")

        await engine.runGeneration()
        // The chunk observer delivers on the next main-queue turn.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(narration.isWaitingForChunk, "generation auto-resumes playback")
        XCTAssertEqual(narration.currentChunkIndex, 0)
        narration.pause()
    }
}
