//
//  ScriptToolbar.swift
//  DirectorsChair-Desktop
//
//  Script View: Toolbar with page count, toggles, and export button
//

import SwiftUI
import PDFKit
import DirectorsChairCore
import DirectorsChairExports

struct ScriptToolbar: View {
    @ObservedObject var viewModel: ScriptViewModel
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var showShortcutsPopover = false
    @State private var showStatsPopover = false

    var body: some View {
        HStack(spacing: 12) {
            // Page count & word count
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Text("~\(viewModel.estimatedPageCount) \(viewModel.estimatedPageCount == 1 ? "page" : "pages")")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text("\(viewModel.wordCount) words")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                Button {
                    showStatsPopover.toggle()
                } label: {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Script statistics")
                .popover(isPresented: $showStatsPopover, arrowEdge: .bottom) {
                    ScriptStatsPopoverView(stats: viewModel.scriptStats, pageCount: viewModel.estimatedPageCount)
                }
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

            // Pages mode toggle
            Toggle(isOn: $viewModel.showPagesMode) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 11))
                    Text("Pages")
                        .font(.system(size: 11))
                }
            }
            .toggleStyle(.checkbox)
            .help("Show screenplay as distinct pages")

            // Spell check toggle
            Toggle(isOn: $viewModel.spellCheckEnabled) {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.abc")
                        .font(.system(size: 11))
                    Text("Spelling")
                        .font(.system(size: 11))
                }
            }
            .toggleStyle(.checkbox)
            .help("Enable continuous spell checking")

            // Typewriter mode toggle
            Toggle(isOn: $viewModel.typewriterMode) {
                HStack(spacing: 4) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 11))
                    Text("Typewriter")
                        .font(.system(size: 11))
                }
            }
            .toggleStyle(.checkbox)
            .help("Keep cursor centered while typing")

            // Malayalam transliteration toggle
            Toggle(isOn: $viewModel.transliterationEnabled) {
                HStack(spacing: 4) {
                    Image(systemName: "character.textbox")
                        .font(.system(size: 11))
                    Text("മലയാളം")
                        .font(.system(size: 11))
                }
            }
            .toggleStyle(.checkbox)
            .help("Type in English, get Malayalam (Manglish transliteration)")

            Divider()
                .frame(height: 16)

            // Zoom controls
            HStack(spacing: 4) {
                Text("\(Int(viewModel.currentZoom * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)

                Button {
                    viewModel.saveZoomLevel()
                } label: {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Save current zoom level (\(Int(viewModel.currentZoom * 100))%)")

                Button {
                    viewModel.restoreZoomLevel()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Restore saved zoom level (\(Int(viewModel.savedZoomLevel * 100))%)")
            }

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
                Button("PDF (.pdf)") {
                    exportPDF()
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

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(projectViewModel.project.name).pdf"
        panel.title = "Export Screenplay as PDF"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let pdf = PDFExportService.exportScreenplay(projectViewModel.project) {
                    pdf.write(to: url)
                }
            }
        }
    }
}

// MARK: - Script Stats Popover

struct ScriptStatsPopoverView: View {
    let stats: ScreenplayFormatting.ScriptStats
    let pageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Script Statistics")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Overview
                VStack(alignment: .leading, spacing: 6) {
                    Text("OVERVIEW")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        statItem(value: "\(pageCount)", label: "Pages")
                        statItem(value: "\(stats.wordCount)", label: "Words")
                        statItem(value: "\(stats.sceneCount)", label: "Scenes")
                        statItem(value: "\(stats.characterCount)", label: "Characters")
                    }
                }

                Divider()

                // Content breakdown
                VStack(alignment: .leading, spacing: 6) {
                    Text("CONTENT BREAKDOWN")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dialogue")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("\(stats.dialogueWordCount) words (\(Int(stats.dialoguePercentage))%)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Action")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("\(stats.actionWordCount) words (\(Int(stats.actionPercentage))%)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                    }

                    // Ratio bar
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: max(4, geo.size.width * stats.dialoguePercentage / 100))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: max(4, geo.size.width * stats.actionPercentage / 100))
                        }
                    }
                    .frame(height: 6)
                }

                // Character dialogue breakdown (top 10)
                if !stats.characterStats.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("CHARACTER DIALOGUE")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.2)
                            .foregroundColor(.secondary)

                        ForEach(Array(stats.characterStats.prefix(10))) { stat in
                            HStack {
                                Text(stat.name)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .lineLimit(1)
                                    .frame(maxWidth: 120, alignment: .leading)

                                Spacer()

                                Text("\(stat.lineCount) lines")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)

                                Text("\(stat.wordCount) words")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 340)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.0)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Shortcuts Popover

struct ShortcutsPopoverView: View {
    private let shortcuts: [(key: String, description: String)] = [
        ("Cmd + Shift + N", "New Scene"),
        ("Cmd + Click", "Navigate to element"),
        ("Cmd + F", "Find"),
        ("Cmd + Opt + F", "Find & Replace"),
        ("Cmd + [", "Navigate back"),
        ("Cmd + ]", "Navigate forward"),
        ("Cmd + Z / Cmd + Shift + Z", "Undo / Redo"),
        ("Return", "Next element (Final Draft flow)"),
        ("Tab", "Next element · converts an empty line"),
        ("Ctrl + 1…6", "Set element type"),
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
