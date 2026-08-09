// DirectorsChairCoreTests/DailiesIngestTests.swift
//
// Watch-folder dailies (§2.18). The promises: the filename convention
// reads the way sets actually name clips, matching REFUSES rather than
// guesses (a misfiled take is worse than an unsorted one), locked
// production numbers are what "S22A" means after a lock, and the
// watcher only delivers files that have stopped growing — once.

import XCTest
@testable import DirectorsChairCore

final class DailiesIngestTests: XCTestCase {

    // MARK: - Filename convention

    func testParseReadsTheSetConventions() {
        XCTAssertEqual(DailiesIngest.parse(fileName: "S22_T03.mov"),
                       .init(sceneNumber: "22", takeNumber: 3))
        XCTAssertEqual(DailiesIngest.parse(fileName: "s22a-t3.mp4"),
                       .init(sceneNumber: "22A", takeNumber: 3))
        XCTAssertEqual(DailiesIngest.parse(fileName: "SC22_SH04_T03.mov"),
                       .init(sceneNumber: "22", shotNumber: 4, takeNumber: 3))
        XCTAssertEqual(DailiesIngest.parse(fileName: "Scene 22 Shot 4 Take 3.mov"),
                       .init(sceneNumber: "22", shotNumber: 4, takeNumber: 3))
        XCTAssertEqual(DailiesIngest.parse(fileName: "scene22_take3.mkv"),
                       .init(sceneNumber: "22", takeNumber: 3))
        XCTAssertEqual(DailiesIngest.parse(fileName: "A001_S07.mov"),
                       .init(sceneNumber: "7"),
                       "a scene token alone is still a scene match")
    }

    func testParseRefusesNamesWithoutASceneToken() {
        XCTAssertNil(DailiesIngest.parse(fileName: "C0575.mov"),
                     "a bare camera clip name says nothing about scenes")
        XCTAssertNil(DailiesIngest.parse(fileName: "IMG_4021.mov"))
        XCTAssertNil(DailiesIngest.parse(fileName: "sunset test.mov"),
                     "'s' inside a word is not a scene token")
    }

    // MARK: - Destination

    private func makeProject() -> Project {
        var sceneOne = Scene(name: "Scene 7")
        sceneOne.shots = [Shot(shotId: 4), Shot(shotId: 5)]
        var sceneTwo = Scene(name: "Opening")
        sceneTwo.lockedNumber = "22A"
        sceneTwo.shots = [Shot(shotId: 9)]
        var project = Project(name: "Dailies")
        project.sequences = [Sequence(name: "Act 1",
                                      scenes: [sceneOne, sceneTwo])]
        return project
    }

    func testDestinationPrefersLockedNumbersThenNames() {
        let project = makeProject()

        let byLocked = DailiesIngest.destination(
            for: .init(sceneNumber: "22A"), in: project)
        XCTAssertEqual(byLocked,
                       .init(sequenceIndex: 0, sceneIndex: 1, shotIndex: 0),
                       "after a lock, the slate number IS the locked "
                       + "number — and a single-shot scene needs no shot "
                       + "token")

        let byName = DailiesIngest.destination(
            for: .init(sceneNumber: "7", shotNumber: 5), in: project)
        XCTAssertEqual(byName,
                       .init(sequenceIndex: 0, sceneIndex: 0, shotIndex: 1))
    }

    func testDestinationRefusesRatherThanGuesses() {
        let project = makeProject()
        XCTAssertNil(DailiesIngest.destination(
            for: .init(sceneNumber: "7"), in: project),
            "two shots and no shot token — a human files it")
        XCTAssertNil(DailiesIngest.destination(
            for: .init(sceneNumber: "7", shotNumber: 99), in: project),
            "naming a shot the scene doesn't have is a refusal")
        XCTAssertNil(DailiesIngest.destination(
            for: .init(sceneNumber: "44"), in: project))
    }

    // MARK: - Dedupe and take construction

    func testIngestedClipsAreRememberedByTheirCameraName() {
        var project = makeProject()
        var take = Take(takeNumber: 1)
        take.cameraSourceFileName = "S22A_T01.mov"
        project.sequences[0].scenes[1].shots[0].takes = [take]

        XCTAssertTrue(DailiesIngest.alreadyIngested(
            fileName: "S22A_T01.mov", in: project),
            "relaunching must not re-ingest yesterday's cards")
        XCTAssertFalse(DailiesIngest.alreadyIngested(
            fileName: "S22A_T02.mov", in: project))
    }

    func testMakeTakeNumbersFromTheSlateElseAfterExisting() {
        let slated = DailiesIngest.makeTake(
            fileName: "S22_T07.mov", relativeVideoPath: "footage/x.mov",
            match: .init(sceneNumber: "22", takeNumber: 7),
            existingTakes: [Take(takeNumber: 2)])
        XCTAssertEqual(slated.takeNumber, 7,
                       "the slate outranks local numbering")
        XCTAssertEqual(slated.cameraSourceFileName, "S22_T07.mov")
        XCTAssertEqual(slated.capturedVideoPath, "footage/x.mov")
        XCTAssertTrue(slated.useAudioFromVideo)

        let unslated = DailiesIngest.makeTake(
            fileName: "S22.mov", relativeVideoPath: "footage/y.mov",
            match: .init(sceneNumber: "22"),
            existingTakes: [Take(takeNumber: 2), Take(takeNumber: 5)])
        XCTAssertEqual(unslated.takeNumber, 6,
                       "no slate number — file after the shot's takes")
    }

    // MARK: - The watcher

    func testWatcherDeliversAFileOnceItStopsGrowingAndOnlyOnce() {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailiesWatcherTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let watcher = DailiesWatcher(pollInterval: 0.1)
        var deliveries: [String] = []
        let delivered = expectation(description: "file delivered")
        watcher.onFileReady = { url in
            deliveries.append(url.lastPathComponent)
            delivered.fulfill()
        }
        watcher.start(folder: temp)

        // Simulate a copy in progress: grow the file across two polls,
        // then let it settle.
        let clip = temp.appendingPathComponent("S22_T01.mov")
        try? Data(repeating: 1, count: 100).write(to: clip)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            try? Data(repeating: 1, count: 500).write(to: clip)
        }

        wait(for: [delivered], timeout: 5)
        XCTAssertEqual(deliveries, ["S22_T01.mov"])

        // A non-video file and a dotfile never deliver; the clip never
        // delivers twice.
        try? Data(repeating: 2, count: 10).write(
            to: temp.appendingPathComponent("notes.txt"))
        try? Data(repeating: 2, count: 10).write(
            to: temp.appendingPathComponent(".DS_Store"))
        let quiet = expectation(description: "no further deliveries")
        quiet.isInverted = true
        watcher.onFileReady = { _ in quiet.fulfill() }
        wait(for: [quiet], timeout: 0.6)
        watcher.stop()
        XCTAssertFalse(watcher.isWatching)
    }
}
