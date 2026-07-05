//
// ProjectSettingsView+Sections.swift
//
// Extracted from ProjectSettingsView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairServices
import DirectorsChairViews

extension ProjectSettingsView {

    // MARK: - Tab Bar

    var settingsTabBar: some View {
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

    var projectIdentitySection: some View {
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

    var projectClassificationSection: some View {
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

    var projectStorySection: some View {
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

    var productionTeamSection: some View {
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

    var productionScheduleSection: some View {
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

    var accountingBudgetSection: some View {
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

    var accountingDefaultsSection: some View {
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

    var cinematographyPresetsSection: some View {
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

    var cinematographyDefaultsSection: some View {
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

    var cinematographyOptionsSection: some View {
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
}
