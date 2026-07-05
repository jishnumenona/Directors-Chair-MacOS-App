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
        initialSelectedShotId: Int? = nil,
        scrollToShotSection: Binding<String?> = .constant(nil),
        onShotsChanged: (([Shot]) -> Void)? = nil,
        onJumpToScriptElement: ((String, String) -> Void)? = nil,
        onOptionClickShot: ((Shot) -> Void)? = nil,
        onNavigateToCharacter: ((Character) -> Void)? = nil,
        onNavigateToLocation: ((Location) -> Void)? = nil,
        onNavigateToStoryDesign: (() -> Void)? = nil,
        onNavigateToCuration: ((Shot) -> Void)? = nil,
        onSceneUpdated: ((DCScene) -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: CinematographyViewModel(shots: shots))
        self.shots = shots
        self.scenes = scenes
        self.characters = characters
        self.locations = locations
        self.projectBasePath = projectBasePath
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

                    // Linked Script Elements
                    if let currentScene = sceneForShot(shot),
                       (!shot.linkedDialogueIds.isEmpty || !shot.linkedActionIds.isEmpty || !shot.linkedNarrationIds.isEmpty) {
                        LinkedScriptElementsSection(
                            shot: shot,
                            scene: currentScene,
                            onJumpToScript: { itemId, itemType in
                                onJumpToScriptElement?(itemId, itemType)
                            }
                        )
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

                    // Camera settings grid
                    shotCameraSettings(shot)

                    Divider()

                    // Reference Media
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

                    Divider()

                    // Video Generation
                    ShotVideoGenerationSection(
                        shot: shot,
                        scene: sceneForShot(shot),
                        characters: characters,
                        locations: locations,
                        projectBasePath: projectBasePath?.deletingLastPathComponent(),
                        onShotUpdated: { updatedShot in
                            viewModel.updateShot(updatedShot)
                        },
                        onSceneUpdated: onSceneUpdated,
                        onNavigateToCharacter: onNavigateToCharacter,
                        onNavigateToLocation: onNavigateToLocation,
                        onNavigateToStoryDesign: onNavigateToStoryDesign
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

// MARK: - Shot List Row

private struct ShotListRow: View {
    let shot: Shot
    let isSelected: Bool
    var onEdit: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onDelete: (() -> Void)?
    var onStatusChange: ((ShotStatus) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Shot number
            Text("#\(shot.shotId)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40)

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            // Shot info
            VStack(alignment: .leading, spacing: 2) {
                Text(shot.shotType)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(shot.description.isEmpty ? shot.cameraAngle : shot.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Video indicator
            if let videoPath = shot.videoPath, !videoPath.isEmpty {
                Image(systemName: "video.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green.opacity(0.8))
                    .help("Has generated video")
            }

            // Duration
            if let duration = shot.duration {
                Text("\(String(format: "%.1f", duration))s")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .contextMenu {
            Button {
                onEdit?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onDuplicate?()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Menu("Set Status") {
                ForEach(ShotStatus.allCases) { status in
                    Button {
                        onStatusChange?(status)
                    } label: {
                        Label(status.rawValue, systemImage: status.systemImage)
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var statusColor: Color {
        (ShotStatus(rawValue: shot.status) ?? .planning).color
    }
}

// MARK: - Shot Status Badge

private struct ShotStatusBadge: View {
    let status: ShotStatus
    var onStatusChange: ((ShotStatus) -> Void)? = nil

    @State private var showingPopover = false

    var body: some View {
        if onStatusChange != nil {
            Button {
                showingPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: status.systemImage)
                        .font(.caption2)
                    Text(status.rawValue)
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.2))
                .foregroundColor(status.color)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(ShotStatus.allCases) { option in
                        Button {
                            onStatusChange?(option)
                            showingPopover = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: option.systemImage)
                                    .frame(width: 16)
                                    .foregroundColor(option.color)
                                Text(option.rawValue)
                                Spacer()
                                if option == status {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(option == status ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                }
                .padding(8)
                .frame(width: 180)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: status.systemImage)
                    .font(.caption2)
                Text(status.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Shot Preview Section

private struct ShotPreviewSection: View {
    let shot: Shot
    let scene: DCScene?
    let characters: [Character]
    let locations: [Location]
    let projectBasePath: URL?
    let onPreviewGenerated: (String) -> Void

    @State private var isGenerating = false
    @State private var previewImage: NSImage?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingPromptEditor = false
    @State private var showingFullSizePreview = false
    @State private var showingAnnotationEditor = false
    @State private var editablePrompt: String = ""
    @State private var lastUsedPrompt: String = ""
    @State private var allPreviewImages: [URL] = []
    @State private var currentImageIndex: Int = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preview container
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1A1A"))

                if let image = previewImage {
                    // Display preview image
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 420)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if isGenerating {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("Generating shot preview...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)

                        Text(buildPromptSummary())
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                } else {
                    // Empty state with generate button
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#2A2A2A"))
                                .frame(width: 72, height: 72)

                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                        }

                        VStack(spacing: 6) {
                            Text("Shot Preview")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))

                            Text("Generate a preview based on shot settings")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        HStack(spacing: 12) {
                            Button(action: { openPromptEditor() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.badge.plus")
                                        .font(.system(size: 12))
                                    Text("Edit Prompt")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#3A3A3A"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: { generateWithDefaultPrompt() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 12))
                                    Text("Generate")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                }

                // Overlay buttons (when image exists)
                if previewImage != nil {
                    VStack {
                        HStack {
                            Spacer()
                            if !isGenerating {
                                // View full size button
                                Button(action: { showingFullSizePreview = true }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("View full size")

                                // Annotate & edit button
                                Button(action: { showingAnnotationEditor = true }) {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Annotate & edit image")

                                // Edit prompt button
                                Button(action: { openPromptEditor() }) {
                                    Image(systemName: "text.badge.plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Edit prompt")

                                // Download button
                                Button(action: { downloadPreviewImage() }) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Download image")
                            }

                            // Regenerate button (shows spinner when generating)
                            Button(action: { generateWithDefaultPrompt() }) {
                                ZStack {
                                    if isGenerating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 27, height: 27)
                                .background(isGenerating ? Color.accentColor.opacity(0.8) : Color.black.opacity(0.6))
                                .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isGenerating)
                            .help(isGenerating ? "Generating..." : "Regenerate preview")
                        }
                        .padding(12)
                        Spacer()
                    }
                }

                // Image history navigation
                if allPreviewImages.count > 1 {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Button {
                                if currentImageIndex > 0 {
                                    currentImageIndex -= 1
                                    loadPreviewImageAtIndex(currentImageIndex)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(currentImageIndex > 0 ? .white : .white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .disabled(currentImageIndex <= 0)

                            Text("\(currentImageIndex + 1) / \(allPreviewImages.count)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)

                            Button {
                                if currentImageIndex < allPreviewImages.count - 1 {
                                    currentImageIndex += 1
                                    loadPreviewImageAtIndex(currentImageIndex)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(currentImageIndex < allPreviewImages.count - 1 ? .white : .white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .disabled(currentImageIndex >= allPreviewImages.count - 1)

                            if currentImageIndex == allPreviewImages.count - 1 {
                                let isFromTake = allPreviewImages[currentImageIndex].lastPathComponent == "preview_take.png"
                                Text(isFromTake ? "Take" : "Latest")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isFromTake ? Color.green.opacity(0.7) : Color.accentColor.opacity(0.7))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(height: 420)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
            )

            // Shot info pills and prompt info
            HStack(spacing: 8) {
                ShotInfoPill(icon: "camera.viewfinder", text: shot.cameraAngle)
                ShotInfoPill(icon: "circle.dotted", text: shot.lensMm != nil ? "\(shot.lensMm!)mm" : "—")
                ShotInfoPill(icon: "rectangle.expand.vertical", text: shot.shotType)
                ShotInfoPill(icon: "arrow.left.and.right", text: shot.movement)

                Spacer()

                // Show prompt button if we have a last used prompt
                if !lastUsedPrompt.isEmpty {
                    Button(action: { openPromptEditor() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 9))
                            Text("View Prompt")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.accentColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("View or edit the prompt used for this preview")
                }

                if scene != nil {
                    Text("Scene: \(scene!.name)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
        }
        .onAppear {
            loadExistingPreview()
            loadSavedPrompt()
            generateTakePreviewIfNeeded()
            discoverPreviewImages()
        }
        .onChange(of: shot.previewImage) { _, newPath in
            if let path = newPath {
                loadPreviewImage(from: path)
            }
        }
        .alert("Preview Generation Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $showingPromptEditor) {
            PromptEditorSheet(
                prompt: $editablePrompt,
                isPresented: $showingPromptEditor,
                onGenerate: { customPrompt in
                    generatePreview(with: customPrompt)
                }
            )
        }
        .sheet(isPresented: $showingFullSizePreview) {
            ShotPreviewFullSizeSheet(
                image: previewImage,
                shotId: shot.shotId,
                isPresented: $showingFullSizePreview,
                onDownload: { downloadPreviewImage() }
            )
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = previewImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT SHOT PREVIEW",
                    subtitle: "Shot \(shot.shotId) — \(shot.shotType) \(shot.cameraAngle)",
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generatePreviewWithAnnotations(annotations)
                    }
                )
            }
        }
    }

    // MARK: - Prompt Editor

    private func openPromptEditor() {
        editablePrompt = lastUsedPrompt.isEmpty ? buildPrompt() : lastUsedPrompt
        showingPromptEditor = true
    }

    private func generateWithDefaultPrompt() {
        let prompt = buildPrompt()
        generatePreview(with: prompt)
    }

    // MARK: - Download Preview Image

    private func downloadPreviewImage() {
        guard let image = previewImage else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "shot_\(shot.shotId)_preview.png"
        savePanel.title = "Save Shot Preview"
        savePanel.message = "Choose a location to save the preview image"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Determine format based on extension
                let ext = url.pathExtension.lowercased()

                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData) {

                    let imageData: Data?
                    if ext == "jpg" || ext == "jpeg" {
                        imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                    } else {
                        imageData = bitmap.representation(using: .png, properties: [:])
                    }

                    if let data = imageData {
                        do {
                            try data.write(to: url)
                        } catch {
                            print("Error saving image: \(error)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Load Existing Preview

    private func loadExistingPreview() {
        guard let imagePath = shot.previewImage,
              let basePath = projectBasePath else { return }

        let fullPath = basePath.deletingLastPathComponent().appendingPathComponent(imagePath)
        if let image = NSImage(contentsOf: fullPath) {
            previewImage = image
        }
    }

    private func loadPreviewImage(from relativePath: String) {
        guard let basePath = projectBasePath else { return }
        let fullPath = basePath.deletingLastPathComponent().appendingPathComponent(relativePath)
        if let image = NSImage(contentsOf: fullPath) {
            previewImage = image
        }
    }

    private func loadSavedPrompt() {
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shot.shotId)")
        let promptFile = shotDir.appendingPathComponent("prompt.txt")

        if let savedPrompt = try? String(contentsOf: promptFile, encoding: .utf8) {
            lastUsedPrompt = savedPrompt
        }
    }

    // MARK: - Take Preview Generation

    /// Generates `preview_take.png` as a collage: AI-generated preview (left) + take frame (right).
    /// If no AI preview exists, saves just the take frame. Runs on appear if file doesn't exist yet.
    private func generateTakePreviewIfNeeded() {
        // Only generate collage for post-shooting statuses (Review, Approved, etc.)
        let preShootingStatuses = ["Planning", "Ready", "Shooting"]
        guard !preShootingStatuses.contains(shot.status) else { return }
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shot.shotId)")
        let takePreviewURL = shotDir.appendingPathComponent("preview_take.png")

        // Skip if already exists
        if FileManager.default.fileExists(atPath: takePreviewURL.path) { return }

        // Prefer a circled take with video; fall back to latest take with video
        let selectedTake = shot.circledTakes.first(where: { $0.capturedVideoPath != nil })
            ?? shot.takes.last(where: { $0.capturedVideoPath != nil })
        guard let selectedTake, let videoRelPath = selectedTake.capturedVideoPath else { return }

        let videoURL = projectDir.appendingPathComponent(videoRelPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return }

        // Find latest AI-generated preview (exclude preview_take.png itself)
        let aiPreviewImage: CGImage? = {
            guard FileManager.default.fileExists(atPath: shotDir.path),
                  let contents = try? FileManager.default.contentsOfDirectory(at: shotDir, includingPropertiesForKeys: nil) else { return nil }
            let aiPreviews = contents
                .filter { $0.pathExtension.lowercased() == "png" }
                .filter { $0.lastPathComponent.hasPrefix("preview_") && $0.lastPathComponent != "preview_take.png" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard let latestAI = aiPreviews.last,
                  let nsImage = NSImage(contentsOf: latestAI),
                  let cgImg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            return cgImg
        }()

        Task {
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1280, height: 720)

            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let targetSeconds = max(0, durationSeconds - 2.0)
            let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)

            guard let takeFrame = try? await generator.image(at: time).image else { return }

            let collageData: Data?
            if let aiImage = aiPreviewImage {
                collageData = Self.createCollage(leftImage: aiImage, leftLabel: "AI PREVIEW", rightImage: takeFrame, rightLabel: "TAKE")
            } else {
                // No AI preview — just save the take frame at full resolution
                let bitmapRep = NSBitmapImageRep(cgImage: takeFrame)
                collageData = bitmapRep.representation(using: .png, properties: [:])
            }

            guard let pngData = collageData else { return }

            try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
            try? pngData.write(to: takePreviewURL)

            await MainActor.run {
                discoverPreviewImages()
                if let image = NSImage(contentsOf: takePreviewURL) {
                    previewImage = image
                }
            }
        }
    }

    /// Creates a side-by-side collage at 1920x540 with labeled panels and a dark gap.
    private static func createCollage(leftImage: CGImage, leftLabel: String, rightImage: CGImage, rightLabel: String) -> Data? {
        let canvasWidth: CGFloat = 1920
        let canvasHeight: CGFloat = 540
        let gap: CGFloat = 4
        let panelWidth = (canvasWidth - gap) / 2
        let labelHeight: CGFloat = 28
        let labelFontSize: CGFloat = 13

        guard let ctx = CGContext(
            data: nil,
            width: Int(canvasWidth),
            height: Int(canvasHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Fill background black
        ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        // Draw each panel fitted within its half
        func drawPanel(image: CGImage, label: String, originX: CGFloat) {
            let imgW = CGFloat(image.width)
            let imgH = CGFloat(image.height)
            let availableHeight = canvasHeight - labelHeight
            let scale = min(panelWidth / imgW, availableHeight / imgH)
            let drawW = imgW * scale
            let drawH = imgH * scale
            let x = originX + (panelWidth - drawW) / 2
            let y = labelHeight + (availableHeight - drawH) / 2
            ctx.draw(image, in: CGRect(x: x, y: y, width: drawW, height: drawH))

            // Draw label background
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
            ctx.fill(CGRect(x: originX, y: 0, width: panelWidth, height: labelHeight))

            // Draw label text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: labelFontSize, weight: .semibold),
                .foregroundColor: NSColor.white,
                .kern: 1.5
            ]
            let attrString = NSAttributedString(string: label, attributes: attributes)
            let textSize = attrString.size()
            let textX = originX + (panelWidth - textSize.width) / 2
            let textY = (labelHeight - textSize.height) / 2

            // Use NSGraphicsContext to draw text into the CGContext
            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = nsCtx
            attrString.draw(at: NSPoint(x: textX, y: textY))
            NSGraphicsContext.restoreGraphicsState()
        }

        drawPanel(image: leftImage, label: leftLabel, originX: 0)
        drawPanel(image: rightImage, label: rightLabel, originX: panelWidth + gap)

        guard let compositeImage = ctx.makeImage() else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: compositeImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    // MARK: - Image History

    private func discoverPreviewImages() {
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shot.shotId)")

        guard FileManager.default.fileExists(atPath: shotDir.path) else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: shotDir, includingPropertiesForKeys: nil)
            let images = contents
                .filter { $0.pathExtension.lowercased() == "png" }
                .filter { $0.lastPathComponent.hasPrefix("preview_") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            allPreviewImages = images
            if !images.isEmpty {
                currentImageIndex = images.count - 1
            }
        } catch {
            // Directory doesn't exist or can't be read
        }
    }

    private func loadPreviewImageAtIndex(_ index: Int) {
        guard index >= 0, index < allPreviewImages.count else { return }
        let url = allPreviewImages[index]
        if let image = NSImage(contentsOf: url) {
            previewImage = image
        }
    }

    // MARK: - Generate Preview

    private func generatePreview(with prompt: String) {
        isGenerating = true
        errorMessage = nil
        lastUsedPrompt = prompt

        Task {
            do {
                let aiClient = AIServiceClient.shared

                guard await aiClient.testConnection() else {
                    await MainActor.run {
                        errorMessage = "Could not connect to AI server. Please ensure the AI Proxy server is running."
                        showingError = true
                        isGenerating = false
                    }
                    return
                }

                // Collect all reference images (location, characters, costumes)
                var refs: [ReferenceImage] = []
                if let scene = scene, let projDir = projectBasePath?.deletingLastPathComponent() {
                    refs = CharacterReferenceHelper.collectReferenceImages(
                        forScene: scene,
                        characters: characters,
                        locations: locations,
                        projectDirectory: projDir
                    )
                }

                // Prepend reference image instructions to the prompt
                let fullPrompt: String
                if !refs.isEmpty {
                    let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: refs)
                    fullPrompt = prefix + prompt
                } else {
                    fullPrompt = prompt
                }

                let request = ImageGenerationRequest(
                    prompt: fullPrompt,
                    provider: .googleImagen,
                    aspectRatio: "16:9",
                    numberOfImages: 1,
                    referenceImages: refs.isEmpty ? nil : refs
                )

                let response = try await aiClient.generateImage(request)

                guard let imageData = response.images.first else {
                    throw AIClientError.invalidResponse("No image generated")
                }

                // Save to project directory with proper structure
                guard let basePath = projectBasePath else {
                    throw AIClientError.invalidResponse("No project path")
                }

                let projectDir = basePath.deletingLastPathComponent()

                // Create shot-specific directory: assets/shots/shot_{id}/
                let shotDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("shots")
                    .appendingPathComponent("shot_\(shot.shotId)")

                if !FileManager.default.fileExists(atPath: shotDir.path) {
                    try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
                }

                // Generate timestamped filename
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let imageFilename = "preview_\(timestamp).png"
                let promptFilename = "prompt.txt"

                // Save the image
                let imagePath = shotDir.appendingPathComponent(imageFilename)
                try imageData.write(to: imagePath)

                // Save the prompt
                let promptPath = shotDir.appendingPathComponent(promptFilename)
                try prompt.write(to: promptPath, atomically: true, encoding: .utf8)

                // Also save prompt history
                let historyFilename = "prompt_\(timestamp).txt"
                let historyPath = shotDir.appendingPathComponent(historyFilename)
                try prompt.write(to: historyPath, atomically: true, encoding: .utf8)

                // Update the "current" symlink/reference (save as latest.png too)
                let latestPath = shotDir.appendingPathComponent("latest.png")
                if FileManager.default.fileExists(atPath: latestPath.path) {
                    try FileManager.default.removeItem(at: latestPath)
                }
                try imageData.write(to: latestPath)

                let relativePath = "assets/shots/shot_\(shot.shotId)/latest.png"

                await MainActor.run {
                    if let image = NSImage(data: imageData) {
                        previewImage = image
                    }
                    onPreviewGenerated(relativePath)
                    isGenerating = false
                    discoverPreviewImages()
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isGenerating = false
                }
            }
        }
    }

    // MARK: - Generate Preview With Annotations

    private func generatePreviewWithAnnotations(_ annotations: [KeyframeAnnotation]) {
        guard let currentImage = previewImage else { return }

        let editPrompt = ImageAnnotationEditor.buildEditPrompt(from: annotations, context: "shot preview")
        let basePrompt = lastUsedPrompt.isEmpty ? buildPrompt() : lastUsedPrompt
        let combinedPrompt = editPrompt + "\n\nOriginal prompt: " + basePrompt

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let aiClient = AIServiceClient.shared

                // Encode current image as reference
                var refs: [ReferenceImage] = []
                if let tiffData = currentImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    refs.append(ReferenceImage(
                        base64: pngData.base64EncodedString(),
                        mimeType: "image/png",
                        label: "Current shot preview to edit"
                    ))
                }

                // Also collect scene reference images
                if let scene = scene, let projDir = projectBasePath?.deletingLastPathComponent() {
                    let sceneRefs = CharacterReferenceHelper.collectReferenceImages(
                        forScene: scene,
                        characters: characters,
                        locations: locations,
                        projectDirectory: projDir
                    )
                    refs.append(contentsOf: sceneRefs)
                }

                let request = ImageGenerationRequest(
                    prompt: combinedPrompt,
                    provider: .googleImagen,
                    aspectRatio: "16:9",
                    numberOfImages: 1,
                    referenceImages: refs.isEmpty ? nil : refs
                )

                let response = try await aiClient.generateImage(request)

                guard let imageData = response.images.first else {
                    throw AIClientError.invalidResponse("No image generated")
                }

                guard let basePath = projectBasePath else {
                    throw AIClientError.invalidResponse("No project path")
                }

                let projectDir = basePath.deletingLastPathComponent()
                let shotDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("shots")
                    .appendingPathComponent("shot_\(shot.shotId)")

                if !FileManager.default.fileExists(atPath: shotDir.path) {
                    try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let imageFilename = "preview_\(timestamp).png"

                let imagePath = shotDir.appendingPathComponent(imageFilename)
                try imageData.write(to: imagePath)

                // Save the edit prompt
                let promptPath = shotDir.appendingPathComponent("prompt.txt")
                try combinedPrompt.write(to: promptPath, atomically: true, encoding: .utf8)

                let latestPath = shotDir.appendingPathComponent("latest.png")
                if FileManager.default.fileExists(atPath: latestPath.path) {
                    try FileManager.default.removeItem(at: latestPath)
                }
                try imageData.write(to: latestPath)

                let relativePath = "assets/shots/shot_\(shot.shotId)/latest.png"

                await MainActor.run {
                    if let image = NSImage(data: imageData) {
                        previewImage = image
                    }
                    lastUsedPrompt = combinedPrompt
                    onPreviewGenerated(relativePath)
                    isGenerating = false
                    discoverPreviewImages()
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isGenerating = false
                }
            }
        }
    }

    // MARK: - Build Prompt

    private func buildPrompt() -> String {
        var parts: [String] = []

        // Base cinematic instruction
        parts.append("Cinematic film still, professional cinematography")

        // Shot type and framing
        parts.append("\(shot.shotType) shot")

        // Camera angle
        parts.append("\(shot.cameraAngle) angle")

        // Lens characteristics
        if let lens = shot.lensMm {
            if lens <= 24 {
                parts.append("wide angle lens, expansive view")
            } else if lens >= 85 {
                parts.append("telephoto lens, compressed perspective, shallow depth of field")
            } else if lens >= 50 {
                parts.append("natural perspective, cinematic depth")
            }
        }

        // Aperture / depth of field
        if shot.aperture.contains("1.") || shot.aperture.contains("2.") {
            parts.append("shallow depth of field, bokeh background")
        } else if shot.aperture.contains("8") || shot.aperture.contains("11") || shot.aperture.contains("16") {
            parts.append("deep focus, sharp throughout")
        }

        // Movement hint
        if shot.movement != "Static" {
            parts.append("sense of \(shot.movement.lowercased()) movement")
        }

        // Shot description
        if !shot.description.isEmpty {
            parts.append(shot.description)
        }

        // Scene context
        if let scene = scene {
            // Location — detailed description
            if let locationName = scene.location, !locationName.isEmpty {
                if let location = locations.first(where: { $0.name.lowercased() == locationName.lowercased() }) {
                    var locDesc = "Location: \(location.name)"
                    if !location.locationType.isEmpty {
                        locDesc += " (\(location.locationType))"
                    }
                    if !location.description.isEmpty {
                        locDesc += " — \(location.description.prefix(200))"
                    }
                    parts.append(locDesc)
                } else {
                    parts.append("set in \(locationName)")
                }
            }

            // Scene description
            if !scene.description.isEmpty {
                parts.append(scene.description.prefix(200).description)
            }

            // Characters in scene — detailed descriptions for visual accuracy
            let sceneCharacters = getCharactersInScene(scene)
            if !sceneCharacters.isEmpty {
                let charDescriptions = sceneCharacters.prefix(3).map { char -> String in
                    var desc = char.name
                    let physicalDesc = buildCharacterDescription(char)
                    if !physicalDesc.isEmpty {
                        desc += " (\(physicalDesc.prefix(150)))"
                    }
                    if let costumes = char.costumes, let first = costumes.first {
                        desc += ", wearing \(first.name)"
                    }
                    return desc
                }
                parts.append("Characters: \(charDescriptions.joined(separator: "; "))")
            }

            // Sample dialogue for mood
            if let firstDialogue = scene.dialogues.first, !firstDialogue.text.isEmpty {
                parts.append("mood: \"\(firstDialogue.text.prefix(80))...\"")
            }
        }

        // Style and format
        parts.append("Dramatic lighting, film grain, cinematic color grading, 35mm film aesthetic, photorealistic")
        parts.append("Widescreen 16:9 landscape composition, full frame edge-to-edge, no black bars or letterboxing")

        return parts.joined(separator: ". ")
    }

    private func buildPromptSummary() -> String {
        var summary: [String] = []
        summary.append("\(shot.shotType) • \(shot.cameraAngle)")
        if let scene = scene {
            summary.append(scene.name)
        }
        return summary.joined(separator: " • ")
    }

    private func getCharactersInScene(_ scene: DCScene) -> [Character] {
        let characterNames = Set(scene.dialogues.map { $0.character })
        return characters.filter { characterNames.contains($0.name) }
    }

    /// Build a brief physical description from character attributes
    private func buildCharacterDescription(_ char: Character) -> String {
        var parts: [String] = []

        // Use about field if available
        if !char.about.isEmpty {
            return char.about
        }

        // Otherwise build from physical attributes
        if char.age > 0 {
            parts.append("\(char.age) year old")
        }

        if !char.gender.isEmpty && char.gender != "neutral" {
            parts.append(char.gender)
        }

        if !char.build.isEmpty && char.build != "Average" {
            parts.append(char.build.lowercased())
        }

        if !char.hairColor.isEmpty && !char.hairColor.hasPrefix("#") {
            parts.append("\(char.hairColor) hair")
        } else if !char.hairStyle.isEmpty {
            parts.append("\(char.hairStyle) hair")
        }

        if !char.distinguishingFeatures.isEmpty {
            parts.append(char.distinguishingFeatures)
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Prompt Editor Sheet

private struct PromptEditorSheet: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    let onGenerate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shot Preview Prompt")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Prompt editor
            VStack(alignment: .leading, spacing: 12) {
                Text("Edit the prompt below to customize the generated image:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                TextEditor(text: $prompt)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
                    )
                    .frame(minHeight: 200)

                // Tips
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tips:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)

                    Group {
                        Label("Be specific about camera angles, lighting, and mood", systemImage: "lightbulb")
                        Label("Include character descriptions for better results", systemImage: "person")
                        Label("Add style keywords like 'cinematic', 'film noir', '35mm'", systemImage: "film")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.top, 8)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    isPresented = false
                    onGenerate(prompt)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate with Prompt")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: 600, height: 480)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Shot Preview Full Size Sheet

private struct ShotPreviewFullSizeSheet: View {
    let image: NSImage?
    let shotId: Int
    @Binding var isPresented: Bool
    let onDownload: () -> Void

    private var imageSize: CGSize {
        guard let image = image else { return CGSize(width: 900, height: 506) }
        return image.size
    }

    private var sheetSize: (width: CGFloat, height: CGFloat) {
        let chromeHeight: CGFloat = 100 // header + footer + dividers
        let aspectRatio = imageSize.width / max(imageSize.height, 1)
        let displayWidth = min(imageSize.width, 1200)
        let displayHeight = displayWidth / aspectRatio
        return (displayWidth, displayHeight + chromeHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shot #\(shotId) Preview")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Image
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No preview available")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1A1A1A"))
            }

            Divider()

            // Footer
            HStack {
                if let image = image {
                    Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onDownload) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Download")
                    }
                }

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: sheetSize.width, height: sheetSize.height)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Shot Info Pill

private struct ShotInfoPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundColor(.gray)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(4)
    }
}

// MARK: - Camera Setting Card (Read-only, kept for reference)

private struct CameraSettingCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
    }
}

// MARK: - Shot Attribute Descriptions

/// Descriptions for camera angles to help users choose
private let cameraAngleDescriptions: [String: String] = [
    "Eye Level": "Natural, neutral perspective at subject's eye height. Creates relatability and connection.",
    "Low": "Camera looks up at subject. Conveys power, dominance, or heroism.",
    "High": "Camera looks down on subject. Suggests vulnerability, weakness, or insignificance.",
    "Dutch": "Tilted camera angle. Creates unease, tension, or psychological disturbance.",
    "Bird's Eye": "Directly overhead view. Provides god-like perspective, shows spatial relationships.",
    "Worm's Eye": "Extreme low angle from ground. Dramatic effect, makes subjects appear monumental.",
    "POV": "Point of view shot. Shows exactly what character sees, creates immersion."
]

/// Descriptions for shot types to help users choose
private let shotTypeDescriptions: [String: String] = [
    "ECU": "Extreme Close-Up — Single feature (eyes, hands). Intense focus, heightens emotion.",
    "CU": "Close-Up — Face fills frame. Shows emotion and reaction, creates intimacy.",
    "MCU": "Medium Close-Up — Chest up. Intimate but not too personal, great for dialogue.",
    "MS": "Medium Shot — Waist up. Standard conversational framing, shows body language.",
    "MWS": "Medium Wide Shot — Subject from knees up. Balances character and environment.",
    "WS": "Wide Shot — Shows full body with environment. Establishes setting and character's place in it.",
    "EWS": "Extreme Wide Shot — Establishes vast environment, subject appears tiny. Great for landscapes.",
    "OTS": "Over The Shoulder — Shows subject from behind another character. Creates intimacy in dialogue.",
    "2S": "Two Shot — Two subjects in frame. Shows relationship and interaction between characters.",
    "3S": "Three Shot — Three subjects in frame. Shows group dynamics while maintaining focus.",
    "Group": "Group Shot — Multiple subjects. Establishes group dynamics and relationships.",
    "Insert": "Insert Shot — Detail shot of object or action. Draws attention to important story elements.",
    "Cutaway": "Cutaway — Shot of something outside main action. Provides context or parallel action.",
    "POV": "Point of View — Shows exactly what character sees. Creates immersion and subjectivity.",
    "Reaction": "Reaction Shot — Character's response to events. Essential for emotional impact."
]

/// Descriptions for camera movements to help users choose
private let movementDescriptions: [String: String] = [
    "Static": "No camera movement. Stable, observational, lets action unfold naturally.",
    "Pan Left": "Horizontal rotation left. Follows action or reveals environment to the left.",
    "Pan Right": "Horizontal rotation right. Follows action or reveals environment to the right.",
    "Tilt Up": "Vertical rotation upward. Reveals height, follows upward movement, shows scale.",
    "Tilt Down": "Vertical rotation downward. Focuses attention, moves down to subject.",
    "Dolly In": "Camera moves toward subject. Increases intensity, draws viewer in emotionally.",
    "Dolly Out": "Camera moves away from subject. Creates distance, reveals context.",
    "Dolly Left": "Camera slides left. Reveals new elements, follows lateral action.",
    "Dolly Right": "Camera slides right. Reveals new elements, follows lateral action.",
    "Tracking": "Camera follows alongside subject. Creates energy, keeps pace with action.",
    "Crane Up": "Camera rises vertically. Reveals scope, often used for dramatic endings.",
    "Crane Down": "Camera descends vertically. Focuses attention, moves into scene.",
    "Handheld": "Deliberate camera shake. Creates urgency, documentary feel, tension.",
    "Steadicam": "Smooth handheld movement. Fluid following shots, dreamlike quality.",
    "Zoom In": "Lens zooms closer. Quick focus shift, can feel voyeuristic or dramatic.",
    "Zoom Out": "Lens zooms wider. Reveals context, can create isolation effect.",
    "Push In": "Slow move toward subject. Builds tension, focuses attention gradually.",
    "Pull Out": "Slow move away from subject. Reveals surprise, shows isolation.",
    "Arc Left": "Camera moves in curved path left around subject. Dynamic reveal, adds dimension.",
    "Arc Right": "Camera moves in curved path right around subject. Dynamic reveal, adds dimension.",
    "Whip Pan": "Very fast pan. Creates energy, shows passage of time, transitions scenes."
]

/// Descriptions for lens focal lengths
private let lensDescriptions: [Int: String] = [
    16: "Ultra wide — Dramatic distortion, vast environments, claustrophobic interiors",
    24: "Wide angle — Expansive view, slight distortion, great for landscapes and interiors",
    28: "Moderate wide — Natural wide view, minimal distortion, versatile storytelling lens",
    35: "Classic cinema — Natural perspective, slight width, the 'director's lens'",
    50: "Standard — Closest to human vision, neutral and natural look",
    85: "Portrait — Flattering compression, beautiful bokeh, ideal for close-ups",
    100: "Short telephoto — Compressed perspective, intimate feel, great for dialogue",
    135: "Telephoto — Strong compression, isolates subject, cinematic depth",
    200: "Long telephoto — Extreme compression, voyeuristic feel, dramatic isolation"
]

/// Descriptions for aperture values
private let apertureDescriptions: [String: String] = [
    "f/1.2": "Extremely shallow depth — Dreamy, romantic, razor-thin focus plane",
    "f/1.4": "Very shallow depth — Beautiful bokeh, subject isolation, low light capable",
    "f/1.8": "Shallow depth — Soft backgrounds, subject emphasis, intimate feel",
    "f/2": "Moderately shallow — Good separation, natural look, versatile",
    "f/2.8": "Standard cinema — Classic look, manageable focus, professional standard",
    "f/4": "Moderate depth — More in focus, easier to shoot, good for movement",
    "f/5.6": "Medium depth — Balanced sharpness, good for group shots",
    "f/8": "Deep focus — Most of frame sharp, documentary style, landscape work",
    "f/11": "Very deep focus — Nearly everything sharp, detailed environments",
    "f/16": "Maximum depth — Everything in focus, architectural, maximum detail"
]

// MARK: - Chip Selector (Modern pill-style selector)

private struct ChipSelector: View {
    let icon: String
    let title: String
    let options: [String]
    let selectedValue: String
    let onSelect: (String) -> Void
    var descriptions: [String: String] = [:]

    @State private var hoveredOption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with tooltip
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                // Tooltip appears here, next to title
                if let hovered = hoveredOption, let desc = descriptions[hovered] {
                    Text("— \(desc)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        ChipButton(
                            label: option,
                            isSelected: option == selectedValue,
                            isHoveredBinding: Binding(
                                get: { hoveredOption == option },
                                set: { if $0 { hoveredOption = option } else if hoveredOption == option { hoveredOption = nil } }
                            ),
                            onTap: { onSelect(option) }
                        )
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct ChipButton: View {
    let label: String
    let isSelected: Bool
    @Binding var isHoveredBinding: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .overlay(
                            Capsule()
                                .stroke(isHovered && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .white : .gray)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            isHoveredBinding = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Lens Selector (Compact number chips)

private struct LensSelector: View {
    let icon: String
    let title: String
    let options: [Int]
    let selectedValue: Int?
    let onSelect: (Int) -> Void
    var descriptions: [Int: String] = [:]

    @State private var hoveredLens: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with tooltip
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                if let hovered = hoveredLens, let desc = descriptions[hovered] {
                    Text("— \(desc)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Lens chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { lens in
                        LensChip(
                            value: lens,
                            isSelected: lens == selectedValue,
                            isHoveredBinding: Binding(
                                get: { hoveredLens == lens },
                                set: { if $0 { hoveredLens = lens } else if hoveredLens == lens { hoveredLens = nil } }
                            ),
                            onTap: { onSelect(lens) }
                        )
                    }
                }
            }
        }
        .frame(minWidth: 180)
    }
}

private struct LensChip: View {
    let value: Int
    let isSelected: Bool
    @Binding var isHoveredBinding: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text("\(value)")
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .frame(width: 36, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isHovered && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .white : .gray)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            isHoveredBinding = hovering
        }
    }
}

// MARK: - Aperture Selector (f-stop chips)

private struct ApertureSelector: View {
    let icon: String
    let title: String
    let options: [String]
    let selectedValue: String
    let onSelect: (String) -> Void
    var descriptions: [String: String] = [:]

    @State private var hoveredAperture: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with tooltip
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                if let hovered = hoveredAperture, let desc = descriptions[hovered] {
                    Text("— \(desc)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Aperture chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { aperture in
                        ApertureChip(
                            value: aperture,
                            isSelected: aperture == selectedValue,
                            isHoveredBinding: Binding(
                                get: { hoveredAperture == aperture },
                                set: { if $0 { hoveredAperture = aperture } else if hoveredAperture == aperture { hoveredAperture = nil } }
                            ),
                            onTap: { onSelect(aperture) }
                        )
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }
}

private struct ApertureChip: View {
    let value: String
    let isSelected: Bool
    @Binding var isHoveredBinding: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Text(value)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                .frame(minWidth: 36, minHeight: 28, maxHeight: 28)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isHovered && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .white : .gray)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            isHoveredBinding = hovering
        }
    }
}

// MARK: - Duration Editor (Stepper style)

private struct DurationEditor: View {
    let icon: String
    let title: String
    let value: Double?
    let onValueChange: (Double?) -> Void

    @State private var displayValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            // Duration control
            HStack(spacing: 0) {
                // Decrease button
                Button {
                    let newValue = max(0.5, displayValue - 0.5)
                    displayValue = newValue
                    onValueChange(newValue)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#3A3A3A"))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .cornerRadius(6, corners: [.topLeft, .bottomLeft])

                // Value display
                Text(String(format: "%.1fs", displayValue))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(width: 50, height: 28)
                    .background(Color(hex: "#2A2A2A"))
                    .foregroundColor(.white)

                // Increase button
                Button {
                    let newValue = displayValue + 0.5
                    displayValue = newValue
                    onValueChange(newValue)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#3A3A3A"))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .cornerRadius(6, corners: [.topRight, .bottomRight])
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "#4A4A4A"), lineWidth: 1)
            )
        }
        .onAppear {
            displayValue = value ?? 2.0
        }
        .onChange(of: value) { _, newValue in
            displayValue = newValue ?? 2.0
        }
    }
}

// MARK: - Inline Description Editor

private struct InlineDescriptionEditor: View {
    let description: String
    let characters: [Character]
    let onDescriptionChange: (String) -> Void

    @State private var editText = ""
    @State private var hasInitialized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("Description")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            // Always-editable inline text with @mention support
            CharacterMentionTextEditor(
                text: $editText,
                characters: characters,
                placeholder: "Write a description..."
            )
        }
        .onAppear {
            editText = description
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasInitialized = true
            }
        }
        .onChange(of: editText) { _, newValue in
            if hasInitialized && newValue != description {
                onDescriptionChange(newValue)
            }
        }
        .onChange(of: description) { _, newValue in
            if newValue != editText {
                editText = newValue
            }
        }
    }
}

// MARK: - Reference Media Section

private struct ReferenceMediaSection: View {
    let media: [ReferenceMedia]
    let shotId: Int
    let projectBasePath: URL?
    let onMediaAdded: (ReferenceMedia) -> Void
    let onMediaRemoved: (String) -> Void
    let onUseAsPreview: (String) -> Void

    @State private var isDraggingOver = false
    @State private var showingFilePicker = false
    @State private var selectedMedia: ReferenceMedia?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("Reference Images")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)

                if !media.isEmpty {
                    Text("·")
                        .foregroundColor(.gray.opacity(0.5))
                    Text("\(media.count)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                }

                Spacer()

                // Add button in header
                Button(action: { showingFilePicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("Add")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Media grid or empty state
            if media.isEmpty {
                // Empty state with drop zone
                ReferenceDropZone(
                    isDraggingOver: $isDraggingOver,
                    onTap: { showingFilePicker = true },
                    onDrop: handleDrop
                )
            } else {
                // Scrollable grid of larger thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(media) { item in
                            ReferenceMediaCard(
                                media: item,
                                onRemove: { onMediaRemoved(item.id) },
                                onTap: { selectedMedia = item },
                                onUseAsPreview: item.type == .image ? {
                                    useReferenceAsPreview(item)
                                } : nil
                            )
                        }

                        // Add more button
                        AddMoreButton(
                            isDraggingOver: $isDraggingOver,
                            onTap: { showingFilePicker = true },
                            onDrop: handleDrop
                        )
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie, .video],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $selectedMedia) { media in
            ReferenceMediaPreviewSheet(
                media: media,
                isPresented: Binding(
                    get: { selectedMedia != nil },
                    set: { if !$0 { selectedMedia = nil } }
                ),
                onUseAsPreview: media.type == .image ? {
                    useReferenceAsPreview(media)
                    selectedMedia = nil
                } : nil
            )
        }
    }

    /// Copy reference image to shot preview location and use it as the preview
    private func useReferenceAsPreview(_ media: ReferenceMedia) {
        guard let basePath = projectBasePath else { return }

        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shotId)")

        do {
            // Create directory if needed
            if !FileManager.default.fileExists(atPath: shotDir.path) {
                try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
            }

            // Copy the reference image
            let sourceURL = URL(fileURLWithPath: media.path)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())

            // Save with timestamp for history
            let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let historyFilename = "preview_\(timestamp)_ref.\(ext)"
            let historyPath = shotDir.appendingPathComponent(historyFilename)

            // Copy to history
            if FileManager.default.fileExists(atPath: historyPath.path) {
                try FileManager.default.removeItem(at: historyPath)
            }
            try FileManager.default.copyItem(at: sourceURL, to: historyPath)

            // Also copy as latest.png
            let latestPath = shotDir.appendingPathComponent("latest.png")
            if FileManager.default.fileExists(atPath: latestPath.path) {
                try FileManager.default.removeItem(at: latestPath)
            }

            // Load and save as PNG to ensure format consistency
            if let image = NSImage(contentsOf: sourceURL),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try pngData.write(to: latestPath)
            } else {
                // Fallback: just copy the file
                try FileManager.default.copyItem(at: sourceURL, to: latestPath)
            }

            // Save a note that this was from a reference
            let promptPath = shotDir.appendingPathComponent("prompt.txt")
            let note = "[Reference Image]\nUsed reference image: \(media.caption)\nOriginal path: \(media.path)\nDate: \(Date())"
            try note.write(to: promptPath, atomically: true, encoding: .utf8)

            let relativePath = "assets/shots/shot_\(shotId)/latest.png"
            onUseAsPreview(relativePath)

        } catch {
            print("Error copying reference to preview: \(error)")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            addMedia(from: url, type: .image)
                        }
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier("public.movie") {
                provider.loadItem(forTypeIdentifier: "public.movie", options: nil) { item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            addMedia(from: url, type: .video)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        for url in urls {
            let ext = url.pathExtension.lowercased()
            let type: ReferenceMedia.MediaType = ["mp4", "mov", "m4v", "avi"].contains(ext) ? .video : .image
            addMedia(from: url, type: type)
        }
    }

    private func addMedia(from url: URL, type: ReferenceMedia.MediaType) {
        let media = ReferenceMedia(
            type: type,
            path: url.path,
            caption: url.lastPathComponent
        )
        onMediaAdded(media)
    }
}

// MARK: - Reference Drop Zone (Empty State)

private struct ReferenceDropZone: View {
    @Binding var isDraggingOver: Bool
    let onTap: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(isDraggingOver ? .accentColor : .gray.opacity(0.5))

                Text("Drop images or click to add")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: isDraggingOver ? "#2A2A2A" : "#1E1E1E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isDraggingOver ? Color.accentColor : Color(hex: "#3A3A3A"),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 3])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onDrop(of: [.image, .movie], isTargeted: $isDraggingOver, perform: onDrop)
    }
}

// MARK: - Reference Media Card (Larger Thumbnail)

private struct ReferenceMediaCard: View {
    let media: ReferenceMedia
    let onRemove: () -> Void
    let onTap: () -> Void
    let onUseAsPreview: (() -> Void)?

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            Button(action: onTap) {
                ZStack {
                    if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(hex: "#2A2A2A")
                        VStack(spacing: 6) {
                            Image(systemName: media.type == .video ? "play.rectangle.fill" : "photo")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.4))
                            Text(media.caption)
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.5))
                                .lineLimit(1)
                        }
                    }

                    // Video overlay
                    if media.type == .video && thumbnailImage != nil {
                        Color.black.opacity(0.3)
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Hover overlay with action buttons
                    if isHovered && thumbnailImage != nil {
                        Color.black.opacity(0.4)

                        // Use as Preview button (for images only)
                        if onUseAsPreview != nil {
                            VStack(spacing: 8) {
                                Button(action: { onUseAsPreview?() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo.badge.checkmark")
                                            .font(.system(size: 11))
                                        Text("Use as Preview")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                Text("Click to view")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        } else {
                            Image(systemName: "eye")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Remove button
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color.black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
        .onHover { isHovered = $0 }
        .onAppear { loadThumbnail() }
        .help("Click to view full size")
    }

    private func loadThumbnail() {
        guard media.type == .image else { return }
        let url = URL(fileURLWithPath: media.path)
        if let image = NSImage(contentsOf: url) {
            thumbnailImage = image
        }
    }
}

// MARK: - Add More Button

private struct AddMoreButton: View {
    @Binding var isDraggingOver: Bool
    let onTap: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isHovered = false

    private let cardHeight: CGFloat = 100

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                Text("Add")
                    .font(.system(size: 10))
            }
            .foregroundColor(isHovered || isDraggingOver ? .white : .gray)
            .frame(width: 80, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: isHovered || isDraggingOver ? "#3A3A3A" : "#2A2A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isDraggingOver ? Color.accentColor : Color.white.opacity(0.1),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onDrop(of: [.image, .movie], isTargeted: $isDraggingOver, perform: onDrop)
    }
}

// MARK: - Reference Media Preview Sheet

private struct ReferenceMediaPreviewSheet: View {
    let media: ReferenceMedia
    @Binding var isPresented: Bool
    let onUseAsPreview: (() -> Void)?

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reference Image")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(media.caption)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Image preview
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack(spacing: 12) {
                    if media.type == .video {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Video preview not available")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1A1A1A"))
            }

            Divider()

            // Footer with file info and actions
            HStack {
                if let image = image {
                    Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Use as Preview button (prominent)
                if let onUseAsPreview = onUseAsPreview {
                    Button(action: onUseAsPreview) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.badge.checkmark")
                                .font(.system(size: 12))
                            Text("Use as Shot Preview")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Open in Finder") {
                    NSWorkspace.shared.selectFile(media.path, inFileViewerRootedAtPath: "")
                }
                .font(.caption)

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: 800, height: 600)
        .background(Color(hex: "#252525"))
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard media.type == .image else { return }
        let url = URL(fileURLWithPath: media.path)
        if let loadedImage = NSImage(contentsOf: url) {
            image = loadedImage
        }
    }
}

// MARK: - Corner Radius Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        return path
    }
}

private struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

// MARK: - Storyboard Card

private struct StoryboardCard: View {
    let shot: Shot
    let isSelected: Bool
    var onSelect: (() -> Void)?
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area (placeholder)
            ZStack {
                Rectangle()
                    .fill(Color(hex: "#2A2A2A"))
                    .aspectRatio(16/9, contentMode: .fit)

                VStack {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(shot.shotType)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Info footer
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(shot.shotId)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if let videoPath = shot.videoPath, !videoPath.isEmpty {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green.opacity(0.8))
                    }

                    Spacer()

                    ShotStatusBadge(status: ShotStatus(rawValue: shot.status) ?? .planning)
                }

                Text(shot.description.isEmpty ? shot.cameraAngle : shot.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding(12)
            .background(Color(hex: "#252525"))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect?()
        }
        .onTapGesture(count: 2) {
            onEdit?()
        }
    }
}

// MARK: - Preset Card

private struct PresetCard: View {
    let preset: CameraPreset
    let isSelected: Bool
    var onSelect: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(preset.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }

            HStack(spacing: 16) {
                Label("\(preset.lensMm)mm", systemImage: "circle.dotted")
                Label(preset.aperture, systemImage: "camera.aperture")
            }
            .font(.caption)
            .foregroundColor(.gray)

            Text(preset.description)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(hex: "#2A2A2A"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect?()
        }
    }
}

// MARK: - Shot Editor Sheet

private struct ShotEditorSheet: View {
    @Binding var shot: Shot
    let presets: [CameraPreset]
    let characters: [Character]
    @Binding var isPresented: Bool
    var onSave: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(shot.shotId == 0 ? "New Shot" : "Edit Shot #\(shot.shotId)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.gray)
                        CharacterMentionTextEditor(
                            text: $shot.description,
                            characters: characters,
                            placeholder: "Write a description..."
                        )
                        .frame(minHeight: 80)
                        .background(Color(hex: "#1E1E1E"))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Status
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("Status", selection: $shot.status) {
                            ForEach(ShotStatus.allCases) { status in
                                Text(status.rawValue).tag(status.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    // Camera Settings
                    Text("Camera Settings")
                        .font(.headline)
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Camera Angle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Camera Angle")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Angle", selection: $shot.cameraAngle) {
                                ForEach(CameraAngleOptions.angles, id: \.self) { angle in
                                    Text(angle).tag(angle)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Shot Type
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shot Type")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Type", selection: $shot.shotType) {
                                ForEach(CameraAngleOptions.shotTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Lens
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lens (mm)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Lens", selection: Binding(
                                get: { shot.lensMm ?? 50 },
                                set: { shot.lensMm = $0 }
                            )) {
                                ForEach(CameraAngleOptions.commonLenses, id: \.self) { lens in
                                    Text("\(lens)mm").tag(lens)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Aperture
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aperture")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Aperture", selection: $shot.aperture) {
                                ForEach(CameraAngleOptions.commonApertures, id: \.self) { ap in
                                    Text(ap).tag(ap)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Movement
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Movement")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Picker("Movement", selection: $shot.movement) {
                                ForEach(CameraAngleOptions.movements, id: \.self) { mov in
                                    Text(mov).tag(mov)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration (seconds)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Duration", value: Binding(
                                get: { shot.duration ?? 0 },
                                set: { shot.duration = $0 > 0 ? $0 : nil }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave?()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: 600, height: 550)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Preview

// MARK: - Linked Script Elements Section

/// Shows dialogues, actions, and narrations connected to a shot
/// with color-coded type indicators and "Jump to Script" navigation
private struct LinkedScriptElementsSection: View {
    let shot: Shot
    let scene: DCScene
    var onJumpToScript: ((String, String) -> Void)?

    @State private var isExpanded = true

    private var linkedItems: [(id: String, type: String, icon: String, color: Color, label: String, text: String, character: String?)] {
        var items: [(id: String, type: String, icon: String, color: Color, label: String, text: String, character: String?)] = []

        for dialogueId in shot.linkedDialogueIds {
            if let dialogue = scene.dialogues.first(where: { $0.id == dialogueId }) {
                items.append((
                    id: dialogue.id,
                    type: "dialogue",
                    icon: "text.quote",
                    color: .blue,
                    label: "Dialogue",
                    text: dialogue.text,
                    character: dialogue.character
                ))
            }
        }

        for actionId in shot.linkedActionIds {
            if let action = scene.actions.first(where: { $0.id == actionId }) {
                items.append((
                    id: action.id,
                    type: "action",
                    icon: "figure.walk",
                    color: .orange,
                    label: "Action",
                    text: action.description,
                    character: nil
                ))
            }
        }

        for narrationId in shot.linkedNarrationIds {
            if let narration = scene.narrations.first(where: { $0.id == narrationId }) {
                items.append((
                    id: narration.id,
                    type: "narration",
                    icon: "text.alignleft",
                    color: .teal,
                    label: "Narration",
                    text: narration.text,
                    character: nil
                ))
            }
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)

                    Text("SCRIPT ELEMENTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)

                    Text("\(linkedItems.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.7)))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(Array(linkedItems.enumerated()), id: \.element.id) { _, item in
                        LinkedScriptItemRow(
                            icon: item.icon,
                            color: item.color,
                            label: item.label,
                            text: item.text,
                            character: item.character,
                            onJump: {
                                onJumpToScript?(item.id, item.type)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

/// Individual row for a linked script element
private struct LinkedScriptItemRow: View {
    let icon: String
    let color: Color
    let label: String
    let text: String
    let character: String?
    let onJump: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Type indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4, height: 36)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                        .tracking(0.8)

                    if let character = character {
                        Text(character)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }

                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Jump to script button
            Button(action: onJump) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.doc")
                        .font(.system(size: 10))
                    Text("Script")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isHovered ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternarySystemFill).opacity(0.3))
        )
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
