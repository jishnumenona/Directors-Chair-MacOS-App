// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/SFXCueListSidebar.swift
//
// Sidebar list of SFX cues for the SFX choreography mode

import SwiftUI
import DirectorsChairCore

struct SFXCueListSidebar: View {
    @Binding var project: Project
    @Binding var selectedCue: SFXCue?
    @State private var searchText = ""
    @State private var filterEffectType: SFXEffectType? = nil

    private let sfxAccent = Color(hex: "#FF6B35")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(sfxAccent)
                    Text("SFX CUES")
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        SFXFilterChip(label: "All", isSelected: filterEffectType == nil, accent: sfxAccent) {
                            filterEffectType = nil
                        }
                        SFXFilterChip(label: "Smoke", isSelected: filterEffectType == .smoke, accent: sfxAccent) {
                            filterEffectType = .smoke
                        }
                        SFXFilterChip(label: "Pyro", isSelected: filterEffectType == .pyrotechnics, accent: sfxAccent) {
                            filterEffectType = .pyrotechnics
                        }
                        SFXFilterChip(label: "Laser", isSelected: filterEffectType == .laser, accent: sfxAccent) {
                            filterEffectType = .laser
                        }
                        SFXFilterChip(label: "Rain", isSelected: filterEffectType == .rain, accent: sfxAccent) {
                            filterEffectType = .rain
                        }
                        SFXFilterChip(label: "Wind", isSelected: filterEffectType == .wind, accent: sfxAccent) {
                            filterEffectType = .wind
                        }
                        SFXFilterChip(label: "Holo", isSelected: filterEffectType == .hologram, accent: sfxAccent) {
                            filterEffectType = .hologram
                        }
                    }
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
                    .background(sfxAccent.opacity(0.15))
                    .foregroundColor(sfxAccent)
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

    private var filteredCues: [SFXCue] {
        var cues = project.sfxCues
        if let effect = filterEffectType {
            cues = cues.filter { $0.effectType == effect }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            cues = cues.filter {
                $0.name.lowercased().contains(query) ||
                $0.cueNumber.lowercased().contains(query) ||
                $0.effectType.rawValue.lowercased().contains(query)
            }
        }
        return cues.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Row

    private func cueRow(_ cue: SFXCue) -> some View {
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
                            .foregroundColor(isSelected ? .white : sfxAccent)
                        Text(cue.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: cue.effectType.icon)
                            .font(.system(size: 8))
                        Text(cue.effectType.rawValue)
                            .font(.system(size: 9))
                        Text("·")
                        Text(cue.placement.rawValue)
                            .font(.system(size: 9))
                            .lineLimit(1)
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
                    .fill(isSelected ? sfxAccent : Color.clear)
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
        let nextNumber = project.sfxCues.count + 1
        let cue = SFXCue(
            name: "New SFX Cue",
            cueNumber: "FX\(nextNumber)",
            effectType: .smoke,
            startTime: 0,
            duration: 5.0,
            intensity: 0.8,
            markerColor: "#FF6B35",
            placement: .fullStage
        )
        project.sfxCues.append(cue)
        selectedCue = cue
    }

    private func duplicateCue(_ cue: SFXCue) {
        var dup = cue
        dup.id = UUID().uuidString
        dup.name = cue.name + " (Copy)"
        dup.cueNumber = "FX\(project.sfxCues.count + 1)"
        project.sfxCues.append(dup)
        selectedCue = dup
    }

    private func deleteCue(_ cue: SFXCue) {
        project.sfxCues.removeAll { $0.id == cue.id }
        if selectedCue?.id == cue.id {
            selectedCue = project.sfxCues.first
        }
    }

    private func exportCueSheet() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(project.name) - SFX Cue Sheet.html"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let html = generateCueSheetHTML()
                try? html.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func generateCueSheetHTML() -> String {
        let cues = project.sfxCues.sorted { $0.startTime < $1.startTime }
        var rows = ""
        for cue in cues {
            let startMin = Int(cue.startTime) / 60
            let startSec = Int(cue.startTime) % 60
            let timeStr = String(format: "%02d:%02d", startMin, startSec)
            let safetyBadge = cue.requiresVentilation ? "<span style=\"color:#FF6B35;\">⚠ Vent</span>" : ""
            let operatorBadge = cue.operatorRequired ? "<span style=\"color:#FFB347;\">👤 Op</span>" : ""
            rows += """
            <tr style="background: \(cue.markerColor)15;">
                <td>\(cue.cueNumber)</td>
                <td>\(cue.name)</td>
                <td>\(timeStr)</td>
                <td>\(String(format: "%.1f", cue.duration))s</td>
                <td>\(cue.effectType.rawValue)</td>
                <td>\(cue.placement.rawValue)</td>
                <td>\(Int(cue.intensity * 100))%</td>
                <td>\(cue.intensityProfile.rawValue)</td>
                <td>\(cue.transitionIn.rawValue) / \(cue.transitionOut.rawValue)</td>
                <td>\(safetyBadge) \(operatorBadge)</td>
                <td>\(cue.notes)</td>
            </tr>
            """
        }

        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <title>\(project.name) - SFX Cue Sheet</title>
        <style>
            body { font-family: -apple-system, 'Helvetica Neue', sans-serif; margin: 40px; background: #1a1a1a; color: #e0e0e0; }
            h1 { font-size: 24px; margin-bottom: 4px; }
            h2 { font-size: 14px; color: #888; margin-bottom: 24px; font-weight: normal; }
            table { width: 100%; border-collapse: collapse; font-size: 13px; }
            th { background: #2a2a2a; padding: 10px 12px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #888; border-bottom: 2px solid #FF6B35; }
            td { padding: 8px 12px; border-bottom: 1px solid #333; }
            tr:hover { background: #2a2a2a !important; }
            @media print { body { background: white; color: black; } th { background: #f0f0f0; color: #333; border-bottom-color: #FF6B35; } td { border-bottom-color: #ddd; } tr:hover { background: transparent !important; } }
        </style>
        </head><body>
        <h1>\(project.name)</h1>
        <h2>SFX Cue Sheet · \(cues.count) cues · Generated \(Date().formatted(date: .abbreviated, time: .shortened))</h2>
        <table>
        <thead><tr>
            <th>Cue #</th><th>Name</th><th>Time</th><th>Duration</th><th>Effect</th><th>Placement</th><th>Intensity</th><th>Profile</th><th>Transition In/Out</th><th>Safety</th><th>Notes</th>
        </tr></thead>
        <tbody>\(rows)</tbody>
        </table>
        </body></html>
        """
    }
}

// MARK: - SFX Filter Chip

private struct SFXFilterChip: View {
    let label: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? accent : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
