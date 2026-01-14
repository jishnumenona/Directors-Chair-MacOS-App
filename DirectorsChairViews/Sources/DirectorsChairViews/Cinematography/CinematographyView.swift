// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/CinematographyView.swift
//
// Cinematography View - Shot Planning Interface
// Comprehensive shot composition, camera angles, and lighting setup management.

import SwiftUI
import DirectorsChairCore

// MARK: - Cinematography View

public struct CinematographyView: View {
    // MARK: - Properties

    @StateObject private var viewModel: CinematographyViewModel

    /// Callback when shots change (for persistence)
    public var onShotsChanged: (([Shot]) -> Void)?

    // MARK: - State

    @State private var showingDeleteAlert: Bool = false
    @State private var shotToDelete: String?

    // MARK: - Init

    public init(
        shots: [Shot] = [],
        onShotsChanged: (([Shot]) -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: CinematographyViewModel(shots: shots))
        self.onShotsChanged = onShotsChanged
    }

    // MARK: - Body

    public var body: some View {
        HSplitView {
            // Left sidebar - shot list
            shotListSidebar
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            // Main content area
            mainContentArea
                .frame(minWidth: 500)
        }
        .sheet(isPresented: $viewModel.showingShotEditor) {
            if let shot = viewModel.editingShot {
                ShotEditorSheet(
                    shot: Binding(
                        get: { viewModel.editingShot ?? shot },
                        set: { viewModel.editingShot = $0 }
                    ),
                    presets: viewModel.cameraPresets,
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Shot header
                    shotDetailHeader(shot)

                    Divider()

                    // Camera settings grid
                    shotCameraSettings(shot)

                    Divider()

                    // Description
                    if !shot.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(shot.description)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()
                }
                .padding(24)
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

                    ShotStatusBadge(status: ShotStatus(rawValue: shot.status) ?? .planning)
                }

                Text(shot.shotType)
                    .font(.title3)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button {
                    viewModel.editShot(shot)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.duplicateShot(shot.id)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func shotCameraSettings(_ shot: Shot) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            CameraSettingCard(
                icon: "camera.viewfinder",
                title: "Camera Angle",
                value: shot.cameraAngle
            )

            CameraSettingCard(
                icon: "circle.dotted",
                title: "Lens",
                value: shot.lensMm != nil ? "\(shot.lensMm!)mm" : "—"
            )

            CameraSettingCard(
                icon: "camera.aperture",
                title: "Aperture",
                value: shot.aperture
            )

            CameraSettingCard(
                icon: "rectangle.expand.vertical",
                title: "Shot Type",
                value: shot.shotType
            )

            CameraSettingCard(
                icon: "arrow.left.and.right",
                title: "Movement",
                value: shot.movement
            )

            CameraSettingCard(
                icon: "clock",
                title: "Duration",
                value: shot.duration != nil ? "\(String(format: "%.1f", shot.duration!))s" : "—"
            )
        }
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

    var body: some View {
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

// MARK: - Camera Setting Card

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
                        TextEditor(text: $shot.description)
                            .frame(height: 80)
                            .font(.body)
                            .scrollContentBackground(.hidden)
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
                status: "Shot",
                cameraAngle: "Eye Level",
                lensMm: 85,
                aperture: "f/1.8",
                shotType: "CU",
                movement: "Static",
                duration: 2.0
            )
        ])
        .frame(width: 1200, height: 800)
    }
}
#endif
