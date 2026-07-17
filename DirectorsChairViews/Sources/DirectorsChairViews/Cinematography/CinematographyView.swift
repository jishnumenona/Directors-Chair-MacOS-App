// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/CinematographyView.swift
//
// Cinematography View - Shot Planning Interface
// Comprehensive shot composition, camera angles, and lighting setup management.

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Cinematography View

public struct CinematographyView: View {
    // MARK: - Properties

    @StateObject private var viewModel: CinematographyViewModel
    @EnvironmentObject var captureService: LiveCaptureService

    /// The shots passed in from the project. The view model is seeded from this
    /// once; an .onChange keeps the model in sync when the project changes
    /// externally (e.g. shots added from the script view, or another view's
    /// edits), which a once-seeded @StateObject would otherwise miss.
    let shots: [Shot]

    /// All scenes for resolving shot-to-scene context
    let scenes: [DCScene]
    let characters: [Character]
    let locations: [Location]
    let projectBasePath: URL?

    /// Project look bible: user-defined FilmStyles + the project default,
    /// resolved per shot (shot → scene → default) for AI generation.
    let filmStyles: [FilmStyle]
    let defaultFilmStyleId: String?

    /// Callback when shots change (for persistence)
    public var onShotsChanged: (([Shot]) -> Void)?

    /// Callback to jump to a script element (itemId, itemType)
    public var onJumpToScriptElement: ((String, String) -> Void)?

    /// Callback when a shot is Option+clicked (jump to script for shot)
    public var onOptionClickShot: ((Shot) -> Void)?

    /// Navigation callbacks for shot context
    public var onNavigateToCharacter: ((Character) -> Void)?
    public var onNavigateToLocation: ((Location) -> Void)?
    public var onNavigateToStoryDesign: (() -> Void)?
    public var onNavigateToCuration: ((Shot) -> Void)?

    /// Callback when scene data is updated (props, sounds, etc.)
    public var onSceneUpdated: ((DCScene) -> Void)?

    /// Deep-link to Scene Connections for a shot (optionally targeting a
    /// specific script item) — the app hub where bubbles link to shots.
    public var onOpenConnections: ((Shot, String?) -> Void)?

    /// Initial shot ID to select when view appears or changes
    public var initialSelectedShotId: Int?

    /// Section to scroll to in shot detail (e.g. "takes"). Consumed and cleared externally.
    @Binding public var scrollToShotSection: String?

    // MARK: - State

    @State private var showingDeleteAlert: Bool = false
    @State private var shotToDelete: String?
    @State private var lastAppliedShotId: Int?
    @State private var isShotListCollapsed: Bool = true

    // MARK: - Init

    public init(
        shots: [Shot] = [],
        scenes: [DCScene] = [],
        characters: [Character] = [],
        locations: [Location] = [],
        projectBasePath: URL? = nil,
        filmStyles: [FilmStyle] = [],
        defaultFilmStyleId: String? = nil,
        initialSelectedShotId: Int? = nil,
        scrollToShotSection: Binding<String?> = .constant(nil),
        onShotsChanged: (([Shot]) -> Void)? = nil,
        onJumpToScriptElement: ((String, String) -> Void)? = nil,
        onOptionClickShot: ((Shot) -> Void)? = nil,
        onNavigateToCharacter: ((Character) -> Void)? = nil,
        onNavigateToLocation: ((Location) -> Void)? = nil,
        onNavigateToStoryDesign: (() -> Void)? = nil,
        onNavigateToCuration: ((Shot) -> Void)? = nil,
        onOpenConnections: ((Shot, String?) -> Void)? = nil,
        onSceneUpdated: ((DCScene) -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: CinematographyViewModel(shots: shots))
        self.shots = shots
        self.scenes = scenes
        self.characters = characters
        self.locations = locations
        self.projectBasePath = projectBasePath
        self.filmStyles = filmStyles
        self.defaultFilmStyleId = defaultFilmStyleId
        self.initialSelectedShotId = initialSelectedShotId
        self._scrollToShotSection = scrollToShotSection
        self.onShotsChanged = onShotsChanged
        self.onJumpToScriptElement = onJumpToScriptElement
        self.onOptionClickShot = onOptionClickShot
        self.onNavigateToCharacter = onNavigateToCharacter
        self.onNavigateToLocation = onNavigateToLocation
        self.onNavigateToStoryDesign = onNavigateToStoryDesign
        self.onNavigateToCuration = onNavigateToCuration
        self.onSceneUpdated = onSceneUpdated
        self.onOpenConnections = onOpenConnections
    }

    /// Find the parent scene for a given shot
    private func sceneForShot(_ shot: Shot) -> DCScene? {
        scenes.first { scene in
            scene.shots.contains { $0.id == shot.id }
        }
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            // Left sidebar - shot list (collapsible)
            if !isShotListCollapsed {
                shotListSidebar
                    .frame(width: 320)
                    .transition(.move(edge: .leading))
            }

            // Main content area
            mainContentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: isShotListCollapsed)
        .sheet(isPresented: $viewModel.showingShotEditor) {
            if let shot = viewModel.editingShot {
                ShotEditorSheet(
                    shot: Binding(
                        get: { viewModel.editingShot ?? shot },
                        set: { viewModel.editingShot = $0 }
                    ),
                    presets: viewModel.cameraPresets,
                    characters: characters,
                    isPresented: $viewModel.showingShotEditor,
                    onSave: {
                        viewModel.saveEditedShot()
                    }
                )
            }
        }
        .alert("Delete Shot", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let shotId = shotToDelete {
                    viewModel.removeShot(shotId)
                }
                shotToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                shotToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this shot?")
        }
        .onAppear {
            viewModel.onShotsChanged = onShotsChanged
            applyInitialSelection()
        }
        .onChange(of: shots) { _, newShots in
            // Resync when the project's shots change externally. notify:false so
            // this does not echo back to the parent as a fresh edit.
            viewModel.setShots(newShots, notify: false)
        }
        .onChange(of: initialSelectedShotId) { _, newValue in
            applyInitialSelection()
        }
    }

    /// Apply initial shot selection if it's different from the last applied
    private func applyInitialSelection() {
        guard let shotId = initialSelectedShotId, shotId != lastAppliedShotId else { return }
        if let shot = viewModel.shots.first(where: { $0.shotId == shotId }) {
            viewModel.selectedShotId = shot.id
            lastAppliedShotId = shotId
        }
    }

    // MARK: - Shot List Sidebar

    @ViewBuilder
    private var shotListSidebar: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader

            Divider()

            // Filter bar
            filterBar

            Divider()

            // Shot list
            shotList
        }
        .background(Color(hex: "#252525"))
        // Expose the container to the UI-test driver (a SwiftUI container's
        // identifier isn't queryable unless it's an accessibility element).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shot-list-sidebar")
    }

    // MARK: - Sidebar Header

    @ViewBuilder
    private var sidebarHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shot List")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(viewModel.filteredShots.count) shots")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                viewModel.createNewShot()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Add New Shot")
        }
        .padding()
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 8) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search shots...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(6)

            // Status filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    statusFilterButton(nil, label: "All")

                    ForEach(ShotStatus.allCases) { status in
                        statusFilterButton(status, label: status.rawValue)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(hex: "#2A2A2A"))
    }

    @ViewBuilder
    private func statusFilterButton(_ status: ShotStatus?, label: String) -> some View {
        let isSelected = viewModel.filterByStatus == status

        Button {
            viewModel.filterByStatus = status
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? (status?.color ?? Color.accentColor) : Color(hex: "#3A3A3A"))
                .foregroundColor(isSelected ? .white : .gray)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shot List

    @ViewBuilder
    private var shotList: some View {
        if viewModel.filteredShots.isEmpty {
            emptyStateView
        } else {
            List(selection: $viewModel.selectedShotId) {
                ForEach(viewModel.filteredShots) { shot in
                    ShotListRow(
                        shot: shot,
                        isSelected: viewModel.selectedShotId == shot.id,
                        onEdit: {
                            viewModel.editShot(shot)
                        },
                        onDuplicate: {
                            viewModel.duplicateShot(shot.id)
                        },
                        onDelete: {
                            shotToDelete = shot.id
                            showingDeleteAlert = true
                        },
                        onStatusChange: { newStatus in
                            viewModel.updateShotStatus(shot.id, status: newStatus)
                        }
                    )
                    .tag(shot.id)
                }
                .onMove { source, destination in
                    viewModel.moveShot(from: source, to: destination)
                }
            }
            .listStyle(.sidebar)
            .onChange(of: viewModel.selectedShotId) { _, newId in
                if NSEvent.modifierFlags.contains(.option),
                   let shotId = newId,
                   let shot = viewModel.shots.first(where: { $0.id == shotId }) {
                    onOptionClickShot?(shot)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No shots yet")
                .font(.headline)
                .foregroundColor(.gray)

            Text("Add your first shot to start planning")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button {
                viewModel.createNewShot()
            } label: {
                Label("Add Shot", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Main Content Area

    @ViewBuilder
    private var mainContentArea: some View {
        VStack(spacing: 0) {
            // Mode selector toolbar
            modeToolbar

            Divider()

            // Content based on mode
            switch viewModel.viewMode {
            case .shotList:
                shotDetailView
            case .storyboard:
                storyboardView
            case .overhead:
                overheadView
            case .settings:
                cameraSettingsView
            }
        }
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Mode Toolbar

    @ViewBuilder
    private var modeToolbar: some View {
        HStack(spacing: 16) {
            // Shot list toggle
            Button {
                isShotListCollapsed.toggle()
            } label: {
                Image(systemName: isShotListCollapsed ? "sidebar.left" : "sidebar.left")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundColor(isShotListCollapsed ? .gray : .accentColor)
            .help(isShotListCollapsed ? "Show Shot List" : "Hide Shot List")

            Divider()
                .frame(height: 20)

            // View mode picker
            ForEach(CinematographyViewMode.allCases) { mode in
                Button {
                    viewModel.viewMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.systemImage)
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundColor(viewModel.viewMode == mode ? .accentColor : .gray)
                .help(mode.rawValue)
            }

            Divider()
                .frame(height: 20)

            // Progress indicator
            HStack(spacing: 8) {
                Text("Progress:")
                    .font(.caption)
                    .foregroundColor(.gray)

                ProgressView(value: viewModel.completionPercentage, total: 100)
                    .frame(width: 100)

                Text("\(Int(viewModel.completionPercentage))%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Total duration
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundColor(.gray)
                Text(formatDuration(viewModel.totalDuration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(hex: "#252525"))
    }

    // MARK: - Shot Detail View

    @ViewBuilder
    private var shotDetailView: some View {
        if let shot = viewModel.selectedShot {
            VStack(alignment: .leading, spacing: 0) {
                // Shot header - pinned outside scroll view
                shotDetailHeader(shot)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                    // Shot Preview - Main section
                    ShotPreviewSection(
                        shot: shot,
                        scene: sceneForShot(shot),
                        characters: characters,
                        locations: locations,
                        projectBasePath: projectBasePath,
                        onPreviewGenerated: { imagePath in
                            updateShotField(shot) { $0.previewImage = imagePath }
                        }
                    )

                    // Description (Click to edit)
                    InlineDescriptionEditor(
                        description: shot.description,
                        characters: characters,
                        onDescriptionChange: { newDescription in
                            updateShotField(shot) { $0.description = newDescription }
                        }
                    )

                    // Shot Context — who/where/what of this shot's scene, plus
                    // the scene's script bubbles. Shot-level truth, so it lives
                    // here rather than inside video generation.
                    CollapsibleCard(icon: "text.book.closed.fill",
                                    title: "Shot Context",
                                    summary: contextSummary(for: shot),
                                    storageKey: "shotContext") {
                        ShotContextCard(
                            shot: shot,
                            scene: sceneForShot(shot),
                            characters: characters,
                            locations: locations,
                            projectBasePath: projectBasePath?.deletingLastPathComponent(),
                            showsHeader: false,
                            onNavigateToCharacter: onNavigateToCharacter,
                            onNavigateToLocation: onNavigateToLocation,
                            onNavigateToStoryDesign: onNavigateToStoryDesign,
                            onSceneUpdated: onSceneUpdated,
                            onOpenConnections: onOpenConnections.map { open in
                                { itemId in open(shot, itemId) }
                            }
                        )
                    }

                    // Linked Script Elements
                    if let currentScene = sceneForShot(shot),
                       (!shot.linkedDialogueIds.isEmpty || !shot.linkedActionIds.isEmpty || !shot.linkedNarrationIds.isEmpty) {
                        CollapsibleCard(icon: "link",
                                        iconColor: .cyan,
                                        title: "Linked Script",
                                        summary: linkedScriptSummary(shot),
                                        storageKey: "linkedScript") {
                            LinkedScriptElementsSection(
                                shot: shot,
                                scene: currentScene,
                                onJumpToScript: { itemId, itemType in
                                    onJumpToScriptElement?(itemId, itemType)
                                }
                            )
                        }
                    }

                    // Takes Section (visible when shooting or has takes)
                    if shot.status == ShotStatus.shooting.rawValue || shot.hasTakes {
                        TakesSectionView(
                            shot: shot,
                            projectBasePath: projectBasePath,
                            onShotUpdated: { updatedShot in
                                viewModel.updateShot(updatedShot)
                            },
                            captureService: captureService,
                            onNavigateToCuration: onNavigateToCuration
                        )
                        .id("takes-section")

                        Divider()
                    }

                    // Camera settings — expanded by default (the craft core of a
                    // shot), collapsible to one summary line when not needed.
                    CollapsibleCard(icon: "camera.fill",
                                    iconColor: .white,
                                    title: "Camera",
                                    summary: ShotViewSummaries.camera(for: shot),
                                    storageKey: "camera",
                                    defaultExpanded: true) {
                        shotCameraSettings(shot)
                            .padding(.top, 4)
                    }

                    // Reference Media — collapsed; summary shows the count
                    CollapsibleCard(icon: "photo.on.rectangle.angled",
                                    iconColor: .orange,
                                    title: "Reference Media",
                                    summary: shot.referenceMedia.isEmpty
                                        ? "none added"
                                        : "\(shot.referenceMedia.count) item\(shot.referenceMedia.count == 1 ? "" : "s")",
                                    storageKey: "referenceMedia") {
                        ReferenceMediaSection(
                            media: shot.referenceMedia,
                            shotId: shot.shotId,
                            projectBasePath: projectBasePath,
                            onMediaAdded: { newMedia in
                                updateShotField(shot) { $0.referenceMedia.append(newMedia) }
                            },
                            onMediaRemoved: { mediaId in
                                updateShotField(shot) { $0.referenceMedia.removeAll { $0.id == mediaId } }
                            },
                            onUseAsPreview: { imagePath in
                                updateShotField(shot) { $0.previewImage = imagePath }
                            }
                        )
                    }

                    // Video Generation
                    ShotVideoGenerationSection(
                        shot: shot,
                        scene: sceneForShot(shot),
                        characters: characters,
                        locations: locations,
                        projectBasePath: projectBasePath?.deletingLastPathComponent(),
                        filmStyles: filmStyles,
                        defaultFilmStyleId: defaultFilmStyleId,
                        onShotUpdated: { updatedShot in
                            viewModel.updateShot(updatedShot)
                        },
                        onSceneUpdated: onSceneUpdated,
                        onNavigateToCharacter: onNavigateToCharacter,
                        onNavigateToLocation: onNavigateToLocation
                    )

                    Spacer()
                    }
                    .padding(24)
                }
                .id(shot.id)  // Force entire scroll view to recreate when shot changes
                .onAppear {
                    // Handle scroll-to-section when navigating from another view
                    if let section = scrollToShotSection {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation {
                                scrollProxy.scrollTo(section + "-section", anchor: .top)
                            }
                            scrollToShotSection = nil
                        }
                    }
                }
                .onChange(of: scrollToShotSection) { _, section in
                    if let section = section {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                scrollProxy.scrollTo(section + "-section", anchor: .top)
                            }
                            scrollToShotSection = nil
                        }
                    }
                }
                } // ScrollViewReader
            }
        } else {
            VStack {
                Image(systemName: "film")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("Select a shot to view details")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func shotDetailHeader(_ shot: Shot) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Shot #\(shot.shotId)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    ShotStatusBadge(
                        status: ShotStatus(rawValue: shot.status) ?? .planning,
                        onStatusChange: { newStatus in
                            updateShotField(shot) { $0.status = newStatus.rawValue }
                        }
                    )
                }

                Text(shot.shotType)
                    .font(.title3)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button {
                    onOptionClickShot?(shot)
                } label: {
                    Label("Script", systemImage: "scroll")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4)))
                .contentShape(Rectangle())

                Button {
                    viewModel.editShot(shot)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4)))
                .contentShape(Rectangle())

                Button {
                    viewModel.duplicateShot(shot.id)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4)))
                .contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private func shotCameraSettings(_ shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Camera Angle
            ChipSelector(
                icon: "camera.viewfinder",
                title: "Camera Angle",
                options: CameraAngleOptions.angles,
                selectedValue: shot.cameraAngle,
                onSelect: { newValue in
                    updateShotField(shot) { $0.cameraAngle = newValue }
                },
                descriptions: cameraAngleDescriptions
            )

            // Shot Type
            ChipSelector(
                icon: "rectangle.expand.vertical",
                title: "Shot Type",
                options: CameraAngleOptions.shotTypes,
                selectedValue: shot.shotType,
                onSelect: { newValue in
                    updateShotField(shot) { $0.shotType = newValue }
                },
                descriptions: shotTypeDescriptions
            )

            // Movement
            ChipSelector(
                icon: "arrow.left.and.right",
                title: "Movement",
                options: CameraAngleOptions.movements,
                selectedValue: shot.movement,
                onSelect: { newValue in
                    updateShotField(shot) { $0.movement = newValue }
                },
                descriptions: movementDescriptions
            )

            // Lens & Aperture Row
            HStack(alignment: .top, spacing: 24) {
                LensSelector(
                    icon: "circle.dotted",
                    title: "Lens",
                    options: CameraAngleOptions.commonLenses,
                    selectedValue: shot.lensMm,
                    onSelect: { newValue in
                        updateShotField(shot) { $0.lensMm = newValue }
                    },
                    descriptions: lensDescriptions
                )

                ApertureSelector(
                    icon: "camera.aperture",
                    title: "Aperture",
                    options: CameraAngleOptions.commonApertures,
                    selectedValue: shot.aperture,
                    onSelect: { newValue in
                        updateShotField(shot) { $0.aperture = newValue }
                    },
                    descriptions: apertureDescriptions
                )

                DurationEditor(
                    icon: "clock",
                    title: "Duration",
                    value: shot.duration,
                    onValueChange: { newValue in
                        updateShotField(shot) { $0.duration = newValue }
                    }
                )
            }
        }
    }

    /// Summary for the collapsed Shot Context card.
    private func contextSummary(for shot: Shot) -> String {
        guard let scene = sceneForShot(shot) else { return "no scene linked" }
        return ShotViewSummaries.context(
            characterCount: ShotPromptBuilder.characterNames(in: scene).count,
            location: scene.location,
            propCount: scene.props.count,
            soundCount: scene.soundNotes.count
        )
    }

    /// Summary for the collapsed Linked Script card.
    private func linkedScriptSummary(_ shot: Shot) -> String {
        var parts: [String] = []
        if !shot.linkedDialogueIds.isEmpty { parts.append("\(shot.linkedDialogueIds.count) dialogue") }
        if !shot.linkedActionIds.isEmpty { parts.append("\(shot.linkedActionIds.count) action\(shot.linkedActionIds.count == 1 ? "" : "s")") }
        if !shot.linkedNarrationIds.isEmpty { parts.append("\(shot.linkedNarrationIds.count) narration\(shot.linkedNarrationIds.count == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    /// Helper to update a single field of a shot
    private func updateShotField(_ shot: Shot, update: (inout Shot) -> Void) {
        var updatedShot = shot
        update(&updatedShot)
        viewModel.updateShot(updatedShot)
    }

    // MARK: - Storyboard View

    @ViewBuilder
    private var storyboardView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 280))
            ], spacing: 16) {
                ForEach(viewModel.filteredShots) { shot in
                    StoryboardCard(
                        shot: shot,
                        isSelected: viewModel.selectedShotId == shot.id,
                        onSelect: {
                            viewModel.selectShot(shot.id)
                        },
                        onEdit: {
                            viewModel.editShot(shot)
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Overhead View

    @ViewBuilder
    private var overheadView: some View {
        VStack {
            // Placeholder for overhead camera diagram
            ZStack {
                // Grid background
                GeometryReader { geo in
                    Path { path in
                        let step: CGFloat = 40
                        for x in stride(from: 0, to: geo.size.width, by: step) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        }
                        for y in stride(from: 0, to: geo.size.height, by: step) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }

                VStack(spacing: 16) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Overhead View")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Coming soon - visualize camera positions and movements")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - Camera Settings View

    @ViewBuilder
    private var cameraSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Presets section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Camera Presets")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Select a preset to quickly apply common camera configurations")
                        .font(.caption)
                        .foregroundColor(.gray)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 180, maximum: 220))
                    ], spacing: 12) {
                        ForEach(viewModel.cameraPresets) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: viewModel.selectedPresetId == preset.id,
                                onSelect: {
                                    viewModel.selectedPresetId = preset.id
                                }
                            )
                        }
                    }
                }

                Divider()

                // Quick reference
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Reference")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(alignment: .top, spacing: 32) {
                        // Shot types
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shot Types")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)

                            ForEach(CameraAngleOptions.shotTypes.prefix(8), id: \.self) { type in
                                Text(type)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        // Camera angles
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Camera Angles")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)

                            ForEach(CameraAngleOptions.angles, id: \.self) { angle in
                                Text(angle)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        // Movements
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Movements")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)

                            ForEach(CameraAngleOptions.movements.prefix(10), id: \.self) { movement in
                                Text(movement)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
#if DEBUG
struct CinematographyView_Previews: PreviewProvider {
    static var previews: some View {
        CinematographyView(shots: [
            Shot(
                shotId: 1,
                description: "Wide establishing shot of the city",
                status: "Planning",
                cameraAngle: "High",
                lensMm: 24,
                aperture: "f/5.6",
                shotType: "EWS",
                movement: "Static",
                duration: 5.0
            ),
            Shot(
                shotId: 2,
                description: "Medium shot of protagonist",
                status: "Ready",
                cameraAngle: "Eye Level",
                lensMm: 50,
                aperture: "f/2.8",
                shotType: "MS",
                movement: "Dolly In",
                duration: 3.5
            ),
            Shot(
                shotId: 3,
                description: "Close-up reaction shot",
                status: "Review",
                cameraAngle: "Eye Level",
                lensMm: 85,
                aperture: "f/1.8",
                shotType: "CU",
                movement: "Static",
                duration: 2.0
            )
        ])
        .frame(width: 1200, height: 800)
        .environmentObject(VideoJobCoordinator())
    }
}
#endif
