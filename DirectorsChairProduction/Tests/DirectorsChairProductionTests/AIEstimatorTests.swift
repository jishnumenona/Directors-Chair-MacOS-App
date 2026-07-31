// AIEstimatorTests.swift
//
// Accounting › AI Usage estimator: pure cost math the calculator and the
// "videos for every shot" panel rely on.

import XCTest
@testable import DirectorsChairProduction

final class AIEstimatorTests: XCTestCase {

    func testAllShotsVideoCostBillsSpecifiedAndFallbackSeconds() {
        // 100s of specified shots + 5 unspecified shots at 8s fallback,
        // at $0.40/s → (100 + 40) * 0.40 = $56.
        XCTAssertEqual(AIEstimator.allShotsVideoCost(
            shotSecondsSpecified: 100, shotsWithoutDuration: 5,
            fallbackClipSeconds: 8, ratePerSecond: 0.40), 56.0, accuracy: 0.001)
    }

    func testAllShotsVideoCostWithEverythingSpecified() {
        XCTAssertEqual(AIEstimator.allShotsVideoCost(
            shotSecondsSpecified: 238, shotsWithoutDuration: 0,
            fallbackClipSeconds: 8, ratePerSecond: 0.40), 95.2, accuracy: 0.001)
    }

    func testUnitCosts() {
        XCTAssertEqual(AIEstimator.imagesCost(count: 25, rate: 0.04), 1.0, accuracy: 0.0001)
        XCTAssertEqual(AIEstimator.videoCost(seconds: 60, ratePerSecond: 0.40), 24.0, accuracy: 0.0001)
        XCTAssertEqual(AIEstimator.speechCost(characters: 5_000, ratePer1k: 0.015), 0.075, accuracy: 0.0001)
    }

    func testChatCostUsesBothTokenRates() {
        // 50 turns × (6k in @ $0.30/M + 400 out @ $2.50/M)
        // = 300k in → $0.09; 20k out → $0.05 → $0.14.
        XCTAssertEqual(AIEstimator.chatCost(
            turns: 50, promptTokensPerTurn: 6_000, outputTokensPerTurn: 400,
            inRatePerM: 0.30, outRatePerM: 2.50), 0.14, accuracy: 0.0001)
    }
}
