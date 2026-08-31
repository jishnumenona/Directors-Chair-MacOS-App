// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/StoryDesignView.swift
//
// Main Story Design View - Character Design, Location Design, and Story World Management

import SwiftUI
import DirectorsChairCore
import AppKit
import UniformTypeIdentifiers

// MARK: - Top-Level Mode

/// DC-0092: what Story Design is showing — handed out on every change so
/// the app can bring the user back here after they leave.
public struct StoryDesignSelection: Equatable, Sendable {
    public var mode: String?
    public var characterId: String?
    public var locationId: String?
    public var tab: String?
    public var propId: String?

    public init(mode: String? = nil, characterId: String? = nil, locationId: String? = nil, tab: String? = nil,
                propId: String? = nil) {
        self.mode = mode
        self.characterId = characterId
        self.locationId = locationId
        self.tab = tab
        self.propId = propId
    }
}

public enum StoryDesignMode: String, CaseIterable {
    // Lighting design was removed here — it belongs to the Theater edition,
    // not the cinema version of DirectorsChair.
    case characters
    case locations
    case costumes
    case props

    var displayName: String {
        switch self {
        case .characters: return "Characters"
        case .locations: return "Locations"
        case .costumes: return "Costumes"
        case .props: return "Props"
        }
    }

    var icon: String {
        switch self {
        case .characters: return "person.fill"
        case .locations: return "map.fill"
        case .costumes: return "tshirt.fill"
        case .props: return "cube.box.fill"
        }
    }
}

/// Main Story Design View - Character design, location design, and story world management
///
/// Layout:
/// - Top: Mode picker (Characters / Locations)
/// - Characters mode:
///   - Left (250px): Character list with search and management
///   - Center: Design area with tabs (Physical, Traits, Biography, Relationships, Scenes)
/// - Locations mode:
///   - Left (250px): Location list with search and management
///   - Center: Location detail editor
public struct StoryDesignView: View {
    @Binding var project: Project
    @State var selectedMode: StoryDesignMode = .characters
    @State var selectedCharacter: Character?
    @State var selectedLocation: Location?
    @State var selectedTab: DesignTab = .physical
    @State var showGenerateAllConfirmation = false

    // Buffered character editing — local copy avoids full view hierarchy re-render on every keystroke
    @State var editingCharacter: Character?
    @State var syncTask: Task<Void, Never>?

    // Character rename popover (WS2.5b UI)
    @State var showingRenamePopover = false
    @State var renameDraft = ""

    let projectBasePath: URL?

    // External selection (set by coordinator via Cmd+Click navigation)
    var initialCharacterId: String?
    var initialLocationId: String?
    var preferredMode: String?
    /// DC-0092: where the user was last time (mode, tab); ids come in as
    /// initialCharacterId / initialLocationId.
    var remembered: StoryDesignSelection?
    var onSelectionChanged: ((StoryDesignSelection) -> Void)?
    /// Prop page "Where it's used" jumps (DC-0096).
    var onOpenScene: ((DCScene) -> Void)?
    var onOpenShot: ((Shot, DCScene) -> Void)?
    var initialLightCueId: String?
    var initialSFXCueId: String?
    var initialSupportCueId: String?
    var markers: [TimelineMarker] = []

    // AI operation progress (survives navigation, passed from parent)
    var traitAnalysisProgress: [String: Int] = [:]
    var biographyProgress: [String: Int] = [:]

    // Callbacks for AI operations
    var onGenerateImage: ((Character, String, String, @escaping @MainActor (Double) -> Void) -> Void)?
    var onAnalyzeTraits: ((Character) -> Void)?
    var onGenerateBiography: ((Character) -> Void)?
    var onGenerateLocationImage: ((Location, String, String, @escaping @MainActor (Double) -> Void) -> Void)?
    var onUploadReferenceImage: ((Character, Data, @escaping @MainActor (Double) -> Void) -> Void)?

    public init(
        project: Binding<Project>,
        projectBasePath: URL? = nil,
        initialCharacterId: String? = nil,
        initialLocationId: String? = nil,
        preferredMode: String? = nil,
        initialLightCueId: String? = nil,
        initialSFXCueId: String? = nil,
        initialSupportCueId: String? = nil,
        markers: [TimelineMarker] = [],
        traitAnalysisProgress: [String: Int] = [:],
        biographyProgress: [String: Int] = [:],
        onGenerateImage: ((Character, String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil,
        onAnalyzeTraits: ((Character) -> Void)? = nil,
        onGenerateBiography: ((Character) -> Void)? = nil,
        onGenerateLocationImage: ((Location, String, String, @escaping @MainActor (Double) -> Void) -> Void)? = nil,
        onUploadReferenceImage: ((Character, Data, @escaping @MainActor (Double) -> Void) -> Void)? = nil,
        remembered: StoryDesignSelection? = nil,
        onSelectionChanged: ((StoryDesignSelection) -> Void)? = nil,
        onOpenScene: ((DCScene) -> Void)? = nil,
        onOpenShot: ((Shot, DCScene) -> Void)? = nil
    ) {
        self._project = project
        self.remembered = remembered
        self.onSelectionChanged = onSelectionChanged
        self.onOpenScene = onOpenScene
        self.onOpenShot = onOpenShot
        self.projectBasePath = projectBasePath
        self.initialCharacterId = initialCharacterId
        self.initialLocationId = initialLocationId
        self.preferredMode = preferredMode
        self.initialLightCueId = initialLightCueId
        self.initialSFXCueId = initialSFXCueId
        self.initialSupportCueId = initialSupportCueId
        self.markers = markers
        self.traitAnalysisProgress = traitAnalysisProgress
        self.biographyProgress = biographyProgress
        self.onGenerateImage = onGenerateImage
        self.onAnalyzeTraits = onAnalyzeTraits
        self.onGenerateBiography = onGenerateBiography
        self.onGenerateLocationImage = onGenerateLocationImage
        self.onUploadReferenceImage = onUploadReferenceImage
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Mode picker bar
            modePickerBar

            Divider()

            // Content based on mode
            switch selectedMode {
            case .characters:
                charactersModeContent
            case .locations:
                locationsModeContent
            case .costumes:
                CostumeDepartmentView(
                    project: $project,
                    projectBasePath: projectBasePath,
                    onGenerateImage: onGenerateImage
                )
            case .props:
                PropShopView(
                    project: $project,
                    projectBasePath: projectBasePath,
                    initialPropId: remembered?.propId,
                    onOpenScene: onOpenScene,
                    onOpenShot: onOpenShot,
                    onPropSelected: { id in
                        var selection = StoryDesignSelection(mode: selectedMode.rawValue, characterId: selectedCharacter?.id,
                                                             locationId: selectedLocation?.id, tab: selectedTab.rawValue)
                        selection.propId = id
                        onSelectionChanged?(selection)
                    }
                )
            }
        }
        .alert("Generate All Attributes", isPresented: $showGenerateAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Generate") {
                if let character = selectedCharacter {
                    onAnalyzeTraits?(character)
                    onGenerateBiography?(character)
                }
            }
        } message: {
            Text("This will analyze the script to generate personality traits, physical attributes, and biography information. This may take a few minutes.")
        }
        .onAppear {
            applyInitialSelection()
            loadEditingCharacter()
        }
        // DC-0092: report every selection change so it survives leaving.
        .onChange(of: selectedMode) { _, _ in reportSelection() }
        .onChange(of: selectedTab) { _, _ in reportSelection() }
        .onChange(of: selectedCharacter?.id) { _, _ in reportSelection() }
        .onChange(of: selectedLocation?.id) { _, _ in reportSelection() }
        .onDisappear {
            flushEditingCharacter()
        }
        .onChange(of: selectedCharacter?.id) { _ in
            flushEditingCharacter()
            loadEditingCharacter()
        }
        .onChange(of: projectCharacterSnapshot) { newChar in
            // Detect external updates (AI analysis, trait detection, etc.)
            // Only refresh if no pending local edits and values actually differ
            guard syncTask == nil, let newChar = newChar, newChar != editingCharacter else { return }
            editingCharacter = newChar
        }
        .onChange(of: initialCharacterId) { newId in
            if let id = newId, let char = project.characters.first(where: { $0.id == id }) {
                selectedMode = .characters
                selectedCharacter = char
            }
        }
        .onChange(of: initialLocationId) { newId in
            if let id = newId, let loc = project.locations.first(where: { $0.id == id }) {
                selectedMode = .locations
                selectedLocation = loc
            }
        }
        .onChange(of: preferredMode) { newMode in
            if newMode == "locations" {
                selectedMode = .locations
            } else if newMode == "characters" {
                selectedMode = .characters
            }
        }
    }
}
