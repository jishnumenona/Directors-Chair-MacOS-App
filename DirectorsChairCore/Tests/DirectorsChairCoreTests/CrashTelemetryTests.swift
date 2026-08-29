//
//  CrashTelemetryTests.swift
//
//  The detection contracts: a clean exit is silent, an unclean one is
//  reported exactly once with its breadcrumbs, and only OUR crash from
//  THIS session's window is ever pinned on us. The .ips summarizer runs
//  against the real Apple format (a captured skeleton of one).
//

import XCTest
@testable import DirectorsChairCore

final class CrashTelemetryTests: XCTestCase {

    private var base: URL!
    private var diagnostics: URL!
    private var telemetry: CrashTelemetry!

    override func setUpWithError() throws {
        base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("telemetry-\(UUID().uuidString)")
        diagnostics = base.appendingPathComponent("DiagnosticReports")
        try FileManager.default.createDirectory(
            at: diagnostics, withIntermediateDirectories: true)
        telemetry = CrashTelemetry(
            directory: base.appendingPathComponent("Telemetry"),
            diagnosticsDirectory: diagnostics,
            processName: "DirectorsChair")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    func testACleanSessionReportsNothing() async {
        await telemetry.beginSession(appVersion: "3.10")
        await telemetry.endSessionCleanly()
        let report = await telemetry.launchCheck(appVersion: "3.10",
                                                 osVersion: "15.0")
        XCTAssertNil(report, "a clean quit must never nag")
    }

    /// The terminate path cannot await: the synchronous goodbye must take
    /// the lock off on its own (audit 2026-08-28 — the old semaphore
    /// pattern never ran, so every clean quit looked like a crash).
    func testTheSynchronousGoodbyeRemovesTheLock() async {
        await telemetry.beginSession(appVersion: "3.10")
        telemetry.endSessionCleanlyNow()
        let report = await telemetry.launchCheck(appVersion: "3.10", osVersion: "15.0")
        XCTAssertNil(report, "a synchronous clean quit must never nag either")
    }

    func testAnUncleanExitIsReportedOnceWithItsBreadcrumbs() async {
        await telemetry.beginSession(appVersion: "3.10")
        await telemetry.noteState(lastView: "Vision Board",
                                  projectName: "Backwater",
                                  projectShots: 3600)
        // No clean end: the process "died" here.

        let report = await telemetry.launchCheck(appVersion: "3.11",
                                                 osVersion: "15.0")
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.lastView, "Vision Board")
        XCTAssertEqual(report?.projectShots, 3600)
        XCTAssertEqual(report?.appVersion, "3.10",
                       "the version that CRASHED, not the one now running")

        let again = await telemetry.launchCheck(appVersion: "3.11",
                                                osVersion: "15.0")
        XCTAssertNil(again, "one crash, one report — never a nag loop")
    }

    func testTheReportIsArchivedToDisk() async throws {
        await telemetry.beginSession(appVersion: "3.10")
        _ = await telemetry.launchCheck(appVersion: "3.10", osVersion: "15.0")

        let archived = try FileManager.default.contentsOfDirectory(
            atPath: telemetry.reportsDirectory.path)
        XCTAssertEqual(archived.count, 1)
        XCTAssertTrue(archived[0].hasPrefix("crash-"))
    }

    func testOnlyOurProcessInOurWindowGetsPinnedOnUs() async throws {
        // Someone else's crash, and our own but ancient — both ignored.
        let foreign = diagnostics.appendingPathComponent("Safari-x.ips")
        try Self.fakeIPS().write(to: foreign, options: .atomic)
        let ancient = diagnostics
            .appendingPathComponent("DirectorsChair-old.ips")
        try Self.fakeIPS().write(to: ancient, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-86_400)],
            ofItemAtPath: ancient.path)

        await telemetry.beginSession(appVersion: "3.10")
        let report = await telemetry.launchCheck(appVersion: "3.10",
                                                 osVersion: "15.0")
        XCTAssertNil(report?.terminationSummary,
                     "neither report matches this session")

        // Our crash inside the window IS matched.
        await telemetry.beginSession(appVersion: "3.10")
        let fresh = diagnostics
            .appendingPathComponent("DirectorsChair-now.ips")
        try Self.fakeIPS().write(to: fresh, options: .atomic)
        let matched = await telemetry.launchCheck(appVersion: "3.10",
                                                  osVersion: "15.0")
        XCTAssertEqual(matched?.terminationSummary,
                       "EXC_BAD_ACCESS (SIGSEGV) — Segmentation fault: 11")
        XCTAssertEqual(matched?.crashedThreadFrames.first,
                       "libswiftCore.dylib: swift_retain")
    }

    func testTheSummarizerReadsTheRealAppleFormat() {
        let parsed = CrashTelemetry.summarize(ipsData: Self.fakeIPS())
        XCTAssertEqual(parsed.summary,
                       "EXC_BAD_ACCESS (SIGSEGV) — Segmentation fault: 11")
        XCTAssertEqual(parsed.frames.count, 2)
        XCTAssertEqual(parsed.frames[1], "MyApp: doWork")
    }

    func testGarbageIPSDataDegradesToNothingNotACrash() {
        let parsed = CrashTelemetry.summarize(
            ipsData: Data("not even close".utf8))
        XCTAssertNil(parsed.summary)
        XCTAssertTrue(parsed.frames.isEmpty)
    }

    /// A skeleton of Apple's real .ips shape: one JSON header line, then
    /// the JSON body with exception/termination/threads/usedImages.
    private static func fakeIPS() -> Data {
        let header = #"{"app_name":"DirectorsChair","name":"DirectorsChair"}"#
        let body = """
        {
          "exception": {"type": "EXC_BAD_ACCESS", "signal": "SIGSEGV"},
          "termination": {"indicator": "Segmentation fault: 11"},
          "faultingThread": 0,
          "usedImages": [
            {"name": "libswiftCore.dylib"},
            {"name": "MyApp"}
          ],
          "threads": [
            {"frames": [
              {"imageIndex": 0, "symbol": "swift_retain"},
              {"imageIndex": 1, "symbol": "doWork"}
            ]}
          ]
        }
        """
        return Data((header + "\n" + body).utf8)
    }
}
