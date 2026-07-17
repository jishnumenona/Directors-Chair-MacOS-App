//
// PropShopView.swift
//
// The Props mode of Story Design — the art department's prop shop, built on
// the existing production-grade Prop model. Props are designed/sourced here
// once, then placed into scenes (which is what puts them at a location):
// assigning a prop appends its name to scene.props, the same field the AI
// prompts, Shot Context, and reference collages already read.
//
// Tools a props master expects: a pipeline board (Concept → Sourcing →
// Building → Ready → On Set), AI concept-image generation, internet
// reference images by URL, and paste-from-clipboard references.
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairServices

struct PropShopView: View {
    @Binding var project: Project
    let projectBasePath: URL?

    @State private var selectedPropId: String?
    @State private var statusFilter: String = "All"
    @State private var isGenerating = false
    @State private var referenceURLText = ""
    @State private var feedback: String?
    @State private var imageRefresh = UUID()
    // New-prop creation sheet
    @State private var showingNewPropSheet = false
    @State private var newPropName = ""
    @State private var newPropCategory = "Hand"
    @State private var newPropDescription = ""

    static let pipelineStages = ["Concept", "Sourcing", "Building", "Ready", "On Set"]
    static let categories = ["Hero", "Hand", "Set Dressing", "Furniture", "Weapon", "Document", "Food", "Vehicle", "Other"]

    /// Pipeline counts across the shop. Pure — tested.
    static func pipelineCounts(for props: [Prop]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for prop in props { counts[prop.status ?? "Concept", default: 0] += 1 }
        return counts
    }

    /// Scenes that use a prop (name match against scene.props — the same
    /// linkage the prompts use). Pure — tested.
    static func scenesUsing(_ propName: String, in scenes: [DCScene]) -> [DCScene] {
        scenes.filter { scene in
            scene.props.contains { $0.caseInsensitiveCompare(propName) == .orderedSame }
        }
    }

    /// Prop names mentioned in scenes (script breakdown / Detect from Script)
    /// that don't exist in the shop yet — the import queue. Pure — tested.
    static func unregisteredSceneProps(props: [Prop], scenes: [DCScene]) -> [String] {
        let known = Set(props.map { $0.name.lowercased() })
        var seen = Set<String>()
        var result: [String] = []
        for scene in scenes {
            for name in scene.props {
                let key = name.lowercased()
                if !known.contains(key), !seen.contains(key), !name.isEmpty {
                    seen.insert(key)
                    result.append(name)
                }
            }
        }
        return result
    }

    private var allScenes: [DCScene] { project.sequences.flatMap(\.scenes) }

    var body: some View {
        HSplitView {
            shelf
                .frame(minWidth: 250, maxWidth: 310)
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { if selectedPropId == nil { selectedPropId = project.props.first?.id } }
        .sheet(isPresented: $showingNewPropSheet) { newPropSheet }
    }

    // MARK: - Shelf

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("PROP SHOP")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
                let counts = Self.pipelineCounts(for: project.props)
                HStack(spacing: 6) {
                    ForEach(Self.pipelineStages, id: \.self) { stage in
                        VStack(spacing: 1) {
                            Text("\(counts[stage] ?? 0)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(stageColor(stage))
                            Text(stage)
                                .font(.system(size: 7))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                HStack {
                    Menu {
                        Button("All") { statusFilter = "All" }
                        Divider()
                        ForEach(Self.pipelineStages, id: \.self) { stage in
                            Button(stage) { statusFilter = stage }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 10))
                            Text(statusFilter == "All" ? "All stages" : statusFilter)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.gray)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    Spacer()
                    Button(action: { showingNewPropSheet = true }) {
                        Label("New Prop", systemImage: "plus.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .help("Create a prop (⇧⌘N)")
                }
            }
            .padding(12)

            Divider()

            // Import queue — props the script breakdown already named
            let detected = Self.unregisteredSceneProps(props: project.props, scenes: allScenes)
            if !detected.isEmpty {
                Button(action: importDetectedProps) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 10))
                        Text("Import \(detected.count) prop\(detected.count == 1 ? "" : "s") from your scenes")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(2)
                        Spacer()
                    }
                    .foregroundColor(.orange)
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                }
                .buttonStyle(.plain)
                .help("Scenes mention: \(detected.joined(separator: ", "))")
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Self.categories + ["Uncategorized"], id: \.self) { category in
                        let items = project.props.filter { prop in
                            let propCategory = Self.categories.contains(prop.category) ? prop.category : "Uncategorized"
                            return propCategory == category
                                && (statusFilter == "All" || (prop.status ?? "Concept") == statusFilter)
                        }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(.gray.opacity(0.7))
                                ForEach(items) { prop in shelfRow(prop) }
                            }
                        }
                    }
                    if project.props.isEmpty {
                        Text("No props yet. Create one, or use “Detect from Script” in a shot's context to break down the scene — detected props can be promoted here.")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(10)
                    }
                }
                .padding(10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func shelfRow(_ prop: Prop) -> some View {
        let sceneCount = Self.scenesUsing(prop.name, in: allScenes).count
        Button(action: { selectedPropId = prop.id }) {
            HStack(spacing: 8) {
                propThumbnail(prop, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(prop.name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(prop.status ?? "Concept")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(stageColor(prop.status ?? "Concept"))
                        if sceneCount > 0 {
                            Text("· \(sceneCount) scene\(sceneCount == 1 ? "" : "s")")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
            }
            .padding(6)
            .background(selectedPropId == prop.id ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let index = project.props.firstIndex(where: { $0.id == selectedPropId }) {
            propEditor($project.props[index])
                .id(project.props[index].id)
        } else {
            // Empty state = the creation call-to-action, not a dead pane.
            let detected = Self.unregisteredSceneProps(props: project.props, scenes: allScenes)
            VStack(spacing: 16) {
                Image(systemName: "cube.box")
                    .font(.system(size: 44))
                    .foregroundColor(.orange.opacity(0.5))
                Text(project.props.isEmpty ? "Stock the prop shop" : "Select a prop from the shelf")
                    .font(.system(size: 16, weight: .semibold))
                Text("Design a prop with AI concept images, pull references from the web or your clipboard, and place it into scenes.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                HStack(spacing: 12) {
                    Button(action: { showingNewPropSheet = true }) {
                        Label("Create a Prop", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)

                    if !detected.isEmpty {
                        Button(action: importDetectedProps) {
                            Label("Import \(detected.count) from scenes", systemImage: "square.and.arrow.down.on.square")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Scenes mention: \(detected.joined(separator: ", "))")
                    }
                }
                if detected.isEmpty && project.props.isEmpty {
                    Text("Tip: “Detect from Script” in a shot's context breaks down scene props automatically — they'll appear here for import.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.6))
                        .frame(maxWidth: 380)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - New-prop sheet

    private var newPropSheet: some View {
        let canCreate = !newPropName.trimmingCharacters(in: .whitespaces).isEmpty
        let detected = Self.unregisteredSceneProps(props: project.props, scenes: allScenes)

        return VStack(alignment: .leading, spacing: 16) {
            // Header — same pattern as the app's other sheets
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(.orange)
                Text("New Prop")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Cancel") { showingNewPropSheet = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray)
                TextField("e.g. Brass pocket watch", text: $newPropName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
                    .onSubmit(createPropFromSheet)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("CATEGORY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray)
                VideoContextFlowLayout(spacing: 6) {
                    ForEach(Self.categories, id: \.self) { category in
                        Button(action: { newPropCategory = category }) {
                            Text(category)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(newPropCategory == category ? Color.accentColor : Color(hex: "#3A3A3A"))
                                .foregroundColor(newPropCategory == category ? .white : .gray)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("VISUAL DESCRIPTION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray)
                TextField("What it looks like — drives the AI concept image", text: $newPropDescription)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(10)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
            }

            if !detected.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DETECTED IN YOUR SCENES — CLICK TO USE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.gray)
                    VideoContextFlowLayout(spacing: 6) {
                        ForEach(detected, id: \.self) { name in
                            Button(action: { newPropName = name }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 8))
                                    Text(name)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(newPropName == name ? Color.orange.opacity(0.25) : Color.orange.opacity(0.08))
                                .foregroundColor(.orange)
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(newPropName == name ? 0.5 : 0.2), lineWidth: 1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            HStack(spacing: 10) {
                if !detected.isEmpty {
                    Button(action: {
                        importDetectedProps()
                        showingNewPropSheet = false
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .font(.system(size: 10))
                            Text("Import all \(detected.count)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#3A3A3A"))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(action: createPropFromSheet) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Create Prop")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(canCreate ? Color.accentColor : Color(hex: "#3A3A3A"))
                    .foregroundColor(canCreate ? .white : .gray)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(hex: "#252525"))
    }

    private func createPropFromSheet() {
        let name = newPropName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var prop = Prop(name: name, description: newPropDescription, category: newPropCategory)
        prop.status = "Concept"
        // If the name came from the script breakdown, it's already placed in
        // those scenes by name — record them.
        let usedIn = Self.scenesUsing(name, in: allScenes).map(\.name)
        if !usedIn.isEmpty { prop.sceneNames = usedIn }
        project.props.append(prop)
        selectedPropId = prop.id
        newPropName = ""
        newPropDescription = ""
        showingNewPropSheet = false
    }

    /// Promote every scene-breakdown prop that isn't in the shop yet.
    private func importDetectedProps() {
        let detected = Self.unregisteredSceneProps(props: project.props, scenes: allScenes)
        for name in detected {
            var prop = Prop(name: name)
            prop.status = "Concept"
            prop.sceneNames = Self.scenesUsing(name, in: allScenes).map(\.name)
            project.props.append(prop)
        }
        if selectedPropId == nil { selectedPropId = project.props.first?.id }
    }

    @ViewBuilder
    private func propEditor(_ prop: Binding<Prop>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Identity
                TextField("Prop name", text: prop.name)
                    .font(.system(size: 18, weight: .semibold))
                    .textFieldStyle(.plain)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CATEGORY").font(.system(size: 8, weight: .bold)).tracking(1.0).foregroundColor(.gray)
                        VideoContextFlowLayout(spacing: 4) {
                            ForEach(Self.categories, id: \.self) { category in
                                Button(action: { prop.wrappedValue.category = category }) {
                                    Text(category)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(prop.wrappedValue.category == category
                                                    ? Color.accentColor : Color(hex: "#3A3A3A"))
                                        .foregroundColor(prop.wrappedValue.category == category ? .white : .gray)
                                        .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PIPELINE").font(.system(size: 8, weight: .bold)).tracking(1.0).foregroundColor(.gray)
                        HStack(spacing: 4) {
                            ForEach(Self.pipelineStages, id: \.self) { stage in
                                Button(action: { prop.wrappedValue.status = stage }) {
                                    Text(stage)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background((prop.wrappedValue.status ?? "Concept") == stage
                                                    ? stageColor(stage).opacity(0.25) : Color(hex: "#1A1A1A"))
                                        .foregroundColor((prop.wrappedValue.status ?? "Concept") == stage
                                                         ? stageColor(stage) : .gray)
                                        .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Concept image + AI generation
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 6) {
                        propThumbnail(prop.wrappedValue, size: 180)
                            .id(imageRefresh)
                        if isGenerating {
                            ProgressView().controlSize(.small)
                        } else {
                            Button(action: { generateConceptImage(prop) }) {
                                Label("Generate with AI", systemImage: "wand.and.stars")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .help("Generate a concept image from the name, category, description, and reference images")
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION (drives the AI concept)").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                        TextEditor(text: prop.description)
                            .font(.system(size: 11))
                            .frame(height: 70)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(Color(hex: "#1A1A1A"))
                            .cornerRadius(6)
                        Text("MAKER SPECS / SOURCING NOTES").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                        TextEditor(text: prop.detailedSpecs)
                            .font(.system(size: 11))
                            .frame(height: 50)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(Color(hex: "#1A1A1A"))
                            .cornerRadius(6)
                    }
                }

                // Reference images — internet URL + clipboard
                VStack(alignment: .leading, spacing: 8) {
                    Text("REFERENCE IMAGES").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                    HStack(spacing: 8) {
                        TextField("Paste an image URL from the internet…", text: $referenceURLText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(hex: "#1A1A1A"))
                            .cornerRadius(6)
                            .font(.system(size: 11))
                            .onSubmit { addReferenceFromURL(prop) }
                        Button(action: { addReferenceFromURL(prop) }) {
                            Label("Add from URL", systemImage: "globe")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .disabled(referenceURLText.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button(action: { pasteReferenceFromClipboard(prop) }) {
                            Label("Paste Image", systemImage: "doc.on.clipboard")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .help("Add a reference image from the clipboard (⌘C an image anywhere, then click)")
                    }
                    if let feedback {
                        Text(feedback)
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(prop.wrappedValue.referencePhotos, id: \.self) { path in
                                referenceThumb(path: path, prop: prop)
                            }
                            if prop.wrappedValue.referencePhotos.isEmpty {
                                Text("No references yet — pull research from the internet or your clipboard.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }
                    }
                }

                // Scene placement (what puts the prop at a location)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("USED IN SCENES").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                        Spacer()
                        Menu {
                            ForEach(allScenes) { scene in
                                let used = Self.scenesUsing(prop.wrappedValue.name, in: [scene]).count > 0
                                Button(action: { toggleScene(scene, prop: prop) }) {
                                    if used {
                                        Label(scene.name, systemImage: "checkmark")
                                    } else {
                                        Text(scene.name)
                                    }
                                }
                            }
                        } label: {
                            Label("Place in scene…", systemImage: "plus.circle")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    let usedScenes = Self.scenesUsing(prop.wrappedValue.name, in: allScenes)
                    if usedScenes.isEmpty {
                        Text("Not placed anywhere yet — placing a prop in a scene puts it at that scene's location and into every AI prompt for its shots.")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.6))
                    } else {
                        VideoContextFlowLayout(spacing: 6) {
                            ForEach(usedScenes) { scene in
                                HStack(spacing: 4) {
                                    Image(systemName: "film").font(.system(size: 8))
                                    Text(scene.name).font(.system(size: 9, weight: .medium)).lineLimit(1)
                                    if let location = scene.location, !location.isEmpty {
                                        Text("@ \(location)")
                                            .font(.system(size: 8))
                                            .foregroundColor(.green.opacity(0.9))
                                    }
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.08))
                                .overlay(Capsule().stroke(Color.orange.opacity(0.2), lineWidth: 1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Notes + delete
                VStack(alignment: .leading, spacing: 6) {
                    Text("HANDLING / CONTINUITY NOTES").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                    TextEditor(text: prop.notes)
                        .font(.system(size: 11))
                        .frame(height: 46)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(hex: "#1A1A1A"))
                        .cornerRadius(6)
                }
                Button(role: .destructive, action: { deleteProp(prop.wrappedValue) }) {
                    Label("Delete prop", systemImage: "trash").font(.system(size: 10))
                }
            }
            .padding(18)
        }
    }

    // MARK: - Actions

    private func deleteProp(_ prop: Prop) {
        project.props.removeAll { $0.id == prop.id }
        selectedPropId = project.props.first?.id
    }

    private func toggleScene(_ scene: DCScene, prop: Binding<Prop>) {
        var updated = scene
        let name = prop.wrappedValue.name
        if let existing = updated.props.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            updated.props.remove(at: existing)
            prop.wrappedValue.sceneNames?.removeAll { $0 == scene.name }
        } else {
            updated.props.append(name)
            prop.wrappedValue.sceneNames = (prop.wrappedValue.sceneNames ?? []) + [scene.name]
        }
        for sequenceIndex in project.sequences.indices {
            if let sceneIndex = project.sequences[sequenceIndex].scenes.firstIndex(where: { $0.id == updated.id }) {
                project.sequences[sequenceIndex].scenes[sceneIndex] = updated
                return
            }
        }
    }

    private func propAssetDir(_ prop: Prop) -> URL? {
        guard let basePath = projectBasePath else { return nil }
        let sanitized = CharacterReferenceHelper.sanitizeLocationName(prop.name.isEmpty ? prop.id : prop.name)
        return basePath.appendingPathComponent("assets/props/\(sanitized)")
    }

    private func saveImageData(_ data: Data, prop: Binding<Prop>, prefix: String, asPrimary: Bool) {
        guard let basePath = projectBasePath, let dir = propAssetDir(prop.wrappedValue) else {
            feedback = "Open the project from disk first."
            return
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let filename = "\(prefix)_\(Int(Date().timeIntervalSince1970)).png"
            try data.write(to: dir.appendingPathComponent(filename))
            let relative = dir.appendingPathComponent(filename).path
                .replacingOccurrences(of: basePath.path + "/", with: "")
            if asPrimary {
                prop.wrappedValue.thumbnail = relative
            } else {
                prop.wrappedValue.referencePhotos.append(relative)
            }
            imageRefresh = UUID()
            feedback = nil
        } catch {
            feedback = "Could not save image: \(error.localizedDescription)"
        }
    }

    /// AI concept generation: prompt from the prop's identity + references.
    private func generateConceptImage(_ prop: Binding<Prop>) {
        isGenerating = true
        feedback = nil
        let snapshot = prop.wrappedValue
        var parts = ["Professional film-production prop concept image: \(snapshot.name)."]
        if !snapshot.description.isEmpty { parts.append(snapshot.description) }
        if !snapshot.category.isEmpty { parts.append("Prop category: \(snapshot.category).") }
        if !snapshot.detailedSpecs.isEmpty { parts.append("Specifications: \(snapshot.detailedSpecs)") }
        parts.append("Studio product photography on a neutral dark background, high detail, realistic materials, no people, no text.")
        let prompt = parts.joined(separator: " ")

        // Reference photos guide the generation when present.
        let refs: [ReferenceImage] = snapshot.referencePhotos.compactMap { path in
            guard let basePath = projectBasePath,
                  let data = try? Data(contentsOf: basePath.appendingPathComponent(path)) else { return nil }
            return ReferenceImage(base64: data.base64EncodedString(), label: "reference:\(snapshot.name)")
        }

        Task {
            if let token = await AIServiceClient.shared.tokenProvider?() {
                await AIServiceClient.shared.setAuthToken(token)
            }
            do {
                let request = ImageGenerationRequest(
                    prompt: prompt,
                    provider: .googleImagen,
                    aspectRatio: "1:1",
                    referenceImages: refs.isEmpty ? nil : refs
                )
                let response = try await AIServiceClient.shared.generateImage(request)
                await MainActor.run {
                    isGenerating = false
                    if let imageData = response.images.first {
                        saveImageData(imageData, prop: prop, prefix: "concept", asPrimary: true)
                    } else {
                        feedback = "The model returned no image — try enriching the description."
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    feedback = "Generation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Internet reference: download the image at a URL.
    private func addReferenceFromURL(_ prop: Binding<Prop>) {
        let text = referenceURLText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: text), url.scheme?.hasPrefix("http") == true else {
            feedback = "That doesn't look like an image URL."
            return
        }
        feedback = "Downloading…"
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard NSImage(data: data) != nil else {
                    await MainActor.run { feedback = "The URL didn't return a readable image." }
                    return
                }
                await MainActor.run {
                    saveImageData(data, prop: prop, prefix: "ref_web", asPrimary: false)
                    referenceURLText = ""
                }
            } catch {
                await MainActor.run { feedback = "Download failed: \(error.localizedDescription)" }
            }
        }
    }

    /// Clipboard reference: grab an image from the pasteboard.
    private func pasteReferenceFromClipboard(_ prop: Binding<Prop>) {
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            saveImageData(png, prop: prop, prefix: "ref_clip", asPrimary: false)
        } else {
            feedback = "No image on the clipboard — copy an image first (⌘C), then click Paste Image."
        }
    }

    private func removeReference(_ path: String, prop: Binding<Prop>) {
        prop.wrappedValue.referencePhotos.removeAll { $0 == path }
    }

    // MARK: - Small pieces

    @ViewBuilder
    private func referenceThumb(path: String, prop: Binding<Prop>) -> some View {
        ZStack(alignment: .topTrailing) {
            if let basePath = projectBasePath,
               let image = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 74, height: 74)
            }
            Button(action: { removeReference(path, prop: prop) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .padding(3)
        }
    }

    @ViewBuilder
    private func propThumbnail(_ prop: Prop, size: CGFloat) -> some View {
        if let basePath = projectBasePath, let path = prop.thumbnail,
           let image = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size > 100 ? 10 : 5))
        } else {
            RoundedRectangle(cornerRadius: size > 100 ? 10 : 5)
                .fill(Color.orange.opacity(0.1))
                .frame(width: size, height: size)
                .overlay(Image(systemName: "cube.box")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(.orange.opacity(0.5)))
        }
    }

    private func stageColor(_ stage: String) -> Color {
        switch stage {
        case "Concept": return .purple
        case "Sourcing": return .orange
        case "Building": return .yellow
        case "Ready": return .green
        case "On Set": return .blue
        default: return .gray
        }
    }
}
