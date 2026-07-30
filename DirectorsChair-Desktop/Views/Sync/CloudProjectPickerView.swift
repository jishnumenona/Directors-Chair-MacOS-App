// CloudProjectPickerView.swift
//
// "Open from Cloud" (Orgs §12B.7): every project the signed-in user can
// reach, grouped by organization. Projects already on this Mac open in
// place; cloud-only ones are cloned (directory + revision-0 checkpoint +
// pull) into ~/Directors Chair/{username}/ first. List-only entries
// (my_role null, Orgs D3) and never-pushed projects render disabled with
// the reason inline.

import DirectorsChairServices
import SwiftUI

struct CloudProjectPickerView: View {
    @EnvironmentObject private var syncEngine: SyncEngine
    @EnvironmentObject private var projectViewModel: ProjectViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    /// Re-runs the explorer's discovery after a clone lands a new folder.
    var onProjectAdded: () -> Void = {}

    @State private var listings: [SyncEngine.CloudOrgListing] = []
    @State private var localByProjectID: [String: URL] = [:]
    @State private var phase: Phase = .loading
    @State private var busyProjectID: String?

    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 460, height: 440)
        .task { await loadDirectory() }
    }

    private var header: some View {
        HStack {
            Label("Open from Cloud", systemImage: "icloud.and.arrow.down")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            Spacer()
            ProgressView("Loading your cloud projects…")
            Spacer()
        case .failed(let message):
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "xmark.icloud")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await loadDirectory() } }
            }
            .padding(24)
            Spacer()
        case .ready:
            if listings.allSatisfy({ $0.projects.isEmpty }) {
                Spacer()
                Text("No projects in your cloud yet — push one with the "
                     + "sync button in a project's toolbar.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(24)
                Spacer()
            } else {
                List {
                    ForEach(listings) { listing in
                        if !listing.projects.isEmpty {
                            Section(orgTitle(listing.org)) {
                                ForEach(listing.projects, id: \.id) { project in
                                    row(project, org: listing.org)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func orgTitle(_ org: SyncOrg) -> String {
        org.kind == "personal" ? "Personal" : org.name
    }

    @ViewBuilder
    private func row(_ project: SyncProject, org: SyncOrg) -> some View {
        let local = localByProjectID[project.id]
        let blocked = blockedReason(project)
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 6) {
                    if let role = project.myRole {
                        Text(role.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                    if project.archivedAt != nil {
                        Text("Archived")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                    }
                    if let blocked {
                        Text(blocked)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else if local != nil {
                        Text("On this Mac")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if busyProjectID == project.id {
                ProgressView().controlSize(.small)
            } else {
                Button(local == nil ? "Download" : "Open") {
                    Task { await open(project, org: org, localDir: local) }
                }
                .disabled(blocked != nil || busyProjectID != nil)
            }
        }
        .accessibilityIdentifier("cloud-project-\(project.id)")
    }

    /// Why a row can't be opened, or nil when it can.
    private func blockedReason(_ project: SyncProject) -> String? {
        if localByProjectID[project.id] != nil { return nil }  // open always works
        if project.myRole == nil { return "No access — listed only" }
        if (project.headRevision ?? 0) == 0 { return "Empty — never pushed" }
        return nil
    }

    private func loadDirectory() async {
        phase = .loading
        localByProjectID = Self.localIndex()
        do {
            listings = try await syncEngine.cloudDirectory()
            phase = .ready
        } catch {
            phase = .failed((error as? SyncAPIError) == .notAuthenticated
                ? "Sign in to see your cloud projects."
                : "Couldn't reach DirectorsChair Cloud — check your connection.")
        }
    }

    /// projectID → local directory, from each folder's sync checkpoint.
    static func localIndex() -> [String: URL] {
        var index: [String: URL] = [:]
        for dir in ProjectDirectoryManager.listProjects() {
            if let checkpoint = SyncCheckpoint.load(projectDir: dir) {
                index[checkpoint.projectID] = dir
            }
        }
        return index
    }

    @MainActor
    private func open(_ project: SyncProject, org: SyncOrg, localDir: URL?) async {
        busyProjectID = project.id
        defer { busyProjectID = nil }

        var dir = localDir
        if dir == nil {
            guard let root = try? ProjectDirectoryManager.ensureRootExists() else { return }
            dir = await syncEngine.clone(projectID: project.id,
                                         name: project.name,
                                         orgName: orgTitle(org),
                                         myRole: project.myRole,
                                         into: root)
            if dir != nil { onProjectAdded() }
        }
        guard let dir else {
            if case .error(let message) = syncEngine.state {
                phase = .failed(message)
            } else {
                phase = .failed("Download failed — try again.")
            }
            return
        }
        do {
            try await projectViewModel.load(
                from: ProjectDirectoryManager.projectFileURL(in: dir))
            dismiss()
            coordinator.navigateTo(.overview)
        } catch {
            phase = .failed("Downloaded, but the project failed to open: "
                            + error.localizedDescription)
        }
    }
}
