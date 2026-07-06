//
//  ProjectDialogs.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  New/Open project dialogs and file pickers
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - New Project Dialog

struct NewProjectDialog: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @Environment(\.dismiss) var dismiss

    @State private var projectTitle = ""
    @State private var director = ""
    @State private var productionCompany = ""
    @State private var genre = ""
    @State private var saveLocation: URL?
    @State private var showingFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("New Project")
                .font(.title2)
                .fontWeight(.semibold)

            // Form
            Form {
                TextField("Project Title", text: $projectTitle)
                    .textFieldStyle(.roundedBorder)

                TextField("Director", text: $director)
                    .textFieldStyle(.roundedBorder)

                TextField("Production Company", text: $productionCompany)
                    .textFieldStyle(.roundedBorder)

                TextField("Genre", text: $genre)
                    .textFieldStyle(.roundedBorder)

                Divider()

                HStack {
                    Text("Save Location:")
                    Spacer()
                    Button(saveLocation?.lastPathComponent ?? "Choose...") {
                        showingFilePicker = true
                    }
                }
            }
            .formStyle(.grouped)

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(projectTitle.isEmpty || saveLocation == nil)
            }
        }
        .padding(24)
        .frame(width: 450, height: 400)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    saveLocation = url
                }
            case .failure(let error):
                debugLog("File picker error: \(error)")
            }
        }
    }

    private func createProject() {
        projectViewModel.createNew()
        projectViewModel.updateMetadata(
            name: projectTitle,
            director: director,
            productionCompany: productionCompany,
            genre: genre
        )

        if let location = saveLocation {
            let filename = projectTitle.isEmpty ? "Untitled" : projectTitle
            let projectPath = location.appendingPathComponent("\(filename).directorchair")
            projectViewModel.projectPath = projectPath

            Task {
                await projectViewModel.save()
            }
        }

        dismiss()
    }
}

// MARK: - Open Project Dialog

struct OpenProjectDialog: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showingFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Open Project")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Select a DirectorsChair project file")
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Browse...") {
                    showingFilePicker = true
                }
                .keyboardShortcut(.defaultAction)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 250)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json, UTType(filenameExtension: "directorchair")].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        do {
                            try await projectViewModel.load(from: url)
                            dismiss()
                        } catch {
                            debugLog("Failed to load project: \(error)")
                            // TODO: Show error alert
                        }
                    }
                }
            case .failure(let error):
                debugLog("File picker error: \(error)")
            }
        }
        .onAppear {
            // Auto-show file picker when dialog appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingFilePicker = true
            }
        }
    }
}

// MARK: - Preview

#Preview("New Project") {
    NewProjectDialog(projectViewModel: ProjectViewModel())
}

#Preview("Open Project") {
    OpenProjectDialog(projectViewModel: ProjectViewModel())
}
