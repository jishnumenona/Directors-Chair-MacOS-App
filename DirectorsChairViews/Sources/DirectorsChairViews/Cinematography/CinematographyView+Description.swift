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
            }

            // Always-editable inline text with @mention support
            CharacterMentionTextEditor(
                text: $editText,
                characters: characters,
                locations: locations,
                props: props,
                placeholder: "Write a description... (@ character, # location, $ prop)"
            )
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
