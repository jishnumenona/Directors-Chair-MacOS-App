// AIUsageChatTests.swift
//
// AI Assistant usage accounting: chat tokens tally separately from plain
// text calls, bill at the text-model rates, and join the totals.

import XCTest
@testable import DirectorsChairServices

final class AIUsageChatTests: XCTestCase {

    func testChatUsageTalliesAndCosts() {
        var stats = AIUsageStats()
        stats.addChatUsage(promptTokens: 6_000, completionTokens: 400)
        stats.addChatUsage(promptTokens: 4_000, completionTokens: 600)

        XCTAssertEqual(stats.totalChatCalls, 2)
        XCTAssertEqual(stats.totalChatPromptTokens, 10_000)
        XCTAssertEqual(stats.totalChatCompletionTokens, 1_000)
        // 10k × $0.30/M + 1k × $2.50/M = 0.003 + 0.0025
        XCTAssertEqual(stats.chatCostUSD, 0.0055, accuracy: 0.00001)
        XCTAssertEqual(stats.totalCostUSD, stats.chatCostUSD, accuracy: 0.00001,
                       "chat joins the grand total")
        XCTAssertEqual(stats.totalCalls, 2)
        XCTAssertEqual(stats.totalTextCalls, 0, "chat never pollutes text tallies")
    }

    func testStatsDecodeWithoutChatKeysDefaultsToZero() throws {
        // Pre-chat persisted files must keep loading.
        let legacy = #"{"totalPromptTokens": 5, "totalTextCalls": 1}"#
        let stats = try JSONDecoder().decode(AIUsageStats.self,
                                             from: Data(legacy.utf8))
        XCTAssertEqual(stats.totalChatCalls, 0)
        XCTAssertEqual(stats.totalPromptTokens, 5)
    }

    func testRateCardMatchesCostMath() {
        let rates = AIUsageStats.rateCard
        XCTAssertEqual(AIUsageStats.imageCallCost(imageCount: 1), rates.imagePerImage)
        XCTAssertEqual(AIUsageStats.videoCallCost(durationSeconds: 1), rates.videoPerSecond)
        XCTAssertEqual(AIUsageStats.speechCallCost(charCount: 1000), rates.speechPer1kChars)
    }
}
