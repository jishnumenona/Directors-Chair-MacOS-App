//
// CurationView+MediaSources.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

extension CurationView {

    // MARK: - Media Sources Panel

    var mediaSourcesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("MEDIA SOURCES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // Match stats
                let matched = viewModel.matchedTakeCount(in: project)
                let unmatched = viewModel.unmatchedTakeCount(in: project)
                let total = matched + unmatched
                if total > 0 {
                    HStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(Color.white.opacity(0.06))
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(matched == total ? Color.green : Color.accentColor)
                                    .frame(width: max(0, geo.size.width * CGFloat(matched) / CGFloat(total)))
                            }
                        }
                        .frame(width: 40, height: 5)

                        Text("\(matched)/\(total)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(matched == total ? .green : .gray)
                        Text("matched")
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }

                // Rescan
                if !viewModel.mediaSources.isEmpty {
                    Button { viewModel.rescanAllSources() } label: {
                        Image(systemName: viewModel.isScanning ? "progress.indicator" : "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#2A2A2A")))
                    }
                    .buttonStyle(.plain)
                    .help("Rescan all sources")
                }

                // Sort & filter
                Menu {
                    ForEach(CurationSortOrder.allCases, id: \.self) { order in
                        Button {
                            viewModel.sortOrder = order
                        } label: {
                            if viewModel.sortOrder == order {
                                Label(order.rawValue, systemImage: "checkmark")
                            } else {
                                Text(order.rawValue)
                            }
                        }
                    }
                    Divider()
                    Button {
                        viewModel.showOnlyUnmatched.toggle()
                    } label: {
                        if viewModel.showOnlyUnmatched {
                            Label("Show All Takes", systemImage: "line.3.horizontal.decrease.circle")
                        } else {
                            Label("Show Unmatched Only", systemImage: "exclamationmark.triangle")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(viewModel.sortOrder != .takeNumber || viewModel.showOnlyUnmatched ? .accentColor : .gray.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#2A2A2A")))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort & filter")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Sources in two columns
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    mediaSourceColumn(
                        label: "VIDEO",
                        icon: "video.fill",
                        color: .accentColor,
                        sources: viewModel.mediaSources.filter { $0.type == .video },
                        fileCount: viewModel.totalVideoFiles,
                        addLabel: "Add camera folder",
                        onAdd: { viewModel.addVideoSource() }
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 1)

                    mediaSourceColumn(
                        label: "AUDIO",
                        icon: "waveform",
                        color: .blue,
                        sources: viewModel.mediaSources.filter { $0.type == .audio },
                        fileCount: viewModel.totalAudioFiles,
                        addLabel: "Add audio folder",
                        onAdd: { viewModel.addAudioSource() }
                    )
                }

                // Match actions
                if !viewModel.cameraFiles.isEmpty || !viewModel.audioFiles.isEmpty {
                    HStack(spacing: 8) {
                        if !viewModel.cameraFiles.isEmpty {
                            Button {
                                let results = viewModel.autoMatchByTimestamp(project: project)
                                if !results.isEmpty {
                                    viewModel.applyAutoMatchResults(results, project: &project)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock.arrow.2.circlepath").font(.system(size: 9, weight: .semibold))
                                    Text("Auto-Match by Timestamp").font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                            }
                            .buttonStyle(.plain)

                            let hasClipNames = project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }.contains { $0.cameraClipName != nil }
                            if hasClipNames {
                                Button {
                                    let results = viewModel.autoMatchByClipName(project: project)
                                    if !results.isEmpty {
                                        viewModel.applyAutoMatchResults(results, project: &project)
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "text.magnifyingglass").font(.system(size: 9, weight: .semibold))
                                        Text("Match by Clip Name").font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#2A2A2A")))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        // Remap all — re-run matching after adding new sources
                        Button {
                            viewModel.rescanAllSources()
                            // Re-run both matching strategies
                            let tsResults = viewModel.autoMatchByTimestamp(project: project)
                            if !tsResults.isEmpty {
                                viewModel.applyAutoMatchResults(tsResults, project: &project)
                            }
                            let clipResults = viewModel.autoMatchByClipName(project: project)
                            if !clipResults.isEmpty {
                                viewModel.applyAutoMatchResults(clipResults, project: &project)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9, weight: .semibold))
                                Text("Remap All").font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#2A2A2A")))
                        }
                        .buttonStyle(.plain)
                        .help("Rescan sources and re-run all matching")
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Media Source Column

    func mediaSourceColumn(
        label: String,
        icon: String,
        color: Color,
        sources: [MediaSource],
        fileCount: Int,
        addLabel: String,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Column header
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color.opacity(0.7))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.gray.opacity(0.5))

                Spacer()

                if fileCount > 0 {
                    Text("\(fileCount) files")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(color.opacity(0.5))
                }
            }

            // Source rows
            ForEach(sources) { source in
                mediaSourceRow(source: source, color: color)
            }

            // Add button
            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                    Text(sources.isEmpty ? addLabel : "Add source")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(color.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(color.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Media Source Row

    func mediaSourceRow(source: MediaSource, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: source.type == .video ? "sdcard.fill" : "mic.fill")
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.6))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(source.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text("\(source.fileCount) files")
                        .font(.system(size: 8))
                        .foregroundColor(color.opacity(0.45))
                    if let t = source.lastScanned {
                        Text(t, style: .relative)
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.25))
                    }
                }
            }

            Spacer()

            Button { NSWorkspace.shared.open(source.url) } label: {
                Image(systemName: "folder")
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.removeSource(source)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.2))
            }
            .buttonStyle(.plain)
            .help("Remove source")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(hex: "#252525")))
    }
}
