//
//  ProjectOverviewView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Project overview and pitch information
//

import SwiftUI
import DirectorsChairCore

struct ProjectOverviewView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var isEditingPitch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Project Header
                ProjectHeaderSection(project: projectViewModel.project)

                Divider()

                // Project Pitch
                ProjectPitchSection(
                    project: $projectViewModel.project,
                    isEditing: $isEditingPitch
                )

                Divider()

                // Project Statistics
                ProjectStatisticsSection(projectViewModel: projectViewModel)

                Divider()

                // Quick Actions
                QuickActionsSection()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Project Header Section

struct ProjectHeaderSection: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(project.title)
                .font(.system(size: 32, weight: .bold))

            HStack(spacing: 16) {
                if !project.director.isEmpty {
                    Label(project.director, systemImage: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                if !project.productionCompany.isEmpty {
                    Label(project.productionCompany, systemImage: "building.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                if !project.genre.isEmpty {
                    Label(project.genre, systemImage: "theatermasks.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Project Pitch Section

struct ProjectPitchSection: View {
    @Binding var project: Project
    @Binding var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Project Pitch")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    isEditing.toggle()
                }) {
                    Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(.borderedProminent)
            }

            if isEditing {
                TextEditor(text: Binding(
                    get: { project.pitch ?? "" },
                    set: { project.pitch = $0 }
                ))
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } else {
                if let pitch = project.pitch, !pitch.isEmpty {
                    Text(pitch)
                        .font(.body)
                        .foregroundColor(.primary)
                } else {
                    Text("No pitch written yet. Click Edit to add a pitch.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
}

// MARK: - Project Statistics Section

struct ProjectStatisticsSection: View {
    @ObservedObject var projectViewModel: ProjectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Statistics")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    icon: "film.stack",
                    title: "Sequences",
                    value: "\(projectViewModel.sequences.count)",
                    color: .blue
                )

                StatCard(
                    icon: "film",
                    title: "Scenes",
                    value: "\(projectViewModel.allScenes.count)",
                    color: .green
                )

                StatCard(
                    icon: "person.3.fill",
                    title: "Characters",
                    value: "\(projectViewModel.characters.count)",
                    color: .purple
                )

                StatCard(
                    icon: "camera.fill",
                    title: "Shots",
                    value: "\(projectViewModel.project.shots.count)",
                    color: .orange
                )

                StatCard(
                    icon: "square.grid.2x2",
                    title: "Vision Cards",
                    value: "\(projectViewModel.project.visionCards.count)",
                    color: .pink
                )

                StatCard(
                    icon: "calendar",
                    title: "Schedule Items",
                    value: "\(projectViewModel.project.scheduleItems.count)",
                    color: .red
                )
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Edit Dialogue",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                ) {
                    coordinator.navigateTo(.bubble)
                }

                QuickActionButton(
                    title: "Manage Characters",
                    icon: "book",
                    color: .purple
                ) {
                    coordinator.navigateTo(.storyDesign)
                }

                QuickActionButton(
                    title: "Vision Board",
                    icon: "square.grid.2x2",
                    color: .pink
                ) {
                    coordinator.navigateTo(.visionBoard)
                }

                QuickActionButton(
                    title: "Shot List",
                    icon: "camera",
                    color: .orange
                ) {
                    coordinator.navigateTo(.shotList)
                }

                QuickActionButton(
                    title: "Production Schedule",
                    icon: "calendar",
                    color: .red
                ) {
                    coordinator.navigateTo(.schedule)
                }

                QuickActionButton(
                    title: "Project Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    coordinator.navigateTo(.settings)
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)

                Text(title)
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ProjectOverviewView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
}
