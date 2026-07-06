// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/VoiceTab.swift
//
// Voice settings tab for character AI voice configuration
// Full TTS configuration: 30 Gemini voices, tone, pace, accent, auto-detect

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AVFoundation

/// Voice settings tab for configuring character AI voice
///
/// Displays:
/// - Auto-detect button (header)
/// - Voice selection grid (all 30 Gemini voices, gender-filtered)
/// - Tone & Emotion chips
/// - Pace & Delivery chips + accent
/// - Voice style text field (custom overrides)
/// - Preview section with test playback
public struct VoiceTab: View {
    @Binding var character: Character
    let project: Project
    var onSwitchToTraitsTab: (() -> Void)?

    @State private var previewText: String = ""
    @State private var isPreviewPlaying = false
    @State private var isGeneratingPreview = false
    @State private var previewError: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isAutoDetecting = false
    @State private var autoDetectError: String?
    @State private var showTraitsWarning = false

    public init(character: Binding<Character>, project: Project, onSwitchToTraitsTab: (() -> Void)? = nil) {
        self._character = character
        self.project = project
        self.onSwitchToTraitsTab = onSwitchToTraitsTab
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                autoDetectHeader
                voiceSelectionCard
                toneEmotionCard
                paceDeliveryCard
                voiceStyleCard
                previewCard
            }
            .padding(20)
        }
        .onAppear {
            if previewText.isEmpty {
                previewText = firstDialogueText()
            }
        }
    }

    // MARK: - Auto-Detect Header

    /// Whether the character's traits have been calibrated by AI (not still at defaults)
    private var traitsCalibrated: Bool {
        character.traitsLastCalibrated != nil
    }

    private var autoDetectHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Traits warning banner
            if showTraitsWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("Personality traits haven't been analyzed yet. Auto-detect works best with calibrated traits.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    Spacer()
                    Button("Go to Traits") {
                        showTraitsWarning = false
                        onSwitchToTraitsTab?()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                    Button("Continue Anyway") {
                        showTraitsWarning = false
                        Task { await autoDetectVoiceSettings() }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            }

            HStack {
                if let error = autoDetectError {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                if isAutoDetecting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyzing character...")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                } else {
                    Button(action: handleAutoDetectTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text("Auto-Detect from Script")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func handleAutoDetectTap() {
        autoDetectError = nil
        if !traitsCalibrated {
            showTraitsWarning = true
        } else {
            Task { await autoDetectVoiceSettings() }
        }
    }

    // MARK: - Voice Selection Card

    private var voiceSelectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("VOICE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            // Gender-matching voices first
            let primaryVoices = voicesForGender(character.gender)
            let secondaryVoices = GeminiVoice.allVoices.filter { !primaryVoices.contains($0) }

            if !primaryVoices.isEmpty {
                Text("Recommended")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(primaryVoices) { voice in
                        VoiceChip(
                            voice: voice,
                            isSelected: character.voice == voice.name
                        ) {
                            character.voice = voice.name
                        }
                    }
                }
            }

            if !secondaryVoices.isEmpty {
                Text("Other Voices")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(secondaryVoices) { voice in
                        VoiceChip(
                            voice: voice,
                            isSelected: character.voice == voice.name
                        ) {
                            character.voice = voice.name
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Tone & Emotion Card

    private var toneEmotionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "theatermasks")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("TONE & EMOTION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            // Tone row
            Text("Tone")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                ForEach(VoiceOption.tones, id: \.self) { tone in
                    AttributeChip(
                        label: tone,
                        icon: toneIcon(tone),
                        isSelected: character.voiceTone == tone
                    ) {
                        character.voiceTone = character.voiceTone == tone ? nil : tone
                    }
                }
            }

            // Personality row
            Text("Personality")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                ForEach(VoiceOption.personalities, id: \.self) { personality in
                    AttributeChip(
                        label: personality,
                        icon: personalityIcon(personality),
                        isSelected: character.voicePersonality == personality
                    ) {
                        character.voicePersonality = character.voicePersonality == personality ? nil : personality
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Pace & Delivery Card

    private var paceDeliveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "metronome")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("PACE & DELIVERY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            // Pace row
            Text("Pace")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                ForEach(VoiceOption.paces, id: \.self) { pace in
                    AttributeChip(
                        label: pace,
                        icon: paceIcon(pace),
                        isSelected: character.voicePace == pace
                    ) {
                        character.voicePace = character.voicePace == pace ? nil : pace
                    }
                }
            }

            // Age row
            Text("Voice Age")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                ForEach(VoiceOption.ages, id: \.self) { age in
                    AttributeChip(
                        label: age,
                        icon: ageIcon(age),
                        isSelected: character.voiceAge == age
                    ) {
                        character.voiceAge = character.voiceAge == age ? nil : age
                    }
                }
            }

            // Accent row
            Text("Accent")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
                ForEach(VoiceOption.accents, id: \.self) { accent in
                    AttributeChip(
                        label: accent,
                        icon: "globe",
                        isSelected: character.voiceAccent == accent
                    ) {
                        character.voiceAccent = character.voiceAccent == accent ? nil : accent
                    }
                }
            }

            // Custom accent text field
            TextField("Custom accent (e.g. Scottish, French, Indian)", text: Binding(
                get: {
                    let current = character.voiceAccent ?? ""
                    return VoiceOption.accents.contains(current) ? "" : current
                },
                set: { newValue in
                    character.voiceAccent = newValue.isEmpty ? nil : newValue
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Voice Style Card

    private var voiceStyleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("VOICE STYLE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            Text("Additional style notes (overrides above if conflicting)")
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))

            TextField("e.g. Calm and authoritative, Nervous and hesitant", text: Binding(
                get: { character.voiceStyle ?? "" },
                set: { character.voiceStyle = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("PREVIEW")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            TextField("Enter text to preview...", text: $previewText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(2...5)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .quaternarySystemFill))
                )

            HStack(spacing: 12) {
                if isGeneratingPreview {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating...")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                } else if isPreviewPlaying {
                    Button(action: stopPreview) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { Task { await generatePreview() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Preview Voice")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || character.voice == nil)
                }

                Spacer()

                // Show current config badges
                HStack(spacing: 4) {
                    if let selectedVoice = character.voice {
                        configBadge(selectedVoice)
                    }
                    if let tone = character.voiceTone {
                        configBadge(tone)
                    }
                    if let pace = character.voicePace {
                        configBadge(pace)
                    }
                }
            }

            if let error = previewError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    private func configBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(4)
    }

    // MARK: - Actions

    private func generatePreview() async {
        guard !previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isGeneratingPreview = true
        previewError = nil

        do {
            let request = SpeechGenerationRequest(
                text: previewText,
                provider: .google,
                voiceName: character.voice,
                emotion: character.voiceStyle,
                characterName: character.name,
                voiceTone: character.voiceTone,
                voicePersonality: character.voicePersonality,
                voicePace: character.voicePace,
                voiceAccent: character.voiceAccent,
                voiceAge: character.voiceAge
            )

            let response = try await AIServiceClient.shared.generateSpeech(request)

            audioPlayer = try AVAudioPlayer(data: response.audioData)
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            AudioPlayerDelegate.shared.onFinished = {
                isPreviewPlaying = false
            }
            audioPlayer?.play()
            isPreviewPlaying = true
        } catch {
            previewError = error.localizedDescription
        }

        isGeneratingPreview = false
    }

    private func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPreviewPlaying = false
    }

    // MARK: - Auto-Detect

    private func autoDetectVoiceSettings() async {
        isAutoDetecting = true
        autoDetectError = nil

        // Gather character context
        var context = "Character: \(character.name)\n"
        if !character.role.isEmpty { context += "Role: \(character.role)\n" }
        context += "Gender: \(character.gender)\n"
        context += "Age: \(character.age)\n"
        if !character.build.isEmpty { context += "Build: \(character.build)\n" }
        if !character.ethnicity.isEmpty { context += "Ethnicity: \(character.ethnicity)\n" }
        if let occupation = character.occupation { context += "Occupation: \(occupation)\n" }
        if let backgroundStory = character.backgroundStory {
            context += "Background: \(String(backgroundStory.prefix(300)))\n"
        }

        // Personality traits — include full profile if calibrated
        if traitsCalibrated {
            context += "\nCalibrated personality profile (0-100 scale):\n"
            let sortedTraits = character.traits.sorted { $0.value > $1.value }
            for trait in sortedTraits {
                let level: String
                switch trait.value {
                case 80...: level = "Very High"
                case 65..<80: level = "High"
                case 35..<65: level = "Average"
                case 20..<35: level = "Low"
                default: level = "Very Low"
                }
                context += "  \(trait.key): \(Int(trait.value)) (\(level))\n"
            }
            if let reasoning = character.traitsAiReasoning {
                context += "AI analysis: \(String(reasoning.prefix(300)))\n"
            }
        } else {
            let highTraits = character.traits.filter { $0.value > 65 }.sorted { $0.value > $1.value }
            let lowTraits = character.traits.filter { $0.value < 35 }.sorted { $0.value < $1.value }
            if !highTraits.isEmpty {
                context += "Strong traits: \(highTraits.map { $0.key }.joined(separator: ", "))\n"
            }
            if !lowTraits.isEmpty {
                context += "Weak traits: \(lowTraits.map { $0.key }.joined(separator: ", "))\n"
            }
        }

        // Sample dialogues
        var dialogueSamples: [String] = []
        for sequence in project.sequences {
            for scene in sequence.scenes {
                for dialogue in scene.dialogues where dialogue.character == character.name {
                    let text = dialogue.text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        dialogueSamples.append(text)
                    }
                    if dialogueSamples.count >= 5 { break }
                }
                if dialogueSamples.count >= 5 { break }
            }
            if dialogueSamples.count >= 5 { break }
        }

        if !dialogueSamples.isEmpty {
            context += "\nSample dialogue:\n"
            for (i, sample) in dialogueSamples.enumerated() {
                context += "\(i + 1). \"\(String(sample.prefix(200)))\"\n"
            }
        }

        let voiceNames = GeminiVoice.allVoices.map { "\($0.name) (\($0.descriptor), \($0.gender == .female ? "F" : "M"))" }.joined(separator: ", ")

        let prompt = """
        Based on this character, pick optimal TTS voice settings. Use ONLY values from the lists.

        \(context)

        Voices: \(voiceNames)
        Tones: \(VoiceOption.tones.joined(separator: ", "))
        Personalities: \(VoiceOption.personalities.joined(separator: ", "))
        Paces: \(VoiceOption.paces.joined(separator: ", "))
        Ages: \(VoiceOption.ages.joined(separator: ", "))

        Respond with ONLY this JSON, no other text:
        {"voice":"name","voiceTone":"tone","voicePersonality":"personality","voicePace":"pace","voiceAccent":"accent or empty","voiceAge":"age","voiceStyle":"brief note or empty"}
        """

        do {
            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 1000,
                temperature: 0.3,
                systemPrompt: "You are a JSON API. Respond with ONLY valid JSON, no markdown, no explanation, no code fences. Output a single JSON object on one line."
            )

            let response = try await AIServiceClient.shared.generateText(request)
            let rawText = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            debugLog("[VoiceTab] Auto-detect raw response (\(rawText.count) chars): \(rawText)")

            // Try JSON parsing first, fall back to regex extraction
            let values = extractJSON(from: rawText) ?? extractValuesViaRegex(from: rawText)
            applyAutoDetectValues(values)
        } catch {
            autoDetectError = error.localizedDescription
        }

        isAutoDetecting = false
    }

    // MARK: - Helpers

    private func firstDialogueText() -> String {
        for sequence in project.sequences {
            for scene in sequence.scenes {
                if let dialogue = scene.dialogues.first(where: { $0.character == character.name }) {
                    let text = dialogue.text
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("<") {
                        let tagPattern = "<[^>]+>"
                        if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                            let range = NSRange(location: 0, length: trimmed.utf16.count)
                            return regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    return text
                }
            }
        }
        return "Hello, my name is \(character.name)."
    }

    private func voicesForGender(_ gender: String) -> [GeminiVoice] {
        switch gender.lowercased() {
        case "female":
            return GeminiVoice.allVoices.filter { $0.gender == .female }
        case "male":
            return GeminiVoice.allVoices.filter { $0.gender == .male }
        default:
            return GeminiVoice.allVoices
        }
    }

    // MARK: - Auto-Detect Helpers

    /// Apply parsed voice settings to character
    private func applyAutoDetectValues(_ values: [String: Any]?) {
        guard let values = values, !values.isEmpty else {
            autoDetectError = "Could not parse AI response. Try again."
            return
        }

        if let voice = values["voice"] as? String,
           GeminiVoice.allVoices.contains(where: { $0.name == voice }) {
            character.voice = voice
        }
        if let tone = values["voiceTone"] as? String, VoiceOption.tones.contains(tone) {
            character.voiceTone = tone
        }
        if let personality = values["voicePersonality"] as? String, VoiceOption.personalities.contains(personality) {
            character.voicePersonality = personality
        }
        if let pace = values["voicePace"] as? String, VoiceOption.paces.contains(pace) {
            character.voicePace = pace
        }
        if let accent = values["voiceAccent"] as? String, !accent.isEmpty {
            character.voiceAccent = accent
        }
        if let age = values["voiceAge"] as? String, VoiceOption.ages.contains(age) {
            character.voiceAge = age
        }
        if let style = values["voiceStyle"] as? String, !style.isEmpty {
            character.voiceStyle = style
        }
    }

    /// Extract a JSON dictionary from AI response text, handling markdown fences and surrounding text
    private func extractJSON(from text: String) -> [String: Any]? {
        // Strategy 1: Try direct parse
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }

        // Strategy 2: Strip markdown code fences
        var cleaned = text
        if cleaned.contains("```") {
            let lines = cleaned.components(separatedBy: "\n")
            let filtered = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            cleaned = filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }

        // Strategy 3: Find first { and last } and try to parse that substring
        if let firstBrace = text.firstIndex(of: "{"),
           let lastBrace = text.lastIndex(of: "}") {
            let jsonSubstring = String(text[firstBrace...lastBrace])
            if let data = jsonSubstring.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }

        return nil
    }

    /// Regex fallback: extract "key":"value" pairs directly from text
    private func extractValuesViaRegex(from text: String) -> [String: Any]? {
        let keys = ["voice", "voiceTone", "voicePersonality", "voicePace", "voiceAccent", "voiceAge", "voiceStyle"]
        var result: [String: String] = [:]

        for key in keys {
            // Match "key":"value" or "key": "value" (with optional spaces)
            let pattern = "\"\(key)\"\\s*:\\s*\"([^\"]*)\""
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let valueRange = Range(match.range(at: 1), in: text) {
                let value = String(text[valueRange])
                if !value.isEmpty {
                    result[key] = value
                }
            }
        }

        debugLog("[VoiceTab] Regex extraction found \(result.count) values: \(result)")
        return result.isEmpty ? nil : result
    }

    // MARK: - Icon Helpers

    private func toneIcon(_ tone: String) -> String {
        switch tone {
        case "Warm": return "sun.max"
        case "Cold": return "snowflake"
        case "Authoritative": return "crown"
        case "Gentle": return "leaf"
        case "Intense": return "flame"
        case "Playful": return "face.smiling"
        case "Serious": return "exclamationmark.triangle"
        case "Mysterious": return "eye"
        default: return "circle"
        }
    }

    private func personalityIcon(_ personality: String) -> String {
        switch personality {
        case "Confident": return "star"
        case "Nervous": return "bolt.heart"
        case "Sarcastic": return "quote.bubble"
        case "Cheerful": return "sun.min"
        case "Melancholic": return "cloud.rain"
        case "Aggressive": return "bolt"
        case "Calm": return "wind"
        case "Dramatic": return "theatermasks"
        default: return "circle"
        }
    }

    private func paceIcon(_ pace: String) -> String {
        switch pace {
        case "Very Slow": return "tortoise"
        case "Slow": return "gauge.with.dots.needle.0percent"
        case "Normal": return "gauge.with.dots.needle.50percent"
        case "Moderate": return "gauge.with.dots.needle.50percent"
        case "Fast": return "gauge.with.dots.needle.100percent"
        case "Rapid": return "hare"
        default: return "circle"
        }
    }

    private func ageIcon(_ age: String) -> String {
        switch age {
        case "Young": return "figure.child"
        case "Middle-aged": return "figure.stand"
        case "Elderly": return "figure.roll"
        default: return "figure.stand"
        }
    }
}

// MARK: - Voice Option Constants

private enum VoiceOption {
    static let tones = ["Warm", "Cold", "Authoritative", "Gentle", "Intense", "Playful", "Serious", "Mysterious"]
    static let personalities = ["Confident", "Nervous", "Sarcastic", "Cheerful", "Melancholic", "Aggressive", "Calm", "Dramatic"]
    static let paces = ["Very Slow", "Slow", "Normal", "Moderate", "Fast", "Rapid"]
    static let ages = ["Young", "Middle-aged", "Elderly"]
    static let accents = ["British", "American Southern", "New York", "Irish", "Australian", "None"]
}

// MARK: - Gemini Voice Model (30 voices)

struct GeminiVoice: Identifiable, Equatable {
    let id: String
    let name: String
    let descriptor: String
    let gender: VoiceGender
    let icon: String

    var description: String { "\(name) — \(descriptor)" }

    enum VoiceGender {
        case male, female
    }

    static let allVoices: [GeminiVoice] = [
        // Female voices
        GeminiVoice(id: "zephyr", name: "Zephyr", descriptor: "Bright", gender: .female, icon: "wind"),
        GeminiVoice(id: "kore", name: "Kore", descriptor: "Firm", gender: .female, icon: "shield"),
        GeminiVoice(id: "leda", name: "Leda", descriptor: "Youthful", gender: .female, icon: "sparkles"),
        GeminiVoice(id: "aoede", name: "Aoede", descriptor: "Breezy", gender: .female, icon: "leaf"),
        GeminiVoice(id: "callirrhoe", name: "Callirrhoe", descriptor: "Easy-going", gender: .female, icon: "cloud"),
        GeminiVoice(id: "autonoe", name: "Autonoe", descriptor: "Bright", gender: .female, icon: "sun.max"),
        GeminiVoice(id: "despina", name: "Despina", descriptor: "Smooth", gender: .female, icon: "waveform"),
        GeminiVoice(id: "erinome", name: "Erinome", descriptor: "Clear", gender: .female, icon: "drop"),
        GeminiVoice(id: "laomedeia", name: "Laomedeia", descriptor: "Upbeat", gender: .female, icon: "music.note"),
        GeminiVoice(id: "achernar", name: "Achernar", descriptor: "Soft", gender: .female, icon: "moon"),
        GeminiVoice(id: "pulcherrima", name: "Pulcherrima", descriptor: "Forward", gender: .female, icon: "arrow.right"),
        GeminiVoice(id: "vindemiatrix", name: "Vindemiatrix", descriptor: "Gentle", gender: .female, icon: "heart"),
        GeminiVoice(id: "sadachbia", name: "Sadachbia", descriptor: "Lively", gender: .female, icon: "flame"),
        GeminiVoice(id: "sulafat", name: "Sulafat", descriptor: "Warm", gender: .female, icon: "sun.min"),

        // Male voices
        GeminiVoice(id: "puck", name: "Puck", descriptor: "Upbeat", gender: .male, icon: "theatermasks"),
        GeminiVoice(id: "charon", name: "Charon", descriptor: "Informative", gender: .male, icon: "book"),
        GeminiVoice(id: "fenrir", name: "Fenrir", descriptor: "Excitable", gender: .male, icon: "bolt.fill"),
        GeminiVoice(id: "orus", name: "Orus", descriptor: "Firm", gender: .male, icon: "shield.fill"),
        GeminiVoice(id: "enceladus", name: "Enceladus", descriptor: "Breathy", gender: .male, icon: "wind"),
        GeminiVoice(id: "iapetus", name: "Iapetus", descriptor: "Clear", gender: .male, icon: "drop.fill"),
        GeminiVoice(id: "umbriel", name: "Umbriel", descriptor: "Easy-going", gender: .male, icon: "cloud.fill"),
        GeminiVoice(id: "algieba", name: "Algieba", descriptor: "Smooth", gender: .male, icon: "waveform"),
        GeminiVoice(id: "algenib", name: "Algenib", descriptor: "Gravelly", gender: .male, icon: "mountain.2"),
        GeminiVoice(id: "rasalgethi", name: "Rasalgethi", descriptor: "Informative", gender: .male, icon: "info.circle"),
        GeminiVoice(id: "alnilam", name: "Alnilam", descriptor: "Firm", gender: .male, icon: "star.fill"),
        GeminiVoice(id: "schedar", name: "Schedar", descriptor: "Even", gender: .male, icon: "equal"),
        GeminiVoice(id: "gacrux", name: "Gacrux", descriptor: "Mature", gender: .male, icon: "person.fill"),
        GeminiVoice(id: "achird", name: "Achird", descriptor: "Friendly", gender: .male, icon: "hand.wave"),
        GeminiVoice(id: "zubenelgenubi", name: "Zubenelgenubi", descriptor: "Casual", gender: .male, icon: "cup.and.saucer"),
        GeminiVoice(id: "sadaltager", name: "Sadaltager", descriptor: "Knowledgeable", gender: .male, icon: "graduationcap"),
    ]
}

// MARK: - Voice Chip

private struct VoiceChip: View {
    let voice: GeminiVoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: voice.icon)
                    .font(.system(size: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(voice.name)
                        .font(.system(size: 11, weight: .semibold))
                    Text(voice.descriptor)
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color(nsColor: .tertiaryLabelColor))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Attribute Chip

private struct AttributeChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Audio Player Delegate

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    var onFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinished?()
        }
    }
}
