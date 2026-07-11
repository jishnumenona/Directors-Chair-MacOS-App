//
//  PerfScenarioRunner.swift
//  DirectorsChair-Desktop
//
//  In-app performance scenarios for the UI-responsiveness workstream.
//  Launch with:  DirectorsChair-Desktop --perf-scenario <open|tabsweep|publish|idle>
//
//  Each run: regenerates the deterministic stress project, opens it, runs the
//  scenario with the main-thread hang watchdog active, then writes a JSON
//  report to ~/Directors Chair/perf-results/ and terminates the app.
//
//  Metrics per report: wall duration, hitches (>16ms) and hangs (>100ms) on
//  the main thread, worst stall, and all PerfCounters (hot-path durations +
//  body-evaluation / event-handler counts).
//

import AppKit
import Foundation
import DirectorsChairCore

@MainActor
enum PerfScenarioRunner {

    struct Report: Codable {
        let scenario: String
        let date: String
        let appVersion: String
        let scenarioDurationMs: Double
        let watchdog: MainThreadHangWatchdog.Report
        let counters: [String: PerfCounters.Stat]
    }

    nonisolated static var requestedScenario: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--perf-scenario"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func run(scenario: String,
                    projectViewModel: ProjectViewModel,
                    coordinator: AppCoordinator) async {
        let watchdog = MainThreadHangWatchdog()
        PerfCounters.shared.reset()

        // Deterministic fixture — regenerating guarantees an identical
        // workload regardless of what earlier runs did to the project.
        guard let projectDir = try? await StressProjectGenerator.generateOnDisk() else {
            fputs("perf: failed to generate stress project\n", stderr)
            NSApp.terminate(nil)
            return
        }

        watchdog.start()
        let start = DispatchTime.now().uptimeNanoseconds

        try? await projectViewModel.load(from: projectDir.appendingPathComponent("project.json"))
        coordinator.notifyProjectChanged(.general)

        // Let the initial render settle
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        switch scenario {
        case "open":
            // Open cost + first render is what we already captured.
            break

        case "tabsweep":
            // Visit every tab twice: first pass mounts them, second pass
            // measures switching with all tabs alive (audit A2). Each visit is
            // bracketed by a watchdog snapshot so the per-tab stall is attributed
            // to a "tabstall.<view>" counter (maxMs = worst single mount).
            for _ in 0..<2 {
                for view in AppView.allCases {
                    let before = watchdog.snapshot()
                    coordinator.navigateTo(view)
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    let after = watchdog.snapshot()
                    let stallDeltaMs = max(0, after.totalStallMs - before.totalStallMs)
                    PerfCounters.shared.record(name: "tabstall.\(view.rawValue)",
                                               nanoseconds: UInt64(stallDeltaMs * 1_000_000))
                }
            }

        case "publish":
            // Simulate the editor's 500ms flush fan-out (audit A1/A3/A4):
            // whole-project publish + .script event, 20 ticks. Counters show
            // how many bodies/handlers wake per tick.
            for i in 0..<20 {
                projectViewModel.project.projectNotes = "perf tick \(i)"
                coordinator.notifyProjectChanged(.script)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

        case "navigator":
            // Navigator responsiveness: outline mounted + typing fan-out,
            // then a rapid-click probe (how many navigation clicks actually
            // land at a fast-but-human 150ms cadence).
            coordinator.showingNavigator = true
            coordinator.navigateTo(.script)
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            for i in 0..<20 {
                projectViewModel.project.projectNotes = "nav tick \(i)"
                coordinator.notifyProjectChanged(.script)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            let clickSequence: [AppView] = [.overview, .script, .bubble, .scenes, .script,
                                            .overview, .bubble, .script, .scenes, .overview]
            for target in clickSequence {
                PerfCounters.shared.increment("nav.clicksAttempted")
                let before = coordinator.selectedView
                coordinator.navigateTo(target)
                if coordinator.selectedView != before {
                    PerfCounters.shared.increment("nav.clicksApplied")
                }
                try? await Task.sleep(nanoseconds: 80_000_000)  // fast-clicking user
            }

        case "idle":
            // Background churn with a project open (audit D2).
            try? await Task.sleep(nanoseconds: 30_000_000_000)

        default:
            fputs("perf: unknown scenario '\(scenario)'\n", stderr)
        }

        let durationMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        watchdog.stop()
        // Let the last watchdog pings drain
        try? await Task.sleep(nanoseconds: 300_000_000)

        writeReport(Report(
            scenario: scenario,
            date: ISO8601DateFormatter().string(from: Date()),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
            scenarioDurationMs: durationMs,
            watchdog: watchdog.snapshot(),
            counters: PerfCounters.shared.snapshot()
        ))

        NSApp.terminate(nil)
    }

    private static func writeReport(_ report: Report) {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Directors Chair")
            .appendingPathComponent("perf-results")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("\(report.scenario)-\(stamp).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report) {
            try? data.write(to: url)
            print("perf: report written to \(url.path)")
        }
    }
}
