// DirectorsChairViews/StoryDesign/LocationDetailView+FloorPlan.swift
//
// DC-0130 (owner 2026-09-05): "a way to design the floor plan also for the
// location." The plan is designed in the Studio as a line drawing — sketch
// the walls and fixtures, label them with notes, the location's photos ride
// along as references — or imported from a picture file. It becomes one of
// the pictures the camera can be placed on (DC-0129).

import AppKit
import DirectorsChairCore
import DirectorsChairServices
import SwiftUI

extension LocationDetailView {

    private var floorPlanPath: String? { location.floorPlanImage ?? location.cinemaFloorPlanImage }

    var floorPlanCard: some View {
        LocationAttributeCard(title: "FLOOR PLAN", icon: "square.split.bottomrightquarter") {
            VStack(alignment: .leading, spacing: 10) {
                if let path = floorPlanPath, let base = projectBasePath {
                    AsyncThumbnail(url: base.appendingPathComponent(path), displaySize: 512) {
                        floorPlanPlaceholder
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08)))
                    .accessibilityIdentifier("location-floor-plan-picture")
                } else {
                    Text("Sketch the walls and fixtures, label them with notes, and the Studio draws a clean top-down plan from this place's photos. The camera for an angle can then be placed on it.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Button {
                        guard projectBasePath != nil else { return }
                        showingFloorPlanStudio = true
                    } label: {
                        Label(floorPlanPath == nil ? "Design in Studio" : "Edit in Studio", systemImage: "paintbrush.pointed")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(projectBasePath == nil)
                    .requiresTier(.creator, feature: "AI floor plans")
                    .accessibilityIdentifier("location-floor-plan-studio")
                    Button {
                        importFloorPlan()
                    } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(projectBasePath == nil)
                    .help("Use a picture of the real floor plan")
                    Spacer()
                    if floorPlanPath != nil {
                        Button(role: .destructive) {
                            location.floorPlanImage = nil
                        } label: {
                            Image(systemName: "trash").font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Remove the floor plan (the file stays in the project)")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFloorPlanStudio) {
            floorPlanStudio
        }
    }

    private var floorPlanPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "square.split.bottomrightquarter")
                .font(.system(size: 18))
                .foregroundColor(.gray.opacity(0.5))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// The Studio in its floor-plan medium: the location is the subject's
    /// mention (its photo attaches), the library carries the rest.
    @ViewBuilder
    private var floorPlanStudio: some View {
        let existing = floorPlanPath.flatMap { path in projectBasePath.flatMap { try? Data(contentsOf: $0.appendingPathComponent(path)) } }
        ShotSketchStudio(
            characters: project.characters, locations: project.locations,
            props: project.props, shots: project.studioShots,
            scenes: project.studioScenes,
            subjectLibraryId: "plan-\(location.id)",
            title: "\(location.name) — floor plan",
            keepLabel: "floor plan",
            targetSize: existing.map { ShotSketchStudio.targetSize(matching: $0) } ?? ImageTargetSize(width: 1024, height: 1024),
            projectDirectory: projectBasePath,
            seedPrompt: LocationAngles.floorPlanSeed(location: location),
            currentPreviewPath: floorPlanPath,
            documentURL: ShotSketchStudio.documentURL(
                projectDirectory: projectBasePath,
                subject: "location-\(DiscoveredLocationImages.sanitizeName(location.name))-floorplan"),
            onKeep: { data in keepFloorPlan(data) },
            onSketchSaved: { _ in },
            medium: .floorPlan)
    }

    /// Every kept plan is its own file; the location points at the newest.
    func keepFloorPlan(_ data: Data) {
        guard let base = projectBasePath else { return }
        _ = base.startAccessingSecurityScopedResource()
        defer { base.stopAccessingSecurityScopedResource() }
        let directory = "assets/locations/\(DiscoveredLocationImages.sanitizeName(location.name))"
        do {
            let path = try UploadedImage.writePNG(
                data, projectBasePath: base, relativeDirectory: directory,
                filename: "floor_plan_\(UploadedImage.historyTimestamp()).png")
            location.floorPlanImage = path
        } catch {
            NSLog("Floor plan keep failed: \(error)")
        }
    }

    /// A picture of the real plan, copied into the project as PNG.
    func importFloorPlan() {
        guard let picked = UploadedImage.pickData(message: "Choose a picture of the floor plan"),
              let png = UploadedImage.normalizedPNG(from: picked) else { return }
        keepFloorPlan(png)
    }
}
