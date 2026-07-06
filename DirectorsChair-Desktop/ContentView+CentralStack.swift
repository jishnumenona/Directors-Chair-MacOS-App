//
// ContentView+CentralStack.swift
//
// Extracted from ContentView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were already internal helper views.
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairProduction
import DirectorsChairServices

struct CentralViewRouter: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        // Don't use .id() - it destroys @StateObjects and causes issues during rapid switching
        CentralViewStack()
    }
}
struct CentralViewStack: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    /// Incremented on each projectChanged event to trigger BubbleView cache refresh
    @State private var bubbleRefreshTrigger = 0

    /// Track which views have been visited so we only create them lazily,
    /// but keep them alive (preserving scroll position and all @State) once created.
    @State private var visitedViews: Set<AppView> = []

    /// AI operation progress — survives navigation between tabs
    @StateObject private var aiProgress = AIProgressTracker()

    // Cache view models to prevent recreation on every switch
    @StateObject private var scheduleViewModel = ScheduleViewModel(scheduleItems: [])
    @StateObject private var castCrewViewModel = CastCrewViewModel(castMembers: [], crewMembers: [], teams: [], equipment: [])
    @StateObject private var budgetViewModel = BudgetViewModel(budget: ProjectBudget())
    @StateObject private var equipmentViewModel = EquipmentViewModel()
    @StateObject private var ganttViewModel = GanttViewModel()
    /// Owns the video-generation lifecycle app-side so jobs aren't orphaned by
    /// navigating away from the cinematography view (WS6.1).
    @StateObject private var videoJobCoordinator = VideoJobCoordinator()

    var body: some View {
        let currentView = coordinator.selectedView
        let _ = debugLog("🔄 CentralViewStack body - current: \(currentView.rawValue)")

        ZStack {
            ForEach(AppView.allCases) { view in
                if visitedViews.contains(view) || view == currentView {
                    viewContent(for: view)
                        .opacity(view == currentView ? 1 : 0)
                        .allowsHitTesting(view == currentView)
                        .zIndex(view == currentView ? 1 : 0)
                }
            }
        }
        .onChange(of: currentView) { _, newView in
            visitedViews.insert(newView)
        }
        .onAppear {
            visitedViews.insert(currentView)
            // Persist video-job results into the project (app-scoped, so a job
            // completes even after the generation view is gone).
            videoJobCoordinator.onEvent = { event in
                switch event {
                case .started(let shotId, let jobId):
                    projectViewModel.setShotVideoJobId(shotId: shotId, jobId: jobId)
                case .completed(let shotId, let path):
                    projectViewModel.setShotVideoPath(shotId: shotId, videoRelativePath: path)
                case .cleared(let shotId):
                    projectViewModel.setShotVideoJobId(shotId: shotId, jobId: nil)
                }
            }
        }
        // Removed animation to prevent stacking during rapid view switches
        .onReceive(coordinator.projectEvents) { event in
            // Bubble view renders script content — skip shot/production churn.
            guard event != .shots && event != .production else { return }
            bubbleRefreshTrigger += 1
        }
    }

    @ViewBuilder
    private func viewContent(for view: AppView) -> some View {
        switch view {
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
                    projectViewModel.isDirty = true
                    coordinator.notifyProjectChanged()
                },
                onContentChanged: {
                    projectViewModel.isDirty = true
                    coordinator.notifyProjectChanged()
                },
                externalSelectedSceneId: coordinator.selectedScene?.id,
                externalRefreshTrigger: bubbleRefreshTrigger,
                onDialogueSelected: { dialogue in
                    coordinator.chatContextDialogue = dialogue
                },
                onNavigateToCharacter: { character in
                    coordinator.selectCharacter(character)
                }
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
                    .environmentObject(videoJobCoordinator)
            }
            .onAppear { debugLog("📱 CinematographyView appeared") }
        case .production:
            ProductionContainer(
                scheduleViewModel: scheduleViewModel,
                castCrewViewModel: castCrewViewModel,
                budgetViewModel: budgetViewModel,
                equipmentViewModel: equipmentViewModel,
                ganttViewModel: ganttViewModel
            )
            .onAppear { debugLog("📱 ProductionContainer appeared") }
        case .storyDesign:
            StoryDesignView(
                project: $projectViewModel.project,
                projectBasePath: projectViewModel.projectPath?.deletingLastPathComponent(),
                initialCharacterId: coordinator.selectedCharacter?.id,
                initialLocationId: coordinator.selectedLocation?.id,
                preferredMode: coordinator.preferredStoryDesignMode,
                initialLightCueId: coordinator.selectedLightCueId,
                initialSFXCueId: coordinator.selectedSFXCueId,
                initialSupportCueId: coordinator.selectedSupportCueId,
                markers: timelineViewModel.userMarkers,
                traitAnalysisProgress: aiProgress.traitAnalysis,
                biographyProgress: aiProgress.biography,
                onGenerateImage: { character, angle, prompt, progressHandler in
                    Task {
                        await generateCharacterImage(character: character, angle: angle, prompt: prompt, progressHandler: progressHandler)
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
                },
                onGenerateLocationImage: { location, variation, prompt, progressHandler in
                    Task {
                        await generateLocationImage(location: location, variation: variation, prompt: prompt, progressHandler: progressHandler)
                    }
                },
                onUploadReferenceImage: { character, imageData, progressHandler in
                    Task {
                        await analyzeCharacterReferenceImage(character: character, imageData: imageData, progressHandler: progressHandler)
                    }
                }
            )
            .onAppear { debugLog("📱 StoryDesignView appeared") }
        case .curation:
            ProductionViewWrapper(
                project: projectViewModel.project,
                projectPath: projectViewModel.projectPath,
                subtitle: "Curation"
            ) {
                CurationViewAdapter()
            }
            .onAppear { debugLog("📱 CurationView appeared") }
        case .playback:
            PlaybackView()
                .onAppear { debugLog("📱 PlaybackView appeared") }
        case .settings:
            ProjectSettingsView()
                .onAppear { debugLog("📱 ProjectSettingsView appeared") }
        case .projects:
            ProjectsExplorerView()
                .onAppear { debugLog("📱 ProjectsExplorerView appeared") }
        }
    }

    // MARK: - AI Integration Methods

    private func generateCharacterImage(character: Character, angle: String, prompt: String, progressHandler: @escaping @MainActor (Double) -> Void) async {
        let aiClient = AIServiceClient.shared

        await MainActor.run { progressHandler(0.05) }

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                progressHandler(1.0) // Clear progress
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
        }

        await MainActor.run { progressHandler(0.1) }

        do {
            // Load base image as reference when generating angle variants
            var referenceBase64: String? = nil
            var referenceMime: String? = nil
            if angle != "base" {
                referenceBase64 = loadBaseImageAsBase64(for: character)
                if referenceBase64 != nil {
                    referenceMime = "image/png"
                }
            }

            await MainActor.run { progressHandler(0.15) }

            let request = ImageGenerationRequest(
                prompt: prompt,
                provider: .googleImagen,
                aspectRatio: "1:1",
                numberOfImages: 1,
                referenceImageBase64: referenceBase64,
                referenceMimeType: referenceMime
            )

            // Simulate gradual progress during the AI call
            let progressSimulator = Task { @MainActor in
                var current = 0.2
                while current < 0.85 {
                    progressHandler(current)
                    try await Task.sleep(nanoseconds: 800_000_000) // 0.8s intervals
                    current += Double.random(in: 0.03...0.08)
                }
            }

            let response = try await aiClient.generateImage(request)
            progressSimulator.cancel()

            await MainActor.run { progressHandler(0.88) }

            guard let imageData = response.images.first else {
                throw AIClientError.invalidResponse("No image generated")
            }

            await MainActor.run { progressHandler(0.92) }

            // Save image to project directory
            if let projectPath = projectViewModel.projectPath {
                let projectDir = projectPath.deletingLastPathComponent()
                let sanitizedName = sanitizeAssetName(character.name)

                // Check if this is a costume image (format: "costume:{costumeName}:{angle}")
                let isCostumeImage = angle.hasPrefix("costume:")
                let costumeComponents = angle.split(separator: ":", maxSplits: 2).map(String.init)

                let subfolder: String
                let filename: String

                if isCostumeImage, costumeComponents.count == 3 {
                    let costumeName = costumeComponents[1]
                    let costumeAngle = costumeComponents[2]
                    let sanitizedCostumeName = sanitizeAssetName(costumeName)
                    subfolder = "costumes/\(sanitizedCostumeName)"
                    filename = costumeAngle
                } else {
                    let assetPath = getAssetPath(for: angle)
                    subfolder = assetPath.subfolder
                    filename = assetPath.filename
                }

                let characterAssetsDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("characters")
                    .appendingPathComponent(sanitizedName)
                    .appendingPathComponent(subfolder)

                let imagePath = characterAssetsDir.appendingPathComponent("\(filename).png")

                let saveSucceeded = await saveImageWithUserPermission(
                    imageData: imageData,
                    imagePath: imagePath,
                    imagesDir: characterAssetsDir,
                    projectDir: projectDir
                )

                if !saveSucceeded {
                    await MainActor.run { progressHandler(1.0) }
                    return
                }

                await MainActor.run { progressHandler(0.96) }

                let relativePath = "assets/characters/\(sanitizedName)/\(subfolder)/\(filename).png"

                if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                    await MainActor.run {
                        if isCostumeImage, costumeComponents.count == 3 {
                            // Store on the matching CharacterCostume
                            let costumeName = costumeComponents[1]
                            let costumeAngle = costumeComponents[2]
                            if var costumes = projectViewModel.project.characters[charIndex].costumes,
                               let costumeIdx = costumes.firstIndex(where: { $0.name == costumeName }) {
                                switch costumeAngle {
                                case "front":
                                    costumes[costumeIdx].imageFront = relativePath
                                case "three_quarter_left":
                                    costumes[costumeIdx].imageThreeQuarterLeft = relativePath
                                case "three_quarter_right":
                                    costumes[costumeIdx].imageThreeQuarterRight = relativePath
                                case "profile":
                                    costumes[costumeIdx].imageProfile = relativePath
                                case "back":
                                    costumes[costumeIdx].imageBack = relativePath
                                case "full_body":
                                    costumes[costumeIdx].imageFullBody = relativePath
                                default:
                                    costumes[costumeIdx].imageFront = relativePath
                                }
                                projectViewModel.project.characters[charIndex].costumes = costumes
                            }
                        } else {
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
                                projectViewModel.project.characters[charIndex].baseImage = relativePath
                            }
                        }
                        projectViewModel.isDirty = true
                    }
                }
            }

            // Signal completion
            await MainActor.run { progressHandler(1.0) }

        } catch {
            await MainActor.run {
                progressHandler(1.0) // Clear progress even on failure
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Image Generation Failed"
                )
            }
        }
    }

    /// Load the base image for a character as base64 string for use as reference
    private func loadBaseImageAsBase64(for character: Character) -> String? {
        guard let projectPath = projectViewModel.projectPath else { return nil }
        let projectDir = projectPath.deletingLastPathComponent()

        // Try character's stored base image path first, then front image
        let candidatePaths = [character.baseImage, character.imageFront].compactMap { $0 }

        for relativePath in candidatePaths {
            let fullPath = projectDir.appendingPathComponent(relativePath)
            if let imageData = try? Data(contentsOf: fullPath) {
                return imageData.base64EncodedString()
            }
        }

        // Also try discovered images from filesystem
        let sanitizedName = sanitizeAssetName(character.name)
        let faceFrontPath = projectDir
            .appendingPathComponent("assets/characters/\(sanitizedName)/face/front.png")
        if let imageData = try? Data(contentsOf: faceFrontPath) {
            return imageData.base64EncodedString()
        }

        return nil
    }

    /// Save image with user permission - prompts for folder access if needed
    private func saveImageWithUserPermission(
        imageData: Data,
        imagePath: URL,
        imagesDir: URL,
        projectDir: URL
    ) async -> Bool {
        // Create directory automatically if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            do {
                _ = projectDir.startAccessingSecurityScopedResource()
                defer { projectDir.stopAccessingSecurityScopedResource() }

                try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                await MainActor.run {
                    self.projectViewModel.errorAlert = ErrorAlert(
                        title: "Failed to Create Folder",
                        message: "Could not create images folder at:\n\(imagesDir.path)\n\nError: \(error.localizedDescription)"
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

    // MARK: - Analyze Character Reference Image

    private func analyzeCharacterReferenceImage(
        character: Character,
        imageData: Data,
        progressHandler: @escaping @MainActor (Double) -> Void
    ) async {
        let aiClient = AIServiceClient.shared

        await MainActor.run { progressHandler(0.1) }

        guard await aiClient.testConnection() else {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server. Please check your internet connection and try again."
                )
            }
            return
        }

        await MainActor.run { progressHandler(0.2) }

        let base64 = imageData.base64EncodedString()

        let prompt = """
        Analyze this character reference image and extract physical attributes and costume details.
        Return ONLY valid JSON with no markdown formatting or code fences.

        {
          "gender": "male|female|neutral",
          "age": <estimated age as integer>,
          "build": "Slim|Athletic|Average|Stocky|Heavy",
          "heightCm": <estimated height in cm>,
          "weightKg": <estimated weight in kg>,
          "hairColor": "<hex color string like #8B4513>",
          "hairStyle": "<e.g., Wavy, Straight, Curly, Braided>",
          "hairLength": "Bald|Short|Medium|Long|Very Long",
          "eyeColor": "<hex color string>",
          "eyeColorDescription": "<e.g., Brown, Blue, Hazel>",
          "eyeShape": "Almond|Round|Hooded|Monolid|Deep-set|Upturned|Downturned",
          "skinTone": "<hex color string>",
          "ethnicity": "<estimated ethnicity description>",
          "facialStructure": "Oval|Round|Square|Heart|Oblong|Diamond",
          "distinguishingFeatures": "<scars, tattoos, birthmarks, or 'None'>",
          "costume": {
            "name": "<descriptive costume name>",
            "description": "<brief overall description>",
            "garmentTop": "<top garment description>",
            "garmentBottom": "<bottom garment description>",
            "footwear": "<footwear description or empty string>",
            "outerwear": "<outerwear description or empty string>",
            "headwear": "<headwear description or empty string>",
            "accessories": ["<item1>", "<item2>"],
            "colorPalette": ["#hex1", "#hex2", "#hex3"],
            "era": "<Modern|Period|Fantasy|Sci-Fi|Victorian|Medieval|etc>",
            "styleCategory": "<Casual|Formal|Military|Athletic|etc>"
          }
        }
        """

        do {
            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 2000,
                temperature: 0.3,
                imageBase64: base64,
                imageMimeType: "image/png"
            )

            await MainActor.run { progressHandler(0.4) }

            let response = try await aiClient.generateText(request)

            await MainActor.run { progressHandler(0.7) }

            // Strip markdown code fences if present
            var jsonText = response.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonText.hasPrefix("```") {
                if let firstNewline = jsonText.firstIndex(of: "\n") {
                    jsonText = String(jsonText[jsonText.index(after: firstNewline)...])
                }
                if jsonText.hasSuffix("```") {
                    jsonText = String(jsonText.dropLast(3))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            guard let jsonData = jsonText.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                await MainActor.run {
                    progressHandler(1.0)
                    projectViewModel.errorAlert = ErrorAlert(
                        title: "Analysis Failed",
                        message: "Could not parse AI response. The image may not contain a clear character."
                    )
                }
                return
            }

            await MainActor.run { progressHandler(0.8) }

            guard let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) else {
                await MainActor.run { progressHandler(1.0) }
                return
            }

            await MainActor.run {
                var char = projectViewModel.project.characters[charIndex]

                if let gender = json["gender"] as? String, !gender.isEmpty {
                    let g = gender.lowercased()
                    if g == "male" || g == "female" || g == "neutral" {
                        char.gender = g
                    }
                }
                if let age = json["age"] as? Int, age > 0 {
                    char.age = age
                }
                if let build = json["build"] as? String, !build.isEmpty {
                    char.build = build
                }
                if let heightCm = json["heightCm"] as? Double, heightCm > 0 {
                    char.heightCm = heightCm
                }
                if let weightKg = json["weightKg"] as? Double, weightKg > 0 {
                    char.weightKg = weightKg
                }
                if let hairColor = json["hairColor"] as? String, !hairColor.isEmpty {
                    char.hairColor = hairColor
                }
                if let hairStyle = json["hairStyle"] as? String, !hairStyle.isEmpty {
                    char.hairStyle = hairStyle
                }
                if let hairLength = json["hairLength"] as? String, !hairLength.isEmpty {
                    char.hairLength = hairLength
                }
                if let eyeColor = json["eyeColor"] as? String, !eyeColor.isEmpty {
                    char.eyeColor = eyeColor
                }
                if let eyeColorDesc = json["eyeColorDescription"] as? String, !eyeColorDesc.isEmpty {
                    char.eyeColorDescription = eyeColorDesc
                }
                if let eyeShape = json["eyeShape"] as? String, !eyeShape.isEmpty {
                    char.eyeShape = eyeShape
                }
                if let skinTone = json["skinTone"] as? String, !skinTone.isEmpty {
                    char.skinTone = skinTone
                }
                if let ethnicity = json["ethnicity"] as? String, !ethnicity.isEmpty {
                    char.ethnicity = ethnicity
                }
                if let facialStructure = json["facialStructure"] as? String, !facialStructure.isEmpty {
                    char.facialStructure = facialStructure
                }
                if let features = json["distinguishingFeatures"] as? String, !features.isEmpty, features != "None" {
                    char.distinguishingFeatures = features
                }

                // Create costume if present
                if let costumeJson = json["costume"] as? [String: Any],
                   let costumeName = costumeJson["name"] as? String, !costumeName.isEmpty {
                    let costume = CharacterCostume(
                        name: costumeName,
                        description: costumeJson["description"] as? String ?? "",
                        era: costumeJson["era"] as? String,
                        styleCategory: costumeJson["styleCategory"] as? String,
                        colorPalette: costumeJson["colorPalette"] as? [String],
                        garmentTop: costumeJson["garmentTop"] as? String,
                        garmentBottom: costumeJson["garmentBottom"] as? String,
                        footwear: costumeJson["footwear"] as? String,
                        outerwear: costumeJson["outerwear"] as? String,
                        headwear: costumeJson["headwear"] as? String,
                        accessories: costumeJson["accessories"] as? [String]
                    )

                    if char.costumes == nil {
                        char.costumes = [costume]
                    } else {
                        char.costumes?.append(costume)
                    }

                    // Copy uploaded image as costume front image
                    if let projectPath = projectViewModel.projectPath {
                        let projectDir = projectPath.deletingLastPathComponent()
                        let sanitizedCharName = sanitizeAssetName(char.name)
                        let sanitizedCostumeName = sanitizeAssetName(costumeName)
                        let costumeDir = projectDir
                            .appendingPathComponent("assets/characters/\(sanitizedCharName)/costumes/\(sanitizedCostumeName)")
                        let costumeFrontPath = costumeDir.appendingPathComponent("front.png")

                        do {
                            _ = projectDir.startAccessingSecurityScopedResource()
                            defer { projectDir.stopAccessingSecurityScopedResource() }
                            try FileManager.default.createDirectory(at: costumeDir, withIntermediateDirectories: true)
                            try imageData.write(to: costumeFrontPath)

                            let relativePath = "assets/characters/\(sanitizedCharName)/costumes/\(sanitizedCostumeName)/front.png"
                            if let lastIndex = char.costumes?.indices.last {
                                char.costumes?[lastIndex].imageFront = relativePath
                            }
                        } catch {
                            debugLog("Failed to save costume image: \(error)")
                        }
                    }
                }

                projectViewModel.project.characters[charIndex] = char
                projectViewModel.isDirty = true
                progressHandler(1.0)
            }
        } catch {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "Analysis Failed",
                    message: "Failed to analyze reference image: \(error.localizedDescription)"
                )
            }
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
        let charId = character.id
        let tracker = aiProgress

        await MainActor.run { tracker.traitAnalysis[charId] = 0 }

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                tracker.traitAnalysis.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
        }

        do {
            let analyzer = CharacterAnalyzer(project: projectViewModel.project, aiClient: aiClient)

            let result = try await analyzer.analyzeCharacter(character) { progress in
                Task { @MainActor in
                    tracker.traitAnalysis[charId] = progress
                }
            }

            // Update character with analysis results
            if let charIndex = projectViewModel.project.characters.firstIndex(where: { $0.id == character.id }) {
                await MainActor.run {
                    tracker.traitAnalysis[charId] = 95

                    // Update traits
                    for (trait, score) in result.traitScores {
                        projectViewModel.project.characters[charIndex].traits[trait] = score
                    }

                    // Store AI analysis metadata
                    projectViewModel.project.characters[charIndex].traitsConfidenceScore = result.confidenceScore
                    projectViewModel.project.characters[charIndex].traitsAiReasoning = result.reasoning
                    projectViewModel.project.characters[charIndex].traitsLastCalibrated = Date()

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
                    tracker.traitAnalysis.removeValue(forKey: charId)
                }
            } else {
                await MainActor.run {
                    tracker.traitAnalysis.removeValue(forKey: charId)
                }
            }

        } catch {
            await MainActor.run {
                tracker.traitAnalysis.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Character Analysis Failed"
                )
            }
        }
    }

    private func generateCharacterBiography(character: Character) async {
        let aiClient = AIServiceClient.shared
        let charId = character.id
        let tracker = aiProgress

        await MainActor.run { tracker.biography[charId] = 0 }

        // Check if AI server is available
        guard await aiClient.testConnection() else {
            await MainActor.run {
                tracker.biography.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
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
                    tracker.biography.removeValue(forKey: charId)
                }
            } else {
                await MainActor.run {
                    tracker.biography.removeValue(forKey: charId)
                }
            }

        } catch {
            await MainActor.run {
                tracker.biography.removeValue(forKey: charId)
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Biography Generation Failed"
                )
            }
        }
    }

    // MARK: - Location Image Generation

    private func generateLocationImage(location: Location, variation: String, prompt: String, progressHandler: @escaping @MainActor (Double) -> Void) async {
        let aiClient = AIServiceClient.shared

        await MainActor.run { progressHandler(0.05) }

        guard await aiClient.testConnection() else {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    title: "AI Service Unavailable",
                    message: "Could not connect to AI server at directorschair.app. Please check your internet connection and try again."
                )
            }
            return
        }

        await MainActor.run { progressHandler(0.1) }

        do {
            // Load primary image as reference when generating variations
            var referenceBase64: String? = nil
            var referenceMime: String? = nil
            if variation != "primary" {
                referenceBase64 = loadPrimaryLocationImageAsBase64(for: location)
                if referenceBase64 != nil {
                    referenceMime = "image/png"
                }
            }

            await MainActor.run { progressHandler(0.15) }

            let request = ImageGenerationRequest(
                prompt: prompt,
                provider: .googleImagen,
                aspectRatio: "16:9",
                numberOfImages: 1,
                referenceImageBase64: referenceBase64,
                referenceMimeType: referenceMime
            )

            // Simulate gradual progress during the AI call
            let progressSimulator = Task { @MainActor in
                var current = 0.2
                while current < 0.85 {
                    progressHandler(current)
                    try await Task.sleep(nanoseconds: 800_000_000)
                    current += Double.random(in: 0.03...0.08)
                }
            }

            let response = try await aiClient.generateImage(request)
            progressSimulator.cancel()

            await MainActor.run { progressHandler(0.88) }

            guard let imageData = response.images.first else {
                throw AIClientError.invalidResponse("No image generated")
            }

            await MainActor.run { progressHandler(0.92) }

            // Save image to project directory
            if let projectPath = projectViewModel.projectPath {
                let projectDir = projectPath.deletingLastPathComponent()
                let sanitizedName = sanitizeAssetName(location.name)

                let locationAssetsDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("locations")
                    .appendingPathComponent(sanitizedName)

                let imagePath = locationAssetsDir.appendingPathComponent("\(variation).png")

                let saveSucceeded = await saveImageWithUserPermission(
                    imageData: imageData,
                    imagePath: imagePath,
                    imagesDir: locationAssetsDir,
                    projectDir: projectDir
                )

                if !saveSucceeded {
                    await MainActor.run { progressHandler(1.0) }
                    return
                }

                await MainActor.run { progressHandler(0.96) }

                let relativePath = "assets/locations/\(sanitizedName)/\(variation).png"

                if let locIndex = projectViewModel.project.locations.firstIndex(where: { $0.id == location.id }) {
                    await MainActor.run {
                        if variation == "primary" {
                            projectViewModel.project.locations[locIndex].primaryImage = relativePath
                        }
                        if !projectViewModel.project.locations[locIndex].images.contains(relativePath) {
                            projectViewModel.project.locations[locIndex].images.append(relativePath)
                        }
                        projectViewModel.isDirty = true
                    }
                }
            }

            await MainActor.run { progressHandler(1.0) }

        } catch {
            await MainActor.run {
                progressHandler(1.0)
                projectViewModel.errorAlert = ErrorAlert(
                    error: error,
                    title: "Location Image Generation Failed"
                )
            }
        }
    }

    /// Load the primary image for a location as base64 string for use as reference
    private func loadPrimaryLocationImageAsBase64(for location: Location) -> String? {
        guard let projectPath = projectViewModel.projectPath else { return nil }
        let projectDir = projectPath.deletingLastPathComponent()

        // Try location's stored primary image path first
        if let primaryPath = location.primaryImage {
            let fullPath = projectDir.appendingPathComponent(primaryPath)
            if let imageData = try? Data(contentsOf: fullPath) {
                return imageData.base64EncodedString()
            }
        }

        // Try discovered primary image from filesystem
        let sanitizedName = sanitizeAssetName(location.name)
        let primaryPath = projectDir
            .appendingPathComponent("assets/locations/\(sanitizedName)/primary.png")
        if let imageData = try? Data(contentsOf: primaryPath) {
            return imageData.base64EncodedString()
        }

        return nil
    }
}
struct CinematographyViewAdapter: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var shotsAdapter: ShotsAdapter?

    var body: some View {
        Group {
            if let adapter = shotsAdapter {
                CinematographyView(
                    shots: adapter.allShots,
                    scenes: projectViewModel.allScenes,
                    characters: projectViewModel.project.characters,
                    locations: projectViewModel.project.locations,
                    projectBasePath: projectViewModel.projectPath,
                    initialSelectedShotId: coordinator.selectedShot?.shotId,
                    scrollToShotSection: $coordinator.scrollToShotSection,
                    onShotsChanged: { updatedShots in
                        adapter.updateShots(updatedShots)
                    },
                    onJumpToScriptElement: { itemId, itemType in
                        coordinator.jumpToScriptElement(itemId: itemId, itemType: itemType)
                    },
                    onOptionClickShot: { shot in
                        let parentScene = projectViewModel.allScenes.first { scene in
                            scene.shots.contains { $0.id == shot.id }
                        }
                        coordinator.jumpToScriptForShot(shot, scene: parentScene)
                    },
                    onNavigateToCharacter: { character in
                        coordinator.selectCharacter(character)
                    },
                    onNavigateToLocation: { location in
                        coordinator.selectLocation(location)
                    },
                    onNavigateToStoryDesign: {
                        coordinator.navigateTo(.storyDesign)
                    },
                    onNavigateToCuration: { shot in
                        coordinator.selectShotInCuration(shot)
                    },
                    onSceneUpdated: { updatedScene in
                        // Update the scene in the project model — search ALL sequences
                        for seqIdx in projectViewModel.project.sequences.indices {
                            if let sceneIdx = projectViewModel.project.sequences[seqIdx].scenes.firstIndex(where: { $0.id == updatedScene.id }) {
                                projectViewModel.project.sequences[seqIdx].scenes[sceneIdx] = updatedScene
                                projectViewModel.isDirty = true
                                coordinator.notifyProjectChanged()
                                break
                            }
                        }
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
                        coordinator.notifyProjectChanged()
                    }
                )
            }
        }
        // Refresh adapter when project changes externally (e.g. navigator adds/removes shots)
        .onReceive(coordinator.projectEvents) { event in
            // The adapter mirrors scenes+shots — pure script/production edits
            // don't change the shot projection.
            guard event != .script && event != .production else { return }
            shotsAdapter?.refresh(from: projectViewModel.project)
        }
    }
}
