// VideoProviderTests.swift
// Tests for VideoProvider enum: properties, fromFolderName, case iteration

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairServices

final class VideoProviderTests: XCTestCase {

    // MARK: - CaseIterable

    func testAllCasesCount() {
        XCTAssertEqual(VideoProvider.allCases.count, 3)
    }

    func testAllCasesContainsExpected() {
        let cases = VideoProvider.allCases
        XCTAssertTrue(cases.contains(.veo3))
        XCTAssertTrue(cases.contains(.sora2))
        XCTAssertTrue(cases.contains(.kling))
    }

    // MARK: - Raw Values

    func testRawValues() {
        XCTAssertEqual(VideoProvider.veo3.rawValue, "google_veo")
        XCTAssertEqual(VideoProvider.sora2.rawValue, "sora_2")
        XCTAssertEqual(VideoProvider.kling.rawValue, "kling")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(VideoProvider(rawValue: "google_veo"), .veo3)
        XCTAssertEqual(VideoProvider(rawValue: "sora_2"), .sora2)
        XCTAssertEqual(VideoProvider(rawValue: "kling"), .kling)
        XCTAssertNil(VideoProvider(rawValue: "unknown"))
    }

    // MARK: - Display Names

    func testDisplayNames() {
        XCTAssertEqual(VideoProvider.veo3.displayName, "Veo 3")
        XCTAssertEqual(VideoProvider.sora2.displayName, "Sora 2")
        XCTAssertEqual(VideoProvider.kling.displayName, "Kling")
    }

    func testDisplayNamesNotEmpty() {
        for provider in VideoProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty, "\(provider) displayName should not be empty")
        }
    }

    // MARK: - Icons

    func testIcons() {
        XCTAssertEqual(VideoProvider.veo3.icon, "play.rectangle.fill")
        XCTAssertEqual(VideoProvider.sora2.icon, "film.fill")
        XCTAssertEqual(VideoProvider.kling.icon, "video.fill")
    }

    func testIconsUnique() {
        let icons = VideoProvider.allCases.map { $0.icon }
        XCTAssertEqual(Set(icons).count, icons.count, "Icons should be unique")
    }

    // MARK: - Duration Limits

    func testMinDurationPositive() {
        for provider in VideoProvider.allCases {
            XCTAssertGreaterThan(provider.minDuration, 0, "\(provider) minDuration must be > 0")
        }
    }

    func testMaxDurationGreaterThanMin() {
        for provider in VideoProvider.allCases {
            XCTAssertGreaterThan(provider.maxDuration, provider.minDuration,
                "\(provider) maxDuration must exceed minDuration")
        }
    }

    func testSpecificDurations() {
        XCTAssertEqual(VideoProvider.veo3.minDuration, 5)
        XCTAssertEqual(VideoProvider.veo3.maxDuration, 10)
        XCTAssertEqual(VideoProvider.sora2.minDuration, 5)
        XCTAssertEqual(VideoProvider.sora2.maxDuration, 20)
        XCTAssertEqual(VideoProvider.kling.minDuration, 3)
        XCTAssertEqual(VideoProvider.kling.maxDuration, 15)
    }

    // MARK: - Cost

    func testCostPerSecondPositive() {
        for provider in VideoProvider.allCases {
            XCTAssertGreaterThan(provider.costPerSecond, 0, "\(provider) cost must be > 0")
        }
    }

    func testSpecificCosts() {
        XCTAssertEqual(VideoProvider.veo3.costPerSecond, 0.02)
        XCTAssertEqual(VideoProvider.sora2.costPerSecond, 0.02)
        XCTAssertEqual(VideoProvider.kling.costPerSecond, 0.01)
    }

    func testKlingCheaperThanOthers() {
        XCTAssertLessThan(VideoProvider.kling.costPerSecond, VideoProvider.veo3.costPerSecond)
        XCTAssertLessThan(VideoProvider.kling.costPerSecond, VideoProvider.sora2.costPerSecond)
    }

    // MARK: - Folder Names

    func testFolderNames() {
        XCTAssertEqual(VideoProvider.veo3.folderName, "veo3")
        XCTAssertEqual(VideoProvider.sora2.folderName, "sora2")
        XCTAssertEqual(VideoProvider.kling.folderName, "kling")
    }

    func testFolderNamesUnique() {
        let folders = VideoProvider.allCases.map { $0.folderName }
        XCTAssertEqual(Set(folders).count, folders.count, "Folder names should be unique")
    }

    // MARK: - AI Provider

    func testAIProviders() {
        XCTAssertEqual(VideoProvider.veo3.aiProvider, .google)
        XCTAssertEqual(VideoProvider.sora2.aiProvider, .openai)
        XCTAssertEqual(VideoProvider.kling.aiProvider, .openai)
    }

    // MARK: - fromFolderName

    func testFromFolderNameValid() {
        XCTAssertEqual(VideoProvider.fromFolderName("veo3"), .veo3)
        XCTAssertEqual(VideoProvider.fromFolderName("sora2"), .sora2)
        XCTAssertEqual(VideoProvider.fromFolderName("kling"), .kling)
    }

    func testFromFolderNameInvalid() {
        XCTAssertNil(VideoProvider.fromFolderName("unknown"))
        XCTAssertNil(VideoProvider.fromFolderName(""))
        XCTAssertNil(VideoProvider.fromFolderName("Veo3"))  // case-sensitive
        XCTAssertNil(VideoProvider.fromFolderName("google_veo"))  // raw value, not folder name
    }

    func testFromFolderNameRoundTrip() {
        for provider in VideoProvider.allCases {
            XCTAssertEqual(VideoProvider.fromFolderName(provider.folderName), provider)
        }
    }

    // MARK: - Supported Aspect Ratios / Resolutions

    func testVeoRejectsSquareAspectRatio() {
        // Veo 400s on 1:1 — the UI must not offer it.
        XCTAssertEqual(VideoProvider.veo3.supportedAspectRatios, ["16:9", "9:16"])
        XCTAssertFalse(VideoProvider.veo3.supportedAspectRatios.contains("1:1"))
    }

    func testOtherProvidersKeepSquareAspectRatio() {
        XCTAssertTrue(VideoProvider.sora2.supportedAspectRatios.contains("1:1"))
        XCTAssertTrue(VideoProvider.kling.supportedAspectRatios.contains("1:1"))
    }

    func testSupportedResolutions() {
        for provider in VideoProvider.allCases {
            XCTAssertEqual(provider.supportedResolutions, ["720p", "1080p"])
        }
    }

    // MARK: - End-frame interpolation duration

    func testOnlyVeoSupportsEndFrameInterpolation() {
        XCTAssertTrue(VideoProvider.veo3.supportsEndFrameInterpolation)
        XCTAssertFalse(VideoProvider.sora2.supportsEndFrameInterpolation)
        XCTAssertFalse(VideoProvider.kling.supportsEndFrameInterpolation)
    }

    func testEffectiveDurationFixedWhenVeoBridgesEndFrame() {
        // Veo interpolation ignores the requested duration and fixes the clip
        // length itself — billing/estimates must use that length.
        XCTAssertEqual(VideoProvider.veo3.effectiveDuration(requested: 5.0, bridgesEndFrame: true),
                       VideoProvider.interpolationDurationSeconds)
    }

    func testEffectiveDurationHonorsRequestWithoutEndFrame() {
        XCTAssertEqual(VideoProvider.veo3.effectiveDuration(requested: 6.5, bridgesEndFrame: false), 6.5)
    }

    func testEffectiveDurationHonorsRequestForNonInterpolatingProviders() {
        XCTAssertEqual(VideoProvider.sora2.effectiveDuration(requested: 12.0, bridgesEndFrame: true), 12.0)
        XCTAssertEqual(VideoProvider.kling.effectiveDuration(requested: 7.0, bridgesEndFrame: true), 7.0)
    }
}
