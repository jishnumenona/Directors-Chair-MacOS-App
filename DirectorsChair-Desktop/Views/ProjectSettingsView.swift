//
//  ProjectSettingsView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Project metadata and settings
//

import SwiftUI
import DirectorsChairCore

struct ProjectSettingsView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var title: String = ""
    @State private var director: String = ""
    @State private var productionCompany: String = ""
    @State private var genre: String = ""
    @State private var logline: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Project Metadata Section
                ProjectMetadataSection(
                    title: $title,
                    director: $director,
                    productionCompany: $productionCompany,
                    genre: $genre,
                    logline: $logline
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
        logline != (projectViewModel.project.overviewLogline ?? "")
    }

    private func loadFromProject() {
        title = projectViewModel.project.name
        director = projectViewModel.project.director
        productionCompany = projectViewModel.project.productionCompany
        genre = projectViewModel.project.genre ?? ""
        logline = projectViewModel.project.overviewLogline ?? ""
    }

    private func saveToProject() {
        projectViewModel.project.name = title
        projectViewModel.project.director = director
        projectViewModel.project.productionCompany = productionCompany
        projectViewModel.project.genre = genre.isEmpty ? nil : genre
        projectViewModel.project.overviewLogline = logline.isEmpty ? nil : logline
        projectViewModel.isDirty = true
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
                InfoRow(label: "Created", value: formattedDate(projectViewModel.project.createdAt))
                InfoRow(label: "Last Modified", value: formattedDate(projectViewModel.project.updatedAt))
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
