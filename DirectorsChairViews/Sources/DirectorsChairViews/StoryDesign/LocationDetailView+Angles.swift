// DirectorsChairViews/StoryDesign/LocationDetailView+Angles.swift
//
// DC-0125 (owner 2026-09-04): "a way to specify an angle for a location
// that can be used in the shots. Each angle definition section should
// have a preview studio tool like the one of shots preview so that the
// angle can be composed from all the story design elements and other
// shots and scene previews if needed."
//
// An angle is a named vantage on the location — "Wide from the gate",
// "Reverse toward the bar" — with a description and a picture the Studio
// composes. Shots pick an angle; the Studio library lists every angle
// under its location.

import DirectorsChairCore
import SwiftUI

extension LocationDetailView {

    // MARK: - Angles Card

    var anglesCard: some View {
        LocationAttributeCard(title: "ANGLES", icon: "camera.viewfinder") {
            VStack(alignment: .leading, spacing: 12) {
                if location.angles.isEmpty {
                    Text("Name the ways the camera sees this place — a wide from the gate, a reverse toward the bar. Shots pick an angle, and the Studio composes its picture from the location, your cast, props, other shots and scene previews.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach($location.angles) { $angle in
                    angleRow($angle)
                }
                Button {
                    addAngle()
                } label: {
                    Label("Add angle", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .accessibilityIdentifier("location-angle-add")
            }
        }
        .sheet(isPresented: $showingAngleStudio) {
            if let angle = location.angles.first(where: { $0.id == studioAngleId }) {
                angleStudio(angle)
            }
        }
    }

    private func angleRow(_ angle: Binding<LocationAngle>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            angleThumbnail(angle.wrappedValue)
                .frame(width: 128, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08)))

            VStack(alignment: .leading, spacing: 6) {
                TextField("Angle name", text: angle.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityIdentifier("location-angle-name-\(angle.wrappedValue.id)")
                CharacterMentionTextEditor(
                    text: angle.description, characters: project.characters,
                    locations: project.locations, props: project.props, continuityShots: [],
                    placeholder: "What the camera sees from here — composition, lens feel, what is in frame.",
                    font: .system(size: 11), foregroundColor: .primary, minHeight: 40)
                    .padding(6)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(6)
            }

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    openAngleStudio(angle.wrappedValue)
                } label: {
                    Label(angle.wrappedValue.image == nil ? "Compose" : "Studio",
                          systemImage: "paintbrush.pointed")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(projectBasePath == nil)
                .help("Compose this angle's picture in the Studio")
                .requiresTier(.creator, feature: "AI location angles")
                .accessibilityIdentifier("location-angle-studio-\(angle.wrappedValue.id)")
                Button(role: .destructive) {
                    removeAngle(id: angle.wrappedValue.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Remove this angle")
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func angleThumbnail(_ angle: LocationAngle) -> some View {
        if let path = angle.image, !path.isEmpty, let base = projectBasePath {
            AsyncThumbnail(url: base.appendingPathComponent(path), displaySize: 256) {
                anglePlaceholder
            }
        } else {
            anglePlaceholder
        }
    }

    private var anglePlaceholder: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 18))
                .foregroundColor(.gray.opacity(0.5))
        }
    }

    // MARK: - Mutations

    func addAngle() {
        location.angles.append(LocationAngle(name: "Angle \(location.angles.count + 1)"))
    }

    func removeAngle(id: String) {
        location.angles.removeAll { $0.id == id }
        if studioAngleId == id {
            showingAngleStudio = false
            studioAngleId = nil
        }
    }

    func openAngleStudio(_ angle: LocationAngle) {
        guard projectBasePath != nil else { return }
        studioAngleId = angle.id
        showingAngleStudio = true
    }

    // MARK: - Studio

    /// The words the Studio starts from on a blank canvas: the location's
    /// mention (its picture rides along as a reference) and the angle's own
    /// description. With a kept picture as the base the Studio starts with
    /// empty words, exactly like a shot.
    func angleSeedPrompt(_ angle: LocationAngle) -> String {
        let detail = angle.description.trimmingCharacters(in: .whitespacesAndNewlines)
        var words = "Establishing view of #\(location.name) from the angle \"\(angle.name)\"."
        if !detail.isEmpty { words += " " + detail }
        return words
    }

    private func angleStudio(_ angle: LocationAngle) -> some View {
        ShotSketchStudio(
            characters: project.characters, locations: project.locations,
            props: project.props, shots: project.studioShots,
            scenes: project.studioScenes,
            subjectLibraryId: "angle-\(angle.id)",
            title: "\(location.name) — \(angle.name)",
            keepLabel: "angle picture",
            targetSize: .projectPreview,
            projectDirectory: projectBasePath,
            seedPrompt: angleSeedPrompt(angle),
            currentPreviewPath: angle.image,
            documentURL: ShotSketchStudio.documentURL(
                projectDirectory: projectBasePath,
                subject: "location-\(DiscoveredLocationImages.sanitizeName(location.name))-angle-\(angle.id)"),
            onKeep: { data in keepAngleResult(data, angleId: angle.id) },
            onSketchSaved: { _ in })
    }

    /// Every kept picture is its own file (history, and a fresh path the
    /// thumbnails cannot serve stale); the angle points at the newest.
    func keepAngleResult(_ data: Data, angleId: String) {
        guard let base = projectBasePath,
              let index = location.angles.firstIndex(where: { $0.id == angleId }) else { return }
        _ = base.startAccessingSecurityScopedResource()
        defer { base.stopAccessingSecurityScopedResource() }
        let directory = "assets/locations/\(DiscoveredLocationImages.sanitizeName(location.name))/angles/\(angleId)"
        do {
            let path = try UploadedImage.writePNG(
                data, projectBasePath: base, relativeDirectory: directory,
                filename: "preview_\(UploadedImage.historyTimestamp()).png")
            location.angles[index].image = path
        } catch {
            NSLog("Location angle keep failed: \(error)")
        }
    }
}
