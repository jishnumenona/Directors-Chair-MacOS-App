// DirectorsChairViews/Shared/StructuredPromptEditor.swift
//
// Owner 2026-08-29: a prompt is built from many places — the camera chips,
// the description, the location record, the cast, the app's style words —
// and one long text box hid that. This editor shows each part with where
// it comes from, lets the user change or drop a part, and shows the exact
// assembled text that will be sent.

import SwiftUI

/// A reference picture that travels with the prompt (what the model SEES).
public struct PromptPicture: Identifiable, Equatable {
    public let id: String
    public var label: String
    public var image: NSImage

    public init(label: String, image: NSImage) {
        self.id = label + "|" + String(image.hashValue)
        self.label = label
        self.image = image
    }
}

/// One part of a prompt and where it came from.
public struct PromptSection: Identifiable, Equatable {
    public let id: String
    public var title: String
    /// Where the words come from ("Camera section", "Location: Desert road").
    public var source: String
    public var text: String
    public var isIncluded: Bool
    /// App-fixed wording (style, format) is shown but starts read-only.
    public var isFixed: Bool
    /// The reference pictures this part sends along (owner 2026-08-29: show
    /// the picture the model gets, not just the words).
    public var pictures: [PromptPicture]

    public init(id: String, title: String, source: String, text: String, isIncluded: Bool = true, isFixed: Bool = false,
                pictures: [PromptPicture] = []) {
        self.id = id
        self.title = title
        self.source = source
        self.text = text
        self.isIncluded = isIncluded
        self.isFixed = isFixed
        self.pictures = pictures
    }
}

public enum PromptSections {
    /// The wording the annotation composer puts between the marked changes
    /// and the picture's original prompt.
    public static let originalPromptMarker = "\n\nOriginal prompt: "

    /// Sections joined the way the builders always joined their parts.
    public static func assemble(_ sections: [PromptSection], separator: String = ". ") -> String {
        sections.filter { $0.isIncluded && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: separator)
    }

    /// An edit prompt is "Edit this … changes: … Original prompt: <base>".
    public static func isEditPrompt(_ prompt: String) -> Bool {
        prompt.hasPrefix("Edit this ")
    }

    /// The marked changes and the base of an edit prompt, if it is one.
    public static func splitEditPrompt(_ prompt: String) -> (changes: String, original: String)? {
        guard isEditPrompt(prompt), let range = prompt.range(of: originalPromptMarker) else { return nil }
        return (String(prompt[..<range.lowerBound]), String(prompt[range.upperBound...]))
    }

    /// The prompt an annotation edit should call "original": never a previous
    /// edit prompt (that nested edits inside edits, owner report 2026-08-29),
    /// the user's own custom prompt when they wrote one, else the built one.
    public static func baseForEdit(lastUsed: String, built: String) -> String {
        if lastUsed.isEmpty || isEditPrompt(lastUsed) { return built }
        return lastUsed
    }
}

/// The sectioned prompt editor every picture surface can present.
public struct StructuredPromptEditor: View {
    let title: String
    let subtitle: String?
    @Binding var sections: [PromptSection]
    var separator: String = ". "
    var onReset: (() -> Void)?
    let onCancel: () -> Void
    let onGenerate: (String) -> Void

    @State private var showAssembled = true
    @State private var editorHeight: CGFloat = StructuredPromptEditor.hostHeight()
    @State private var unlockedFixed: Set<String> = []

    public init(title: String, subtitle: String? = nil, sections: Binding<[PromptSection]>, separator: String = ". ",
                onReset: (() -> Void)? = nil, onCancel: @escaping () -> Void, onGenerate: @escaping (String) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self._sections = sections
        self.separator = separator
        self.onReset = onReset
        self.onCancel = onCancel
        self.onGenerate = onGenerate
    }

    private var assembled: String { PromptSections.assemble(sections, separator: separator) }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "text.badge.checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle ?? "Each part shows where it comes from. Change a part here for this generation, or turn it off.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let onReset {
                    Button("Rebuild from the shot") { onReset() }
                        .font(.system(size: 11))
                        .help("Throw away edits and rebuild every part from the shot's current facts")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($sections) { $section in
                        sectionCard($section)
                    }

                    // The exact text that will be sent.
                    VStack(alignment: .leading, spacing: 6) {
                        Button { withAnimation(.easeInOut(duration: 0.15)) { showAssembled.toggle() } } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showAssembled ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("What will be sent")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("\(assembled.count) characters")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(assembled, forType: .string)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc").font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if showAssembled {
                            Text(assembled)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(20)
            }

            Divider()

            HStack {
                Text("\(sections.filter(\.isIncluded).count) of \(sections.count) parts included")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button(action: { onGenerate(assembled) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars").font(.system(size: 11))
                        Text("Generate with this prompt").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(assembled.isEmpty)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("structured-prompt-generate")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 820, height: editorHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Measured once from the main window (reading the key window per render
    /// re-sized the sheet when it became key).
    static func hostHeight() -> CGFloat {
        let host = (NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && !$0.isSheet })?.frame.height
            ?? NSScreen.main?.visibleFrame.height ?? 900
        return max(560, min(host * 0.86, 980))
    }

    private func sectionCard(_ section: Binding<PromptSection>) -> some View {
        let locked = section.wrappedValue.isFixed && !unlockedFixed.contains(section.wrappedValue.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle("", isOn: section.isIncluded)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help(section.wrappedValue.isIncluded ? "Leave this part out" : "Include this part")
                Text(section.wrappedValue.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(section.wrappedValue.isIncluded ? .primary : .secondary)
                Text(section.wrappedValue.source)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color(nsColor: .quaternarySystemFill)))
                Spacer()
                if section.wrappedValue.isFixed {
                    Button(locked ? "Edit anyway" : "Editing") {
                        if locked { unlockedFixed.insert(section.wrappedValue.id) } else { unlockedFixed.remove(section.wrappedValue.id) }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            if !section.wrappedValue.pictures.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(section.wrappedValue.pictures) { picture in
                            VStack(spacing: 3) {
                                Image(nsImage: picture.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                Text(picture.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .help("These pictures are sent with the prompt as references")
            }
            if section.wrappedValue.text.isEmpty {
                EmptyView()
            } else if locked {
                Text(section.wrappedValue.text)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .quaternarySystemFill).opacity(0.6))
                    .cornerRadius(6)
            } else {
                TextEditor(text: section.text)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 34, maxHeight: 110)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
                    .accessibilityIdentifier("prompt-section-\(section.wrappedValue.id)")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(section.wrappedValue.isIncluded ? 0.04 : 0.015)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .opacity(section.wrappedValue.isIncluded ? 1 : 0.6)
    }
}
