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
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
            }
            startAutoAdvanceTimer()
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
            title: "Automate Your Edit",
            subtitle: "Seamless integration with DaVinci Resolve and smart clapboard",
            features: [
                FeatureItem(icon: "timeline.selection", title: "Curated timeline export", description: "Auto-generate DaVinci Resolve timelines from your shot plan"),
                FeatureItem(icon: "ipad.landscape", title: "Smart clapboard for iPad", description: "Digital slate syncs metadata, take notes, and scene info automatically"),
                FeatureItem(icon: "gearshape.2", title: "Automated post workflow", description: "EDL/XML export with scene markers, color tags, and clip organization"),
            ]
        )
    }

    // MARK: - Page 8: Smart Clapboard

    private var smartClapboardPage: some View {
        featureShowcasePage(
            preview: AnyView(SmartClapboardPreviewAnimation(accentCyan: accentCyan)),
            icon: "ipad.landscape",
            title: "Smart Clapboard for iPad",
            subtitle: "A digital slate that syncs with your entire production",
            features: [
                FeatureItem(icon: "movieclapper", title: "Digital smart slate", description: "Scene, shot, and take info updates automatically from your script"),
                FeatureItem(icon: "arrow.triangle.2.circlepath", title: "Auto-sync with Director's Chair", description: "Metadata flows seamlessly between iPad on set and desktop in edit"),
                FeatureItem(icon: "note.text", title: "Take notes & annotations", description: "Add notes per take — circle selects, print, director comments"),
                FeatureItem(icon: "waveform", title: "Audio timecode sync", description: "Jam-sync timecode for frame-accurate editorial alignment"),
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

// MARK: - Script Preview Animation (typing screenplay text)

private struct ScriptPreviewAnimation: View {
    let accentCyan: Color
    @State private var visibleLines = 0
    @State private var cursorVisible = true

    private let scriptLines: [(String, ScriptLineType)] = [
        ("INT. COFFEE SHOP - MORNING", .sceneHeading),
        ("", .spacing),
        ("The morning sun filters through dusty windows.", .action),
        ("SARAH (30s, determined) sits at a corner table,", .action),
        ("laptop open, coffee untouched.", .action),
        ("", .spacing),
        ("SARAH", .character),
        ("I've been waiting for this moment", .dialogue),
        ("my entire life.", .dialogue),
        ("", .spacing),
        ("(looking up)", .parenthetical),
        ("", .spacing),
        ("SARAH", .character),
        ("And I'm not going to let anyone", .dialogue),
        ("stop me now.", .dialogue),
        ("", .spacing),
        ("EXT. CITY STREET - CONTINUOUS", .sceneHeading),
        ("", .spacing),
        ("Sarah bursts through the door, determination", .action),
        ("in every step.", .action),
    ]

    enum ScriptLineType {
        case sceneHeading, action, character, dialogue, parenthetical, spacing
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(["Overview", "Script", "Timeline", "Story Design", "Production"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 8))
                            .foregroundColor(item == "Script" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                item == "Script" ?
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                    RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                            )
                    }
                    Spacer()
                }
                .frame(width: 80)
                .padding(.top, 40)
                .padding(.leading, 8)
                .background(Color(red: 0.03, green: 0.04, blue: 0.06))

                // Script content
                VStack(alignment: .leading, spacing: 0) {
                    // Toolbar
                    HStack {
                        Text("Script")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                    // Script text area
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(scriptLines.prefix(visibleLines).enumerated()), id: \.offset) { index, line in
                                scriptLineView(line.0, type: line.1, isLast: index == visibleLines - 1)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Format bar at bottom
                    HStack(spacing: 0) {
                        ForEach(["Scene Heading", "Action", "Character", "Dialogue", "Transition"], id: \.self) { fmt in
                            Text(fmt)
                                .font(.system(size: 7))
                                .foregroundColor(fmt == "Dialogue" ? accentCyan : .white.opacity(0.3))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    fmt == "Dialogue" ?
                                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)) :
                                        RoundedRectangle(cornerRadius: 3).fill(Color.clear)
                                )
                        }
                    }
                    .padding(6)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))
                }
            }
        }
        .onAppear {
            startTypingAnimation()
            startCursorBlink()
        }
    }

    private func scriptLineView(_ text: String, type: ScriptLineType, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            switch type {
            case .sceneHeading:
                Text(text)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(accentCyan)
            case .action:
                Text(text)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
            case .character:
                Spacer().frame(width: 100)
                Text(text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            case .dialogue:
                Spacer().frame(width: 60)
                Text(text)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.75))
            case .parenthetical:
                Spacer().frame(width: 70)
                Text(text)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            case .spacing:
                Text(" ")
                    .font(.system(size: 6))
            }

            if isLast && cursorVisible {
                Rectangle()
                    .fill(accentCyan)
                    .frame(width: 1.5, height: 12)
                    .padding(.leading, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func startTypingAnimation() {
        for i in 1...scriptLines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) {
                withAnimation(.easeOut(duration: 0.15)) {
                    visibleLines = i
                }
            }
        }
    }

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}

// MARK: - Timeline Preview Animation (sliding scene blocks)

private struct TimelinePreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0

    private let sceneColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 0.9),
        Color(red: 0.9, green: 0.4, blue: 0.3),
        Color(red: 0.3, green: 0.8, blue: 0.5),
        Color(red: 0.8, green: 0.6, blue: 0.2),
        Color(red: 0.6, green: 0.3, blue: 0.8),
        Color(red: 0.3, green: 0.7, blue: 0.7),
    ]

    private let scenes = ["INT. COFFEE\nSHOP", "EXT. CITY\nSTREET", "INT. OFFICE\nLOBBY", "EXT. PARK\nBENCH", "INT. SARAH'S\nAPT", "EXT. ROOFTOP\nNIGHT"]
    private let rows = ["Sarah", "James", "Coffee Cup", "Laptop", "City Sounds", "Music"]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(["Overview", "Script", "Timeline", "Story Design", "Production"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 8))
                            .foregroundColor(item == "Timeline" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                item == "Timeline" ?
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                    RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                            )
                    }
                    Spacer()
                }
                .frame(width: 80)
                .padding(.top, 40)
                .padding(.leading, 8)
                .background(Color(red: 0.03, green: 0.04, blue: 0.06))

                VStack(alignment: .leading, spacing: 0) {
                    // Toolbar
                    HStack {
                        Text("Timeline")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                    // Scene header blocks
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(scenes.enumerated()), id: \.offset) { i, scene in
                                let lines = scene.split(separator: "\n")
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(String(lines[0]))
                                        .font(.system(size: 6, weight: .bold))
                                    if lines.count > 1 {
                                        Text(String(lines[1]))
                                            .font(.system(size: 6))
                                    }
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .frame(width: CGFloat.random(in: 65...80), height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(sceneColors[i].opacity(0.7))
                                )
                                .scaleEffect(animationPhase > i ? 1.0 : 0.0)
                                .opacity(animationPhase > i ? 1.0 : 0.0)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }

                    // Timeline rows
                    VStack(spacing: 2) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, rowName in
                            HStack(spacing: 4) {
                                Text(rowName)
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.35))
                                    .frame(width: 50, alignment: .leading)

                                ForEach(0..<6, id: \.self) { colIdx in
                                    let present = (rowIdx + colIdx) % 3 != 2
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(present ? sceneColors[colIdx].opacity(0.3) : Color.clear)
                                        .frame(width: CGFloat.random(in: 50...70), height: 16)
                                        .scaleEffect(x: animationPhase > 6 + rowIdx ? 1.0 : 0.0, y: 1.0, anchor: .leading)
                                        .opacity(animationPhase > 6 + rowIdx ? 1.0 : 0.0)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.top, 4)

                    Spacer()

                    // Shot list panel
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SHOT LIST — Scene 1")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(accentCyan)

                        ForEach(["Wide establishing", "CU Sarah's face", "OTS laptop screen", "Medium two-shot"], id: \.self) { shot in
                            Text(shot)
                                .font(.system(size: 7))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.04))
                                )
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .opacity(animationPhase > 12 ? 1.0 : 0.0)
                }
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Animate scene headers one by one, then rows, then shot list
        for i in 1...14 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animationPhase = i
                }
            }
        }
    }
}

// MARK: - Production Preview Animation (schedule + budget)

private struct ProductionPreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var budgetProgress: CGFloat = 0
    @State private var spentAmount = 0

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(["Overview", "Script", "Timeline", "Story Design", "Production"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 8))
                            .foregroundColor(item == "Production" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                item == "Production" ?
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                    RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                            )
                    }
                    Spacer()
                }
                .frame(width: 80)
                .padding(.top, 40)
                .padding(.leading, 8)
                .background(Color(red: 0.03, green: 0.04, blue: 0.06))

                VStack(alignment: .leading, spacing: 0) {
                    // Toolbar
                    HStack {
                        Text("Production")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                    // Sub-tabs
                    HStack(spacing: 12) {
                        ForEach(["Schedule", "Budget", "Cast & Crew"], id: \.self) { tab in
                            Text(tab)
                                .font(.system(size: 8))
                                .foregroundColor(tab == "Schedule" ? accentCyan : .white.opacity(0.3))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    tab == "Schedule" ?
                                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                        RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    HStack(alignment: .top, spacing: 12) {
                        // Schedule cards
                        VStack(alignment: .leading, spacing: 8) {
                            // Day 1
                            scheduleCard(
                                day: "Day 1 — Monday, Mar 15",
                                callTime: "Call: 7:00 AM  |  Wrap: 6:00 PM",
                                scenes: [
                                    ("Sc 1", "INT. COFFEE SHOP", "Morning", Color(red: 0.3, green: 0.6, blue: 0.9)),
                                    ("Sc 3", "INT. OFFICE LOBBY", "Afternoon", Color(red: 0.3, green: 0.8, blue: 0.5)),
                                    ("Sc 5", "INT. SARAH'S APT", "Evening", Color(red: 0.6, green: 0.3, blue: 0.8)),
                                ],
                                visible: animationPhase > 0
                            )

                            // Day 2
                            scheduleCard(
                                day: "Day 2 — Tuesday, Mar 16",
                                callTime: "Call: 8:00 AM  |  Wrap: 7:00 PM",
                                scenes: [
                                    ("Sc 2", "EXT. CITY STREET", "Morning", Color(red: 0.9, green: 0.4, blue: 0.3)),
                                    ("Sc 6", "EXT. ROOFTOP", "Night", Color(red: 0.3, green: 0.7, blue: 0.7)),
                                ],
                                visible: animationPhase > 1
                            )
                        }
                        .frame(maxWidth: .infinity)

                        // Budget + Crew panels
                        VStack(spacing: 8) {
                            // Budget card
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Budget Overview")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.85))

                                HStack {
                                    Text("Total Budget")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text("$125,000")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                }

                                HStack {
                                    Text("Spent")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text("$\(spentAmount.formatted())")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                }

                                HStack {
                                    Text("Remaining")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text("$\((125000 - spentAmount).formatted())")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                                }

                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(accentCyan)
                                            .frame(width: geo.size.width * budgetProgress)
                                    }
                                }
                                .frame(height: 4)

                                Text("\(Int(budgetProgress * 100))% spent")
                                    .font(.system(size: 6))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .opacity(animationPhase > 2 ? 1.0 : 0.0)

                            // Cast card
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Cast & Crew")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.85))

                                ForEach([("Sarah Miller", "Lead"), ("James Chen", "Supporting"), ("Maria Lopez", "Director")], id: \.0) { name, role in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 14, height: 14)
                                        Text(name)
                                            .font(.system(size: 7))
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        Text(role)
                                            .font(.system(size: 6))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .opacity(animationPhase > 3 ? 1.0 : 0.0)
                        }
                        .frame(width: 150)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                    Spacer()
                }
            }
        }
        .onAppear { startAnimation() }
    }

    private func scheduleCard(day: String, callTime: String, scenes: [(String, String, String, Color)], visible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(day)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
            Text(callTime)
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.35))

            ForEach(Array(scenes.enumerated()), id: \.offset) { _, scene in
                HStack(spacing: 6) {
                    Text(scene.0)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scene.3.opacity(0.7))
                        )
                    Text(scene.1)
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(scene.2)
                        .font(.system(size: 6))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(scene.3.opacity(0.1))
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .scaleEffect(visible ? 1.0 : 0.95)
        .opacity(visible ? 1.0 : 0.0)
    }

    private func startAnimation() {
        // Phase 1-4: cards appear
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animationPhase = i
                }
            }
        }

        // Budget counter animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 1.5)) {
                budgetProgress = 0.346
            }
            // Count up the spent amount
            let target = 43200
            let steps = 30
            for step in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.05) {
                    spentAmount = Int(Double(target) * Double(step) / Double(steps))
                }
            }
        }
    }
}

// MARK: - AI Image Generation Preview Animation

private struct AIImagePreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var promptChars = 0

    private let promptText = "Wide shot, dimly lit coffee shop, golden morning light streaming through dusty windows, cinematic"

    private let shotThumbnails: [(String, String, Color)] = [
        ("Wide establishing", "camera", Color(red: 0.3, green: 0.6, blue: 0.9)),
        ("CU Sarah's face", "person.crop.circle", Color(red: 0.9, green: 0.5, blue: 0.3)),
        ("OTS laptop", "laptopcomputer", Color(red: 0.3, green: 0.8, blue: 0.5)),
        ("Low angle exterior", "building.2", Color(red: 0.8, green: 0.6, blue: 0.2)),
        ("Mood: warm tones", "sun.max", Color(red: 0.9, green: 0.7, blue: 0.3)),
        ("Mood: cool night", "moon.stars", Color(red: 0.4, green: 0.4, blue: 0.8)),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(accentCyan)
                    Text("AI Image Studio")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("Scene 1: INT. COFFEE SHOP")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                // Prompt input area
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROMPT")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(1)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(accentCyan.opacity(0.3), lineWidth: 1)
                            )

                        HStack(spacing: 0) {
                            Text(String(promptText.prefix(promptChars)))
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.75))
                            if animationPhase < 2 {
                                Rectangle()
                                    .fill(accentCyan)
                                    .frame(width: 1, height: 10)
                                    .opacity(animationPhase >= 1 ? 1 : 0)
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                    .frame(height: 36)

                    // Generate button
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 7))
                            Text(animationPhase >= 2 ? "Generating..." : "Generate")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(animationPhase >= 2 ? accentCyan : .black.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(animationPhase >= 2 ? accentCyan.opacity(0.15) : accentCyan)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Generated images grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(shotThumbnails.enumerated()), id: \.offset) { idx, shot in
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [shot.2.opacity(0.4), shot.2.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            // Shimmer loading effect
                            if animationPhase == 2 + idx {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.15), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .offset(x: shimmerOffset)
                                    .clipped()
                            }

                            if animationPhase > 2 + idx {
                                VStack(spacing: 4) {
                                    Image(systemName: shot.1)
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(shot.0)
                                        .font(.system(size: 6, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            } else if animationPhase <= 2 + idx && animationPhase >= 2 {
                                ProgressView()
                                    .scaleEffect(0.4)
                                    .tint(.white.opacity(0.4))
                            }
                        }
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(animationPhase > 2 + idx ? shot.2.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .opacity(animationPhase >= 2 ? 1.0 : 0.3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Style selector at bottom
                HStack(spacing: 8) {
                    ForEach(["Cinematic", "Photorealistic", "Storyboard", "Concept Art"], id: \.self) { style in
                        Text(style)
                            .font(.system(size: 7))
                            .foregroundColor(style == "Cinematic" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(style == "Cinematic" ? Color.white.opacity(0.06) : Color.clear)
                            )
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Phase 1: Start typing prompt
        animationPhase = 1
        let chars = promptText.count
        for i in 1...chars {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.025) {
                promptChars = i
            }
        }

        // Phase 2: Click generate
        let typingDuration = Double(chars) * 0.025 + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            withAnimation(.easeOut(duration: 0.2)) { animationPhase = 2 }
        }

        // Shimmer animation
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }

        // Phase 3-8: Images appear one by one
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration + 0.5 + Double(i) * 0.35) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animationPhase = 3 + i
                }
            }
        }
    }
}

// MARK: - AI Video Generation Preview Animation

private struct AIVideoPreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var playbackProgress: CGFloat = 0
    @State private var currentFrame = 0
    @State private var isPlaying = false

    private let frameColors: [Color] = [
        Color(red: 0.2, green: 0.15, blue: 0.1),
        Color(red: 0.25, green: 0.18, blue: 0.12),
        Color(red: 0.15, green: 0.2, blue: 0.25),
        Color(red: 0.1, green: 0.15, blue: 0.25),
        Color(red: 0.2, green: 0.12, blue: 0.18),
        Color(red: 0.12, green: 0.22, blue: 0.18),
    ]

    private let storyboardFrames = [
        ("Wide shot — Coffee shop", "building.2"),
        ("Sarah enters — door push", "figure.walk"),
        ("CU — Sarah sits down", "person.crop.circle"),
        ("Hands on laptop — typing", "hand.raised"),
        ("Reaction — looks up", "eye"),
        ("Wide — stands up, exits", "figure.walk.departure"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Image(systemName: "film.stack")
                        .font(.system(size: 9))
                        .foregroundColor(accentCyan)
                    Text("AI Video Studio")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    if animationPhase >= 3 {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("Ready")
                                .font(.system(size: 7))
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                // Main video preview area
                ZStack {
                    // Video canvas
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: animationPhase >= 3 ?
                                    [frameColors[currentFrame % frameColors.count], frameColors[(currentFrame + 1) % frameColors.count]] :
                                    [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.06, green: 0.06, blue: 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    if animationPhase < 2 {
                        // Storyboard -> video conversion indicator
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.2))
                            Text("Storyboard frames loaded")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    } else if animationPhase == 2 {
                        // Generating
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(accentCyan)
                            Text("Generating video from storyboard...")
                                .font(.system(size: 8))
                                .foregroundColor(accentCyan.opacity(0.7))
                        }
                    } else {
                        // Playing video
                        VStack(spacing: 6) {
                            Image(systemName: storyboardFrames[currentFrame % storyboardFrames.count].1)
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.5))
                            Text(storyboardFrames[currentFrame % storyboardFrames.count].0)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        // Play button overlay (brief)
                        if !isPlaying {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .offset(x: 1)
                                )
                        }

                        // Timecode
                        VStack {
                            HStack {
                                Spacer()
                                Text(String(format: "00:%02d:%02d", currentFrame * 4, (currentFrame * 17) % 30))
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(3)
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Playback controls + progress bar
                VStack(spacing: 6) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentCyan)
                                .frame(width: geo.size.width * playbackProgress)
                        }
                    }
                    .frame(height: 3)

                    // Controls
                    HStack(spacing: 16) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(accentCyan)
                        Image(systemName: "forward.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("1080p  •  24fps  •  AI Generated")
                            .font(.system(size: 6))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // Storyboard film strip at bottom
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(storyboardFrames.enumerated()), id: \.offset) { idx, frame in
                            VStack(spacing: 2) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(frameColors[idx % frameColors.count])
                                    Image(systemName: frame.1)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .frame(width: 58, height: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(idx == currentFrame && animationPhase >= 3 ? accentCyan : Color.white.opacity(0.08), lineWidth: idx == currentFrame && animationPhase >= 3 ? 1.5 : 0.5)
                                )

                                Text("F\(idx + 1)")
                                    .font(.system(size: 5))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                            .opacity(animationPhase > idx ? 1.0 : 0.3)
                            .scaleEffect(animationPhase > idx ? 1.0 : 0.9)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Phase 1: Storyboard frames slide in
        for i in 1...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    animationPhase = i
                }
            }
        }

        // Phase 2: Start generating (at 1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { animationPhase = 2 }
        }

        // Phase 3: Video ready, start playing (at 2.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.4)) { animationPhase = 3 }
        }

        // Start playback (at 3.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isPlaying = true
            // Animate playback progress
            withAnimation(.linear(duration: 6.0)) {
                playbackProgress = 1.0
            }
            // Cycle through frames
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentFrame = (currentFrame + 1) % storyboardFrames.count
                }
                if currentFrame == 0 {
                    timer.invalidate()
                    isPlaying = false
                }
            }
        }
    }
}

// MARK: - Editing Automation Preview Animation (DaVinci Resolve + Smart Clapboard)

private struct EditingAutomationPreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var timelineClips = 0
    @State private var clapboardFlash = false
    @State private var exportProgress: CGFloat = 0

    private let trackColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 0.9),
        Color(red: 0.3, green: 0.8, blue: 0.5),
        Color(red: 0.9, green: 0.5, blue: 0.3),
        Color(red: 0.6, green: 0.3, blue: 0.8),
    ]

    private let clipWidths: [[CGFloat]] = [
        [60, 45, 70, 55, 40, 65],
        [50, 70, 35, 60, 55, 45],
        [40, 55, 65, 45, 70, 50],
        [70, 40, 50, 60, 35, 55],
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Image(systemName: "slider.horizontal.below.rectangle")
                        .font(.system(size: 9))
                        .foregroundColor(accentCyan)
                    Text("Editing Automation")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                HStack(alignment: .top, spacing: 10) {
                    // Left: DaVinci Resolve timeline mockup
                    VStack(alignment: .leading, spacing: 0) {
                        // DaVinci header
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 10, height: 10)
                            Text("DaVinci Resolve Timeline")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            if animationPhase >= 6 {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 7))
                                        .foregroundColor(.green)
                                    Text("Synced")
                                        .font(.system(size: 6))
                                        .foregroundColor(.green.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12))

                        // Timecode ruler
                        HStack(spacing: 0) {
                            ForEach(0..<12, id: \.self) { i in
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 1, height: 8)
                                    Text("\(i)s")
                                        .font(.system(size: 5))
                                        .foregroundColor(.white.opacity(0.2))
                                }
                                .frame(width: 28)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)

                        // Timeline tracks
                        VStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { trackIdx in
                                HStack(spacing: 0) {
                                    // Track label
                                    Text(["V1", "V2", "A1", "A2"][trackIdx])
                                        .font(.system(size: 6, weight: .bold))
                                        .foregroundColor(.white.opacity(0.3))
                                        .frame(width: 20)

                                    // Clips
                                    HStack(spacing: 2) {
                                        ForEach(0..<min(timelineClips, 6), id: \.self) { clipIdx in
                                            let w = clipWidths[trackIdx][clipIdx]
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(trackColors[trackIdx].opacity(0.5))
                                                .frame(width: w, height: 18)
                                                .overlay(
                                                    Text("Sc\(clipIdx + 1)")
                                                        .font(.system(size: 5))
                                                        .foregroundColor(.white.opacity(0.4))
                                                )
                                                .transition(.scale(scale: 0, anchor: .leading).combined(with: .opacity))
                                        }
                                    }
                                }
                                .frame(height: 20)
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color(red: 0.07, green: 0.07, blue: 0.09))

                        // Scene markers
                        if animationPhase >= 5 {
                            HStack(spacing: 6) {
                                ForEach(["Sc1", "Sc2", "Sc3", "Sc4", "Sc5", "Sc6"], id: \.self) { marker in
                                    VStack(spacing: 1) {
                                        Triangle()
                                            .fill(accentCyan.opacity(0.6))
                                            .frame(width: 6, height: 4)
                                        Text(marker)
                                            .font(.system(size: 5))
                                            .foregroundColor(accentCyan.opacity(0.5))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 4)
                            .transition(.opacity)
                        }

                        Spacer()

                        // Export status
                        if animationPhase >= 7 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 7))
                                    .foregroundColor(accentCyan)
                                Text("Exported: timeline.xml")
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(accentCyan)
                                            .frame(width: geo.size.width * exportProgress)
                                    }
                                }
                                .frame(width: 60, height: 4)
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // Right: Smart Clapboard
                    VStack(spacing: 8) {
                        // Clapboard
                        VStack(spacing: 0) {
                            // Clapper sticks
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                                    .frame(height: 24)

                                // Diagonal stripes
                                HStack(spacing: 6) {
                                    ForEach(0..<8, id: \.self) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 8)
                                            .rotationEffect(.degrees(-45))
                                    }
                                }
                                .clipped()
                                .frame(height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .opacity(clapboardFlash ? 0.6 : 0.3)
                            }

                            // Slate content
                            VStack(spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SCENE")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("1")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("TAKE")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("3")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SHOT")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("1A")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }

                                Divider().background(Color.white.opacity(0.1))

                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("INT. COFFEE SHOP")
                                            .font(.system(size: 6, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("Wide establishing")
                                            .font(.system(size: 5))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    Spacer()
                                }

                                if animationPhase >= 2 {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.red).frame(width: 5, height: 5)
                                        Text("SYNCING")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.red.opacity(0.8))
                                        Spacer()
                                        Image(systemName: "ipad.landscape")
                                            .font(.system(size: 7))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .padding(8)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .scaleEffect(animationPhase >= 1 ? 1.0 : 0.9)
                        .opacity(animationPhase >= 1 ? 1.0 : 0.0)

                        // Metadata sync status
                        if animationPhase >= 3 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("METADATA SYNC")
                                    .font(.system(size: 5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.3))
                                    .tracking(0.8)

                                ForEach(["Scene info", "Take notes", "Timecode", "Camera settings"], id: \.self) { item in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundColor(.green.opacity(0.7))
                                        Text(item)
                                            .font(.system(size: 6))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(width: 140)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Phase 1: Clapboard appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { animationPhase = 1 }
        }

        // Phase 2: Clapboard flash + sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.1)) { clapboardFlash = true }
            withAnimation { animationPhase = 2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.3)) { clapboardFlash = false }
            }
        }

        // Phase 3: Metadata sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5)) { animationPhase = 3 }
        }

        // Phase 4: Timeline clips start populating
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            animationPhase = 4
            for i in 1...6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        timelineClips = i
                    }
                }
            }
        }

        // Phase 5: Scene markers appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.4)) { animationPhase = 5 }
        }

        // Phase 6: Synced badge
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            withAnimation(.easeOut(duration: 0.3)) { animationPhase = 6 }
        }

        // Phase 7: Export
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.3)) { animationPhase = 7 }
            withAnimation(.easeOut(duration: 1.5)) { exportProgress = 1.0 }
        }
    }
}

// Triangle shape for scene markers
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Smart Clapboard Preview Animation

private struct SmartClapboardPreviewAnimation: View {
    let accentCyan: Color

    @State private var clapAngle: Double = 0          // clapper stick rotation
    @State private var currentSlate = 0                // which scene/shot/take combo to show
    @State private var slateOpacity: Double = 1.0
    @State private var syncPulse = false
    @State private var connectedBadge = false
    @State private var takeNotes: [String] = []

    private let slates: [(scene: String, shot: String, take: String, location: String, desc: String)] = [
        ("1",  "1A", "1", "INT. COFFEE SHOP — MORNING", "Wide establishing"),
        ("1",  "1B", "2", "INT. COFFEE SHOP — MORNING", "CU Sarah's face"),
        ("3",  "2A", "1", "EXT. CITY STREET — DAY",     "Tracking shot"),
        ("5",  "3A", "3", "INT. SARAH'S APT — EVENING",  "OTS laptop"),
        ("6",  "4A", "1", "EXT. ROOFTOP — NIGHT",        "Low angle wide"),
        ("1",  "1A", "4", "INT. COFFEE SHOP — MORNING", "Wide establishing — circle take"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar — iPad frame hint
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "ipad.landscape")
                            .font(.system(size: 9))
                            .foregroundColor(accentCyan)
                        Text("Director's Chair — Smart Clapboard")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    if connectedBadge {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                                .scaleEffect(syncPulse ? 1.3 : 1.0)
                            Text("Connected")
                                .font(.system(size: 7))
                                .foregroundColor(.green.opacity(0.8))
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                Spacer().frame(height: 10)

                // The Clapboard
                ZStack {
                    VStack(spacing: 0) {
                        // Clapper sticks (top part that rotates)
                        ZStack {
                            clapperSticks
                                .rotationEffect(.degrees(-clapAngle), anchor: .leading)
                        }
                        .frame(height: 32)
                        .zIndex(1)

                        // Slate body
                        VStack(spacing: 0) {
                            // Fixed top stripe bar (bottom half of clapper)
                            clapperSticks
                                .frame(height: 32)

                            // Slate content
                            slateContent
                        }
                        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 10)

                // Take notes panel
                if !takeNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TAKE NOTES")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(0.8)

                        ForEach(Array(takeNotes.enumerated()), id: \.offset) { _, note in
                            HStack(spacing: 4) {
                                let isCircled = note.contains("CIRCLED")
                                Image(systemName: isCircled ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 6))
                                    .foregroundColor(isCircled ? .green : .white.opacity(0.25))
                                Text(note)
                                    .font(.system(size: 7))
                                    .foregroundColor(isCircled ? .green.opacity(0.8) : .white.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .onAppear { startClapSequence() }
    }

    // MARK: - Clapper Sticks

    private var clapperSticks: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.17))

            // Diagonal stripes
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { i in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: geo.size.width / 20)
                            Rectangle()
                                .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                                .frame(width: geo.size.width / 20)
                        }
                    }
                }
                .rotationEffect(.degrees(-20))
                .offset(y: -4)
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 32)
    }

    // MARK: - Slate Content

    private var slateContent: some View {
        let slate = slates[currentSlate % slates.count]

        return VStack(spacing: 8) {
            // Production title
            Text("DIRECTOR'S CHAIR")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(accentCyan)
                .tracking(2)
                .padding(.top, 10)

            // Main fields
            HStack(spacing: 0) {
                slateField(label: "SCENE", value: slate.scene, large: true)
                slateDivider
                slateField(label: "SHOT", value: slate.shot, large: true)
                slateDivider
                slateField(label: "TAKE", value: slate.take, large: true)
            }
            .padding(.horizontal, 12)
            .opacity(slateOpacity)

            // Location + description
            VStack(spacing: 3) {
                Text(slate.location)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Text(slate.desc)
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.4))
            }
            .opacity(slateOpacity)

            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)

            // Bottom row — camera, date, FPS
            HStack {
                slateFieldSmall(label: "CAMERA", value: "A")
                Spacer()
                slateFieldSmall(label: "DATE", value: "03/15/26")
                Spacer()
                slateFieldSmall(label: "FPS", value: "24")
                Spacer()
                slateFieldSmall(label: "LENS", value: "35mm")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Sync indicator
            if syncPulse {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 7))
                        .foregroundColor(accentCyan)
                        .opacity(syncPulse ? 1.0 : 0.3)
                    Text("Syncing to Director's Chair Desktop...")
                        .font(.system(size: 6))
                        .foregroundColor(accentCyan.opacity(0.6))
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    private func slateField(label: String, value: String, large: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 5, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
                .tracking(0.8)
            Text(value)
                .font(.system(size: large ? 28 : 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private var slateDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 40)
    }

    private func slateFieldSmall(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 4, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Animation Sequence

    private func startClapSequence() {
        // Connected badge
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) { connectedBadge = true }
        }

        // Start cycling through slates with clap animation
        performClap(atDelay: 1.0, toSlate: 1, note: "Sc1 Shot1B Take2 — Good energy")
        performClap(atDelay: 3.0, toSlate: 2, note: "Sc3 Shot2A Take1 — Tracking steady")
        performClap(atDelay: 5.0, toSlate: 3, note: "Sc5 Shot3A Take3 — Adjust lighting")
        performClap(atDelay: 7.0, toSlate: 4, note: "Sc6 Shot4A Take1 — Night setup")
        performClap(atDelay: 9.0, toSlate: 5, note: "Sc1 Shot1A Take4 — CIRCLED ★")
    }

    private func performClap(atDelay delay: Double, toSlate: Int, note: String) {
        // Clap down
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.08)) {
                clapAngle = 25
            }
        }

        // Fade out old content during clap
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.05) {
            withAnimation(.easeOut(duration: 0.06)) {
                slateOpacity = 0.0
            }
        }

        // Change slate content
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.12) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                currentSlate = toSlate
            }
        }

        // Clap back up
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                clapAngle = 0
            }
            withAnimation(.easeIn(duration: 0.15)) {
                slateOpacity = 1.0
            }
        }

        // Sync pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) { syncPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.3)) { syncPulse = false }
            }
        }

        // Add take note
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.6) {
            withAnimation(.spring(response: 0.3)) {
                takeNotes.append(note)
                if takeNotes.count > 4 { takeNotes.removeFirst() }
            }
        }
    }
}

// MARK: - Supporting Types

private struct FeatureItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

private struct GenreChip: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .black.opacity(0.85) : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Particle Effect

private struct ParticleView: View {
    @State private var particles: [Particle] = (0..<12).map { _ in Particle() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Color.white)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: particle.x * geo.size.width,
                            y: particle.y * geo.size.height
                        )
                        .opacity(particle.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                for i in particles.indices {
                    particles[i].y -= CGFloat.random(in: 0.1...0.3)
                    particles[i].opacity = Double.random(in: 0.05...0.2)
                }
            }
        }
    }

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat = CGFloat.random(in: 0...1)
        var y: CGFloat = CGFloat.random(in: 0...1)
        var size: CGFloat = CGFloat.random(in: 1...3)
        var opacity: Double = Double.random(in: 0.05...0.15)
    }
}
