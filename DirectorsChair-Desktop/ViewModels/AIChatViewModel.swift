//
//  AIChatViewModel.swift
//  DirectorsChair-Desktop
//
//  ViewModel for the AI Chat Assistant overlay
//

import Foundation
import SwiftUI
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    enum MessageRole: String, Codable, Equatable {
        case user
        case assistant
        case system
        case toolResult
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Project Modification

struct ProjectModification: Identifiable {
    let id = UUID()
    let type: String
    let description: String
    let oldValue: String
    let newValue: String
    let reason: String
    let parameters: [String: Any]
}

// MARK: - Conversation

struct ChatConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - ViewModel

@MainActor
class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var showHistory: Bool = false
    /// Modification proposals awaiting review, in arrival order. A single reply
    /// may propose several edits (A0.1); each is approved or declined in turn.
    @Published var pendingModifications: [ProjectModification] = []
    @Published var conversations: [ChatConversation] = []
    @Published var searchResults: [SearchResult] = []

    /// The proposal currently presented for review — the head of the queue.
    var pendingModification: ProjectModification? { pendingModifications.first }

    weak var coordinator: AppCoordinator?
    weak var projectViewModel: ProjectViewModel?

    private var currentConversationId: UUID?
    private let historyDirectory: URL
    private let featureReference: String

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        historyDirectory = appSupport.appendingPathComponent("DirectorsChair/chat_history")
        try? FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)

        // Load feature reference from bundle or generate inline
        featureReference = Self.loadFeatureReference()

        loadConversations()
        startNewConversation()
    }

    // MARK: - Public API

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isGenerating = true

        Task {
            await generateResponse(for: text)
        }
    }

    /// Applies the proposal at the head of the queue; the next one (if any)
    /// becomes the presented card.
    func applyModification() {
        guard !pendingModifications.isEmpty else { return }
        let mod = pendingModifications.removeFirst()
        guard let project = projectViewModel else { return }

        applyProjectChange(mod, projectVM: project)
        messages.append(ChatMessage(role: .system, content: "Applied: \(mod.description)"))
        saveCurrentConversation()
    }

    /// Declines the proposal at the head of the queue.
    func rejectModification() {
        guard !pendingModifications.isEmpty else { return }
        let mod = pendingModifications.removeFirst()
        messages.append(ChatMessage(role: .system, content: "Declined: \(mod.description)"))
        saveCurrentConversation()
    }

    func startNewConversation() {
        saveCurrentConversation()
        let conv = ChatConversation()
        conversations.insert(conv, at: 0)
        currentConversationId = conv.id
        messages = []
        pendingModifications = []
    }

    /// Injects a welcome message for first-time users
    func addWelcomeMessageIfNeeded() {
        let key = "hasShownAIChatWelcome"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let welcome = """
        **Welcome to Director's Chair!** I'm your AI assistant.

        You can open me anytime by pressing **Shift** twice quickly. Just type your question below and hit Enter — try one of the suggestions to get started!
        """

        messages.append(ChatMessage(role: .assistant, content: welcome))
    }

    func loadConversation(_ conversation: ChatConversation) {
        saveCurrentConversation()
        currentConversationId = conversation.id
        messages = conversation.messages
        pendingModifications = []
        showHistory = false
    }

    func deleteConversation(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        let file = historyDirectory.appendingPathComponent("\(conversation.id.uuidString).json")
        try? FileManager.default.removeItem(at: file)
        if currentConversationId == conversation.id {
            startNewConversation()
        }
    }

    // MARK: - AI Response Generation

    private func generateResponse(for query: String) async {
        let aiClient = AIServiceClient.shared

        // Check connection
        guard await aiClient.testConnection() else {
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: "Unable to connect to AI service. Please check that the AI proxy server is running."))
                isGenerating = false
            }
            return
        }

        // Build prompt
        var systemPrompt = buildSystemPrompt(query: query)
        let conversationHistory = buildConversationHistory()
        let fullPrompt = conversationHistory + "\nUser: \(query)"

        // A0.3: attach the selected entity's image (small JPEG) so visual
        // questions are answered about the actual frame, not a description.
        var imageBase64: String? = nil
        if let relativePath = ChatVisionContext.imagePath(for: coordinator?.aiChatContext),
           let projectFile = projectViewModel?.projectPath {
            let imageURL = projectFile.deletingLastPathComponent()
                .appendingPathComponent(relativePath)
            imageBase64 = ChatVisionContext.downscaledJPEGBase64(at: imageURL)
            if imageBase64 != nil {
                systemPrompt += "\n\nAn image of the user's currently selected item is attached to this message."
            }
        }

        let request = TextGenerationRequest(
            prompt: fullPrompt,
            provider: .google,
            maxTokens: 4000,
            temperature: 0.7,
            systemPrompt: systemPrompt,
            imageBase64: imageBase64,
            imageMimeType: "image/jpeg"
        )

        do {
            let response = try await aiClient.generateText(request)
            await handleAIResponse(response.text, originalQuery: query)
        } catch {
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
                isGenerating = false
                saveCurrentConversation()
            }
        }
    }

    // Internal (not private) so the test target can drive the full
    // parse-and-dispatch path without a network round-trip.
    func handleAIResponse(_ text: String, originalQuery: String) async {
        let parsed = ChatToolParser.parse(text)

        // Process tools
        for tool in parsed.tools {
            switch tool.name {
            case "web_search":
                await handleWebSearch(tool, displayText: parsed.displayText, originalQuery: originalQuery)
                return // Web search re-sends to AI with results

            case "modify_project":
                await MainActor.run {
                    handleModifyProject(tool)
                }

            case "navigate":
                await MainActor.run {
                    handleNavigate(tool)
                }

            default:
                break
            }
        }

        // Add assistant message
        await MainActor.run {
            if !parsed.displayText.isEmpty {
                messages.append(ChatMessage(role: .assistant, content: parsed.displayText))
            }
            isGenerating = false
            saveCurrentConversation()
        }
    }

    // MARK: - Tool Handlers

    private func handleWebSearch(_ tool: ToolInvocation, displayText: String, originalQuery: String) async {
        let query = tool.parameters["query"] as? String ?? originalQuery

        await MainActor.run {
            if !displayText.isEmpty {
                messages.append(ChatMessage(role: .assistant, content: displayText))
            }
            messages.append(ChatMessage(role: .system, content: "Searching: \(query)..."))
        }

        let results = await WebSearchClient.shared.search(query: query)

        await MainActor.run {
            self.searchResults = results
        }

        // Format results for AI
        var resultText = "Web search results for \"\(query)\":\n"
        for (i, result) in results.enumerated() {
            resultText += "\(i + 1). \(result.title)\n   \(result.url)\n   \(result.snippet)\n\n"
        }

        await MainActor.run {
            messages.append(ChatMessage(role: .toolResult, content: resultText))
        }

        // Re-send to AI with search results
        let followUpPrompt = """
        The user asked: \(originalQuery)

        Here are the web search results:
        \(resultText)

        Please synthesize these search results into a helpful answer for the user. Be concise and cite relevant sources.
        """

        let request = TextGenerationRequest(
            prompt: followUpPrompt,
            provider: .google,
            maxTokens: 4000,
            temperature: 0.7,
            systemPrompt: buildSystemPrompt(query: originalQuery)
        )

        do {
            let response = try await AIServiceClient.shared.generateText(request)
            let cleanText = ChatToolParser.parse(response.text).displayText
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: cleanText))
                isGenerating = false
                saveCurrentConversation()
            }
        } catch {
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: "Could not process search results: \(error.localizedDescription)"))
                isGenerating = false
                saveCurrentConversation()
            }
        }
    }

    func handleModifyProject(_ tool: ToolInvocation) {
        let type = tool.parameters["type"] as? String ?? "unknown"
        let reason = tool.parameters["reason"] as? String ?? ""
        let field = tool.parameters["field"] as? String ?? ""
        let character = tool.parameters["character"] as? String
        let scene = tool.parameters["scene"] as? String

        // Build description
        var desc = type.replacingOccurrences(of: "_", with: " ").capitalized
        if let char = character { desc += " for \(char)" }
        if let sc = scene { desc += " in \(sc)" }
        if !field.isEmpty { desc += ": \(field)" }

        // Get old value
        let oldValue = getCurrentValue(type: type, params: tool.parameters)
        let newValue: String
        if let val = tool.parameters["value"] {
            newValue = "\(val)"
        } else {
            newValue = tool.parameters["text"] as? String ?? "—"
        }

        pendingModifications.append(ProjectModification(
            type: type,
            description: desc,
            oldValue: oldValue,
            newValue: newValue,
            reason: reason,
            parameters: tool.parameters
        ))
    }

    func handleNavigate(_ tool: ToolInvocation) {
        guard let viewName = tool.parameters["view"] as? String else { return }

        // A0.2: the complete section map (all 13 AppView destinations).
        let viewMap: [String: AppView] = [
            "overview": .overview, "script": .script, "bubble": .bubble,
            "scenes": .scenes, "assets": .assets, "visionBoard": .visionBoard,
            "shotList": .shotList, "production": .production,
            "storyDesign": .storyDesign, "curation": .curation,
            "playback": .playback, "settings": .settings, "projects": .projects
        ]

        if let view = viewMap[viewName] {
            coordinator?.navigateTo(view)

            // Production sub-tab (accepts common aliases, maps to canonical).
            if let tab = tool.parameters["production_tab"] as? String {
                let canonical: [String: String] = [
                    "schedule": "Schedule", "gantt": "Gantt",
                    "cast & crew": "Cast & Crew", "cast and crew": "Cast & Crew",
                    "cast": "Cast & Crew", "crew": "Cast & Crew",
                    "accounting": "Accounting", "budget": "Accounting",
                    "equipment": "Equipment"
                ]
                if let resolved = canonical[tab.lowercased()] {
                    coordinator?.selectedProductionTab = resolved
                }
            }

            // Entity sub-selection. Unknown names are a silent no-op — the
            // view switch above still happened, which is the safe outcome.
            if let charName = tool.parameters["character"] as? String,
               let char = projectViewModel?.project.characters.first(where: { $0.name == charName }) {
                coordinator?.selectCharacter(char)
            }
            let allScenes = projectViewModel?.project.sequences.flatMap(\.scenes) ?? []
            if let sceneName = tool.parameters["scene"] as? String,
               let scene = allScenes.first(where: { $0.name == sceneName }) {
                coordinator?.selectScene(scene)
            }
            if let sequenceName = tool.parameters["sequence"] as? String,
               let sequence = projectViewModel?.project.sequences.first(where: { $0.name == sequenceName }) {
                coordinator?.selectSequence(sequence)
            }
            if let locationName = tool.parameters["location"] as? String,
               let location = projectViewModel?.project.locations.first(where: { $0.name == locationName }) {
                coordinator?.selectLocation(location)
            }
            if let shotNumber = tool.parameters["shot"] as? Int,
               let shot = allScenes.flatMap(\.shots).first(where: { $0.shotId == shotNumber }) {
                coordinator?.selectShot(shot)
            }
        }
    }

    // MARK: - Project Modification Application

    func applyProjectChange(_ mod: ProjectModification, projectVM: ProjectViewModel) {
        switch mod.type {
        case "update_character_trait":
            guard let charName = mod.parameters["character"] as? String,
                  let field = mod.parameters["field"] as? String,
                  let value = mod.parameters["value"] as? Double,
                  let idx = projectVM.project.characters.firstIndex(where: { $0.name == charName }) else { return }
            projectVM.project.characters[idx].traits[field] = value
            projectVM.isDirty = true

        case "update_character_bio":
            guard let charName = mod.parameters["character"] as? String,
                  let field = mod.parameters["field"] as? String,
                  let value = mod.parameters["value"] as? String ?? mod.parameters["text"] as? String,
                  let idx = projectVM.project.characters.firstIndex(where: { $0.name == charName }) else { return }
            switch field {
            case "occupation": projectVM.project.characters[idx].occupation = value
            case "primaryGoal", "goal": projectVM.project.characters[idx].primaryGoal = value
            case "primaryFear", "fear": projectVM.project.characters[idx].primaryFear = value
            case "backstory", "backgroundStory": projectVM.project.characters[idx].backgroundStory = value
            case "about": projectVM.project.characters[idx].about = value
            default: break
            }
            projectVM.isDirty = true

        case "update_scene_description":
            guard let sceneName = mod.parameters["scene"] as? String,
                  let text = mod.parameters["text"] as? String ?? mod.parameters["value"] as? String else { return }
            for seqIdx in projectVM.project.sequences.indices {
                if let scIdx = projectVM.project.sequences[seqIdx].scenes.firstIndex(where: { $0.name == sceneName }) {
                    projectVM.project.sequences[seqIdx].scenes[scIdx].description = text
                    projectVM.isDirty = true
                    return
                }
            }

        case "update_dialogue":
            guard let text = mod.parameters["text"] as? String else { return }
            // Preferred addressing: scene name + the [index] shown beside each
            // dialogue in PROJECT DATA (A0.1 — the model never sees UUIDs).
            if let sceneName = mod.parameters["scene"] as? String,
               let index = mod.parameters["index"] as? Int {
                for seqIdx in projectVM.project.sequences.indices {
                    if let scIdx = projectVM.project.sequences[seqIdx].scenes.firstIndex(where: { $0.name == sceneName }) {
                        guard projectVM.project.sequences[seqIdx].scenes[scIdx].dialogues.indices.contains(index) else { return }
                        projectVM.project.sequences[seqIdx].scenes[scIdx].dialogues[index].text = text
                        projectVM.isDirty = true
                        return
                    }
                }
                return
            }
            // Legacy addressing by dialogue UUID (kept for compatibility).
            guard let dialogueId = mod.parameters["dialogueId"] as? String else { return }
            for seqIdx in projectVM.project.sequences.indices {
                for scIdx in projectVM.project.sequences[seqIdx].scenes.indices {
                    if let dlgIdx = projectVM.project.sequences[seqIdx].scenes[scIdx].dialogues.firstIndex(where: { $0.uuid == dialogueId }) {
                        projectVM.project.sequences[seqIdx].scenes[scIdx].dialogues[dlgIdx].text = text
                        projectVM.isDirty = true
                        return
                    }
                }
            }

        case "update_project_metadata":
            guard let field = mod.parameters["field"] as? String,
                  let value = mod.parameters["value"] as? String else { return }
            switch field {
            case "genre": projectVM.project.genre = value
            case "status": projectVM.project.status = value
            case "tagline": projectVM.project.overviewTagline = value
            case "logline": projectVM.project.overviewLogline = value
            case "description": projectVM.project.description = value
            default: break
            }
            projectVM.isDirty = true

        case "add_relationship":
            guard let charName = mod.parameters["character"] as? String,
                  let targetChar = mod.parameters["target"] as? String,
                  let relationship = mod.parameters["relationship"] as? String,
                  let idx = projectVM.project.characters.firstIndex(where: { $0.name == charName }) else { return }
            if projectVM.project.characters[idx].relationships == nil {
                projectVM.project.characters[idx].relationships = [:]
            }
            projectVM.project.characters[idx].relationships?[targetChar] = relationship
            projectVM.isDirty = true

        default:
            break
        }
    }

    func getCurrentValue(type: String, params: [String: Any]) -> String {
        guard let project = projectViewModel?.project else { return "—" }

        switch type {
        case "update_scene_description":
            if let sceneName = params["scene"] as? String,
               let scene = project.sequences.flatMap(\.scenes).first(where: { $0.name == sceneName }) {
                return String(scene.description.prefix(100))
            }
        case "update_dialogue":
            if let sceneName = params["scene"] as? String,
               let index = params["index"] as? Int,
               let scene = project.sequences.flatMap(\.scenes).first(where: { $0.name == sceneName }),
               scene.dialogues.indices.contains(index) {
                return String(scene.dialogues[index].text.prefix(100))
            }
            if let dialogueId = params["dialogueId"] as? String,
               let dialogue = project.sequences.flatMap(\.scenes).flatMap(\.dialogues)
                   .first(where: { $0.uuid == dialogueId }) {
                return String(dialogue.text.prefix(100))
            }
        case "add_relationship":
            if let charName = params["character"] as? String,
               let target = params["target"] as? String,
               let char = project.characters.first(where: { $0.name == charName }) {
                return char.relationships?[target] ?? "—"
            }
        case "update_character_trait":
            if let charName = params["character"] as? String,
               let field = params["field"] as? String,
               let char = project.characters.first(where: { $0.name == charName }) {
                return "\(Int(char.traits[field] ?? 0))"
            }
        case "update_character_bio":
            if let charName = params["character"] as? String,
               let field = params["field"] as? String,
               let char = project.characters.first(where: { $0.name == charName }) {
                switch field {
                case "occupation": return char.occupation ?? "—"
                case "primaryGoal", "goal": return char.primaryGoal ?? "—"
                case "primaryFear", "fear": return char.primaryFear ?? "—"
                case "backstory", "backgroundStory": return String((char.backgroundStory ?? "—").prefix(100))
                case "about": return String(char.about.prefix(100))
                default: return "—"
                }
            }
        case "update_project_metadata":
            if let field = params["field"] as? String {
                switch field {
                case "genre": return project.genre
                case "status": return project.status
                case "tagline": return project.overviewTagline
                case "logline": return project.overviewLogline
                default: return "—"
                }
            }
        default:
            break
        }
        return "—"
    }

    // MARK: - System Prompt

    func buildSystemPrompt(query: String) -> String {
        var prompt = """
        You are the Director's Chair AI Assistant — a knowledgeable filmmaking companion.
        You have full access to the user's project data shown below.

        CAPABILITIES:
        - Answer questions about the project's characters, scenes, shots, budget, schedule
        - Answer questions about the Director's Chair app features
        - Search the web for filmmaking knowledge
        - Suggest project modifications (changes require user approval)
        - Navigate the app and select scenes, shots, characters, sequences, or locations

        TOOL FORMAT (use when needed):
        [TOOL:web_search]{"query": "search terms"}[/TOOL]
        [TOOL:modify_project]{"type": "update_character_trait", "character": "Name", "field": "confidence", "value": 75, "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "update_character_bio", "character": "Name", "field": "occupation", "value": "Detective", "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "update_scene_description", "scene": "Scene Name", "text": "New description", "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "update_dialogue", "scene": "Scene Name", "index": 0, "text": "New line", "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "update_project_metadata", "field": "genre", "value": "Neo-Noir", "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "add_relationship", "character": "Name", "target": "Other Character", "relationship": "Estranged mentor", "reason": "..."}[/TOOL]
        [TOOL:navigate]{"view": "shotList", "shot": 12}[/TOOL]

        Tool notes:
        - update_dialogue "index" is the [n] shown beside that dialogue in PROJECT DATA.
        - You may propose SEVERAL modify_project tools in one reply; the user approves each in turn.
        - navigate "view" is one of: overview, script, bubble, scenes, assets, visionBoard,
          shotList, production, storyDesign, curation, playback, settings, projects.
          Optional selectors: "scene", "character", "sequence", "location" (names),
          "shot" (the shot number), and "production_tab"
          (Schedule | Gantt | Cast & Crew | Accounting | Equipment).

        Rules:
        - Only reference data that appears in the PROJECT DATA section below
        - For modifications, always explain what you want to change and why
        - Never fabricate project data that isn't provided
        - Be concise and specific to filmmaking
        - If the user asks about app features, reference the FEATURE GUIDE below

        """

        // Add project context
        if let project = projectViewModel?.project {
            let context = ProjectContextBuilder.buildContext(
                project: project,
                context: coordinator?.aiChatContext,
                query: query
            )
            prompt += "\n\n" + context
        }

        // Always include feature reference so the assistant knows what the app can do
        prompt += "\n\n--- FEATURE GUIDE ---\n" + featureReference

        return prompt
    }

    private func buildConversationHistory() -> String {
        let recentMessages = messages.suffix(10)
        var history = ""
        for msg in recentMessages {
            switch msg.role {
            case .user:
                history += "User: \(msg.content)\n"
            case .assistant:
                history += "Assistant: \(msg.content)\n"
            case .system:
                history += "[System: \(msg.content)]\n"
            case .toolResult:
                history += "[Tool Result: \(String(msg.content.prefix(200)))]\n"
            }
        }
        return history
    }

    // MARK: - Persistence

    func saveCurrentConversation() {
        guard let convId = currentConversationId,
              let idx = conversations.firstIndex(where: { $0.id == convId }),
              !messages.isEmpty else { return }

        conversations[idx].messages = messages
        conversations[idx].updatedAt = Date()

        // Set title from first user message
        if conversations[idx].title == "New Chat",
           let firstUserMsg = messages.first(where: { $0.role == .user }) {
            conversations[idx].title = String(firstUserMsg.content.prefix(50))
        }

        // Save to disk
        let file = historyDirectory.appendingPathComponent("\(convId.uuidString).json")
        if let data = try? JSONEncoder().encode(conversations[idx]) {
            try? data.write(to: file)
        }
    }

    private func loadConversations() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: nil) else { return }

        var loaded: [ChatConversation] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let conv = try? JSONDecoder().decode(ChatConversation.self, from: data) {
                loaded.append(conv)
            }
        }

        conversations = loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Feature Reference

    private static func loadFeatureReference() -> String {
        """
        Director's Chair is a comprehensive filmmaking project management app for macOS.

        VIEWS (Cmd+1-9):
        - Overview (Cmd+1): Project pitch deck with poster, summary, mood analysis
        - Bubble View (Cmd+2): Visual script editing with dialogue bubbles, actions, narrations
        - Scenes (Cmd+3): Scene list with detail panels, location images
        - Assets (Cmd+4): Media library with images, videos, audio
        - Vision Board (Cmd+5): Drag-and-drop mood board cards
        - Shot List / Cinematography (Cmd+6): Camera angles, lens, movement, shot detail with video generation
        - Production (Cmd+7): Schedule, Cast & Crew, Accounting, Equipment tabs
        - Story Design (Cmd+8): Character profiles (traits, appearance, costumes, biography), Locations
        - Settings (Cmd+9): Project metadata configuration

        PANELS:
        - Navigator (Cmd+Opt+1): Left sidebar with Outline, Markers, Versions, Comments tabs
        - Timeline (Cmd+Opt+2): Bottom timeline with drag-to-reorder segments, playhead, markers
        - Right Panel (Cmd+Opt+3): Context-dependent detail panel

        KEY FEATURES:
        - Script View: Professional formatted screenplay with scene headings, dialogue, action, Cmd+Click character navigation
        - Timeline: Visual timeline with segments per scene, drag-to-reorder shots, playhead cursor, custom markers
        - Scene Connections: Bezier curves linking script items to camera shots
        - Character Design: 25 personality traits across 5 categories, physical appearance, costumes, relationships
        - Budget tracking with receipt scanning and AI-powered analysis
        - Equipment library with allocation to schedule items
        - Export to FDX (Final Draft), Fountain, HTML, PDF

        AI CAPABILITIES (the app HAS these features):
        - AI Chat Assistant: Double-Shift or Cmd+Shift+Space to open. Ask questions about the project, get suggestions, search the web
        - AI Image Generation: Generate keyframe images for shots using Google Imagen. Found in Shot List > select a shot > Video Generation > Keyframes > Generate
        - AI Video Generation: Generate videos from keyframes using Veo 3, Sora 2, or Kling. Found in Shot List > select a shot > Video Generation section
        - Keyframe Annotation & Edit: Click the pencil icon on a generated keyframe to open the annotation overlay. Place pins on the image, describe changes, and regenerate with spatial edit instructions
        - AI Character Analysis: Generate character biographies, personality insights, and profile images
        - AI Screenplay Import: Import screenplays from text/PDF with AI-powered 5-pass parsing (metadata, characters, props/locations, scene list, scene contents)
        - AI-powered scene generation and project creation from scratch

        VIDEO GENERATION WORKFLOW:
        1. Go to Shot List (Cmd+6) and select a shot
        2. In the Video Generation section, configure keyframes (Start/End frames)
        3. Click "Generate" on a keyframe to create an AI-generated image for that frame
        4. Optionally use the annotation editor (pencil icon) to refine keyframe images with point-and-click edits
        5. Choose a video provider (Veo 3, Sora 2, Kling), set duration, quality, aspect ratio, camera motion
        6. Click "Generate Video" to create the video from keyframes
        7. Multiple takes are saved and can be compared in the Video Takes section

        KEYBOARD SHORTCUTS:
        - Cmd+[ / Cmd+]: Navigate back/forward
        - Cmd+Opt+A: Show all panels | Cmd+Opt+H: Hide all panels
        - Cmd+Shift+Space: AI Chat Assistant
        - Double-Shift: AI Chat Assistant (quick toggle)
        - Cmd+Shift+N: New scene (in script view)
        """
    }
}
