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
