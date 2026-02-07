//
//  ScriptToolbar.swift
//  DirectorsChair-Desktop
//
//  Script View: Toolbar with page count, toggles, and export button
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairExports

struct ScriptToolbar: View {
    @ObservedObject var viewModel: ScriptViewModel
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var showShortcutsPopover = false

    var body: some View {
        HStack(spacing: 12) {
            // Page count
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                Text("~\(viewModel.estimatedPageCount) \(viewModel.estimatedPageCount == 1 ? "page" : "pages")")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 16)

            // Scene numbers toggle
            Toggle(isOn: $viewModel.showSceneNumbers) {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.system(size: 11))
                    Text("Scene #")
                        .font(.system(size: 11))
                }
            }
            .toggleStyle(.checkbox)
            .help("Show/hide scene numbers")

            // Scene navigator toggle
            Toggle(isOn: $viewModel.showSceneNavigator) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11))
                    Text("Navigator")
                        .font(.system(size: 11))
                }
            }
            .toggleStyle(.checkbox)
            .help("Show/hide scene navigator sidebar")

            Spacer()

            // Shortcuts help
            Button {
                showShortcutsPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text("Shortcuts")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.borderless)
            .help("View all keyboard shortcuts")
            .popover(isPresented: $showShortcutsPopover, arrowEdge: .bottom) {
                ShortcutsPopoverView()
            }

            // Export dropdown
            Menu {
                Button("Fountain (.fountain)") {
                    exportFountain()
                }
                Button("Final Draft (.fdx)") {
                    exportFDX()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                    Text("Export Script")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 120)
            .help("Export screenplay to industry-standard formats")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }

    // MARK: - Export

    private func exportFountain() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(projectViewModel.project.name).fountain"
        panel.title = "Export Fountain Screenplay"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let content = FountainExportService.exportProject(projectViewModel.project)
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func exportFDX() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = "\(projectViewModel.project.name).fdx"
        panel.title = "Export Final Draft Screenplay"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let content = FDXExportService.exportProject(projectViewModel.project)
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Shortcuts Popover

struct ShortcutsPopoverView: View {
    private let shortcuts: [(key: String, description: String)] = [
        ("Cmd + Shift + N", "New Scene"),
        ("Cmd + Click", "Navigate to element"),
        ("Cmd + [", "Navigate back"),
        ("Cmd + ]", "Navigate forward"),
        ("Tab", "Cycle element type"),
        ("@", "Character name"),
        ("%", "Location"),
        ("$", "Time of day"),
        ("#", "Transition"),
        ("~", "Sound / Music cue"),
        ("^", "Props"),
        ("/", "Script note"),
        ("Esc", "Dismiss autocomplete"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Script Shortcuts")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, shortcut in
                    HStack {
                        Text(shortcut.key)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 130, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                            )

                        Text(shortcut.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 320)
    }
}
