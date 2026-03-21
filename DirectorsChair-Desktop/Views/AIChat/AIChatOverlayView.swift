//
//  AIChatOverlayView.swift
//  DirectorsChair-Desktop
//
//  Spotlight-style AI Chat overlay
//

import SwiftUI
import AppKit
import DirectorsChairCore

struct AIChatOverlayView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @StateObject private var viewModel = AIChatViewModel()
    @FocusState private var isInputFocused: Bool
    @AppStorage(PrefKey.showAssistantOnLaunch) private var showAssistantOnLaunch: Bool = true

    var body: some View {
        ZStack {
            // Backdrop — subtle darkened blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Chat card
            HStack(spacing: 0) {
                // History sidebar
                if viewModel.showHistory {
                    AIChatHistorySidebar(viewModel: viewModel)
                        .transition(.move(edge: .leading))
                }

                // Main chat area
                VStack(spacing: 0) {
                    // Header
                    chatHeader

                    // Context badge
                    if let ctx = coordinator.aiChatContext {
                        contextBadge(ctx)
                    }

                    Divider()
                        .opacity(0.5)

                    // Messages
                    messageList

                    Divider()
                        .opacity(0.5)

                    // Input area
                    inputArea
                }
                .frame(maxWidth: 720)
            }
            .frame(maxWidth: viewModel.showHistory ? 940 : 720, maxHeight: 600)
            .background(
                ZStack {
                    // Behind-window blur for translucency
                    VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                    // Dark gray tint matching app UI, with transparency
                    Color(nsColor: .controlBackgroundColor).opacity(0.82)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
        }
        .onAppear {
            viewModel.coordinator = coordinator
            viewModel.projectViewModel = projectViewModel
            viewModel.addWelcomeMessageIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onExitCommand {
            dismiss()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showHistory)
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 10) {
            // History toggle
            Button(action: { viewModel.showHistory.toggle() }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.showHistory ? .accentColor : Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Chat History")

            Spacer()

            // Title
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("AI ASSISTANT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }

            Spacer()

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Close (Escape)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Context Badge

    private func contextBadge(_ ctx: AIChatContext) -> some View {
        HStack(spacing: 6) {
            Image(systemName: contextIcon(ctx))
                .font(.system(size: 10))
                .foregroundColor(.accentColor)

            Text(contextLabel(ctx))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func contextIcon(_ ctx: AIChatContext) -> String {
        if ctx.selectedCharacter != nil { return "person.fill" }
        if ctx.selectedScene != nil { return "film" }
        if ctx.selectedShot != nil { return "camera.fill" }
        if ctx.selectedLocation != nil { return "mappin.circle.fill" }
        return ctx.currentView.icon
    }

    private func contextLabel(_ ctx: AIChatContext) -> String {
        if let char = ctx.selectedCharacter { return "Character: \(char.name)" }
        if let scene = ctx.selectedScene { return "Scene: \(scene.name)" }
        if let shot = ctx.selectedShot { return "Shot #\(shot.shotId): \(shot.description.prefix(30))" }
        if let loc = ctx.selectedLocation { return "Location: \(loc.name)" }
        if let tab = ctx.productionTab { return "Production > \(tab)" }
        return ctx.currentView.rawValue
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }

                    ForEach(viewModel.messages) { message in
                        AIChatMessageView(
                            message: message,
                            pendingModification: message == viewModel.messages.last ? viewModel.pendingModification : nil,
                            onApply: { viewModel.applyModification() },
                            onDecline: { viewModel.rejectModification() }
                        )
                        .id(message.id)
                    }

                    // Show suggestions after the welcome message (no user messages yet)
                    if !viewModel.messages.isEmpty && !viewModel.messages.contains(where: { $0.role == .user }) {
                        suggestionsList
                    }

                    if viewModel.isGenerating {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isGenerating) { _, generating in
                if generating {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            suggestionChip("What can you do?")
            suggestionChip("How do I get to the screenplay view?")
            suggestionChip("How can I create a shot in a scene?")
            suggestionChip("Do a psychological evaluation of the main character")
            suggestionChip("Suggest a dad joke for the antagonist")
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 16)

            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.accentColor.opacity(0.5))

            Text("Ask me about your project")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                suggestionChip("What can you do?")
                suggestionChip("How do I get to the screenplay view?")
                suggestionChip("How can I create a shot in a scene?")
                suggestionChip("Do a psychological evaluation of the main character")
                suggestionChip("Suggest a dad joke for the antagonist")
            }

            // Keyboard shortcuts reference
            shortcutsCard

            // Don't show on launch checkbox
            launchToggle
        }
    }

    // MARK: - Keyboard Shortcuts Card

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("KEYBOARD SHORTCUTS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }

            VStack(alignment: .leading, spacing: 3) {
                shortcutRow("AI Assistant", keys: ["\u{21E7}\u{21E7}", "\u{2318}\u{21E7}Space"])
                shortcutRow("Project Overview", keys: ["\u{2318}1"])
                shortcutRow("Bubble View", keys: ["\u{2318}2"])
                shortcutRow("Scenes", keys: ["\u{2318}3"])
                shortcutRow("Assets", keys: ["\u{2318}4"])
                shortcutRow("Vision Board", keys: ["\u{2318}5"])
                shortcutRow("Shot List", keys: ["\u{2318}6"])
                shortcutRow("Production", keys: ["\u{2318}7"])
                shortcutRow("Story Design", keys: ["\u{2318}8"])
                shortcutRow("Settings", keys: ["\u{2318}9"])

                Divider().opacity(0.3).padding(.vertical, 2)

                shortcutRow("Navigator", keys: ["\u{2318}\u{2325}1"])
                shortcutRow("Timeline", keys: ["\u{2318}\u{2325}2"])
                shortcutRow("Right Panel", keys: ["\u{2318}\u{2325}3"])
                shortcutRow("Comments", keys: ["\u{2318}\u{2325}4"])
                shortcutRow("Show All Panels", keys: ["\u{2318}\u{2325}A"])
                shortcutRow("Hide All Panels", keys: ["\u{2318}\u{2325}H"])

                Divider().opacity(0.3).padding(.vertical, 2)

                shortcutRow("New Project", keys: ["\u{2318}N"])
                shortcutRow("Open Project", keys: ["\u{2318}O"])
                shortcutRow("Save", keys: ["\u{2318}S"])
                shortcutRow("Navigate Back", keys: ["\u{2318}["])
                shortcutRow("Navigate Forward", keys: ["\u{2318}]"])
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    private func shortcutRow(_ label: String, keys: [String]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
            }
        }
    }

    // MARK: - Launch Toggle

    private var launchToggle: some View {
        HStack(spacing: 6) {
            Toggle(isOn: Binding(
                get: { !showAssistantOnLaunch },
                set: { showAssistantOnLaunch = !$0 }
            )) {
                Text("Don't show on app launch")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button(action: {
            viewModel.inputText = text
            viewModel.sendMessage()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .labelColor))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 10) {
            TextField("Ask about your project...", text: $viewModel.inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .cornerRadius(10)
                .focused($isInputFocused)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color(nsColor: .tertiaryLabelColor) : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Actions

    private func dismiss() {
        viewModel.saveCurrentConversation()
        coordinator.showingAIChat = false
    }
}

// MARK: - NSVisualEffectView Wrapper for Translucent Backgrounds

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
