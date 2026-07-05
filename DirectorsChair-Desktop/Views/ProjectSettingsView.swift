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

enum SettingsTab: String, CaseIterable, Identifiable {
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

    @State var selectedTab: SettingsTab = .project
    @State var hasUnsavedChanges = false

    // Project Identity
    @State var title = ""
    @State var tagline = ""
    @State var logline = ""
    @State var projectDescription = ""

    // Classification (now under Project tab)
    @State var genre = ""
    @State var status = ""
    @State var projectType = ""

    // Production Details
    @State var director = ""
    @State var productionCompany = ""

    // Schedule
    @State var targetDuration = ""
    @State var startDate = ""
    @State var endDate = ""

    // Accounting
    @State var budget = ""
    @State var defaultExpenseDepartment = ""
    @State var defaultExpenseAccountCode = ""

    // Cinematography Presets
    @State var customPresets: [CameraPreset] = []
    @State var selectedPresetId: String?
    @State var showingPresetEditor = false
    @State var editingPreset: CameraPreset?

    // AI Settings
    @State var aiProxyURL = ""
    @State var aiDefaultTextProvider = ""
    @State var aiDefaultImageProvider = ""
    @State var aiServerHealthy = false
    @State var aiCheckingHealth = false
    @State var aiAvailableProviders: [String: Bool] = [:]
    @State var aiUsageStats: (sessions: Int, totalCost: Double) = (0, 0)

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
}
