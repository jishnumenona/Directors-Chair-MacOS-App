//
//  ViewCommands.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  View menu commands for navigation
//

import SwiftUI
import AppKit

struct ViewCommands: Commands {
    @FocusedValue(\.appCoordinator) var coordinator: AppCoordinator?
    @FocusedValue(\.projectViewModel) var projectViewModel: ProjectViewModel?

    var body: some Commands {
        CommandMenu("View") {
            // Main Views
            Menu("Go to View") {
                Button("Project Overview") {
                    coordinator?.navigateTo(.overview)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Bubble View") {
                    coordinator?.navigateTo(.bubble)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Scenes") {
                    coordinator?.navigateTo(.scenes)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Assets") {
                    coordinator?.navigateTo(.assets)
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button("Vision Board") {
                    coordinator?.navigateTo(.visionBoard)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Shot List") {
                    coordinator?.navigateTo(.shotList)
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Production") {
                    coordinator?.navigateTo(.production)
                }
                .keyboardShortcut("7", modifiers: .command)

                Divider()

                Button("Story Design") {
                    coordinator?.navigateTo(.storyDesign)
                }
                .keyboardShortcut("8", modifiers: .command)

                Button("Project Settings") {
                    coordinator?.navigateTo(.settings)
                }
                .keyboardShortcut("9", modifiers: .command)
            }

            Divider()

            // Panel Toggles
            Button("Toggle Navigator") {
                coordinator?.toggleNavigator()
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Toggle Timeline") {
                coordinator?.toggleTimeline()
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Toggle Right Panel") {
                coordinator?.toggleRightPanel()
            }
            .keyboardShortcut("3", modifiers: [.command, .option])

            Button("Toggle Comments") {
                coordinator?.toggleComments()
            }
            .keyboardShortcut("4", modifiers: [.command, .option])

            Button("Toggle Usage Widget") {
                coordinator?.toggleUsageWidget()
            }
            .keyboardShortcut("5", modifiers: [.command, .option])

            Divider()

            // View Options
            Button("Show All Panels") {
                coordinator?.showingNavigator = true
                coordinator?.showingTimeline = true
                coordinator?.showingRightPanel = true
            }
            .keyboardShortcut("a", modifiers: [.command, .option])

            Button("Hide All Panels") {
                coordinator?.showingNavigator = false
                coordinator?.showingTimeline = false
                coordinator?.showingRightPanel = false
            }
            .keyboardShortcut("h", modifiers: [.command, .option])

            Divider()

            Button("AI Chat Assistant") {
                coordinator?.toggleAIChat()
            }
            .keyboardShortcut(" ", modifiers: [.command, .shift])

            Divider()

            // Project Folder
            Button("Open Project Folder in Finder") {
                guard let projectPath = projectViewModel?.projectPath else { return }
                let projectDir = projectPath.deletingLastPathComponent()
                NSWorkspace.shared.open(projectDir)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(projectViewModel?.projectPath == nil)
        }
    }
}
