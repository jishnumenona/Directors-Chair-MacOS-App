//
// BubbleView+Mutations.swift
//
// Extracted from BubbleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import UniformTypeIdentifiers
import AVFoundation

extension BubbleView {

    // MARK: - Actions

    func updateDialogue(_ updated: Dialogue) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
              let dialogueIndex = project.sequences[seqIndex].scenes[sceneIndex].dialogues.firstIndex(where: { $0.id == updated.id })
        else { return }

        project.sequences[seqIndex].scenes[sceneIndex].dialogues[dialogueIndex] = updated

        // Update selected scene reference
        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        onContentChanged?()
    }

    /// Scroll to a newly added item after a brief delay for the view to settle
    func scrollToNewItem(_ itemId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToItemId = itemId
        }
    }

    func addDialogue(for characterName: String) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newDialogue = Dialogue(
            character: characterName,
            text: "",
            chronologyNumber: maxChronology + 1
        )

        // Find and update scene in project
        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].dialogues.append(newDialogue)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newDialogue.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newDialogue.id)
            onContentChanged?()
        }
    }

    func deleteDialogue(_ dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].dialogues.removeAll { $0.id == dialogue.id }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]

            // Clear selection if deleted dialogue was selected
            if selectedDialogue?.id == dialogue.id {
                selectedDialogue = nil
            }

            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func addAction() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newAction = Action(
            uuid: UUID().uuidString,
            description: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: []
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions.append(newAction)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newAction.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newAction.id)
            onContentChanged?()
        }
    }

    func addNarration() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNarration = Narration(
            uuid: UUID().uuidString,
            text: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: []
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations.append(newNarration)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNarration.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newNarration.id)
            onContentChanged?()
        }
    }

    func addNote() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNote = Note(
            uuid: UUID().uuidString,
            content: "",
            noteType: "text",
            chronologyNumber: maxChronology + 1
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.append(newNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newNote.id)
            onContentChanged?()
        }
    }

    func addSoundNote() {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newSoundNote = SoundNote(
            uuid: UUID().uuidString,
            description: "",
            soundType: "ambient",
            chronologyNumber: maxChronology + 1
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes.append(newSoundNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newSoundNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(newSoundNote.id)
            onContentChanged?()
        }
    }

    // MARK: - Add Connected Items (directly to a dialogue)

    func addConnectedAction(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newAction = Action(
            uuid: UUID().uuidString,
            description: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: [],
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions.append(newAction)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newAction.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    func addConnectedNarration(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNarration = Narration(
            uuid: UUID().uuidString,
            text: "",
            tags: [],
            costumes: [],
            effects: [],
            color: "",
            textColor: "",
            chronologyNumber: maxChronology + 1,
            globalChronologyNumber: maxChronology + 1,
            characters: [],
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations.append(newNarration)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNarration.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    func addConnectedNote(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newNote = Note(
            uuid: UUID().uuidString,
            content: "",
            noteType: "text",
            chronologyNumber: maxChronology + 1,
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.append(newNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    func addConnectedSoundNote(to dialogue: Dialogue) {
        guard let scene = selectedScene else { return }

        let maxChronology = globalMaxChronology()

        let newSoundNote = SoundNote(
            uuid: UUID().uuidString,
            description: "",
            soundType: "ambient",
            chronologyNumber: maxChronology + 1,
            parentDialogueId: dialogue.id
        )

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes.append(newSoundNote)
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            newlyAddedItemId = newSoundNote.id
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            sortRefreshTrigger = UUID()
            scrollToNewItem(dialogue.id)
            onContentChanged?()
        }
    }

    func editAction(_ action: Action) {
        editingAction = action
    }

    func deleteAction(_ action: Action) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions.removeAll { $0.uuid == action.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func editNarration(_ narration: Narration) {
        editingNarration = narration
    }

    func deleteNarration(_ narration: Narration) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations.removeAll { $0.uuid == narration.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func editNote(_ note: Note) {
        editingNote = note
    }

    func deleteNote(_ note: Note) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.removeAll { $0.uuid == note.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func editSoundNote(_ soundNote: SoundNote) {
        editingSoundNote = soundNote
    }

    func deleteSoundNote(_ soundNote: SoundNote) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes.removeAll { $0.uuid == soundNote.uuid }
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func updateAction(_ updated: Action) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let actionIndex = project.sequences[seqIndex].scenes[sceneIndex].actions.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].actions[actionIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func updateNarration(_ updated: Narration) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let narrationIndex = project.sequences[seqIndex].scenes[sceneIndex].narrations.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].narrations[narrationIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func updateNote(_ updated: Note) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let noteIndex = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[noteIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func updateSoundNote(_ updated: SoundNote) {
        guard let scene = selectedScene else { return }

        if let seqIndex = project.sequences.firstIndex(where: { seq in
            seq.scenes.contains { $0.id == scene.id }
        }),
           let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
           let soundNoteIndex = project.sequences[seqIndex].scenes[sceneIndex].soundNotes.firstIndex(where: { $0.uuid == updated.uuid }) {

            project.sequences[seqIndex].scenes[sceneIndex].soundNotes[soundNoteIndex] = updated
            selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
            rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
            onContentChanged?()
        }
    }

    func playSoundNote(_ soundNote: SoundNote) {
        // TODO: Implement via TTS service
    }

    func playDialogue(_ dialogue: Dialogue) {
        // If audio file exists on disk, play it
        if let audioPath = dialogue.audioFilePath,
           let basePath = projectBasePath {
            let fileURL = basePath.appendingPathComponent(audioPath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    stopDialogue()
                    audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                    audioPlayer?.delegate = BubbleAudioDelegate.shared
                    BubbleAudioDelegate.shared.onFinished = { [weak audioPlayer] in
                        if audioPlayer != nil {
                            playingDialogueId = nil
                        }
                    }
                    audioPlayer?.play()
                    playingDialogueId = dialogue.id
                } catch {
                    debugLog("Error playing dialogue audio: \(error)")
                }
                return
            }
        }
        // No saved audio — generate it
        Task { await generateAndPlayDialogue(dialogue) }
    }

    func stopDialogue() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingDialogueId = nil
    }

    func generateAndPlayDialogue(_ dialogue: Dialogue) async {
        let dialogueId = dialogue.id
        generatingAudioIds.insert(dialogueId)

        do {
            // Look up character voice
            let character = cachedCharacterMap[dialogue.character]
            let voiceName = character?.voice ?? (character?.gender.lowercased() == "female" ? "Kore" : "Charon")

            // Build emotion from voiceStyle + tags
            var emotionParts: [String] = []
            if let style = character?.voiceStyle, !style.isEmpty {
                emotionParts.append(style)
            }
            if !dialogue.tags.isEmpty {
                emotionParts.append(contentsOf: dialogue.tags)
            }
            let emotion = emotionParts.isEmpty ? nil : "Say \(emotionParts.joined(separator: ", "))"

            // Strip HTML from dialogue text
            var text = dialogue.text
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<") {
                let tagPattern = "<[^>]+>"
                if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                    let range = NSRange(location: 0, length: text.utf16.count)
                    text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            let request = SpeechGenerationRequest(
                text: text,
                provider: .google,
                voiceName: voiceName,
                emotion: emotion,
                characterName: dialogue.character,
                voiceTone: character?.voiceTone,
                voicePersonality: character?.voicePersonality,
                voicePace: character?.voicePace,
                voiceAccent: character?.voiceAccent,
                voiceAge: character?.voiceAge
            )

            let response = try await AIServiceClient.shared.generateSpeech(request)

            // Save audio file
            if let basePath = projectBasePath {
                let audioDir = basePath.appendingPathComponent("assets/audio/dialogues")
                try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

                let fileName = "\(dialogueId).wav"
                let filePath = audioDir.appendingPathComponent(fileName)
                try response.audioData.write(to: filePath)

                // Update dialogue with audio path
                var updated = dialogue
                updated.audioFilePath = "assets/audio/dialogues/\(fileName)"
                updateDialogue(updated)
            }

            // Play the audio
            stopDialogue()
            audioPlayer = try AVAudioPlayer(data: response.audioData)
            audioPlayer?.delegate = BubbleAudioDelegate.shared
            BubbleAudioDelegate.shared.onFinished = { [weak audioPlayer] in
                if audioPlayer != nil {
                    playingDialogueId = nil
                }
            }
            audioPlayer?.play()
            playingDialogueId = dialogueId

        } catch {
            debugLog("Error generating dialogue audio: \(error)")
            audioErrorMessage = error.localizedDescription
        }

        generatingAudioIds.remove(dialogueId)
    }

    // MARK: - Emotion Detection

    func detectDialogueEmotion(_ dialogue: Dialogue) async {
        let dialogueId = dialogue.id
        detectingEmotionIds.insert(dialogueId)

        do {
            // Strip HTML from text
            var text = dialogue.text
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<") {
                let tagPattern = "<[^>]+>"
                if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                    let range = NSRange(location: 0, length: text.utf16.count)
                    text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            guard !text.isEmpty else {
                detectingEmotionIds.remove(dialogueId)
                return
            }

            let characterName = dialogue.character
            let prompt = """
            Analyze the emotion/tone of this dialogue line spoken by \(characterName):

            "\(text)"

            Return ONLY a comma-separated list of 1-3 emotion tags (single words, lowercase).
            Examples: angry, sarcastic, tender, fearful, joyful, melancholic, anxious, determined, playful, bitter, hopeful, resigned, threatening, pleading, nostalgic, disgusted, confused, amused, defiant, vulnerable
            Do not include any other text, explanation, or formatting.
            """

            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 50,
                temperature: 0.3
            )

            let response = try await AIServiceClient.shared.generateText(request)
            let emotionText = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let tags = emotionText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count < 20 }

            if !tags.isEmpty {
                var updated = dialogue
                updated.tags = tags
                updateDialogue(updated)
            }
        } catch {
            debugLog("Error detecting dialogue emotion: \(error)")
        }

        detectingEmotionIds.remove(dialogueId)
    }

    // MARK: - Handle Drop

    /// Handles the drop of a dragged item onto a dialogue
    func handleDrop(providers: [NSItemProvider], dialogueId: String) -> Bool {
        guard let provider = providers.first else { return false }

        // Try to load as plain text (our encoded format)
        if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, error in
                DispatchQueue.main.async {
                    if let data = data as? Data, let encoded = String(data: data, encoding: .utf8),
                       let dragData = BubbleItemDragData.decode(encoded) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    } else if let string = data as? String,
                              let dragData = BubbleItemDragData.decode(string) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    }
                }
            }
            return true
        }

        // Try loading as UTF8 text
        if provider.hasItemConformingToTypeIdentifier("public.utf8-plain-text") {
            provider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { data, error in
                DispatchQueue.main.async {
                    if let data = data as? Data, let encoded = String(data: data, encoding: .utf8),
                       let dragData = BubbleItemDragData.decode(encoded) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    } else if let string = data as? String,
                              let dragData = BubbleItemDragData.decode(string) {
                        connectItem(itemId: dragData.itemId, itemType: dragData.itemType, toDialogueId: dialogueId)
                    }
                }
            }
            return true
        }

        return false
    }

    // MARK: - Connect/Disconnect Items

    /// Connects an item to a dialogue as a sub-bubble
    func connectItem(itemId: String, itemType: String, toDialogueId dialogueId: String) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        switch itemType {
        case "action":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].actions.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].actions[idx].parentDialogueId = dialogueId
            }
        case "narration":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].narrations.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].narrations[idx].parentDialogueId = dialogueId
            }
        case "note":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[idx].parentDialogueId = dialogueId
            }
        case "soundNote":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].soundNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].soundNotes[idx].parentDialogueId = dialogueId
            }
        default:
            break
        }

        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        sortRefreshTrigger = UUID()
        onContentChanged?()
    }

    /// Disconnects an item from its parent dialogue
    func disconnectItem(itemId: String, itemType: String) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        switch itemType {
        case "action":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].actions.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].actions[idx].parentDialogueId = nil
            }
        case "narration":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].narrations.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].narrations[idx].parentDialogueId = nil
            }
        case "note":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].sceneNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].sceneNotes[idx].parentDialogueId = nil
            }
        case "soundNote":
            if let idx = project.sequences[seqIndex].scenes[sceneIndex].soundNotes.firstIndex(where: { $0.id == itemId }) {
                project.sequences[seqIndex].scenes[sceneIndex].soundNotes[idx].parentDialogueId = nil
            }
        default:
            break
        }

        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        sortRefreshTrigger = UUID()
        onContentChanged?()
    }
}
