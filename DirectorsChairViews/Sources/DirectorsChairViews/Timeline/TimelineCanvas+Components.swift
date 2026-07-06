//
// TimelineCanvas+Components.swift
//
// Extracted from TimelineCanvas.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import Foundation


// MARK: - Canvas Right-Click Overlay

/// Invisible overlay that intercepts right-mouse-down events on the canvas
struct CanvasRightClickOverlay: NSViewRepresentable {
    var onRightClick: (CGPoint, NSView) -> Void

    func makeNSView(context: Context) -> CanvasRightClickNSView {
        let view = CanvasRightClickNSView()
        view.onRightClick = onRightClick
        view.installMonitor()
        return view
    }

    func updateNSView(_ nsView: CanvasRightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    class CanvasRightClickNSView: NSView {
        var onRightClick: ((CGPoint, NSView) -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func installMonitor() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self = self, let window = self.window, event.window === window else {
                    return event
                }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(locationInView) {
                    let flippedY = self.bounds.height - locationInView.y
                    let point = CGPoint(x: locationInView.x, y: flippedY)
                    self.onRightClick?(point, self)
                }
                return event
            }
        }

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// NSObject target for NSMenu items — holds a closure for the menu action
class CanvasMenuHandler: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    @objc func execute() {
        action()
    }
}

// MARK: - Timeline Mode

/// Timeline view mode
public enum TimelineMode: String, Sendable {
    case scene      // Single scene view
    case sequence   // All scenes in a sequence
    case global     // All sequences and scenes
}
