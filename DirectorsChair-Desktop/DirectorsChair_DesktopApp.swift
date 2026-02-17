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
import Sparkle

// MARK: - Onboarding State

/// Observable flag shared between AppDelegate and SwiftUI views.
/// The AppDelegate sets `showOnboarding` after checking UserDefaults in
/// `applicationDidFinishLaunching` (which always runs fresh, immune to
/// SwiftUI scene-state restoration).
class OnboardingState: ObservableObject {
    @Published var showOnboarding = false

    func complete() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

@main
struct DirectorsChair_DesktopApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var projectViewModel: ProjectViewModel
    @StateObject private var onboardingState = OnboardingState()
    @StateObject private var tourManager = GuidedTourManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _projectViewModel = StateObject(wrappedValue: ProjectViewModel())
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(projectViewModel)
                .environmentObject(onboardingState)
                .environmentObject(tourManager)
                .focusedValue(\.projectViewModel, projectViewModel)
                .focusedValue(\.appCoordinator, coordinator)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    // Register references with AppDelegate for post-splash actions
                    appDelegate.coordinator = coordinator
                    appDelegate.projectViewModel = projectViewModel
                    appDelegate.onboardingState = onboardingState

                    // AppDelegate fires fresh every launch — check onboarding there
                    if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                        onboardingState.showOnboarding = true
                    }
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updaterController.updater)
            }
            FileCommands()
            ViewCommands()
            ExportCommands()
        }

        #if os(macOS)
        Settings {
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
    var onboardingState: OnboardingState?

    /// Sparkle auto-update controller
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

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
            if let window = NSApplication.shared.windows.first(where: { $0.contentView is NSHostingView<ContentView> }) ?? NSApplication.shared.windows.first {
                if let screen = window.screen ?? NSScreen.main {
                    window.setFrame(screen.visibleFrame, display: true, animate: false)
                }

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
              let coordinator = coordinator,
              let onboardingState = onboardingState else { return }

        // TESTING ONLY: Ask user whether to show onboarding
        // TODO: Remove this prompt before packaging/shipping
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let alert = NSAlert()
            alert.messageText = "First-time launch?"
            alert.informativeText = "(Testing only) Show the first-time onboarding screen?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Yes — Show Onboarding")
            alert.addButton(withTitle: "No — Go to Projects")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Show onboarding
                onboardingState.showOnboarding = true
            } else {
                // Normal launch — restore last project or show projects
                Task { @MainActor in
                    if ProjectViewModel.getLastProjectPath() != nil {
                        await projectViewModel.restoreLastProject()
                    } else {
                        let existingProjects = ProjectDirectoryManager.listProjects()
                        if existingProjects.isEmpty {
                            coordinator.navigateTo(.projects)
                        }
                    }
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
