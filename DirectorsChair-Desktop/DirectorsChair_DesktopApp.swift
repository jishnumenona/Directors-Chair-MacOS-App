//
//  DirectorsChair_DesktopApp.swift
//  DirectorsChair-Desktop
//
//  Phase 8: Main App Integration
//  Application entry point with splash screen
//

import SwiftUI
import DirectorsChairCore
import AppKit

@main
struct DirectorsChair_DesktopApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var projectViewModel: ProjectViewModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Initialize with empty project (no project loaded initially)
        _projectViewModel = StateObject(wrappedValue: ProjectViewModel())
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(projectViewModel)
                .focusedValue(\.projectViewModel, projectViewModel)
                .focusedValue(\.appCoordinator, coordinator)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    // Register references with AppDelegate for post-splash actions
                    appDelegate.coordinator = coordinator
                    appDelegate.projectViewModel = projectViewModel
                }
        }
        .commands {
            // Phase 8C: Menu Bar & Commands
            FileCommands()
            ViewCommands()
            ExportCommands()
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

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var splashController: SplashWindowController?
    var coordinator: AppCoordinator?
    var projectViewModel: ProjectViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide main window initially
        hideMainWindow()

        // Show splash screen
        splashController = SplashWindowController()
        splashController?.showSplash { [weak self] in
            // Splash complete - show and setup main window
            self?.showMainWindow()
            self?.postLaunchSetup()
        }
    }

    private func hideMainWindow() {
        // Hide the main window while splash is showing
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                if window.contentView is NSHostingView<ContentView> ||
                   window.title.contains("Directors") ||
                   window.className.contains("AppKit") {
                    window.orderOut(nil)
                }
            }
        }
    }

    private func showMainWindow() {
        DispatchQueue.main.async {
            // Find and show the main window
            if let window = NSApplication.shared.windows.first(where: { $0.contentView is NSHostingView<ContentView> }) ?? NSApplication.shared.windows.first {
                // Maximize to fill screen
                if let screen = window.screen ?? NSScreen.main {
                    window.setFrame(screen.visibleFrame, display: true, animate: false)
                }

                // Show with fade in
                window.alphaValue = 0
                window.makeKeyAndOrderFront(nil)

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    window.animator().alphaValue = 1
                }
            }
        }
    }

    private func postLaunchSetup() {
        guard let projectViewModel = projectViewModel,
              let coordinator = coordinator else { return }

        Task { @MainActor in
            // Check if there's a last project to restore
            if ProjectViewModel.getLastProjectPath() != nil {
                await projectViewModel.restoreLastProject()
            } else {
                // Check if any projects exist in Directors Chair folder
                let existingProjects = ProjectDirectoryManager.listProjects()
                if existingProjects.isEmpty {
                    // First time user - show welcome and prompt to create project
                    coordinator.navigateTo(.settings)
                    showNewProjectPrompt(projectViewModel: projectViewModel, coordinator: coordinator)
                }
            }
        }
    }

    private func showNewProjectPrompt(projectViewModel: ProjectViewModel, coordinator: AppCoordinator) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Welcome to Director's Chair!"
            alert.informativeText = "It looks like this is your first time here. Would you like to create a new project to get started?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Create New Project")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.showNewProjectDialog(projectViewModel: projectViewModel, coordinator: coordinator)
            }
        }
    }

    private func showNewProjectDialog(projectViewModel: ProjectViewModel, coordinator: AppCoordinator) {
        let alert = NSAlert()
        alert.messageText = "New Project"
        alert.informativeText = "Enter a name for your new project.\nIt will be created in ~/Directors Chair/"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = "My First Project"
        textField.placeholderString = "Project Name"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let projectName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                if !projectName.isEmpty {
                    projectViewModel.createNew(named: projectName)
                } else {
                    projectViewModel.createNew(named: "My First Project")
                }
                coordinator.navigateTo(.overview)
            }
        }
    }
}
