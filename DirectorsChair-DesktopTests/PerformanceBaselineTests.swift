// PerformanceBaselineTests.swift
//
// Headless performance benchmarks for the UI-responsiveness workstream.
// Each test measures a hot path identified by the 2026-07-08 performance
// audit against the deterministic stress project (60 scenes / ~400 shots /
// ~2,000 script elements, fixed seed) so numbers are comparable across
// implementations and machines-with-baselines.
//
// These are MEASUREMENTS, not assertions: they never fail on timing (only on
// setup errors). Compare runs via docs/perf/ baseline documents or Xcode
// baselines set on a reference machine.

import XCTest
import SwiftUI
import AppKit
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairViews

@MainActor
final class PerformanceBaselineTests: XCTestCase {

    static var stressProject: Project!

    override class func setUp() {
        super.setUp()
        // Built once — deterministic, so identical for every test and run.
        stressProject = StressProjectGenerator.makeProject()
    }

    private var project: Project { Self.stressProject }

    private func makeLoadedViewModel() -> (ScriptViewModel, ProjectViewModel) {
        let pvm = ProjectViewModel()
        pvm.project = project
        let vm = ScriptViewModel()
        vm.loadFromProject(project, projectViewModel: pvm)
        return (vm, pvm)
    }

    private let metrics: [XCTMetric] = [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]

    // MARK: - Fixture sanity (fails loudly if the workload silently shrinks)

    func testStressProjectShape() {
        let scenes = project.sequences.flatMap { $0.scenes }
        XCTAssertEqual(scenes.count, 60)
        XCTAssertGreaterThan(scenes.flatMap { $0.shots }.count, 350)
        let elements = ProjectToScriptConverter.convert(from: project)
        XCTAssertGreaterThan(elements.count, 1800, "Stress script must stay ~2,000 elements")
        XCTAssertEqual(project.characters.count, 25)
        XCTAssertEqual(project.locations.count, 30)
    }

    // MARK: - Converter (runs on every external .script event — audit F5/A6)

    func testPerf_ConvertProjectToScript() {
        measure(metrics: metrics) {
            _ = ProjectToScriptConverter.convert(from: project)
        }
    }

    // MARK: - Typing flush cycle (every 500ms while typing — audit §3)

    func testPerf_TypingFlushCycle() {
        let (vm, _) = makeLoadedViewModel()
        // Pick 20 dialogue elements spread across the document
        let dialogueIndices = vm.elements.enumerated()
            .filter { $0.element.type == .dialogue }
            .map(\.offset)
        let targets = stride(from: 0, to: dialogueIndices.count, by: max(1, dialogueIndices.count / 20))
            .map { dialogueIndices[$0] }

        measure(metrics: metrics) {
            for (i, idx) in targets.enumerated() {
                vm.handleTextEdit(elementIndex: idx,
                                  newText: vm.elements[idx].text + " take\(i)")
                vm.flushDirtyElements()
            }
        }
    }

    // MARK: - Return-key burst (synchronous structural path — audit B1/B2/B3)

    func testPerf_ReturnKeyBurst() {
        let baseline = makeLoadedViewModel().0.elements

        measure(metrics: metrics) {
            let (vm, _) = makeLoadedViewModel()
            vm.elements = baseline
            let step = max(1, vm.elements.count / 20)
            for i in 0..<20 {
                let idx = min(i * step + 5, vm.elements.count - 1)
                _ = vm.handleReturn(atElementIndex: idx, cursorOffset: 0)
            }
        }
    }

    // MARK: - Undo (snapshot restore — audit B1 via .fullRebuild)

    func testPerf_UndoBurst() {
        measure(metrics: metrics) {
            let (vm, _) = makeLoadedViewModel()
            for i in 0..<10 {
                let idx = min(i * 50 + 5, vm.elements.count - 1)
                _ = vm.handleReturn(atElementIndex: idx, cursorOffset: 0)
            }
            for _ in 0..<10 {
                _ = vm.performUndo()
            }
        }
    }

    // MARK: - Timeline rebuild (fires per event, audit A3)

    func testPerf_TimelineRebuild() {
        let timeline = TimelineViewModel()
        measure(metrics: metrics) {
            timeline.setProject(project)
            timeline.refresh()
        }
    }

    // MARK: - Editor stats passes (synchronous per structural edit — audit B3)

    func testPerf_StatsPasses() {
        let (vm, _) = makeLoadedViewModel()
        let elements = vm.elements
        measure(metrics: metrics) {
            _ = ScreenplayFormatting.estimatePageCount(from: elements)
            _ = ScreenplayFormatting.wordCount(from: elements)
            _ = ScreenplayFormatting.computeStats(from: elements)
            _ = ProjectToScriptConverter.extractSceneOutline(from: elements)
        }
    }
}

// MARK: - Big-project scale audit (2026-08-06)
//
// The wall's audit found its cliff (a 1,000-element board crashed); this
// is the same discipline for every other central view. A 300-scene /
// 3,600-shot project is mounted into each tab through the REAL router —
// CentralViewRouter with the real coordinator, project view-model, and
// timeline — and mount plus one project-publish tick are timed. Model
// paths that run on every save/sync are timed at the same scale.
// Numbers print to stderr (stdout is block-buffered under a piped
// runner, and a dying test takes its buffer with it).

@MainActor
final class BigProjectViewAuditTests: XCTestCase {

    private static func note(_ line: String) {
        FileHandle.standardError.write(("AUDIT[" + line + "\n").data(using: .utf8)!)
    }

    private func hostRouter(project: Project, view: AppView)
        -> (NSWindow, AppCoordinator, ProjectViewModel, () -> Void) {
        let coordinator = AppCoordinator()
        let projectViewModel = ProjectViewModel()
        projectViewModel.project = project
        let timeline = TimelineViewModel()
        timeline.setProject(project)
        coordinator.selectedView = view

        let root = AnyView(CentralViewRouter()
            .environmentObject(coordinator)
            .environmentObject(projectViewModel)
            .environmentObject(timeline)
            .frame(width: 1440, height: 900))
        let hosting = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: 1440, height: 900),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderBack(nil)
        return (window, coordinator, projectViewModel, {
            RunLoop.main.run(mode: .default, before: Date())
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
        })
    }

    func testMountAndPublishEveryCentralView() {
        let big = StressProjectGenerator.makeProject(scenes: 300,
                                                    shotsPerScene: 12)
        Self.note("project] scenes=\(big.sequences.flatMap(\.scenes).count) "
            + "shots=\(big.sequences.flatMap(\.scenes).flatMap(\.shots).count) "
            + "characters=\(big.characters.count)")

        let views: [AppView] = [.overview, .script, .bubble, .shotList,
                                .scenes, .assets, .production, .storyDesign,
                                .curation, .playback, .settings]
        for view in views {
            autoreleasepool {
                let start = DispatchTime.now().uptimeNanoseconds
                let (window, _, projectViewModel, tick) =
                    hostRouter(project: big, view: view)
                tick()
                let mountMs = Double(DispatchTime.now().uptimeNanoseconds
                                     - start) / 1e6
                // One project publish against the mounted view — the
                // "any change anywhere" cost the user pays constantly.
                let publishStart = DispatchTime.now().uptimeNanoseconds
                for _ in 0..<10 {
                    projectViewModel.objectWillChange.send()
                    tick()
                }
                let publishMs = Double(DispatchTime.now().uptimeNanoseconds
                                       - publishStart) / 1e6 / 10
                Self.note("\(view.rawValue)] mount \(Int(mountMs))ms, "
                    + "publish \(String(format: "%.1f", publishMs))ms/tick")
                XCTAssertLessThan(mountMs, 30_000,
                    "\(view.rawValue) took \(Int(mountMs))ms to mount a "
                    + "300-scene project — scale cliff")
                window.orderOut(nil)
            }
        }
    }

    func testBlockbusterHeadroom() {
        // Interstellar/Avengers scale: production breakdowns run to
        // thousands of shots. 600 scenes × 12 = 7,200 shots, ~20k
        // script elements — double the standard audit board.
        let huge = StressProjectGenerator.makeProject(scenes: 600,
                                                      shotsPerScene: 12)
        for view in [AppView.script, .shotList, .storyDesign, .overview] {
            autoreleasepool {
                let start = DispatchTime.now().uptimeNanoseconds
                let (window, _, projectViewModel, tick) =
                    hostRouter(project: huge, view: view)
                tick()
                let mountMs = Double(DispatchTime.now().uptimeNanoseconds
                                     - start) / 1e6
                let publishStart = DispatchTime.now().uptimeNanoseconds
                for _ in 0..<5 {
                    projectViewModel.objectWillChange.send()
                    tick()
                }
                let publishMs = Double(DispatchTime.now().uptimeNanoseconds
                                       - publishStart) / 1e6 / 5
                Self.note("XL-\(view.rawValue)] mount \(Int(mountMs))ms, "
                    + "publish \(String(format: "%.1f", publishMs))ms/tick")
                XCTAssertLessThan(mountMs, 60_000)
                window.orderOut(nil)
            }
        }
    }

    func testModelPathsAtScale() throws {
        let big = StressProjectGenerator.makeProject(scenes: 300,
                                                     shotsPerScene: 12)
        var start = DispatchTime.now().uptimeNanoseconds
        let data = try JSONEncoder().encode(big)
        Self.note("encode-save] \(Int(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6))ms, \(data.count / 1024)KB")

        start = DispatchTime.now().uptimeNanoseconds
        _ = try JSONDecoder().decode(Project.self, from: data)
        Self.note("decode-open] \(Int(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6))ms")

        start = DispatchTime.now().uptimeNanoseconds
        _ = ProjectToScriptConverter.convert(from: big)
        Self.note("script-convert] \(Int(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6))ms")

        start = DispatchTime.now().uptimeNanoseconds
        let timeline = TimelineViewModel()
        timeline.setProject(big)
        timeline.refresh()
        Self.note("timeline-rebuild] \(Int(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6))ms")
    }
}
