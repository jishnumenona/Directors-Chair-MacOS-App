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
        if projectViewModel.hasProject {
            // Script revisions (§2.18) — the palette rebuilds per open,
            // so these labels are always current (the File menu's are
            // deliberately generic).
            if projectViewModel.project.scriptRevisionColor == nil {
                entries.append(PaletteEntry(
                    id: "cmd.lockScenes", title: "Lock Scene Numbers",
                    subtitle: "Freeze production numbers — the White draft",
                    systemImage: "lock", category: .command))
            } else {
                let next = ScriptRevisionTracker.nextColor(
                    after: projectViewModel.project.scriptRevisionColor)
                entries.append(PaletteEntry(
                    id: "cmd.advanceRevision",
                    title: "Start \(next) Revision",
                    subtitle: "Stamp changed scenes and open a new round",
                    systemImage: "doc.badge.clock", category: .command))
            }
        }

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

        // Global search (§2.18): the project's own content, after the
        // commands so an empty palette still leads with navigation. A
        // result is only as findable as its words, so wordless vision
        // scraps stay out rather than listing as anonymous "Picture"s.
        if projectViewModel.hasProject {
            entries += contentEntries(project: projectViewModel.project)
        }
        return entries
    }

    /// Scenes, shots, characters, locations, and vision elements as
    /// palette entries. Built on palette open — at the audited stress
    /// scale (300 scenes / 3,600 shots) this is struct construction,
    /// not work worth caching against.
    static func contentEntries(project: Project) -> [PaletteEntry] {
        var entries: [PaletteEntry] = []
        for scene in project.sequences.flatMap(\.scenes) {
            entries.append(PaletteEntry(
                id: "find.scene.\(scene.id)",
                title: scene.name,
                subtitle: scene.location ?? scene.description,
                systemImage: "film",
                category: .content))
            for shot in scene.shots {
                entries.append(PaletteEntry(
                    id: "find.shot.\(shot.id)",
                    title: "Shot \(shot.shotId)",
                    subtitle: shot.description.isEmpty
                        ? scene.name : shot.description,
                    systemImage: "camera",
                    category: .content))
            }
        }
        for character in project.characters {
            entries.append(PaletteEntry(
                id: "find.char.\(character.name)",
                title: character.name,
                subtitle: "Character",
                systemImage: "person",
                category: .content))
        }
        for location in project.locations {
            entries.append(PaletteEntry(
                id: "find.loc.\(location.name)",
                title: location.name,
                subtitle: "Location",
                systemImage: "map",
                category: .content))
        }
        for card in project.beats {
            let words = card.title.isEmpty ? card.text : card.title
            let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            entries.append(PaletteEntry(
                id: "find.vision.\(card.id)",
                title: String(trimmed.prefix(48)),
                subtitle: "Vision board" + (card.referenceNote.map { note in
                    note.isEmpty ? "" : " — \(note.prefix(40))" } ?? ""),
                systemImage: "square.grid.2x2",
                category: .content))
        }
        return entries
    }

    /// Exits into the surfaces that search what the catalog can't hold:
    /// the assets library searches the DISK, and the script's find bar
    /// searches full text. Both take the palette's query with them.
    static func dynamicEntries(query: String,
                               hasProject: Bool) -> [PaletteEntry] {
        guard hasProject, !query.isEmpty else { return [] }
        return [
            PaletteEntry(id: "forward.assets",
                         title: "Search assets for “\(query)”",
                         subtitle: "Files on disk — media, audio, footage",
                         systemImage: "photo.on.rectangle",
                         category: .content),
            PaletteEntry(id: "forward.script",
                         title: "Find “\(query)” in the script",
                         subtitle: "Opens the screenplay's find bar",
                         systemImage: "text.magnifyingglass",
                         category: .content),
        ]
    }

    static func run(_ entry: PaletteEntry, query: String,
                    coordinator: AppCoordinator,
                    projectViewModel: ProjectViewModel) {
        let project = projectViewModel.project
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
        } else if entry.id == "cmd.lockScenes" {
            ScriptRevisionTracker.lock(
                &projectViewModel.project,
                date: ISO8601DateFormatter().string(from: Date()))
        } else if entry.id == "cmd.advanceRevision" {
            ScriptRevisionTracker.advance(
                &projectViewModel.project,
                date: ISO8601DateFormatter().string(from: Date()))
        } else if entry.id.hasPrefix("action.") {
            coordinator.pendingAssistantPrompt = entry.title + " "
            coordinator.showingAIChat = true
        } else if entry.id.hasPrefix("find.scene.") {
            let id = String(entry.id.dropFirst(11))
            if let scene = project.sequences.flatMap(\.scenes)
                .first(where: { $0.id == id }) {
                coordinator.selectScene(scene)
                coordinator.navigateTo(.scenes)
            }
        } else if entry.id.hasPrefix("find.shot.") {
            let id = String(entry.id.dropFirst(10))
            if let shot = project.sequences.flatMap(\.scenes)
                .flatMap(\.shots).first(where: { $0.id == id }) {
                coordinator.selectShot(shot)
            }
        } else if entry.id.hasPrefix("find.char.") {
            let name = String(entry.id.dropFirst(10))
            if let character = project.characters
                .first(where: { $0.name == name }) {
                coordinator.selectCharacter(character)
            }
        } else if entry.id.hasPrefix("find.loc.") {
            let name = String(entry.id.dropFirst(9))
            if let location = project.locations
                .first(where: { $0.name == name }) {
                coordinator.selectLocation(location)
            }
        } else if entry.id.hasPrefix("find.vision.") {
            coordinator.revealOnVisionBoard(
                cardId: String(entry.id.dropFirst(12)))
        } else if entry.id == "forward.assets" {
            coordinator.pendingAssetsSearch = query
            coordinator.navigateTo(.assets)
        } else if entry.id == "forward.script" {
            stageScriptFind(query, coordinator: coordinator)
        }
    }

    /// The screenplay searches through the native NSTextFinder bar, and
    /// that bar reads the SYSTEM find pasteboard — staging the query
    /// there is exactly how find carries across macOS apps. Then summon
    /// the bar down the responder chain once the editor has mounted; if
    /// the focus race is lost, ⌘F still opens it with the query already
    /// staged, so the worst case degrades to one extra keystroke.
    private static func stageScriptFind(_ query: String,
                                        coordinator: AppCoordinator) {
        let pasteboard = NSPasteboard(name: .find)
        pasteboard.clearContents()
        pasteboard.setString(query, forType: .string)
        coordinator.navigateTo(.script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let sender = NSMenuItem()
            sender.tag = Int(NSTextFinder.Action.showFindInterface.rawValue)
            NSApp.sendAction(
                #selector(NSResponder.performTextFinderAction(_:)),
                to: nil, from: sender)
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
