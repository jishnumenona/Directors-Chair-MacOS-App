//
//  ContentView.swift
//  DirectorsChair-Desktop
//
//  Phase 8: Main App Integration
//  Main window layout with navigation
//

import SwiftUI
import DirectorsChairCore

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        NavigationSplitView(
            columnVisibility: .constant(coordinator.showingNavigator ? .all : .detailOnly)
        ) {
            // Left Sidebar - Navigator
            NavigatorSidebar()
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
                .background(Color(nsColor: .controlBackgroundColor))
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
                    TimelineContainer()
                        .frame(height: 200)
                }
            }
        }
    }
}

// MARK: - Central View Stack

/// Routes to the appropriate view based on coordinator.selectedView
struct CentralViewStack: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        Group {
            switch coordinator.selectedView {
            case .overview:
                ProjectOverviewPlaceholder()
            case .bubble:
                BubblePlaceholder()
            case .scenes:
                ScenesPlaceholder()
            case .assets:
                AssetsPlaceholder()
            case .visionBoard:
                VisionBoardPlaceholder()
            case .shotList:
                ShotListPlaceholder()
            case .schedule:
                SchedulePlaceholder()
            case .castCrew:
                CastCrewPlaceholder()
            case .storyDesign:
                StoryDesignPlaceholder()
            case .settings:
                SettingsPlaceholder()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.selectedView)
    }
}

// MARK: - App Toolbar

struct AppToolbar: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 0) {
            // View Selection (Radio Button Group)
            HStack(spacing: 4) {
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
            }
            .padding(.leading, 12)

            Spacer()

            // Toggle Controls
            HStack(spacing: 8) {
                Divider()
                    .frame(height: 20)

                Button(action: {
                    coordinator.toggleNavigator()
                }) {
                    Image(systemName: "sidebar.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingNavigator))
                .help("Toggle Navigator (⌘⌥1)")

                Button(action: {
                    coordinator.toggleTimeline()
                }) {
                    Image(systemName: "waveform")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingTimeline))
                .help("Toggle Timeline (⌘⌥2)")

                Button(action: {
                    coordinator.toggleRightPanel()
                }) {
                    Image(systemName: "sidebar.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ToggleButtonStyle(isActive: coordinator.showingRightPanel))
                .help("Toggle Right Panel (⌘⌥3)")
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }
}

// MARK: - Toolbar Button Styles

struct ToolbarButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.2)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct ToggleButtonStyle: ButtonStyle {
    let isActive: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(0.15)
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isActive)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Navigator Sidebar

struct NavigatorSidebar: View {
    @State private var selectedTab: NavigatorTab = .outline

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            Picker("Navigator", selection: $selectedTab) {
                ForEach(NavigatorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Tab Content
            Group {
                switch selectedTab {
                case .outline:
                    OutlineTab()
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
    case versions = "Versions"
    case comments = "Comments"

    var id: String { rawValue }
}

// MARK: - Timeline Container

struct TimelineContainer: View {
    var body: some View {
        VStack {
            Text("Timeline View")
                .font(.headline)
            Text("TODO: Integrate Agent 4's TimelineView")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Placeholder Views

struct ProjectOverviewPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Overview", description: "Project pitch and overview information")
    }
}

struct BubblePlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Bubble View", description: "TODO: Integrate Agent 2's BubbleView")
    }
}

struct ScenesPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Scenes", description: "Scene list and management")
    }
}

struct AssetsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Assets", description: "Media library and asset management")
    }
}

struct VisionBoardPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Vision Board", description: "TODO: Integrate Agent 2's VisionBoardView")
    }
}

struct ShotListPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Shot List", description: "TODO: Integrate Agent 2's CinematographyView")
    }
}

struct SchedulePlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Schedule", description: "TODO: Integrate Agent 2's ScheduleView")
    }
}

struct CastCrewPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Cast & Crew", description: "TODO: Integrate Agent 2's CastCrewView")
    }
}

struct StoryDesignPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Story Design", description: "TODO: Integrate Agent 2's StoryDesignView")
    }
}

struct SettingsPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Project Settings", description: "Project metadata and configuration")
    }
}


// MARK: - Generic Placeholder View

struct PlaceholderView: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title)
                .fontWeight(.semibold)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
}
