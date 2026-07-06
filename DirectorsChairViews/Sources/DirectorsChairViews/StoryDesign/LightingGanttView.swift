// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/LightingGanttView.swift
//
// Gantt chart view for lighting choreography — shows all light cues, SFX cues, and support cues as horizontal bars

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore

enum GanttCategoryFilter: String, CaseIterable {
    case all, lighting, sfx, support
    var label: String {
        switch self {
        case .all: return "All"
        case .lighting: return "Lighting"
        case .sfx: return "SFX"
        case .support: return "Support"
        }
    }
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .lighting: return "light.max"
        case .sfx: return "sparkles"
        case .support: return "person.2.fill"
        }
    }
}

struct LightingGanttView: View {
    @Binding var project: Project
    var markers: [TimelineMarker] = []
    var onCueDoubleClicked: ((String) -> Void)? = nil
    var onSFXCueDoubleClicked: ((String) -> Void)? = nil
    var onSupportCueDoubleClicked: ((String) -> Void)? = nil
    var onCueClicked: ((String) -> Void)? = nil
    var onSFXCueClicked: ((String) -> Void)? = nil
    var onSupportCueClicked: ((String) -> Void)? = nil
    var selectedCueId: String? = nil

    @State var pxPerSec: CGFloat = 8.0
    @State var workflowFilter: LightingWorkflow? = nil
    @State var categoryFilter: GanttCategoryFilter = .all
    @State var hoveredCueId: String? = nil
    @State var horizontalScrollOffset: CGFloat = 0

    let rowHeight: CGFloat = 40
    let labelWidth: CGFloat = 220
    let rulerHeight: CGFloat = 28
    let sfxAccent = Color(hex: "#FF6B35")
    let supportAccent = Color(hex: "#2DD4BF")

    var showLighting: Bool { categoryFilter == .all || categoryFilter == .lighting }
    var showSFX: Bool { categoryFilter == .all || categoryFilter == .sfx }
    var showSupport: Bool { categoryFilter == .all || categoryFilter == .support }

    var filteredCues: [LightCue] {
        guard showLighting else { return [] }
        let cues = project.lightCues.filter { $0.isActive }
        if let filter = workflowFilter {
            return cues.filter { $0.workflow == filter }
        }
        return cues
    }

    var filteredSFXCues: [SFXCue] {
        guard showSFX else { return [] }
        return project.sfxCues.filter { $0.isActive }.sorted { $0.startTime < $1.startTime }
    }

    var filteredSupportCues: [SupportCue] {
        guard showSupport else { return [] }
        return project.supportCues.filter { $0.isActive }.sorted { $0.startTime < $1.startTime }
    }

    var totalDuration: CGFloat {
        let lightMax = filteredCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let sfxMax = filteredSFXCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let supportMax = filteredSupportCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        return max(max(max(lightMax, sfxMax), supportMax) + 10, 30)
    }

    var timelineWidth: CGFloat {
        totalDuration * pxPerSec
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ganttContent
        }
    }
}
