// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/SFXCueConfigPopover.swift
//
// Quick-add popover for creating/editing SFX cues from the timeline

import SwiftUI
import DirectorsChairCore

struct SFXCueConfigPopover: View {
    @Binding var cueName: String
    @Binding var cueNumber: String
    @Binding var effectType: SFXEffectType
    @Binding var intensity: Double
    @Binding var duration: Double
    @Binding var cueColor: String

    var isEditing: Bool = false
    var onSave: () -> Void
    var onCancel: () -> Void
    var onFullEditor: (() -> Void)?

    private let colorOptions = [
        "#FF6B35", "#FF2D55", "#FFD60A", "#FF9500",
        "#34C759", "#007AFF", "#AF52DE", "#FFFFFF"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(isEditing ? "EDIT SFX CUE" : "ADD SFX CUE")
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
                    TextField("SFX Cue", text: $cueName)
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
                    TextField("FX1", text: $cueNumber)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .frame(width: 60)
                }
            }

            // Effect type chips
            VStack(alignment: .leading, spacing: 4) {
                Text("Effect Type")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)], spacing: 4) {
                    ForEach(SFXEffectType.allCases, id: \.self) { effect in
                        Button {
                            effectType = effect
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: effect.icon)
                                    .font(.system(size: 9))
                                Text(effect.rawValue)
                                    .font(.system(size: 9, weight: effectType == effect ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(effectType == effect ? Color(hex: "#FF6B35") : Color(nsColor: .quaternarySystemFill))
                            )
                            .foregroundColor(effectType == effect ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .instantTooltip(effect.tooltip)
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

            // Color swatches
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
                                            cueColor == color ? Color(hex: "#FF6B35") : (color == "#FFFFFF" ? Color.gray.opacity(0.5) : Color.clear),
                                            lineWidth: cueColor == color ? 2.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
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
        .frame(width: 320)
    }
}
