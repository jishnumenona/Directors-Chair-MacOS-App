//
// ContentView+Navigator.swift
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


// MARK: - Sidebar Divider (Resizable)

struct SidebarDivider: View {
    @Binding var sidebarWidth: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newWidth = sidebarWidth + value.translation.width
                        sidebarWidth = min(500, max(200, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

// MARK: - Central View Router (Isolated from unnecessary updates)

/// This view ONLY observes selectedView changes, not the entire coordinator
/// This prevents cascading re-renders when other coordinator properties change

// MARK: - Navigator Sidebar

struct NavigatorSidebar: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var selectedTab: NavigatorTab = .outline

    var body: some View {
        VStack(spacing: 0) {
            // Project Identity Header
            if projectViewModel.hasProject {
                ProjectIdentityView(
                    project: projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    size: .standard,
                    showMetadata: false
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()
            }

            // Navigator Header
            HStack {
                Text("Navigator")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab Selector
            Picker("", selection: $selectedTab) {
                ForEach(NavigatorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .help("Switch between Outline, Versions, and Comments views")

            Divider()

            // Tab Content
            Group {
                switch selectedTab {
                case .outline:
                    OutlineTab()
                case .markers:
                    MarkersTab()
                case .versions:
                    VersionsTab()
                case .comments:
                    CommentsTab()
                }
            }
        }
    }
}

enum NavigatorTab: String, CaseIterable, Identifiable {
    case outline = "Outline"
    case markers = "Markers"
    case versions = "Versions"
    case comments = "Comments"

    var id: String { rawValue }
}

// MARK: - Scenes and shots on the wall
//
// Both ends of "this scene lives on the vision board". Dragging out of
// the outline and jumping back from it are the same relationship read in
// opposite directions, so they share one place: the lookup that decides
// whether a link exists, and the little button that appears only when
// there is somewhere to go. They live beside the navigator because the
// rows that use them do.

enum VisionLinkLookup {

    /// The element a scene was dropped on, if any. A card linked to a
    /// SHOT also carries that shot's scene id, so this deliberately
    /// excludes those — asking for the scene's element should not return
    /// an element that is really about one of its shots.
    static func elements(forScene sceneId: String,
                         in cards: [VisionCard]) -> [VisionCard] {
        cards.filter { $0.linkedSceneId == sceneId && $0.linkedShotId == nil }
    }

    static func elements(forShot shotId: String,
                         in cards: [VisionCard]) -> [VisionCard] {
        cards.filter { $0.linkedShotId == shotId }
    }
}

/// A list of every element a scene or shot is pinned to, as links. Plural
/// deliberately: the same scene can be up on the wall several times —
/// a location reference, a lighting note, a costume swatch — and a
/// control that only ever reaches the first of them would be lying.
struct WallLinksButton: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    let elements: [VisionCard]
    var compact: Bool = false

    var body: some View {
        if elements.count == 1, let only = elements.first {
            Button {
                coordinator.revealOnVisionBoard(cardId: only.id)
            } label: { label(for: only.linkedLabel ?? "the vision board") }
            .buttonStyle(.plain)
            .help("Show this on the vision board")
        } else if elements.count > 1 {
            Menu {
                ForEach(elements, id: \.id) { element in
                    Button(WallLinksButton.name(of: element)) {
                        coordinator.revealOnVisionBoard(cardId: element.id)
                    }
                }
            } label: {
                label(for: "\(elements.count) on the wall")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Show these on the vision board")
        }
    }

    @ViewBuilder
    private func label(for text: String) -> some View {
        if compact {
            Image(systemName: "pin.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.accentColor)
        } else {
            Label(text, systemImage: "pin.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
        }
    }

    /// What to call an element in a list of links. Its own title if it has
    /// one, otherwise what kind of thing it is — never a bare id.
    static func name(of element: VisionCard) -> String {
        let title = element.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        if !element.text.isEmpty {
            return String(element.text.prefix(38))
        }
        switch element.cardType {
        case "image": return "Picture"
        case "video": return "Video"
        case "color_palette": return "Palette"
        case "link": return "Link"
        default: return "Element"
        }
    }
}

// MARK: - Command palette catalog (§2.18)
//
// Lives here for the same reason VisionLinkLookup does: new files under
// the app target's synchronized folder group silently don't compile, so
// homeless app-target code moves in with an existing neighbour. The
// palette's generic half (entry model, ranker, panel UI) is
// CommandPaletteCore in DirectorsChairViews.

/// Everything ⌘K can do, and how to do it. The catalog is rebuilt on each
/// palette open — cheap, and it tracks live state (project open or not,
/// signed in or not) without invalidation bookkeeping.
@MainActor
enum CommandPaletteCatalog {

    static let productionTabs = ["Schedule", "Gantt", "Cast & Crew",
                                 "Accounting", "Equipment"]

    static func entries(coordinator: AppCoordinator,
                        projectViewModel: ProjectViewModel,
                        assistantAvailable: Bool) -> [PaletteEntry] {
        var entries: [PaletteEntry] = []

        // Navigation first: it is what an empty palette should offer.
        for view in AppView.allCases {
            if view.requiresProject && !projectViewModel.hasProject { continue }
            entries.append(PaletteEntry(
                id: "nav.\(view.rawValue)",
                title: "Go to \(view.rawValue)",
                subtitle: nil,
                systemImage: view.icon,
                category: .navigation))
        }
        if projectViewModel.hasProject {
            for tab in productionTabs {
                entries.append(PaletteEntry(
                    id: "ptab.\(tab)",
                    title: "Production: \(tab)",
                    subtitle: nil,
                    systemImage: "theatermasks",
                    category: .navigation))
            }
        }

        // App commands.
        if projectViewModel.hasProject {
            entries.append(PaletteEntry(
                id: "cmd.save", title: "Save Project",
                subtitle: "Write the project to disk now",
                systemImage: "square.and.arrow.down", category: .command))
            entries.append(PaletteEntry(
                id: "cmd.snapshots", title: "Project Snapshots…",
                subtitle: "Browse and restore restore-points",
                systemImage: "clock.arrow.circlepath", category: .command))
        }
        entries.append(PaletteEntry(
            id: "cmd.assistant", title: "AI Assistant",
            subtitle: "Open the assistant chat",
            systemImage: "sparkles", category: .command))

        // Assistant actions: what the palette makes discoverable. Picking
        // one stages its phrase in the chat composer — actions take
        // arguments, so the finishing move belongs to the user, in words.
        if assistantAvailable && projectViewModel.hasProject {
            let registry = AssistantActionFactory.makeRegistry(
                projectViewModel: projectViewModel, coordinator: coordinator)
            for tool in registry.toolDefinitions {
                entries.append(PaletteEntry(
                    id: "action.\(tool.name)",
                    title: humanize(tool.name),
                    subtitle: tool.description,
                    systemImage: "sparkles",
                    category: .assistant))
            }
        }
        return entries
    }

    static func run(_ entry: PaletteEntry,
                    coordinator: AppCoordinator,
                    projectViewModel: ProjectViewModel) {
        if entry.id.hasPrefix("nav."),
           let view = AppView(rawValue: String(entry.id.dropFirst(4))) {
            coordinator.navigateTo(view)
        } else if entry.id.hasPrefix("ptab.") {
            coordinator.selectedProductionTab = String(entry.id.dropFirst(5))
            coordinator.navigateTo(.production)
        } else if entry.id == "cmd.save" {
            Task { await projectViewModel.save() }
        } else if entry.id == "cmd.snapshots" {
            coordinator.showingSnapshots = true
        } else if entry.id == "cmd.assistant" {
            coordinator.showingAIChat = true
        } else if entry.id.hasPrefix("action.") {
            coordinator.pendingAssistantPrompt = entry.title + " "
            coordinator.showingAIChat = true
        }
    }

    /// "generate_scene_image" → "Generate scene image".
    static func humanize(_ wireName: String) -> String {
        let words = wireName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
