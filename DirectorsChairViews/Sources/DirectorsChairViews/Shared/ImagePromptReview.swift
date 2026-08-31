// DirectorsChairViews/Shared/ImagePromptReview.swift
//
// DC-0093: see the prompt before it goes to the AI — every image surface
// (shots, scenes, locations, characters, costumes, props, vision board,
// assistant actions) passes through AIServiceClient.generateImage, and the
// client hands each composed request to ONE reviewer. The owner asked for
// this after a location came back with a film crew in it: the prompt was
// wrong and nothing showed it. Opt-in: Settings → AI Services → "Review
// each image prompt before it is sent".

import DirectorsChairCore
import DirectorsChairServices
import SwiftUI

/// One request waiting for the user's yes/no/edit.
public struct PendingImagePromptReview: Identifiable {
    public let id = UUID()
    public var request: ImageGenerationRequest
    let resume: (ImageGenerationRequest?) -> Void
}

/// The app's reviewer: queues requests (batch pipelines ask many times),
/// presents one at a time through `pending`, resumes the caller with the
/// user's decision.
@MainActor
public final class ImagePromptReviewCenter: ObservableObject, ImagePromptReviewing {
    @Published public var pending: PendingImagePromptReview?
    private var queue: [PendingImagePromptReview] = []
    /// "Don't ask again this session" — the preference stays on for next time.
    public var pausedForSession = false

    public init() {}

    /// The preference, read at ask time so a change applies at once.
    nonisolated public static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AIProviderSelection.reviewImagePromptsKey)
    }

    nonisolated public func review(_ request: ImageGenerationRequest) async -> ImageGenerationRequest? {
        guard Self.isEnabled else { return request }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard !self.pausedForSession else { continuation.resume(returning: request); return }
                self.enqueue(PendingImagePromptReview(request: request) { continuation.resume(returning: $0) })
            }
        }
    }

    func enqueue(_ review: PendingImagePromptReview) {
        if pending == nil { pending = review } else { queue.append(review) }
    }

    /// Send the (possibly edited) request, or nil to cancel it.
    public func resolve(_ review: PendingImagePromptReview, with decision: ImageGenerationRequest?) {
        review.resume(decision)
        if pending?.id == review.id { pending = queue.isEmpty ? nil : queue.removeFirst() }
    }

    /// Everything still queued goes out as composed (used when the user
    /// pauses reviews mid-batch).
    public func flushQueueUnchanged() {
        for review in queue { review.resume(review.request) }
        queue.removeAll()
    }
}

/// What the user sees: the surface, the model, the size, the references,
/// and the prompt itself — editable — with Send / Cancel.
public struct ImagePromptReviewSheet: View {
    let review: PendingImagePromptReview
    @ObservedObject var center: ImagePromptReviewCenter
    @State private var prompt: String
    @State private var subject: String
    @State private var stopAsking = false

    public init(review: PendingImagePromptReview, center: ImagePromptReviewCenter) {
        self.review = review
        self.center = center
        _prompt = State(initialValue: review.request.prompt)
        _subject = State(initialValue: review.request.brief?.subject ?? "")
    }

    private var request: ImageGenerationRequest { review.request }
    private var isOnDevice: Bool { request.provider == .onDevice }

    private var surfaceName: String {
        switch request.brief?.purpose {
        case .shot: return "Shot preview"
        case .scene: return "Scene preview"
        case .location: return "Location picture"
        case .character: return "Character study"
        case .costume: return "Costume sheet"
        case .prop: return "Prop concept"
        case .moodboard: return "Vision board picture"
        case .edit: return "Edit of an existing picture"
        case nil: return request.isEditOfExistingImage ? "Edit of an existing picture" : "Picture"
        }
    }

    private var providerLine: String {
        if isOnDevice { return "On this Mac · \(LocalImageEngine.model.displayName)" }
        let model = request.model ?? AIProviderSelection.shared.modelId(for: .image) ?? "server default model"
        let provider = AIProviderCatalog.options(for: .image)
            .first { $0.wireId == request.provider.rawValue }?.displayName ?? request.provider.rawValue
        return "\(provider) · \(model)"
    }

    private var sizeLine: String {
        if let size = request.targetSize { return "\(size.width) × \(size.height) (project preview size)" }
        return "Provider default · \(request.aspectRatio)"
    }

    private var referenceLabels: [String] {
        if let refs = request.referenceImages, !refs.isEmpty { return refs.map(\.label) }
        return request.referenceImageBase64 == nil ? [] : ["Reference picture"]
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review prompt — \(surfaceName)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("This is exactly what will be sent. Change it here if it isn't what you meant.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 18) {
                    detail("Model", icon: "cpu", value: providerLine)
                    detail("Size", icon: "aspectratio", value: sizeLine)
                }
                if !referenceLabels.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        label("Reference pictures sent along", icon: "photo.on.rectangle")
                        HStack(spacing: 6) {
                            ForEach(referenceLabels, id: \.self) { ref in
                                Text(ref)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(Color(nsColor: .quaternarySystemFill)))
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if isOnDevice {
                        label("What the local model is asked to draw", icon: "text.alignleft")
                        editor($subject)
                        if let framing = request.brief?.framing, !framing.isEmpty {
                            Text("Framing: \(framing)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Text("The Sketch/Comic look and the reference wording are added by the app after this text.")
                            .font(.system(size: 10))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    } else {
                        label("Prompt", icon: "text.alignleft")
                        editor($prompt)
                    }
                }
                Toggle("Don't ask again this session (the setting stays on for next time)", isOn: $stopAsking)
                    .font(.system(size: 11))
                    .toggleStyle(.checkbox)
            }
            .padding(20)

            Divider()

            HStack {
                Text("Turn this off any time: Settings → AI Services.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                Spacer()
                Button("Cancel") { finish(send: false) }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("prompt-review-cancel")
                Button(action: { finish(send: true) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill").font(.system(size: 11))
                        Text("Send to AI").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("prompt-review-send")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func finish(send: Bool) {
        if stopAsking {
            center.pausedForSession = true
            center.flushQueueUnchanged()
        }
        guard send else { center.resolve(review, with: nil); return }
        var edited = request
        if isOnDevice {
            if var brief = edited.brief, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                brief.subject = subject
                edited.brief = brief
            }
        } else if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            edited.prompt = prompt
        }
        center.resolve(review, with: edited)
    }

    private func label(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.secondary)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
        }
    }

    private func detail(_ title: String, icon: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title, icon: icon)
            Text(value).font(.system(size: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editor(_ text: Binding<String>) -> some View {
        TextEditor(text: text)
            .font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: 140, maxHeight: 260)
            .background(Color(nsColor: .quaternarySystemFill))
            .cornerRadius(6)
            .accessibilityIdentifier("prompt-review-text")
    }
}
