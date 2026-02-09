//
//  ContentView.swift
//  DirectorsChair-Desktop
//
//  Phase 8: Main App Integration
//  Main window layout with navigation
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairProduction
import DirectorsChairServices

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @StateObject private var timelineViewModel = TimelineViewModel()

    /// Timeline height as percentage of available space (default 20%)
    @State private var timelineHeightRatio: CGFloat = 0.20

    /// Sidebar width
    @State private var sidebarWidth: CGFloat = 280

    /// Whether we're on the Projects view (hide panels)
    private var isProjectsView: Bool {
        coordinator.selectedView == .projects
    }

    /// Whether to show the navigator (hidden on Projects view)
    private var shouldShowNavigator: Bool {
        coordinator.showingNavigator && !isProjectsView
    }

    /// Whether to show the timeline (hidden on Projects view)
    private var shouldShowTimeline: Bool {
        coordinator.showingTimeline && !isProjectsView
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let totalHeight = geometry.size.height
                let timelineHeight = shouldShowTimeline ? max(100, totalHeight * timelineHeightRatio) : 0
                let mainContentHeight = totalHeight - timelineHeight - (shouldShowTimeline ? 6 : 0) // 6 for divider

                VStack(spacing: 0) {
                    // Main content area - using simple HStack instead of NavigationSplitView
                    HStack(spacing: 0) {
                        // Left Sidebar - Navigator (conditionally shown, hidden on Projects view)
                        if shouldShowNavigator {
                            NavigatorSidebar()
                                .environmentObject(timelineViewModel)
                                .frame(width: sidebarWidth)
                                .frame(maxHeight: .infinity)
                                .background(Color(nsColor: .controlBackgroundColor))

                            // Sidebar resize handle
                            SidebarDivider(sidebarWidth: $sidebarWidth)
                        }

                        // Main Content Area
                        VStack(spacing: 0) {
                            // Top Toolbar (hidden on Projects view for cleaner look)
                            if !isProjectsView {
                                AppToolbar()
                            }

                            // Central View Stack - isolated to only re-render on selectedView change
                            CentralViewRouter()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: mainContentHeight)

                    // Timeline section - spans full width (hidden on Projects view)
                    if shouldShowTimeline {
                        // Resizable divider
                        TimelineDivider(
                            timelineHeightRatio: $timelineHeightRatio,
                            totalHeight: totalHeight
                        )

                        // Bottom Timeline (20% of space, resizable) - full width
                        TimelineContainer()
                            .environmentObject(timelineViewModel)
                            .frame(maxWidth: .infinity)
                            .frame(height: timelineHeight)
                    }
                }
            }

            // Loading overlay
            if projectViewModel.isLoading {
                LoadingOverlay()
            }
        }
        .focusedValue(\.projectViewModel, projectViewModel)
        .focusedValue(\.appCoordinator, coordinator)
        .errorAlert($projectViewModel.errorAlert)
        .background(
            // Navigation history keyboard shortcuts (Cmd+[ / Cmd+])
            Group {
                Button("") { coordinator.navigateBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .hidden()

                Button("") { coordinator.navigateForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .hidden()
            }
            .frame(width: 0, height: 0)
        )
    }
}

// MARK: - Sidebar Divider (Resizable)

struct SidebarDivider: View {
    @Binding var sidebarWidth: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newWidth = sidebarWidth + value.translation.width
                        sidebarWidth = min(500, max(200, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

// MARK: - Central View Router (Isolated from unnecessary updates)

/// This view ONLY observes selectedView changes, not the entire coordinator
/// This prevents cascading re-renders when other coordinator properties change
struct CentralViewRouter: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        // Don't use .id() - it destroys @StateObjects and causes issues during rapid switching
        CentralViewStack()
    }
}

// MARK: - Timeline Divider (Resizable)

struct TimelineDivider: View {
    @Binding var timelineHeightRatio: CGFloat
    let totalHeight: CGFloat

    @State private var isDragging = false
    @State private var previousRatio: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDragging ? Color.accentColor : Color.gray.opacity(0.5))
                    .frame(width: 40, height: 4)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        // Clear saved ratio when user manually drags
                        previousRatio = nil
                        // Calculate new ratio based on drag
                        let dragOffset = value.translation.height
                        let newTimelineHeight = (totalHeight * timelineHeightRatio) - dragOffset
                        let newRatio = newTimelineHeight / totalHeight

                        // Clamp between 10% and 60%
                        timelineHeightRatio = min(0.60, max(0.10, newRatio))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .help("Drag to resize timeline panel")
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if abs(timelineHeightRatio - 0.50) < 0.01, let saved = previousRatio {
                        // Already at 50% — restore previous size
                        timelineHeightRatio = saved
                        previousRatio = nil
                    } else {
                        // Save current and snap to 50%
                        previousRatio = timelineHeightRatio
                        timelineHeightRatio = 0.50
                    }
                }
            }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)

                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 20)
        }
    }
}

// MARK: - Central View Stack

/// Routes to the appropriate view based on coordinator.selectedView
struct CentralViewStack: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    // Cache view models to prevent recreation on every switch
    @StateObject private var scheduleViewModel = ScheduleViewModel(scheduleItems: [])
    @StateObject private var castCrewViewModel = CastCrewViewModel(castMembers: [], crewMembers: [], teams: [], equipment: [])
    @StateObject private var budgetViewModel = BudgetViewModel(budget: ProjectBudget())

    var body: some View {
        let _ = debugLog("🔄 CentralViewStack body - current: \(coordinator.selectedView.rawValue)")

        Group {
            switch coordinator.selectedView {
            case .overview:
                ProjectOverviewView()
                    .onAppear { debugLog("📱 Overview appeared") }
            case .script:
                ScriptView()
                    .onAppear { debugLog("📱 ScriptView appeared") }
            case .bubble:
                BubbleView(
                    project: $projectViewModel.project,
                    projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                    highlightedBubbleItem: coordinator.highlightedBubbleItem,
                    onItemsReordered: {
                        // Notify that project data changed (triggers timeline refresh)
                        coordinator.notifyProjectChanged()
                    },
                    onContentChanged: {
                        // Notify that content was added/modified (triggers timeline refresh)
                        coordinator.notifyProjectChanged()
                    },
                    externalSelectedSceneName: coordinator.selectedScene?.name
                )
                .onAppear { debugLog("📱 BubbleView appeared") }
            case .scenes:
                ScenesListView()
                    .onAppear { debugLog("📱 ScenesListView appeared") }
            case .assets:
                AssetsView()
                    .onAppear { debugLog("📱 AssetsView appeared") }
            case .visionBoard:
                VisionBoardView(
                    cards: projectViewModel.project.beats,
                    onCardsChanged: { cards in
                        projectViewModel.project.beats = cards
                        projectViewModel.isDirty = true
                    }
                )
                .onAppear { debugLog("📱 VisionBoardView appeared") }
            case .shotList:
                ProductionViewWrapper(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    subtitle: "Shot List"
                ) {
                    CinematographyViewAdapter()
                }
                .onAppear { debugLog("📱 CinematographyView appeared") }
            case .schedule:
                ProductionViewWrapper(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    subtitle: "Production Schedule"
                ) {
                    ScheduleView(viewModel: scheduleViewModel)
                }
                .onAppear {
                    debugLog("📱 ScheduleView appeared - loading data")
                    scheduleViewModel.setScheduleItems(projectViewModel.project.scheduleItems)
                    debugLog("📱 ScheduleView data loaded")
                }
            case .castCrew:
                ProductionViewWrapper(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    subtitle: "Cast & Crew"
                ) {
                    CastCrewView(viewModel: castCrewViewModel)
                }
                .onAppear {
                    debugLog("📱 CastCrewView appeared - loading data")
                    castCrewViewModel.setCastMembers(projectViewModel.project.castMembers)
                    castCrewViewModel.setCrewMembers(projectViewModel.project.crewMembers)
                    castCrewViewModel.setTeams(projectViewModel.project.teams)
                    castCrewViewModel.setEquipment(projectViewModel.project.equipmentLibrary)
                    debugLog("📱 CastCrewView data loaded")
                }
            case .budget:
                ProductionViewWrapper(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    subtitle: "Budget"
                ) {
                    BudgetView(viewModel: budgetViewModel)
                }
                .onAppear {
                    debugLog("📱 BudgetView appeared - loading data")
                    budgetViewModel.setBudget(projectViewModel.project.projectBudget ?? ProjectBudget())
                    debugLog("📱 BudgetView data loaded")
                }
            case .storyDesign:
                StoryDesignView(
                    project: $projectViewModel.project,
                    projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                    initialCharacterId: coordinator.selectedCharacter?.id,
                    initialLocationId: coordinator.selectedLocation?.id,
                    onGenerateImage: { character, angle, prompt in
                        Task {
                            await generateCharacterImage(character: character, angle: angle, prompt: prompt)
                        }
                    },
                    onAnalyzeTraits: { character in
                        Task {
                            await analyzeCharacterTraits(character: character)
                        }
                    },
                    onGenerateBiography: { character in
                        Task {
                            await generateCharacterBiography(character: character)
                        }
                    }
                )
                .onAppear { debugLog("📱 StoryDesignView appeared") }
            case .settings:
                ProjectSettingsView()
                    .onAppear { debugLog("📱 ProjectSettingsView appeared") }
            case .projects:
                ProjectsExplorerView()
                    .onAppear { debugLog("📱 ProjectsExplorerView appeared") }
            }
        }
        // Removed animation to prevent stacking during rapid view switches
    }

    // MARK: - AI Integration Methods

    private func generateCharacterImage(character: Character, angle: String, prompt: String) async {
        let aiClient = AIServiceClient.shared

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at http://165.22.172.244:8002. Please ensure the AI Proxy server is running."
                )
            }
            return
        }

        await MainActor.run {
            projectViewModel.isLoading = true
        }

        do {
            let request = ImageGenerationRequest(
                prompt: prompt,
                provider: .googleImagen,
                aspectRatio: "1:1",
                numberOfImages: 1
            )

            let response = try await aiClient.generateImage(request)

            guard let imageData = response.images.first else {
                throw AIClientError.invalidResponse("No image generated")
            }

            // Save image to project directory using Python-compatible structure:
            // assets/characters/{CharacterName}/face/{angle}.png
            if let projectPath = projectViewModel.projectPath {
                let projectDir = projectPath.deletingLastPathComponent()
                let sanitizedName = sanitizeAssetName(character.name)

                // Determine subfolder based on angle type
                let (subfolder, filename) = getAssetPath(for: angle)

                // Build path: assets/characters/{CharacterName}/{subfolder}/{filename}.png
                let characterAssetsDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("characters")
                    .appendingPathComponent(sanitizedName)
                    .appendingPathComponent(subfolder)

                let imagePath = characterAssetsDir.appendingPathComponent("\(filename).png")

                // Try to write the image, prompt for access if needed
                let saveSucceeded = await saveImageWithUserPermission(
                    imageData: imageData,
                    imagePath: imagePath,
                    imagesDir: characterAssetsDir,
                    projectDir: projectDir
                )

                if !saveSucceeded {
                    await MainActor.run {
                        projectViewModel.isLoading = false
                    }
                    return
                }

                // Store relative path from project directory (Python-compatible)
                let relativePath = "assets/characters/\(sanitizedName)/\(subfolder)/\(filename).png"

                // Update character with relative image path
                if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                    await MainActor.run {
                        switch angle {
                        case "base":
                            projectViewModel.project.characters[charIndex].baseImage = relativePath
                        case "front":
                            projectViewModel.project.characters[charIndex].imageFront = relativePath
                        case "three_quarter_left":
                            projectViewModel.project.characters[charIndex].imageThreeQuarterLeft = relativePath
                        case "three_quarter_right":
                            projectViewModel.project.characters[charIndex].imageThreeQuarterRight = relativePath
                        case "profile_left":
                            projectViewModel.project.characters[charIndex].imageProfileLeft = relativePath
                        case "profile_right":
                            projectViewModel.project.characters[charIndex].imageProfileRight = relativePath
                        case "back":
                            projectViewModel.project.characters[charIndex].imageBack = relativePath
                        default:
                            // Default to base image
                            projectViewModel.project.characters[charIndex].baseImage = relativePath
                        }
                        projectViewModel.isDirty = true
                    }
                }
            }

            await MainActor.run {
                projectViewModel.isLoading = false
            }

        } catch {
            await MainActor.run {
                projectViewModel.isLoading = false
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Image Generation Failed"
                )
            }
        }
    }

    /// Save image with user permission - prompts for folder access if needed
    private func saveImageWithUserPermission(
        imageData: Data,
        imagePath: URL,
        imagesDir: URL,
        projectDir: URL
    ) async -> Bool {
        // Check if we need to prompt for directory creation
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            // Directory doesn't exist - show dialog to user
            let shouldContinue = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Create Character Images Folder?"
                    alert.informativeText = "The 'character_images' folder doesn't exist. Would you like to create it at:\n\(projectDir.path)"
                    alert.addButton(withTitle: "Create Folder")
                    alert.addButton(withTitle: "Cancel")
                    alert.alertStyle = .informational

                    let response = alert.runModal()
                    continuation.resume(returning: response == .alertFirstButtonReturn)
                }
            }

            guard shouldContinue else {
                return false
            }

            // Try to create the directory
            do {
                // Start accessing the project directory
                _ = projectDir.startAccessingSecurityScopedResource()
                defer { projectDir.stopAccessingSecurityScopedResource() }

                try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                await MainActor.run {
                    self.projectViewModel.errorAlert = ErrorAlert(
                        title: "Failed to Create Folder",
                        message: "Could not create character_images folder. Please create it manually in the Finder at:\n\(projectDir.path)\n\nError: \(error.localizedDescription)"
                    )
                }
                return false
            }
        }

        // Try to write the image
        do {
            _ = projectDir.startAccessingSecurityScopedResource()
            defer { projectDir.stopAccessingSecurityScopedResource() }

            try imageData.write(to: imagePath)
            return true
        } catch {
            await MainActor.run {
                self.projectViewModel.errorAlert = ErrorAlert(
                    title: "Failed to Save Image",
                    message: "Could not save image to character_images folder. You may need to manually create the folder at:\n\(projectDir.path)\n\nError: \(error.localizedDescription)"
                )
            }
            return false
        }
    }

    /// Sanitize asset name for filesystem (Python-compatible)
    /// Converts spaces to underscores, removes special characters
    private func sanitizeAssetName(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")

        // Collapse multiple underscores
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        // Remove leading/trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        // Limit length
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100))
        }

        return sanitized.isEmpty ? "Unnamed" : sanitized
    }

    /// Get asset subfolder and filename for a given angle
    /// Returns (subfolder, filename) tuple matching Python structure
    private func getAssetPath(for angle: String) -> (subfolder: String, filename: String) {
        switch angle {
        case "base", "front":
            return ("face", "front")
        case "three_quarter_left":
            return ("face", "three_quarter_left")
        case "three_quarter_right":
            return ("face", "three_quarter_right")
        case "profile_left", "profile":
            return ("face", "profile")
        case "profile_right":
            return ("face", "profile_right")
        case "back":
            return ("body", "back")
        case "body_front":
            return ("body", "front")
        case "body_three_quarter_left":
            return ("body", "three_quarter_left")
        case "body_three_quarter_right":
            return ("body", "three_quarter_right")
        case "body_profile":
            return ("body", "profile")
        default:
            return ("face", "front")
        }
    }

    /// Open project folder in Finder
    func openProjectFolder() {
        guard let projectPath = projectViewModel.projectPath else {
            projectViewModel.errorAlert = ErrorAlert(
                title: "No Project Open",
                message: "Please open a project first."
            )
            return
        }
        let projectDir = projectPath.deletingLastPathComponent()
        NSWorkspace.shared.open(projectDir)
    }

    private func analyzeCharacterTraits(character: Character) async {
        let aiClient = AIServiceClient.shared

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at http://165.22.172.244:8002. Please ensure the AI Proxy server is running."
                )
            }
            return
        }

        await MainActor.run {
            projectViewModel.isLoading = true
        }

        do {
            let analyzer = CharacterAnalyzer(project: projectViewModel.project, aiClient: aiClient)
            let result = try await analyzer.analyzeCharacter(character) { progress in
                // Progress callback - could update UI here
            }

            // Update character with analysis results
            if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                await MainActor.run {
                    // Update traits
                    for (trait, score) in result.traitScores {
                        projectViewModel.project.characters[charIndex].traits[trait] = score
                    }

                    // Update physical attributes if available
                    if !result.physicalAttributes.isEmpty {
                        if let build = result.physicalAttributes["build"] {
                            projectViewModel.project.characters[charIndex].build = build
                        }
                        if let hairColor = result.physicalAttributes["hair_color"] {
                            projectViewModel.project.characters[charIndex].hairColor = hairColor
                        }
                        if let eyeColor = result.physicalAttributes["eye_color"] {
                            projectViewModel.project.characters[charIndex].eyeColor = eyeColor
                        }
                    }

                    // Update biography attributes if available
                    if !result.biographyAttributes.isEmpty {
                        if let occupation = result.biographyAttributes["occupation"] {
                            projectViewModel.project.characters[charIndex].occupation = occupation
                        }
                        if let primaryGoal = result.biographyAttributes["primary_goal"] {
                            projectViewModel.project.characters[charIndex].primaryGoal = primaryGoal
                        }
                        if let primaryFear = result.biographyAttributes["primary_fear"] {
                            projectViewModel.project.characters[charIndex].primaryFear = primaryFear
                        }
                    }

                    projectViewModel.isDirty = true
                    projectViewModel.isLoading = false
                }
            } else {
                await MainActor.run {
                    projectViewModel.isLoading = false
                }
            }

        } catch {
            await MainActor.run {
                projectViewModel.isLoading = false
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Character Analysis Failed"
                )
            }
        }
    }

    private func generateCharacterBiography(character: Character) async {
        let aiClient = AIServiceClient.shared

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at http://165.22.172.244:8002. Please ensure the AI Proxy server is running."
                )
            }
            return
        }

        await MainActor.run {
            projectViewModel.isLoading = true
        }

        do {
            let keyTraits = character.traits.sorted { $0.value > $1.value }.prefix(5).map { $0.key }

            let backstory = try await aiClient.generateCharacterBackstory(
                characterName: character.name,
                age: "\(character.age)",
                occupation: character.occupation ?? "",
                keyTraits: Array(keyTraits),
                storyContext: projectViewModel.project.overviewSummary
            )

            // Update character with generated backstory
            if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                await MainActor.run {
                    projectViewModel.project.characters[charIndex].backgroundStory = backstory
                    projectViewModel.isDirty = true
                    projectViewModel.isLoading = false
                }
            } else {
                await MainActor.run {
                    projectViewModel.isLoading = false
                }
            }

        } catch {
            await MainActor.run {
                projectViewModel.isLoading = false
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Biography Generation Failed"
                )
            }
        }
    }
}

// MARK: - App Toolbar

struct AppToolbar: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 0) {
            // View Selection (Radio Button Group)
            HStack(spacing: 4) {
                ForEach(AppView.allCases) { view in
                    Button(action: {
                        debugLog("🖱️ Button pressed: \(view.rawValue)")
                        coordinator.navigateTo(view)
                        debugLog("🖱️ Button action complete: \(view.rawValue)")
                    }) {
                        Label(view.rawValue, systemImage: view.icon)
                            .labelStyle(.iconOnly)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(ToolbarButtonStyle(isSelected: coordinator.selectedView == view, tooltipText: view.rawValue))
                }
            }
            .padding(.leading, 12)

            Spacer()

            // Toggle Controls
            HStack(spacing: 8) {
                Divider()
                    .frame(height: 20)

                Button(action: {
                    coordinator.toggleNavigator()
                }) {
                    Image(systemName: "sidebar.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingNavigator, tooltipText: "Navigator (⌘⌥1)"))

                Button(action: {
                    coordinator.toggleTimeline()
                }) {
                    Image(systemName: "waveform")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingTimeline, tooltipText: "Timeline (⌘⌥2)"))

                Button(action: {
                    coordinator.toggleRightPanel()
                }) {
                    Image(systemName: "sidebar.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingRightPanel, tooltipText: "Right Panel (⌘⌥3)"))
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }
}

// MARK: - Instant Tooltip using NSWindow

/// A floating tooltip window that appears instantly on hover
class TooltipWindowController {
    static let shared = TooltipWindowController()

    private var window: NSWindow?
    private var textField: NSTextField?

    private init() {}

    func show(text: String, near point: NSPoint) {
        debugLog("🪟 TooltipWindow.show: '\(text)' near \(point)")
        hide()

        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.systemFont(ofSize: 11)
        textField.textColor = NSColor.labelColor
        textField.backgroundColor = NSColor.windowBackgroundColor
        textField.isBordered = false
        textField.sizeToFit()

        let padding: CGFloat = 8
        let contentSize = NSSize(
            width: textField.frame.width + padding * 2,
            height: textField.frame.height + padding
        )

        textField.frame.origin = NSPoint(x: padding, y: padding / 2)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 4
        window.contentView?.addSubview(textField)

        // Position below the mouse cursor
        let screenPoint = NSPoint(
            x: point.x - contentSize.width / 2,
            y: point.y - contentSize.height - 20
        )
        debugLog("🪟 TooltipWindow positioning at: \(screenPoint)")
        window.setFrameOrigin(screenPoint)
        window.orderFront(nil)

        self.window = window
        self.textField = textField
        debugLog("🪟 TooltipWindow shown")
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        textField = nil
    }
}


// MARK: - Toolbar Button Styles

struct ToolbarButtonStyle: ButtonStyle {
    let isSelected: Bool
    var tooltipText: String = ""
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.2)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { hovering in
                isHovered = hovering
                if !tooltipText.isEmpty {
                    if hovering {
                        let mouseLocation = NSEvent.mouseLocation
                        TooltipWindowController.shared.show(text: tooltipText, near: mouseLocation)
                    } else {
                        TooltipWindowController.shared.hide()
                    }
                }
            }
    }
}

struct ToggleButtonStyle: ButtonStyle {
    let isActive: Bool
    var tooltipText: String = ""
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(0.15)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { hovering in
                isHovered = hovering
                if !tooltipText.isEmpty {
                    if hovering {
                        let mouseLocation = NSEvent.mouseLocation
                        TooltipWindowController.shared.show(text: tooltipText, near: mouseLocation)
                    } else {
                        TooltipWindowController.shared.hide()
                    }
                }
            }
    }
}

// MARK: - Navigator Sidebar

struct NavigatorSidebar: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var selectedTab: NavigatorTab = .outline

    var body: some View {
        VStack(spacing: 0) {
            // Project Identity Header
            if projectViewModel.hasProject {
                ProjectIdentityView(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    size: .standard,
                    showMetadata: false
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()
            }

            // Navigator Header
            HStack {
                Text("Navigator")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab Selector
            Picker("", selection: $selectedTab) {
                ForEach(NavigatorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .help("Switch between Outline, Versions, and Comments views")

            Divider()

            // Tab Content
            Group {
                switch selectedTab {
                case .outline:
                    OutlineTab()
                case .markers:
                    MarkersTab()
                case .versions:
                    VersionsTab()
                case .comments:
                    CommentsTab()
                }
            }
        }
    }
}

enum NavigatorTab: String, CaseIterable, Identifiable {
    case outline = "Outline"
    case markers = "Markers"
    case versions = "Versions"
    case comments = "Comments"

    var id: String { rawValue }
}

// MARK: - Timeline Container

struct TimelineContainer: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    /// Track sequence count to detect actual changes (not just any array mutation)
    @State private var lastSequenceCount: Int = 0

    /// Project base path as URL for image loading (matches CinematographyView resolution)
    private var projectBaseURL: URL? {
        projectViewModel.projectPath?.deletingLastPathComponent()
    }

    var body: some View {
        TimelineView(
            viewModel: timelineViewModel,
            projectBasePath: projectBaseURL,
            onSegmentClicked: { segment in
                // Handle segment click - navigate to the appropriate scene
                if !segment.sceneName.isEmpty {
                    // Find scene by name and select it
                    if let scene = projectViewModel.allScenes.first(where: { $0.name == segment.sceneName }) {
                        coordinator.selectScene(scene)
                        // Navigate to bubble view
                        coordinator.navigateTo(.bubble)
                    }
                }
            },
            onSegmentDoubleClicked: { segment in
                // Handle double-click - highlight the corresponding bubble
                let itemType: String
                switch segment.contentType {
                case .dialogue:
                    itemType = "dialogue"
                case .action:
                    itemType = "action"
                case .narration:
                    itemType = "narration"
                case .note:
                    itemType = "note"
                case .soundNote:
                    itemType = "soundNote"
                }

                // Use sourceItemId (the original dialogue/action/narration ID) for matching
                let itemId = segment.sourceItemId ?? segment.id.uuidString

                // Trigger highlight in bubble view
                coordinator.highlightBubbleItem(
                    id: itemId,
                    type: itemType,
                    sceneName: segment.sceneName
                )

                // Navigate to bubble view if not already there
                if coordinator.selectedView != .bubble {
                    coordinator.navigateTo(.bubble)
                }
            },
            onShotLabelDoubleClicked: { shotId, sceneName in
                // Find the shot by shotId and sceneName to ensure correct match
                if let scene = projectViewModel.allScenes.first(where: { $0.name == sceneName }),
                   let shot = scene.shots.first(where: { $0.shotId == shotId }) {
                    coordinator.selectScene(scene)
                    coordinator.selectShot(shot)
                    coordinator.navigateTo(.shotList)
                }
            },
            onShotLabelMoved: { _, _, _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onSegmentMoved: { _, _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onSegmentsMoved: { _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            // Set project and show global timeline view
            timelineViewModel.projectFilePath = projectViewModel.projectPath
            timelineViewModel.setProject(projectViewModel.project)
            timelineViewModel.showGlobal()
            lastSequenceCount = projectViewModel.project.sequences.count
        }
        // Refresh when project finishes loading (catches async restoreLastProject)
        .onChange(of: projectViewModel.hasProject) { _, hasProject in
            if hasProject {
                timelineViewModel.projectFilePath = projectViewModel.projectPath
                timelineViewModel.setProject(projectViewModel.project)
                timelineViewModel.showGlobal()
                lastSequenceCount = projectViewModel.project.sequences.count
            }
        }
        // Only refresh when sequence COUNT changes, not on every array comparison
        .onChange(of: projectViewModel.project.sequences.count) { _, newCount in
            if newCount != lastSequenceCount {
                lastSequenceCount = newCount
                timelineViewModel.setProject(projectViewModel.project)
                timelineViewModel.refresh()
            }
        }
        // Subscribe to project changed events (e.g., when bubbles are reordered)
        .onReceive(coordinator.projectChanged) { _ in
            timelineViewModel.setProject(projectViewModel.project)
            timelineViewModel.refresh()
        }
    }
}

// MARK: - Placeholder Views

struct ProjectOverviewPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Overview", description: "Project pitch and overview information")
    }
}

struct ScenesPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Scenes", description: "Scene list and management")
    }
}

struct AssetsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Assets", description: "Media library and asset management")
    }
}

struct SettingsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Settings", description: "Project metadata and configuration")
    }
}


// MARK: - Generic Placeholder View

struct PlaceholderView: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title)
                .fontWeight(.semibold)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Production View Wrapper

/// Wraps production views with a project identity header
struct ProductionViewWrapper<Content: View>: View {
    let project: Project
    let projectPath: URL?
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderBanner(
                project: project,
                projectPath: projectPath,
                subtitle: subtitle
            )

            Divider()

            content()
        }
    }
}

// MARK: - Cinematography View Adapter

/// Adapter view that integrates CinematographyView with scene-based shot storage
struct CinematographyViewAdapter: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var shotsAdapter: ShotsAdapter?
    @State private var lastSequenceCount: Int = 0

    /// Get the first scene from the project for context
    private var firstScene: DCScene? {
        projectViewModel.project.sequences.first?.scenes.first
    }

    var body: some View {
        Group {
            if let adapter = shotsAdapter {
                CinematographyView(
                    shots: adapter.allShots,
                    scene: firstScene,
                    characters: projectViewModel.project.characters,
                    projectBasePath: projectViewModel.projectPath,
                    initialSelectedShotId: coordinator.selectedShot?.shotId,
                    onShotsChanged: { updatedShots in
                        adapter.updateShots(updatedShots)
                    }
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            // Initialize adapter with actual project and callback
            if shotsAdapter == nil {
                shotsAdapter = ShotsAdapter(
                    project: projectViewModel.project,
                    onShotsChanged: { updatedProject in
                        projectViewModel.project = updatedProject
                        projectViewModel.isDirty = true
                        // Notify timeline and other views that shots changed
                        coordinator.projectChanged.send(())
                    }
                )
            }
            lastSequenceCount = projectViewModel.project.sequences.count
        }
        // Only refresh when sequence COUNT changes, not on every comparison
        .onChange(of: projectViewModel.project.sequences.count) { newCount in
            if newCount != lastSequenceCount {
                lastSequenceCount = newCount
                shotsAdapter?.refresh(from: projectViewModel.project)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
}
