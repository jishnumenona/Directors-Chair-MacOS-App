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
