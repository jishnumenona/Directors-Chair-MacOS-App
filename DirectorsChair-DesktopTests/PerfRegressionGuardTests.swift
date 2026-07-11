// PerfRegressionGuardTests.swift
//
// A CATASTROPHIC-regression guard for the hot paths, safe to gate in CI.
//
// The XCTClockMetric baselines in PerformanceBaselineTests report timings but
// don't assert — and a tight timing assertion would flake on shared CI
// runners whose hardware varies run-to-run. This guard instead asserts
// GENEROUS ceilings: far above the measured post-Tier-1 baselines, but far
// below the pre-optimization numbers. It catches an algorithmic regression
// (e.g. the editor returning to full-document rebuilds — the 529ms/20 world)
// without failing on ordinary runner noise.
//
// Baselines (local, 2026): Return burst ~33ms/20, convert ~6ms. Ceilings are
// set at roughly 6–10× to absorb slow runners while still catching a real
// regression, which is typically an order of magnitude.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore

@MainActor
final class PerfRegressionGuardTests: XCTestCase {

    static var stressProject: Project!
    override class func setUp() {
        super.setUp()
        stressProject = StressProjectGenerator.makeProject()
    }
    private var project: Project { Self.stressProject }

    private func elapsedMs(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    /// Project → script conversion must not become O(worse). Baseline ~6ms.
    func testConvertStaysFast() {
        let ms = elapsedMs { _ = ProjectToScriptConverter.convert(from: project) }
        XCTAssertLessThan(ms, 120, "convert(from:) took \(Int(ms))ms — a regression (baseline ~6ms)")
    }

    /// 20 structural Return edits must stay far below the pre-Tier-1 529ms.
    /// Baseline ~33ms; ceiling 300ms catches the full-rebuild regression.
    func testReturnBurstStaysFast() {
        let pvm = ProjectViewModel(); pvm.project = project
        let vm = ScriptViewModel(); vm.loadFromProject(project, projectViewModel: pvm)
        let base = vm.elements
        let ms = elapsedMs {
            vm.elements = base
            let step = max(1, vm.elements.count / 20)
            for i in 0..<20 {
                let idx = min(i * step + 5, vm.elements.count - 1)
                _ = vm.handleReturn(atElementIndex: idx, cursorOffset: 0)
            }
        }
        XCTAssertLessThan(ms, 300, "20 Return edits took \(Int(ms))ms — a regression (baseline ~33ms, pre-Tier-1 was 529ms)")
    }

    /// The 4 stat passes on a large script must stay bounded. Baseline ~26ms.
    func testStatsPassesStayFast() {
        let pvm = ProjectViewModel(); pvm.project = project
        let vm = ScriptViewModel(); vm.loadFromProject(project, projectViewModel: pvm)
        let elements = vm.elements
        let ms = elapsedMs {
            _ = ScreenplayFormatting.estimatePageCount(from: elements)
            _ = ScreenplayFormatting.wordCount(from: elements)
            _ = ScreenplayFormatting.computeStats(from: elements)
            _ = ProjectToScriptConverter.extractSceneOutline(from: elements)
        }
        XCTAssertLessThan(ms, 250, "stat passes took \(Int(ms))ms — a regression (baseline ~26ms)")
    }
}
