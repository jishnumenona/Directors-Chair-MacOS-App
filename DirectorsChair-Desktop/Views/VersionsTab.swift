//
//  VersionsTab.swift
//  DirectorsChair-Desktop
//
//  Phase 8B: Navigation & Sidebar
//  Project version history and snapshots
//

import SwiftUI
import DirectorsChairCore

struct VersionsTab: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var versions: [ProjectSnapshot] = []

    var body: some View {
        ScrollView {
            if projectViewModel.hasProject {
                if versions.isEmpty {
                    EmptyVersionsView()
                } else {
                    VersionsList(versions: versions)
                }
            } else {
                NoProjectView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadVersions()
        }
    }

    private func loadVersions() {
        // TODO: Load versions from persistence
        // For now, show empty state
        versions = []
    }
}

// MARK: - Versions List

struct VersionsList: View {
    let versions: [ProjectSnapshot]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(versions) { snapshot in
                VersionRow(snapshot: snapshot)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Version Row

struct VersionRow: View {
    let snapshot: ProjectSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text(snapshot.timestamp, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button("Restore", action: {
                        // TODO: Restore snapshot
                    })
                    Button("Delete", role: .destructive, action: {
                        // TODO: Delete snapshot
                    })
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
            }

            if !snapshot.description.isEmpty {
                Text(snapshot.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 22)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }
}

// MARK: - Empty State

struct EmptyVersionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No Versions")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Snapshots will appear here\nwhen you save versions")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Create Snapshot") {
                // TODO: Create snapshot
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Project Snapshot Model

struct ProjectSnapshot: Identifiable {
    let id: String
    let name: String
    let description: String
    let timestamp: Date
    let projectState: Data
}

// MARK: - Preview

#Preview {
    VersionsTab()
        .environmentObject(ProjectViewModel())
        .frame(width: 300, height: 600)
}
