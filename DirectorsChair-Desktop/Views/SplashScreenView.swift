//
//  SplashScreenView.swift
//  DirectorsChair-Desktop
//
//  Professional splash screen with loading progress
//

import SwiftUI
import AppKit
import DirectorsChairCore

// MARK: - Splash Screen View

struct SplashScreenView: View {
    @ObservedObject var loadingState: LoadingStateManager

    var body: some View {
        ZStack {
            // Background — matched to LaunchHero image outer edge color
            Color(red: 0.0, green: 0.02, blue: 0.04)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Launch Hero Image — blends seamlessly with matched background
                Image("LaunchHero")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 540, maxHeight: 420)

                Spacer()
                    .frame(height: 40)

                // Loading Section
                VStack(spacing: 16) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)

                            // Progress fill with glow
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.4, green: 0.8, blue: 1.0),
                                            Color(red: 0.2, green: 0.6, blue: 0.9)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * loadingState.progress, height: 6)
                                .shadow(color: Color.cyan.opacity(0.6), radius: 8)
                                .animation(.easeInOut(duration: 0.3), value: loadingState.progress)
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 400)

                    // Status Text
                    Text(loadingState.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                        .frame(height: 20)
                        .animation(.easeInOut(duration: 0.2), value: loadingState.statusMessage)
                }
                .padding(.horizontal, 60)

                Spacer()
                    .frame(height: 40)

                // Version info
                HStack {
                    Text("Version 1.0.0")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.4))

                    Spacer()

                    Text("© 2024 Director's Chair")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - Loading State Manager

class LoadingStateManager: ObservableObject {
    @Published var progress: CGFloat = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false

    // Loading stages
    enum LoadingStage: CaseIterable {
        case initializing
        case loadingCore
        case loadingUI
        case loadingServices
        case preparingWorkspace
        case restoringProject
        case complete

        var message: String {
            switch self {
            case .initializing: return "Initializing..."
            case .loadingCore: return "Loading core modules..."
            case .loadingUI: return "Preparing user interface..."
            case .loadingServices: return "Starting services..."
            case .preparingWorkspace: return "Preparing workspace..."
            case .restoringProject: return "Restoring last project..."
            case .complete: return "Ready"
            }
        }

        var progress: CGFloat {
            switch self {
            case .initializing: return 0.05
            case .loadingCore: return 0.20
            case .loadingUI: return 0.40
            case .loadingServices: return 0.60
            case .preparingWorkspace: return 0.80
            case .restoringProject: return 0.95
            case .complete: return 1.0
            }
        }
    }

    func updateStage(_ stage: LoadingStage) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.progress = stage.progress
                self.statusMessage = stage.message
                self.isComplete = stage == .complete
            }
        }
    }

    func setCustomStatus(_ message: String, progress: CGFloat) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.statusMessage = message
                self.progress = progress
            }
        }
    }
}

// MARK: - Splash Window Controller

class SplashWindowController: NSObject {
    private var splashWindow: NSWindow?
    private var loadingState = LoadingStateManager()
    private var onComplete: (() -> Void)?

    func showSplash(completion: @escaping () -> Void) {
        self.onComplete = completion

        // Create splash window
        let splashView = SplashScreenView(loadingState: loadingState)
        let hostingView = NSHostingView(rootView: splashView)

        splashWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let window = splashWindow else { return }

        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.center()

        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true

        // Show window with fade in
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1
        }

        // Start loading sequence
        startLoadingSequence()
    }

    private func startLoadingSequence() {
        Task {
            // Stage 1: Initializing
            loadingState.updateStage(.initializing)
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // Stage 2: Loading Core
            loadingState.updateStage(.loadingCore)
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s

            // Stage 3: Loading UI
            loadingState.updateStage(.loadingUI)
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s

            // Stage 4: Loading Services
            loadingState.updateStage(.loadingServices)
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // Stage 5: Preparing Workspace
            loadingState.updateStage(.preparingWorkspace)
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // Stage 6: Restoring Project (if any)
            let hasLastProject = await MainActor.run { ProjectViewModel.getLastProjectPath() != nil }
            if hasLastProject {
                loadingState.updateStage(.restoringProject)
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            }

            // Stage 7: Complete
            loadingState.updateStage(.complete)
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            // Close splash and show main window
            await MainActor.run {
                closeSplash()
            }
        }
    }

    private func closeSplash() {
        guard let window = splashWindow else { return }

        // Fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.splashWindow = nil
            self?.onComplete?()
        })
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView(loadingState: {
        let state = LoadingStateManager()
        state.progress = 0.6
        state.statusMessage = "Loading services..."
        return state
    }())
}
