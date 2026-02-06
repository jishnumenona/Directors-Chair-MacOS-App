//
//  ExportCommands.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  Export menu commands for various formats
//

import SwiftUI

struct ExportCommands: Commands {
    @FocusedValue(\.projectViewModel) var projectViewModel: ProjectViewModel?

    var body: some Commands {
        CommandMenu("Export") {
            Button("Export as Fountain...") {
                // TODO: Implement Fountain export using DirectorsChairExports
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as Final Draft (FDX)...") {
                // TODO: Implement FDX export using DirectorsChairExports
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as PDF...") {
                // TODO: Implement PDF export using DirectorsChairExports
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as HTML...") {
                // TODO: Implement HTML export using DirectorsChairExports
            }
            .disabled(projectViewModel?.hasProject != true)

            Divider()

            Button("Export Character Profiles...") {
                // TODO: Implement character profile export
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Shot List...") {
                // TODO: Implement shot list export
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Schedule...") {
                // TODO: Implement schedule export
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Budget...") {
                // TODO: Implement budget export
            }
            .disabled(projectViewModel?.hasProject != true)

            Divider()

            Button("Export All...") {
                // TODO: Implement batch export
            }
            .keyboardShortcut("e", modifiers: [.command, .option, .shift])
            .disabled(projectViewModel?.hasProject != true)
        }
    }
}
