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
