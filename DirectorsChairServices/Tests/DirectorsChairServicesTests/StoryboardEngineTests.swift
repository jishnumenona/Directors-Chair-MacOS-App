// StoryboardEngineTests.swift
//
// DC-0063: the storyboard model manager's contract — locked style
// composition, disk preflight, marker-driven availability, and the
// core seam — all WITHOUT MLX or network (metallib/SPM rule; the real
// diffusion core is DC-0065's app-target concern).

import XCTest
@testable import DirectorsChairServices

final class StoryboardPromptStylerTests: XCTestCase {

    func testPromptCarriesLockedStyleMarkersAndSubject() {
        let prompt = StoryboardPromptStyler.prompt(
            subject: "Wide establishing shot: MAYA enters the abandoned station at dawn")
        for marker in StoryboardPromptStyler.requiredMarkers {
            XCTAssertTrue(prompt.lowercased().contains(marker),
                          "style marker '\(marker)' missing")
        }
        XCTAssertTrue(prompt.contains("MAYA enters the abandoned station"))
        XCTAssertTrue(prompt.contains("no color"), "monochrome lock missing")
    }

    func testPromptIncludesFramingNotesOnlyWhenPresent() {
        let with = StoryboardPromptStyler.prompt(subject: "Close-up on the letter",
                                                 notes: "low angle, 35mm")
        XCTAssertTrue(with.contains("FRAMING: low angle, 35mm"))
        let without = StoryboardPromptStyler.prompt(subject: "Close-up on the letter",
                                                    notes: "   ")
        XCTAssertFalse(without.contains("FRAMING:"))
    }

    func testOverlongSubjectIsCutFromTheEndNotTheFront() {
        let head = "OPENING FRAME: the important part."
        let long = head + String(repeating: " filler", count: 400)
        let prompt = StoryboardPromptStyler.prompt(subject: long)
        XCTAssertTrue(prompt.contains(head), "front of the subject must survive")
        XCTAssertTrue(prompt.contains("…"))
        XCTAssertLessThan(prompt.count,
                          StoryboardPromptStyler.subjectCharacterBudget + 600)
    }
}

final class StoryboardDiskPreflightTests: XCTestCase {

    func testRefusesWhenFreeSpaceBelowModelPlusHeadroom() {
        let model: Int64 = 5_916_000_000
        let error = ZImageStoryboardEngine.validateDiskSpace(
            freeBytes: 6_000_000_000, modelBytes: model)
        guard case .insufficientDisk(let needed, let free)? = error else {
            return XCTFail("expected insufficientDisk, got \(String(describing: error))")
        }
        XCTAssertEqual(needed, model + ZImageStoryboardEngine.downloadHeadroomBytes)
        XCTAssertEqual(free, 6_000_000_000)
    }

    func testAllowsWhenFreeSpaceCoversModelPlusHeadroom() {
        XCTAssertNil(ZImageStoryboardEngine.validateDiskSpace(
            freeBytes: 20_000_000_000, modelBytes: 5_916_000_000))
    }

    func testFreeDiskBytesReportsARealNumberEvenBeforeStorageExists() {
        let engine = ZImageStoryboardEngine(
            storageRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("dc-storyboard-nonexistent-\(UUID().uuidString)"))
        XCTAssertGreaterThan(engine.freeDiskBytes(), 0)
    }
}

final class ZImageStoryboardEngineTests: XCTestCase {

    private func makeEngine() -> (ZImageStoryboardEngine, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-storyboard-tests-\(UUID().uuidString)")
        return (ZImageStoryboardEngine(storageRoot: root), root)
    }

    private func writeMarker(in root: URL) throws {
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        let marker = root.appendingPathComponent(
            ".ready-\(ZImageStoryboardEngine.model.id.replacingOccurrences(of: "/", with: "_"))")
        try Data().write(to: marker)
    }

    func testFreshEngineNeedsDownloadWithHonestByteCount() async {
        let (engine, _) = makeEngine()
        let state = await engine.availability()
        #if arch(arm64)
        XCTAssertEqual(state, .needsDownload(
            expectedBytes: ZImageStoryboardEngine.model.approxBytes))
        #else
        guard case .unavailable = state else {
            return XCTFail("non-arm64 must be unavailable, got \(state)")
        }
        #endif
    }

    func testMarkerOnDiskReadsAsReady() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let state = await engine.availability()
        XCTAssertEqual(state, .ready)
        XCTAssertTrue(engine.isModelDownloaded())
        #endif
    }

    func testGenerateRefusesBeforeDownloadWithoutTouchingTheCore() async {
        let (engine, _) = makeEngine()
        do {
            _ = try await engine.generateFrame(.init(subject: "test frame"))
            XCTFail("must throw before the model is downloaded")
        } catch let error as StoryboardEngineError {
            guard case .notReady = error else {
                return XCTFail("expected notReady, got \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testGenerateRoutesStyledPromptAndDimensionsThroughTheCore() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let core = RecordingImageCore()
        let previous = ZImageStoryboardEngine.core
        ZImageStoryboardEngine.core = core
        defer { ZImageStoryboardEngine.core = previous }

        let data = try await engine.generateFrame(
            .init(subject: "Two-shot at the diner window", notes: "over-the-shoulder",
                  width: 640, height: 360, seed: 7))
        XCTAssertEqual(data, RecordingImageCore.pngStub)
        let call = try XCTUnwrap(core.calls.first)
        XCTAssertTrue(call.prompt.contains("ink sketch"))
        XCTAssertTrue(call.prompt.contains("Two-shot at the diner window"))
        XCTAssertTrue(call.prompt.contains("FRAMING: over-the-shoulder"))
        XCTAssertEqual(call.width, 640)
        XCTAssertEqual(call.height, 360)
        XCTAssertEqual(call.seed, 7)
        XCTAssertEqual(call.weightsDirectory,
                       root.appendingPathComponent("models", isDirectory: true)
                           .appendingPathComponent(ZImageStoryboardEngine.model.id,
                                                   isDirectory: true))
        #endif
    }

    func testGenerateWithoutCoreFailsHonestlyWhenReady() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let previous = ZImageStoryboardEngine.core
        ZImageStoryboardEngine.core = nil
        defer { ZImageStoryboardEngine.core = previous }
        do {
            _ = try await engine.generateFrame(.init(subject: "frame"))
            XCTFail("must throw without a core")
        } catch let error as StoryboardEngineError {
            guard case .generationFailed(let message) = error else {
                return XCTFail("expected generationFailed, got \(error)")
            }
            XCTAssertTrue(message.contains("core"))
        }
        #endif
    }
}

final class ScriptedStoryboardEngineTests: XCTestCase {

    func testScriptedEngineRecordsSpecsAndHonorsAvailability() async throws {
        let engine = ScriptedStoryboardEngine(
            availability: .needsDownload(expectedBytes: 42))
        do {
            _ = try await engine.generateFrame(.init(subject: "s"))
            XCTFail("not ready must throw")
        } catch let error as StoryboardEngineError {
            guard case .notReady(.needsDownload(42)) = error else {
                return XCTFail("wrong state: \(error)")
            }
        }
        try await engine.prepare()
        let data = try await engine.generateFrame(.init(subject: "after prepare"))
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(engine.preparations, 1)
        XCTAssertEqual(engine.requests.map(\.subject), ["s", "after prepare"])
    }
}

// MARK: - Recording core double

private final class RecordingImageCore: OnDeviceImageGenerating, @unchecked Sendable {
    static let pngStub = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    struct Call {
        let prompt: String
        let width: Int
        let height: Int
        let seed: UInt64?
        let weightsDirectory: URL
    }
    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] { lock.lock(); defer { lock.unlock() }; return _calls }

    func renderFrame(prompt: String, width: Int, height: Int,
                     seed: UInt64?, weightsDirectory: URL) async throws -> Data {
        lock.lock()
        _calls.append(Call(prompt: prompt, width: width, height: height,
                           seed: seed, weightsDirectory: weightsDirectory))
        lock.unlock()
        return Self.pngStub
    }
}

// MARK: - Subjects & persistence (DC-0064)

final class StoryboardSubjectsTests: XCTestCase {

    private func makeScene() -> Scene {
        var scene = Scene(name: "Kitchen Confrontation")
        scene.location = "INT. FARMHOUSE KITCHEN"
        scene.timeOfDay = "Night"
        scene.weather = "Storm"
        scene.sceneOverviewSummary = "Maya confronts her brother over the deed."
        return scene
    }

    func testShotSubjectLeadsWithDescriptionAndCarriesSetting() {
        var shot = Shot(shotId: 3)
        shot.description = "Maya slams the deed onto the table"
        let subject = StoryboardSubjects.subject(for: shot, in: makeScene())
        XCTAssertTrue(subject.hasPrefix("Maya slams the deed"), subject)
        XCTAssertTrue(subject.contains("FARMHOUSE KITCHEN"), subject)
        XCTAssertTrue(subject.contains("Night"), subject)
    }

    func testDescriptionlessShotFallsBackToSceneProse() {
        let shot = Shot(shotId: 4, description: "")
        let subject = StoryboardSubjects.subject(for: shot, in: makeScene())
        XCTAssertTrue(subject.contains("Maya confronts her brother"), subject)
    }

    func testCameraNotesReadAsDirectionAndOmitStatic() {
        var shot = Shot(shotId: 5)
        shot.shotType = "Close-up"
        shot.cameraAngle = "Low"
        shot.movement = "Static"
        shot.lensMm = 85
        let notes = try! XCTUnwrap(StoryboardSubjects.notes(for: shot))
        XCTAssertTrue(notes.contains("Close-up"))
        XCTAssertTrue(notes.contains("Low angle"))
        XCTAssertTrue(notes.contains("85mm lens"))
        XCTAssertFalse(notes.contains("Static"), "static camera is not direction")
    }

    func testSceneSubjectIsAnEstablishingFrameWithSlugFacts() {
        let subject = StoryboardSubjects.subject(for: makeScene())
        XCTAssertTrue(subject.hasPrefix("Establishing frame: Kitchen Confrontation"), subject)
        XCTAssertTrue(subject.contains("Storm"), subject)
        XCTAssertTrue(subject.contains("Maya confronts her brother"), subject)
    }

    func testEngineErrorsExplainThemselvesToUsers() {
        XCTAssertTrue(StoryboardEngineError
            .notReady(.needsDownload(expectedBytes: 1)).userMessage
            .contains("Settings"))
        let disk = StoryboardEngineError
            .insufficientDisk(neededBytes: 7_916_000_000, freeBytes: 8_000_000_000)
            .userMessage
        XCTAssertTrue(disk.contains("7.92 GB"), disk)
        XCTAssertTrue(disk.contains("8 GB"), disk)
    }
}

final class StoryboardFrameStoreTests: XCTestCase {

    func testSaveWritesTimestampedPlusLatestAndReturnsRelativePaths() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-framestore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let stamp = Date(timeIntervalSince1970: 1_756_000_000)

        let saved = try StoryboardFrameStore.save(
            png: png, projectBasePath: base,
            relativeDirectory: "assets/shots/shot_7", timestamp: stamp)

        XCTAssertEqual(saved.relativePath, "assets/shots/shot_7/storyboard_latest.png")
        XCTAssertTrue(saved.timestampedRelativePath.hasPrefix("assets/shots/shot_7/storyboard_2025"))
        for relative in [saved.relativePath, saved.timestampedRelativePath] {
            let url = base.appendingPathComponent(relative)
            XCTAssertEqual(try Data(contentsOf: url), png, relative)
        }
    }

    func testSecondSaveReplacesLatestButKeepsHistory() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-framestore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let first = try StoryboardFrameStore.save(
            png: Data([1]), projectBasePath: base,
            relativeDirectory: "assets/scenes/Kitchen",
            timestamp: Date(timeIntervalSince1970: 1_756_000_000))
        let second = try StoryboardFrameStore.save(
            png: Data([2]), projectBasePath: base,
            relativeDirectory: "assets/scenes/Kitchen",
            timestamp: Date(timeIntervalSince1970: 1_756_000_100))

        XCTAssertEqual(second.relativePath, first.relativePath)
        XCTAssertEqual(
            try Data(contentsOf: base.appendingPathComponent(second.relativePath)),
            Data([2]), "latest must carry the newest frame")
        XCTAssertEqual(
            try Data(contentsOf: base.appendingPathComponent(first.timestampedRelativePath)),
            Data([1]), "history must survive")
    }
}
