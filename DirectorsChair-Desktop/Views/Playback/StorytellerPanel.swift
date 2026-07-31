//
//  StorytellerPanel.swift
//  DirectorsChair-Desktop
//
//  Storyteller UI: the per-scene readiness strip under the transport bar,
//  the cost-confirmation sheet that gates ALL generation, and the
//  slideshow stage overlay the viewfinder mounts while the mode is active.
//
//  There is deliberately NO play/pause or clock here — the main transport
//  bar drives the narration while the mode is active (one source of
//  truth for the whole transport).
//

import SwiftUI
import DirectorsChairCore

// MARK: - Panel (scene-chunk strip + cache controls)

struct StorytellerPanel: View {
    @ObservedObject var engine: StorytellerEngine
    @ObservedObject var narration: StorytellerNarrationPlayer
    let onSeekChunk: (Int) -> Void
    let onClearCache: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                headerLabel

                sceneChips

                Spacer()

                if narration.isWaitingForChunk {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Preparing scene…")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: onClearCache) {
                    Label("Clear narration cache", systemImage: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Delete this project's cached narration audio")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close Storyteller")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var headerLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("STORYTELLER")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
    }

    private var sceneChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(engine.chunks.enumerated()), id: \.element.id) { index, chunk in
                    Button(action: { onSeekChunk(index) }) {
                        HStack(spacing: 4) {
                            chunkStateIcon(chunk)
                            Text(chunk.sceneName)
                                .font(.system(size: 10, weight: index == narration.currentChunkIndex ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(index == narration.currentChunkIndex
                            ? Color.accentColor.opacity(0.25)
                            : Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(chunkHelp(chunk))
                }
            }
        }
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private func chunkStateIcon(_ chunk: StorytellerChunk) -> some View {
        switch chunk.state {
        case .pending:
            Image(systemName: "circle.dotted")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        case .generating:
            ProgressView().controlSize(.mini)
        case .cached:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.green)
        case .ready:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 8))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.orange)
        }
    }

    private func chunkHelp(_ chunk: StorytellerChunk) -> String {
        switch chunk.state {
        case .pending: return "\(chunk.sceneName) — not generated yet"
        case .generating: return "\(chunk.sceneName) — generating narration…"
        case .cached: return "\(chunk.sceneName) — cached ($0)"
        case .ready: return "\(chunk.sceneName) — ready"
        case .failed(let message): return "\(chunk.sceneName) — failed: \(message)"
        }
    }
}

// MARK: - Cost sheet (gates ALL generation)

struct StorytellerCostSheet: View {
    @ObservedObject var engine: StorytellerEngine
    let onGenerate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                Text("Storyteller narration")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text("""
            Each scene is transformed into spoken narration and voiced with \
            AI text-to-speech. Cached scenes cost nothing; the rest are \
            billed per the estimates below. Nothing is generated until you \
            confirm.
            """)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            sceneTable

            HStack {
                if engine.cachedChunkCount > 0 {
                    Label("\(engine.cachedChunkCount) of \(engine.chunks.count) scenes cached",
                          systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
                Spacer()
                Text("Total to generate: \(costString(engine.totalEstimatedCost))")
                    .font(.system(size: 12, weight: .semibold))
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Generate & Play (~\(costString(engine.totalEstimatedCost)))",
                       action: onGenerate)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private var sceneTable: some View {
        VStack(spacing: 0) {
            ForEach(engine.chunks) { chunk in
                HStack {
                    Text(chunk.sceneName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    if chunk.state == .cached {
                        Label("cached", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    } else {
                        Text("~\(costString(chunk.estimatedCost))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                if chunk.id != engine.chunks.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(nsColor: .quaternarySystemFill))
        .cornerRadius(6)
        .frame(maxHeight: 220)
    }

    private func costString(_ value: Double) -> String {
        value >= 0.01 || value == 0
            ? String(format: "$%.2f", value)
            : String(format: "$%.3f", value)
    }
}

// MARK: - Stage overlay (slideshow in the viewfinder)

struct StorytellerStageOverlay: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var narration: StorytellerNarrationPlayer

    var body: some View {
        ZStack {
            Color.black

            if let url = viewModel.storytellerSlideURL {
                AsyncThumbnail(url: url, displaySize: 720, contentMode: .fit) {
                    Color.black
                }
                .id(url)
                .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(narration.isWaitingForChunk
                         ? "Preparing the story…" : "Storyteller")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }

            // "narrated by AI · cached" badge (bottom-right, above the
            // shot info bar the viewfinder now keeps visible in this mode)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 8))
                        Text(narration.currentChunkIsCached
                             ? "narrated by AI · cached" : "narrated by AI")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 36)
                }
            }
        }
        // Crossfade: identity change on the slide URL animates old-out/new-in.
        .animation(.easeInOut(duration: 0.6), value: viewModel.storytellerSlideURL)
    }
}
