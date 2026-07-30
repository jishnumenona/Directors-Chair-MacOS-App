//
//  VoiceConversationController.swift
//  DirectorsChair-Desktop
//
//  Hands-free back-and-forth with the assistant (owner request):
//  listen → send → speak the reply aloud → listen again, Siri-style.
//  Listening reuses the existing on-device dictation; replies speak via
//  the on-device AVSpeechSynthesizer — zero API cost, instant start.
//  The controller is a small phase machine with injected seams so the
//  loop is testable without audio hardware.
//

import AVFoundation

@MainActor
final class VoiceConversationController: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case listening
        case thinking
        case speaking
    }

    @Published private(set) var isActive = false
    @Published private(set) var phase: Phase = .idle

    // Seams wired by the hosting view.
    var sendUtterance: ((String) -> Void)?
    var startListening: (() -> Void)?
    var stopListening: (() -> Void)?

    /// Seconds the transcript must stay unchanged (and non-empty) before
    /// the utterance is committed — the "user stopped talking" heuristic.
    var silenceWindow: TimeInterval = 1.6

    /// Injected for tests; default speaks through AVSpeechSynthesizer.
    var speakText: ((String) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var silenceTimer: Timer?
    private var lastTranscript = ""

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle() {
        isActive ? deactivate() : activate()
    }

    func activate() {
        isActive = true
        beginListening()
    }

    func deactivate() {
        isActive = false
        phase = .idle
        silenceTimer?.invalidate()
        silenceTimer = nil
        synthesizer.stopSpeaking(at: .immediate)
        stopListening?()
    }

    private func beginListening() {
        guard isActive else { return }
        lastTranscript = ""
        phase = .listening
        startListening?()
    }

    /// Live transcript feed. A non-empty transcript that stays stable for
    /// `silenceWindow` seconds commits the utterance to the chat.
    func transcriptChanged(_ transcript: String) {
        guard isActive, phase == .listening else { return }
        lastTranscript = transcript
        silenceTimer?.invalidate()
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceWindow,
                                            repeats: false) { [weak self] _ in
            Task { @MainActor in self?.commitUtterance() }
        }
    }

    private func commitUtterance() {
        guard isActive, phase == .listening else { return }
        let utterance = lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !utterance.isEmpty else { return }
        phase = .thinking
        stopListening?()
        sendUtterance?(utterance)
    }

    /// Speak a finished assistant reply aloud, then resume listening.
    func speakReply(_ markdown: String) {
        guard isActive else { return }
        let text = Self.speakableText(from: markdown)
        guard !text.isEmpty else {
            beginListening()
            return
        }
        phase = .speaking
        if let speakText {
            speakText(text)   // test seam
        } else {
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.voice = Self.bestAvailableVoice()
            synthesizer.speak(utterance)
        }
    }

    // MARK: - Voice selection

    /// The default system voice is the compact (robotic) one. Prefer the
    /// best neural voice the user has installed for their language:
    /// Premium > Enhanced > default. Cached per session.
    private static var cachedVoice: AVSpeechSynthesisVoice??
    static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        if let cached = cachedVoice { return cached }
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let identifier = pickVoiceIdentifier(
            voices: AVSpeechSynthesisVoice.speechVoices().map {
                (id: $0.identifier, language: $0.language,
                 qualityRank: $0.quality == .premium ? 2
                            : $0.quality == .enhanced ? 1 : 0)
            },
            language: language)
        let voice = identifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: language)
        cachedVoice = voice
        return voice
    }

    /// Pure selection: highest quality rank, exact-language matches
    /// preferred over same-primary-language ones. Nil when nothing fits.
    nonisolated static func pickVoiceIdentifier(
        voices: [(id: String, language: String, qualityRank: Int)],
        language: String
    ) -> String? {
        let primary = String(language.prefix(2))
        let candidates = voices.filter {
            $0.language == language || $0.language.hasPrefix(primary)
        }
        return candidates.max { lhs, rhs in
            if lhs.qualityRank != rhs.qualityRank {
                return lhs.qualityRank < rhs.qualityRank
            }
            return (lhs.language == language ? 1 : 0)
                 < (rhs.language == language ? 1 : 0)
        }?.id
    }

    /// True when only compact-quality voices are installed for the user's
    /// language — the UI shows a one-time "download a premium voice" tip.
    static var onlyCompactVoiceAvailable: Bool {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let primary = String(language.prefix(2))
        return !AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix(primary) && $0.quality != .default
        }
    }

    /// Barge-in: tap while the assistant is talking to skip to listening.
    func interruptSpeech() {
        guard phase == .speaking else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)  // delegate resumes listening
        } else {
            speechDidEnd()  // test seam path
        }
    }

    /// Delegate/system entry: a spoken reply finished or was cancelled.
    func speechDidEnd() {
        guard isActive else { return }
        beginListening()
    }

    /// Markdown → speech-friendly plain text: strips emphasis, code
    /// ticks, headings, list bullets; links speak their label.
    nonisolated static func speakableText(from markdown: String) -> String {
        var text = markdown
        text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)",
                                         with: "$1", options: .regularExpression)
        for pattern in ["\\*\\*", "__", "\\*", "`", "^#{1,6} ",
                        "(?m)^[-•] "] {
            text = text.replacingOccurrences(of: pattern, with: "",
                                             options: .regularExpression)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension VoiceConversationController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechDidEnd() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speechDidEnd() }
    }
}
