//
//  CommandTapMonitor.swift
//  DirectorsChair-Desktop
//
//  Bare ⌘-tap detector for hands-free dictation in the AI assistant:
//  pressing and releasing Command alone toggles the mic. A tap only counts
//  when NO other key or modifier was involved while ⌘ was down, so command
//  shortcuts (⌘C, ⌘A, …) never trigger it. Companion to DoubleShiftMonitor
//  (which opens the assistant); this one is overlay-scoped, installed only
//  while the chat is on screen.
//

import AppKit

/// The pure tap state machine — testable without AppKit events.
struct BareModifierTapDetector {
    enum Event {
        case modifierDown          // ⌘ pressed with no other modifiers
        case modifierUp            // ⌘ released
        case interrupted           // any other key or modifier while ⌘ held
    }

    private var armed = false

    /// Feeds one event; returns true when a completed bare tap fired.
    mutating func handle(_ event: Event) -> Bool {
        switch event {
        case .modifierDown:
            armed = true
            return false
        case .interrupted:
            armed = false
            return false
        case .modifierUp:
            defer { armed = false }
            return armed
        }
    }
}

@MainActor
final class CommandTapMonitor {
    var onTap: (() -> Void)?

    private var detector = BareModifierTapDetector()
    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    private var commandIsDown = false

    func install() {
        guard flagsMonitor == nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.commandIsDown {
                _ = self.detector.handle(.interrupted)
            }
            return event
        }
    }

    func uninstall() {
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        flagsMonitor = nil
        keyMonitor = nil
        commandIsDown = false
        detector = BareModifierTapDetector()
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags
        let commandPressed = flags.contains(.command)
        let othersPressed = !flags
            .intersection([.shift, .option, .control, .function])
            .isEmpty

        if commandPressed && !commandIsDown {
            commandIsDown = true
            _ = detector.handle(othersPressed ? .interrupted : .modifierDown)
        } else if commandPressed && othersPressed {
            _ = detector.handle(.interrupted)
        } else if !commandPressed && commandIsDown {
            commandIsDown = false
            if detector.handle(.modifierUp) {
                onTap?()
            }
        }
    }
}
