// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/LightingDesignView.swift
//
// Unified choreography workspace — Gantt chart (left) + detail editor (right)
// Uses buffered editing to avoid full Project re-render on every keystroke.

import SwiftUI
import DirectorsChairCore

private enum SelectedCueType: Equatable {
    case light(String)
    case sfx(String)
    case support(String)
    case none
}

public struct LightingDesignView: View {
    @Binding var project: Project
    let projectBasePath: URL?
    let initialLightCueId: String?
    let initialSFXCueId: String?
    let initialSupportCueId: String?
    let markers: [TimelineMarker]
    @State private var selectedCueType: SelectedCueType = .none

    public init(project: Binding<Project>, projectBasePath: URL?, initialLightCueId: String? = nil, initialSFXCueId: String? = nil, initialSupportCueId: String? = nil, markers: [TimelineMarker] = []) {
        self._project = project
        self.projectBasePath = projectBasePath
        self.initialLightCueId = initialLightCueId
        self.initialSFXCueId = initialSFXCueId
        self.initialSupportCueId = initialSupportCueId
        self.markers = markers
    }

    private var selectedCueId: String? {
        switch selectedCueType {
        case .light(let id): return id
        case .sfx(let id): return id
        case .support(let id): return id
        case .none: return nil
        }
    }

    public var body: some View {
        HSplitView {
            // LEFT: Gantt chart
            LightingGanttView(
                project: $project,
                markers: markers,
                onCueDoubleClicked: nil,
                onSFXCueDoubleClicked: nil,
                onSupportCueDoubleClicked: nil,
                onCueClicked: { id in selectedCueType = .light(id) },
                onSFXCueClicked: { id in selectedCueType = .sfx(id) },
                onSupportCueClicked: { id in selectedCueType = .support(id) },
                selectedCueId: selectedCueId
            )
            .frame(minWidth: 500)

            // RIGHT: Detail editor
            detailEditorPanel
                .frame(minWidth: 320, idealWidth: 400, maxWidth: 500)
        }
        .onAppear {
            if let cueId = initialLightCueId {
                selectedCueType = .light(cueId)
            } else if let sfxId = initialSFXCueId {
                selectedCueType = .sfx(sfxId)
            } else if let supportId = initialSupportCueId {
                selectedCueType = .support(supportId)
            }
        }
        .onChange(of: initialLightCueId) { newId in
            if let cueId = newId {
                selectedCueType = .light(cueId)
            }
        }
        .onChange(of: initialSFXCueId) { newId in
            if let sfxId = newId {
                selectedCueType = .sfx(sfxId)
            }
        }
        .onChange(of: initialSupportCueId) { newId in
            if let supportId = newId {
                selectedCueType = .support(supportId)
            }
        }
    }

    @ViewBuilder
    private var detailEditorPanel: some View {
        switch selectedCueType {
        case .light(let cueId):
            if project.lightCues.contains(where: { $0.id == cueId }) {
                LightCueBufferedEditor(
                    project: $project,
                    cueId: cueId
                )
                .id(cueId)
            } else {
                placeholderView
            }
        case .sfx(let cueId):
            if project.sfxCues.contains(where: { $0.id == cueId }) {
                SFXCueBufferedEditor(
                    project: $project,
                    cueId: cueId
                )
                .id(cueId)
            } else {
                placeholderView
            }
        case .support(let cueId):
            if project.supportCues.contains(where: { $0.id == cueId }) {
                SupportCueBufferedEditor(
                    project: $project,
                    cueId: cueId
                )
                .id(cueId)
            } else {
                placeholderView
            }
        case .none:
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.gantt")
                .font(.system(size: 48))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text("Click a cue in the Gantt chart")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("Select any lighting, SFX, or support cue\nto edit its details here.")
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
