// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/SupportCueConfigPopover.swift
//
// Quick-add popover for creating/editing support cues from the timeline

import SwiftUI
import DirectorsChairCore

struct SupportCueConfigPopover: View {
    @Binding var cueName: String
    @Binding var cueNumber: String
    @Binding var actionType: SupportActionType
    @Binding var priority: SupportPriority
    @Binding var assignedTo: String
    @Binding var duration: Double
    @Binding var cueColor: String

    var isEditing: Bool = false
    var onSave: () -> Void
    var onCancel: () -> Void
    var onFullEditor: (() -> Void)?

    private let colorOptions = [
        "#2DD4BF", "#34C759", "#007AFF", "#AF52DE",
        "#FF6B35", "#FF2D55", "#FFD60A", "#FFFFFF"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(isEditing ? "EDIT SUPPORT CUE" : "ADD SUPPORT CUE")
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
                    TextField("Support Cue", text: $cueName)
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
                    TextField("S1", text: $cueNumber)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                        .frame(width: 60)
                }
            }

            // Action type chips
            VStack(alignment: .leading, spacing: 4) {
                Text("Action Type")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
                    ForEach(SupportActionType.allCases, id: \.self) { action in
                        Button {
                            actionType = action
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 9))
                                Text(action.rawValue)
                                    .font(.system(size: 9, weight: actionType == action ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(actionType == action ? Color(hex: "#2DD4BF") : Color(nsColor: .quaternarySystemFill))
                            )
                            .foregroundColor(actionType == action ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .help(action.tooltip)
                    }
                }
            }

            // Priority chips
            VStack(alignment: .leading, spacing: 4) {
                Text("Priority")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)
                HStack(spacing: 4) {
                    ForEach(SupportPriority.allCases, id: \.self) { p in
                        Button {
                            priority = p
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: p.icon)
                                    .font(.system(size: 9))
                                Text(p.rawValue)
                                    .font(.system(size: 9, weight: priority == p ? .semibold : .regular))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(priority == p ? Color(hex: "#2DD4BF") : Color(nsColor: .quaternarySystemFill))
                            )
                            .foregroundColor(priority == p ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Assigned To
            VStack(alignment: .leading, spacing: 2) {
                Text("Assigned To")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .tracking(0.5)
                TextField("Crew member", text: $assignedTo)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(6)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
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
                                            cueColor == color ? Color(hex: "#2DD4BF") : (color == "#FFFFFF" ? Color.gray.opacity(0.5) : Color.clear),
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
        .frame(width: 340)
    }
}
