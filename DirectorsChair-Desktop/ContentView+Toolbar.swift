//
// ContentView+Toolbar.swift
//
// Extracted from ContentView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were already internal helper views.
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairProduction
import DirectorsChairServices


// MARK: - App Toolbar

struct AppToolbar: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var tourManager: GuidedTourManager
    @EnvironmentObject var captureService: LiveCaptureService
    @EnvironmentObject var cloudSyncManager: CloudSyncManager

    var body: some View {
        HStack(spacing: 0) {
            // View Selection (Radio Button Group) — excludes Projects (moved to right)
            HStack(spacing: 4) {
                ForEach(AppView.allCases.filter { $0 != .projects }) { view in
                    let button = Button(action: {
                        debugLog("🖱️ Button pressed: \(view.rawValue)")
                        coordinator.navigateTo(view)
                        debugLog("🖱️ Button action complete: \(view.rawValue)")
                    }) {
                        Label(view.rawValue, systemImage: view.icon)
                            .labelStyle(.iconOnly)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(ToolbarButtonStyle(isSelected: coordinator.selectedView == view, tooltipText: view.rawValue))
                    .accessibilityIdentifier("nav-\(view.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    .accessibilityAddTraits(coordinator.selectedView == view ? [.isSelected] : [])
                    .spotlightTarget(id: "toolbar-\(view.rawValue)")

                    // Add hint dots on specific toolbar buttons
                    if view == .visionBoard {
                        button.hintDot(id: "hint-vision-board", title: "Vision Board", description: "Create mood boards and visual references")
                    } else {
                        button
                    }
                }
            }
            .padding(.leading, 12)

            Spacer()

            // Toggle Controls
            HStack(spacing: 8) {
                // Projects folder button (moved from left tab group)
                Button(action: {
                    coordinator.navigateTo(.projects)
                }) {
                    Label("Projects", systemImage: "folder")
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToolbarButtonStyle(isSelected: coordinator.selectedView == .projects, tooltipText: "Projects"))
                .accessibilityIdentifier("nav-projects")

                if coordinator.showingUsageWidget {
                    AIUsageWidget(projectStorageSize: projectViewModel.projectStorageSize)
                }

                Divider()
                    .frame(height: 20)

                // Global capture device selector
                CaptureDeviceToolbarItem(captureService: captureService)

                Divider()
                    .frame(height: 20)

                // Cloud sync status
                SyncStatusView(syncManager: cloudSyncManager)

                // Account menu
                AccountMenuView()

                Divider()
                    .frame(height: 20)

                Button(action: {
                    coordinator.toggleNavigator()
                }) {
                    Image(systemName: "sidebar.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingNavigator, tooltipText: "Navigator (⌘⌥1)"))
                .spotlightTarget(id: "toggle-navigator")
                .accessibilityLabel("Navigator")
                .accessibilityValue(coordinator.showingNavigator ? "shown" : "hidden")
                .accessibilityIdentifier("toggle-navigator")

                Button(action: {
                    coordinator.toggleTimeline()
                }) {
                    Image(systemName: "waveform")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingTimeline, tooltipText: "Timeline (⌘⌥2)"))
                .hintDot(id: "hint-ai-chat", title: "AI Chat Assistant", description: "Press Shift twice to open the AI Chat assistant")
                .accessibilityLabel("Timeline")
                .accessibilityValue(coordinator.showingTimeline ? "shown" : "hidden")
                .accessibilityIdentifier("toggle-timeline")

                Button(action: {
                    coordinator.toggleRightPanel()
                }) {
                    Image(systemName: "sidebar.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingRightPanel, tooltipText: "Right Panel (⌘⌥3)"))
                .accessibilityLabel("Right Panel")
                .accessibilityValue(coordinator.showingRightPanel ? "shown" : "hidden")
                .accessibilityIdentifier("toggle-right-panel")
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }
}

// MARK: - Capture Device Toolbar Item

/// Compact capture device selector for the app toolbar — sets default video source globally.
/// Does NOT start a capture session. The TakesSectionView auto-connects when it appears.
struct CaptureDeviceToolbarItem: View {
    @ObservedObject var captureService: LiveCaptureService
    @State private var showingHardwarePopover = false

    private var hasDefault: Bool { captureService.defaultDevice != nil }
    private var isLive: Bool { captureService.isSessionRunning }

    var body: some View {
        Button {
            showingHardwarePopover.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(isLive ? Color.green : hasDefault ? Color.accentColor : Color.gray.opacity(0.35))
                    .frame(width: 7, height: 7)

                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 11))
                    .foregroundColor(hasDefault ? .primary : .secondary)

                if let device = captureService.defaultDevice {
                    Text(device.localizedName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                } else {
                    Text("No Device")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isLive ? Color.green.opacity(0.08)
                          : hasDefault ? Color.accentColor.opacity(0.06)
                          : Color(nsColor: .quaternarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isLive ? Color.green.opacity(0.2)
                            : hasDefault ? Color.accentColor.opacity(0.15)
                            : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingHardwarePopover, arrowEdge: .bottom) {
            HardwarePopoverView(captureService: captureService)
        }
    }
}

// MARK: - Instant Tooltip using NSWindow

/// A floating tooltip window that appears instantly on hover
class TooltipWindowController {
    static let shared = TooltipWindowController()

    private var window: NSWindow?
    private var textField: NSTextField?

    private init() {}

    func show(text: String, near point: NSPoint) {
        debugLog("🪟 TooltipWindow.show: '\(text)' near \(point)")
        hide()

        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.systemFont(ofSize: 11)
        textField.textColor = NSColor.labelColor
        textField.backgroundColor = NSColor.windowBackgroundColor
        textField.isBordered = false
        textField.sizeToFit()

        let padding: CGFloat = 8
        let contentSize = NSSize(
            width: textField.frame.width + padding * 2,
            height: textField.frame.height + padding
        )

        textField.frame.origin = NSPoint(x: padding, y: padding / 2)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 4
        window.contentView?.addSubview(textField)

        // Position below the mouse cursor
        let screenPoint = NSPoint(
            x: point.x - contentSize.width / 2,
            y: point.y - contentSize.height - 20
        )
        debugLog("🪟 TooltipWindow positioning at: \(screenPoint)")
        window.setFrameOrigin(screenPoint)
        window.orderFront(nil)

        self.window = window
        self.textField = textField
        debugLog("🪟 TooltipWindow shown")
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        textField = nil
    }
}


// MARK: - Toolbar Button Styles

struct ToolbarButtonStyle: ButtonStyle {
    let isSelected: Bool
    var tooltipText: String = ""
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.2)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { hovering in
                isHovered = hovering
                if !tooltipText.isEmpty {
                    if hovering {
                        let mouseLocation = NSEvent.mouseLocation
                        TooltipWindowController.shared.show(text: tooltipText, near: mouseLocation)
                    } else {
                        TooltipWindowController.shared.hide()
                    }
                }
            }
    }
}

struct ToggleButtonStyle: ButtonStyle {
    let isActive: Bool
    var tooltipText: String = ""
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(0.15)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { hovering in
                isHovered = hovering
                if !tooltipText.isEmpty {
                    if hovering {
                        let mouseLocation = NSEvent.mouseLocation
                        TooltipWindowController.shared.show(text: tooltipText, near: mouseLocation)
                    } else {
                        TooltipWindowController.shared.hide()
                    }
                }
            }
    }
}
