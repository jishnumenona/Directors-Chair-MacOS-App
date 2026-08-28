// LocalModelIdleReleaseTests.swift
//
// DC-0079: the one release-on-idle rule both local engines share. A job
// begins and ends; the release fires only if the interval passes with no
// newer job begun, and carries the token the engine re-checks.

import XCTest
@testable import DirectorsChairServices

final class LocalModelIdleReleaseTests: XCTestCase {

    private final class Releases: @unchecked Sendable {
        private let lock = NSLock()
        private var tokens: [Int] = []
        func record(_ token: Int) { lock.lock(); tokens.append(token); lock.unlock() }
        var all: [Int] { lock.lock(); defer { lock.unlock() }; return tokens }
    }

    func testReleaseFiresAfterTheIntervalWithTheJobsToken() async throws {
        let releases = Releases()
        let idle = LocalModelIdleRelease(interval: { 0.05 }) { releases.record($0) }
        idle.begin()
        idle.end()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(releases.all, [1])
        XCTAssertTrue(idle.isCurrent(1))
    }

    func testAJobInFlightKeepsTheWeights() async throws {
        let releases = Releases()
        let idle = LocalModelIdleRelease(interval: { 0.1 }) { releases.record($0) }
        idle.begin()
        idle.end()          // armed for job 1
        idle.begin()        // job 2 starts before it fires
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(releases.all, [], "a release armed by an older job must not fire under a newer one")
        XCTAssertFalse(idle.isCurrent(1))
        idle.end()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(releases.all, [2], "the release fires once, for the last job")
    }

    /// prepare() loads without a job of its own: ending the current
    /// generation still arms a release.
    func testEndWithoutBeginArmsTheCurrentGeneration() async throws {
        let releases = Releases()
        let idle = LocalModelIdleRelease(interval: { 0.05 }) { releases.record($0) }
        idle.end()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(releases.all, [0])
    }

    func testDefaultIntervalIsTheMemoryPolicys() {
        #if arch(arm64)
        XCTAssertEqual(LocalModelIdleRelease.defaultInterval, MLXMemoryPolicy.idleReleaseInterval)
        #else
        XCTAssertEqual(LocalModelIdleRelease.defaultInterval, 300)
        #endif
    }
}
