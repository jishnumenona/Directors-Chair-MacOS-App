//
// CinematographyView+Description.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Inline Description Editor

struct InlineDescriptionEditor: View {
    let description: String
    let characters: [Character]
    var locations: [Location] = []
    var props: [Prop] = []
    /// The shots this shot keeps continuity with ("&" mentions).
    var continuityShots: [Shot] = []
    /// Project directory — the mentioned things' pictures live under it.
    var projectDirectory: URL? = nil
    /// Owner 2026-08-29: quick jump to the Camera section.
    var onJumpToCamera: (() -> Void)? = nil
    let onDescriptionChange: (String) -> Void

    @State private var editText = ""
    @State private var hasInitialized = false
    @State private var commitTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("Description")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                if let onJumpToCamera {
                    Button(action: onJumpToCamera) {
                        HStack(spacing: 3) {
                            Text("Camera")
                            Image(systemName: "arrow.down")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("Jump to the Camera section")
                    .accessibilityIdentifier("jump-to-camera")
                }
            }

            // Always-editable inline text with @ # $ & mention support
            CharacterMentionTextEditor(
                text: $editText,
                characters: characters,
                locations: locations,
                props: props,
                continuityShots: continuityShots,
                placeholder: "Write a description... (@ character, # location, $ prop, & continuity shot)"
            )

            // What the text mentions, as pictures.
            MentionThumbnailStrip(
                mentions: MentionParser.mentions(in: editText, characters: characters, locations: locations,
                                                 props: props, shots: continuityShots),
                projectDirectory: projectDirectory)
        }
        // The mention list is an overlay — keep this section above the cards
        // stacked after it (owner report 2026-08-29: hidden behind Notes).
        .zIndex(1)
        .onAppear {
            editText = description
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasInitialized = true
            }
        }
        .onChange(of: editText) { _, newValue in
            guard hasInitialized, newValue != description else { return }
            // Debounce the commit to the project model. `editText` is local
            // state so the field itself stays responsive; committing on every
            // keystroke reassigned the whole @Published project and broadcast a
            // global projectChanged (refreshing the timeline/outline/script per
            // character), which made typing lag. Commit ~0.4s after the last
            // keystroke instead.
            commitTask?.cancel()
            let text = newValue
            commitTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                onDescriptionChange(text)
            }
        }
        .onChange(of: description) { _, newValue in
            if newValue != editText {
                editText = newValue
            }
        }
        .onDisappear {
            // Flush any pending edit when leaving the field (e.g. selecting
            // another shot) so a debounced change is never lost.
            commitTask?.cancel()
            if hasInitialized && editText != description {
                onDescriptionChange(editText)
            }
        }
    }
}

// MARK: - Camera in plain English (owner 2026-08-29)

/// A free-text camera direction that joins the preview prompt next to the
/// chips, with a jump back to the description. Local state + debounced
/// commit, like the description editor, so typing never lags.
struct CameraDescriptionEditor: View {
    let text: String
    /// DC-0094: the facts the suggestion is drawn from.
    var shot: Shot? = nil
    var scene: DCScene? = nil
    var locations: [Location] = []
    var characters: [Character] = []
    var onJumpToDescription: (() -> Void)? = nil
    let onChange: (String) -> Void

    @State private var draft = ""
    @State private var hasInitialized = false
    @State private var commitTask: Task<Void, Never>?
    @State private var suggestion: String?
    @State private var isSuggesting = false
    @State private var suggestionFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Camera in your own words")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if shot != nil {
                    Button {
                        if let shot { CameraSuggestion.forget(shot: shot) }
                        fetchSuggestion()
                    } label: {
                        HStack(spacing: 3) {
                            if isSuggesting {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(suggestion == nil ? "Suggest" : "Suggest again")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSuggesting)
                    .help("Ask the AI for a one-line camera direction that fits this shot")
                    .accessibilityIdentifier("camera-suggest")
                }
                if let onJumpToDescription {
                    Button(action: onJumpToDescription) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                            Text("Description")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("Jump back to the description")
                    .accessibilityIdentifier("jump-to-description")
                }
            }
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    hintText
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(minHeight: 48, maxHeight: 96)
                    .accessibilityIdentifier("camera-description")
                    .onKeyPress(.tab) {
                        // Tab takes the suggestion (owner 2026-08-29); otherwise
                        // Tab moves focus as usual.
                        if draft.isEmpty, let suggestion, !suggestion.isEmpty {
                            draft = suggestion
                            return .handled
                        }
                        return .ignored
                    }
            }
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(6)
            if draft.isEmpty, let suggestion, !suggestion.isEmpty {
                HStack(spacing: 6) {
                    Text("Press Tab to use the suggestion")
                        .font(.system(size: 9))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Button("Use it") { draft = suggestion }
                        .font(.system(size: 9, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor.opacity(0.9))
                        .accessibilityIdentifier("camera-suggestion-use")
                }
            }
        }
        .onAppear {
            draft = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { hasInitialized = true }
            if text.isEmpty { fetchSuggestion() }
        }
        .onChange(of: text) { _, newValue in
            if newValue != draft, commitTask == nil { draft = newValue }
        }
        .onChange(of: draft) { _, newValue in
            guard hasInitialized, newValue != text else { return }
            commitTask?.cancel()
            let value = newValue
            commitTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                onChange(value)
                commitTask = nil
            }
        }
    }

    /// The hint: the AI's suggestion when there is one, else what the box is for.
    @ViewBuilder
    private var hintText: some View {
        if let suggestion, !suggestion.isEmpty {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor.opacity(0.7))
                    .padding(.top, 1)
                Text(suggestion)
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.75))
            }
        } else if isSuggesting {
            Text("Thinking about the camera for this shot…")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.4))
        } else {
            Text(suggestionFailed
                 ? "Describe the camera in plain English — this goes into the preview prompt. (No suggestion this time — try Suggest again.)"
                 : "Describe the camera in plain English — this goes into the preview prompt.")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.4))
        }
    }

    private func fetchSuggestion() {
        guard let shot, !isSuggesting else { return }
        isSuggesting = true
        suggestionFailed = false
        let location = scene?.location.flatMap { name in
            locations.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        let cast = scene.map { StoryboardSubjects.cast(for: shot, in: $0, characters: characters) } ?? []
        Task {
            do {
                let line = try await CameraSuggestion.suggest(shot: shot, scene: scene, location: location, characters: cast)
                await MainActor.run {
                    suggestion = line.isEmpty ? nil : line
                    suggestionFailed = line.isEmpty
                    isSuggesting = false
                }
            } catch {
                await MainActor.run {
                    suggestionFailed = true
                    isSuggesting = false
                }
            }
        }
    }
}
