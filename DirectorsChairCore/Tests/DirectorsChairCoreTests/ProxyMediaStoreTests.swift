//
//  ProxyMediaStoreTests.swift
//
//  The pipeline's contracts, with the transcoder faked so no video
//  renders: layout is stable and flat, freshness is mtime-truthful, a
//  broken clip is retried only when it changes, small sources are never
//  proxied, and playback resolution always answers. One end-to-end test
//  renders a real clip through AVAssetExportSession, because a pipeline
//  whose real transcoder was never run is a diagram, not a pipeline.
//

import XCTest
import AVFoundation
@testable import DirectorsChairCore

final class ProxyMediaStoreTests: XCTestCase {

    private var base: URL!

    override func setUpWithError() throws {
        base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("proxy-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: base, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    private func plantSource(_ relPath: String,
                             bytes: Int = 64) throws -> URL {
        let url = base.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    // MARK: - Fakes

    final class FakeTranscoder: ProxyTranscoding, @unchecked Sendable {
        var needsProxyAnswer = true
        var transcodeError: Error?
        private(set) var transcodeCount = 0
        private let lock = NSLock()

        func needsProxy(source: URL) async throws -> Bool { needsProxyAnswer }
        func transcode(source: URL, to destination: URL) async throws {
            lock.lock(); transcodeCount += 1; lock.unlock()
            if let transcodeError { throw transcodeError }
            try Data("proxy".utf8).write(to: destination)
        }
    }

    // MARK: - Layout

    func testProxyPathsAreFlatStableAndCollisionFree() {
        let a = ProxyMediaStore.proxyURL(
            forRelativePath: "takes/Scene_1/Shot_001/take-1.mov",
            projectBase: base)
        let again = ProxyMediaStore.proxyURL(
            forRelativePath: "takes/Scene_1/Shot_001/take-1.mov",
            projectBase: base)
        let other = ProxyMediaStore.proxyURL(
            forRelativePath: "takes/Scene_1/Shot_001/take-2.mov",
            projectBase: base)

        XCTAssertEqual(a, again, "the mapping is deterministic")
        XCTAssertNotEqual(a, other)
        XCTAssertEqual(a.deletingLastPathComponent().lastPathComponent,
                       "proxies", "flat directory, no nested tree to GC")
        XCTAssertTrue(a.lastPathComponent.hasSuffix("-720.mp4"))
    }

    // MARK: - Freshness

    func testAFreshProxyIsFoundAndAStaleOneIsNot() throws {
        let rel = "takes/a.mov"
        _ = try plantSource(rel)
        let proxy = ProxyMediaStore.proxyURL(forRelativePath: rel,
                                             projectBase: base)
        try FileManager.default.createDirectory(
            at: proxy.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("proxy".utf8).write(to: proxy)

        XCTAssertNotNil(ProxyMediaStore.freshProxy(forRelativePath: rel,
                                                   projectBase: base))

        // The source changes AFTER the proxy: the proxy is now a lie.
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(60)],
            ofItemAtPath: base.appendingPathComponent(rel).path)
        XCTAssertNil(ProxyMediaStore.freshProxy(forRelativePath: rel,
                                                projectBase: base),
                     "a stale proxy must never be served")
    }

    // MARK: - Ensuring

    func testEnsureTranscodesOnceAndThenSkips() async throws {
        let rel = "takes/b.mov"
        _ = try plantSource(rel)
        let fake = FakeTranscoder()
        let store = ProxyMediaStore(transcoder: fake)

        await store.ensureProxy(forRelativePath: rel, projectBase: base)
        await store.ensureProxy(forRelativePath: rel, projectBase: base)

        XCTAssertEqual(fake.transcodeCount, 1,
                       "a fresh proxy is never re-encoded")
        XCTAssertNotNil(ProxyMediaStore.freshProxy(forRelativePath: rel,
                                                   projectBase: base))
    }

    func testAFailingClipIsRetriedOnlyWhenItChanges() async throws {
        let rel = "takes/c.mov"
        let source = try plantSource(rel)
        let fake = FakeTranscoder()
        struct Boom: Error {}
        fake.transcodeError = Boom()
        let store = ProxyMediaStore(transcoder: fake)

        await store.ensureProxy(forRelativePath: rel, projectBase: base)
        await store.ensureProxy(forRelativePath: rel, projectBase: base)
        XCTAssertEqual(fake.transcodeCount, 1,
                       "one broken clip must not burn CPU every sweep")

        // The file changes — worth another try.
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(60)],
            ofItemAtPath: source.path)
        await store.ensureProxy(forRelativePath: rel, projectBase: base)
        XCTAssertEqual(fake.transcodeCount, 2)
    }

    func testSmallSourcesAreNeverProxied() async throws {
        let rel = "takes/d.mov"
        _ = try plantSource(rel)
        let fake = FakeTranscoder()
        fake.needsProxyAnswer = false
        let store = ProxyMediaStore(transcoder: fake)

        await store.ensureProxy(forRelativePath: rel, projectBase: base)
        XCTAssertEqual(fake.transcodeCount, 0,
                       "a proxy of a proxy-sized file wastes disk")
        XCTAssertNil(ProxyMediaStore.freshProxy(forRelativePath: rel,
                                                projectBase: base))
    }

    func testAMissingSourceIsANoOp() async {
        let fake = FakeTranscoder()
        let store = ProxyMediaStore(transcoder: fake)
        await store.ensureProxy(forRelativePath: "takes/ghost.mov",
                                projectBase: base)
        XCTAssertEqual(fake.transcodeCount, 0)
    }

    // MARK: - Playback resolution

    func testPlaybackPrefersTheFreshProxyAndFallsBackToTheOriginal() throws {
        let rel = "takes/e.mov"
        let source = try plantSource(rel)

        // No proxy yet: the original plays.
        XCTAssertEqual(ProxyPlayback.url(forRelativePath: rel,
                                         projectBase: base), source)

        let proxy = ProxyMediaStore.proxyURL(forRelativePath: rel,
                                             projectBase: base)
        try FileManager.default.createDirectory(
            at: proxy.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("proxy".utf8).write(to: proxy)
        XCTAssertEqual(ProxyPlayback.url(forRelativePath: rel,
                                         projectBase: base), proxy)

        // The user turns proxies off: originals, no questions.
        UserDefaults.standard.set(false, forKey: ProxyPlayback.preferenceKey)
        defer {
            UserDefaults.standard.removeObject(
                forKey: ProxyPlayback.preferenceKey)
        }
        XCTAssertEqual(ProxyPlayback.url(forRelativePath: rel,
                                         projectBase: base), source)
    }

    func testWorkListCoversShotVideosAndEveryTake() {
        var take1 = Take(takeNumber: 1)
        take1.capturedVideoPath = "takes/s1/t1.mov"
        var take2 = Take(takeNumber: 2)
        take2.capturedVideoPath = "takes/s1/t2.mov"
        var shot = Shot(shotId: 1)
        shot.videoPath = "videos/shot1.mp4"
        shot.takes = [take1, take2]
        var scene = DirectorsChairCore.Scene(name: "Scene 1")
        scene.shots = [shot]
        var sequence = Sequence(name: "Seq")
        sequence.scenes = [scene]
        var project = Project(name: "Test")
        project.sequences = [sequence]

        XCTAssertEqual(Set(ProxyPlayback.mediaRelativePaths(in: project)),
                       ["videos/shot1.mp4", "takes/s1/t1.mov",
                        "takes/s1/t2.mov"])
    }

    // MARK: - The real transcoder, end to end

    func testRealTranscoderProducesAPlayable720Proxy() async throws {
        // Render a real 1920×1080 clip (12 frames of colour), then run it
        // through the REAL AVProxyTranscoder.
        let sourceRel = "takes/real.mov"
        let sourceURL = base.appendingPathComponent(sourceRel)
        try FileManager.default.createDirectory(
            at: sourceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try await Self.writeTestClip(to: sourceURL,
                                     size: CGSize(width: 1920, height: 1080))

        let transcoder = AVProxyTranscoder()
        let needs = try await transcoder.needsProxy(source: sourceURL)
        XCTAssertTrue(needs, "1080p is worth proxying")

        let store = ProxyMediaStore(transcoder: transcoder)
        await store.ensureProxy(forRelativePath: sourceRel, projectBase: base)

        let proxy = try XCTUnwrap(ProxyMediaStore.freshProxy(
            forRelativePath: sourceRel, projectBase: base))
        let tracks = try await AVURLAsset(url: proxy)
            .loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertLessThanOrEqual(min(size.width, size.height), 720.5,
                                 "the proxy really is proxy-sized")

        let smallEnough = try await transcoder.needsProxy(source: proxy)
        XCTAssertFalse(smallEnough, "and would never be proxied again")
    }

    /// A tiny real H.264 clip via AVAssetWriter.
    private static func writeTestClip(to url: URL, size: CGSize) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<12 {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, Int(size.width), Int(size.height),
                                kCVPixelFormatType_32ARGB, nil, &buffer)
            if let buffer {
                CVPixelBufferLockBaseAddress(buffer, [])
                if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
                    memset(baseAddress, Int32(frame * 20),
                           CVPixelBufferGetDataSize(buffer))
                }
                CVPixelBufferUnlockBaseAddress(buffer, [])
                adaptor.append(buffer, withPresentationTime:
                    CMTime(value: CMTimeValue(frame), timescale: 12))
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? ProxyMediaError.exportUnavailable
        }
    }
}
