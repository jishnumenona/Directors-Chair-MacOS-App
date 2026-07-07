//
//  FileCommands.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  File menu commands (New, Open, Save, etc.)
//

import SwiftUI
import AppKit
import DirectorsChairServices

struct FileCommands: Commands {
    // Injected app-scoped references (see ViewCommands note re: @FocusedValue).
    var coordinatorRef: AppCoordinator?
    var projectViewModelRef: ProjectViewModel?
    @FocusedValue(\.projectViewModel) var focusedProjectViewModel: ProjectViewModel?
    @FocusedValue(\.appCoordinator) var focusedCoordinator: AppCoordinator?
    var coordinator: AppCoordinator? { coordinatorRef ?? focusedCoordinator }
    var projectViewModel: ProjectViewModel? { projectViewModelRef ?? focusedProjectViewModel }

    init(coordinatorRef: AppCoordinator? = nil, projectViewModelRef: ProjectViewModel? = nil) {
        self.coordinatorRef = coordinatorRef
        self.projectViewModelRef = projectViewModelRef
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project...") {
                guard let viewModel = projectViewModel else { return }
                showNewProjectDialog(viewModel: viewModel)
            }
            .keyboardShortcut("n", modifiers: .command)
            // New Project should always be enabled

            Button("Open Project...") {
                guard let viewModel = projectViewModel else { return }
                openProjectDialog(viewModel: viewModel)
            }
            .keyboardShortcut("o", modifiers: .command)
            // Open Project should always be enabled

            Divider()

            Button("Close Project") {
                Task {
                    await projectViewModel?.close()
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(projectViewModel?.hasProject != true)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                Task {
                    await projectViewModel?.save()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(projectViewModel == nil || projectViewModel?.isDirty != true || projectViewModel?.projectPath == nil)

            Button("Save As...") {
                guard let viewModel = projectViewModel else { return }
                saveAsDialog(viewModel: viewModel)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(projectViewModel?.hasProject != true)

            Divider()

            Button("Force Save") {
                Task {
                    await projectViewModel?.forceSave()
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(projectViewModel?.isDirty != true)
        }
    }

    // MARK: - Helper Functions

    private func openProjectDialog(viewModel: ProjectViewModel) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        panel.message = "Select a DirectorsChair project file"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do {
                    try await viewModel.load(from: url)
                } catch let decodingError as DecodingError {
                    let errorMessage: String
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        errorMessage = "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"
                    case .typeMismatch(let type, let context):
                        errorMessage = "Type mismatch for type '\(type)' at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")): \(context.debugDescription)"
                    case .valueNotFound(let type, let context):
                        errorMessage = "Value not found for type '\(type)' at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")): \(context.debugDescription)"
                    case .dataCorrupted(let context):
                        errorMessage = "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")): \(context.debugDescription)"
                    @unknown default:
                        errorMessage = decodingError.localizedDescription
                    }
                    viewModel.errorAlert = ErrorAlert(
                        title: "Failed to Decode Project",
                        message: errorMessage
                    )
                } catch {
                    viewModel.errorAlert = ErrorAlert(
                        title: "Failed to Open Project",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func saveAsDialog(viewModel: ProjectViewModel) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "project.json"
        panel.message = "Save DirectorsChair project as"
        panel.canCreateDirectories = true

        // Set initial directory to Documents if no project path exists
        if let projectPath = viewModel.projectPath {
            panel.directoryURL = projectPath.deletingLastPathComponent()
            panel.nameFieldStringValue = projectPath.lastPathComponent
        }

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do {
                    try await viewModel.saveAs(to: url)
                } catch {
                    viewModel.errorAlert = ErrorAlert(
                        title: "Failed to Save Project",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func showNewProjectDialog(viewModel: ProjectViewModel) {
        let alert = NSAlert()
        alert.messageText = "New Project"
        alert.informativeText = "Enter a name for your new project.\nIt will be created in ~/Directors Chair/"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        // Add text field for project name
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = "Untitled Project"
        textField.placeholderString = "Project Name"
        alert.accessoryView = textField

        // Make text field first responder
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let projectName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !projectName.isEmpty {
                viewModel.createNew(named: projectName)
            } else {
                viewModel.createNew(named: "Untitled Project")
            }
        }
    }
}
