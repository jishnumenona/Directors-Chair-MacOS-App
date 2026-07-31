//
//  StorytellerEngine.swift
//  DirectorsChair-Desktop
//
//  Storyteller mode: performs the screenplay as spoken narration, one
//  chunk per scene. The engine builds scene chunks from the same script
//  rendering the Script view uses, estimates cost BEFORE any network
//  call, caches generated audio in Application Support keyed by
//  content hash, and generates chunks sequentially so playback can start
//  as soon as the first scene is ready. Text-transform and TTS calls are
//  injected seams (VoiceConversationController precedent) so tests run
//  offline.
//

import Foundation
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

// MARK: - Prompt (verbatim per spec; version participates in the cache key)

enum StorytellerPrompt {
    /// Bump deliberately to invalidate every cached narration — the version
    /// is hashed into each chunk's cache key.
    static let version = "v1"

    static let systemPrompt = """
    You are a master storyteller — the voice people remember from campfires and
    late-night radio. Your craft: transform a screenplay scene into SPOKEN
    narration that captivates a listener who cannot see the page.

    RULES OF THE CRAFT:
    - Never read screenplay artifacts aloud. "INT. KITCHEN — NIGHT" is not
      spoken; it becomes atmosphere: "Night has settled over the kitchen…".
      No "CUT TO", no camera directions, no parentheticals read literally.
    - Present tense, close and immediate. The listener stands inside the scene.
    - Dialogue is sacred: speak every line VERBATIM as written, woven in with
      natural attribution — a breath before, "…Mara says, barely above a
      whisper" after — never robotic "Character says:" prefixes twice in a row.
      Vary attribution; sometimes let exchanges run bare once speakers are
      established.
    - Compress action into vivid, sensory beats. What the camera sees becomes
      what the listener feels: sound, light, texture, breath. Cut anything a
      listener cannot picture.
    - Rhythm is the instrument: short sentences for tension. Longer, flowing
      ones when the scene breathes. Land each scene's final line like a soft
      cliffhanger — the reason to keep listening.
    - Keep every character name, every plot fact, every told detail faithful to
      the script. You dramatize the telling, never the events.
    - Length discipline: roughly 110–160 spoken words per screenplay page-minute;
      a scene marked ~90 seconds of screen time should take ~90 seconds to tell.
    - Output ONLY the narration text. No headers, no stage notes, no quotes
      around the whole piece.

    CONTINUITY: you receive "PREVIOUSLY:" — a one-line summary of the story so
    far. Flow from it naturally (no recaps) so scene chunks join seamlessly.
    End your output with a line "NEXT-PREVIOUSLY: <one sentence carrying the
    story state forward>" — it is stripped before TTS and fed to the next
    chunk's prompt.
    """
}

// MARK: - Voice delivery (spec: warm narrator; params hash into cache key)

enum StorytellerVoice {
    /// Small curated list of warm narrator voices (user-pickable later).
    static let curatedVoices = ["Sulafat", "Charon", "Kore"]
    static let defaultVoice = "Sulafat"
    static let tone = "warm, intimate, storyteller's gravitas"
    static let pace = "measured, with dynamic swells"
    static let fallbackEmotion = "engaged, quietly intense"

    /// Per-scene delivery derived from slug-line atmosphere + the dominant
    /// analyzed emotion; falls back to the spec default.
    static func emotion(timeOfDay: String?, weather: String?, mood: String?) -> String {
        var parts: [String] = []
        if let mood, !mood.isEmpty { parts.append(mood.lowercased()) }
        if let timeOfDay, !timeOfDay.isEmpty { parts.append("a \(timeOfDay.lowercased()) scene") }
        if let weather, !weather.isEmpty { parts.append(weather.lowercased()) }
        return parts.isEmpty ? fallbackEmotion : parts.joined(separator: ", ")
    }

    /// Everything that changes the produced audio must invalidate the cache.
    static func cacheParams(emotion: String) -> String {
        [defaultVoice, tone, pace, emotion].joined(separator: "|")
    }
}

// MARK: - Chunk model

struct StorytellerChunk: Identifiable {
    enum State: Equatable {
        case pending          // uncached; will cost money to generate
        case generating
        case cached           // audio found on disk from an earlier run ($0)
        case ready            // generated this run
        case failed(String)
    }

    let id: String            // scene UUID
    let sceneIndex: Int       // GLOBAL scene index (matches playback boundaries)
    let sceneName: String
    let scriptText: String    // plain storyteller input (heading + body)
    let emotion: String
    let cacheKey: String
    var state: State = .pending
    var narrationText: String?
    var previouslyLine: String?     // NEXT-PREVIOUSLY handed to the next chunk
    var audioURL: URL?
    var duration: TimeInterval = 0  // REAL measured audio duration, never WPM
    var estimatedCost: Double = 0   // 0 once cached/ready

    var isPlayable: Bool {
        (state == .cached || state == .ready) && audioURL != nil
    }
}

/// Sidecar written next to each cached WAV: the narration text, measured
/// duration, and the PREVIOUSLY line so cached chunks re-thread continuity
/// without a network call.
struct StorytellerSidecar: Codable {
    let narrationText: String
    let duration: TimeInterval
    let previouslyLine: String
    let promptVersion: String
}

struct StorytellerError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// MARK: - Engine

@MainActor
final class StorytellerEngine: ObservableObject {
    typealias TransformText = @Sendable (_ systemPrompt: String, _ userPrompt: String) async throws -> String
    typealias SynthesizeSpeech = @Sendable (SpeechGenerationRequest) async throws -> Data

    @Published private(set) var chunks: [StorytellerChunk] = []
    @Published private(set) var isGenerating = false
    @Published private(set) var lastError: String?

    /// Injected seams — tests replace these; nothing here touches the
    /// network until the user has confirmed generation. Both default seams
    /// record usage inside AIServiceClient (generateText → recordTextUsage,
    /// generateSpeech → recordSpeechUsage), so the engine must NOT record
    /// again.
    var transformText: TransformText
    var synthesizeSpeech: SynthesizeSpeech
    var measureDuration: (URL) -> TimeInterval
    let cacheRoot: URL

    private var generationTask: Task<Void, Never>?
    private(set) var projectUUID: String = ""

    nonisolated static var defaultCacheRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask).first!
            .appendingPathComponent("DirectorsChair/storyteller", isDirectory: true)
    }

    nonisolated init(
        transformText: @escaping TransformText = { system, user in
            let request = TextGenerationRequest(
                prompt: user, provider: .google, maxTokens: 4096,
                temperature: 0.8, systemPrompt: system)
            return try await AIServiceClient.shared.generateText(request).text
        },
        synthesizeSpeech: @escaping SynthesizeSpeech = { request in
            // Returns container-wrapped WAV (PCMWAVWrapper applied inside).
            try await AIServiceClient.shared.generateSpeech(request).audioData
        },
        measureDuration: @escaping (URL) -> TimeInterval = { url in
            (try? AVAudioPlayer(contentsOf: url))?.duration ?? 0
        },
        cacheRoot: URL = StorytellerEngine.defaultCacheRoot
    ) {
        self.transformText = transformText
        self.synthesizeSpeech = synthesizeSpeech
        self.measureDuration = measureDuration
        self.cacheRoot = cacheRoot
    }

    // MARK: - Prepare (disk only — the no-network-before-confirm gate)

    /// Build the scene chunks, resolve the cache, and compute estimates.
    /// Touches only the local cache directory; generation starts separately
    /// after the user confirms the cost.
    func prepare(project: Project) {
        cancelGeneration()
        projectUUID = project.uuid
        chunks = Self.buildChunks(from: project).map { draft in
            var chunk = draft
            let wav = cacheFileURL(for: chunk, ext: "wav")
            let sidecarURL = cacheFileURL(for: chunk, ext: "json")
            if FileManager.default.fileExists(atPath: wav.path),
               let data = try? Data(contentsOf: sidecarURL),
               let sidecar = try? JSONDecoder().decode(StorytellerSidecar.self, from: data) {
                chunk.state = .cached
                chunk.audioURL = wav
                chunk.narrationText = sidecar.narrationText
                chunk.duration = sidecar.duration
                chunk.previouslyLine = sidecar.previouslyLine
                chunk.estimatedCost = 0
            } else {
                chunk.state = .pending
                chunk.estimatedCost = Self.estimatedCost(scriptCharacters: chunk.scriptText.count)
            }
            return chunk
        }
    }

    // MARK: - Derived state

    var pendingChunkCount: Int {
        chunks.filter { !$0.isPlayable }.count
    }

    var cachedChunkCount: Int {
        chunks.filter { $0.state == .cached }.count
    }

    var totalEstimatedCost: Double {
        chunks.reduce(0) { $0 + $1.estimatedCost }
    }

    /// Start offset of a chunk on the story clock — the sum of the REAL
    /// measured durations before it (unready chunks contribute 0 until
    /// their audio lands).
    func chunkStartOffset(at index: Int) -> TimeInterval {
        chunks.prefix(max(0, index)).reduce(0) { $0 + $1.duration }
    }

    var storyDuration: TimeInterval {
        chunks.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Generation (only after user confirmation)

    func startGeneration() {
        guard generationTask == nil, pendingChunkCount > 0 else { return }
        // A failed chunk blocks the PREVIOUSLY chain — retry it.
        for i in chunks.indices {
            if case .failed = chunks[i].state { chunks[i].state = .pending }
        }
        isGenerating = true
        lastError = nil
        generationTask = Task { [weak self] in
            await self?.runGeneration()
            self?.generationTask = nil
            self?.isGenerating = false
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        for i in chunks.indices where chunks[i].state == .generating {
            chunks[i].state = .pending
        }
    }

    /// Sequential per-scene generation with PREVIOUSLY threading. Internal
    /// (not private) so tests can await the full pass deterministically.
    func runGeneration() async {
        var previously = Self.openingPreviously
        for index in chunks.indices {
            if Task.isCancelled { return }
            if chunks[index].isPlayable {
                // Cached chunks re-thread their stored continuity line.
                if let line = chunks[index].previouslyLine, !line.isEmpty {
                    previously = line
                }
                continue
            }
            chunks[index].state = .generating
            do {
                previously = try await generate(chunkAt: index, previously: previously)
            } catch is CancellationError {
                chunks[index].state = .pending
                return
            } catch {
                chunks[index].state = .failed(error.localizedDescription)
                lastError = "Scene “\(chunks[index].sceneName)”: \(error.localizedDescription)"
                // Later chunks need this chunk's PREVIOUSLY line — stop the chain.
                return
            }
        }
    }

    private func generate(chunkAt index: Int, previously: String) async throws -> String {
        let chunk = chunks[index]
        let userPrompt = "PREVIOUSLY: \(previously)\n\nSCENE:\n\(chunk.scriptText)"
        let raw = try await transformText(StorytellerPrompt.systemPrompt, userPrompt)
        let (narration, nextPreviously) = Self.parseNarration(raw)
        guard !narration.isEmpty else {
            throw StorytellerError("the storyteller returned no narration")
        }
        try Task.checkCancellation()

        let request = SpeechGenerationRequest(
            text: narration,
            provider: .google,
            voiceName: StorytellerVoice.defaultVoice,
            emotion: chunk.emotion,
            voiceTone: StorytellerVoice.tone,
            voicePace: StorytellerVoice.pace)
        let audio = try await synthesizeSpeech(request)
        try Task.checkCancellation()

        let directory = projectCacheDirectory()
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        let wav = cacheFileURL(for: chunk, ext: "wav")
        try audio.write(to: wav)
        // Time-accuracy contract: the playhead maps REAL audio time, so the
        // duration must come from the decoded file, never a WPM estimate.
        let duration = measureDuration(wav)
        let carried = nextPreviously.isEmpty
            ? Self.lastSentence(of: narration)
            : nextPreviously
        let sidecar = StorytellerSidecar(
            narrationText: narration, duration: duration,
            previouslyLine: carried, promptVersion: StorytellerPrompt.version)
        try JSONEncoder().encode(sidecar).write(to: cacheFileURL(for: chunk, ext: "json"))

        chunks[index].state = .ready
        chunks[index].audioURL = wav
        chunks[index].narrationText = narration
        chunks[index].duration = duration
        chunks[index].previouslyLine = carried
        chunks[index].estimatedCost = 0
        return carried
    }

    // MARK: - Cache

    private func projectCacheDirectory() -> URL {
        cacheRoot.appendingPathComponent(projectUUID, isDirectory: true)
    }

    private func cacheFileURL(for chunk: StorytellerChunk, ext: String) -> URL {
        projectCacheDirectory()
            .appendingPathComponent("\(chunk.id)-\(chunk.cacheKey)")
            .appendingPathExtension(ext)
    }

    /// Deletes this project's narration cache and re-marks every chunk as
    /// pending with a fresh estimate. Callers stop playback first.
    func clearCache() {
        cancelGeneration()
        try? FileManager.default.removeItem(at: projectCacheDirectory())
        for i in chunks.indices {
            chunks[i].state = .pending
            chunks[i].audioURL = nil
            chunks[i].narrationText = nil
            chunks[i].previouslyLine = nil
            chunks[i].duration = 0
            chunks[i].estimatedCost = Self.estimatedCost(
                scriptCharacters: chunks[i].scriptText.count)
        }
    }

    // MARK: - Pure helpers (unit-tested)

    static let openingPreviously =
        "This is the very beginning of the story — nothing has happened yet."

    /// One chunk per non-empty scene, in screenplay order. The script text
    /// comes from the same converter the Script view renders, filtered per
    /// scene and flattened to plain text (HTML stripped). Editor-only notes
    /// and blank lines are not part of the telling.
    static func buildChunks(from project: Project) -> [StorytellerChunk] {
        let elements = ProjectToScriptConverter.convert(from: project)

        // Global scene index in the same walk order as the playback
        // boundaries (sequence by sequence, scene by scene).
        var globalIndex: [String: Int] = [:]
        var scenes: [DirectorsChairCore.Scene] = []
        for (seqIdx, sequence) in project.sequences.enumerated() {
            for (scnIdx, scene) in sequence.scenes.enumerated() {
                globalIndex["\(seqIdx)-\(scnIdx)"] = scenes.count
                scenes.append(scene)
            }
        }

        var lines: [Int: [String]] = [:]
        for element in elements {
            guard let seqIdx = element.sourceSequenceIndex,
                  let scnIdx = element.sourceSceneIndex,
                  let global = globalIndex["\(seqIdx)-\(scnIdx)"] else { continue }
            let text: String?
            switch element.type {
            case .sceneHeading, .character, .parenthetical, .transition, .soundCue:
                text = element.text
            case .action, .dialogue, .dualDialogue:
                text = DurationEstimator.htmlToPlainText(element.text)
            case .scriptNote, .sectionHeading, .blankLine:
                text = nil
            }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines[global, default: []].append(text)
            }
        }

        var chunks: [StorytellerChunk] = []
        for (global, scene) in scenes.enumerated() {
            let sceneLines = lines[global] ?? []
            // The heading alone is not a scene worth telling — skip empties.
            guard sceneLines.count > 1 else { continue }
            let scriptText = sceneLines.joined(separator: "\n")
            let mood = scene.sceneEmotionalAnalysis?
                .max(by: { $0.value < $1.value })?.key
            let emotion = StorytellerVoice.emotion(
                timeOfDay: scene.timeOfDay, weather: scene.weather, mood: mood)
            chunks.append(StorytellerChunk(
                id: scene.uuid,
                sceneIndex: global,
                sceneName: scene.name,
                scriptText: scriptText,
                emotion: emotion,
                cacheKey: cacheKey(scriptText: scriptText, emotion: emotion)))
        }
        return chunks
    }

    /// sha256(script + prompt version + voice params) — any change to what
    /// would be generated produces a different file name.
    static func cacheKey(scriptText: String, emotion: String,
                         promptVersion: String = StorytellerPrompt.version) -> String {
        let material = scriptText + promptVersion
            + StorytellerVoice.cacheParams(emotion: emotion)
        return SyncHashing.sha256Hex(Data(material.utf8))
    }

    /// Spec estimate: script chars → tokens in (≈4 chars/token); narration
    /// ≈ 0.75× script chars out at the text token rates; TTS bills the
    /// narration chars at the rate-card speech price.
    static func estimatedCost(scriptCharacters: Int) -> Double {
        guard scriptCharacters > 0 else { return 0 }
        let rates = AIUsageStats.rateCard
        let tokensIn = Int((Double(scriptCharacters) / 4.0).rounded(.up))
        let narrationChars = Double(scriptCharacters) * 0.75
        let tokensOut = Int((narrationChars / 4.0).rounded(.up))
        let textCost = AIUsageStats.textCallCost(promptTokens: tokensIn,
                                                 completionTokens: tokensOut)
        let ttsCost = narrationChars / 1000.0 * rates.speechPer1kChars
        return textCost + ttsCost
    }

    /// Splits the model output into (narration, NEXT-PREVIOUSLY line).
    /// The marker line is stripped before TTS per the prompt contract.
    static func parseNarration(_ raw: String) -> (narration: String, nextPreviously: String) {
        let marker = "NEXT-PREVIOUSLY:"
        var narrationLines: [String] = []
        var nextPreviously = ""
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix(marker) {
                nextPreviously = String(trimmed.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespaces)
            } else {
                narrationLines.append(line)
            }
        }
        let narration = narrationLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (narration, nextPreviously)
    }

    /// Fallback continuity when the model forgets the marker: carry the
    /// narration's closing sentence forward (capped).
    static func lastSentence(of narration: String) -> String {
        let sentences = narration
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let last = sentences.last ?? narration
        return String(last.prefix(200))
    }
}
