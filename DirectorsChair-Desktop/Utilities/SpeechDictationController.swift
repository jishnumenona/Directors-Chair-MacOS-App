//
//  SpeechDictationController.swift
//  DirectorsChair-Desktop
//
//  Voice input for the AI assistant: on-device speech-to-text via Apple's
//  Speech framework. Cumulative partial transcripts stream into the chat
//  input field while recording (mergedInput preserves anything already
//  typed); recognition runs on-device whenever the model supports it —
//  private, free, and offline-capable. Permission denials surface as
//  actionable guidance, never silence.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechDictationController: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case denied(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    /// Cumulative partial transcript for the current dictation session.
    @Published private(set) var transcript: String = ""

    var isRecording: Bool { state == .recording }

    /// The user guidance for the current problem state, if any.
    var problemMessage: String? {
        switch state {
        case .denied(let message), .failed(let message): return message
        case .idle, .recording: return nil
        }
    }

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// What the input field should contain while dictating: the text typed
    /// before dictation began, then the live transcript. Partials are
    /// cumulative, so the transcript REPLACES its previous value.
    static func mergedInput(typedPrefix: String, transcript: String) -> String {
        guard !transcript.isEmpty else { return typedPrefix }
        guard !typedPrefix.isEmpty else { return transcript }
        let joiner = typedPrefix.hasSuffix(" ") ? "" : " "
        return typedPrefix + joiner + transcript
    }

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        guard !isRecording else { return }
        transcript = ""
        state = .idle
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.requestMicrophoneThenBegin()
                case .denied, .restricted:
                    self.state = .denied("Enable Speech Recognition for Director's Chair in System Settings → Privacy & Security → Speech Recognition.")
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func requestMicrophoneThenBegin() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard granted else {
                    self.state = .denied("Enable Microphone access for Director's Chair in System Settings → Privacy & Security → Microphone.")
                    return
                }
                self.begin()
            }
        }
    }

    private func begin() {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            state = .failed("Speech recognition isn't available right now — check your internet connection or language settings.")
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            state = .failed("No microphone input is available.")
            return
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            state = .failed("Couldn't start the microphone: \(error.localizedDescription)")
            return
        }

        state = .recording
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil, self.isRecording {
                    // Mid-session failure (model unavailable, audio route
                    // change): stop cleanly, keep whatever was transcribed.
                    self.teardownAudio()
                    self.state = self.transcript.isEmpty
                        ? .failed("Dictation stopped unexpectedly. Please try again.")
                        : .idle
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        request?.endAudio()
        task?.finish()
        teardownAudio()
        state = .idle
    }

    private func teardownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request = nil
        task = nil
    }
}
