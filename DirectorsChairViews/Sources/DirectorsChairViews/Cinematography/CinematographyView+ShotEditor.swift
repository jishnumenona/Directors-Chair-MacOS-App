//
// CinematographyView+ShotEditor.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Shot Editor Sheet

struct ShotEditorSheet: View {
    @Binding var shot: Shot
    let presets: [CameraPreset]
    let characters: [Character]
    @Binding var isPresented: Bool
    var onSave: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(shot.shotId == 0 ? "New Shot" : "Edit Shot #\(shot.shotId)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.gray)
                        CharacterMentionTextEditor(
                            text: $shot.description,
                            characters: characters,
                            placeholder: "Write a description..."
                        )
                        .frame(minHeight: 80)
                        .background(Color(hex: "#1E1E1E"))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Status
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("Status", selection: $shot.status) {
                            ForEach(ShotStatus.allCases) { status in
                                Text(status.rawValue).tag(status.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    // Camera Settings
                    Text("Camera Settings")
                        .font(.headline)
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Camera Angle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Camera Angle")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Angle", selection: $shot.cameraAngle) {
                                ForEach(CameraAngleOptions.angles, id: \.self) { angle in
                                    Text(angle).tag(angle)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Shot Type
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shot Type")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Type", selection: $shot.shotType) {
                                ForEach(CameraAngleOptions.shotTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Lens
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lens (mm)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Lens", selection: Binding(
                                get: { shot.lensMm ?? 50 },
                                set: { shot.lensMm = $0 }
                            )) {
                                ForEach(CameraAngleOptions.commonLenses, id: \.self) { lens in
                                    Text("\(lens)mm").tag(lens)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Aperture
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aperture")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Aperture", selection: $shot.aperture) {
                                ForEach(CameraAngleOptions.commonApertures, id: \.self) { ap in
                                    Text(ap).tag(ap)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Movement
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Movement")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Movement", selection: $shot.movement) {
                                ForEach(CameraAngleOptions.movements, id: \.self) { mov in
                                    Text(mov).tag(mov)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration (seconds)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Duration", value: Binding(
                                get: { shot.duration ?? 0 },
                                set: { shot.duration = $0 > 0 ? $0 : nil }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave?()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: 600, height: 550)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Preview

// MARK: - Linked Script Elements Section

/// Shows dialogues, actions, and narrations connected to a shot
/// with color-coded type indicators and "Jump to Script" navigation
