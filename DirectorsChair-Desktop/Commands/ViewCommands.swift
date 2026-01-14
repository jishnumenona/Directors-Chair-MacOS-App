//
//  ViewCommands.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  View menu commands for navigation
//

import SwiftUI

struct ViewCommands: Commands {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some Commands {
        CommandMenu("View") {
            // Main Views
            Menu("Go to View") {
                Button("Project Overview") {
                    coordinator.navigateTo(.overview)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Bubble View") {
                    coordinator.navigateTo(.bubble)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Scenes") {
                    coordinator.navigateTo(.scenes)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Assets") {
                    coordinator.navigateTo(.assets)
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button("Vision Board") {
                    coordinator.navigateTo(.visionBoard)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Shot List") {
                    coordinator.navigateTo(.shotList)
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Schedule") {
                    coordinator.navigateTo(.schedule)
                }
                .keyboardShortcut("7", modifiers: .command)

                Button("Cast & Crew") {
                    coordinator.navigateTo(.castCrew)
                }
                .keyboardShortcut("8", modifiers: .command)

                Divider()

                Button("Story Design") {
                    coordinator.navigateTo(.storyDesign)
                }
                .keyboardShortcut("9", modifiers: .command)

                Button("Project Settings") {
                    coordinator.navigateTo(.settings)
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            Divider()

            // Panel Toggles
            Button("Toggle Navigator") {
                coordinator.toggleNavigator()
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Toggle Timeline") {
                coordinator.toggleTimeline()
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Toggle Right Panel") {
                coordinator.toggleRightPanel()
            }
            .keyboardShortcut("3", modifiers: [.command, .option])

            Button("Toggle Comments") {
                coordinator.toggleComments()
            }
            .keyboardShortcut("4", modifiers: [.command, .option])

            Divider()

            // View Options
            Button("Show All Panels") {
                coordinator.showingNavigator = true
                coordinator.showingTimeline = true
                coordinator.showingRightPanel = true
            }
            .keyboardShortcut("a", modifiers: [.command, .option])

            Button("Hide All Panels") {
                coordinator.showingNavigator = false
                coordinator.showingTimeline = false
                coordinator.showingRightPanel = false
            }
            .keyboardShortcut("h", modifiers: [.command, .option])
        }
    }
}
