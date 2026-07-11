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

    /// Scroll to a newly added item after a brief delay for the view to settle
    func scrollToNewItem(_ itemId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToItemId = itemId
        }
    }

    // MARK: - Generic scene-item CRUD (WS5.5)
    //
    // Add/update/delete for the five chronology item kinds (Dialogue, Action,
    // Narration, Note, SoundNote) previously existed as 19 hand-copied
    // functions (~460 lines) differing only in the item constructor and the
    // scene array they touch. One generic commit path now serves all of them,
    // preserving the legacy side-effect order exactly: selectedScene snapshot
    // -> newlyAddedItemId -> hook -> bubble-cache rebuild -> sortRefreshTrigger
    // (adds only) -> scroll -> onContentChanged.

    private func commitSelectedSceneMutation(newItemId: String? = nil,
                                             scrollTo: String? = nil,
                                             afterMutate: () -> Void = {},
                                             _ mutate: (inout DCScene) -> Bool) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }
        guard mutate(&project.sequences[seqIndex].scenes[sceneIndex]) else { return }
        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        if let newItemId { newlyAddedItemId = newItemId }
        afterMutate()
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        if newItemId != nil { sortRefreshTrigger = UUID() }
        if let scrollTo { scrollToNewItem(scrollTo) }
        onContentChanged?()
    }

    private func addItem<T: SceneChronologyItem>(_ item: T,
                                                 to keyPath: WritableKeyPath<DCScene, [T]>,
                                                 scrollTo: String? = nil) {
        commitSelectedSceneMutation(newItemId: item.id, scrollTo: scrollTo ?? item.id) {
            $0[keyPath: keyPath].append(item)
            return true
        }
    }

    private func updateItem<T: SceneChronologyItem>(_ item: T,
                                                    in keyPath: WritableKeyPath<DCScene, [T]>) {
        commitSelectedSceneMutation { scene in
            guard let i = scene[keyPath: keyPath].firstIndex(where: { $0.uuid == item.uuid }) else { return false }
            scene[keyPath: keyPath][i] = item
            return true
        }
    }

    private func deleteItem<T: SceneChronologyItem>(_ item: T,
                                                    from keyPath: WritableKeyPath<DCScene, [T]>,
                                                    afterMutate: () -> Void = {}) {
        commitSelectedSceneMutation(afterMutate: afterMutate) { scene in
            scene[keyPath: keyPath].removeAll { $0.uuid == item.uuid }
            return true
        }
    }

    // MARK: - Dialogue

    func updateDialogue(_ updated: Dialogue) {
        updateItem(updated, in: \.dialogues)
    }

    func addDialogue(for characterName: String) {
        let maxChronology = globalMaxChronology()
        let newDialogue = Dialogue(
            character: characterName,
            text: "",
            chronologyNumber: maxChronology + 1
        )
        addItem(newDialogue, to: \.dialogues)
    }

    func deleteDialogue(_ dialogue: Dialogue) {
        deleteItem(dialogue, from: \.dialogues, afterMutate: {
            // Clear selection if deleted dialogue was selected
            if selectedDialogue?.id == dialogue.id {
                selectedDialogue = nil
            }
        })
    }

    // MARK: - Add items

    func addAction() {
        let maxChronology = globalMaxChronology()
        addItem(Action(
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
        ), to: \.actions)
    }

    func addNarration() {
        let maxChronology = globalMaxChronology()
        addItem(Narration(
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
        ), to: \.narrations)
    }

    func addNote() {
        let maxChronology = globalMaxChronology()
        addItem(Note(
            uuid: UUID().uuidString,
            content: "",
            noteType: "text",
            chronologyNumber: maxChronology + 1
        ), to: \.sceneNotes)
    }

    func addSoundNote() {
        let maxChronology = globalMaxChronology()
        addItem(SoundNote(
            uuid: UUID().uuidString,
            description: "",
            soundType: "ambient",
            chronologyNumber: maxChronology + 1
        ), to: \.soundNotes)
    }

    // MARK: - Add Connected Items (directly to a dialogue)

    func addConnectedAction(to dialogue: Dialogue) {
        let maxChronology = globalMaxChronology()
        addItem(Action(
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
        ), to: \.actions, scrollTo: dialogue.id)
    }

    func addConnectedNarration(to dialogue: Dialogue) {
        let maxChronology = globalMaxChronology()
        addItem(Narration(
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
        ), to: \.narrations, scrollTo: dialogue.id)
    }

    func addConnectedNote(to dialogue: Dialogue) {
        let maxChronology = globalMaxChronology()
        addItem(Note(
            uuid: UUID().uuidString,
            content: "",
            noteType: "text",
            chronologyNumber: maxChronology + 1,
            parentDialogueId: dialogue.id
        ), to: \.sceneNotes, scrollTo: dialogue.id)
    }

    func addConnectedSoundNote(to dialogue: Dialogue) {
        let maxChronology = globalMaxChronology()
        addItem(SoundNote(
            uuid: UUID().uuidString,
            description: "",
            soundType: "ambient",
            chronologyNumber: maxChronology + 1,
            parentDialogueId: dialogue.id
        ), to: \.soundNotes, scrollTo: dialogue.id)
    }

    // MARK: - Edit / delete / update

    func editAction(_ action: Action) {
        editingAction = action
    }

    func deleteAction(_ action: Action) {
        deleteItem(action, from: \.actions)
    }

    func editNarration(_ narration: Narration) {
        editingNarration = narration
    }

    func deleteNarration(_ narration: Narration) {
        deleteItem(narration, from: \.narrations)
    }

    func editNote(_ note: Note) {
        editingNote = note
    }

    func deleteNote(_ note: Note) {
        deleteItem(note, from: \.sceneNotes)
    }

    func editSoundNote(_ soundNote: SoundNote) {
        editingSoundNote = soundNote
    }

    func deleteSoundNote(_ soundNote: SoundNote) {
        deleteItem(soundNote, from: \.soundNotes)
    }

    func updateAction(_ updated: Action) {
        updateItem(updated, in: \.actions)
    }

    func updateNarration(_ updated: Narration) {
        updateItem(updated, in: \.narrations)
    }

    func updateNote(_ updated: Note) {
        updateItem(updated, in: \.sceneNotes)
    }

    func updateSoundNote(_ updated: SoundNote) {
        updateItem(updated, in: \.soundNotes)
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

            // Prompt construction lives in ShotPromptBuilder (WS6.2).
            let prompt = ShotPromptBuilder.dialogueEmotionPrompt(characterName: dialogue.character, text: text)

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
    // MARK: - Drag reorder (drop zones between rows)

    /// Locate an item's current chronology + parent linkage in the selected scene.
    func lookupItem(itemId: String, itemType: String) -> (chronology: Int, parentDialogueId: String?)? {
        guard let scene = selectedScene else { return nil }
        switch itemType {
        case "dialogue":
            return scene.dialogues.first { $0.id == itemId }.map { ($0.chronologyNumber, nil) }
        case "action":
            return scene.actions.first { $0.id == itemId }.map { ($0.chronologyNumber, $0.parentDialogueId) }
        case "narration":
            return scene.narrations.first { $0.id == itemId }.map { ($0.chronologyNumber, $0.parentDialogueId) }
        case "note":
            return scene.sceneNotes.first { $0.id == itemId }.map { ($0.chronologyNumber, $0.parentDialogueId) }
        case "soundNote":
            return scene.soundNotes.first { $0.id == itemId }.map { ($0.chronologyNumber, $0.parentDialogueId) }
        default:
            return nil
        }
    }

    /// Drop-zone handler: move the dragged item so it sits BEFORE the given
    /// chronology position (nil = move to the end). A connected item dropped
    /// into a zone is disconnected first — dragging it out of its dialogue is
    /// the natural "detach" gesture.
    func handleReorderDrop(itemId: String, itemType: String, insertBefore targetChronology: Int?) {
        guard let info = lookupItem(itemId: itemId, itemType: itemType) else { return }
        if info.parentDialogueId != nil {
            disconnectItem(itemId: itemId, itemType: itemType)
        }
        guard let current = lookupItem(itemId: itemId, itemType: itemType) else { return }
        let oldIndex = current.chronology

        let newIndex: Int
        if let target = targetChronology {
            // Insert-before semantics with the classic shift adjustment.
            newIndex = oldIndex < target ? target - 1 : target
        } else {
            newIndex = globalMaxChronology()
        }
        guard newIndex != oldIndex else { return }
        reorderItems(movingItemId: itemId, oldIndex: oldIndex, newIndex: newIndex)
    }

    func disconnectItem(itemId: String, itemType: String) {
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains { $0.id == scene.id }
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id })
        else { return }

        BubbleChronology.disconnect(&project.sequences[seqIndex].scenes[sceneIndex],
                                    itemId: itemId, itemType: itemType)

        selectedScene = project.sequences[seqIndex].scenes[sceneIndex]
        rebuildBubbleCache(for: project.sequences[seqIndex].scenes[sceneIndex])
        sortRefreshTrigger = UUID()
        onContentChanged?()
    }
}

// MARK: - Scene chronology item conformances (WS5.5)

/// Minimal surface the generic CRUD helpers need. All five chronology item
/// kinds expose a stable `uuid` (with `id` returning it).
protocol SceneChronologyItem {
    var uuid: String { get }
    var id: String { get }
}

extension Dialogue: SceneChronologyItem {}
extension Action: SceneChronologyItem {}
extension Narration: SceneChronologyItem {}
extension Note: SceneChronologyItem {}
extension SoundNote: SceneChronologyItem {}
