//
//  RemoteControlService.swift
//  DirectorsChair-Desktop
//
//  Remote control button mapping — learn clicker buttons
//  and map them to app actions (start/stop take recording).
//
//  USB clickers send a BURST of keyCodes per physical button press
//  (e.g. Esc → Return → P → F5 within ~200ms). We suppress the
//  entire burst using two mechanisms:
//    1. Escape preamble sets a 500ms window — all keys within it are
//       treated as part of the same clicker burst.
//    2. Matched (mapped) keys also set a 500ms trailing window.
//  Mapped keys always fire their action, even within a burst window.
//  Unmapped keys within a burst window are silently consumed.
//

import AppKit
import AVFAudio
import Combine

// MARK: - Remote Action

enum RemoteAction: String, CaseIterable, Identifiable, Codable {
    case startTakeRecording
    case stopTakeRecording

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .startTakeRecording: return "Start Take Recording"
        case .stopTakeRecording: return "Stop Take Recording"
        }
    }

    var systemImage: String {
        switch self {
        case .startTakeRecording: return "record.circle"
        case .stopTakeRecording: return "stop.circle"
        }
    }

    var notificationName: Notification.Name {
        Notification.Name("remoteControl.\(rawValue)")
    }
}

// MARK: - Key Mapping

struct KeyMapping: Codable, Equatable {
    let keyCode: UInt16
    let action: String
    let keyName: String
}

// MARK: - Remote Control Service

final class RemoteControlService: ObservableObject {
    static let shared = RemoteControlService()

    @Published var mappings: [RemoteAction: KeyMapping] = [:]
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "pref.remote.enabled")
        }
    }
    @Published var learningAction: RemoteAction?

    private var monitor: Any?
    private var keyUpMonitor: Any?
    private var flagsMonitor: Any?

    /// Timestamp of last burst activity (Escape preamble or matched key).
    /// ALL keys within burstWindow of this time are considered clicker burst keys.
    private var lastBurstTime: Date = .distantPast
    private let burstWindow: TimeInterval = 0.5

    /// Debounce: last action fired + time — prevent double-fires from clicker bursts
    private var lastFiredAction: RemoteAction?
    private var lastFiredTime: Date = .distantPast
    private let debounceWindow: TimeInterval = 0.4

    /// Set of all mapped keyCodes for quick lookup
    private var mappedKeyCodes: Set<UInt16> {
        Set(mappings.values.map { $0.keyCode })
    }

    /// Audio player for the ready sound — kept alive on the singleton
    private var audioPlayer: AVAudioPlayer?

    /// Audio player for the recording start tone
    private var recordingTonePlayer: AVAudioPlayer?

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "pref.remote.enabled")
        loadMappings()

        // Pre-load the ready sound from the app bundle
        if let url = Bundle.main.url(forResource: "ready", withExtension: "mp3") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        }

        // Pre-load the recording start tone (macOS built-in "Glass" sound)
        if let url = NSSound(named: "Glass")?.name.flatMap({ _ in
            URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
        }) {
            recordingTonePlayer = try? AVAudioPlayer(contentsOf: url)
            recordingTonePlayer?.prepareToPlay()
        }

        // Listen for announce requests from other packages (e.g. TakesSectionView)
        NotificationCenter.default.addObserver(
            forName: Notification.Name("remoteControl.announce"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.playReadySound()
        }

        // Listen for recording start tone requests
        NotificationCenter.default.addObserver(
            forName: Notification.Name("remoteControl.recordingStartTone"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.playRecordingTone()
        }
    }

    // MARK: - Monitor Lifecycle

    func installGlobalKeyMonitor() {
        guard monitor == nil else { return }

        NSLog("[RemoteControl] Installing monitors. enabled=%d, mappings=%d", isEnabled ? 1 : 0, mappings.count)

        // Monitor keyDown
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [unowned self] event -> NSEvent? in
            guard self.isEnabled else { return event }

            // Don't intercept keys when a text editor is focused — let the editor handle them
            if let responder = event.window?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            let keyCode = event.keyCode
            let now = Date()

            // Learn mode: capture first non-Escape key
            if self.learningAction != nil {
                if keyCode == 53 { return nil } // skip Escape in learn mode too
                let keyName = self.humanReadableKeyName(for: keyCode, event: event)
                let action = self.learningAction!
                self.assignKey(keyCode, keyName: keyName, to: action)
                self.learningAction = nil
                self.lastBurstTime = now
                return nil
            }

            guard !self.mappings.isEmpty else { return event }

            // Escape is always a clicker preamble — suppress and start burst window
            if keyCode == 53 {
                self.lastBurstTime = now
                return nil
            }

            // Check if this key is mapped → fire action (with debounce)
            for (action, mapping) in self.mappings {
                if mapping.keyCode == keyCode {
                    self.lastBurstTime = now

                    // Debounce: skip if same action fired recently
                    if action == self.lastFiredAction &&
                       now.timeIntervalSince(self.lastFiredTime) < self.debounceWindow {
                        return nil
                    }

                    self.lastFiredAction = action
                    self.lastFiredTime = now
                    NSLog("[RemoteControl] Action fired: %@", action.rawValue)
                    NotificationCenter.default.post(name: action.notificationName, object: nil)
                    return nil
                }
            }

            // Suppress ANY unmatched key within burst window (clicker trailing keys)
            if now.timeIntervalSince(self.lastBurstTime) < self.burstWindow {
                return nil
            }

            // Not a clicker key — pass through to the app normally
            return event
        }

        // Suppress keyUp events for mapped/burst keys (prevents beep)
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [unowned self] event -> NSEvent? in
            guard self.isEnabled, !self.mappings.isEmpty else { return event }
            let keyCode = event.keyCode

            if keyCode == 53 { return nil }
            if self.mappedKeyCodes.contains(keyCode) { return nil }
            if Date().timeIntervalSince(self.lastBurstTime) < self.burstWindow { return nil }

            return event
        }

        // Suppress flagsChanged events (modifier keys) within burst window
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [unowned self] event -> NSEvent? in
            guard self.isEnabled, !self.mappings.isEmpty else { return event }
            if Date().timeIntervalSince(self.lastBurstTime) < self.burstWindow { return nil }
            return event
        }
    }

    // Legacy
    func install() {}
    func uninstall() {}

    // MARK: - Sound

    /// Plays the bundled ready.mp3 sound
    func playReadySound() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }

    /// Plays a short tone when recording starts
    func playRecordingTone() {
        recordingTonePlayer?.currentTime = 0
        recordingTonePlayer?.play()
    }

    // MARK: - Learning

    func startLearning(_ action: RemoteAction) {
        learningAction = action
    }

    func cancelLearning() {
        learningAction = nil
    }

    // MARK: - Mapping Management

    func assignKey(_ keyCode: UInt16, keyName: String, to action: RemoteAction) {
        for (existingAction, existingMapping) in mappings {
            if existingMapping.keyCode == keyCode && existingAction != action {
                mappings.removeValue(forKey: existingAction)
            }
        }

        mappings[action] = KeyMapping(keyCode: keyCode, action: action.rawValue, keyName: keyName)
        persistMappings()
    }

    func removeMapping(for action: RemoteAction) {
        mappings.removeValue(forKey: action)
        persistMappings()
    }

    func clearAllMappings() {
        mappings.removeAll()
        persistMappings()
    }

    // MARK: - Persistence

    private func persistMappings() {
        let dict = mappings.map { ($0.key.rawValue, $0.value) }
        let encodable = Dictionary(uniqueKeysWithValues: dict)
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: "pref.remote.keyMappings")
        }
    }

    private func loadMappings() {
        guard let data = UserDefaults.standard.data(forKey: "pref.remote.keyMappings"),
              let decoded = try? JSONDecoder().decode([String: KeyMapping].self, from: data) else { return }

        for (key, mapping) in decoded {
            if let action = RemoteAction(rawValue: key) {
                mappings[action] = mapping
            }
        }
    }

    // MARK: - Key Name Lookup

    func humanReadableKeyName(for keyCode: UInt16, event: NSEvent? = nil) -> String {
        let knownKeys: [UInt16: String] = [
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15",
            126: "Up", 125: "Down", 123: "Left", 124: "Right",
            116: "Page Up", 121: "Page Down",
            115: "Home", 119: "End",
            36: "Return", 76: "Enter",
            49: "Space", 53: "Escape", 51: "Delete",
            117: "Forward Delete", 48: "Tab",
            173: "<<", 175: ">>", 174: "Vol-", 176: "Vol+",
        ]

        if let name = knownKeys[keyCode] {
            return name
        }

        if let chars = event?.charactersIgnoringModifiers, !chars.isEmpty {
            return chars.uppercased()
        }

        return "Key \(keyCode)"
    }
}
