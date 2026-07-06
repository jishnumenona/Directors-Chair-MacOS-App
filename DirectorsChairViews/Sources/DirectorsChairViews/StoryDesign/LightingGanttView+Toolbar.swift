//
// LightingGanttView+Toolbar.swift
//
// Extracted from LightingGanttView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore

extension LightingGanttView {

    // MARK: - Toolbar

    var toolbar: some View {
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

    var totalRowCount: Int {
        var count = filteredCues.count
        if !filteredSFXCues.isEmpty { count += filteredSFXCues.count + 1 } // +1 for section header
        if !filteredSupportCues.isEmpty { count += filteredSupportCues.count + 1 } // +1 for section header
        return count
    }

    var ganttContent: some View {
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

    var timeRuler: some View {
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

    var rulerTickInterval: CGFloat {
        if pxPerSec >= 15 { return 5 }
        if pxPerSec >= 8 { return 10 }
        if pxPerSec >= 4 { return 30 }
        return 60
    }

    // MARK: - Marker Line

    func markerLine(marker: TimelineMarker, x: CGFloat, height: CGFloat) -> some View {
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

    func cueLabel(cue: LightCue, index: Int) -> some View {
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

    var ganttGrid: some View {
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
}
