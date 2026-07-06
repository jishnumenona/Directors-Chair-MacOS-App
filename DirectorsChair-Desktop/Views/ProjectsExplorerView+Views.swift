//
// ProjectsExplorerView+Views.swift
//
// Extracted from ProjectsExplorerView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices

extension ProjectsExplorerView {

    // MARK: - Empty State

    var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 60)

                Image(systemName: "clapperboard")
                    .font(.system(size: 64))
                    .foregroundStyle(.linearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                VStack(spacing: 8) {
                    Text("Start Your First Production")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Create a new project or import a screenplay to begin")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 14) {
                    Button(action: { showingNewProjectSheet = true }) {
                        Label("New Project", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("new-project-button")

                    Button(action: { showingImportPicker = true }) {
                        Label("Import Screenplay", systemImage: "doc.text")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .overlay(Capsule().stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                }

                // Example projects section in empty state
                if !ExampleProjectManager.shared.examples.isEmpty {
                    VStack(spacing: 16) {
                        HStack {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor).opacity(0.4))
                                .frame(height: 1)
                            Text("Or explore an example")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .fixedSize()
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor).opacity(0.4))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 40)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(ExampleProjectManager.shared.examples) { example in
                                    ExampleDownloadCard(
                                        example: example,
                                        downloadState: exampleDownloadStates[example.id] ?? .notDownloaded,
                                        isHovered: hoveredExampleId == example.id,
                                        onDownload: { downloadExample(example) }
                                    )
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            hoveredExampleId = hovering ? example.id : nil
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Projects Grid

    var projectsGridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clapperboard.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                            Text("DIRECTOR'S CHAIR")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(.accentColor)
                        }

                        Text("Your Projects")
                            .font(.system(size: 28, weight: .bold))

                        Text("\(projects.count) project\(projects.count == 1 ? "" : "s") in ~/Directors Chair/")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button(action: { showingNewProjectSheet = true }) {
                            Label("New", systemImage: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingImportPicker = true }) {
                            Label("Import", systemImage: "doc.text")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isImporting)

                        Button(action: discoverProjects) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .padding(7)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .overlay(Circle().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Refresh project list")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Projects Grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(projects) { project in
                        ProjectCard(
                            project: project,
                            isHovered: hoveredProjectId == project.id,
                            onOpen: { openProject(project) }
                        )
                        .contextMenu {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([project.path])
                            } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                            Divider()
                            Button(role: .destructive) {
                                projectPendingDelete = project
                            } label: {
                                Label("Delete Project…", systemImage: "trash")
                            }
                        }
                        .accessibilityIdentifier("project-card-\(project.name)")
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredProjectId = hovering ? project.id : nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Example Projects section (only if some are uninstalled)
                if !uninstalledExamples.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.cyan)
                            Text("EXAMPLE PROJECTS")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(.cyan)
                        }

                        Text("Download example projects to explore Director's Chair features")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(uninstalledExamples) { example in
                                    ExampleDownloadCard(
                                        example: example,
                                        downloadState: exampleDownloadStates[example.id] ?? .notDownloaded,
                                        isHovered: hoveredExampleId == example.id,
                                        onDownload: { downloadExample(example) }
                                    )
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            hoveredExampleId = hovering ? example.id : nil
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }

                Spacer(minLength: 24)
            }
        }
    }

    // MARK: - New Project Sheet

    var newProjectSheet: some View {
        VStack(spacing: 20) {
            Text("Create New Project")
                .font(.headline)

            TextField("Project Name", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .accessibilityIdentifier("project-name-field")
                .onSubmit {
                    createNewProject()
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    newProjectName = ""
                    showingNewProjectSheet = false
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    createNewProject()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("create-project-button")
                .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
