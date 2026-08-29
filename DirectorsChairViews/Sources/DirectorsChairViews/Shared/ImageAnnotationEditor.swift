// DirectorsChairViews/Sources/DirectorsChairViews/Shared/ImageAnnotationEditor.swift
//
// Reusable image annotation editor — extracted from KeyframeAnnotationOverlay

import SwiftUI
import DirectorsChairCore
import AppKit
import DirectorsChairServices

/// A generic image annotation editor that lets users place numbered pins on an image
/// and describe edit instructions for each pin. Used for AI-assisted image editing
/// across keyframes, shot previews, character angles, and location variations.
public struct ImageAnnotationEditor: View {
    let image: NSImage
    let title: String
    let subtitle: String?
    let initialAnnotations: [KeyframeAnnotation]
    /// DC-0102: the story elements the instructions may mention (@ # $ &).
    var characters: [Character] = []
    var locations: [Location] = []
    var props: [Prop] = []
    var shots: [Shot] = []
    var projectDirectory: URL? = nil
    /// Double-click on a mentioned element opens its page.
    var onOpenMention: ((ResolvedMention) -> Void)? = nil
    @Binding var isPresented: Bool
    let onApplyEdits: ([KeyframeAnnotation]) -> Void

    @State private var annotations: [KeyframeAnnotation] = []
    @State private var editorSize: CGSize = ImageAnnotationEditor.hostSize()
    /// Owner 2026-08-29: mark spots, or re-imagine the whole picture.
    @State private var wholePicture = false
    @State private var wholeInstruction = ""
    @State private var selectedAnnotationId: String? = nil
    @State private var editingText: String = ""

    public init(
        image: NSImage,
        title: String,
        subtitle: String? = nil,
        initialAnnotations: [KeyframeAnnotation] = [],
        characters: [Character] = [],
        locations: [Location] = [],
        props: [Prop] = [],
        shots: [Shot] = [],
        projectDirectory: URL? = nil,
        onOpenMention: ((ResolvedMention) -> Void)? = nil,
        isPresented: Binding<Bool>,
        onApplyEdits: @escaping ([KeyframeAnnotation]) -> Void
    ) {
        self.image = image
        self.title = title
        self.subtitle = subtitle
        self.initialAnnotations = initialAnnotations
        self.characters = characters
        self.locations = locations
        self.props = props
        self.shots = shots
        self.projectDirectory = projectDirectory
        self.onOpenMention = onOpenMention
        self._isPresented = isPresented
        self.onApplyEdits = onApplyEdits
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.9))
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                // Mark spots, or change the whole picture from one instruction.
                Picker("", selection: $wholePicture) {
                    Text("Mark spots").tag(false)
                    Text("Whole picture").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 200)
                .accessibilityIdentifier("annotation-mode")
                Button("Cancel") { isPresented = false }
                    .foregroundColor(.gray)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("annotation-cancel")
                Button(action: applyEdits) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Apply Edits")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(canApply ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canApply)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "#1E1E1E"))

            Divider().opacity(0.3)

            // Instruction banner — or, in whole-picture mode, the instruction itself
            Group {
            if wholePicture {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    MentionTextView(text: $wholeInstruction, characters: characters, locations: locations, props: props,
                                    continuityShots: shots, projectDirectory: projectDirectory,
                                    placeholder: "Describe how the whole picture should change — e.g. make it dusk, put @Susan by the door, remove the $Mini van",
                                    onOpenMention: onOpenMention,
                                    submitsOnReturn: true, onSubmit: { if canApply { applyEdits() } })
                        .frame(minHeight: 48, maxHeight: 90)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .onSubmit { if canApply { applyEdits() } }
                        .accessibilityIdentifier("annotation-whole-instruction")
                    Text("The picture is re-imagined from this; its subject and framing are kept unless you say otherwise.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .frame(maxWidth: 260, alignment: .leading)
                }
            } else {
                HStack(spacing: 12) {
                    instructionPill(icon: "hand.tap", text: "Click to add")
                    instructionPill(icon: "cursorarrow.click", text: "Click pin to edit")
                    instructionPill(icon: "trash", text: "Right-click to delete")
                }
            }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(hex: "#1A1A1A"))

            Divider().opacity(0.3)

            // Main content
            HStack(spacing: 0) {
                annotationCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.3)

                annotationListPanel
                    .frame(width: 220)
            }

            Divider().opacity(0.3)

            // Footer
            HStack {
                Text("\(annotations.count) annotation\(annotations.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text("·")
                    .foregroundColor(.gray.opacity(0.4))
                Text("Click pin to edit")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(hex: "#1E1E1E"))
        }
        // Owner 2026-08-29: the picture is the point — take most of the window.
        .frame(width: editorSize.width, height: editorSize.height)
        .background(Color(hex: "#252525"))
        .onAppear {
            annotations = initialAnnotations
        }
    }

    // MARK: - Build Edit Prompt

    /// Builds a textual edit prompt from annotations, suitable for sending to an AI image generator.
    public static func buildEditPrompt(from annotations: [KeyframeAnnotation], context: String = "image") -> String {
        // DC-0073: the one wording, composed in Services beside the request.
        AnnotationEditComposer.instructions(pins: annotations.map(AnnotationPin.init), context: context)
    }

    // MARK: - Instruction Pill

    @ViewBuilder
    private func instructionPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.accentColor.opacity(0.8))
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(4)
    }

    // MARK: - Annotation Canvas

    private var annotationCanvas: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // Calculate aspect-fit dimensions
                let imageAspect = image.size.width / image.size.height
                let containerAspect = geo.size.width / geo.size.height
                let displaySize: CGSize = {
                    if imageAspect > containerAspect {
                        let w = geo.size.width
                        return CGSize(width: w, height: w / imageAspect)
                    } else {
                        let h = geo.size.height
                        return CGSize(width: h * imageAspect, height: h)
                    }
                }()
                let offsetX = (geo.size.width - displaySize.width) / 2
                let offsetY = (geo.size.height - displaySize.height) / 2

                // Image
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Click area for adding pins
                Color.clear
                    .frame(width: displaySize.width, height: displaySize.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let normalizedX = (location.x - offsetX) / displaySize.width
                        let normalizedY = (location.y - offsetY) / displaySize.height
                        guard normalizedX >= 0 && normalizedX <= 1 &&
                              normalizedY >= 0 && normalizedY <= 1 else { return }
                        addAnnotation(at: normalizedX, normalizedY)
                    }

                // The reach of each pin: the circle the on-device engine may
                // repaint (DC-0073) — the same numbers the mask is built from.
                ForEach(annotations) { ann in
                    let reach = (ann.radius ?? EditRegion.defaultRadius) * min(displaySize.width, displaySize.height)
                    Circle()
                        .fill(Color.accentColor.opacity(selectedAnnotationId == ann.id ? 0.14 : 0.07))
                        .overlay(
                            Circle().stroke(Color.accentColor.opacity(selectedAnnotationId == ann.id ? 0.9 : 0.45),
                                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        )
                        .frame(width: reach * 2, height: reach * 2)
                        .position(x: offsetX + ann.normalizedX * displaySize.width,
                                  y: offsetY + ann.normalizedY * displaySize.height)
                        .allowsHitTesting(false)
                }

                // Render pins
                ForEach(annotations) { ann in
                    let pinX = offsetX + ann.normalizedX * displaySize.width
                    let pinY = offsetY + ann.normalizedY * displaySize.height
                    let isSelected = selectedAnnotationId == ann.id

                    annotationPin(annotation: ann, isSelected: isSelected)
                        .position(x: pinX, y: pinY)
                        .onTapGesture {
                            selectAnnotation(ann)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteAnnotation(ann.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                    // Floating text input card below selected pin
                    if isSelected {
                        annotationTextCard(annotation: ann)
                            .position(
                                x: min(max(pinX, 110), geo.size.width - 110),
                                y: min(pinY + 50, geo.size.height - 40)
                            )
                    }
                }
            }
        }
    }

    // MARK: - Annotation Pin

    @ViewBuilder
    private func annotationPin(annotation: KeyframeAnnotation, isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 32, height: 32)

                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }

            Circle()
                .fill(Color.accentColor)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)

            Text("\(annotation.number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .help(annotation.text.isEmpty ? "Click to add description" : annotation.text)
    }

    /// Most of the window the editor sits in (the picture is the point).
    /// Measured ONCE from the app's main window: reading the key window on
    /// every render made the sheet re-size itself when it became key
    /// (owner report 2026-08-29: "the window resized by itself").
    static func hostSize() -> CGSize {
        let host = (NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && $0.isKind(of: NSWindow.self) && !$0.isSheet })?.frame.size
            ?? NSScreen.main?.visibleFrame.size
            ?? CGSize(width: 1400, height: 900)
        return CGSize(width: max(900, host.width * 0.92), height: max(600, host.height * 0.9))
    }

    // MARK: - Annotation Text Card

    @ViewBuilder
    private func annotationTextCard(annotation: KeyframeAnnotation) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text("\(annotation.number)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )

                // The same inline mention editor as the shot description
                // (owner 2026-08-29): pills with pictures, double-click opens.
                MentionTextView(text: $editingText, characters: characters, locations: locations, props: props,
                                continuityShots: shots, projectDirectory: projectDirectory,
                                placeholder: "What changes here? (@ # $ &)", onOpenMention: onOpenMention,
                                submitsOnReturn: true, onSubmit: { confirmEdit() })
                    .frame(width: 260, height: 46)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)

                Button(action: confirmEdit) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .disabled(editingText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // How far the change may reach around the pin (DC-0073) — a
            // slider the dashed circle follows live (owner 2026-08-29: the
            // +/- buttons were not intuitive).
            HStack(spacing: 8) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text("Area")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                Slider(value: Binding(
                    get: { annotation.radius ?? EditRegion.defaultRadius },
                    set: { setReach(of: annotation.id, to: $0) }
                ), in: 0.08...0.5)
                .controlSize(.mini)
                .frame(width: 150)
                .accessibilityIdentifier("annotation-area-slider")
                Text("\(Int((annotation.radius ?? EditRegion.defaultRadius) * 100))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding(8)
        .background(Color(hex: "#1A1A1A").opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        .onExitCommand {
            selectedAnnotationId = nil
            editingText = ""
        }
    }

    // MARK: - Annotation List Panel

    private var annotationListPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Panel header
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("ANNOTATIONS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            if annotations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Click on the image\nto add annotations")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(annotations.sorted(by: { $0.number < $1.number })) { ann in
                            annotationListRow(annotation: ann)
                        }
                    }
                    .padding(.horizontal, 14)
                }

                Spacer()
            }

            // DC-0102: what the instructions mention, by kind — their pictures
            // travel with the edit as references.
            mentionedPanel

            // Add button
            Button(action: {
                addAnnotation(at: 0.5, 0.5)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .medium))
                    Text("Add")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.accentColor.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Mentioned elements (DC-0102)

    /// Every story element the instructions mention, in order of first use.
    private var mentionedElements: [ResolvedMention] {
        let texts = annotations.map(\.text) + [wholeInstruction] + [editingText]
        return MentionParser.mentions(in: texts.joined(separator: "\n"), characters: characters,
                                      locations: locations, props: props, shots: shots)
    }

    @ViewBuilder
    private var mentionedPanel: some View {
        let mentioned = mentionedElements
        if !mentioned.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ReferenceStyle.tint)
                    Text("MENTIONED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("pictures go with the edit")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.7))
                }
                ForEach([ResolvedMention.Kind.character, .location, .prop, .shot], id: \.self) { kind in
                    let items = mentioned.filter { $0.kind == kind }
                    if !items.isEmpty {
                        Text(mentionKindTitle(kind))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.8))
                        ForEach(items) { mention in
                            mentionRow(mention)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    private func mentionKindTitle(_ kind: ResolvedMention.Kind) -> String {
        switch kind {
        case .character: return "Characters"
        case .location: return "Locations"
        case .prop: return "Props"
        case .shot: return "Shots"
        }
    }

    private func mentionRow(_ mention: ResolvedMention) -> some View {
        HStack(spacing: 8) {
            if let path = mention.imagePath, !path.isEmpty, let base = projectDirectory {
                AsyncThumbnail(url: base.appendingPathComponent(path), displaySize: 28) {
                    mention.color.opacity(0.25)
                }
                .frame(width: mention.kind == .character ? 24 : 36, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: mention.kind == .character ? 12 : 4))
            } else {
                Image(systemName: mention.symbol)
                    .font(.system(size: 10))
                    .foregroundColor(mention.color)
                    .frame(width: 24, height: 24)
            }
            Text(mention.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            Spacer()
            Button(action: { removeMention(mention) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove \(mention.name) from the instructions")
            .accessibilityIdentifier("annotation-mention-remove-\(mention.name)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(mention.color.opacity(0.08))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpenMention?(mention) }
        .help(onOpenMention == nil ? mention.name : "Double-click to open \(mention.name)")
    }

    /// Strip every "<trigger>Name" token of this element from the instructions.
    private func removeMention(_ mention: ResolvedMention) {
        let trigger: String
        switch mention.kind {
        case .character: trigger = "@"
        case .location: trigger = "#"
        case .prop: trigger = "$"
        case .shot: trigger = "&"
        }
        let token = trigger + mention.name
        func strip(_ text: String) -> String {
            text.replacingOccurrences(of: token + " ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: token, with: "", options: .caseInsensitive)
        }
        for index in annotations.indices { annotations[index].text = strip(annotations[index].text) }
        wholeInstruction = strip(wholeInstruction)
        editingText = strip(editingText)
    }

    // MARK: - Annotation List Row

    @ViewBuilder
    private func annotationListRow(annotation: KeyframeAnnotation) -> some View {
        let isSelected = selectedAnnotationId == annotation.id

        HStack(spacing: 8) {
            Circle()
                .fill(isSelected ? Color.green : Color.accentColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Text("\(annotation.number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                if annotation.text.isEmpty {
                    Text("No description")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                        .italic()
                } else {
                    Text(annotation.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Text("\(Int(annotation.normalizedX * 100))%, \(Int(annotation.normalizedY * 100))%")
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.5))
            }

            Spacer()

            Button(action: { deleteAnnotation(annotation.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            selectAnnotation(annotation)
        }
    }

    // MARK: - Actions

    private func addAnnotation(at x: Double, _ y: Double) {
        let nextNumber = (annotations.map { $0.number }.max() ?? 0) + 1
        let ann = KeyframeAnnotation(
            normalizedX: x,
            normalizedY: y,
            text: "",
            number: nextNumber
        )
        annotations.append(ann)
        selectedAnnotationId = ann.id
        editingText = ""
    }

    private func setReach(of id: String, to value: Double) {
        guard let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[idx].radius = min(0.5, max(0.08, value))
    }

    private func selectAnnotation(_ annotation: KeyframeAnnotation) {
        selectedAnnotationId = annotation.id
        editingText = annotation.text
    }

    private func confirmEdit() {
        guard let id = selectedAnnotationId,
              let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[idx].text = editingText.trimmingCharacters(in: .whitespaces)
        selectedAnnotationId = nil
        editingText = ""
    }

    private func deleteAnnotation(_ id: String) {
        annotations.removeAll { $0.id == id }
        if selectedAnnotationId == id {
            selectedAnnotationId = nil
            editingText = ""
        }
        // Renumber
        for i in 0..<annotations.count {
            annotations[i].number = i + 1
        }
    }

    private var canApply: Bool {
        if wholePicture { return !wholeInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return !annotations.isEmpty && !annotations.contains(where: { $0.text.isEmpty })
    }

    private func applyEdits() {
        if wholePicture {
            // One instruction for the whole picture: a pin whose reach covers
            // everything (radius 1) — the composer words it as a whole-picture
            // edit and the on-device engine repaints without a mask.
            let instruction = wholeInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
            isPresented = false
            onApplyEdits([KeyframeAnnotation(normalizedX: 0.5, normalizedY: 0.5, text: instruction, number: 1,
                                             radius: KeyframeAnnotation.wholePictureRadius)])
            return
        }
        // Confirm any pending edit
        if let id = selectedAnnotationId,
           let idx = annotations.firstIndex(where: { $0.id == id }),
           !editingText.trimmingCharacters(in: .whitespaces).isEmpty {
            annotations[idx].text = editingText.trimmingCharacters(in: .whitespaces)
        }
        isPresented = false
        onApplyEdits(annotations)
    }
}
