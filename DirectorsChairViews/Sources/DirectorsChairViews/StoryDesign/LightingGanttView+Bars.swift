//
// LightingGanttView+Bars.swift
//
// Extracted from LightingGanttView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore

extension LightingGanttView {

    // MARK: - Gantt Bar (Lighting)

    func ganttBar(cue: LightCue, rowIndex: Int) -> some View {
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

    var sfxSectionHeader: some View {
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

    func sfxCueLabel(cue: SFXCue, index: Int) -> some View {
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

    func sfxGanttBar(cue: SFXCue, rowIndex: Int) -> some View {
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

    var supportSectionHeader: some View {
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

    func supportCueLabel(cue: SupportCue, index: Int) -> some View {
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

    func supportGanttBar(cue: SupportCue, rowIndex: Int) -> some View {
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
}
