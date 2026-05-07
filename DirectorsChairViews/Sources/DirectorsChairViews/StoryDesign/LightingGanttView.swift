// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/LightingGanttView.swift
//
// Gantt chart view for lighting choreography — shows all light cues, SFX cues, and support cues as horizontal bars

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore

private enum GanttCategoryFilter: String, CaseIterable {
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

    @State private var pxPerSec: CGFloat = 8.0
    @State private var workflowFilter: LightingWorkflow? = nil
    @State private var categoryFilter: GanttCategoryFilter = .all
    @State private var hoveredCueId: String? = nil

    private let rowHeight: CGFloat = 40
    private let labelWidth: CGFloat = 220
    private let rulerHeight: CGFloat = 28
    private let sfxAccent = Color(hex: "#FF6B35")
    private let supportAccent = Color(hex: "#2DD4BF")

    private var showLighting: Bool { categoryFilter == .all || categoryFilter == .lighting }
    private var showSFX: Bool { categoryFilter == .all || categoryFilter == .sfx }
    private var showSupport: Bool { categoryFilter == .all || categoryFilter == .support }

    private var filteredCues: [LightCue] {
        guard showLighting else { return [] }
        let cues = project.lightCues.filter { $0.isActive }
        if let filter = workflowFilter {
            return cues.filter { $0.workflow == filter }
        }
        return cues
    }

    private var filteredSFXCues: [SFXCue] {
        guard showSFX else { return [] }
        return project.sfxCues.filter { $0.isActive }.sorted { $0.startTime < $1.startTime }
    }

    private var filteredSupportCues: [SupportCue] {
        guard showSupport else { return [] }
        return project.supportCues.filter { $0.isActive }.sorted { $0.startTime < $1.startTime }
    }

    private var totalDuration: CGFloat {
        let lightMax = filteredCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let sfxMax = filteredSFXCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let supportMax = filteredSupportCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        return max(max(max(lightMax, sfxMax), supportMax) + 10, 30)
    }

    private var timelineWidth: CGFloat {
        totalDuration * pxPerSec
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ganttContent
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            // Category filter chips
            HStack(spacing: 4) {
                ForEach(GanttCategoryFilter.allCases, id: \.self) { cat in
                    GanttFilterChip(label: cat.label, icon: cat.icon, isSelected: categoryFilter == cat) {
                        categoryFilter = cat
                    }
                }
            }

            // Workflow filter chips (only when lighting visible)
            if showLighting {
                HStack(spacing: 4) {
                    GanttFilterChip(label: "All", icon: "light.max", isSelected: workflowFilter == nil) {
                        workflowFilter = nil
                    }
                    GanttFilterChip(label: "Cinema", icon: "film", isSelected: workflowFilter == .cinema) {
                        workflowFilter = .cinema
                    }
                    GanttFilterChip(label: "Theater", icon: "theatermasks", isSelected: workflowFilter == .theater) {
                        workflowFilter = .theater
                    }
                }
            }

            Spacer()

            // Cue count
            let totalCount = filteredCues.count + filteredSFXCues.count + filteredSupportCues.count
            Text("\(totalCount) cue\(totalCount == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(4)

            // Export menu
            Menu {
                Button("Export as CSV") { exportCSV() }
                Button("Export as HTML Timeline") { exportHTML() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10))
                    Text("Export")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .quaternarySystemFill)))
                .foregroundColor(.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Zoom
            HStack(spacing: 6) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .onTapGesture { pxPerSec = max(2, pxPerSec - 2) }

                Slider(value: $pxPerSec, in: 2...20, step: 1)
                    .frame(width: 80)
                    .controlSize(.mini)

                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .onTapGesture { pxPerSec = min(20, pxPerSec + 2) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Gantt Content

    private var totalRowCount: Int {
        var count = filteredCues.count
        if !filteredSFXCues.isEmpty { count += filteredSFXCues.count + 1 } // +1 for section header
        if !filteredSupportCues.isEmpty { count += filteredSupportCues.count + 1 } // +1 for section header
        return count
    }

    @State private var horizontalScrollOffset: CGFloat = 0

    private var ganttContent: some View {
        VStack(spacing: 0) {
            // Header row: corner + time ruler (pinned, always visible)
            HStack(spacing: 0) {
                // Corner cell (fixed)
                Text(showLighting ? "LIGHT CUE" : (showSFX ? "SFX CUE" : "SUPPORT CUE"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                    .frame(width: labelWidth, height: rulerHeight)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

                // Time ruler (clips to match horizontal scroll of timeline below)
                GeometryReader { _ in
                    timeRuler
                        .frame(width: timelineWidth, height: rulerHeight)
                        .offset(x: -horizontalScrollOffset)
                }
                .clipped()
                .frame(height: rulerHeight)
            }

            Divider()

            // Scrollable rows (fills remaining space)
            ScrollView(.vertical, showsIndicators: true) {
                // Rows: fixed labels + scrollable timeline
                HStack(alignment: .top, spacing: 0) {
                    // Label column (fixed, not inside horizontal scroll)
                    VStack(spacing: 0) {
                        // Lighting rows
                        ForEach(Array(filteredCues.enumerated()), id: \.element.id) { idx, cue in
                            cueLabel(cue: cue, index: idx)
                        }

                        // SFX section
                        if !filteredSFXCues.isEmpty {
                            sfxSectionHeader
                            ForEach(Array(filteredSFXCues.enumerated()), id: \.element.id) { idx, cue in
                                sfxCueLabel(cue: cue, index: idx)
                            }
                        }

                        // Support section
                        if !filteredSupportCues.isEmpty {
                            supportSectionHeader
                            ForEach(Array(filteredSupportCues.enumerated()), id: \.element.id) { idx, cue in
                                supportCueLabel(cue: cue, index: idx)
                            }
                        }
                    }
                    .frame(width: labelWidth, height: CGFloat(totalRowCount) * rowHeight)

                    // Timeline area (scrolls horizontally)
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            ganttGrid

                            // Lighting bars
                            ForEach(Array(filteredCues.enumerated()), id: \.element.id) { idx, cue in
                                ganttBar(cue: cue, rowIndex: idx)
                            }

                            // SFX bars
                            if !filteredSFXCues.isEmpty {
                                let sfxOffset = filteredCues.count + 1 // +1 for section header
                                ForEach(Array(filteredSFXCues.enumerated()), id: \.element.id) { idx, cue in
                                    sfxGanttBar(cue: cue, rowIndex: sfxOffset + idx)
                                }
                            }

                            // Support bars
                            if !filteredSupportCues.isEmpty {
                                let supportOffset = filteredCues.count + (filteredSFXCues.isEmpty ? 0 : filteredSFXCues.count + 1) + 1
                                ForEach(Array(filteredSupportCues.enumerated()), id: \.element.id) { idx, cue in
                                    supportGanttBar(cue: cue, rowIndex: supportOffset + idx)
                                }
                            }

                            // Markers overlay
                            ForEach(markers) { marker in
                                let x = marker.time * pxPerSec
                                markerLine(marker: marker, x: x, height: CGFloat(totalRowCount) * rowHeight)
                            }
                        }
                        .frame(width: timelineWidth, height: CGFloat(totalRowCount) * rowHeight)
                        .background(
                            GeometryReader { innerGeo in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: -innerGeo.frame(in: .named("ganttHScroll")).origin.x
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: "ganttHScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        horizontalScrollOffset = value
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Time Ruler

    private var timeRuler: some View {
        Canvas { context, size in
            let tickInterval = rulerTickInterval
            let totalTicks = Int(totalDuration / tickInterval) + 1

            for i in 0..<totalTicks {
                let time = CGFloat(i) * tickInterval
                let x = time * pxPerSec

                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: x, y: size.height - 8))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(Color(nsColor: .tertiaryLabelColor)),
                    lineWidth: 0.5
                )

                let label = DurationEstimator.formatTime(time)
                let text = Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                context.draw(context.resolve(text), at: CGPoint(x: x + 2, y: size.height / 2 - 2), anchor: .leading)
            }

            // Draw marker diamonds on ruler
            for marker in markers {
                let x = marker.time * pxPerSec
                let markerColor = Color(hex: marker.color)
                let diamondSize: CGFloat = 5

                // Diamond shape
                let diamondPath = Path { path in
                    path.move(to: CGPoint(x: x, y: size.height - diamondSize * 2))
                    path.addLine(to: CGPoint(x: x + diamondSize, y: size.height - diamondSize))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x - diamondSize, y: size.height - diamondSize))
                    path.closeSubpath()
                }
                context.fill(diamondPath, with: .color(markerColor))

                // Label
                let markerText = Text(marker.label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(markerColor)
                context.draw(context.resolve(markerText), at: CGPoint(x: x + diamondSize + 2, y: size.height - diamondSize), anchor: .leading)
            }
        }
    }

    private var rulerTickInterval: CGFloat {
        if pxPerSec >= 15 { return 5 }
        if pxPerSec >= 8 { return 10 }
        if pxPerSec >= 4 { return 30 }
        return 60
    }

    // MARK: - Marker Line

    private func markerLine(marker: TimelineMarker, x: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: marker.color).opacity(0.6))
                .frame(width: 1, height: height)
        }
        .offset(x: x)
        .allowsHitTesting(false)
        .help("\(marker.label)")
    }

    // MARK: - Cue Label

    private func cueLabel(cue: LightCue, index: Int) -> some View {
        HStack(spacing: 6) {
            // Fixture icon
            Image(systemName: cue.fixtureType.icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: cue.markerColor))
                .frame(width: 14)

            // Cue number + name + fixture type
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(cue.cueNumber)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(cue.name)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(cue.fixtureType.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(1)
            }

            Spacer()

            // Intensity %
            Text("\(Int(cue.intensity * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary)

            // Color swatch
            Circle()
                .fill(Color(hex: cue.color))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .frame(width: labelWidth, height: rowHeight)
        .background(
            selectedCueId == cue.id
                ? Color.accentColor.opacity(0.15)
                : (hoveredCueId == cue.id
                    ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.1)
                    : (index % 2 == 0 ? Color.clear : Color(nsColor: .quaternarySystemFill).opacity(0.3)))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onCueClicked?(cue.id)
        }
        .onHover { isHovering in
            hoveredCueId = isHovering ? cue.id : nil
        }
    }

    // MARK: - Grid

    private var ganttGrid: some View {
        Canvas { context, size in
            let tickInterval = rulerTickInterval
            let totalTicks = Int(totalDuration / tickInterval) + 1
            let rows = totalRowCount

            for i in 0..<totalTicks {
                let x = CGFloat(i) * tickInterval * pxPerSec
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(Color(nsColor: .separatorColor).opacity(0.2)),
                    lineWidth: 0.5
                )
            }

            for i in 0...rows {
                let y = CGFloat(i) * rowHeight
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(Color(nsColor: .separatorColor).opacity(0.15)),
                    lineWidth: 0.5
                )
            }

            for i in 0..<rows where i % 2 == 1 {
                let rect = CGRect(x: 0, y: CGFloat(i) * rowHeight, width: size.width, height: rowHeight)
                context.fill(Path(rect), with: .color(Color(nsColor: .quaternarySystemFill).opacity(0.3)))
            }
        }
        .frame(width: timelineWidth, height: CGFloat(totalRowCount) * rowHeight)
    }

    // MARK: - Gantt Bar (Lighting)

    private func ganttBar(cue: LightCue, rowIndex: Int) -> some View {
        let x = CGFloat(cue.startTime) * pxPerSec
        let width = CGFloat(cue.duration) * pxPerSec
        let y = CGFloat(rowIndex) * rowHeight + 5
        let barHeight = rowHeight - 10
        let isSelected = selectedCueId == cue.id

        return GanttBarShape(
            cue: cue,
            barWidth: width,
            barHeight: barHeight,
            pxPerSec: pxPerSec,
            isSelected: isSelected
        )
        .frame(width: max(width, 2), height: barHeight)
        .offset(x: x, y: y)
        .help("\(cue.cueNumber) — \(cue.name)\nFixture: \(cue.fixtureType.rawValue)\nWorkflow: \(cue.workflow.rawValue)\nIntensity: \(Int(cue.intensity * 100))%\nDuration: \(String(format: "%.1f", cue.duration))s\nPosition: \(cue.position.rawValue)\nFade In: \(String(format: "%.1f", cue.fadeInDuration))s\nFade Out: \(String(format: "%.1f", cue.fadeOutDuration))s")
        .onTapGesture {
            onCueClicked?(cue.id)
        }
        .onHover { isHovering in
            hoveredCueId = isHovering ? cue.id : nil
        }
    }

    // MARK: - SFX Section Header

    private var sfxSectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundColor(sfxAccent)
            Text("SPECIAL EFFECTS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(sfxAccent)
                .tracking(1.0)
            Spacer()
            Text("\(filteredSFXCues.count)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: labelWidth, height: rowHeight)
        .background(sfxAccent.opacity(0.06))
    }

    // MARK: - SFX Cue Label

    private func sfxCueLabel(cue: SFXCue, index: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: cue.effectType.icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: cue.markerColor))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(cue.cueNumber)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(cue.name)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(cue.effectType.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(1)
            }

            Spacer()

            Text("\(Int(cue.intensity * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary)

            Circle()
                .fill(Color(hex: cue.color))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .frame(width: labelWidth, height: rowHeight)
        .background(
            selectedCueId == cue.id
                ? sfxAccent.opacity(0.15)
                : (hoveredCueId == cue.id
                    ? sfxAccent.opacity(0.1)
                    : (index % 2 == 0 ? Color.clear : Color(nsColor: .quaternarySystemFill).opacity(0.3)))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSFXCueClicked?(cue.id)
        }
        .onHover { isHovering in
            hoveredCueId = isHovering ? cue.id : nil
        }
    }

    // MARK: - SFX Gantt Bar

    private func sfxGanttBar(cue: SFXCue, rowIndex: Int) -> some View {
        let x = CGFloat(cue.startTime) * pxPerSec
        let width = CGFloat(cue.duration) * pxPerSec
        let y = CGFloat(rowIndex) * rowHeight + 5
        let barHeight = rowHeight - 10
        let isSelected = selectedCueId == cue.id

        return SFXGanttBarShape(
            cue: cue,
            barWidth: width,
            barHeight: barHeight,
            pxPerSec: pxPerSec,
            isSelected: isSelected
        )
        .frame(width: max(width, 2), height: barHeight)
        .offset(x: x, y: y)
        .help("\(cue.cueNumber) — \(cue.name)\nEffect: \(cue.effectType.rawValue)\nIntensity: \(Int(cue.intensity * 100))%\nProfile: \(cue.intensityProfile.rawValue)\nDuration: \(String(format: "%.1f", cue.duration))s\nPlacement: \(cue.placement.rawValue)\nCoverage: \(Int(cue.coverage * 100))%")
        .onTapGesture {
            onSFXCueClicked?(cue.id)
        }
        .onHover { isHovering in
            hoveredCueId = isHovering ? cue.id : nil
        }
    }

    // MARK: - Support Section Header

    private var supportSectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
                .foregroundColor(supportAccent)
            Text("SUPPORT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(supportAccent)
                .tracking(1.0)
            Spacer()
            Text("\(filteredSupportCues.count)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: labelWidth, height: rowHeight)
        .background(supportAccent.opacity(0.06))
    }

    // MARK: - Support Cue Label

    private func supportCueLabel(cue: SupportCue, index: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: cue.actionType.icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: cue.markerColor))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(cue.cueNumber)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(cue.name)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(cue.actionType.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(1)
            }

            Spacer()

            Text(cue.priority.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(width: labelWidth, height: rowHeight)
        .background(
            selectedCueId == cue.id
                ? supportAccent.opacity(0.15)
                : (hoveredCueId == cue.id
                    ? supportAccent.opacity(0.1)
                    : (index % 2 == 0 ? Color.clear : Color(nsColor: .quaternarySystemFill).opacity(0.3)))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSupportCueClicked?(cue.id)
        }
        .onHover { isHovering in
            hoveredCueId = isHovering ? cue.id : nil
        }
    }

    // MARK: - Support Gantt Bar

    private func supportGanttBar(cue: SupportCue, rowIndex: Int) -> some View {
        let x = CGFloat(cue.startTime) * pxPerSec
        let width = CGFloat(cue.duration) * pxPerSec
        let y = CGFloat(rowIndex) * rowHeight + 5
        let barHeight = rowHeight - 10
        let isSelected = selectedCueId == cue.id

        return SupportGanttBarShape(
            cue: cue,
            barWidth: width,
            barHeight: barHeight,
            isSelected: isSelected
        )
        .frame(width: max(width, 2), height: barHeight)
        .offset(x: x, y: y)
        .help("\(cue.cueNumber) — \(cue.name)\nAction: \(cue.actionType.rawValue)\nPriority: \(cue.priority.rawValue)\nAssigned: \(cue.assignedTo.isEmpty ? "Unassigned" : cue.assignedTo)\nStage Area: \(cue.stageArea.rawValue)\nDuration: \(String(format: "%.1f", cue.duration))s")
        .onTapGesture {
            onSupportCueClicked?(cue.id)
        }
        .onHover { isHovering in
            hoveredCueId = isHovering ? cue.id : nil
        }
    }

    // MARK: - CSV Export

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Export Cue Sheet"
        panel.nameFieldStringValue = "cue_sheet.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var csv = ""

        // Lighting section
        if !filteredCues.isEmpty {
            csv += "--- LIGHTING CUES ---\n"
            csv += "Cue #,Cue Name,Fixture Type,Workflow,Start Time (s),Duration (s),End Time (s),Start Time (MM:SS),End Time (MM:SS),Intensity (%),End Intensity (%),Color (Hex),Color Temp (K),Gel Filter,Position,Angle,Elevation,Transition In,Fade In (s),Transition Out,Fade Out (s),Motivation,DMX Channel,DMX Universe,Gobo,Scene,Notes\n"

            for cue in filteredCues {
                let endTime = cue.startTime + cue.duration
                let startFormatted = DurationEstimator.formatTime(CGFloat(cue.startTime))
                let endFormatted = DurationEstimator.formatTime(CGFloat(endTime))
                let endIntensity = cue.intensityEnd.map { "\(Int($0 * 100))" } ?? ""
                let colorTemp = cue.colorTemperature.map { "\($0)" } ?? ""
                let gel = csvEscape(cue.gelFilter ?? "")
                let posCustom = cue.position == .custom ? (cue.positionCustom ?? cue.position.rawValue) : cue.position.rawValue
                let angle = cue.angle.map { "\(Int($0))" } ?? ""
                let elevation = cue.elevation.map { "\(Int($0))" } ?? ""
                let dmxCh = cue.dmxChannel.map { "\($0)" } ?? ""
                let dmxUni = cue.dmxUniverse.map { "\($0)" } ?? ""
                let gobo = csvEscape(cue.goboPattern ?? "")
                let scene = csvEscape(cue.sceneName ?? "")
                let notes = csvEscape(cue.notes)

                csv += "\(csvEscape(cue.cueNumber)),\(csvEscape(cue.name)),\(csvEscape(cue.fixtureType.rawValue)),\(cue.workflow.rawValue),\(String(format: "%.1f", cue.startTime)),\(String(format: "%.1f", cue.duration)),\(String(format: "%.1f", endTime)),\(startFormatted),\(endFormatted),\(Int(cue.intensity * 100)),\(endIntensity),\(cue.color),\(colorTemp),\(gel),\(csvEscape(posCustom)),\(angle),\(elevation),\(cue.transitionIn.rawValue),\(String(format: "%.1f", cue.fadeInDuration)),\(cue.transitionOut.rawValue),\(String(format: "%.1f", cue.fadeOutDuration)),\(cue.motivation.rawValue),\(dmxCh),\(dmxUni),\(gobo),\(scene),\(notes)\n"
            }
        }

        // SFX section
        if !filteredSFXCues.isEmpty {
            csv += "\n--- SPECIAL EFFECTS CUES ---\n"
            csv += "Cue #,Cue Name,Effect Type,Start Time (s),Duration (s),End Time (s),Start Time (MM:SS),End Time (MM:SS),Intensity (%),End Intensity (%),Intensity Profile,Color (Hex),Placement,Coverage (%),Transition In,Fade In (s),Transition Out,Fade Out (s),Requires Ventilation,Operator Required,Safety Notes,Notes\n"

            for cue in filteredSFXCues {
                let endTime = cue.startTime + cue.duration
                let startFormatted = DurationEstimator.formatTime(CGFloat(cue.startTime))
                let endFormatted = DurationEstimator.formatTime(CGFloat(endTime))
                let endIntensity = cue.intensityEnd.map { "\(Int($0 * 100))" } ?? ""
                let coverage = Int(cue.coverage * 100)
                let safetyNotes = csvEscape(cue.safetyNotes)
                let notes = csvEscape(cue.notes)

                csv += "\(csvEscape(cue.cueNumber)),\(csvEscape(cue.name)),\(cue.effectType.rawValue),\(String(format: "%.1f", cue.startTime)),\(String(format: "%.1f", cue.duration)),\(String(format: "%.1f", endTime)),\(startFormatted),\(endFormatted),\(Int(cue.intensity * 100)),\(endIntensity),\(cue.intensityProfile.rawValue),\(cue.color),\(cue.placement.rawValue),\(coverage),\(cue.transitionIn.rawValue),\(String(format: "%.1f", cue.fadeInDuration)),\(cue.transitionOut.rawValue),\(String(format: "%.1f", cue.fadeOutDuration)),\(cue.requiresVentilation),\(cue.operatorRequired),\(safetyNotes),\(notes)\n"
            }
        }

        // Support section
        if !filteredSupportCues.isEmpty {
            csv += "\n--- SUPPORT CUES ---\n"
            csv += "Cue #,Cue Name,Action Type,Start Time (s),Duration (s),End Time (s),Start Time (MM:SS),End Time (MM:SS),Priority,Stage Area,Assigned To,Equipment,Safety Notes,Notes\n"

            for cue in filteredSupportCues {
                let endTime = cue.startTime + cue.duration
                let startFormatted = DurationEstimator.formatTime(CGFloat(cue.startTime))
                let endFormatted = DurationEstimator.formatTime(CGFloat(endTime))
                let equipment = csvEscape(cue.equipment)
                let safetyNotes = csvEscape(cue.safetyNotes)
                let notes = csvEscape(cue.notes)

                csv += "\(csvEscape(cue.cueNumber)),\(csvEscape(cue.name)),\(cue.actionType.rawValue),\(String(format: "%.1f", cue.startTime)),\(String(format: "%.1f", cue.duration)),\(String(format: "%.1f", endTime)),\(startFormatted),\(endFormatted),\(cue.priority.rawValue),\(cue.stageArea.rawValue),\(csvEscape(cue.assignedTo)),\(equipment),\(safetyNotes),\(notes)\n"
            }
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - HTML Timeline Export

    private func exportHTML() {
        let panel = NSSavePanel()
        panel.title = "Export Cue Timeline (HTML)"
        panel.nameFieldStringValue = "cue_timeline.html"
        panel.allowedContentTypes = [UTType.html]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let allCues = filteredCues
        let allSFX = filteredSFXCues
        let allSupport = filteredSupportCues

        let maxTime = max(
            allCues.map { $0.startTime + $0.duration }.max() ?? 0,
            allSFX.map { $0.startTime + $0.duration }.max() ?? 0,
            allSupport.map { $0.startTime + $0.duration }.max() ?? 0
        )
        let dur = max(maxTime + 10, 30)
        let pps: Double = 10
        let tw = Int(dur * pps)
        let lw = 180
        let rh = 40
        let rulerH = 32

        let lightCount = allCues.count
        let sfxCount = allSFX.count
        let supportCount = allSupport.count
        let sections = (lightCount > 0 ? 1 : 0) + (sfxCount > 0 ? 1 : 0) + (supportCount > 0 ? 1 : 0)
        let totalRows = lightCount + sfxCount + supportCount + sections
        let ch = totalRows * rh

        let tickInterval: Double = dur > 300 ? 60 : (dur > 120 ? 30 : (dur > 60 ? 15 : 10))
        let dateStr = Self.currentDateString()

        var html = Self.stickyHTMLHead(tw: tw, lw: lw, rh: rh, rulerH: rulerH, ch: ch, pps: pps, dateStr: dateStr)

        // Time ticks
        var tick: Double = 0
        while tick <= dur {
            let x = Int(tick * pps)
            html += "<span class=\"tick\" style=\"left:\(x)px\">\(Self.fmtMMSS(tick))</span>"
            tick += tickInterval
        }
        html += "</div></div>\n"

        // Labels column
        html += "<div class=\"labels-column\">\n"
        if !allCues.isEmpty {
            html += "<div class=\"section-label light\">Lighting</div>\n"
            for cue in allCues {
                html += "<div class=\"label-row\"><span class=\"cue-num\" style=\"color:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber))</span>\(Self.htmlEsc(cue.name))</div>\n"
            }
        }
        if !allSFX.isEmpty {
            html += "<div class=\"section-label sfx\">Special Effects</div>\n"
            for cue in allSFX {
                html += "<div class=\"label-row\"><span class=\"cue-num\" style=\"color:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber))</span>\(Self.htmlEsc(cue.name))</div>\n"
            }
        }
        if !allSupport.isEmpty {
            html += "<div class=\"section-label support\">Support</div>\n"
            for cue in allSupport {
                html += "<div class=\"label-row\"><span class=\"cue-num\" style=\"color:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber))</span>\(Self.htmlEsc(cue.name))</div>\n"
            }
        }
        html += "</div>\n<div class=\"timeline-content\">\n"

        // Timeline bars
        var rowIdx = 0
        if !allCues.isEmpty {
            html += "<div class=\"section-row\" style=\"top:\(rowIdx * rh)px\"></div>\n"
            rowIdx += 1
            for cue in allCues {
                let y = rowIdx * rh
                let x = Int(cue.startTime * pps)
                let w = max(Int(cue.duration * pps), 24)
                let fiW = Int(cue.fadeInDuration * pps)
                let foW = Int(cue.fadeOutDuration * pps)
                let cls = (fiW > 0 || foW > 0) ? " has-fade" : ""
                let fv = (fiW > 0 || foW > 0) ? "--fade-in-w:\(fiW)px;--fade-out-w:\(foW)px;" : ""
                let end = cue.startTime + cue.duration
                html += "<div class=\"timeline-row\" style=\"top:\(y)px\"><div class=\"cue-bar\(cls)\" style=\"left:\(x)px;width:\(w)px;background:\(cue.markerColor);\(fv)\">\(Self.htmlEsc(cue.cueNumber)) \(Self.htmlEsc(cue.name))<div class=\"tooltip\"><strong>\(Self.htmlEsc(cue.cueNumber)) \u{2014} \(Self.htmlEsc(cue.name))</strong><div class=\"tt-row\">Type: \(cue.fixtureType.rawValue) (\(cue.workflow.rawValue))</div><div class=\"tt-row\">Time: \(Self.fmtMMSS(cue.startTime)) \u{2192} \(Self.fmtMMSS(end)) (\(String(format: "%.1f", cue.duration))s)</div><div class=\"tt-row\">Intensity: \(Int(cue.intensity * 100))%</div><div class=\"tt-row\">Fade: In \(String(format: "%.1f", cue.fadeInDuration))s / Out \(String(format: "%.1f", cue.fadeOutDuration))s</div></div></div></div>\n"
                rowIdx += 1
            }
        }
        if !allSFX.isEmpty {
            html += "<div class=\"section-row\" style=\"top:\(rowIdx * rh)px\"></div>\n"
            rowIdx += 1
            for cue in allSFX {
                let y = rowIdx * rh
                let x = Int(cue.startTime * pps)
                let w = max(Int(cue.duration * pps), 24)
                let fiW = Int(cue.fadeInDuration * pps)
                let foW = Int(cue.fadeOutDuration * pps)
                let cls = (fiW > 0 || foW > 0) ? " has-fade" : ""
                let fv = (fiW > 0 || foW > 0) ? "--fade-in-w:\(fiW)px;--fade-out-w:\(foW)px;" : ""
                let end = cue.startTime + cue.duration
                html += "<div class=\"timeline-row\" style=\"top:\(y)px\"><div class=\"cue-bar\(cls)\" style=\"left:\(x)px;width:\(w)px;background:\(cue.markerColor);\(fv)\">\(Self.htmlEsc(cue.cueNumber)) \(Self.htmlEsc(cue.name))<div class=\"tooltip\"><strong>\(Self.htmlEsc(cue.cueNumber)) \u{2014} \(Self.htmlEsc(cue.name))</strong><div class=\"tt-row\">Effect: \(cue.effectType.rawValue)</div><div class=\"tt-row\">Time: \(Self.fmtMMSS(cue.startTime)) \u{2192} \(Self.fmtMMSS(end)) (\(String(format: "%.1f", cue.duration))s)</div><div class=\"tt-row\">Intensity: \(Int(cue.intensity * 100))% (\(cue.intensityProfile.rawValue))</div><div class=\"tt-row\">Placement: \(cue.placement.rawValue) | Coverage: \(Int(cue.coverage * 100))%</div></div></div></div>\n"
                rowIdx += 1
            }
        }
        if !allSupport.isEmpty {
            html += "<div class=\"section-row\" style=\"top:\(rowIdx * rh)px\"></div>\n"
            rowIdx += 1
            for cue in allSupport {
                let y = rowIdx * rh
                let x = Int(cue.startTime * pps)
                let w = max(Int(cue.duration * pps), 24)
                let end = cue.startTime + cue.duration
                html += "<div class=\"timeline-row\" style=\"top:\(y)px\"><div class=\"cue-bar\" style=\"left:\(x)px;width:\(w)px;background:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber)) \(Self.htmlEsc(cue.name))<div class=\"tooltip\"><strong>\(Self.htmlEsc(cue.cueNumber)) \u{2014} \(Self.htmlEsc(cue.name))</strong><div class=\"tt-row\">Action: \(cue.actionType.rawValue)</div><div class=\"tt-row\">Time: \(Self.fmtMMSS(cue.startTime)) \u{2192} \(Self.fmtMMSS(end)) (\(String(format: "%.1f", cue.duration))s)</div><div class=\"tt-row\">Priority: \(cue.priority.rawValue) | Area: \(cue.stageArea.rawValue)</div><div class=\"tt-row\">Assigned: \(cue.assignedTo.isEmpty ? "Unassigned" : Self.htmlEsc(cue.assignedTo))</div></div></div></div>\n"
                rowIdx += 1
            }
        }

        html += "</div></div></div>\n"
        html += "<div class=\"legend\"><div class=\"legend-item\"><div class=\"legend-swatch\" style=\"background:#fbbf24\"></div>Lighting</div><div class=\"legend-item\"><div class=\"legend-swatch\" style=\"background:#ff6b35\"></div>Special Effects</div><div class=\"legend-item\"><div class=\"legend-swatch\" style=\"background:#2dd4bf\"></div>Support</div></div></body></html>"

        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private static func stickyHTMLHead(tw: Int, lw: Int, rh: Int, rulerH: Int, ch: Int, pps: Double, dateStr: String) -> String {
        """
        <!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Cue Timeline</title>
        <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',system-ui,sans-serif;background:#0f0f1a;color:#e0e0e0}
        .page-header{padding:20px 24px 12px;background:#0f0f1a;border-bottom:1px solid #2a2a3e}
        .page-header h1{font-size:20px;font-weight:600;color:#fff}
        .page-header .subtitle{font-size:11px;color:#666;margin-top:2px}
        .timeline-wrapper{position:relative;overflow:auto;height:calc(100vh - 70px)}
        .timeline-grid{display:grid;grid-template-columns:\(lw)px \(tw)px;grid-template-rows:\(rulerH)px \(ch)px;width:\(lw + tw + 40)px}
        .corner-cell{position:sticky;top:0;left:0;z-index:30;background:#12121f;border-bottom:1px solid #2a2a3e;border-right:1px solid #2a2a3e;display:flex;align-items:center;justify-content:center;font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:1.2px;color:#555}
        .time-ruler{position:sticky;top:0;z-index:20;background:#12121f;border-bottom:1px solid #2a2a3e;height:\(rulerH)px}
        .time-ruler-inner{position:relative;width:100%;height:100%}
        .tick{position:absolute;top:8px;font-size:9px;font-family:'SF Mono','Menlo',monospace;color:#666;padding-left:4px}
        .tick::before{content:'';position:absolute;left:0;bottom:-8px;width:1px;height:12px;background:#3a3a4e}
        .labels-column{position:sticky;left:0;z-index:10;background:#12121f;border-right:1px solid #2a2a3e}
        .label-row{height:\(rh)px;display:flex;align-items:center;padding:0 12px;font-size:11px;font-weight:500;color:#bbb;border-bottom:1px solid rgba(255,255,255,0.03);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
        .label-row .cue-num{font-family:'SF Mono',monospace;font-size:10px;font-weight:600;margin-right:8px;padding:2px 6px;border-radius:3px;background:rgba(255,255,255,0.06);flex-shrink:0}
        .section-label{height:\(rh)px;display:flex;align-items:center;padding:0 12px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1px;border-bottom:1px solid rgba(255,255,255,0.05)}
        .section-label.light{color:#fbbf24;background:rgba(251,191,36,0.05)}
        .section-label.sfx{color:#ff6b35;background:rgba(255,107,53,0.05)}
        .section-label.support{color:#2dd4bf;background:rgba(45,212,191,0.05)}
        .timeline-content{position:relative;background:repeating-linear-gradient(90deg,transparent,transparent \(Int(pps * 10) - 1)px,rgba(255,255,255,0.015) \(Int(pps * 10) - 1)px,rgba(255,255,255,0.015) \(Int(pps * 10))px)}
        .timeline-row{position:absolute;left:0;right:0;height:\(rh)px;border-bottom:1px solid rgba(255,255,255,0.02)}
        .section-row{position:absolute;left:0;right:0;height:\(rh)px;background:rgba(255,255,255,0.01);border-bottom:1px solid rgba(255,255,255,0.04)}
        .cue-bar{position:absolute;top:6px;height:28px;border-radius:6px;display:flex;align-items:center;padding:0 8px;font-size:10px;font-weight:600;color:#fff;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;cursor:default;transition:transform .12s ease,box-shadow .12s ease;box-shadow:0 2px 6px rgba(0,0,0,0.4)}
        .cue-bar:hover{transform:translateY(-2px) scale(1.02);box-shadow:0 6px 20px rgba(0,0,0,0.5);z-index:5}
        .cue-bar .tooltip{display:none;position:absolute;bottom:calc(100% + 10px);left:50%;transform:translateX(-50%);background:#1a1a2e;border:1px solid #3a3a5e;border-radius:8px;padding:10px 14px;font-size:10px;font-weight:400;line-height:1.6;white-space:nowrap;z-index:100;color:#ccc;box-shadow:0 8px 28px rgba(0,0,0,0.7);pointer-events:none}
        .cue-bar:hover .tooltip{display:block}
        .tooltip strong{color:#fff;font-size:11px;display:block;margin-bottom:4px}
        .tooltip .tt-row{color:#aaa}
        .cue-bar.has-fade::before{content:'';position:absolute;left:0;top:0;bottom:0;width:var(--fade-in-w,0px);background:linear-gradient(90deg,rgba(0,0,0,0.45),transparent);border-radius:6px 0 0 6px;pointer-events:none}
        .cue-bar.has-fade::after{content:'';position:absolute;right:0;top:0;bottom:0;width:var(--fade-out-w,0px);background:linear-gradient(270deg,rgba(0,0,0,0.45),transparent);border-radius:0 6px 6px 0;pointer-events:none}
        .legend{position:sticky;left:0;padding:14px 24px;display:flex;gap:24px;font-size:11px;color:#888;background:#0f0f1a;border-top:1px solid #2a2a3e}
        .legend-item{display:flex;align-items:center;gap:6px}
        .legend-swatch{width:14px;height:14px;border-radius:4px}
        </style></head><body>
        <div class="page-header"><h1>Cue Timeline</h1><div class="subtitle">Exported from DirectorsChair \u{2022} \(dateStr) \u{2022} Hover over bars for details</div></div>
        <div class="timeline-wrapper"><div class="timeline-grid">
        <div class="corner-cell">Cue</div>
        <div class="time-ruler"><div class="time-ruler-inner">
        """
    }

    private static func fmtMMSS(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }

    private static func htmlEsc(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Gantt Bar Shape (Lighting)

private struct GanttBarShape: View {
    let cue: LightCue
    let barWidth: CGFloat
    let barHeight: CGFloat
    let pxPerSec: CGFloat
    var isSelected: Bool = false

    private var barColor: Color { Color(hex: cue.markerColor) }
    private var barOpacity: CGFloat { cue.intensity * 0.6 + 0.15 }
    private var fadeInWidth: CGFloat { CGFloat(cue.fadeInDuration) * pxPerSec }
    private var fadeOutWidth: CGFloat { CGFloat(cue.fadeOutDuration) * pxPerSec }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main bar
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor.opacity(barOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(barColor.opacity(isSelected ? 1.0 : 0.8), lineWidth: isSelected ? 2.5 : 1)
                )

            // Fade-in gradient
            if fadeInWidth > 2 {
                LinearGradient(
                    colors: [barColor.opacity(0), barColor.opacity(barOpacity)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: min(fadeInWidth, barWidth * 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Fade-out gradient
            if fadeOutWidth > 2 {
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [barColor.opacity(barOpacity), barColor.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: min(fadeOutWidth, barWidth * 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Label inside bar (icon + cue number + name)
            if barWidth > 40 {
                HStack(spacing: 3) {
                    Image(systemName: cue.fixtureType.icon)
                        .font(.system(size: 8))
                    Text(cue.cueNumber)
                        .font(.system(size: 9, weight: .semibold))
                    if barWidth > 80 {
                        Text(cue.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                .padding(.leading, 6)
            }

            // Intensity line at bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(barColor)
                    .frame(width: barWidth * cue.intensity, height: 2)
                    .padding(.bottom, 2)
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - SFX Gantt Bar Shape

private struct SFXGanttBarShape: View {
    let cue: SFXCue
    let barWidth: CGFloat
    let barHeight: CGFloat
    let pxPerSec: CGFloat
    var isSelected: Bool = false

    private var barColor: Color { Color(hex: cue.markerColor) }
    private var barOpacity: CGFloat { cue.intensity * 0.6 + 0.15 }
    private var fadeInWidth: CGFloat { CGFloat(cue.fadeInDuration) * pxPerSec }
    private var fadeOutWidth: CGFloat { CGFloat(cue.fadeOutDuration) * pxPerSec }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main bar
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor.opacity(barOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(barColor.opacity(isSelected ? 1.0 : 0.8), lineWidth: isSelected ? 2.5 : 1)
                )

            // Fade-in gradient
            if fadeInWidth > 2 {
                LinearGradient(
                    colors: [barColor.opacity(0), barColor.opacity(barOpacity)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: min(fadeInWidth, barWidth * 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Fade-out gradient
            if fadeOutWidth > 2 {
                HStack {
                    Spacer()
                    LinearGradient(
                        colors: [barColor.opacity(barOpacity), barColor.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: min(fadeOutWidth, barWidth * 0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Label inside bar (icon + cue number + name)
            if barWidth > 40 {
                HStack(spacing: 3) {
                    Image(systemName: cue.effectType.icon)
                        .font(.system(size: 8))
                    Text(cue.cueNumber)
                        .font(.system(size: 9, weight: .semibold))
                    if barWidth > 80 {
                        Text(cue.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                .padding(.leading, 6)
            }

            // Intensity line at bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(barColor)
                    .frame(width: barWidth * cue.intensity, height: 2)
                    .padding(.bottom, 2)
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - Support Gantt Bar Shape

private struct SupportGanttBarShape: View {
    let cue: SupportCue
    let barWidth: CGFloat
    let barHeight: CGFloat
    var isSelected: Bool = false

    private var barColor: Color { Color(hex: cue.markerColor) }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main bar (no fade gradients for support actions)
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(barColor.opacity(isSelected ? 1.0 : 0.8), lineWidth: isSelected ? 2.5 : 1)
                )

            // Label inside bar (icon + cue number)
            if barWidth > 40 {
                HStack(spacing: 3) {
                    Image(systemName: cue.actionType.icon)
                        .font(.system(size: 8))
                    Text(cue.cueNumber)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                .padding(.leading, 6)
            }
        }
    }
}

// MARK: - Filter Chip

private struct GanttFilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
