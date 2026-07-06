//
//  OnboardingView.swift
//  DirectorsChair-Desktop
//
//  First-launch cinematic onboarding wizard
//  5-page walkthrough with project creation on final page
//

import SwiftUI
import DirectorsChairCore

struct OnboardingView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var tourManager: GuidedTourManager
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var projectName = ""
    @State private var selectedGenre = ""
    @State private var autoAdvanceTimer: Timer?
    /// Handle for the key monitor so it can be removed when onboarding closes.
    /// Leaking it left a global Return-key handler alive for the whole session
    /// that fired createProject() — replacing the open project with a new one.
    @State private var keyMonitor: Any?

    private let totalPages = 9

    // Background color matched to LaunchHero image outer edge
    private let bgColor = Color(red: 0.0, green: 0.02, blue: 0.04)

    // Accent color sampled from "DIRECTOR'S CHAIR" logo text: RGB(186, 236, 248)
    private let accentCyan = Color(red: 186/255, green: 236/255, blue: 248/255)

    private let genres = [
        ("Drama", "theatermasks"),
        ("Thriller", "bolt.shield"),
        ("Comedy", "face.smiling"),
        ("Sci-Fi", "sparkles"),
        ("Horror", "moon.stars"),
        ("Romance", "heart"),
        ("Action", "flame"),
        ("Documentary", "video"),
    ]

    var body: some View {
        ZStack {
            // Background — flat color matching LaunchHero image edges
            bgColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Page content
                Group {
                    switch currentPage {
                    case 0: welcomePage
                    case 1: scriptPage
                    case 2: visualizePage
                    case 3: aiImagePage
                    case 4: aiVideoPage
                    case 5: producePage
                    case 6: editingAutomationPage
                    case 7: smartClapboardPage
                    case 8: createProjectPage
                    default: welcomePage
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentPage)

                Spacer()

                // Bottom navigation
                bottomNavigation
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Install once; store the handle so it can be removed on disappear.
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    handleKeyEvent(event)
                }
            }
            startAutoAdvanceTimer()
        }
        .onDisappear {
            // Critical: tear down the global key monitor and the timer when
            // onboarding closes. Otherwise the Return-key handler stays alive
            // app-wide and re-runs createProject() on the next Enter press.
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
            autoAdvanceTimer?.invalidate()
            autoAdvanceTimer = nil
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 20) {
            // Hero image — bigger, with soft radial blur at edges
            Image("LaunchHero")
                .resizable()
                .scaledToFit()
                .frame(height: 340)
                .mask(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white, location: 0.55),
                            .init(color: .white.opacity(0.4), location: 0.75),
                            .init(color: .clear, location: 0.92),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )

            Spacer().frame(height: 32)

            Text("Your complete filmmaking workspace")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(accentCyan)

            // Get Started button
            Button(action: { advancePage() }) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(accentCyan)
                    )
                    .shadow(color: accentCyan.opacity(0.3), radius: 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            // Floating dust particles
            ParticleView()
                .frame(height: 30)
                .opacity(0.3)
        }
        .frame(maxWidth: 600)
    }

    // MARK: - Page 2: Script Features

    private var scriptPage: some View {
        featureShowcasePage(
            preview: AnyView(ScriptPreviewAnimation(accentCyan: accentCyan)),
            icon: "doc.text.fill",
            title: "Write Your Screenplay",
            subtitle: "Industry-standard formatting with intelligent assistance",
            features: [
                FeatureItem(icon: "doc.text", title: "Professional screenplay formatting", description: "Automatic scene headings, action, dialogue, and transitions"),
                FeatureItem(icon: "character.textbox", title: "Malayalam transliteration", description: "Write in your native language with real-time conversion"),
                FeatureItem(icon: "wand.and.stars", title: "AI-powered generation", description: "Generate scenes, dialogue, and entire screenplays with AI"),
            ]
        )
    }

    // MARK: - Page 3: Visualize Features

    private var visualizePage: some View {
        featureShowcasePage(
            preview: AnyView(TimelinePreviewAnimation(accentCyan: accentCyan)),
            icon: "film.fill",
            title: "Visualize Your Story",
            subtitle: "Plan every frame before you shoot",
            features: [
                FeatureItem(icon: "film", title: "Scene-by-scene timeline", description: "Visualize your story's pacing and structure at a glance"),
                FeatureItem(icon: "camera.viewfinder", title: "Shot planning & cinematography", description: "Plan camera angles, movements, and compositions"),
                FeatureItem(icon: "person.2", title: "Character design studio", description: "Build detailed character profiles with AI-generated portraits"),
            ]
        )
    }

    // MARK: - Page 4: AI Image Generation

    private var aiImagePage: some View {
        featureShowcasePage(
            preview: AnyView(AIImagePreviewAnimation(accentCyan: accentCyan)),
            icon: "photo.fill.on.rectangle.fill",
            title: "AI Image Generation",
            subtitle: "Visualize every shot before you pick up a camera",
            features: [
                FeatureItem(icon: "camera.aperture", title: "Shot visualization", description: "Generate concept images for any shot in your screenplay"),
                FeatureItem(icon: "rectangle.3.group", title: "Storyboard generation", description: "Create complete visual storyboards from scene descriptions"),
                FeatureItem(icon: "paintpalette", title: "Style & mood boards", description: "Explore visual styles, color palettes, and lighting setups"),
            ]
        )
    }

    // MARK: - Page 5: AI Video Generation

    private var aiVideoPage: some View {
        featureShowcasePage(
            preview: AnyView(AIVideoPreviewAnimation(accentCyan: accentCyan)),
            icon: "film.stack",
            title: "AI Video Generation",
            subtitle: "Bring your scenes to life with AI-generated video",
            features: [
                FeatureItem(icon: "video.badge.waveform", title: "Scene pre-visualization", description: "Generate animated previews of scenes before production"),
                FeatureItem(icon: "wand.and.stars", title: "AI motion synthesis", description: "Transform storyboard frames into moving sequences"),
                FeatureItem(icon: "play.rectangle", title: "Animatic creation", description: "Build timed animatics with AI-generated motion and camera moves"),
            ]
        )
    }

    // MARK: - Page 6: Produce Features

    private var producePage: some View {
        featureShowcasePage(
            preview: AnyView(ProductionPreviewAnimation(accentCyan: accentCyan)),
            icon: "movieclapper.fill",
            title: "Produce Your Film",
            subtitle: "From pre-production to wrap, all in one place",
            features: [
                FeatureItem(icon: "calendar", title: "Production scheduling", description: "Plan shoot days, manage call sheets, track scene status"),
                FeatureItem(icon: "dollarsign.circle", title: "Budget tracking", description: "Manage budgets, track expenses, scan receipts with AI"),
                FeatureItem(icon: "square.and.arrow.up", title: "Export to FDX, Fountain, PDF", description: "Share your work in industry-standard formats"),
            ]
        )
    }

    // MARK: - Page 7: Editing Automation

    private var editingAutomationPage: some View {
        featureShowcasePage(
            preview: AnyView(EditingAutomationPreviewAnimation(accentCyan: accentCyan)),
            icon: "slider.horizontal.below.rectangle",
            title: "From Capture to Cut",
            subtitle: "Every take logged, rated, and mapped to your plan",
            features: [
                FeatureItem(icon: "video.badge.checkmark", title: "Live capture & take logging", description: "Record with a connected camera, rate takes with one tap, and log blind timestamps when there's no feed"),
                FeatureItem(icon: "square.grid.3x1.folder.badge.plus", title: "Curation workspace", description: "Review, compare, and select takes; map camera files back to your shots"),
                FeatureItem(icon: "square.and.arrow.up.on.square", title: "Industry-standard exports", description: "Fountain, Final Draft (FDX), HTML, and searchable PDF screenplays"),
            ]
        )
    }

    // MARK: - Page 8: Smart Clapboard

    private var smartClapboardPage: some View {
        featureShowcasePage(
            preview: AnyView(SmartClapboardPreviewAnimation(accentCyan: accentCyan)),
            icon: "movieclapper",
            title: "On-Set Capture Toolkit",
            subtitle: "Tools that keep every take organized while you shoot",
            features: [
                FeatureItem(icon: "movieclapper", title: "Slate that follows your script", description: "Scene, shot, and take numbers update automatically as you work"),
                FeatureItem(icon: "keyboard", title: "Remote-control recording", description: "Map hardware keys to start and stop takes without touching the Mac"),
                FeatureItem(icon: "note.text", title: "Take notes & annotations", description: "Add notes per take — circle selects, ratings, director comments"),
                FeatureItem(icon: "waveform", title: "Sync-tone detection", description: "Audio sync tones help align external camera files to your takes"),
            ]
        )
    }

    // MARK: - Page 9: Create Project

    private var createProjectPage: some View {
        VStack(spacing: 28) {
            Image(systemName: "plus.rectangle.on.folder.fill")
                .font(.system(size: 44))
                .foregroundColor(accentCyan)
                .shadow(color: accentCyan.opacity(0.3), radius: 12)

            Text("Create Your First Project")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)

            Text("Give your project a name to get started")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))

            VStack(alignment: .leading, spacing: 6) {
                Text("PROJECT NAME")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.2)

                TextField("My First Film", text: $projectName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .frame(maxWidth: 360)

            VStack(alignment: .leading, spacing: 8) {
                Text("GENRE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.2)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(genres, id: \.0) { genre in
                        GenreChip(
                            name: genre.0,
                            icon: genre.1,
                            isSelected: selectedGenre == genre.0,
                            accentColor: accentCyan
                        ) {
                            selectedGenre = genre.0
                        }
                    }
                }
            }
            .frame(maxWidth: 460)

            Button(action: createProject) {
                Text("Create Project")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .frame(maxWidth: 240)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(accentCyan)
                    )
                    .shadow(color: accentCyan.opacity(0.3), radius: 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Button(action: openExistingProject) {
                Text("Open Existing Project")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 500)
    }

    // MARK: - Feature Showcase Template

    private func featureShowcasePage(
        preview: AnyView,
        icon: String,
        title: String,
        subtitle: String,
        features: [FeatureItem]
    ) -> some View {
        HStack(spacing: 40) {
            // Left: Animated preview
            preview
                .frame(maxWidth: 520, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: accentCyan.opacity(0.08), radius: 20, y: 8)

            // Right: Title + features
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(accentCyan)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)

                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                VStack(spacing: 12) {
                    ForEach(features) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 16))
                                .foregroundColor(accentCyan)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white.opacity(0.06))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))

                                Text(feature.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.45))
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                }
                .frame(maxWidth: 360)
            }
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Bottom Navigation

    private var bottomNavigation: some View {
        HStack {
            if currentPage > 0 {
                Button(action: { goBack() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 60)
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? accentCyan : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            Spacer()

            if currentPage < totalPages - 1 {
                Button(action: { advancePage() }) {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(accentCyan)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 60)
            }
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Actions

    private func advancePage() {
        guard currentPage < totalPages - 1 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            currentPage += 1
        }
        restartAutoAdvanceTimer()
    }

    private func goBack() {
        guard currentPage > 0 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            currentPage -= 1
        }
        restartAutoAdvanceTimer()
    }

    private func startAutoAdvanceTimer() {
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async {
                guard currentPage < totalPages - 1 else {
                    autoAdvanceTimer?.invalidate()
                    autoAdvanceTimer = nil
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    currentPage += 1
                }
            }
        }
    }

    private func restartAutoAdvanceTimer() {
        autoAdvanceTimer?.invalidate()
        // Don't restart if we're on the last page (Create Project)
        guard currentPage < totalPages - 1 else {
            autoAdvanceTimer = nil
            return
        }
        startAutoAdvanceTimer()
    }

    private func createProject() {
        let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? "My First Film" : name
        projectViewModel.createNew(named: finalName)

        if !selectedGenre.isEmpty {
            projectViewModel.project.genre = selectedGenre
            projectViewModel.isDirty = true
        }

        coordinator.navigateTo(.overview)
        onComplete()

        // Start guided tour after a brief delay to let the UI settle
        if !tourManager.hasCompletedTour {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                tourManager.startSpotlightTour()
            }
        }
    }

    private func openExistingProject() {
        onComplete()
        coordinator.navigateTo(.projects)
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 124: advancePage(); return nil
        case 123: goBack(); return nil
        case 36:
            if currentPage < totalPages - 1 { advancePage() } else { createProject() }
            return nil
        default: return event
        }
    }
}
