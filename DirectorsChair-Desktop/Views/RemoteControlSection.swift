//
//  RemoteControlSection.swift
//  DirectorsChair-Desktop
//
//  Remote control button mapping UI for the Hardware popover.
//  Learn clicker buttons and assign them to app actions.
//

import SwiftUI

// MARK: - Remote Control Section

struct RemoteControlSection: View {
    @ObservedObject private var service = RemoteControlService.shared

    var body: some View {
        HardwareSection(icon: "av.remote", title: "REMOTE CONTROL", count: service.mappings.count) {
            VStack(spacing: 10) {
                // Enable toggle
                HStack {
                    Text("Enable Remote")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $service.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                if service.isEnabled {
                    // Action rows
                    ForEach(RemoteAction.allCases) { action in
                        RemoteActionRow(action: action, service: service)
                    }

                    // Clear all
                    if !service.mappings.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                service.clearAllMappings()
                            } label: {
                                Text("Clear All Mappings")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .overlay {
            if service.learningAction != nil {
                LearnModeOverlay(service: service)
            }
        }
    }
}

// MARK: - Action Row

private struct RemoteActionRow: View {
    let action: RemoteAction
    @ObservedObject var service: RemoteControlService

    private var mapping: KeyMapping? {
        service.mappings[action]
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.systemImage)
                .font(.system(size: 10))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)

            Text(action.displayName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)

            Spacer()

            if let mapping = mapping {
                // Key badge
                HStack(spacing: 4) {
                    Text(mapping.keyName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.6))
                        .clipShape(Capsule())

                    // Remove button
                    Button {
                        service.removeMapping(for: action)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                // Re-learn button
                Button {
                    service.startLearning(action)
                } label: {
                    Text("Re-learn")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    service.startLearning(action)
                } label: {
                    Label("Learn", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 9, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(mapping != nil ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(mapping != nil ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Learn Mode Overlay

private struct LearnModeOverlay: View {
    @ObservedObject var service: RemoteControlService

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text("Press a button on your clicker...")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)

            if let action = service.learningAction {
                Text("Mapping: \(action.displayName)")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button("Cancel") {
                service.cancelLearning()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.9))
        )
    }
}
