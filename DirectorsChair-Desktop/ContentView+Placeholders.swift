//
// ContentView+Placeholders.swift
//
// Extracted from ContentView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were already internal helper views.
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairProduction
import DirectorsChairServices


// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)

                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }
}

// MARK: - AI Progress Tracker

/// Tracks AI operation progress across navigation. Class-based so it can be
/// captured in @Sendable closures and updated from async callbacks.
final class AIProgressTracker: ObservableObject, @unchecked Sendable {
    @Published var traitAnalysis: [String: Int] = [:]
    @Published var biography: [String: Int] = [:]
}

// MARK: - Central View Stack

/// Routes to the appropriate view based on coordinator.selectedView

// MARK: - Placeholder Views

struct ProjectOverviewPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Overview", description: "Project pitch and overview information")
    }
}

struct ScenesPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Scenes", description: "Scene list and management")
    }
}

struct AssetsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Assets", description: "Media library and asset management")
    }
}

struct SettingsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Settings", description: "Project metadata and configuration")
    }
}


// MARK: - Generic Placeholder View

struct PlaceholderView: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title)
                .fontWeight(.semibold)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Production View Wrapper

/// Wraps production views with a project identity header

// MARK: - Project snapshots (P1 §2.17)
//
// Browse, create, restore, delete — one sheet, reached from
// File → Project Snapshots… (⌥⌘S). Restore is deliberately calm: the
// current state is snapshotted first, and the swap itself is a normal
// undoable edit, so there is nothing here a user can't take back.

struct SnapshotsSheet: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var snapshots: [DirectorsChairCore.ProjectSnapshot] = []
    @State private var newLabel = ""
    @State private var confirmRestore: DirectorsChairCore.ProjectSnapshot?
    @State private var working = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Project Snapshots")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            HStack(spacing: 8) {
                TextField("Name this snapshot (e.g. \"Before the recut\")",
                          text: $newLabel)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { createSnapshot() }
                Button {
                    createSnapshot()
                } label: {
                    Label("Snapshot Now", systemImage: "camera")
                }
                .disabled(working)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if snapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text("No snapshots yet")
                        .foregroundStyle(.secondary)
                    Text("A daily snapshot is taken the first time the "
                         + "project opens each day; save your own before "
                         + "big changes.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(snapshots) { snapshot in
                    snapshotRow(snapshot)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 520, height: 440)
        .task { await refresh() }
        .alert("Restore this snapshot?",
               isPresented: Binding(get: { confirmRestore != nil },
                                    set: { if !$0 { confirmRestore = nil } }),
               presenting: confirmRestore) { snapshot in
            Button("Restore", role: .destructive) {
                restore(snapshot)
            }
            Button("Cancel", role: .cancel) { confirmRestore = nil }
        } message: { snapshot in
            Text("The project becomes \"\(snapshot.label)\" from "
                 + snapshot.date.formatted(date: .abbreviated,
                                           time: .shortened)
                 + ". Your current state is snapshotted first, and the "
                 + "restore itself can be undone with \u{2318}Z.")
        }
    }

    @ViewBuilder
    private func snapshotRow(
        _ snapshot: DirectorsChairCore.ProjectSnapshot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: snapshot.isAutomatic ? "calendar" : "camera.fill")
                .foregroundStyle(snapshot.isAutomatic
                                 ? AnyShapeStyle(.secondary)
                                 : AnyShapeStyle(Color.accentColor))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.label)
                    .font(.system(size: 13, weight: .medium))
                Text(snapshot.date.formatted(date: .abbreviated,
                                             time: .shortened)
                     + " · "
                     + ByteCountFormatter.string(
                         fromByteCount: snapshot.sizeBytes,
                         countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore") { confirmRestore = snapshot }
                .disabled(working)
            Button {
                deleteSnapshot(snapshot)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red.opacity(0.8))
            .disabled(working)
        }
        .padding(.vertical, 2)
    }

    private func refresh() async {
        guard let path = projectViewModel.projectPath else { return }
        snapshots = await ProjectSnapshotStore.shared
            .list(forProjectAt: path)
    }

    private func createSnapshot() {
        working = true
        let label = newLabel
        newLabel = ""
        Task {
            await projectViewModel.snapshotNow(label: label)
            await refresh()
            working = false
        }
    }

    private func restore(_ snapshot: DirectorsChairCore.ProjectSnapshot) {
        working = true
        Task {
            await projectViewModel.restoreSnapshot(snapshot)
            await refresh()
            working = false
            dismiss()
        }
    }

    private func deleteSnapshot(_ snapshot: DirectorsChairCore.ProjectSnapshot) {
        working = true
        Task {
            guard projectViewModel.projectPath != nil else { return }
            try? await ProjectSnapshotStore.shared.delete(snapshot)
            await refresh()
            working = false
        }
    }
}
