//
//  ProjectSettingsView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Project metadata and settings — redesigned with modern UI
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

// MARK: - Settings Tab Enum

private enum SettingsTab: String, CaseIterable, Identifiable {
    case project = "Project"
    case production = "Production"
    case cinematography = "Cinematography"
    case accounting = "Accounting"
    case ai = "AI"
    case info = "Info"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .project: return "film.stack"
        case .production: return "person.3.fill"
        case .cinematography: return "camera.aperture"
        case .accounting: return "banknote"
        case .ai: return "sparkles"
        case .info: return "info.circle"
        }
    }
}

// MARK: - Main View

struct ProjectSettingsView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var tourManager: GuidedTourManager

    @State private var selectedTab: SettingsTab = .project
    @State private var hasUnsavedChanges = false

    // Project Identity
    @State private var title = ""
    @State private var tagline = ""
    @State private var logline = ""
    @State private var projectDescription = ""

    // Classification (now under Project tab)
    @State private var genre = ""
    @State private var status = ""
    @State private var projectType = ""

    // Production Details
    @State private var director = ""
    @State private var productionCompany = ""

    // Schedule
    @State private var targetDuration = ""
    @State private var startDate = ""
    @State private var endDate = ""

    // Accounting
    @State private var budget = ""
    @State private var defaultExpenseDepartment = ""
    @State private var defaultExpenseAccountCode = ""

    // Cinematography Presets
    @State private var customPresets: [CameraPreset] = []
    @State private var selectedPresetId: String?
    @State private var showingPresetEditor = false
    @State private var editingPreset: CameraPreset?

    // AI Settings
    @State private var aiProxyURL = ""
    @State private var aiDefaultTextProvider = ""
    @State private var aiDefaultImageProvider = ""
    @State private var aiServerHealthy = false
    @State private var aiCheckingHealth = false
    @State private var aiAvailableProviders: [String: Bool] = [:]
    @State private var aiUsageStats: (sessions: Int, totalCost: Double) = (0, 0)

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            settingsTabBar

            Divider()

            // Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case .project:
                        projectIdentitySection
                        projectClassificationSection
                        projectStorySection
                    case .production:
                        productionTeamSection
                        productionScheduleSection
                    case .cinematography:
                        cinematographyPresetsSection
                        cinematographyDefaultsSection
                        cinematographyOptionsSection
                    case .accounting:
                        accountingBudgetSection
                        accountingDefaultsSection
                    case .ai:
                        aiServerSection
                        aiProvidersSection
                        aiUsageSection
                    case .info:
                        projectStatsSection
                        projectFileSection
                        guidedTourSection
                    }

                    // Save bar — always visible when there are changes
                    if hasUnsavedChanges {
                        saveBar
                    }
                }
                .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadFromProject() }
        .onChange(of: title) { _ in checkForChanges() }
        .onChange(of: tagline) { _ in checkForChanges() }
        .onChange(of: logline) { _ in checkForChanges() }
        .onChange(of: projectDescription) { _ in checkForChanges() }
        .onChange(of: director) { _ in checkForChanges() }
        .onChange(of: productionCompany) { _ in checkForChanges() }
        .onChange(of: genre) { _ in checkForChanges() }
        .onChange(of: status) { _ in checkForChanges() }
        .onChange(of: projectType) { _ in checkForChanges() }
        .onChange(of: targetDuration) { _ in checkForChanges() }
        .onChange(of: budget) { _ in checkForChanges() }
        .onChange(of: startDate) { _ in checkForChanges() }
        .onChange(of: endDate) { _ in checkForChanges() }
        .onChange(of: defaultExpenseDepartment) { _ in checkForChanges() }
        .onChange(of: defaultExpenseAccountCode) { _ in checkForChanges() }
    }

    // MARK: - Tab Bar

    private var settingsTabBar: some View {
        HStack(spacing: 0) {
            // Back button
            if coordinator.canNavigateBack {
                Button {
                    coordinator.navigateBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .help("Go back (⌘[)")

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 6)
            }

            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()

            // Unsaved indicator
            if hasUnsavedChanges {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("Unsaved changes")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Project Identity Section

    private var projectIdentitySection: some View {
        SettingsCard(title: "PROJECT IDENTITY", icon: "film.stack") {
            VStack(alignment: .leading, spacing: 16) {
                SettingsTextField(
                    label: "Project Title",
                    icon: "textformat",
                    placeholder: "Enter project title",
                    text: $title
                )

                SettingsTextField(
                    label: "Tagline",
                    icon: "quote.opening",
                    placeholder: "A short catchy tagline...",
                    text: $tagline
                )
            }
        }
    }

    // MARK: - Project Classification Section (moved from Production)

    private var projectClassificationSection: some View {
        SettingsCard(title: "CLASSIFICATION", icon: "tag.fill") {
            VStack(alignment: .leading, spacing: 18) {
                // Genre
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "theatermasks.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Genre")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    let genres = ["Drama", "Comedy", "Action", "Thriller", "Horror", "Romance", "Sci-Fi", "Fantasy", "Documentary", "Animation"]
                    SettingsChipGrid(options: genres, selected: $genre)

                    TextField("Or type a custom genre...", text: $genre)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                Divider().opacity(0.5)

                // Status
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Status")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    let statuses = ["Analysis", "Pre-production", "Production", "Post-production", "Completed"]
                    SettingsChipGrid(options: statuses, selected: $status)
                }

                Divider().opacity(0.5)

                // Project Type
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "film")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Project Type")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    let types = ["Short Film", "Feature Film", "Series", "Skit", "Music Video", "Documentary", "Commercial", "Game Play"]
                    SettingsChipGrid(options: types, selected: $projectType)
                }
            }
        }
    }

    // MARK: - Project Story Section

    private var projectStorySection: some View {
        SettingsCard(title: "STORY", icon: "book") {
            VStack(alignment: .leading, spacing: 16) {
                // Logline
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Logline")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    TextField("A 1-2 sentence summary of the story...", text: $logline, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .lineLimit(2...4)
                        .padding(10)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Description")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    TextEditor(text: $projectDescription)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 100)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Production Team Section

    private var productionTeamSection: some View {
        SettingsCard(title: "TEAM", icon: "person.2.fill") {
            HStack(alignment: .top, spacing: 16) {
                SettingsTextField(
                    label: "Director",
                    icon: "person.fill",
                    placeholder: "Director name",
                    text: $director
                )
                SettingsTextField(
                    label: "Production Company",
                    icon: "building.2.fill",
                    placeholder: "Company name",
                    text: $productionCompany
                )
            }
        }
    }

    // MARK: - Production Schedule Section

    private var productionScheduleSection: some View {
        SettingsCard(title: "SCHEDULE", icon: "calendar") {
            VStack(alignment: .leading, spacing: 16) {
                SettingsTextField(
                    label: "Target Duration",
                    icon: "clock",
                    placeholder: "e.g. 120 minutes",
                    text: $targetDuration
                )

                HStack(alignment: .top, spacing: 16) {
                    SettingsTextField(
                        label: "Start Date",
                        icon: "calendar",
                        placeholder: "YYYY-MM-DD",
                        text: $startDate
                    )
                    SettingsTextField(
                        label: "End Date",
                        icon: "calendar.badge.checkmark",
                        placeholder: "YYYY-MM-DD",
                        text: $endDate
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("Detailed day-by-day scheduling is available in the Production > Schedule tab.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
    }

    // MARK: - Accounting Budget Section

    private var accountingBudgetSection: some View {
        SettingsCard(title: "BUDGET", icon: "dollarsign.circle") {
            SettingsTextField(
                label: "Total Budget",
                icon: "banknote",
                placeholder: "e.g. $50,000",
                text: $budget
            )
        }
    }

    // MARK: - Accounting Defaults Section

    private var accountingDefaultsSection: some View {
        SettingsCard(title: "EXPENSE DEFAULTS", icon: "banknote") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    SettingsTextField(
                        label: "Default Department",
                        icon: "building.columns",
                        placeholder: "e.g. Production, Art, Camera",
                        text: $defaultExpenseDepartment
                    )
                    SettingsTextField(
                        label: "Default Account Code",
                        icon: "number",
                        placeholder: "e.g. 3300",
                        text: $defaultExpenseAccountCode
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("These defaults are pre-filled when creating new expense entries in the Accounting tab.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
    }

    // MARK: - Cinematography Presets Section

    private var cinematographyPresetsSection: some View {
        SettingsCard(title: "CAMERA PRESETS", icon: "camera.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // Actions row
                HStack {
                    Text("\(CameraPreset.defaultPresets.count) built-in + \(customPresets.count) custom")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        editingPreset = nil
                        showingPresetEditor = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("New Preset")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                }

                // Custom presets (editable)
                if !customPresets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Custom Presets")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.8)
                        }

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(customPresets) { preset in
                                PresetCard(
                                    preset: preset,
                                    isSelected: selectedPresetId == preset.id,
                                    isCustom: true,
                                    onSelect: { selectedPresetId = preset.id },
                                    onEdit: {
                                        editingPreset = preset
                                        showingPresetEditor = true
                                    },
                                    onDelete: {
                                        customPresets.removeAll { $0.id == preset.id }
                                        if selectedPresetId == preset.id { selectedPresetId = nil }
                                    }
                                )
                            }
                        }
                    }

                    Divider().opacity(0.5)
                }

                // Built-in presets
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Built-in Presets")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.8)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(CameraPreset.defaultPresets) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: selectedPresetId == preset.id,
                                isCustom: false,
                                onSelect: { selectedPresetId = preset.id },
                                onEdit: nil,
                                onDelete: nil
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPresetEditor) {
            PresetEditorSheet(
                preset: editingPreset,
                onSave: { saved in
                    if let idx = customPresets.firstIndex(where: { $0.id == saved.id }) {
                        customPresets[idx] = saved
                    } else {
                        customPresets.append(saved)
                    }
                    showingPresetEditor = false
                },
                onCancel: { showingPresetEditor = false }
            )
        }
    }

    // MARK: - Cinematography Defaults Section

    private var cinematographyDefaultsSection: some View {
        SettingsCard(title: "NEW SHOT DEFAULTS", icon: "camera.badge.ellipsis") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("These defaults apply when creating new shots in the Cinematography view.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }

                HStack(alignment: .top, spacing: 16) {
                    // Default shot type
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Shot Type")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(["CU", "MCU", "MS", "MWS", "WS", "OTS"], id: \.self) { type in
                                SettingsChip(
                                    label: type,
                                    isSelected: projectViewModel.project.defaultFilmStyle == type,
                                    action: { /* read-only reference */ }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Default lens
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Lens")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(CameraAngleOptions.commonLenses, id: \.self) { lens in
                                Text("\(lens)mm")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(lens == 50 ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                                    )
                                    .foregroundColor(lens == 50 ? .white : .primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Cinematography Options Reference Section

    private var cinematographyOptionsSection: some View {
        SettingsCard(title: "OPTIONS REFERENCE", icon: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 18) {
                // Camera Angles
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "angle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Camera Angles")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(CameraAngleOptions.angles, id: \.self) { angle in
                            Text(angle)
                                .font(.system(size: 10))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                        }
                    }
                }

                Divider().opacity(0.3)

                // Shot Types
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Shot Types")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(CameraAngleOptions.shotTypes, id: \.self) { type in
                            Text(type)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                        }
                    }
                }

                Divider().opacity(0.3)

                // Camera Movements
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Camera Movements")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(CameraAngleOptions.movements, id: \.self) { movement in
                            Text(movement)
                                .font(.system(size: 10))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                        }
                    }
                }

                Divider().opacity(0.3)

                // Apertures
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Apertures")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach(CameraAngleOptions.commonApertures, id: \.self) { ap in
                            Text(ap)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI Server Section

    private var aiServerSection: some View {
        SettingsCard(title: "AI SERVER", icon: "server.rack") {
            VStack(alignment: .leading, spacing: 16) {
                // Server URL
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Proxy Server URL")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text(aiProxyURL)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)

                        // Connection status indicator
                        HStack(spacing: 5) {
                            Circle()
                                .fill(aiCheckingHealth ? Color.yellow : (aiServerHealthy ? Color.green : Color.red))
                                .frame(width: 8, height: 8)
                            Text(aiCheckingHealth ? "Checking..." : (aiServerHealthy ? "Connected" : "Offline"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(aiCheckingHealth ? .yellow : (aiServerHealthy ? .green : .red))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                    }
                }

                // Check connection button
                Button {
                    checkAIHealth()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Test Connection")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
                }
                .buttonStyle(.plain)
                .disabled(aiCheckingHealth)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("All AI operations (text, image, video generation) are routed through this proxy server.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
        .onAppear { checkAIHealth() }
    }

    // MARK: - AI Providers Section

    private var aiProvidersSection: some View {
        SettingsCard(title: "PROVIDERS", icon: "cpu") {
            VStack(alignment: .leading, spacing: 16) {
                // Default providers info
                VStack(alignment: .leading, spacing: 10) {
                    aiProviderRow(
                        label: "Text Generation",
                        icon: "text.bubble",
                        provider: "Google Gemini",
                        detail: "gemini-2.5-flash-preview"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Image Generation",
                        icon: "photo",
                        provider: "Google Imagen",
                        detail: "imagen-3.0-generate"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Video Generation",
                        icon: "film",
                        provider: "Google Veo",
                        detail: "veo-3"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "AI Chat",
                        icon: "bubble.left.and.bubble.right",
                        provider: "Google Gemini",
                        detail: "4000 tokens, temp 0.7"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Character Analysis",
                        icon: "person.text.rectangle",
                        provider: "Google Gemini",
                        detail: "8000 tokens, temp 0.3"
                    )
                    Divider().opacity(0.3)
                    aiProviderRow(
                        label: "Screenplay Import",
                        icon: "doc.text.magnifyingglass",
                        provider: "Google Gemini",
                        detail: "65000 tokens, 5 passes"
                    )
                }

                // Available providers from health check
                if !aiAvailableProviders.isEmpty {
                    Divider().opacity(0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Available Providers")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                            ForEach(aiAvailableProviders.sorted(by: { $0.key < $1.key }), id: \.key) { provider, available in
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(available ? Color.green : Color.red.opacity(0.6))
                                        .frame(width: 6, height: 6)
                                    Text(provider)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(available ? .primary : .secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI Usage Section

    private var aiUsageSection: some View {
        SettingsCard(title: "USAGE & COSTS", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 16) {
                // Session stats from AIUsageTracker
                let tracker = AIUsageTracker.shared
                let sessionStats = tracker.sessionStats

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    StatBadge(icon: "text.bubble", label: "Text Calls", value: "\(sessionStats.totalTextCalls)")
                    StatBadge(icon: "photo", label: "Images", value: "\(sessionStats.totalImages)")
                    StatBadge(icon: "film", label: "Videos", value: "\(sessionStats.totalVideos)")
                    StatBadge(icon: "dollarsign.circle", label: "Session Cost", value: String(format: "$%.2f", sessionStats.totalCostUSD))
                }

                Divider().opacity(0.5)

                // Token usage
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Input Tokens")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(formatNumber(sessionStats.totalPromptTokens))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Output Tokens")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(formatNumber(sessionStats.totalCompletionTokens))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "video")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Video Duration")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(String(format: "%.1fs", sessionStats.totalVideoSeconds))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Cost breakdown
                Divider().opacity(0.5)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Pricing Reference")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 0) {
                        costInfoCell(label: "Text Input", value: "$0.30 / 1M tokens")
                        costInfoCell(label: "Text Output", value: "$2.50 / 1M tokens")
                        costInfoCell(label: "Image", value: "$0.04 / image")
                        costInfoCell(label: "Video", value: "$0.02 / second")
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("Session stats reset when the app restarts. Costs are estimates based on Google Gemini Flash pricing.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
    }

    // MARK: - Project Stats Section

    private var projectStatsSection: some View {
        SettingsCard(title: "PROJECT STATS", icon: "chart.bar.fill") {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 14) {
                StatBadge(icon: "rectangle.stack", label: "Sequences", value: "\(projectViewModel.sequences.count)")
                StatBadge(icon: "film", label: "Scenes", value: "\(projectViewModel.allScenes.count)")
                StatBadge(icon: "person.3.fill", label: "Characters", value: "\(projectViewModel.characters.count)")
                StatBadge(icon: "camera.fill", label: "Shots", value: "\(projectViewModel.allShots.count)")
                StatBadge(icon: "map.fill", label: "Locations", value: "\(projectViewModel.project.locations.count)")
                StatBadge(icon: "text.bubble", label: "Dialogues", value: "\(countDialogues())")
                StatBadge(icon: "person.2.fill", label: "Cast", value: "\(projectViewModel.project.castMembers.count)")
                StatBadge(icon: "wrench.and.screwdriver", label: "Crew", value: "\(projectViewModel.project.crewMembers.count)")
            }
        }
    }

    // MARK: - Project File Section

    private var projectFileSection: some View {
        SettingsCard(title: "FILE DETAILS", icon: "doc.badge.gearshape") {
            VStack(alignment: .leading, spacing: 14) {
                SettingsInfoRow(
                    icon: "number",
                    label: "Project ID",
                    value: projectViewModel.project.id
                )

                Divider().opacity(0.3)

                SettingsInfoRow(
                    icon: "clock",
                    label: "Last Saved",
                    value: projectViewModel.lastSaved.map { formattedDate($0) } ?? "Never"
                )

                Divider().opacity(0.3)

                SettingsInfoRow(
                    icon: "folder",
                    label: "File Path",
                    value: projectViewModel.projectPath?.deletingLastPathComponent().path ?? "Not saved"
                )

                Divider().opacity(0.3)

                SettingsInfoRow(
                    icon: "internaldrive",
                    label: "Storage Size",
                    value: formattedStorageSize(projectViewModel.projectStorageSize)
                )

                // Quick actions
                HStack(spacing: 10) {
                    Button {
                        openProjectFolder()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                            Text("Open in Finder")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(projectViewModel.projectPath == nil)

                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Guided Tour

    private var guidedTourSection: some View {
        SettingsCard(title: "GUIDED TOUR", icon: "questionmark.circle") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Re-run the guided walkthrough to learn about the app's features.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Button {
                        tourManager.resetTour()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("Restart Guided Tour")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if tourManager.hasCompletedTour {
                        Text("Tour completed")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        HStack(spacing: 12) {
            Button {
                loadFromProject()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10))
                    Text("Discard")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .quaternarySystemFill))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                saveToProject()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Save Changes")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - AI Helper Views

    private func aiProviderRow(label: String, icon: String, provider: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(provider)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Text(detail)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
    }

    private func costInfoCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }

    // MARK: - Data Operations

    private func loadFromProject() {
        let p = projectViewModel.project
        title = p.name
        tagline = p.overviewTagline
        logline = p.overviewLogline
        projectDescription = p.description
        director = p.director
        productionCompany = p.productionCompany
        genre = p.genre
        status = p.status
        projectType = p.projectType
        targetDuration = p.targetDuration
        budget = p.budget
        startDate = p.startDate
        endDate = p.endDate
        defaultExpenseDepartment = p.defaultExpenseDepartment
        defaultExpenseAccountCode = p.defaultExpenseAccountCode
        aiProxyURL = "http://localhost:8002"
        hasUnsavedChanges = false
    }

    private func saveToProject() {
        projectViewModel.project.name = title
        projectViewModel.project.overviewTagline = tagline
        projectViewModel.project.overviewLogline = logline
        projectViewModel.project.description = projectDescription
        projectViewModel.project.director = director
        projectViewModel.project.productionCompany = productionCompany
        projectViewModel.project.genre = genre
        projectViewModel.project.status = status
        projectViewModel.project.projectType = projectType
        projectViewModel.project.targetDuration = targetDuration
        projectViewModel.project.budget = budget
        projectViewModel.project.startDate = startDate
        projectViewModel.project.endDate = endDate
        projectViewModel.project.defaultExpenseDepartment = defaultExpenseDepartment
        projectViewModel.project.defaultExpenseAccountCode = defaultExpenseAccountCode
        projectViewModel.isDirty = true
        hasUnsavedChanges = false
    }

    private func checkForChanges() {
        let p = projectViewModel.project
        hasUnsavedChanges =
            title != p.name ||
            tagline != p.overviewTagline ||
            logline != p.overviewLogline ||
            projectDescription != p.description ||
            director != p.director ||
            productionCompany != p.productionCompany ||
            genre != p.genre ||
            status != p.status ||
            projectType != p.projectType ||
            targetDuration != p.targetDuration ||
            budget != p.budget ||
            startDate != p.startDate ||
            endDate != p.endDate ||
            defaultExpenseDepartment != p.defaultExpenseDepartment ||
            defaultExpenseAccountCode != p.defaultExpenseAccountCode
    }

    private func checkAIHealth() {
        aiCheckingHealth = true
        Task {
            let client = AIServiceClient.shared
            let connected = await client.testConnection()

            // Try to get provider availability via health check
            var providers: [String: Bool] = [:]
            if connected {
                if let health = try? await client.checkHealth() {
                    providers = health.providers
                }
            }

            await MainActor.run {
                aiServerHealthy = connected
                aiAvailableProviders = providers
                aiCheckingHealth = false
            }
        }
    }

    private func openProjectFolder() {
        guard let projectPath = projectViewModel.projectPath else { return }
        let projectDir = projectPath.deletingLastPathComponent()
        NSWorkspace.shared.open(projectDir)
    }

    private func countDialogues() -> Int {
        projectViewModel.project.sequences.flatMap(\.scenes).reduce(0) { total, scene in
            total + scene.dialogues.count
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }

    private func formattedStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Settings Card

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Settings Text Field

private struct SettingsTextField: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Chip Grid

private struct SettingsChipGrid: View {
    let options: [String]
    @Binding var selected: String

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(options, id: \.self) { option in
                SettingsChip(
                    label: option,
                    isSelected: selected.localizedCaseInsensitiveCompare(option) == .orderedSame,
                    action: { selected = option }
                )
            }
        }
    }
}

// MARK: - Settings Chip

private struct SettingsChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }
}

// MARK: - Settings Info Row

private struct SettingsInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
    }
}

// MARK: - Preset Card

private struct PresetCard: View {
    let preset: CameraPreset
    let isSelected: Bool
    let isCustom: Bool
    var onSelect: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: isCustom ? "star.fill" : "tray.fill")
                    .font(.system(size: 9))
                    .foregroundColor(isCustom ? .orange : .secondary)

                Text(preset.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                // Hover actions
                if isHovered && isCustom {
                    HStack(spacing: 4) {
                        if let onEdit {
                            Button { onEdit() } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        if let onDelete {
                            Button { onDelete() } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Parameters row
            HStack(spacing: 6) {
                presetParam(icon: "viewfinder", value: preset.shotType)
                presetParam(icon: "angle", value: preset.cameraAngle)
                presetParam(icon: "circle.dashed", value: "\(preset.lensMm)mm")
            }

            HStack(spacing: 6) {
                presetParam(icon: "camera.aperture", value: preset.aperture)
                presetParam(icon: "arrow.triangle.swap", value: preset.movement)
            }

            if !preset.description.isEmpty {
                Text(preset.description)
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .quaternarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect?() }
    }

    private func presetParam(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(.accentColor.opacity(0.7))
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Preset Editor Sheet

private struct PresetEditorSheet: View {
    let preset: CameraPreset?
    let onSave: (CameraPreset) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var shotType = "MS"
    @State private var cameraAngle = "Eye Level"
    @State private var lensMm = 50
    @State private var aperture = "f/2.8"
    @State private var movement = "Static"
    @State private var presetDescription = ""

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(preset == nil ? "New Camera Preset" : "Edit Preset")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "textformat", text: "Preset Name")
                        TextField("e.g. My Hero Shot", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }

                    // Shot Type
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "viewfinder", text: "Shot Type")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 55), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(CameraAngleOptions.shotTypes, id: \.self) { type in
                                chipButton(label: type, isSelected: shotType == type) { shotType = type }
                            }
                        }
                    }

                    // Camera Angle
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "angle", text: "Camera Angle")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 75), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(CameraAngleOptions.angles, id: \.self) { angle in
                                chipButton(label: angle, isSelected: cameraAngle == angle) { cameraAngle = angle }
                            }
                        }
                    }

                    // Lens
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "circle.dashed", text: "Lens (mm)")
                        HStack(spacing: 4) {
                            ForEach(CameraAngleOptions.commonLenses, id: \.self) { lens in
                                chipButton(label: "\(lens)", isSelected: lensMm == lens) { lensMm = lens }
                            }
                        }
                    }

                    // Aperture
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "camera.aperture", text: "Aperture")
                        HStack(spacing: 4) {
                            ForEach(CameraAngleOptions.commonApertures, id: \.self) { ap in
                                chipButton(label: ap, isSelected: aperture == ap) { aperture = ap }
                            }
                        }
                    }

                    // Movement
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "arrow.triangle.swap", text: "Camera Movement")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 75), spacing: 4)], alignment: .leading, spacing: 4) {
                            ForEach(CameraAngleOptions.movements, id: \.self) { mov in
                                chipButton(label: mov, isSelected: movement == mov) { movement = mov }
                            }
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        editorLabel(icon: "text.alignleft", text: "Description")
                        TextField("Short description of this preset...", text: $presetDescription)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button { onCancel() } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    let saved = CameraPreset(
                        id: preset?.id ?? UUID().uuidString,
                        name: name,
                        cameraAngle: cameraAngle,
                        lensMm: lensMm,
                        aperture: aperture,
                        shotType: shotType,
                        movement: movement,
                        description: presetDescription,
                        isDefault: false
                    )
                    onSave(saved)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(preset == nil ? "Create Preset" : "Save Changes")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(name.isEmpty ? Color.gray : Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 520, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let p = preset {
                name = p.name
                shotType = p.shotType
                cameraAngle = p.cameraAngle
                lensMm = p.lensMm
                aperture = p.aperture
                movement = p.movement
                presetDescription = p.description
            }
        }
    }

    private func editorLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ProjectSettingsView()
        .environmentObject(ProjectViewModel())
        .environmentObject(AppCoordinator())
}
