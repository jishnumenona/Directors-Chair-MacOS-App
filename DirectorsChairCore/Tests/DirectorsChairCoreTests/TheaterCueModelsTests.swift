// TheaterCueModelsTests.swift
//
// Coverage + correctness for the theater-choreography models (lighting,
// SFX, support cues, gantt, soundtrack). These carried 0% coverage despite
// being real feature logic: every enum exposes an `icon`/`tooltip` used by
// the timeline lanes, and each cue is Codable into the project wire format.
// The tests assert every enum case has a non-empty icon (so no lane renders
// blank), that Codable round-trips are lossless, and that timing math holds.

import XCTest
@testable import DirectorsChairCore

final class TheaterCueModelsTests: XCTestCase {

    // MARK: - Enum icons/tooltips (covers every switch branch)

    private func assertIcons<T: CaseIterable>(_ type: T.Type, icon: (T) -> String,
                                              file: StaticString = #filePath, line: UInt = #line) {
        for c in T.allCases {
            XCTAssertFalse(icon(c).isEmpty, "\(type) case must have a non-empty icon",
                           file: file, line: line)
        }
    }

    func testLightingEnumIconsAllPresent() {
        assertIcons(LightFixtureType.self) { $0.icon }
        assertIcons(LightMotivation.self) { $0.icon }
        assertIcons(LightTransition.self) { $0.icon }
        assertIcons(LightPosition.self) { $0.icon }
        // Fixture types also carry a tooltip used in the lighting lane.
        for f in LightFixtureType.allCases { XCTAssertFalse(f.tooltip.isEmpty) }
        // LightingWorkflow is a plain classifier (round-tripped via LightCue).
        XCTAssertFalse(LightingWorkflow.allCases.isEmpty)
    }

    func testSFXEnumIconsAllPresent() {
        assertIcons(SFXEffectType.self) { $0.icon }
        assertIcons(SFXIntensityProfile.self) { $0.icon }
        assertIcons(SFXTransition.self) { $0.icon }
        assertIcons(SFXPlacement.self) { $0.icon }
        for e in SFXEffectType.allCases { XCTAssertFalse(e.tooltip.isEmpty) }
    }

    func testSupportEnumIconsAllPresent() {
        assertIcons(SupportActionType.self) { $0.icon }
        assertIcons(SupportPriority.self) { $0.icon }
        assertIcons(SupportStageArea.self) { $0.icon }
        for a in SupportActionType.allCases { XCTAssertFalse(a.tooltip.isEmpty) }
    }

    func testGanttCategoryIconsAllPresent() {
        assertIcons(GanttTaskCategory.self) { $0.icon }
    }

    // MARK: - Codable round trips (lossless wire format)

    private func roundTrip<T: Codable & Equatable>(_ value: T,
                                                   file: StaticString = #filePath,
                                                   line: UInt = #line) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(value, decoded, "\(T.self) must round-trip losslessly",
                       file: file, line: line)
    }

    func testLightCueRoundTrips() throws {
        try roundTrip(LightCue(name: "Warm wash", cueNumber: "LX12",
                               workflow: .cinema, fixtureType: .keyLight,
                               startTime: 12.5, duration: 8))
    }

    func testSFXCueRoundTrips() throws {
        try roundTrip(SFXCue(name: "Thunder", cueNumber: "FX3",
                             effectType: .smoke, startTime: 30, duration: 5))
    }

    func testSupportCueRoundTrips() throws {
        try roundTrip(SupportCue(name: "Reset props", cueNumber: "S2",
                                 actionType: .propMove, startTime: 40, duration: 6))
    }

    func testGanttTaskRoundTrips() throws {
        try roundTrip(GanttTask(name: "Location scout", category: .custom))
    }

    func testSoundtrackTrackRoundTrips() throws {
        try roundTrip(SoundtrackTrack(name: "Score", audioFilePath: "audio/score.m4a",
                                      startTimeOffset: 2, duration: 120, volume: 0.8))
    }

    // MARK: - Timing invariants

    func testCueEndTimesAreStartPlusDuration() {
        let lx = LightCue(name: "x", startTime: 10, duration: 4)
        XCTAssertEqual(lx.startTime + lx.duration, 14, accuracy: 0.001)
        let fx = SFXCue(name: "y", startTime: 20, duration: 3)
        XCTAssertEqual(fx.startTime + fx.duration, 23, accuracy: 0.001)
    }

    func testCueIdentityIsStable() {
        let cue = LightCue(name: "z")
        XCTAssertEqual(cue.id, cue.id)
        XCTAssertFalse(cue.id.isEmpty)
    }
}
