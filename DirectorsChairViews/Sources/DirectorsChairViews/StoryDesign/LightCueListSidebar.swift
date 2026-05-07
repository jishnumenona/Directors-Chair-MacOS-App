// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/LightCueListSidebar.swift
//
// Sidebar list of light cues for the Lighting Design mode

import SwiftUI
import DirectorsChairCore

struct LightCueListSidebar: View {
    @Binding var project: Project
    @Binding var selectedCue: LightCue?
    @State private var searchText = ""
    @State private var filterWorkflow: LightingWorkflow? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                    Text("LIGHT CUES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                    Spacer()
                    Text("\(filteredCues.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(4)
                }

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    TextField("Search cues...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(6)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)

                // Filter chips
                HStack(spacing: 4) {
                    FilterChip(label: "All", isSelected: filterWorkflow == nil) {
                        filterWorkflow = nil
                    }
                    FilterChip(label: "Cinema", isSelected: filterWorkflow == .cinema) {
                        filterWorkflow = .cinema
                    }
                    FilterChip(label: "Theater", isSelected: filterWorkflow == .theater) {
                        filterWorkflow = .theater
                    }
                    Spacer()
                }
            }
            .padding(12)

            Divider()

            // Cue list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCues) { cue in
                        cueRow(cue)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Bottom buttons
            VStack(spacing: 8) {
                Button {
                    addNewCue()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Cue")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button {
                    exportCueSheet()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Cue Sheet")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 250)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Computed

    private var filteredCues: [LightCue] {
        var cues = project.lightCues
        if let wf = filterWorkflow {
            cues = cues.filter { $0.workflow == wf }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            cues = cues.filter {
                $0.name.lowercased().contains(query) ||
                $0.cueNumber.lowercased().contains(query)
            }
        }
        return cues.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Row

    private func cueRow(_ cue: LightCue) -> some View {
        let isSelected = selectedCue?.id == cue.id
        return Button {
            selectedCue = cue
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: cue.markerColor))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(cue.cueNumber)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? .white : .accentColor)
                        Text(cue.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: cue.fixtureType.icon)
                            .font(.system(size: 8))
                        Text(cue.fixtureType.rawValue)
                            .font(.system(size: 9))
                        if let scene = cue.sceneName, !scene.isEmpty {
                            Text("·")
                            Text(scene)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }
                Spacer()

                if !cue.isActive {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Duplicate") { duplicateCue(cue) }
            Divider()
            Button("Delete", role: .destructive) { deleteCue(cue) }
        }
    }

    // MARK: - Actions

    private func addNewCue() {
        let nextNumber = project.lightCues.count + 1
        let cue = LightCue(
            name: "New Light Cue",
            cueNumber: "Q\(nextNumber)",
            sortOrder: nextNumber
        )
        project.lightCues.append(cue)
        selectedCue = cue
    }

    private func duplicateCue(_ cue: LightCue) {
        var dup = cue
        dup.id = UUID().uuidString
        dup.name = cue.name + " (Copy)"
        dup.cueNumber = "Q\(project.lightCues.count + 1)"
        dup.sortOrder = project.lightCues.count + 1
        project.lightCues.append(dup)
        selectedCue = dup
    }

    private func deleteCue(_ cue: LightCue) {
        project.lightCues.removeAll { $0.id == cue.id }
        if selectedCue?.id == cue.id {
            selectedCue = project.lightCues.first
        }
    }

    private func exportCueSheet() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(project.name) - Light Cue Sheet.html"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let html = generateCueSheetHTML()
                try? html.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func generateCueSheetHTML() -> String {
        let cues = project.lightCues.sorted { $0.sortOrder < $1.sortOrder }
        var rows = ""
        for cue in cues {
            let startMin = Int(cue.startTime) / 60
            let startSec = Int(cue.startTime) % 60
            let timeStr = String(format: "%02d:%02d", startMin, startSec)
            rows += """
            <tr style="background: \(cue.markerColor)15;">
                <td>\(cue.cueNumber)</td>
                <td>\(timeStr)</td>
                <td>\(String(format: "%.1f", cue.duration))s</td>
                <td>\(cue.fixtureType.rawValue)</td>
                <td>\(cue.position.rawValue)</td>
                <td>\(Int(cue.intensity * 100))%</td>
                <td><span style="display:inline-block;width:16px;height:16px;background:\(cue.color);border-radius:3px;vertical-align:middle;"></span> \(cue.color)</td>
                <td>\(String(format: "%.1f", cue.fadeInDuration))s / \(String(format: "%.1f", cue.fadeOutDuration))s</td>
                <td>\(cue.notes)</td>
            </tr>
            """
        }

        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <title>\(project.name) - Light Cue Sheet</title>
        <style>
            body { font-family: -apple-system, 'Helvetica Neue', sans-serif; margin: 40px; background: #1a1a1a; color: #e0e0e0; }
            h1 { font-size: 24px; margin-bottom: 4px; }
            h2 { font-size: 14px; color: #888; margin-bottom: 24px; font-weight: normal; }
            table { width: 100%; border-collapse: collapse; font-size: 13px; }
            th { background: #2a2a2a; padding: 10px 12px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #888; border-bottom: 2px solid #444; }
            td { padding: 8px 12px; border-bottom: 1px solid #333; }
            tr:hover { background: #2a2a2a !important; }
            @media print { body { background: white; color: black; } th { background: #f0f0f0; color: #333; border-bottom-color: #999; } td { border-bottom-color: #ddd; } tr:hover { background: transparent !important; } }
        </style>
        </head><body>
        <h1>\(project.name)</h1>
        <h2>Lighting Cue Sheet · \(cues.count) cues · Generated \(Date().formatted(date: .abbreviated, time: .shortened))</h2>
        <table>
        <thead><tr>
            <th>Cue #</th><th>Time</th><th>Duration</th><th>Fixture</th><th>Position</th><th>Intensity</th><th>Color</th><th>Fade In/Out</th><th>Notes</th>
        </tr></thead>
        <tbody>\(rows)</tbody>
        </table>
        </body></html>
        """
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
