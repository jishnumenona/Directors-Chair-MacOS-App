//
//  ViewCommands.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  View menu commands for navigation
//

import SwiftUI
import AppKit
import DirectorsChairViews

struct ViewCommands: Commands {
    // Injected app-scoped references (WS-fix: @FocusedValue returns nil when
    // focus is in an AppKit view or nothing has focus, which silently disabled
    // EVERY menu shortcut). Focused values remain as a fallback only.
    var coordinatorRef: AppCoordinator?
    var projectViewModelRef: ProjectViewModel?
    @FocusedValue(\.appCoordinator) var focusedCoordinator: AppCoordinator?
    @FocusedValue(\.projectViewModel) var focusedProjectViewModel: ProjectViewModel?
    var coordinator: AppCoordinator? { coordinatorRef ?? focusedCoordinator }
    var projectViewModel: ProjectViewModel? { projectViewModelRef ?? focusedProjectViewModel }

    /// §2.18: rebindable shortcuts come from the store; observing it
    /// re-renders the menu the moment a binding changes.
    @ObservedObject private var shortcuts = ShortcutStore.shared

    init(coordinatorRef: AppCoordinator? = nil, projectViewModelRef: ProjectViewModel? = nil) {
        self.coordinatorRef = coordinatorRef
        self.projectViewModelRef = projectViewModelRef
    }

    var body: some Commands {
        CommandMenu("View") {
            Button("Command Palette…") {
                coordinator?.showingCommandPalette.toggle()
            }
            .keyboardShortcut(shortcuts.spec(for: "tool.palette").keyboardShortcutOrDefault)

            Divider()

            // Main Views
            Menu("Go to View") {
                Button("Project Overview") {
                    coordinator?.navigateTo(.overview)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Overview").keyboardShortcutOrDefault)

                Button("Bubble View") {
                    coordinator?.navigateTo(.bubble)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Bubble").keyboardShortcutOrDefault)

                Button("Scenes") {
                    coordinator?.navigateTo(.scenes)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Scenes").keyboardShortcutOrDefault)

                Button("Assets") {
                    coordinator?.navigateTo(.assets)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Assets").keyboardShortcutOrDefault)

                Divider()

                Button("Vision Board") {
                    coordinator?.navigateTo(.visionBoard)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Vision Board").keyboardShortcutOrDefault)

                Button("Shot List") {
                    coordinator?.navigateTo(.shotList)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Shot List").keyboardShortcutOrDefault)

                Button("Production") {
                    coordinator?.navigateTo(.production)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Production").keyboardShortcutOrDefault)

                Divider()

                Button("Story Design") {
                    coordinator?.navigateTo(.storyDesign)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Story Design").keyboardShortcutOrDefault)

                Button("Project Settings") {
                    coordinator?.navigateTo(.settings)
                }
                .keyboardShortcut(shortcuts.spec(for: "nav.Settings").keyboardShortcutOrDefault)
            }

            Divider()

            // Panel Toggles
            Button("Toggle Navigator") {
                coordinator?.toggleNavigator()
            }
            .keyboardShortcut(shortcuts.spec(for: "panel.navigator").keyboardShortcutOrDefault)

            Button("Toggle Timeline") {
                coordinator?.toggleTimeline()
            }
            .keyboardShortcut(shortcuts.spec(for: "panel.timeline").keyboardShortcutOrDefault)

            Button("Toggle Right Panel") {
                coordinator?.toggleRightPanel()
            }
            .keyboardShortcut(shortcuts.spec(for: "panel.rightPanel").keyboardShortcutOrDefault)

            Button("Toggle Comments") {
                coordinator?.toggleComments()
            }
            .keyboardShortcut(shortcuts.spec(for: "panel.comments").keyboardShortcutOrDefault)

            Button("Toggle Usage Widget") {
                coordinator?.toggleUsageWidget()
            }
            .keyboardShortcut(shortcuts.spec(for: "panel.usage").keyboardShortcutOrDefault)

            Divider()

            // View Options
            Button("Show All Panels") {
                coordinator?.showingNavigator = true
                coordinator?.showingTimeline = true
                coordinator?.showingRightPanel = true
            }
            .keyboardShortcut("a", modifiers: [.command, .option])

            Button("Hide All Panels") {
                coordinator?.showingNavigator = false
                coordinator?.showingTimeline = false
                coordinator?.showingRightPanel = false
            }
            .keyboardShortcut("h", modifiers: [.command, .option])

            Divider()

            Button("AI Chat Assistant") {
                coordinator?.toggleAIChat()
            }
            .keyboardShortcut(" ", modifiers: [.command, .shift])

            Divider()

            // Project Folder
            Button("Open Project Folder in Finder") {
                guard let projectPath = projectViewModel?.projectPath else { return }
                let projectDir = projectPath.deletingLastPathComponent()
                NSWorkspace.shared.open(projectDir)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(projectViewModel?.projectPath == nil)
        }
    }
}

// MARK: - Remappable shortcuts (§2.18)
//
// The store owns WHICH commands are rebindable, their shipped defaults,
// and the user's overrides (UserDefaults). Commands structs observe it,
// so a rebind re-renders the menus live. ShortcutSpec (the value type)
// lives in DirectorsChairViews.

/// A command a user may rebind: stable id, menu label, shipped default.
struct RebindableCommand: Identifiable {
    let id: String
    let label: String
    let group: String
    let defaultSpec: ShortcutSpec
}

@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    /// The whole rebindable surface. Navigation ⌘1–9, panels ⌥⌘1–5, the
    /// palette, snapshots, exports. File-menu staples (⌘S/N/O/W) stay
    /// fixed — retraining ⌘S helps nobody and breaks muscle memory the
    /// platform owns. NOTE the Force Save default is ⌃⌘S: its old ⌥⌘S
    /// collided with Project Snapshots (a latent clash this feature's
    /// conflict rule now makes impossible to reintroduce).
    static let commands: [RebindableCommand] = [
        .init(id: "nav.Overview", label: "Go to Overview", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "1", command: true)),
        .init(id: "nav.Bubble", label: "Go to Bubble View", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "2", command: true)),
        .init(id: "nav.Scenes", label: "Go to Scenes", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "3", command: true)),
        .init(id: "nav.Assets", label: "Go to Assets", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "4", command: true)),
        .init(id: "nav.Vision Board", label: "Go to Vision Board", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "5", command: true)),
        .init(id: "nav.Shot List", label: "Go to Shot List", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "6", command: true)),
        .init(id: "nav.Production", label: "Go to Production", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "7", command: true)),
        .init(id: "nav.Story Design", label: "Go to Story Design", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "8", command: true)),
        .init(id: "nav.Settings", label: "Go to Project Settings", group: "Navigation",
              defaultSpec: ShortcutSpec(key: "9", command: true)),
        .init(id: "tool.palette", label: "Command Palette", group: "Tools",
              defaultSpec: ShortcutSpec(key: "k", command: true)),
        .init(id: "panel.navigator", label: "Toggle Navigator", group: "Panels",
              defaultSpec: ShortcutSpec(key: "1", command: true, option: true)),
        .init(id: "panel.timeline", label: "Toggle Timeline", group: "Panels",
              defaultSpec: ShortcutSpec(key: "2", command: true, option: true)),
        .init(id: "panel.rightPanel", label: "Toggle Right Panel", group: "Panels",
              defaultSpec: ShortcutSpec(key: "3", command: true, option: true)),
        .init(id: "panel.comments", label: "Toggle Comments", group: "Panels",
              defaultSpec: ShortcutSpec(key: "4", command: true, option: true)),
        .init(id: "panel.usage", label: "Toggle Usage Widget", group: "Panels",
              defaultSpec: ShortcutSpec(key: "5", command: true, option: true)),
        .init(id: "file.snapshots", label: "Project Snapshots", group: "File",
              defaultSpec: ShortcutSpec(key: "s", command: true, option: true)),
        .init(id: "file.forceSave", label: "Force Save", group: "File",
              defaultSpec: ShortcutSpec(key: "s", command: true, control: true)),
        .init(id: "export.fountain", label: "Export Fountain", group: "Export",
              defaultSpec: ShortcutSpec(key: "e", command: true, shift: true)),
        .init(id: "export.pdf", label: "Export PDF", group: "Export",
              defaultSpec: ShortcutSpec(key: "p", command: true, shift: true)),
        .init(id: "export.batch", label: "Batch Export", group: "Export",
              defaultSpec: ShortcutSpec(key: "e", command: true, shift: true,
                                        option: true)),
    ]

    /// Platform staples no rebind may claim — taking ⌘S for "Go to
    /// Scenes" would shadow Save app-wide.
    static let protectedCombos: [ShortcutSpec] = [
        ShortcutSpec(key: "s", command: true),
        ShortcutSpec(key: "n", command: true),
        ShortcutSpec(key: "o", command: true),
        ShortcutSpec(key: "w", command: true),
        ShortcutSpec(key: "q", command: true),
        ShortcutSpec(key: "z", command: true),
        ShortcutSpec(key: "c", command: true),
        ShortcutSpec(key: "v", command: true),
        ShortcutSpec(key: "x", command: true),
        ShortcutSpec(key: "a", command: true),
        ShortcutSpec(key: "f", command: true),
    ]

    private static let defaultsKey = "remappedShortcuts"

    @Published private(set) var overrides: [String: ShortcutSpec] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.dictionary(forKey: Self.defaultsKey)
            as? [String: String] {
            overrides = stored.compactMapValues(ShortcutSpec.parse)
        }
    }

    func spec(for id: String) -> ShortcutSpec {
        overrides[id] ?? Self.commands.first { $0.id == id }?.defaultSpec
            ?? ShortcutSpec(key: "?")
    }

    func isOverridden(_ id: String) -> Bool { overrides[id] != nil }

    /// Applies and persists, or explains why not. One combo, one command
    /// — the Force Save/Snapshots clash this app actually shipped is the
    /// argument for refusing rather than allowing-and-praying.
    @discardableResult
    func set(_ spec: ShortcutSpec, for id: String) -> String? {
        guard spec.isChorded else {
            return "A shortcut needs ⌘, ⌥, or ⌃ — a bare key is typing."
        }
        if Self.protectedCombos.contains(spec) {
            return "\(spec.display) belongs to the system."
        }
        if let holder = Self.commands.first(where: {
            $0.id != id && self.spec(for: $0.id) == spec
        }) {
            return "\(spec.display) is already \(holder.label)."
        }
        overrides[id] = spec
        persist()
        return nil
    }

    func reset(_ id: String) {
        overrides[id] = nil
        persist()
    }

    func resetAll() {
        overrides = [:]
        persist()
    }

    private func persist() {
        defaults.set(overrides.mapValues(\.storage), forKey: Self.defaultsKey)
    }
}

/// `.keyboardShortcut` wants a non-optional; the spec's key is never
/// empty in practice, but the menu must not crash if it ever is.
extension ShortcutSpec {
    var keyboardShortcutOrDefault: KeyboardShortcut {
        keyboardShortcut ?? KeyboardShortcut("?", modifiers: [.command,
                                                             .option,
                                                             .control])
    }
}
