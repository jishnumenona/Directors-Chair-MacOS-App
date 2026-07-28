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
import DirectorsChairProduction

/// The AssistantKit wire message (distinct from this file's display-side
/// `ChatMessage`, which persists conversations and drives the bubbles).
private typealias KitMessage = DirectorsChairServices.ChatMessage

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    /// Where the reply came from: on-device logic vs a third-party model.
    /// Optional so conversations saved before this field decode unchanged.
    var source: MessageSource?
    /// Story elements with artwork mentioned in the reply — rendered as
    /// thumbnails under the bubble. Optional for the same reason.
    var entityRefs: [EntityRef]?

    init(role: MessageRole, content: String,
         source: MessageSource? = nil,
         entityRefs: [EntityRef]? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.source = source
        self.entityRefs = entityRefs
    }

    enum MessageRole: String, Codable, Equatable {
        case user
        case assistant
        case system
        case toolResult
    }

    /// Provenance of an assistant-produced message.
    enum MessageSource: Codable, Equatable {
        /// Produced by deterministic on-device logic — no AI call at all
        /// (welcome, proactive checks, error notices). Phase L's local
        /// model tier will get its own case when it exists.
        case local
        /// Answered by the routed third-party model ("Gemini", "Claude"…).
        case cloud(provider: String)
    }

    /// A story element referenced in a reply that has an image to show.
    struct EntityRef: Codable, Hashable {
        let kind: String       // "character" | "location" | "scene"
        let name: String
        let imagePath: String  // project-relative (or legacy absolute)
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
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
    @Published var conversations: [ChatConversation] = []

    // AssistantKit turn state (A2.4/A2.5)
    /// Live streamed assistant text for the in-flight turn.
    @Published var streamingText: String = ""
    /// Transient tool-activity chip ("Running get_scene…").
    @Published var toolActivity: String? = nil
    /// Mutating proposals awaiting review (AD5) — drives the TurnPlan card.
    @Published var turnPlan: TurnPlan? = nil
    /// Whether the last applied plan can still be reverted.
    @Published var canUndoAssistantChanges: Bool = false

    /// Whole-project snapshot captured before applying a TurnPlan (AD5).
    private var undoProject: Project?
    /// Tool-fidelity transcript (wire messages, system excluded) — the
    /// model's memory across turns; display `messages` stay human-readable.
    private var kitHistory: [KitMessage] = []

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
        // Resume the most recent conversation so closing the widget never
        // "loses" the thread; New Chat in the sidebar starts fresh.
        if let latest = conversations.first {
            currentConversationId = latest.id
            messages = latest.messages
        } else {
            startNewConversation()
        }
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
            await runAssistantTurn(for: text)
        }
    }

    /// Applies the selected TurnPlan items (AD5): one whole-project snapshot
    /// before, one "Undo" for the whole assistant turn after.
    func applyTurnPlan(selectedIds: Set<String>) {
        guard let plan = turnPlan else { return }
        turnPlan = nil
        let items = plan.items.filter { selectedIds.contains($0.id) }
        guard !items.isEmpty, let pvm = projectViewModel else { return }
        undoProject = pvm.project
        canUndoAssistantChanges = true
        let registry = AssistantActionFactory.makeRegistry(
            projectViewModel: pvm, coordinator: coordinator)
        Task { @MainActor in
            var applied = 0
            for item in items {
                guard let action = registry.action(named: item.actionName) else { continue }
                do {
                    _ = try await action.execute(argumentsData: item.argumentsData)
                    applied += 1
                    // Async video jobs get in-chat progress (A5.4).
                    if item.actionName == "generate_shot_video",
                       let shotNumber = try? JSONDecoder().decode(
                           ShotRef.self, from: item.argumentsData).shot {
                        startVideoJobMonitor(shotNumber: shotNumber)
                    }
                } catch {
                    messages.append(ChatMessage(
                        role: .system,
                        content: "Couldn't apply “\(item.plan.summary)”: \(error.localizedDescription)"))
                }
            }
            messages.append(ChatMessage(
                role: .system,
                content: "Applied \(applied) change\(applied == 1 ? "" : "s") — Undo available"))
            saveCurrentConversation()
        }
    }

    // MARK: - Video job progress (A5.4)

    private struct ShotRef: Decodable { let shot: Int }

    /// Looks up a shot's video-job phase + message; injectable for tests.
    /// Default reads the app-scoped VideoJobCoordinator.
    var videoJobStateLookup: (@MainActor (String) -> (phase: String, message: String)?) = { shotUUID in
        guard let state = AssistantRuntime.shared.videoJobs?.state(forShot: shotUUID) else {
            return nil
        }
        return ("\(state.phase)", state.message)
    }
    /// Poll cadence; shortened by tests.
    var videoMonitorInterval: TimeInterval = 3

    /// Follows a submitted video job and narrates phase changes into the
    /// conversation until it completes, fails, or 20 minutes pass.
    func startVideoJobMonitor(shotNumber: Int) {
        guard let shotUUID = projectViewModel?.project.sequences
            .flatMap(\.scenes).flatMap(\.shots)
            .first(where: { $0.shotId == shotNumber })?.id else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            var lastPhase = ""
            let deadline = Date().addingTimeInterval(20 * 60)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds:
                    UInt64(self.videoMonitorInterval * 1_000_000_000))
                guard let state = self.videoJobStateLookup(shotUUID) else { continue }
                if state.phase != lastPhase {
                    lastPhase = state.phase
                    self.messages.append(ChatMessage(
                        role: .system,
                        content: "🎬 Shot #\(shotNumber): \(state.message)"))
                    if state.phase == "completed" {
                        self.messages.append(ChatMessage(
                            role: .system,
                            content: "Shot #\(shotNumber) video is ready — open Cinematography to play it"))
                        self.saveCurrentConversation()
                        return
                    }
                    if state.phase == "failed" {
                        self.saveCurrentConversation()
                        return
                    }
                }
            }
        }
    }

    /// Declines every remaining proposal in the plan.
    func discardTurnPlan() {
        if let plan = turnPlan {
            messages.append(ChatMessage(
                role: .system,
                content: "Declined \(plan.items.count) proposed change\(plan.items.count == 1 ? "" : "s")"))
        }
        turnPlan = nil
        saveCurrentConversation()
    }

    /// One-tap revert of the last applied assistant turn (AD5).
    func undoAssistantChanges() {
        guard let previous = undoProject, let pvm = projectViewModel else { return }
        pvm.project = previous
        pvm.isDirty = true
        coordinator?.notifyProjectChanged(.general)
        undoProject = nil
        canUndoAssistantChanges = false
        messages.append(ChatMessage(role: .system, content: "Assistant changes reverted"))
        saveCurrentConversation()
    }

    // MARK: - Proactive checks (A6.3, opt-in)

    /// Once per widget-open guard so reopening doesn't repeat findings.
    private var proactiveChecksRan = false

    /// Runs the DETERMINISTIC checkers (no AI, no cost) and posts one
    /// compact heads-up when something needs attention. Opt-in via the
    /// bell in the chat header.
    func runProactiveChecksIfEnabled() {
        guard UserDefaults.standard.bool(forKey: PrefKey.assistantProactiveChecks),
              !proactiveChecksRan,
              let project = projectViewModel?.project else { return }
        proactiveChecksRan = true

        var findings: [String] = []
        if !project.scheduleItems.isEmpty {
            let checker = ScheduleViewModel(scheduleItems: project.scheduleItems)
            checker.detectConflicts()
            if !checker.conflicts.isEmpty {
                findings.append("\(checker.conflicts.count) schedule conflict\(checker.conflicts.count == 1 ? "" : "s")")
            }
        }
        if !project.ganttTasks.isEmpty {
            let checker = GanttViewModel()
            checker.setTasks(project.ganttTasks)
            let problems = checker.validateDependencies()
            if !problems.isEmpty {
                findings.append("\(problems.count) plan dependency problem\(problems.count == 1 ? "" : "s")")
            }
        }
        guard !findings.isEmpty else { return }
        messages.append(ChatMessage(
            role: .system,
            content: "⚠ Heads up: \(findings.joined(separator: " and ")) — ask me for details or fixes."))
    }

    // MARK: - Reply provenance + referenced entities

    /// Display name of the routed third-party chat provider (A6.5 table).
    static func routedProviderDisplayName() -> String {
        switch AssistantRuntime.routedConfiguration().provider {
        case "anthropic": return "Claude"
        case "deepseek": return "DeepSeek"
        default: return "Gemini"
        }
    }

    /// Story elements mentioned in a reply that have artwork: characters,
    /// locations, and scenes matched by whole-word, case-insensitive name.
    /// First-occurrence order, deduped, capped at 4; nil when none match.
    func entityRefs(in text: String) -> [ChatMessage.EntityRef]? {
        guard let project = projectViewModel?.project else { return nil }

        var candidates: [(name: String, kind: String, image: String)] = []
        for character in project.characters {
            if let image = character.avatar ?? character.baseImage
                ?? character.imageFront, !image.isEmpty {
                candidates.append((character.name, "character", image))
            }
        }
        for location in project.locations {
            if let image = location.primaryImage, !image.isEmpty {
                candidates.append((location.name, "location", image))
            }
        }
        for scene in project.sequences.flatMap(\.scenes) {
            if let image = scene.sceneOverviewImage, !image.isEmpty {
                candidates.append((scene.name, "scene", image))
            }
        }

        let lowered = text.lowercased()
        var found: [(position: String.Index, ref: ChatMessage.EntityRef)] = []
        for candidate in candidates where candidate.name.count >= 3 {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: candidate.name.lowercased()))\\b"
            if let range = lowered.range(of: pattern, options: .regularExpression) {
                found.append((range.lowerBound,
                              ChatMessage.EntityRef(kind: candidate.kind,
                                                    name: candidate.name,
                                                    imagePath: candidate.image)))
            }
        }
        guard !found.isEmpty else { return nil }

        var seen = Set<String>()
        var refs: [ChatMessage.EntityRef] = []
        for item in found.sorted(by: { $0.position < $1.position }) {
            if seen.insert("\(item.ref.kind)|\(item.ref.name)").inserted {
                refs.append(item.ref)
            }
            if refs.count == 4 { break }
        }
        return refs
    }

    private func resetTurnState() {
        streamingText = ""
        toolActivity = nil
        turnPlan = nil
        kitHistory = []
        undoProject = nil
        canUndoAssistantChanges = false
    }

    func startNewConversation() {
        saveCurrentConversation()
        let conv = ChatConversation()
        conversations.insert(conv, at: 0)
        currentConversationId = conv.id
        messages = []
        resetTurnState()
    }

    /// Injects a welcome message for first-time users
    func addWelcomeMessageIfNeeded() {
        let key = "hasShownAIChatWelcome"
        guard messages.isEmpty else { return }   // never inject mid-history
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let welcome = """
        **Welcome to Director's Chair!** I'm your AI assistant.

        You can open me anytime by pressing **Shift** twice quickly. Just type your question below and hit Enter — try one of the suggestions to get started!
        """

        messages.append(ChatMessage(role: .assistant, content: welcome,
                                    source: .local))
    }

    func loadConversation(_ conversation: ChatConversation) {
        saveCurrentConversation()
        currentConversationId = conversation.id
        messages = conversation.messages
        resetTurnState()
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

    /// One assistant turn through the AssistantKit engine (A2.5): native
    /// tools via /generate/chat, streamed deltas into `streamingText`,
    /// read-only tools auto-executed, mutating proposals surfaced as a
    /// TurnPlan for approval. The engine and gateway both cap the loop.
    private func runAssistantTurn(for query: String) async {
        let registry = AssistantActionFactory.makeRegistry(
            projectViewModel: projectViewModel, coordinator: coordinator)
        let engine = AssistantRuntime.shared.makeEngine(registry: registry)

        // Vision context (A0.3): the selected entity's image rides as a
        // native image part on the user message.
        var parts: [DirectorsChairServices.ChatContentPart] = [.text(query)]
        var systemPrompt = buildSystemPrompt(query: query)
        if let relativePath = ChatVisionContext.imagePath(for: coordinator?.aiChatContext),
           let projectFile = projectViewModel?.projectPath,
           let imageBase64 = ChatVisionContext.downscaledJPEGBase64(
               at: projectFile.deletingLastPathComponent()
                   .appendingPathComponent(relativePath)) {
            parts.append(.image(base64: imageBase64, mimeType: "image/jpeg"))
            systemPrompt += "\n\nAn image of the user's currently selected item is attached to this message."
        }

        streamingText = ""
        let history = [KitMessage.system(systemPrompt)] + kitHistory

        for await event in await engine.runTurn(history: history,
                                                userMessage: .user(parts)) {
            switch event {
            case .assistantText(let fragment):
                streamingText += fragment
            case .toolStarted(let name):
                toolActivity = "Running \(name)…"
            case .toolFinished(_, let summary):
                toolActivity = nil
                messages.append(ChatMessage(role: .system, content: summary))
            case .turnPlan(let plan):
                turnPlan = plan
            case .finished(let fullText, let transcript):
                if !fullText.isEmpty {
                    messages.append(ChatMessage(
                        role: .assistant, content: fullText,
                        source: .cloud(provider: Self.routedProviderDisplayName()),
                        entityRefs: entityRefs(in: fullText)))
                } else if turnPlan == nil,
                          !messages.contains(where: { $0.role == .system
                              && $0.timestamp > (messages.last { $0.role == .user }?.timestamp ?? .distantPast) }) {
                    // A turn that produced no text, no tools, and no plan is a
                    // protocol failure — say so instead of staying silent.
                    messages.append(ChatMessage(
                        role: .assistant,
                        content: "I didn't receive a response from the assistant service. Please try again.",
                        source: .local))
                }
                // The system prompt is rebuilt fresh each turn — persist the
                // rest as the model's tool-fidelity memory.
                kitHistory = Array(transcript.dropFirst())
            case .failed(let message):
                messages.append(ChatMessage(role: .assistant,
                                            content: "Error: \(message)",
                                            source: .local))
            }
        }

        streamingText = ""
        toolActivity = nil
        isGenerating = false
        saveCurrentConversation()
    }

    // MARK: - System Prompt

    func buildSystemPrompt(query: String) -> String {
        var prompt = """
        You are the Director's Chair AI Assistant — a knowledgeable filmmaking companion.
        A compact PROJECT INDEX below lists what exists; fetch actual content
        with the read tools before answering specifics.

        CAPABILITIES:
        - Answer questions about the project's characters, scenes, shots, budget, schedule
        - Answer questions about the Director's Chair app features
        - Search the web, navigate the app, and select scenes/shots/characters
        - Propose project edits through tools (every change requires user approval)

        TOOLS:
        - Use the provided tools — never write tool syntax as plain text.
        - Read-only tools (web_search, navigate) run immediately; edit and
          generation tools create PROPOSALS the user reviews and approves —
          after proposing, briefly summarize what you proposed and stop.
        - NEVER ask for permission in plain text, even for actions that cost
          money — call the tool directly; the app itself shows the user an
          approval card (with costs) before anything is applied or spent.
          If the user says "yes"/"go ahead" to something you offered, call
          the tool immediately.
        - For update_dialogue, "index" is the [n] each dialogue carries in
          get_scene's result. You may propose several edits in one reply.

        Rules:
        - The PROJECT INDEX below is names and counts ONLY — before answering
          about content (dialogue, schedules, budgets, plans, people), call
          the matching read tool (get_scene, get_schedule, get_budget_summary,
          get_gantt, get_people, get_equipment, list_scenes) and answer from
          its result.
        - Never fabricate project data; if a tool shows something doesn't
          exist, say so.
        - For modifications, always explain what you want to change and why
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
