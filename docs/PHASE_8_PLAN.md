# Phase 8: Main App Integration - Implementation Plan
**Architect:** Agent 1
**Timeline:** Week 5-7 (3 weeks)
**Status:** PLANNING COMPLETE - Ready to implement

---

## Architecture Design

### Python to SwiftUI Mapping

Based on the comprehensive Python architecture study, here's the SwiftUI equivalent design:

| Python Component | SwiftUI Equivalent | Implementation |
|------------------|-------------------|----------------|
| `QMainWindow` | `@main DirectorsChairApp` | App entry point |
| `QStackedWidget` | `NavigationSplitView` + enum routing | View navigation |
| Signal/Slot (Qt) | `@Published` + Combine | Reactive updates |
| `_Bus` singleton | `AppCoordinator` (EnvironmentObject) | Event bus |
| `Project` QObject | `ProjectViewModel` (@ObservableObject) | State management |
| `QDockWidget` | `NavigationSplitView` sidebar | Navigation panel |
| Menu/Toolbar | `.toolbar()` + `.commands()` | macOS menu bar |
| `QSettings` | `@AppStorage` + UserDefaults | Preferences |
| Threading | `async/await` + `Task` | Concurrency |

---

## SwiftUI App Structure

### 1. App Entry Point

```swift
// DirectorsChair-Desktop/DirectorsChair_DesktopApp.swift

@main
struct DirectorsChairApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var projectViewModel: ProjectViewModel

    init() {
        // Initialize with empty or last opened project
        let project = Project.empty()
        _projectViewModel = StateObject(wrappedValue: ProjectViewModel(project: project))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(projectViewModel)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            AppCommands()
        }

        #if os(macOS)
        Settings {
            PreferencesView()
                .environmentObject(coordinator)
        }
        #endif
    }
}
```

### 2. AppCoordinator (Event Bus)

```swift
// DirectorsChair-Desktop/AppCoordinator.swift

@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Navigation State
    @Published var selectedView: AppView = .overview
    @Published var selectedSequence: Sequence?
    @Published var selectedScene: Scene?
    @Published var selectedShot: Shot?

    // MARK: - UI State
    @Published var showingNavigator = true
    @Published var showingTimeline = true
    @Published var showingRightPanel = true

    // MARK: - Event Publishers (replaces Qt signals)
    let projectChanged = PassthroughSubject<Void, Never>()
    let sceneChanged = PassthroughSubject<Scene, Never>()
    let sequenceChanged = PassthroughSubject<Sequence, Never>()
    let dialogueSelected = PassthroughSubject<Dialogue, Never>()
    let actionSelected = PassthroughSubject<Action, Never>()

    // MARK: - Navigation Methods
    func navigateTo(_ view: AppView) {
        selectedView = view
    }

    func selectSequence(_ sequence: Sequence) {
        selectedSequence = sequence
        sequenceChanged.send(sequence)
    }

    func selectScene(_ scene: Scene) {
        selectedScene = scene
        sceneChanged.send(scene)
    }

    func selectShot(_ shot: Shot) {
        selectedShot = shot
    }
}

enum AppView: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case bubble = "Bubble"
    case scenes = "Scenes"
    case assets = "Assets"
    case visionBoard = "Vision Board"
    case shotList = "Shot List"
    case schedule = "Schedule"
    case castCrew = "Cast & Crew"
    case storyDesign = "Story Design"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "doc.text"
        case .bubble: return "bubble.left.and.bubble.right"
        case .scenes: return "film"
        case .assets: return "photo.on.rectangle"
        case .visionBoard: return "square.grid.2x2"
        case .shotList: return "camera"
        case .schedule: return "calendar"
        case .castCrew: return "person.3"
        case .storyDesign: return "book"
        case .settings: return "gear"
        }
    }
}
```

### 3. Main Content View

```swift
// DirectorsChair-Desktop/ContentView.swift

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        NavigationSplitView(
            columnVisibility: $coordinator.showingNavigator ? .constant(.all) : .constant(.detailOnly)
        ) {
            // Left Sidebar - Navigator
            NavigatorSidebar()
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
        } detail: {
            // Main Content Area
            VStack(spacing: 0) {
                // Top Toolbar
                AppToolbar()

                // Central View Stack
                CentralViewStack()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Timeline (collapsible)
                if coordinator.showingTimeline {
                    Divider()
                    TimelineView(viewModel: TimelineViewModel())
                        .frame(height: 200)
                }
            }
        }
        .toolbar {
            ToolbarCommands()
        }
    }
}
```

### 4. Central View Stack (Router)

```swift
// DirectorsChair-Desktop/Views/CentralViewStack.swift

struct CentralViewStack: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        Group {
            switch coordinator.selectedView {
            case .overview:
                ProjectOverviewView(project: projectViewModel.project)
            case .bubble:
                BubbleView()
            case .scenes:
                ScenesListView()
            case .assets:
                AssetsView()
            case .visionBoard:
                VisionBoardView(viewModel: VisionBoardViewModel())
            case .shotList:
                CinematographyView(viewModel: CinematographyViewModel())
            case .schedule:
                ScheduleView(viewModel: ScheduleViewModel())
            case .castCrew:
                CastCrewView(viewModel: CastCrewViewModel())
            case .storyDesign:
                StoryDesignView()
            case .settings:
                ProjectSettingsView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.selectedView)
    }
}
```

### 5. Navigator Sidebar

```swift
// DirectorsChair-Desktop/Views/NavigatorSidebar.swift

struct NavigatorSidebar: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var selectedTab: NavigatorTab = .outline

    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("Navigator", selection: $selectedTab) {
                ForEach(NavigatorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Tab Content
            TabView(selection: $selectedTab) {
                OutlineTab()
                    .tag(NavigatorTab.outline)

                VersionsTab()
                    .tag(NavigatorTab.versions)

                CommentsTab()
                    .tag(NavigatorTab.comments)
            }
            .tabViewStyle(.automatic)
        }
    }
}

enum NavigatorTab: String, CaseIterable, Identifiable {
    case outline = "Outline"
    case versions = "Versions"
    case comments = "Comments"

    var id: String { rawValue }
}
```

### 6. App Toolbar

```swift
// DirectorsChair-Desktop/Views/AppToolbar.swift

struct AppToolbar: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 12) {
            // View Selection (Radio Button Group)
            ForEach(AppView.allCases) { view in
                Button(action: {
                    coordinator.navigateTo(view)
                }) {
                    Label(view.rawValue, systemImage: view.icon)
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToolbarButtonStyle(isSelected: coordinator.selectedView == view))
                .help(view.rawValue)
            }

            Spacer()

            // Toggle Controls
            Button(action: {
                coordinator.showingNavigator.toggle()
            }) {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Navigator")

            Button(action: {
                coordinator.showingTimeline.toggle()
            }) {
                Image(systemName: "waveform")
            }
            .help("Toggle Timeline")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
```

### 7. Menu Commands

```swift
// DirectorsChair-Desktop/Commands/AppCommands.swift

struct AppCommands: Commands {
    var body: some Commands {
        // File Menu
        CommandGroup(replacing: .newItem) {
            Button("New Project...") {
                // TODO: Show new project dialog
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Open Project...") {
                // TODO: Show open project dialog
            }
            .keyboardShortcut("o", modifiers: [.command])

            Divider()

            Button("Save Project") {
                // TODO: Save current project
            }
            .keyboardShortcut("s", modifiers: [.command])
        }

        // View Menu
        CommandMenu("View") {
            ForEach(AppView.allCases) { view in
                Button(view.rawValue) {
                    // TODO: Navigate to view
                }
            }

            Divider()

            Toggle("Show Navigator", isOn: .constant(true))
                .keyboardShortcut("0", modifiers: [.command])

            Toggle("Show Timeline", isOn: .constant(true))
                .keyboardShortcut("1", modifiers: [.command])
        }

        // Export Menu
        CommandMenu("Export") {
            Button("Export as Fountain...") {
                // TODO: Fountain export
            }

            Button("Export as PDF...") {
                // TODO: PDF export
            }

            Button("Export as HTML...") {
                // TODO: HTML export
            }

            Button("Export as Final Draft...") {
                // TODO: FDX export
            }
        }
    }
}
```

### 8. Project ViewModel

```swift
// DirectorsChair-Desktop/ViewModels/ProjectViewModel.swift

@MainActor
class ProjectViewModel: ObservableObject {
    @Published var project: Project
    @Published var isDirty = false
    @Published var lastSaved: Date?

    private var persistence: ProjectPersistence
    private var autoSaveManager: DebouncedSaveManager
    private var cancellables = Set<AnyCancellable>()

    init(project: Project) {
        self.project = project
        self.persistence = ProjectPersistence()
        self.autoSaveManager = DebouncedSaveManager()

        setupAutoSave()
    }

    private func setupAutoSave() {
        // Watch for project changes
        $project
            .dropFirst()
            .sink { [weak self] _ in
                self?.isDirty = true
                Task {
                    await self?.autoSaveManager.requestSave()
                }
            }
            .store(in: &cancellables)

        // Handle save requests
        autoSaveManager.savePublisher
            .sink { [weak self] in
                Task {
                    await self?.save()
                }
            }
            .store(in: &cancellables)
    }

    func save() async {
        do {
            try await persistence.save(project, to: project.projectPath)
            isDirty = false
            lastSaved = Date()
        } catch {
            print("Failed to save project: \(error)")
        }
    }

    func load(from path: URL) async throws {
        let loadedProject = try await persistence.load(from: path)
        project = loadedProject
        isDirty = false
        lastSaved = Date()
    }
}
```

---

## Implementation Phases

### Phase 8A: Core Infrastructure (Week 5, Days 1-3)
**Priority:** CRITICAL

Files to create:
1. ✅ `DirectorsChair_DesktopApp.swift` - App entry point
2. ✅ `AppCoordinator.swift` - Event bus and navigation state
3. ✅ `ContentView.swift` - Main window layout
4. ✅ `CentralViewStack.swift` - View router
5. ✅ `ProjectViewModel.swift` - State management

**Success Criteria:**
- App launches with empty window
- Navigation structure in place
- Can switch between placeholder views
- State management working

### Phase 8B: Navigation & Sidebar (Week 5, Days 4-5)
**Priority:** HIGH

Files to create:
1. ✅ `NavigatorSidebar.swift` - Left navigation panel
2. ✅ `OutlineTab.swift` - Sequence/scene tree
3. ✅ `VersionsTab.swift` - Snapshot management
4. ✅ `CommentsTab.swift` - Collaboration comments
5. ✅ `AppToolbar.swift` - Top toolbar with view buttons

**Success Criteria:**
- Navigator displays project outline
- Can select sequences/scenes
- Toolbar buttons switch views
- Side panels toggle correctly

### Phase 8C: Menu Bar & Commands (Week 6, Days 1-2)
**Priority:** HIGH

Files to create:
1. ✅ `AppCommands.swift` - Menu bar commands
2. ✅ `FileCommands.swift` - File operations
3. ✅ `ViewCommands.swift` - View navigation
4. ✅ `ExportCommands.swift` - Export operations
5. ✅ `ProjectDialogs.swift` - New/Open project dialogs

**Success Criteria:**
- Full menu bar with all commands
- Keyboard shortcuts working
- File operations (New, Open, Save)
- Export menu functional

### Phase 8D: View Integration (Week 6, Days 3-5)
**Priority:** HIGH

Integration tasks:
1. ✅ Wire up Timeline view (Agent 4's work)
2. ✅ Wire up Bubble view (Agent 2's work)
3. ✅ Wire up Story Design view (Agent 2's work)
4. ✅ Wire up Vision Board view (Agent 2's work)
5. ✅ Wire up Cinematography view (Agent 2's work)
6. ✅ Wire up Production views (Agent 2's work)

**Success Criteria:**
- All existing views load in main window
- Navigation between views works
- State flows correctly between coordinator and views
- No compilation errors

### Phase 8E: Project Management (Week 7, Days 1-3)
**Priority:** HIGH

Files to create:
1. ✅ `ProjectOverviewView.swift` - Overview/pitch view
2. ✅ `ProjectSettingsView.swift` - Project metadata
3. ✅ `ScenesListView.swift` - Scene list management
4. ✅ `AssetsView.swift` - Media library
5. ✅ `NewProjectView.swift` - New project wizard
6. ✅ `OpenProjectView.swift` - Project selection

**Success Criteria:**
- Can create new projects
- Can open existing projects
- Project settings editable
- Assets manageable

### Phase 8F: Polish & Testing (Week 7, Days 4-5)
**Priority:** MEDIUM

Tasks:
1. ✅ Window state persistence (size, position)
2. ✅ Recent projects list
3. ✅ Keyboard shortcuts polish
4. ✅ Error handling and user feedback
5. ✅ Integration testing with Agent 5
6. ✅ Performance profiling
7. ✅ Bug fixes

**Success Criteria:**
- App feels polished and responsive
- No crashes or major bugs
- Good user experience
- Performance acceptable

---

## Key Design Decisions

### 1. NavigationSplitView vs TabView
**Decision:** Use `NavigationSplitView` with sidebar for main navigation
**Rationale:**
- Matches Python's dock-based layout
- More flexible than TabView
- Better for desktop app UX
- Allows collapsible sidebar

### 2. EnvironmentObject vs Singleton
**Decision:** Use `@EnvironmentObject` for `AppCoordinator`
**Rationale:**
- More SwiftUI-idiomatic
- Easier testing
- Better view lifecycle management
- Still provides global access

### 3. Enum-based Routing vs NavigationStack
**Decision:** Enum-based view switching with `@Published var selectedView`
**Rationale:**
- More explicit and type-safe
- Matches Python's QStackedWidget pattern
- Easier to manage complex navigation
- Better animation control

### 4. Commands vs Custom Menu
**Decision:** Use `.commands()` modifier for menu bar
**Rationale:**
- Native macOS integration
- Automatic keyboard shortcut handling
- System menu merging
- Follows Apple HIG

### 5. Debounced Auto-Save
**Decision:** Keep Python's 500ms debounced save pattern
**Rationale:**
- Proven UX in existing app
- Prevents excessive I/O
- Good balance between safety and performance

---

## Dependencies

### External Packages
None required - using only:
- SwiftUI (built-in)
- Combine (built-in)
- Foundation (built-in)

### Internal Modules
- `DirectorsChairCore` - Data models, persistence, EventBus
- `DirectorsChairViews` - All view components (Phases 3-5)
- `DirectorsChairProduction` - Production management views
- `DirectorsChairServices` - AI, TTS, Git services
- `DirectorsChairExports` - Export services

---

## Testing Strategy

### Unit Tests
- `AppCoordinator` navigation logic
- `ProjectViewModel` state management
- View routing logic

### Integration Tests
- View integration with coordinator
- Menu command execution
- File operations (New, Open, Save)
- Export functionality

### Manual Testing
- Full user workflow testing
- All menu commands
- Keyboard shortcuts
- Window state persistence
- Multi-window support (if needed)

### Performance Testing
- Launch time
- View switching performance
- Memory usage with large projects
- Save/load performance

---

## Risk Assessment

### Low Risks 🟢
- SwiftUI API knowledge (well-documented)
- View integration (modules already built)
- State management (straightforward pattern)

### Medium Risks 🟡
- Menu bar complexity (many commands)
- Window state management (desktop-specific)
- File operations UX (need good error handling)

### Mitigations
- Start with minimal menu, expand iteratively
- Use UserDefaults for simple state persistence
- Implement comprehensive error handling early

---

## Success Metrics

### Week 5 Goals
- [ ] App launches and shows main window
- [ ] Can navigate between all views
- [ ] Coordinator managing state correctly
- [ ] Basic menu bar functional

### Week 6 Goals
- [ ] All views integrated and working
- [ ] Full menu bar implemented
- [ ] File operations working (New, Open, Save)
- [ ] Export functionality connected

### Week 7 Goals
- [ ] Project management complete
- [ ] Polished user experience
- [ ] All tests passing
- [ ] Performance targets met
- [ ] Ready for Phase 9 (Polish)

---

## Next Steps

**Immediate (Today):**
1. Create basic app structure files
2. Implement AppCoordinator
3. Create ContentView with NavigationSplitView
4. Test basic navigation

**Tomorrow:**
1. Implement Navigator sidebar
2. Wire up existing views
3. Add toolbar
4. Test view switching

**This Week:**
1. Complete Phase 8A (Core Infrastructure)
2. Complete Phase 8B (Navigation)
3. Start Phase 8C (Menu Bar)

---

**Document Created:** 2026-01-14T04:00:00Z
**Author:** Agent 1 (Architect)
**Status:** READY TO IMPLEMENT
