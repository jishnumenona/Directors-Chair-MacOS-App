//
// ProjectOverviewView+Poster.swift
//
// Extracted from ProjectOverviewView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices
import AppKit


// MARK: - Poster Full Screen Viewer

struct PosterFullScreenViewer: View {
    let imageURL: URL?
    let title: String
    var onDownload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()

                Button { onDownload?() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("Download")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .quaternarySystemFill)))
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                        Text("Close")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.8)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Image content
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        ScrollView([.horizontal, .vertical]) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text("Failed to load image")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .empty:
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No image available")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.black)
    }
}

// MARK: - Poster Prompt Editor

struct PosterPromptEditor: View {
    @Binding var prompt: String
    var onGenerate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("EDIT PROMPT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("POSTER")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Prompt editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Generation Prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                TextEditor(text: $prompt)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(8)
                    .frame(minHeight: 140)

                Text("Describe the poster style, mood, lighting, composition, and any key visual elements...")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(2)
            }
            .padding(20)

            Divider()

            // Action buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    onGenerate()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Generate")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Metadata Pill

struct MetadataPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.15))
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}
