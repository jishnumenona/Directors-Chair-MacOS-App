// CurationViewAdapter.swift
// DirectorsChair-Desktop
//
// Bridges ProjectViewModel to CurationView (follows CinematographyViewAdapter pattern)

import SwiftUI
import DirectorsChairCore

struct CurationViewAdapter: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        CurationView(
            project: $projectViewModel.project,
            projectDir: projectViewModel.projectPath?.deletingLastPathComponent()
        )
    }
}
