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
                coordinator.toggleNavigator()
            }) {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Navigator")

            Button(action: {
                coordinator.toggleTimeline()
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

// MARK: - Toolbar Button Style

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

// MARK: - Navigator Sidebar

struct NavigatorSidebar: View {
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
            Group {
                switch selectedTab {
                case .outline:
                    OutlineTabPlaceholder()
                case .versions:
                    VersionsTabPlaceholder()
                case .comments:
                    CommentsTabPlaceholder()
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

struct OutlineTabPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Outline", description: "Sequences, scenes, and shots tree")
    }
}

struct VersionsTabPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Versions", description: "Project snapshots and version history")
    }
}

struct CommentsTabPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Comments", description: "Collaboration comments and feedback")
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
