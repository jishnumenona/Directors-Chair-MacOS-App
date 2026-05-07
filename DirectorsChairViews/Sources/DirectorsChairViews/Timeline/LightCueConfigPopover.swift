// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/LightCueConfigPopover.swift
//
// Quick-add popover for creating light cues from the timeline right-click menu

import SwiftUI
import DirectorsChairCore

// MARK: - Instant Tooltip

/// Wraps a SwiftUI view and sets an NSView tooltip with zero initial delay.
/// Uses a passthrough NSView subclass so clicks reach the SwiftUI button underneath.
struct InstantTooltip: NSViewRepresentable {
    let text: String

    private class PassthroughTooltipView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughTooltipView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}

extension View {
    /// Shows a tooltip immediately on hover (no delay)
    func instantTooltip(_ text: String) -> some View {
        self.overlay(InstantTooltip(text: text))
    }
}

struct LightCueConfigPopover: View {
    @Binding var cueName: String
    @Binding var cueNumber: String
    @Binding var workflow: LightingWorkflow
    @Binding var fixtureType: LightFixtureType
    @Binding var intensity: Double
    @Binding var duration: Double
    @Binding var cueColor: String

    var isEditing: Bool = false
    var onSave: () -> Void
    var onCancel: () -> Void
    var onFullEditor: (() -> Void)?

    private let colorOptions = [
        "#FFFFFF", "#FFD60A", "#FF9500", "#FF5F5F",
        "#34C759", "#007AFF", "#AF52DE", "#FF2D55"
    ]

    private let cinemaFixtures: [LightFixtureType] = [
        .keyLight, .fillLight, .backLight, .practical, .bounce, .kicker
    ]

    private let theaterFixtures: [LightFixtureType] = [
        .fresnel, .ellipsoidal, .par, .ledPanel, .followSpot, .cyc, .gobo, .movingHead
    ]

    private let commonFixtures: [LightFixtureType] = [
        .spot, .flood, .custom
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(isEditing ? "EDIT LIGHTING CUE" : "ADD LIGHTING CUE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1.2)

            // Name + Cue Number
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Name")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .tracking(0.5)
                    TextField("Light Cue", text: $cueName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cue #")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .tracking(0.5)
                    TextField("Q1", text: $cueNumber)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .frame(width: 60)
                }
            }

            // Workflow toggle
            HStack(spacing: 4) {
                ForEach(LightingWorkflow.allCases, id: \.self) { wf in
                    Button {
                        workflow = wf
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: wf == .cinema ? "film" : "theatermasks")
                                .font(.system(size: 10))
                            Text(wf.rawValue)
                                .font(.system(size: 10, weight: workflow == wf ? .semibold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(workflow == wf ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                        )
                        .foregroundColor(workflow == wf ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Fixture type chips
            VStack(alignment: .leading, spacing: 4) {
                Text("Fixture")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)

                let fixtures = workflow == .cinema ? cinemaFixtures + commonFixtures : theaterFixtures + commonFixtures
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], spacing: 4) {
                    ForEach(fixtures, id: \.self) { fixture in
                        Button {
                            fixtureType = fixture
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: fixture.icon)
                                    .font(.system(size: 9))
                                Text(fixture.rawValue)
                                    .font(.system(size: 9, weight: fixtureType == fixture ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(fixtureType == fixture ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                            )
                            .foregroundColor(fixtureType == fixture ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .instantTooltip(fixture.tooltip)
                    }
                }
            }

            // Intensity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Intensity")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .tracking(0.5)
                    Spacer()
                    Text("\(Int(intensity * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
                Slider(value: $intensity, in: 0...1, step: 0.05)
                    .controlSize(.small)
            }

            // Duration
            HStack {
                Text("Duration")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)
                Spacer()
                TextField("5.0", value: $duration, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .padding(4)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(4)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                Text("sec")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Color swatches + custom picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)
                HStack(spacing: 6) {
                    ForEach(colorOptions, id: \.self) { color in
                        Button {
                            cueColor = color
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            cueColor == color ? Color.accentColor : (color == "#FFFFFF" ? Color.gray.opacity(0.5) : Color.clear),
                                            lineWidth: cueColor == color ? 2.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Custom color picker + hex input
                HStack(spacing: 8) {
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: cueColor) },
                        set: { newColor in
                            cueColor = nsColorToHex(newColor)
                        }
                    ))
                    .labelsHidden()
                    .frame(width: 24, height: 24)

                    Text("#")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    TextField("FFFFFF", text: Binding(
                        get: { cueColor.hasPrefix("#") ? String(cueColor.dropFirst()) : cueColor },
                        set: { val in
                            let cleaned = val.trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: "#", with: "")
                            if cleaned.count <= 6 {
                                cueColor = "#" + cleaned.uppercased()
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(4)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(4)
                    .frame(width: 70)
                }
            }

            // Buttons
            HStack {
                if let onFullEditor = onFullEditor {
                    Button("Full Editor") {
                        onFullEditor()
                    }
                    .font(.system(size: 11))
                }
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Update" : "Add") { onSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func nsColorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
