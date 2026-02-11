//
//  DoubleShiftMonitor.swift
//  DirectorsChair-Desktop
//
//  Global double-shift detector for AI Chat activation
//

import AppKit

@MainActor
final class DoubleShiftMonitor {
    static let shared = DoubleShiftMonitor()

    var onDoubleShift: (() -> Void)?

    private var monitor: Any?
    private var lastShiftReleaseTime: Date = .distantPast
    private var shiftIsDown = false
    private let threshold: TimeInterval = 0.4

    private init() {}

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
            return event
        }
    }

    func uninstall() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags
        let shiftPressed = flags.contains(.shift)

        // Ignore if other modifiers are held
        let otherMods: NSEvent.ModifierFlags = [.command, .option, .control]
        if !flags.intersection(otherMods).isEmpty {
            shiftIsDown = false
            return
        }

        if shiftPressed && !shiftIsDown {
            // Shift just went down
            shiftIsDown = true
        } else if !shiftPressed && shiftIsDown {
            // Shift just released
            shiftIsDown = false
            let now = Date()
            let elapsed = now.timeIntervalSince(lastShiftReleaseTime)
            if elapsed < threshold {
                lastShiftReleaseTime = .distantPast
                onDoubleShift?()
            } else {
                lastShiftReleaseTime = now
            }
        }
    }
}
