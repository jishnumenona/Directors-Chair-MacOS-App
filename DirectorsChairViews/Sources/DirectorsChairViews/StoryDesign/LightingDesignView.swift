// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/LightingDesignView.swift
//
// Unified choreography workspace — Gantt chart (left) + detail editor (right)
// Uses buffered editing to avoid full Project re-render on every keystroke.

import SwiftUI
import DirectorsChairCore

private enum SelectedCueType: Equatable {
    case light(String)
    case sfx(String)
    case support(String)
    case none
}

public struct LightingDesignView: View {
    @Binding var project: Project
    let projectBasePath: URL?
    let initialLightCueId: String?
    let initialSFXCueId: String?
    let initialSupportCueId: String?
    let markers: [TimelineMarker]
    @State private var selectedCueType: SelectedCueType = .none

    public init(project: Binding<Project>, projectBasePath: URL?, initialLightCueId: String? = nil, initialSFXCueId: String? = nil, initialSupportCueId: String? = nil, markers: [TimelineMarker] = []) {
        self._project = project
        self.projectBasePath = projectBasePath
        self.initialLightCueId = initialLightCueId
        self.initialSFXCueId = initialSFXCueId
        self.initialSupportCueId = initialSupportCueId
        self.markers = markers
    }

    private var selectedCueId: String? {
        switch selectedCueType {
        case .light(let id): return id
        case .sfx(let id): return id
        case .support(let id): return id
        case .none: return nil
        }
    }

    public var body: some View {
        HSplitView {
            // LEFT: Gantt chart
            LightingGanttView(
                project: $project,
                markers: markers,
                onCueDoubleClicked: nil,
                onSFXCueDoubleClicked: nil,
                onSupportCueDoubleClicked: nil,
                onCueClicked: { id in selectedCueType = .light(id) },
                onSFXCueClicked: { id in selectedCueType = .sfx(id) },
                onSupportCueClicked: { id in selectedCueType = .support(id) },
                selectedCueId: selectedCueId
            )
            .frame(minWidth: 500)

            // RIGHT: Detail editor
            detailEditorPanel
                .frame(minWidth: 320, idealWidth: 400, maxWidth: 500)
        }
        .onAppear {
            if let cueId = initialLightCueId {
                selectedCueType = .light(cueId)
            } else if let sfxId = initialSFXCueId {
                selectedCueType = .sfx(sfxId)
            } else if let supportId = initialSupportCueId {
                selectedCueType = .support(supportId)
            }
        }
        .onChange(of: initialLightCueId) { newId in
            if let cueId = newId {
                selectedCueType = .light(cueId)
            }
        }
        .onChange(of: initialSFXCueId) { newId in
            if let sfxId = newId {
                selectedCueType = .sfx(sfxId)
            }
        }
        .onChange(of: initialSupportCueId) { newId in
            if let supportId = newId {
                selectedCueType = .support(supportId)
            }
        }
    }

    @ViewBuilder
    private var detailEditorPanel: some View {
        switch selectedCueType {
        case .light(let cueId):
            if project.lightCues.contains(where: { $0.id == cueId }) {
                LightCueBufferedEditor(
                    project: $project,
                    cueId: cueId
                )
                .id(cueId)
            } else {
                placeholderView
            }
        case .sfx(let cueId):
            if project.sfxCues.contains(where: { $0.id == cueId }) {
                SFXCueBufferedEditor(
                    project: $project,
                    cueId: cueId
                )
                .id(cueId)
            } else {
                placeholderView
            }
        case .support(let cueId):
            if project.supportCues.contains(where: { $0.id == cueId }) {
                SupportCueBufferedEditor(
                    project: $project,
                    cueId: cueId
                )
                .id(cueId)
            } else {
                placeholderView
            }
        case .none:
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.gantt")
                .font(.system(size: 48))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text("Click a cue in the Gantt chart")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("Select any lighting, SFX, or support cue\nto edit its details here.")
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Buffered Editor (Light Cues)

/// Holds a local copy of the cue and flushes edits to the project on a debounce timer.
/// This prevents every keystroke from triggering a full Project re-render.
private struct LightCueBufferedEditor: View {
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

// MARK: - Buffered Editor (SFX Cues)

/// Holds a local copy of the SFX cue and flushes edits to the project on a debounce timer.
/// This prevents every keystroke from triggering a full Project re-render.
private struct SFXCueBufferedEditor: View {
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

// MARK: - Buffered Editor (Support Cues)

/// Holds a local copy of the support cue and flushes edits to the project on a debounce timer.
private struct SupportCueBufferedEditor: View {
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

// MARK: - Light Attribute Card

private struct LightAttributeCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Light Chip

private struct LightChip: View {
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
                    .lineLimit(1)
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

// MARK: - Lighting Tab Chip

private struct LightingTabChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color hex helper

private extension Color {
    var lightCueHexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - MM:SS Time Field

private struct TimeFieldMMSS: View {
    let label: String
    @Binding var seconds: Double
    var isReadOnly: Bool = false

    @State private var minText: String = ""
    @State private var secText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .tracking(0.5)
            if isReadOnly {
                Text(DurationEstimator.formatTime(CGFloat(seconds)))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(6)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
                    .frame(minWidth: 70)
            } else {
                HStack(spacing: 2) {
                    TextField("00", text: $minText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .frame(width: 36)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitTime() }
                        .onChange(of: minText) { _ in commitTime() }
                    Text(":")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    TextField("00", text: $secText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .frame(width: 36)
                        .multilineTextAlignment(.leading)
                        .onSubmit { commitTime() }
                        .onChange(of: secText) { _ in commitTime() }
                }
            }
        }
        .onAppear { syncFromSeconds() }
        .onChange(of: seconds) { _ in syncFromSeconds() }
    }

    private func syncFromSeconds() {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let newMin = String(format: "%02d", m)
        let newSec = String(format: "%02d", s)
        if minText != newMin { minText = newMin }
        if secText != newSec { secText = newSec }
    }

    private func commitTime() {
        let m = Int(minText) ?? 0
        let s = Int(secText) ?? 0
        let total = Double(max(0, m * 60 + s))
        if seconds != total {
            seconds = total
        }
    }
}
