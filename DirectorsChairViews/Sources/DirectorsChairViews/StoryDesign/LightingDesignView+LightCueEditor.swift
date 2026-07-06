//
// LightingDesignView+LightCueEditor.swift
//
// Extracted from LightingDesignView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore


// MARK: - Buffered Editor (Light Cues)

/// Holds a local copy of the cue and flushes edits to the project on a debounce timer.
/// This prevents every keystroke from triggering a full Project re-render.
struct LightCueBufferedEditor: View {
    @Binding var project: Project
    let cueId: String

    @State private var cue: LightCue = LightCue()
    @State private var flushTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            lightCueDetailEditor
                .padding(24)
        }
        .frame(maxWidth: .infinity)
        .onAppear { loadCue() }
        .onDisappear { flushImmediately() }
    }

    // MARK: - Flush Logic

    private func loadCue() {
        if let source = project.lightCues.first(where: { $0.id == cueId }) {
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
        if let idx = project.lightCues.firstIndex(where: { $0.id == cueId }) {
            if project.lightCues[idx] != cue {
                project.lightCues[idx] = cue
            }
        }
    }

    /// Binding into the local cue that auto-schedules a flush
    private func buffered<T>(_ keyPath: WritableKeyPath<LightCue, T>) -> Binding<T> {
        Binding(
            get: { cue[keyPath: keyPath] },
            set: { newValue in
                cue[keyPath: keyPath] = newValue
                scheduleFlush()
            }
        )
    }

    // Convenience for optional strings that should be nil when empty
    private func bufferedOptionalString(_ keyPath: WritableKeyPath<LightCue, String?>) -> Binding<String> {
        Binding(
            get: { cue[keyPath: keyPath] ?? "" },
            set: { newValue in
                cue[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                scheduleFlush()
            }
        )
    }

    // MARK: - Detail Editor

    @ViewBuilder
    private var lightCueDetailEditor: some View {
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
                        TextField("Cue name", text: buffered(\.name))
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
                            TextField("Q1", text: buffered(\.cueNumber))
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                                .frame(width: 80)
                        }

                        // Workflow
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Workflow")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            HStack(spacing: 4) {
                                ForEach(LightingWorkflow.allCases, id: \.self) { wf in
                                    LightChip(
                                        label: wf.rawValue,
                                        icon: wf == .cinema ? "film" : "theatermasks",
                                        isSelected: cue.workflow == wf
                                    ) {
                                        cue.workflow = wf
                                        flushImmediately()
                                    }
                                }
                            }
                        }
                    }

                    // Fixture type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fixture Type")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .tracking(0.5)
                        let fixtures = fixturesForWorkflow(cue.workflow)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
                            ForEach(fixtures, id: \.self) { fixture in
                                LightChip(
                                    label: fixture.rawValue,
                                    icon: fixture.icon,
                                    isSelected: cue.fixtureType == fixture
                                ) {
                                    cue.fixtureType = fixture
                                    flushImmediately()
                                }
                                .instantTooltip(fixture.tooltip)
                            }
                        }
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

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scene")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .tracking(0.5)
                        Picker("", selection: buffered(\.sceneId)) {
                            Text("None").tag(String?.none)
                            ForEach(allScenes, id: \.id) { scene in
                                Text(scene.name).tag(String?.some(scene.id))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
            }

            // INTENSITY CARD
            LightAttributeCard(title: "INTENSITY & TRANSITIONS", icon: "sun.max.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    // Start intensity
                    HStack {
                        Text("Start Intensity")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(cue.intensity * 100))%")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Slider(value: buffered(\.intensity), in: 0...1, step: 0.05)
                        .controlSize(.small)

                    // End intensity (for ramps)
                    HStack {
                        Text("End Intensity")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        if let endVal = cue.intensityEnd {
                            Text("\(Int(endVal * 100))%")
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Text("Same")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Toggle("Ramp", isOn: Binding(
                            get: { cue.intensityEnd != nil },
                            set: { enabled in
                                cue.intensityEnd = enabled ? cue.intensity : nil
                                flushImmediately()
                            }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    if cue.intensityEnd != nil {
                        Slider(
                            value: Binding(
                                get: { cue.intensityEnd ?? cue.intensity },
                                set: { cue.intensityEnd = $0; scheduleFlush() }
                            ),
                            in: 0...1, step: 0.05
                        )
                        .controlSize(.small)
                    }

                    Divider()

                    // Fade durations
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fade In")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            HStack(spacing: 4) {
                                TextField("0", value: buffered(\.fadeInDuration), format: .number)
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
                            Text("Fade Out")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            HStack(spacing: 4) {
                                TextField("0", value: buffered(\.fadeOutDuration), format: .number)
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

                    // Transition chips
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transition In")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], spacing: 4) {
                                ForEach(LightTransition.allCases, id: \.self) { trans in
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
                                ForEach(LightTransition.allCases, id: \.self) { trans in
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
                }
            }

            // COLOR CARD
            LightAttributeCard(title: "COLOR", icon: "paintpalette.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    // Color swatch + hex
                    HStack(spacing: 12) {
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: cue.color) },
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
                            TextField("#FFFFFF", text: buffered(\.color))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(6)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                                .frame(width: 100)
                        }
                    }

                    // Color temperature
                    HStack {
                        Text("Color Temperature")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(cue.colorTemperature ?? 5600)K")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(cue.colorTemperature ?? 5600) },
                            set: { cue.colorTemperature = Int($0); scheduleFlush() }
                        ),
                        in: 2700...6500, step: 100
                    )
                    .controlSize(.small)

                    // Gel filter
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gel Filter")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            .tracking(0.5)
                        TextField("e.g. Lee 201, R27", text: bufferedOptionalString(\.gelFilter))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }
                }
            }

            // POSITION CARD
            LightAttributeCard(title: "POSITION", icon: "scope") {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
                        ForEach(LightPosition.allCases, id: \.self) { pos in
                            LightChip(
                                label: pos.rawValue,
                                icon: pos.icon,
                                isSelected: cue.position == pos
                            ) {
                                cue.position = pos
                                flushImmediately()
                            }
                        }
                    }

                    if cue.position == .custom {
                        TextField("Custom position", text: bufferedOptionalString(\.positionCustom))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Angle")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            HStack(spacing: 4) {
                                Text("\(Int(cue.angle ?? 0))")
                                    .font(.system(size: 14, weight: .bold))
                                Text("\u{00B0}")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { cue.angle ?? 0 },
                                    set: { cue.angle = $0; scheduleFlush() }
                                ),
                                in: 0...360, step: 5
                            )
                            .controlSize(.small)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Elevation")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            HStack(spacing: 4) {
                                Text("\(Int(cue.elevation ?? 0))")
                                    .font(.system(size: 14, weight: .bold))
                                Text("\u{00B0}")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { cue.elevation ?? 0 },
                                    set: { cue.elevation = $0; scheduleFlush() }
                                ),
                                in: -90...90, step: 5
                            )
                            .controlSize(.small)
                        }
                    }
                }
            }

            // MOTIVATION CARD (Cinema only)
            if cue.workflow == .cinema {
                LightAttributeCard(title: "MOTIVATION", icon: "film") {
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
                            ForEach(LightMotivation.allCases, id: \.self) { mot in
                                LightChip(
                                    label: mot.rawValue,
                                    icon: mot.icon,
                                    isSelected: cue.motivation == mot
                                ) {
                                    cue.motivation = mot
                                    flushImmediately()
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Diffusion")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            TextField("e.g. 1/4 CTB, Full CTO", text: bufferedOptionalString(\.diffusion))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flags & Cutters")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                .tracking(0.5)
                            TextField("Notes on flags, cutters, barn doors...", text: bufferedOptionalString(\.flagsAndCutters))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }
                    }
                }
            }

            // DMX / THEATER CARD (Theater only)
            if cue.workflow == .theater {
                LightAttributeCard(title: "DMX / THEATER", icon: "theatermasks") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DMX Channel")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                TextField("", value: buffered(\.dmxChannel), format: .number)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(6)
                                    .background(Color(nsColor: .quaternarySystemFill))
                                    .cornerRadius(6)
                                    .frame(width: 70)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Universe")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                TextField("", value: buffered(\.dmxUniverse), format: .number)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(6)
                                    .background(Color(nsColor: .quaternarySystemFill))
                                    .cornerRadius(6)
                                    .frame(width: 70)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gobo Pattern")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            TextField("e.g. Stars, Breakup", text: bufferedOptionalString(\.goboPattern))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }

                        if cue.goboPattern != nil && !(cue.goboPattern?.isEmpty ?? true) {
                            HStack {
                                Text("Gobo Rotation")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(cue.goboRotation ?? 0))\u{00B0}")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Slider(
                                value: Binding(
                                    get: { cue.goboRotation ?? 0 },
                                    set: { cue.goboRotation = $0; scheduleFlush() }
                                ),
                                in: 0...360, step: 5
                            )
                            .controlSize(.small)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Follow Spot Operator")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            TextField("Operator name", text: bufferedOptionalString(\.followSpotOperator))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Focus Target")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            TextField("e.g. Lead Actor, Center Stage", text: bufferedOptionalString(\.focusTarget))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(8)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }
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

    // MARK: - Helpers

    private var allScenes: [DCScene] {
        project.sequences.flatMap { $0.scenes }
    }

    private func fixturesForWorkflow(_ workflow: LightingWorkflow) -> [LightFixtureType] {
        switch workflow {
        case .cinema:
            return [.keyLight, .fillLight, .backLight, .practical, .bounce, .kicker, .spot, .flood, .custom]
        case .theater:
            return [.fresnel, .ellipsoidal, .par, .ledPanel, .followSpot, .cyc, .gobo, .movingHead, .spot, .flood, .custom]
        }
    }
}
