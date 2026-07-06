//
// LightingDesignView+SupportCueEditor.swift
//
// Extracted from LightingDesignView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore


// MARK: - Buffered Editor (Support Cues)

/// Holds a local copy of the support cue and flushes edits to the project on a debounce timer.
struct SupportCueBufferedEditor: View {
    @Binding var project: Project
    let cueId: String

    @State private var cue: SupportCue = SupportCue()
    @State private var flushTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            supportCueDetailEditor
                .padding(24)
        }
        .frame(maxWidth: .infinity)
        .onAppear { loadCue() }
        .onDisappear { flushImmediately() }
    }

    // MARK: - Flush Logic

    private func loadCue() {
        if let source = project.supportCues.first(where: { $0.id == cueId }) {
            cue = source
        }
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            flushImmediately()
        }
    }

    private func flushImmediately() {
        flushTask?.cancel()
        flushTask = nil
        if let idx = project.supportCues.firstIndex(where: { $0.id == cueId }) {
            if project.supportCues[idx] != cue {
                project.supportCues[idx] = cue
            }
        }
    }

    private func flushing<T>(_ keyPath: WritableKeyPath<SupportCue, T>) -> Binding<T> {
        Binding(
            get: { cue[keyPath: keyPath] },
            set: { newValue in
                cue[keyPath: keyPath] = newValue
                scheduleFlush()
            }
        )
    }

    // MARK: - Detail Editor

    @ViewBuilder
    private var supportCueDetailEditor: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: cue.actionType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#2DD4BF"))
                Text("SUPPORT CUE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
                Spacer()
                Toggle("Active", isOn: flushing(\.isActive))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            // IDENTITY
            LightAttributeCard(title: "IDENTITY", icon: "tag") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                            TextField("Support Cue", text: flushing(\.name))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cue #").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                            TextField("S1", text: flushing(\.cueNumber))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                                .frame(width: 70)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Action Type").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                            ForEach(SupportActionType.allCases, id: \.self) { action in
                                LightChip(
                                    label: action.rawValue,
                                    icon: action.icon,
                                    isSelected: cue.actionType == action
                                ) {
                                    cue.actionType = action
                                    scheduleFlush()
                                }
                            }
                        }
                    }
                }
            }

            // COLOR
            LightAttributeCard(title: "COLOR", icon: "paintpalette.fill") {
                HStack(spacing: 12) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: cue.markerColor) },
                        set: { newColor in
                            cue.markerColor = newColor.lightCueHexString
                            scheduleFlush()
                        }
                    ))
                    .labelsHidden()
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hex")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        TextField("#2DD4BF", text: flushing(\.markerColor))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(6)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                            .frame(width: 100)
                    }
                }
            }

            // TIMELINE
            LightAttributeCard(title: "TIMELINE", icon: "clock") {
                HStack(spacing: 16) {
                    TimeFieldMMSS(label: "Start Time", seconds: flushing(\.startTime))
                    TimeFieldMMSS(label: "End Time", seconds: Binding(
                        get: { cue.startTime + cue.duration },
                        set: { newEnd in
                            let newDur = max(0, newEnd - cue.startTime)
                            cue.duration = newDur
                            scheduleFlush()
                        }
                    ))
                    TimeFieldMMSS(label: "Duration", seconds: flushing(\.duration))
                }
            }

            // ASSIGNMENT
            LightAttributeCard(title: "ASSIGNMENT", icon: "person.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assigned To").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                        TextField("Crew member name", text: flushing(\.assignedTo))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Priority").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            ForEach(SupportPriority.allCases, id: \.self) { p in
                                LightChip(
                                    label: p.rawValue,
                                    icon: p.icon,
                                    isSelected: cue.priority == p
                                ) {
                                    cue.priority = p
                                    scheduleFlush()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stage Area").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                            ForEach(SupportStageArea.allCases, id: \.self) { area in
                                LightChip(
                                    label: area.rawValue,
                                    icon: area.icon,
                                    isSelected: cue.stageArea == area
                                ) {
                                    cue.stageArea = area
                                    scheduleFlush()
                                }
                            }
                        }
                    }
                }
            }

            // EQUIPMENT
            LightAttributeCard(title: "EQUIPMENT", icon: "wrench") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Equipment / Props Required").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                    TextEditor(text: flushing(\.equipment))
                        .font(.system(size: 12))
                        .frame(minHeight: 60)
                        .padding(4)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }

            // SAFETY
            LightAttributeCard(title: "SAFETY", icon: "exclamationmark.triangle") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Notes").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                    TextEditor(text: flushing(\.safetyNotes))
                        .font(.system(size: 12))
                        .frame(minHeight: 60)
                        .padding(4)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }

            // NOTES
            LightAttributeCard(title: "NOTES", icon: "note.text") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                    TextEditor(text: flushing(\.notes))
                        .font(.system(size: 12))
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }
        }
    }
}
