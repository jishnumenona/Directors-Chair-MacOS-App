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
    @Published var pendingModification: ProjectModification? = nil
    @Published var conversations: [ChatConversation] = []
    @Published var searchResults: [SearchResult] = []

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

    func applyModification() {
        guard let mod = pendingModification,
              let project = projectViewModel else {
            pendingModification = nil
            return
        }

        applyProjectChange(mod, projectVM: project)
        messages.append(ChatMessage(role: .system, content: "Applied: \(mod.description)"))
        pendingModification = nil
        saveCurrentConversation()
    }

    func rejectModification() {
        if let mod = pendingModification {
            messages.append(ChatMessage(role: .system, content: "Declined: \(mod.description)"))
        }
        pendingModification = nil
        saveCurrentConversation()
    }

    func startNewConversation() {
        saveCurrentConversation()
        let conv = ChatConversation()
        conversations.insert(conv, at: 0)
        currentConversationId = conv.id
        messages = []
    }

    func loadConversation(_ conversation: ChatConversation) {
        saveCurrentConversation()
        currentConversationId = conversation.id
        messages = conversation.messages
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
        let systemPrompt = buildSystemPrompt(query: query)
        let conversationHistory = buildConversationHistory()
        let fullPrompt = conversationHistory + "\nUser: \(query)"

        let request = TextGenerationRequest(
            prompt: fullPrompt,
            provider: .google,
            maxTokens: 4000,
            temperature: 0.7,
            systemPrompt: systemPrompt
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

    private func handleAIResponse(_ text: String, originalQuery: String) async {
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

    private func handleModifyProject(_ tool: ToolInvocation) {
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

        pendingModification = ProjectModification(
            type: type,
            description: desc,
            oldValue: oldValue,
            newValue: newValue,
            reason: reason,
            parameters: tool.parameters
        )
    }

    private func handleNavigate(_ tool: ToolInvocation) {
        guard let viewName = tool.parameters["view"] as? String else { return }

        let viewMap: [String: AppView] = [
            "overview": .overview, "script": .script, "bubble": .bubble,
            "scenes": .scenes, "assets": .assets, "visionBoard": .visionBoard,
            "shotList": .shotList, "production": .production,
            "storyDesign": .storyDesign, "settings": .settings
        ]

        if let view = viewMap[viewName] {
            coordinator?.navigateTo(view)

            // Handle sub-navigation
            if let charName = tool.parameters["character"] as? String,
               let char = projectViewModel?.project.characters.first(where: { $0.name == charName }) {
                coordinator?.selectCharacter(char)
            }
            if let sceneName = tool.parameters["scene"] as? String {
                let allScenes = projectViewModel?.project.sequences.flatMap(\.scenes) ?? []
                if let scene = allScenes.first(where: { $0.name == sceneName }) {
                    coordinator?.selectScene(scene)
                }
            }
        }
    }

    // MARK: - Project Modification Application

    private func applyProjectChange(_ mod: ProjectModification, projectVM: ProjectViewModel) {
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
            guard let dialogueId = mod.parameters["dialogueId"] as? String,
                  let text = mod.parameters["text"] as? String else { return }
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

    private func getCurrentValue(type: String, params: [String: Any]) -> String {
        guard let project = projectViewModel?.project else { return "—" }

        switch type {
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

    private func buildSystemPrompt(query: String) -> String {
        var prompt = """
        You are the Director's Chair AI Assistant — a knowledgeable filmmaking companion.
        You have full access to the user's project data shown below.

        CAPABILITIES:
        - Answer questions about the project's characters, scenes, shots, budget, schedule
        - Answer questions about the Director's Chair app features
        - Search the web for filmmaking knowledge
        - Suggest project modifications (changes require user approval)

        TOOL FORMAT (use when needed):
        [TOOL:web_search]{"query": "search terms"}[/TOOL]
        [TOOL:modify_project]{"type": "update_character_trait", "character": "Name", "field": "confidence", "value": 75, "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "update_character_bio", "character": "Name", "field": "occupation", "value": "Detective", "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "update_scene_description", "scene": "Scene Name", "text": "New description", "reason": "..."}[/TOOL]
        [TOOL:modify_project]{"type": "update_project_metadata", "field": "genre", "value": "Neo-Noir", "reason": "..."}[/TOOL]
        [TOOL:navigate]{"view": "storyDesign", "character": "Name"}[/TOOL]

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
