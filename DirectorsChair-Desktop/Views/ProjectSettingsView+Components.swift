//
// ProjectSettingsView+Components.swift
//
// Extracted from ProjectSettingsView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews


// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Settings Text Field

struct SettingsTextField: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Chip Grid

struct SettingsChipGrid: View {
    let options: [String]
    @Binding var selected: String

    let columns = [GridItem(.adaptive(minimum: 90), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(options, id: \.self) { option in
                SettingsChip(
                    label: option,
                    isSelected: selected.localizedCaseInsensitiveCompare(option) == .orderedSame,
                    action: { selected = option }
                )
            }
        }
    }
}

// MARK: - Settings Chip

struct SettingsChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }
}

// MARK: - Settings Info Row

struct SettingsInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: CameraPreset
    let isSelected: Bool
    let isCustom: Bool
    var onSelect: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: isCustom ? "star.fill" : "tray.fill")
                    .font(.system(size: 9))
                    .foregroundColor(isCustom ? .orange : .secondary)

                Text(preset.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                // Hover actions
                if isHovered && isCustom {
                    HStack(spacing: 4) {
                        if let onEdit {
                            Button { onEdit() } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        if let onDelete {
                            Button { onDelete() } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Parameters row
            HStack(spacing: 6) {
                presetParam(icon: "viewfinder", value: preset.shotType)
                presetParam(icon: "angle", value: preset.cameraAngle)
                presetParam(icon: "circle.dashed", value: "\(preset.lensMm)mm")
            }

            HStack(spacing: 6) {
                presetParam(icon: "camera.aperture", value: preset.aperture)
                presetParam(icon: "arrow.triangle.swap", value: preset.movement)
            }

            if !preset.description.isEmpty {
                Text(preset.description)
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .quaternarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect?() }
    }

    func presetParam(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(.accentColor.opacity(0.7))
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Preset Editor Sheet

struct PresetEditorSheet: View {
    let preset: CameraPreset?
    let onSave: (CameraPreset) -> Void
    let onCancel: () -> Void

    @State var name = ""
    @State var shotType = "MS"
    @State var cameraAngle = "Eye Level"
    @State var lensMm = 50
    @State var aperture = "f/2.8"
    @State var movement = "Static"
    @State var presetDescription = ""

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(preset == nil ? "New Camera Preset" : "Edit Preset")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "textformat", text: "Preset Name")
                        TextField("e.g. My Hero Shot", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }

                    // Shot Type
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "viewfinder", text: "Shot Type")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 55), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(CameraAngleOptions.shotTypes, id: \.self) { type in
                                chipButton(label: type, isSelected: shotType == type) { shotType = type }
                            }
                        }
                    }

                    // Camera Angle
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "angle", text: "Camera Angle")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 75), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(CameraAngleOptions.angles, id: \.self) { angle in
                                chipButton(label: angle, isSelected: cameraAngle == angle) { cameraAngle = angle }
                            }
                        }
                    }

                    // Lens
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "circle.dashed", text: "Lens (mm)")
                        HStack(spacing: 4) {
                            ForEach(CameraAngleOptions.commonLenses, id: \.self) { lens in
                                chipButton(label: "\(lens)", isSelected: lensMm == lens) { lensMm = lens }
                            }
                        }
                    }

                    // Aperture
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "camera.aperture", text: "Aperture")
                        HStack(spacing: 4) {
                            ForEach(CameraAngleOptions.commonApertures, id: \.self) { ap in
                                chipButton(label: ap, isSelected: aperture == ap) { aperture = ap }
                            }
                        }
                    }

                    // Movement
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "arrow.triangle.swap", text: "Camera Movement")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 75), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(CameraAngleOptions.movements, id: \.self) { mov in
                                chipButton(label: mov, isSelected: movement == mov) { movement = mov }
                            }
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "text.alignleft", text: "Description")
                        TextField("Short description of this preset...", text: $presetDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button { onCancel() } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    let saved = CameraPreset(
                        id: preset?.id ?? UUID().uuidString,
                        name: name,
                        cameraAngle: cameraAngle,
                        lensMm: lensMm,
                        aperture: aperture,
                        shotType: shotType,
                        movement: movement,
                        description: presetDescription,
                        isDefault: false
                    )
                    onSave(saved)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(preset == nil ? "Create Preset" : "Save Changes")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(name.isEmpty ? Color.gray : Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 520, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let p = preset {
                name = p.name
                shotType = p.shotType
                cameraAngle = p.cameraAngle
                lensMm = p.lensMm
                aperture = p.aperture
                movement = p.movement
                presetDescription = p.description
            }
        }
    }

    func editorLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
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

// MARK: - Preview

#Preview {
    ProjectSettingsView()
        .environmentObject(ProjectViewModel())
        .environmentObject(AppCoordinator())
}
