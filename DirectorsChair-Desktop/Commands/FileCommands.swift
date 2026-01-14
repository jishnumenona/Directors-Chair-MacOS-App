//
//  FileCommands.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  File menu commands (New, Open, Save, etc.)
//

import SwiftUI

struct FileCommands: Commands {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var showingNewProjectDialog = false
    @State private var showingOpenProjectDialog = false

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project...") {
                showingNewProjectDialog = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .sheet(isPresented: $showingNewProjectDialog) {
                NewProjectDialog(projectViewModel: projectViewModel)
            }

            Button("Open Project...") {
                showingOpenProjectDialog = true
            }
            .keyboardShortcut("o", modifiers: .command)
            .sheet(isPresented: $showingOpenProjectDialog) {
                OpenProjectDialog(projectViewModel: projectViewModel)
            }

            Divider()

            Button("Close Project") {
                Task {
                    await projectViewModel.close()
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(!projectViewModel.hasProject)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                Task {
                    await projectViewModel.save()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!projectViewModel.isDirty || projectViewModel.projectPath == nil)

            Button("Save As...") {
                Task {
                    // TODO: Show save dialog and call projectViewModel.saveAs
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!projectViewModel.hasProject)

            Divider()

            Button("Force Save") {
                Task {
                    await projectViewModel.forceSave()
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(!projectViewModel.isDirty)
        }
    }
}
