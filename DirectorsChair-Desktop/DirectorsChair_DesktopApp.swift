//
//  DirectorsChair_DesktopApp.swift
//  DirectorsChair-Desktop
//
//  Phase 8: Main App Integration
//  Application entry point
//

import SwiftUI
import DirectorsChairCore

@main
struct DirectorsChair_DesktopApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var projectViewModel: ProjectViewModel

    init() {
        // Initialize with empty project (no project loaded initially)
        _projectViewModel = StateObject(wrappedValue: ProjectViewModel())
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(projectViewModel)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            // Phase 8C: Menu Bar & Commands
            FileCommands()
                .environmentObject(projectViewModel)

            ViewCommands()
                .environmentObject(coordinator)

            ExportCommands()
                .environmentObject(projectViewModel)
        }

        #if os(macOS)
        Settings {
            // TODO: Add preferences view in Phase 8E
            Text("Preferences")
                .frame(width: 600, height: 400)
        }
        #endif
    }
}
