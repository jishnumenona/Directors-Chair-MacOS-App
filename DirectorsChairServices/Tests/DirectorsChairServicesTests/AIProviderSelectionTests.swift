// DirectorsChairServicesTests/AIProviderSelectionTests.swift
//
// DC-0056: the per-function service catalog and resolution point. The
// catalog is the preferences UI's truth table, so its honesty is pinned:
// no dead options, every server option carries a real health key, and a
// stale stored choice can never reach the wire.

import XCTest
@testable import DirectorsChairServices

final class AIProviderSelectionTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suite = "ai-pref-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Catalog honesty

    func testEveryFunctionHasOptionsAndDefaultsAreFirst() {
        for function in AIFunction.allCases {
            let options = AIProviderCatalog.options(for: function)
            XCTAssertFalse(options.isEmpty, function.rawValue)
            XCTAssertEqual(AIProviderCatalog.defaultOption(for: function).wireId,
                           options[0].wireId, function.rawValue)
            // Wire ids unique within a function.
            XCTAssertEqual(Set(options.map(\.wireId)).count, options.count)
        }
    }

    func testVideoOffersOnlyWhatTheWireCanAddress() {
        // Server §19 decision: Veo only. Sora/Kling were dead chips in the
        // old pane — they must never come back without a wire change.
        XCTAssertEqual(AIProviderCatalog.options(for: .video).map(\.wireId),
                       ["google_veo"])
    }

    func testHealthKeysMatchTheGatewayVocabulary() {
        // The gateway /health providers map (spec §8.2) uses exactly these
        // keys — a catalog typo would silently mark a service unavailable.
        let known: Set<String> = ["openai", "anthropic", "google", "stability",
                                  "deepseek", "elevenlabs", "google_veo"]
        for function in AIFunction.allCases {
            for option in AIProviderCatalog.options(for: function) {
                if let key = option.healthKey {
                    XCTAssertTrue(known.contains(key),
                                  "\(function.rawValue)/\(option.wireId): unknown health key '\(key)'")
                }
            }
        }
        // Exactly one on-device option exists today (assistant voice).
        let onDevice = AIFunction.allCases.flatMap {
            AIProviderCatalog.options(for: $0).filter { $0.healthKey == nil }
        }
        XCTAssertEqual(onDevice.map(\.wireId), ["device"])
    }

    func testPreferenceKeysAreFrozen() {
        // Pre-DC-0056 keys must never move — users keep their choices.
        XCTAssertEqual(AIFunction.chat.preferenceKey, "pref.ai.chatProvider")
        XCTAssertEqual(AIFunction.text.preferenceKey, "pref.ai.textProvider")
        XCTAssertEqual(AIFunction.image.preferenceKey, "pref.ai.imageProvider")
        XCTAssertEqual(AIFunction.video.preferenceKey, "pref.ai.videoProvider")
        XCTAssertEqual(AIFunction.voiceReplies.preferenceKey, "pref.ai.voiceReplyEngine")
        XCTAssertEqual(AIFunction.speech.preferenceKey, "pref.ai.speechProvider")
    }

    // MARK: - Resolution

    func testResolutionReadsStoredChoiceAndFallsBackSafely() {
        let defaults = freshDefaults()
        let selection = AIProviderSelection(defaults: defaults)

        // Nothing stored → shipped default.
        XCTAssertEqual(selection.wireId(for: .image), "google_imagen")
        XCTAssertEqual(selection.provider(for: .image), .googleImagen)

        // A real choice is honored.
        defaults.set("stability", forKey: AIFunction.image.preferenceKey)
        XCTAssertEqual(selection.provider(for: .image), .stability)

        // A stale value from an older build (Sora was once offered for
        // video) degrades to the default — never reaches the wire.
        defaults.set("sora", forKey: AIFunction.video.preferenceKey)
        XCTAssertEqual(selection.wireId(for: .video), "google_veo")

        // A value valid for ANOTHER function doesn't leak across.
        defaults.set("google_veo", forKey: AIFunction.text.preferenceKey)
        XCTAssertEqual(selection.wireId(for: .text), "google")
    }

    // MARK: - Availability

    func testAvailabilityReadsHealthAndOnDeviceIsAlwaysOn() {
        let health = AIProviderHealth(
            providers: ["google": true, "stability": false, "elevenlabs": false],
            checkedAt: Date())
        let imagen = AIProviderCatalog.options(for: .image)[0]
        let stability = AIProviderCatalog.options(for: .image)[1]
        XCTAssertTrue(health.isAvailable(imagen))
        XCTAssertFalse(health.isAvailable(stability))
        // Missing key reads as unavailable, never as a shrug.
        let openai = AIProviderCatalog.options(for: .text).first { $0.wireId == "openai" }!
        XCTAssertFalse(health.isAvailable(openai))
        // On-device needs no server.
        let device = AIProviderCatalog.options(for: .voiceReplies).first { $0.healthKey == nil }!
        XCTAssertTrue(health.isAvailable(device))
    }
}
