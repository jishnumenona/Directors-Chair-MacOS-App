//
// CurationView+MediaSources.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AppKit
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

// MARK: - Watch-folder dailies ingest (§2.18)
//
// The app-side half: DailiesIngest (Core) reads the slate convention and
// finds destinations; DailiesWatcher (Core) reports files that finished
// arriving; this controller copies matched clips into the project's
// footage layout, files the take, kicks the proxy encoder, and parks
// what it cannot place for a human. App-wide (owned by ContentView) so
// watching doesn't stop when the Curation tab unmounts.

@MainActor
final class DailiesIngestController: ObservableObject {

    @Published private(set) var watchFolder: URL?
    @Published private(set) var unsorted: [URL] = []
    @Published private(set) var ingestedThisSession = 0

    private let watcher = DailiesWatcher()
    private weak var projectViewModel: ProjectViewModel?

    private var preferenceKey: String? {
        guard let id = projectViewModel?.project.id else { return nil }
        return "dailiesWatchFolder.\(id)"
    }

    /// Called by ContentView on appear and whenever the open project
    /// changes: re-reads this project's folder choice and re-arms.
    func configure(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
        unsorted = []
        ingestedThisSession = 0
        watcher.stop()
        watchFolder = nil
        guard projectViewModel.hasProject, let key = preferenceKey,
              let path = UserDefaults.standard.string(forKey: key)
        else { return }
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            arm(url)
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Watch Folder for Dailies"
        panel.message = "New video files landing here are ingested as takes."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Watch"
        guard panel.runModal() == .OK, let url = panel.url,
              let key = preferenceKey else { return }
        UserDefaults.standard.set(url.path, forKey: key)
        arm(url)
    }

    func stopWatching() {
        watcher.stop()
        watchFolder = nil
        if let key = preferenceKey {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func arm(_ url: URL) {
        watchFolder = url
        watcher.onFileReady = { [weak self] file in
            self?.absorb(file)
        }
        watcher.start(folder: url)
    }

    private func absorb(_ file: URL) {
        guard let viewModel = projectViewModel, viewModel.hasProject
        else { return }
        let name = file.lastPathComponent
        guard !DailiesIngest.alreadyIngested(fileName: name,
                                             in: viewModel.project),
              !unsorted.contains(file) else { return }
        guard let match = DailiesIngest.parse(fileName: name),
              let destination = DailiesIngest.destination(
                for: match, in: viewModel.project) else {
            unsorted.append(file)
            return
        }
        ingest(file, match: match, at: destination)
    }

    /// A human filing an unsorted clip from the navigator.
    func file(_ file: URL, sequenceIndex: Int, sceneIndex: Int,
              shotIndex: Int) {
        let match = DailiesIngest.parse(fileName: file.lastPathComponent)
            ?? DailiesIngest.Match(sceneNumber: "")
        ingest(file, match: match,
               at: DailiesIngest.Destination(sequenceIndex: sequenceIndex,
                                             sceneIndex: sceneIndex,
                                             shotIndex: shotIndex))
        unsorted.removeAll { $0 == file }
    }

    private func ingest(_ file: URL, match: DailiesIngest.Match,
                        at destination: DailiesIngest.Destination) {
        guard let viewModel = projectViewModel,
              let projectPath = viewModel.projectPath else { return }
        let projectDir = projectPath.deletingLastPathComponent()
        let shot = viewModel.project
            .sequences[destination.sequenceIndex]
            .scenes[destination.sceneIndex]
            .shots[destination.shotIndex]

        // Mirror the recording pipeline's layout exactly, but keep the
        // camera's own file name — it is evidence.
        let footageDir = projectDir
            .appendingPathComponent("footage")
            .appendingPathComponent("Scene_\(shot.shotId)")
            .appendingPathComponent(String(format: "Shot_%03d", shot.shotId))
        try? FileManager.default.createDirectory(
            at: footageDir, withIntermediateDirectories: true)
        var target = footageDir.appendingPathComponent(file.lastPathComponent)
        if FileManager.default.fileExists(atPath: target.path) {
            let stem = (file.lastPathComponent as NSString).deletingPathExtension
            let ext = file.pathExtension
            target = footageDir.appendingPathComponent(
                "\(stem)-\(UUID().uuidString.prefix(6)).\(ext)")
        }
        do {
            try FileManager.default.copyItem(at: file, to: target)
        } catch {
            unsorted.append(file)
            return
        }

        let relative = target.path.replacingOccurrences(
            of: projectDir.path + "/", with: "")
        let take = DailiesIngest.makeTake(
            fileName: file.lastPathComponent,
            relativeVideoPath: relative,
            match: match,
            existingTakes: shot.takes)
        viewModel.project
            .sequences[destination.sequenceIndex]
            .scenes[destination.sceneIndex]
            .shots[destination.shotIndex]
            .takes.append(take)
        ingestedThisSession += 1
        ProxyMediaStore.shared.sweep(relativePaths: [relative],
                                     projectBase: projectDir)
    }
}
