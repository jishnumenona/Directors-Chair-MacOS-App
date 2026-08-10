// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionImaginePanel.swift
//
// The Imagine panel (DC-0034) — a real generation surface where the
// caret used to be.
//
// Owner: "the image tool needs to be more feature rich than just a text
// input." The ring's Imagine chip now opens this: the prompt, the shape
// of the picture, how many variations, and which pictures ride along as
// references — everything the service could always do and no UI ever
// asked for. It stays a scrap of paper ON the wall (paper-toned, forced
// light), not a system dialog over it.

import SwiftUI
import AppKit

struct VisionImaginePanel: View {
    let onImagine: (ImagineRequest) -> Void
    let onCancel: () -> Void

    @State private var prompt = ""
    @State private var aspectRatio = "16:9"
    @State private var variationCount = 1
    @State private var references: [URL] = []
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(VisionWallPalette.greasePencil)
                Text("Imagine")
                    .font(.system(size: 12, weight: .black))
                    .fontWidth(.condensed)
                Spacer()
            }

            TextField("A rain-slicked night market, neon on wet tarpaulin…",
                      text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(2...4)
                .focused($promptFocused)
                .onSubmit { commit() }
                .padding(7)
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)

            // The picture's shape.
            HStack(spacing: 4) {
                ForEach(ImagineRequest.aspectRatios, id: \.self) { ratio in
                    chip(ratio, isOn: aspectRatio == ratio) {
                        aspectRatio = ratio
                    }
                }
                Spacer()
                // How many to hang side by side.
                ForEach(1...ImagineRequest.maxVariations, id: \.self) { count in
                    chip("×\(count)", isOn: variationCount == count) {
                        variationCount = count
                    }
                }
            }

            // References: the model steers toward these instead of
            // inventing from nothing.
            HStack(spacing: 6) {
                ForEach(references, id: \.self) { url in
                    referenceThumb(url)
                }
                Button {
                    addReferences()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 10))
                        if references.isEmpty {
                            Text("Reference…")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Pictures the result should take after")
                Spacer()
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button {
                    commit()
                } label: {
                    Text(variationCount > 1
                         ? "Imagine ×\(variationCount)" : "Imagine")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                VisionWallPalette.greasePencil.opacity(
                                    canImagine ? 1 : 0.35)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canImagine)
            }
        }
        .padding(13)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(VisionWallPalette.clipping)
                .shadow(color: VisionWallPalette.scrapShadow,
                        radius: 12, y: 5))
        .foregroundStyle(VisionWallPalette.ink)
        .tint(VisionWallPalette.greasePencil)
        .environment(\.colorScheme, .light)
        .onAppear { promptFocused = true }
        .accessibilityIdentifier("imagine-panel")
    }

    private var canImagine: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commit() {
        guard canImagine else { return }
        onImagine(ImagineRequest(prompt: prompt,
                                 aspectRatio: aspectRatio,
                                 variationCount: variationCount,
                                 referenceURLs: references))
    }

    private func chip(_ label: String, isOn: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9.5,
                              weight: isOn ? .bold : .medium,
                              design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOn ? VisionWallPalette.greasePencil
                                   : Color.black.opacity(0.05)))
                .foregroundStyle(isOn ? .white : VisionWallPalette.ink)
        }
        .buttonStyle(.plain)
    }

    private func referenceThumb(_ url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 34, height: 34)
            }
            Button {
                references.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .help(url.lastPathComponent)
    }

    private func addReferences() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP, .tiff]
        panel.title = "Reference Pictures"
        guard panel.runModal() == .OK else { return }
        // Three is plenty for steering; more dilutes all of them.
        references = Array((references + panel.urls).prefix(3))
    }
}
