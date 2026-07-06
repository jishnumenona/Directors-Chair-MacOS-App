//
// LightingDesignView+SFXCueEditor.swift
//
// Extracted from LightingDesignView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore


// MARK: - Buffered Editor (SFX Cues)

/// Holds a local copy of the SFX cue and flushes edits to the project on a debounce timer.
/// This prevents every keystroke from triggering a full Project re-render.
struct SFXCueBufferedEditor: View {
    @Binding var project: Project
    let cueId: String

    @State private var cue: SFXCue = SFXCue()
    @State private var flushTask: Task<Void, Never>?

    private let sfxAccent = Color(hex: "#FF6B35")

    var body: some View {
        ScrollView {
            sfxCueDetailEditor
                .padding(24)
        }
        .frame(maxWidth: .infinity)
        .onAppear { loadCue() }
        .onDisappear { flushImmediately() }
    }

    // MARK: - Flush Logic

    private func loadCue() {
        if let source = project.sfxCues.first(where: { $0.id == cueId }) {
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
        if let idx = project.sfxCues.firstIndex(where: { $0.id == cueId }) {
            if project.sfxCues[idx] != cue {
                project.sfxCues[idx] = cue
            }
        }
    }

    /// Binding into the local cue that auto-schedules a flush
    private func buffered<T>(_ keyPath: WritableKeyPath<SFXCue, T>) -> Binding<T> {
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
    private var sfxCueDetailEditor: some View {
        VStack(alignment: .leading, spacing: 24) {

            // IDENTITY CARD
            LightAttributeCard(title: "IDENTITY", icon: "tag.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    // Name
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Name")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .tracking(0.5)
                        TextField("SFX Cue name", text: buffered(\.name))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }

                    HStack(spacing: 16) {
                        // Cue Number
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cue #")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            TextField("FX1", text: buffered(\.cueNumber))
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                                .frame(width: 80)
                        }
                    }

                    // Effect Type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Effect Type")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .tracking(0.5)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                            ForEach(SFXEffectType.allCases, id: \.self) { effect in
                                LightChip(
                                    label: effect.rawValue,
                                    icon: effect.icon,
                                    isSelected: cue.effectType == effect
                                ) {
                                    cue.effectType = effect
                                    flushImmediately()
                                }
                                .instantTooltip(effect.tooltip)
                            }
                        }
                    }
                }
            }

            // COLOR CARD
            LightAttributeCard(title: "COLOR", icon: "paintpalette.fill") {
                HStack(spacing: 12) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: cue.markerColor) },
                        set: { newColor in
                            cue.color = newColor.lightCueHexString
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
                        TextField("#FF6B35", text: Binding(
                            get: { cue.markerColor },
                            set: { newVal in
                                cue.color = newVal
                                cue.markerColor = newVal
                                scheduleFlush()
                            }
                        ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(6)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                            .frame(width: 100)
                    }
                }
            }

            // TIMELINE CARD
            LightAttributeCard(title: "TIMELINE", icon: "clock.fill") {
                HStack(spacing: 16) {
                    TimeFieldMMSS(label: "Start Time", seconds: buffered(\.startTime))
                    TimeFieldMMSS(label: "End Time", seconds: Binding(
                        get: { cue.startTime + cue.duration },
                        set: { newEnd in
                            let newDur = max(0, newEnd - cue.startTime)
                            cue.duration = newDur
                            scheduleFlush()
                        }
                    ))
                    TimeFieldMMSS(label: "Duration", seconds: buffered(\.duration))
                }
            }

            // EFFECT CARD
            LightAttributeCard(title: "EFFECT", icon: "wand.and.stars") {
                VStack(alignment: .leading, spacing: 12) {
                    // Intensity
                    HStack {
                        Text("Intensity")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(cue.intensity * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(sfxAccent)
                    }
                    Slider(value: buffered(\.intensity), in: 0...1, step: 0.05)
                        .controlSize(.small)
                        .tint(sfxAccent)

                    // Intensity Profile
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intensity Profile")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .tracking(0.5)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                            ForEach(SFXIntensityProfile.allCases, id: \.self) { profile in
                                LightChip(
                                    label: profile.rawValue,
                                    icon: profile.icon,
                                    isSelected: cue.intensityProfile == profile
                                ) {
                                    cue.intensityProfile = profile
                                    flushImmediately()
                                }
                            }
                        }
                    }

                    Divider()

                    // Coverage
                    HStack {
                        Text("Coverage")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(cue.coverage * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(sfxAccent)
                    }
                    Slider(value: buffered(\.coverage), in: 0...1, step: 0.05)
                        .controlSize(.small)
                        .tint(sfxAccent)
                }
            }

            // PLACEMENT CARD
            LightAttributeCard(title: "PLACEMENT", icon: "mappin.and.ellipse") {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                        ForEach(SFXPlacement.allCases, id: \.self) { place in
                            LightChip(
                                label: place.rawValue,
                                icon: place.icon,
                                isSelected: cue.placement == place
                            ) {
                                cue.placement = place
                                flushImmediately()
                            }
                        }
                    }
                }
            }

            // TRANSITIONS CARD
            LightAttributeCard(title: "TRANSITIONS", icon: "arrow.left.arrow.right") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transition In")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], spacing: 4) {
                                ForEach(SFXTransition.allCases, id: \.self) { trans in
                                    LightChip(
                                        label: trans.rawValue,
                                        icon: trans.icon,
                                        isSelected: cue.transitionIn == trans
                                    ) {
                                        cue.transitionIn = trans
                                        flushImmediately()
                                    }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transition Out")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], spacing: 4) {
                                ForEach(SFXTransition.allCases, id: \.self) { trans in
                                    LightChip(
                                        label: trans.rawValue,
                                        icon: trans.icon,
                                        isSelected: cue.transitionOut == trans
                                    ) {
                                        cue.transitionOut = trans
                                        flushImmediately()
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Fade durations
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fade In Duration")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            HStack(spacing: 4) {
                                TextField("1.0", value: buffered(\.fadeInDuration), format: .number)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(6)
                                    .background(Color(nsColor: .quaternarySystemFill))
                                    .cornerRadius(6)
                                    .frame(width: 50)
                                Text("sec")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fade Out Duration")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            HStack(spacing: 4) {
                                TextField("1.0", value: buffered(\.fadeOutDuration), format: .number)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(6)
                                    .background(Color(nsColor: .quaternarySystemFill))
                                    .cornerRadius(6)
                                    .frame(width: 50)
                                Text("sec")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // SAFETY CARD
            LightAttributeCard(title: "SAFETY", icon: "exclamationmark.triangle.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Requires Ventilation", isOn: Binding(
                            get: { cue.requiresVentilation },
                            set: { cue.requiresVentilation = $0; flushImmediately() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        Spacer()
                    }

                    HStack {
                        Toggle("Operator Required", isOn: Binding(
                            get: { cue.operatorRequired },
                            set: { cue.operatorRequired = $0; flushImmediately() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safety Notes")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .tracking(0.5)
                        TextEditor(text: buffered(\.safetyNotes))
                            .font(.system(size: 12))
                            .frame(minHeight: 60)
                            .padding(4)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }
                }
            }

            // NOTES CARD
            LightAttributeCard(title: "NOTES", icon: "note.text") {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: buffered(\.notes))
                        .font(.system(size: 12))
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)

                    // Active toggle
                    HStack {
                        Toggle("Active", isOn: Binding(
                            get: { cue.isActive },
                            set: { cue.isActive = $0; flushImmediately() }
                        ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        Spacer()
                    }
                }
            }
        }
    }
}
