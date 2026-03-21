// DirectorsChairViews/Sources/DirectorsChairViews/Shared/ImageAnnotationEditor.swift
//
// Reusable image annotation editor — extracted from KeyframeAnnotationOverlay

import SwiftUI
import DirectorsChairCore
import AppKit

/// A generic image annotation editor that lets users place numbered pins on an image
/// and describe edit instructions for each pin. Used for AI-assisted image editing
/// across keyframes, shot previews, character angles, and location variations.
public struct ImageAnnotationEditor: View {
    let image: NSImage
    let title: String
    let subtitle: String?
    let initialAnnotations: [KeyframeAnnotation]
    @Binding var isPresented: Bool
    let onApplyEdits: ([KeyframeAnnotation]) -> Void

    @State private var annotations: [KeyframeAnnotation] = []
    @State private var selectedAnnotationId: String? = nil
    @State private var editingText: String = ""

    public init(
        image: NSImage,
        title: String,
        subtitle: String? = nil,
        initialAnnotations: [KeyframeAnnotation] = [],
        isPresented: Binding<Bool>,
        onApplyEdits: @escaping ([KeyframeAnnotation]) -> Void
    ) {
        self.image = image
        self.title = title
        self.subtitle = subtitle
        self.initialAnnotations = initialAnnotations
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
                Button("Done") { isPresented = false }
                    .foregroundColor(.gray)
                Button(action: applyEdits) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Apply Edits")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(annotations.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(annotations.isEmpty || annotations.contains(where: { $0.text.isEmpty }))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "#1E1E1E"))

            Divider().opacity(0.3)

            // Instruction banner
            HStack(spacing: 12) {
                instructionPill(icon: "hand.tap", text: "Click to add")
                instructionPill(icon: "cursorarrow.click", text: "Click pin to edit")
                instructionPill(icon: "trash", text: "Right-click to delete")
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
        .frame(width: 900, height: 600)
        .background(Color(hex: "#252525"))
        .onAppear {
            annotations = initialAnnotations
        }
    }

    // MARK: - Build Edit Prompt

    /// Builds a textual edit prompt from annotations, suitable for sending to an AI image generator.
    public static func buildEditPrompt(from annotations: [KeyframeAnnotation], context: String = "image") -> String {
        guard !annotations.isEmpty else { return "" }

        var prompt = "Edit this \(context) with the following changes:\n"
        for ann in annotations.sorted(by: { $0.number < $1.number }) {
            let region = "(\(Int(ann.normalizedX * 100))%, \(Int(ann.normalizedY * 100))%)"
            prompt += "\(ann.number). At \(region): \(ann.text)\n"
        }
        prompt += "Keep all other areas unchanged."
        return prompt
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

                TextField("Describe the change...", text: $editingText, onCommit: {
                    confirmEdit()
                })
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .frame(width: 150)

                Button(action: confirmEdit) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .disabled(editingText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
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

    private func applyEdits() {
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
