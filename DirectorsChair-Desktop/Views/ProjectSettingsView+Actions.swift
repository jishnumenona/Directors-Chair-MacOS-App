//
// ProjectSettingsView+Actions.swift
//
// Extracted from ProjectSettingsView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

extension ProjectSettingsView {

    // MARK: - Project Stats Section

    var projectStatsSection: some View {
        SettingsCard(title: "PROJECT STATS", icon: "chart.bar.fill") {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 14) {
                StatBadge(icon: "rectangle.stack", label: "Sequences", value: "\(projectViewModel.sequences.count)")
                StatBadge(icon: "film", label: "Scenes", value: "\(projectViewModel.allScenes.count)")
                StatBadge(icon: "person.3.fill", label: "Characters", value: "\(projectViewModel.characters.count)")
                StatBadge(icon: "camera.fill", label: "Shots", value: "\(projectViewModel.allShots.count)")
                StatBadge(icon: "map.fill", label: "Locations", value: "\(projectViewModel.project.locations.count)")
                StatBadge(icon: "text.bubble", label: "Dialogues", value: "\(countDialogues())")
                StatBadge(icon: "person.2.fill", label: "Cast", value: "\(projectViewModel.project.castMembers.count)")
                StatBadge(icon: "wrench.and.screwdriver", label: "Crew", value: "\(projectViewModel.project.crewMembers.count)")
            }
        }
    }

    // MARK: - Project File Section

    var projectFileSection: some View {
        SettingsCard(title: "FILE DETAILS", icon: "doc.badge.gearshape") {
            VStack(alignment: .leading, spacing: 14) {
                SettingsInfoRow(
                    icon: "number",
                    label: "Project ID",
                    value: projectViewModel.project.id
                )

                Divider().opacity(0.3)

                SettingsInfoRow(
                    icon: "clock",
                    label: "Last Saved",
                    value: projectViewModel.lastSaved.map { formattedDate($0) } ?? "Never"
                )

                Divider().opacity(0.3)

                SettingsInfoRow(
                    icon: "folder",
                    label: "File Path",
                    value: projectViewModel.projectPath?.deletingLastPathComponent().path ?? "Not saved"
                )

                Divider().opacity(0.3)

                SettingsInfoRow(
                    icon: "internaldrive",
                    label: "Storage Size",
                    value: formattedStorageSize(projectViewModel.projectStorageSize)
                )

                // Quick actions
                HStack(spacing: 10) {
                    Button {
                        openProjectFolder()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                            Text("Open in Finder")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(projectViewModel.projectPath == nil)

                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Guided Tour

    var guidedTourSection: some View {
        SettingsCard(title: "GUIDED TOUR", icon: "questionmark.circle") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Re-run the guided walkthrough to learn about the app's features.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Button {
                        tourManager.resetTour()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("Restart Guided Tour")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if tourManager.hasCompletedTour {
                        Text("Tour completed")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Save Bar

    var saveBar: some View {
        HStack(spacing: 12) {
            Button {
                loadFromProject()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10))
                    Text("Discard")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .quaternarySystemFill))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                saveToProject()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Save Changes")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - AI Helper Views

    func aiProviderRow(label: String, icon: String, provider: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(provider)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Text(detail)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
    }

    func costInfoCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }

    // MARK: - Data Operations

    func loadFromProject() {
        let p = projectViewModel.project
        title = p.name
        tagline = p.overviewTagline
        logline = p.overviewLogline
        projectDescription = p.description
        director = p.director
        productionCompany = p.productionCompany
        genre = p.genre
        status = p.status
        projectType = p.projectType
        targetDuration = p.targetDuration
        budget = p.budget
        startDate = p.startDate
        endDate = p.endDate
        defaultExpenseDepartment = p.defaultExpenseDepartment
        defaultExpenseAccountCode = p.defaultExpenseAccountCode
        aiProxyURL = "https://directorschair.app/ai"
        hasUnsavedChanges = false
    }

    func saveToProject() {
        projectViewModel.project.name = title
        projectViewModel.project.overviewTagline = tagline
        projectViewModel.project.overviewLogline = logline
        projectViewModel.project.description = projectDescription
        projectViewModel.project.director = director
        projectViewModel.project.productionCompany = productionCompany
        projectViewModel.project.genre = genre
        projectViewModel.project.status = status
        projectViewModel.project.projectType = projectType
        projectViewModel.project.targetDuration = targetDuration
        projectViewModel.project.budget = budget
        projectViewModel.project.startDate = startDate
        projectViewModel.project.endDate = endDate
        projectViewModel.project.defaultExpenseDepartment = defaultExpenseDepartment
        projectViewModel.project.defaultExpenseAccountCode = defaultExpenseAccountCode
        projectViewModel.isDirty = true
        hasUnsavedChanges = false
    }

    func checkForChanges() {
        let p = projectViewModel.project
        hasUnsavedChanges =
            title != p.name ||
            tagline != p.overviewTagline ||
            logline != p.overviewLogline ||
            projectDescription != p.description ||
            director != p.director ||
            productionCompany != p.productionCompany ||
            genre != p.genre ||
            status != p.status ||
            projectType != p.projectType ||
            targetDuration != p.targetDuration ||
            budget != p.budget ||
            startDate != p.startDate ||
            endDate != p.endDate ||
            defaultExpenseDepartment != p.defaultExpenseDepartment ||
            defaultExpenseAccountCode != p.defaultExpenseAccountCode
    }

    func checkAIHealth() {
        aiCheckingHealth = true
        Task {
            let client = AIServiceClient.shared
            let connected = await client.testConnection()

            // Try to get provider availability via health check
            var providers: [String: Bool] = [:]
            if connected {
                if let health = try? await client.checkHealth() {
                    providers = health.providers
                }
            }

            await MainActor.run {
                aiServerHealthy = connected
                aiAvailableProviders = providers
                aiCheckingHealth = false
            }
        }
    }

    func openProjectFolder() {
        guard let projectPath = projectViewModel.projectPath else { return }
        let projectDir = projectPath.deletingLastPathComponent()
        NSWorkspace.shared.open(projectDir)
    }

    func countDialogues() -> Int {
        projectViewModel.project.sequences.flatMap(\.scenes).reduce(0) { total, scene in
            total + scene.dialogues.count
        }
    }

    func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }

    func formattedStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
