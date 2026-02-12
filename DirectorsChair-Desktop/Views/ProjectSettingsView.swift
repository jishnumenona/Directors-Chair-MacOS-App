//
//  ProjectSettingsView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Project metadata and settings
//

import SwiftUI
import AppKit
import DirectorsChairCore

struct ProjectSettingsView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var title: String = ""
    @State private var director: String = ""
    @State private var productionCompany: String = ""
    @State private var genre: String = ""
    @State private var logline: String = ""
    @State private var defaultExpenseDepartment: String = ""
    @State private var defaultExpenseAccountCode: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Project Identity Header
                ProjectHeaderBanner(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    subtitle: "Project Settings"
                )
                .cornerRadius(12)

                // Project Metadata Section
                ProjectMetadataSection(
                    title: $title,
                    director: $director,
                    productionCompany: $productionCompany,
                    genre: $genre,
                    logline: $logline
                )

                // Accounting Defaults Section
                AccountingDefaultsSection(
                    defaultExpenseDepartment: $defaultExpenseDepartment,
                    defaultExpenseAccountCode: $defaultExpenseAccountCode
                )

                Divider()

                // Project Information
                ProjectInformationSection(projectViewModel: projectViewModel)

                Divider()

                // Actions
                HStack {
                    Button("Reset") {
                        loadFromProject()
                    }

                    Button {
                        openProjectFolder()
                    } label: {
                        Label("Open Project Folder", systemImage: "folder")
                    }
                    .disabled(projectViewModel.projectPath == nil)

                    Spacer()

                    Button("Save Changes") {
                        saveToProject()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            loadFromProject()
        }
    }

    private var hasChanges: Bool {
        title != projectViewModel.project.name ||
        director != projectViewModel.project.director ||
        productionCompany != projectViewModel.project.productionCompany ||
        genre != (projectViewModel.project.genre ?? "") ||
        logline != (projectViewModel.project.overviewLogline ?? "") ||
        defaultExpenseDepartment != projectViewModel.project.defaultExpenseDepartment ||
        defaultExpenseAccountCode != projectViewModel.project.defaultExpenseAccountCode
    }

    private func loadFromProject() {
        title = projectViewModel.project.name
        director = projectViewModel.project.director
        productionCompany = projectViewModel.project.productionCompany
        genre = projectViewModel.project.genre ?? ""
        logline = projectViewModel.project.overviewLogline ?? ""
        defaultExpenseDepartment = projectViewModel.project.defaultExpenseDepartment
        defaultExpenseAccountCode = projectViewModel.project.defaultExpenseAccountCode
    }

    private func saveToProject() {
        projectViewModel.project.name = title
        projectViewModel.project.director = director
        projectViewModel.project.productionCompany = productionCompany
        projectViewModel.project.genre = genre
        projectViewModel.project.overviewLogline = logline
        projectViewModel.project.defaultExpenseDepartment = defaultExpenseDepartment
        projectViewModel.project.defaultExpenseAccountCode = defaultExpenseAccountCode
        projectViewModel.isDirty = true
    }

    private func openProjectFolder() {
        guard let projectPath = projectViewModel.projectPath else { return }
        let projectDir = projectPath.deletingLastPathComponent()
        NSWorkspace.shared.open(projectDir)
    }
}

// MARK: - Project Metadata Section

struct ProjectMetadataSection: View {
    @Binding var title: String
    @Binding var director: String
    @Binding var productionCompany: String
    @Binding var genre: String
    @Binding var logline: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Metadata")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                LabeledContent("Project Title") {
                    TextField("Enter project title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Director") {
                    TextField("Enter director name", text: $director)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Production Company") {
                    TextField("Enter production company", text: $productionCompany)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Genre") {
                    TextField("Enter genre", text: $genre)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Logline") {
                    TextField("Enter one-line summary", text: $logline, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Accounting Defaults Section

struct AccountingDefaultsSection: View {
    @Binding var defaultExpenseDepartment: String
    @Binding var defaultExpenseAccountCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accounting Defaults")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                LabeledContent("Default Department") {
                    TextField("e.g. Production, Art, Camera", text: $defaultExpenseDepartment)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Default Account Code") {
                    TextField("e.g. 3300", text: $defaultExpenseAccountCode)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Project Information Section

struct ProjectInformationSection: View {
    @ObservedObject var projectViewModel: ProjectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Information")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 16) {
                InfoRow(label: "Project ID", value: projectViewModel.project.id)
                InfoRow(label: "Last Saved", value: projectViewModel.lastSaved.map { formattedDate($0) } ?? "Never")
                InfoRow(label: "File Path", value: projectViewModel.projectPath?.path ?? "Not saved")

                InfoRow(label: "Sequences", value: "\(projectViewModel.sequences.count)")
                InfoRow(label: "Scenes", value: "\(projectViewModel.allScenes.count)")
                InfoRow(label: "Characters", value: "\(projectViewModel.characters.count)")
                InfoRow(label: "Shots", value: "\(projectViewModel.allShots.count)")
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectSettingsView()
        .environmentObject(ProjectViewModel())
}
