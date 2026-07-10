//
//  DirectorsChair_DesktopApp.swift
//  DirectorsChair-Desktop
//
//  Phase 8: Main App Integration
//  Application entry point with splash screen
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit

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
    @StateObject private var authManager = AuthManager()
    @StateObject private var cloudSyncManager = CloudSyncManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // UI testing / perf benchmark bypass: skip onboarding and auth gate
        if ProcessInfo.processInfo.arguments.contains("--uitesting") ||
           ProcessInfo.processInfo.arguments.contains("--perf-scenario") ||
           ProcessInfo.processInfo.arguments.contains("--qa-fixture") ||
           ProcessInfo.processInfo.arguments.contains("--qa-fixture-keep") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        _projectViewModel = StateObject(wrappedValue: ProjectViewModel())
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(projectViewModel)
                .environmentObject(onboardingState)
                .environmentObject(tourManager)
                .environmentObject(authManager)
                .environmentObject(cloudSyncManager)
                .focusedValue(\.projectViewModel, projectViewModel)
                .focusedValue(\.appCoordinator, coordinator)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    // Register references with AppDelegate for post-splash actions
                    appDelegate.coordinator = coordinator
                    appDelegate.projectViewModel = projectViewModel
                    appDelegate.onboardingState = onboardingState
                    appDelegate.authManager = authManager

                    // UI-test mode skips the splash, so postLaunchSetup runs in
                    // applicationDidFinishLaunching BEFORE these refs are set —
                    // it early-returns there. Run it here now that the refs
                    // exist (idempotent: normal launches ignore this branch).
                    if TestMode.isUITesting {
                        appDelegate.runPostLaunchSetupForTesting()
                    }

                    // AppDelegate fires fresh every launch — check onboarding there
                    if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                        onboardingState.showOnboarding = true
                    }
                }
                .task {
                    // UI-test mode: launch fully offline and deterministically.
                    // Restoring the session hits the network (dead server on a
                    // machine with a cached token); its variable timing raced
                    // with fixture setup and made the UI suite flaky. Mark the
                    // session authenticated-offline so the LoginView gate
                    // ("Continue Offline") never blocks the test flow.
                    if TestMode.skipAuthAndNetwork {
                        authManager.isAuthenticated = true
                        return
                    }

                    // Restore auth session from Keychain on launch
                    await authManager.restoreSession()
                    // Sync auth token to AI service client
                    let capturedAuthManager = authManager
                    AIServiceClient.shared.tokenProvider = {
                        capturedAuthManager.currentAccessToken
                    }
                    AIServiceClient.shared.tokenRefresher = {
                        try? await capturedAuthManager.forceRefreshToken()
                        return capturedAuthManager.currentAccessToken
                    }
                    if let token = authManager.currentAccessToken {
                        await AIServiceClient.shared.setAuthToken(token)
                        await cloudSyncManager.setAuthToken(token)
                    }
                    // Set per-user project directory based on restored session
                    if authManager.isAuthenticated, let username = authManager.currentUser?.username {
                        NSLog("[App] .task: setting user to %@", username)
                        ProjectDirectoryManager.setCurrentUser(username)
                    } else {
                        NSLog("[App] .task: no auth user, currentUsername=%@", ProjectDirectoryManager.currentUsername)
                    }
                }
                .onChange(of: authManager.currentUser?.username) { oldUsername, newUsername in
                    NSLog("[App] .onChange: username %@ -> %@", oldUsername ?? "nil", newUsername ?? "nil")
                    // Keep the per-user project namespace in sync.
                    ProjectDirectoryManager.setCurrentUser(newUsername)

                    // Only tear down the open project on a GENUINE account change:
                    // a logout, or a switch to a different user. The initial
                    // session restore at launch fires this handler as nil -> user
                    // (and a transient token-refresh failure fires it as user ->
                    // nil), so an unguarded reset here silently wiped the project
                    // the user had open and replaced it with the sample template.
                    let isLogout = newUsername == nil && oldUsername != nil
                    let isAccountSwitch = oldUsername != nil && newUsername != nil && oldUsername != newUsername

                    if isLogout || isAccountSwitch {
                        projectViewModel.projectPath = nil
                        projectViewModel.hasProject = false
                        projectViewModel.project = Project.empty()
                        coordinator.navigateTo(.projects)
                    } else if !projectViewModel.hasProject {
                        // First sign-in of the session with nothing open: land on
                        // the projects list without disturbing any open project.
                        coordinator.navigateTo(.projects)
                    }
                }
                .onOpenURL { url in
                    // Handle OAuth callback URL scheme
                    debugLog("[App] onOpenURL: \(url)")
                    if url.scheme == "directorschair" {
                        Task {
                            do {
                                try await authManager.handleCallback(url: url)
                            } catch {
                                debugLog("[App] onOpenURL callback error: \(error)")
                                authManager.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
        }
        .commands {
            FileCommands(coordinatorRef: coordinator, projectViewModelRef: projectViewModel)
            ViewCommands(coordinatorRef: coordinator, projectViewModelRef: projectViewModel)
            ExportCommands(projectViewModelRef: projectViewModel)
        }

        #if os(macOS)
        Settings {
            SoftwarePreferencesView()
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
    var authManager: AuthManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // UI-test mode: don't hide the window or run the splash at all. Let
        // SwiftUI's WindowGroup present the main window naturally (hiding it
        // and re-showing after a manual delay is exactly what raced the test
        // driver). Setup runs from ContentView.onAppear once the delegate
        // refs are wired (see runPostLaunchSetupForTesting).
        if TestMode.skipSplash {
            return
        }

        // Hide main window initially
        hideMainWindow()

        // Show splash screen
        splashController = SplashWindowController()
        splashController?.showSplash { [weak self] in
            // Splash complete - show and setup main window
            self?.showMainWindow()
            self?.postLaunchSetup()

            // Install remote control key monitor
            RemoteControlService.shared.installGlobalKeyMonitor()
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

    /// UI-test entry point: run postLaunchSetup exactly once, after the
    /// delegate refs are wired from ContentView.onAppear (the splash path is
    /// skipped in test mode, so the normal deferred call finds nil refs).
    private var didRunTestSetup = false
    func runPostLaunchSetupForTesting() {
        guard !didRunTestSetup else { return }
        didRunTestSetup = true
        postLaunchSetup()
    }

    private func postLaunchSetup() {
        guard let projectViewModel = projectViewModel,
              let coordinator = coordinator,
              let onboardingState = onboardingState else { return }

        // QA fixture mode: regenerate + open the deterministic E2E fixture
        // instead of restoring the last project (see qa/README.md).
        if QAFixture.isRequested {
            Task { @MainActor in
                await QAFixture.prepareAndOpen(projectViewModel: projectViewModel,
                                               coordinator: coordinator)
            }
            return
        }

        // Performance benchmark mode: run the scenario instead of the normal
        // restore path, write a JSON report, terminate.
        if let scenario = PerfScenarioRunner.requestedScenario {
            Task { @MainActor in
                await PerfScenarioRunner.run(scenario: scenario,
                                             projectViewModel: projectViewModel,
                                             coordinator: coordinator)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // First-time users see onboarding; returning users restore their project
            if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                onboardingState.showOnboarding = true
            } else {
                Task { @MainActor in
                    if ProjectViewModel.getLastProjectPath() != nil {
                        await projectViewModel.restoreLastProject()
                    } else {
                        coordinator.navigateTo(.projects)
                    }

                    // Show AI assistant on launch if preference is enabled
                    // (never in UI-test mode — it steals focus from the tests).
                    if PreferencesManager.shared.showAssistantOnLaunch && !TestMode.isUITesting {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            coordinator.showingAIChat = true
                        }
                    }
                }
            }
        }
    }

}
