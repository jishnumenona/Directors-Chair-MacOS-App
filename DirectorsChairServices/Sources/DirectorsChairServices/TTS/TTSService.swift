// DirectorsChairServices/Sources/DirectorsChairServices/TTS/TTSService.swift
//
// Text-to-Speech Service using AVFoundation
// Supports macOS built-in voices with character-specific selection

import Foundation
import AVFoundation
import Combine

// MARK: - Voice

/// Represents a TTS voice
public struct Voice: Sendable, Identifiable, Hashable {
    public var id: String { identifier }
    public var name: String
    public var gender: VoiceGender
    public var language: String
    public var identifier: String
    
    public init(name: String, gender: VoiceGender, language: String = "en", identifier: String = "") {
        self.name = name
        self.gender = gender
        self.language = language
        self.identifier = identifier.isEmpty ? name : identifier
    }
}

/// Voice gender
public enum VoiceGender: String, Sendable {
    case male
    case female
    case neutral
}

// MARK: - TTS Events

/// Events emitted by the TTS service
public enum TTSEvent: Sendable {
    case speechStarted(String)
    case speechFinished(String)
    case speechError(String)
    case speechProgress(Double)
}

// MARK: - TTS Service

/// Text-to-Speech service using AVFoundation
@MainActor
public final class TTSService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var availableVoices: [Voice] = []
    @Published public private(set) var currentText: String = ""
    
    // MARK: - Properties
    
    private let synthesizer: AVSpeechSynthesizer
    private var eventSubject = PassthroughSubject<TTSEvent, Never>()
    private var speechContinuation: CheckedContinuation<Void, Never>?
    
    /// Publisher for TTS events
    public var events: AnyPublisher<TTSEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Shared instance
    public static let shared = TTSService()
    
    // MARK: - Initialization
    
    public override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
        loadAvailableVoices()
    }
    
    // MARK: - Voice Management
    
    /// Load available system voices
    private func loadAvailableVoices() {
        let systemVoices = AVSpeechSynthesisVoice.speechVoices()
        
        availableVoices = systemVoices.compactMap { voice -> Voice? in
            // Filter to English voices primarily
            guard voice.language.hasPrefix("en") else { return nil }
            
            let gender = detectGender(voiceName: voice.name)
            
            return Voice(
                name: voice.name,
                gender: gender,
                language: voice.language,
                identifier: voice.identifier
            )
        }
        
        // If no voices found, add defaults
        if availableVoices.isEmpty {
            setupDefaultVoices()
        }
    }
    
    /// Setup default voices as fallback
    private func setupDefaultVoices() {
        availableVoices = [
            Voice(name: "Alex", gender: .male, identifier: "com.apple.speech.synthesis.voice.Alex"),
            Voice(name: "Samantha", gender: .female, identifier: "com.apple.speech.synthesis.voice.samantha"),
            Voice(name: "Victoria", gender: .female, identifier: "com.apple.speech.synthesis.voice.Victoria"),
            Voice(name: "Daniel", gender: .male, identifier: "com.apple.speech.synthesis.voice.daniel"),
            Voice(name: "Fiona", gender: .female, identifier: "com.apple.speech.synthesis.voice.fiona"),
            Voice(name: "Fred", gender: .male, identifier: "com.apple.speech.synthesis.voice.Fred")
        ]
    }
    
    /// Detect gender based on voice name patterns
    private func detectGender(voiceName: String) -> VoiceGender {
        let name = voiceName.lowercased()
        
        let femaleNames = ["samantha", "victoria", "allison", "ava", "fiona",
                          "kathy", "princess", "tessa", "karen", "susan",
                          "moira", "kate", "serena", "veena", "zoe"]
        
        let maleNames = ["alex", "daniel", "fred", "jorge", "tom", "diego",
                        "ralph", "bruce", "junior", "albert", "lee", "oliver",
                        "rishi", "aaron", "nathan", "gordon"]
        
        if femaleNames.contains(where: { name.contains($0) }) {
            return .female
        } else if maleNames.contains(where: { name.contains($0) }) {
            return .male
        } else {
            return .neutral
        }
    }
    
    /// Get the best voice for a character
    public func getVoiceForCharacter(
        gender: String,
        name: String = "",
        preferredVoice: String? = nil
    ) -> Voice {
        // If a specific voice is selected, try to use it
        if let preferred = preferredVoice,
           let voice = availableVoices.first(where: { $0.name == preferred }) {
            return voice
        }
        
        // Convert gender string
        let genderEnum: VoiceGender
        switch gender.lowercased() {
        case "male": genderEnum = .male
        case "female": genderEnum = .female
        default: genderEnum = .neutral
        }
        
        // Find matching gender voices
        let matchingVoices = availableVoices.filter { $0.gender == genderEnum }
        
        if let firstMatch = matchingVoices.first {
            // Try to find a name match
            if !name.isEmpty {
                let nameLower = name.lowercased()
                if let nameMatch = matchingVoices.first(where: {
                    nameLower.contains($0.name.lowercased()) ||
                    $0.name.lowercased().contains(nameLower)
                }) {
                    return nameMatch
                }
            }
            return firstMatch
        }
        
        // Fallback to any available voice
        return availableVoices.first ?? Voice(name: "Alex", gender: .male, identifier: "com.apple.speech.synthesis.voice.Alex")
    }
    
    // MARK: - Speech Control
    
    /// Speak the given text
    @discardableResult
    public func speak(
        text: String,
        characterGender: String = "neutral",
        characterName: String = "",
        voiceName: String = "",
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0,
        volume: Float = 1.0
    ) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Stop current speech if any
        if isSpeaking {
            stop()
        }
        
        // Choose voice
        let voice: Voice
        if !voiceName.isEmpty, let v = availableVoices.first(where: { $0.name.lowercased() == voiceName.lowercased() }) {
            voice = v
        } else {
            voice = getVoiceForCharacter(gender: characterGender, name: characterName)
        }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        
        if let avVoice = AVSpeechSynthesisVoice(identifier: voice.identifier) {
            utterance.voice = avVoice
        } else if let avVoice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = avVoice
        }
        
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        // Start speaking
        currentText = text
        synthesizer.speak(utterance)
        
        return true
    }
    
    /// Speak text and wait for completion
    public func speakAsync(
        text: String,
        characterGender: String = "neutral",
        characterName: String = "",
        voiceName: String = ""
    ) async {
        await withCheckedContinuation { continuation in
            self.speechContinuation = continuation
            let started = speak(
                text: text,
                characterGender: characterGender,
                characterName: characterName,
                voiceName: voiceName
            )
            if !started {
                self.speechContinuation = nil
                continuation.resume()
            }
        }
    }
    
    /// Stop current speech
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentText = ""
        
        // Resume any waiting continuation
        speechContinuation?.resume()
        speechContinuation = nil
    }
    
    /// Pause current speech
    public func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    /// Resume paused speech
    public func resume() {
        synthesizer.continueSpeaking()
    }
    
    // MARK: - Dialogue Sequence
    
    /// Speak a sequence of dialogues with pauses between them
    public func speakDialogueSequence(
        dialogues: [(text: String, gender: String, name: String, voice: String?)],
        pauseDuration: TimeInterval = 1.0
    ) async {
        for (index, dialogue) in dialogues.enumerated() {
            guard !dialogue.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            await speakAsync(
                text: dialogue.text,
                characterGender: dialogue.gender,
                characterName: dialogue.name,
                voiceName: dialogue.voice ?? ""
            )
            
            // Pause between dialogues (except after the last one)
            if index < dialogues.count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(pauseDuration * 1_000_000_000))
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSService: AVSpeechSynthesizerDelegate {
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
            self.eventSubject.send(.speechStarted(utterance.speechString))
        }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentText = ""
            self.eventSubject.send(.speechFinished(utterance.speechString))
            
            // Resume any waiting continuation
            self.speechContinuation?.resume()
            self.speechContinuation = nil
        }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentText = ""
            
            // Resume any waiting continuation
            self.speechContinuation?.resume()
            self.speechContinuation = nil
        }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let progress = Double(characterRange.location) / Double(utterance.speechString.count)
        Task { @MainActor in
            self.eventSubject.send(.speechProgress(progress))
        }
    }
}

// MARK: - Global TTS Instance

/// Get the global TTS service instance
@MainActor
public func getTTSService() -> TTSService {
    return TTSService.shared
}
