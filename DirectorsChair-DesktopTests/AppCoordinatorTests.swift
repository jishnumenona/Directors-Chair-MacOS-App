// DirectorsChair-DesktopTests/AppCoordinatorTests.swift
//
// Tests for AppCoordinator navigation state, history, and view switching.

import XCTest
import Combine
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices
import DirectorsChairViews

@MainActor
final class AppCoordinatorTests: XCTestCase {

    var coordinator: AppCoordinator!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        coordinator = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialNavigationState() {
        // Coordinator should start on projects view
        XCTAssertEqual(coordinator.selectedView, .projects)
    }

    func testInitialUIState() {
        XCTAssertTrue(coordinator.showingNavigator, "Navigator should be visible by default")
        XCTAssertTrue(coordinator.showingTimeline, "Timeline should be visible by default")
        XCTAssertTrue(coordinator.showingRightPanel, "Right panel should be visible by default")
        XCTAssertFalse(coordinator.showingComments, "Comments should be hidden by default")
        XCTAssertTrue(coordinator.showingUsageWidget, "Usage widget should be visible by default")
        XCTAssertFalse(coordinator.showingAIChat, "AI Chat should be hidden by default")
    }

    func testInitialSelections() {
        XCTAssertNil(coordinator.selectedSequence)
        XCTAssertNil(coordinator.selectedScene)
        XCTAssertNil(coordinator.selectedShot)
        XCTAssertNil(coordinator.selectedCharacter)
        XCTAssertNil(coordinator.selectedLocation)
    }

    func testInitialHistoryState() {
        XCTAssertFalse(coordinator.canNavigateBack, "Should not be able to navigate back initially")
        XCTAssertFalse(coordinator.canNavigateForward, "Should not be able to navigate forward initially")
    }

    // MARK: - Navigate To

    func testNavigateToProject() {
        coordinator.navigateTo(.script)

        XCTAssertEqual(coordinator.selectedView, .script)
    }

    func testNavigateToMultipleViews() {
        coordinator.navigateTo(.script)
        XCTAssertEqual(coordinator.selectedView, .script)

        // Need to wait for debounce unlock before next navigation
        let expectation = XCTestExpectation(description: "Navigation debounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.coordinator.navigateTo(.bubble)
            XCTAssertEqual(self.coordinator.selectedView, .bubble)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testNavigateToSameViewIsNoOp() {
        coordinator.navigateTo(.projects)

        // Navigating to the same view should be a no-op
        // (selectedView should stay .projects and no back stack entry should be added)
        XCTAssertEqual(coordinator.selectedView, .projects)
        XCTAssertFalse(coordinator.canNavigateBack)
    }

    // MARK: - Navigate Back

    func testNavigateBack() {
        // Navigate away from initial view
        coordinator.navigateTo(.script)
        XCTAssertEqual(coordinator.selectedView, .script)
        XCTAssertTrue(coordinator.canNavigateBack)

        coordinator.navigateBack()
        XCTAssertEqual(coordinator.selectedView, .projects)
    }

    func testNavigateBackIsNoOpWhenEmpty() {
        // Should not crash or change state when back stack is empty
        XCTAssertFalse(coordinator.canNavigateBack)
        coordinator.navigateBack()
        XCTAssertEqual(coordinator.selectedView, .projects, "Should stay on initial view")
    }

    func testNavigateBackCreatesForwardEntry() {
        coordinator.navigateTo(.script)
        coordinator.navigateBack()

        XCTAssertTrue(coordinator.canNavigateForward,
                      "After navigating back, should be able to go forward")
    }

    // MARK: - Navigate Forward

    func testNavigateForward() {
        coordinator.navigateTo(.script)
        coordinator.navigateBack()

        XCTAssertEqual(coordinator.selectedView, .projects)
        XCTAssertTrue(coordinator.canNavigateForward)

        coordinator.navigateForward()
        XCTAssertEqual(coordinator.selectedView, .script)
    }

    func testNavigateForwardIsNoOpWhenEmpty() {
        XCTAssertFalse(coordinator.canNavigateForward)
        coordinator.navigateForward()
        XCTAssertEqual(coordinator.selectedView, .projects)
    }

    // MARK: - View Switching

    func testViewSwitching() {
        // Rapid back-to-back navigation must land EVERY click. The old
        // navigateTo silently dropped requests behind a 150ms lock + 250ms
        // debounce (this test documented that defect via XCTExpectFailure);
        // the navigator-responsiveness fix removed the click-dropping, so
        // this now asserts the correct behavior directly.
        let views: [AppView] = [.script, .scenes, .production, .storyDesign, .settings]
        for view in views {
            coordinator.navigateTo(view)
            XCTAssertEqual(coordinator.selectedView, view,
                           "Should reach \(view.rawValue) view after navigating to it")
        }
    }

    // MARK: - AppView Properties

    func testAppViewRequiresProject() {
        // Views that should NOT require a project
        XCTAssertFalse(AppView.settings.requiresProject)
        XCTAssertFalse(AppView.overview.requiresProject)
        XCTAssertFalse(AppView.projects.requiresProject)

        // Views that SHOULD require a project
        XCTAssertTrue(AppView.script.requiresProject)
        XCTAssertTrue(AppView.bubble.requiresProject)
        XCTAssertTrue(AppView.scenes.requiresProject)
        XCTAssertTrue(AppView.shotList.requiresProject)
        XCTAssertTrue(AppView.production.requiresProject)
        XCTAssertTrue(AppView.storyDesign.requiresProject)
        XCTAssertTrue(AppView.curation.requiresProject)
        XCTAssertTrue(AppView.playback.requiresProject)
        XCTAssertTrue(AppView.assets.requiresProject)
        XCTAssertTrue(AppView.visionBoard.requiresProject)
    }

    func testAppViewAllCases() {
        let allViews = AppView.allCases
        XCTAssertEqual(allViews.count, 13)
    }

    func testAppViewRequiredTier() {
        // Product-Versions §3: the production suite and the capture/curation
        // toolkit are Creator; every other app-nav destination is Free.
        XCTAssertEqual(AppView.production.requiredTier, .creator)
        XCTAssertEqual(AppView.curation.requiredTier, .creator)

        for view in AppView.allCases where view != .production && view != .curation {
            XCTAssertEqual(view.requiredTier, .free,
                           "\(view.rawValue) is part of the free creative core")
        }

        // Nothing at app-nav level is Studio — org surfaces live inside the
        // sync UI, not the navigator.
        XCTAssertFalse(AppView.allCases.contains { $0.requiredTier == .studio })

        // Structure-now invariant: at today's session tier (.studio,
        // fail-open) no destination is ever locked — zero user impact.
        XCTAssertTrue(AppView.allCases.allSatisfy {
            $0.requiredTier <= ProductTier.studio
        })
    }

    func testAppViewIcons() {
        // Every view should have a non-empty icon
        for view in AppView.allCases {
            XCTAssertFalse(view.icon.isEmpty, "\(view.rawValue) should have an icon")
        }
    }

    func testAppViewIds() {
        // id should equal rawValue
        for view in AppView.allCases {
            XCTAssertEqual(view.id, view.rawValue)
        }
    }

    // MARK: - Clear Selections

    func testClearSelections() {
        // Set some selections
        let scene = Scene(name: "Test Scene")
        let shot = Shot(shotId: 1, description: "Test Shot")
        let sequence = Sequence(name: "Test Sequence")

        coordinator.selectScene(scene)
        coordinator.selectedShot = shot
        coordinator.selectedSequence = sequence

        // Clear all
        coordinator.clearSelections()

        XCTAssertNil(coordinator.selectedSequence)
        XCTAssertNil(coordinator.selectedScene)
        XCTAssertNil(coordinator.selectedShot)
        XCTAssertNil(coordinator.selectedCharacter)
    }

    // MARK: - Select Scene

    func testSelectScene() {
        let scene = Scene(name: "Test Scene", description: "A test scene")
        coordinator.selectScene(scene)

        XCTAssertNotNil(coordinator.selectedScene)
        XCTAssertEqual(coordinator.selectedScene?.name, "Test Scene")
    }

    // MARK: - Select Sequence

    func testSelectSequence() {
        let sequence = Sequence(name: "Act 1")
        coordinator.selectSequence(sequence)

        XCTAssertNotNil(coordinator.selectedSequence)
        XCTAssertEqual(coordinator.selectedSequence?.name, "Act 1")
    }

    // MARK: - Event Publishers

    func testProjectChangedPublisher() {
        let expectation = XCTestExpectation(description: "Project changed event")

        coordinator.projectEvents.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        coordinator.notifyProjectChanged()

        wait(for: [expectation], timeout: 1.0)
    }

    func testSelectSceneUpdatesSelection() {
        // WS5.2: the dead sceneChanged subject was removed; selection is
        // plain @Published state now.
        let scene = Scene(name: "New Scene")
        coordinator.selectScene(scene)
        XCTAssertEqual(coordinator.selectedScene?.name, "New Scene")
    }

    // MARK: - Sub-Tab State

    func testInitialSubTabState() {
        XCTAssertEqual(coordinator.selectedSceneTab, "Scenes")
        XCTAssertEqual(coordinator.selectedProductionTab, "Schedule")
    }

    // MARK: - UI Toggles

    func testToggleNavigator() {
        XCTAssertTrue(coordinator.showingNavigator)
        coordinator.toggleNavigator()
        XCTAssertFalse(coordinator.showingNavigator)
        coordinator.toggleNavigator()
        XCTAssertTrue(coordinator.showingNavigator)
    }

    func testToggleTimeline() {
        XCTAssertTrue(coordinator.showingTimeline)
        coordinator.toggleTimeline()
        XCTAssertFalse(coordinator.showingTimeline)
    }

    func testToggleRightPanel() {
        XCTAssertTrue(coordinator.showingRightPanel)
        coordinator.toggleRightPanel()
        XCTAssertFalse(coordinator.showingRightPanel)
    }

    func testToggleComments() {
        XCTAssertFalse(coordinator.showingComments)
        coordinator.toggleComments()
        XCTAssertTrue(coordinator.showingComments)
    }

    // MARK: - Jump to Script

    func testJumpToScriptElement() {
        coordinator.jumpToScriptElement(itemId: "dialogue-123", itemType: "dialogue")

        XCTAssertEqual(coordinator.scrollToScriptItemId, "dialogue-123")
        XCTAssertEqual(coordinator.selectedView, .script)
    }

    func testJumpToScriptForShot() {
        let shot = Shot(
            shotId: 1,
            description: "Test shot",
            linkedDialogueIds: ["d-001"]
        )

        coordinator.jumpToScriptForShot(shot, scene: nil)

        XCTAssertEqual(coordinator.scrollToScriptItemId, "d-001")
        XCTAssertEqual(coordinator.selectedView, .script)
    }

    func testJumpToScriptForShotFallbackToAction() {
        let shot = Shot(
            shotId: 2,
            description: "Action shot",
            linkedDialogueIds: [],
            linkedActionIds: ["a-001"]
        )

        coordinator.jumpToScriptForShot(shot, scene: nil)

        XCTAssertEqual(coordinator.scrollToScriptItemId, "a-001")
    }

    func testJumpToScriptForShotFallbackToScene() {
        let shot = Shot(
            shotId: 3,
            description: "Scene fallback shot",
            linkedDialogueIds: [],
            linkedActionIds: [],
            linkedNarrationIds: []
        )
        let scene = Scene(uuid: "scene-fallback-001", name: "Fallback Scene")

        coordinator.jumpToScriptForShot(shot, scene: scene)

        XCTAssertEqual(coordinator.scrollToScriptItemId, "scene-fallback-001")
    }

    // MARK: - Connections Deep-Link

    func testNavigateToConnectionsSetsSceneTabAndHighlights() {
        let coordinator = AppCoordinator()
        coordinator.selectedView = .shotList
        let scene = Scene(uuid: "scene-c1", name: "Scene 1")

        coordinator.navigateToConnections(scene: scene,
                                          highlightShotId: "shot-9",
                                          highlightItemId: "dlg-4")

        XCTAssertEqual(coordinator.selectedView, .scenes)
        XCTAssertEqual(coordinator.selectedSceneTab, "Connections")
        XCTAssertEqual(coordinator.selectedScene?.id, "scene-c1")
        XCTAssertEqual(coordinator.connectionsHighlightShotId, "shot-9")
        XCTAssertEqual(coordinator.connectionsHighlightItemId, "dlg-4")
        XCTAssertTrue(coordinator.canNavigateBack,
                      "arriving at Connections must be reversible via Cmd+[")
    }

    func testNavigateToConnectionsWithoutSceneKeepsSelection() {
        let coordinator = AppCoordinator()
        let existing = Scene(uuid: "scene-keep", name: "Keep Me")
        coordinator.selectedScene = existing

        coordinator.navigateToConnections(scene: nil, highlightItemId: "act-1")

        XCTAssertEqual(coordinator.selectedScene?.id, "scene-keep")
        XCTAssertNil(coordinator.connectionsHighlightShotId)
        XCTAssertEqual(coordinator.connectionsHighlightItemId, "act-1")
    }
}

// MARK: - Scenes and shots on the wall
//
// The reverse direction: standing on a scene or a shot, what is it pinned
// to? The owner asked for hyperlinks (plural) because one scene can be up
// on the wall several times — a location reference, a lighting note, a
// costume swatch — and a control that only reached the first would
// quietly hide the rest.
//
// Lives here rather than in its own file because the test target's
// synchronized folder group does not pick up new files.

final class VisionWallLinksTests: XCTestCase {

    private func element(id: String, scene: String? = nil,
                         shot: String? = nil, title: String = "") -> VisionCard {
        var card = VisionCard()
        card.id = id
        card.title = title
        card.linkedSceneId = scene
        card.linkedShotId = shot
        return card
    }

    func testEveryElementPinnedToASceneIsListed() {
        let cards = [element(id: "a", scene: "scene-7"),
                     element(id: "b", scene: "scene-7"),
                     element(id: "c", scene: "scene-9")]

        let found = VisionLinkLookup.elements(forScene: "scene-7", in: cards)

        XCTAssertEqual(found.map(\.id), ["a", "b"],
                       "a scene can be up on the wall more than once")
    }

    func testAScenesListExcludesElementsThatAreReallyAboutOneOfItsShots() {
        // Linking a shot records its scene too. Asking for the SCENE's
        // elements must not sweep those in, or every shot reference would
        // masquerade as a scene reference.
        let cards = [element(id: "a", scene: "scene-7"),
                     element(id: "b", scene: "scene-7", shot: "shot-2")]

        XCTAssertEqual(
            VisionLinkLookup.elements(forScene: "scene-7", in: cards).map(\.id),
            ["a"])
        XCTAssertEqual(
            VisionLinkLookup.elements(forShot: "shot-2", in: cards).map(\.id),
            ["b"])
    }

    func testNothingPinnedMeansNoLinks() {
        XCTAssertTrue(VisionLinkLookup.elements(forScene: "scene-7",
                                                in: []).isEmpty)
        XCTAssertTrue(VisionLinkLookup.elements(
            forShot: "shot-2", in: [element(id: "a", scene: "scene-7")]).isEmpty)
    }

    // MARK: - What a link is called

    func testAnElementIsNamedByItsTitleWhenItHasOne() {
        let card = element(id: "a", scene: "s", title: "Golden hour ref")
        XCTAssertEqual(WallLinksButton.name(of: card), "Golden hour ref")
    }

    func testAnUntitledElementIsNamedByWhatItIs() {
        var card = element(id: "a", scene: "s")
        card.cardType = "image"
        XCTAssertEqual(WallLinksButton.name(of: card), "Picture",
                       "never a bare id in front of a person")
    }

    func testAWordClippingIsNamedByItsWords() {
        var card = element(id: "a", scene: "s")
        card.cardType = "text"
        card.text = "COLD, WIDE, UNFORGIVING"
        XCTAssertEqual(WallLinksButton.name(of: card), "COLD, WIDE, UNFORGIVING")
    }

    func testAVeryLongClippingIsTrimmedRatherThanFillingTheMenu() {
        var card = element(id: "a", scene: "s")
        card.cardType = "text"
        card.text = String(repeating: "long ", count: 40)
        XCTAssertLessThanOrEqual(WallLinksButton.name(of: card).count, 38)
    }
}

// MARK: - Curation view-model (P1 §2.17 test debt — audit grade D)

@MainActor
final class CurationFilterTests: XCTestCase {

    private func project() -> Project {
        var goodTake = Take(takeNumber: 1)
        goodTake.rating = .circle
        goodTake.notes = "keeper, great light"
        var badTake = Take(takeNumber: 2)
        badTake.rating = .ng
        badTake.tags = ["soft focus"]
        var shot = Shot(shotId: 1)
        shot.takes = [goodTake, badTake]
        var harbor = DirectorsChairCore.Scene(name: "Harbor Dawn")
        harbor.shots = [shot]

        var emptyShot = Shot(shotId: 2)
        emptyShot.takes = []
        var teaShop = DirectorsChairCore.Scene(name: "Tea Shop")
        teaShop.shots = [emptyShot]

        var sequence = Sequence(name: "Act One")
        sequence.scenes = [harbor, teaShop]
        var project = Project(name: "P")
        project.sequences = [sequence]
        return project
    }

    func testNoFiltersShowsEveryScene() {
        let viewModel = CurationViewModel()
        XCTAssertEqual(viewModel.filteredScenes(from: project()).count, 2,
                       "even the scene with no takes — it still exists")
    }

    func testRatingFilterDropsTakesAndCollapsesEmptyScenes() {
        let viewModel = CurationViewModel()
        viewModel.filterRating = .circle

        let scenes = viewModel.filteredScenes(from: project())
        XCTAssertEqual(scenes.map(\.name), ["Harbor Dawn"],
                       "a scene with no matching takes disappears")
        XCTAssertEqual(scenes[0].shots[0].takes.map(\.takeNumber), [1],
                       "and inside it only the matching take remains")
    }

    func testSearchMatchesNotesTagsAndSceneNames() {
        let viewModel = CurationViewModel()

        viewModel.searchQuery = "keeper"
        XCTAssertEqual(viewModel.filteredScenes(from: project())
            .first?.shots.first?.takes.map(\.takeNumber), [1])

        viewModel.searchQuery = "soft focus"
        XCTAssertEqual(viewModel.filteredScenes(from: project())
            .first?.shots.first?.takes.map(\.takeNumber), [2],
            "tags are searchable too")

        viewModel.searchQuery = "harbor"
        XCTAssertEqual(viewModel.filteredScenes(from: project())
            .first?.shots.first?.takes.count, 2,
            "matching the scene NAME keeps all its takes")
    }

    func testRatingAndSearchCombineAsAND() {
        let viewModel = CurationViewModel()
        viewModel.filterRating = .circle
        viewModel.searchQuery = "soft focus"
        XCTAssertTrue(viewModel.filteredScenes(from: project()).isEmpty,
                      "the circled take doesn't match the search; the "
                      + "matching take isn't circled")
    }
}

// MARK: - Playback view-model (P1 §2.17 test debt — audit grade D)

@MainActor
final class PlaybackViewModelContractTests: XCTestCase {

    func testMuteZeroesTheEffectiveVolumeWithoutForgettingTheDial() {
        let viewModel = PlaybackViewModel()
        viewModel.volume = 0.6
        viewModel.isMuted = true
        XCTAssertEqual(viewModel.effectiveVolume, 0)
        viewModel.isMuted = false
        XCTAssertEqual(viewModel.effectiveVolume, 0.6,
                       "unmuting returns to where the dial was")
    }

    func testPlaylistBoundariesFollowSceneOrder() {
        // Playlist ITEMS come from shots; scenes contribute boundaries.
        var shotA = Shot(shotId: 1); shotA.duration = 3
        var sceneA = DirectorsChairCore.Scene(name: "First")
        sceneA.dialogues = [Dialogue(character: "MEERA", text: "We go at dawn.")]
        sceneA.shots = [shotA]
        var shotB = Shot(shotId: 2); shotB.duration = 2
        var sceneB = DirectorsChairCore.Scene(name: "Second")
        sceneB.dialogues = [Dialogue(character: "DEV", text: "Then sleep now.")]
        sceneB.shots = [shotB]
        var sequence = Sequence(name: "Act")
        sequence.scenes = [sceneA, sceneB]
        var project = Project(name: "P")
        project.sequences = [sequence]

        let viewModel = PlaybackViewModel()
        viewModel.buildPlaylist(from: project, basePath: nil)

        XCTAssertEqual(viewModel.sceneBoundaries.map(\.name),
                       ["First", "Second"])
        XCTAssertLessThan(viewModel.sceneBoundaries[0].time,
                          viewModel.sceneBoundaries[1].time + 0.001,
                          "boundaries never run backwards")
        XCTAssertFalse(viewModel.playlistItems.isEmpty)
        XCTAssertGreaterThan(viewModel.totalDuration, 0)
    }

    func testResolvedVideoPathRidesTheProxyPipeline() throws {
        // The §2.17 seam: playback resolves through ProxyPlayback, so a
        // fresh proxy wins and the toggle restores originals.
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("playback-proxy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: base.appendingPathComponent("takes"),
            withIntermediateDirectories: true)
        let rel = "takes/a.mov"
        try Data([0x1]).write(to: base.appendingPathComponent(rel))
        defer { try? FileManager.default.removeItem(at: base) }

        let viewModel = PlaybackViewModel()
        viewModel.buildPlaylist(from: Project(name: "P"), basePath: base)

        XCTAssertEqual(viewModel.resolvedVideoPath(for: rel),
                       base.appendingPathComponent(rel),
                       "no proxy yet: the original plays")

        let proxy = ProxyMediaStore.proxyURL(forRelativePath: rel,
                                             projectBase: base)
        try FileManager.default.createDirectory(
            at: proxy.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("proxy".utf8).write(to: proxy)
        XCTAssertEqual(viewModel.resolvedVideoPath(for: rel), proxy,
                       "a fresh proxy wins for playback")

        UserDefaults.standard.set(false, forKey: ProxyPlayback.preferenceKey)
        defer {
            UserDefaults.standard.removeObject(
                forKey: ProxyPlayback.preferenceKey)
        }
        XCTAssertEqual(viewModel.resolvedVideoPath(for: rel),
                       base.appendingPathComponent(rel),
                       "the Preferences toggle restores originals")
    }
}

// MARK: - Command palette catalog (§2.18)
//
// Same housing note as VisionWallLinksTests: new files in this target's
// synchronized folder group don't compile, so the palette's app-side
// tests live here. The generic ranking is pinned in the Views package
// (CommandPaletteRankTests); these pin what the CATALOG promises — what
// ⌘K offers tracks live app state, ids stay unique, and an assistant
// action stages rather than fires.

@MainActor
final class CommandPaletteCatalogTests: XCTestCase {

    private func makeViewModel(withProject: Bool) -> ProjectViewModel {
        let viewModel = ProjectViewModel()
        if withProject {
            viewModel.project = Project(name: "Palette Test")
            viewModel.hasProject = true
        }
        return viewModel
    }

    func testCatalogTracksProjectState() {
        let coordinator = AppCoordinator()
        let without = CommandPaletteCatalog.entries(
            coordinator: coordinator,
            projectViewModel: makeViewModel(withProject: false),
            assistantAvailable: true)
        XCTAssertFalse(without.contains { $0.id == "nav.Scenes" },
                       "project-requiring views must not be offered "
                       + "with no project open")
        XCTAssertFalse(without.contains { $0.id.hasPrefix("ptab.") })
        XCTAssertFalse(without.contains { $0.id.hasPrefix("action.") })
        XCTAssertTrue(without.contains { $0.id == "nav.Projects" },
                      "the way OUT of no-project state must be offered")

        let with = CommandPaletteCatalog.entries(
            coordinator: coordinator,
            projectViewModel: makeViewModel(withProject: true),
            assistantAvailable: true)
        XCTAssertTrue(with.contains { $0.id == "nav.Scenes" })
        for tab in CommandPaletteCatalog.productionTabs {
            XCTAssertTrue(with.contains { $0.id == "ptab.\(tab)" },
                          "every real production tab is reachable — the "
                          + "UI journeys proved these five exist")
        }
        XCTAssertGreaterThan(
            with.filter { $0.id.hasPrefix("action.") }.count, 30,
            "the assistant's catalog is the palette's long tail")
    }

    func testCatalogIdsAreUniqueAndNavigationLeads() {
        let entries = CommandPaletteCatalog.entries(
            coordinator: AppCoordinator(),
            projectViewModel: makeViewModel(withProject: true),
            assistantAvailable: true)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count,
                       "two entries sharing an id would collide in the list")
        XCTAssertEqual(entries.first?.category, .navigation,
                       "an empty palette shows navigation first")
    }

    func testAssistantUnavailableHidesActionsButKeepsTheApp() {
        let entries = CommandPaletteCatalog.entries(
            coordinator: AppCoordinator(),
            projectViewModel: makeViewModel(withProject: true),
            assistantAvailable: false)
        XCTAssertFalse(entries.contains { $0.id.hasPrefix("action.") },
                       "signed out, the chat can't open — offering its "
                       + "actions would dead-end")
        XCTAssertTrue(entries.contains { $0.id == "nav.Scenes" })
    }

    func testRunningAnAssistantActionStagesInsteadOfFiring() {
        let coordinator = AppCoordinator()
        let viewModel = makeViewModel(withProject: true)
        let entry = PaletteEntry(id: "action.update_scene_description",
                                 title: "Update scene description",
                                 subtitle: nil, systemImage: "sparkles",
                                 category: .assistant)
        CommandPaletteCatalog.run(entry, query: "", coordinator: coordinator,
                                  projectViewModel: viewModel)
        XCTAssertEqual(coordinator.pendingAssistantPrompt,
                       "Update scene description ",
                       "actions take arguments — the palette stages the "
                       + "phrase for the user to finish, never fires blind")
        XCTAssertTrue(coordinator.showingAIChat)
    }

    func testRunningNavigationAndTabsNavigates() {
        let coordinator = AppCoordinator()
        let viewModel = makeViewModel(withProject: true)
        CommandPaletteCatalog.run(
            PaletteEntry(id: "nav.Scenes", title: "Go to Scenes",
                         subtitle: nil, systemImage: "film",
                         category: .navigation),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertEqual(coordinator.selectedView, .scenes)

        CommandPaletteCatalog.run(
            PaletteEntry(id: "ptab.Accounting", title: "Production: Accounting",
                         subtitle: nil, systemImage: "theatermasks",
                         category: .navigation),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertEqual(coordinator.selectedView, .production)
        XCTAssertEqual(coordinator.selectedProductionTab, "Accounting")
    }

    func testHumanizeTurnsWireNamesIntoTitles() {
        XCTAssertEqual(CommandPaletteCatalog.humanize("generate_scene_image"),
                       "Generate scene image")
        XCTAssertEqual(CommandPaletteCatalog.humanize("navigate"), "Navigate")
    }
}

// MARK: - Global search through the palette (§2.18)

@MainActor
final class CommandPaletteGlobalSearchTests: XCTestCase {

    private func makeViewModel() -> ProjectViewModel {
        let viewModel = ProjectViewModel()
        var scene = Scene(name: "Night Market")
        scene.location = "EXT. NIGHT MARKET - NIGHT"
        scene.shots = [Shot(shotId: 7, description: "Crane over the stalls")]
        var project = Project(name: "Search Test")
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        project.characters = [Character(name: "Mara")]
        project.locations = [Location(name: "Harbour")]
        var card = VisionCard()
        card.title = "Neon rain palette"
        var wordless = VisionCard()
        wordless.title = ""
        wordless.text = ""
        project.beats = [card, wordless]
        viewModel.project = project
        viewModel.hasProject = true
        return viewModel
    }

    func testContentEntriesCoverEveryFindableKindAndSkipWordlessScraps() {
        let entries = CommandPaletteCatalog.contentEntries(
            project: makeViewModel().project)
        let ids = entries.map(\.id)
        XCTAssertTrue(ids.contains { $0.hasPrefix("find.scene.") })
        XCTAssertTrue(ids.contains { $0.hasPrefix("find.shot.") })
        XCTAssertTrue(ids.contains { $0.hasPrefix("find.char.Mara") })
        XCTAssertTrue(ids.contains { $0.hasPrefix("find.loc.Harbour") })
        XCTAssertEqual(ids.filter { $0.hasPrefix("find.vision.") }.count, 1,
                       "a scrap with no words is unfindable by text — "
                       + "listing it as an anonymous Picture is noise")
        XCTAssertTrue(entries.allSatisfy { $0.category == .content })
    }

    func testContentIsFindableByTypingItsName() {
        let viewModel = makeViewModel()
        let coordinator = AppCoordinator()
        let all = CommandPaletteCatalog.entries(
            coordinator: coordinator, projectViewModel: viewModel,
            assistantAvailable: false)
        let ranked = PaletteRank.rank(entries: all, query: "night market")
        XCTAssertTrue(ranked.contains { $0.id.hasPrefix("find.scene.") },
                      "typing a scene's name must surface the scene")
    }

    func testRunningFindEntriesNavigatesToTheRealThing() {
        let viewModel = makeViewModel()
        let scene = viewModel.project.sequences[0].scenes[0]
        let shot = scene.shots[0]
        let coordinator = AppCoordinator()

        CommandPaletteCatalog.run(
            PaletteEntry(id: "find.scene.\(scene.id)", title: scene.name,
                         subtitle: nil, systemImage: "film", category: .content),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertEqual(coordinator.selectedScene?.id, scene.id)
        XCTAssertEqual(coordinator.selectedView, .scenes)

        CommandPaletteCatalog.run(
            PaletteEntry(id: "find.shot.\(shot.id)", title: "Shot 7",
                         subtitle: nil, systemImage: "camera", category: .content),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertEqual(coordinator.selectedShot?.id, shot.id)
        XCTAssertEqual(coordinator.selectedView, .shotList)

        CommandPaletteCatalog.run(
            PaletteEntry(id: "find.char.Mara", title: "Mara",
                         subtitle: nil, systemImage: "person", category: .content),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertEqual(coordinator.selectedCharacter?.name, "Mara")
        XCTAssertEqual(coordinator.selectedView, .storyDesign)

        CommandPaletteCatalog.run(
            PaletteEntry(id: "find.vision.abc123", title: "Neon",
                         subtitle: nil, systemImage: "square.grid.2x2",
                         category: .content),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertEqual(coordinator.revealVisionCardId, "abc123")
        XCTAssertEqual(coordinator.selectedView, .visionBoard)
    }

    func testDeletedTargetIsANoOpNotAJump() {
        let viewModel = makeViewModel()
        let coordinator = AppCoordinator()
        coordinator.navigateTo(.script)
        CommandPaletteCatalog.run(
            PaletteEntry(id: "find.scene.gone", title: "Gone",
                         subtitle: nil, systemImage: "film", category: .content),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertNil(coordinator.selectedScene)
        XCTAssertEqual(coordinator.selectedView, .script,
                       "a stale result must not fling the user anywhere")
    }

    func testForwardersCarryTheQueryToTheirSurfaces() {
        let viewModel = makeViewModel()
        let coordinator = AppCoordinator()

        let dynamics = CommandPaletteCatalog.dynamicEntries(
            query: "crane", hasProject: true)
        XCTAssertEqual(dynamics.map(\.id),
                       ["forward.assets", "forward.script"])
        XCTAssertTrue(CommandPaletteCatalog.dynamicEntries(
            query: "", hasProject: true).isEmpty,
            "no query, nothing to forward")
        XCTAssertTrue(CommandPaletteCatalog.dynamicEntries(
            query: "crane", hasProject: false).isEmpty)

        CommandPaletteCatalog.run(
            dynamics[0], query: "crane", coordinator: coordinator,
            projectViewModel: viewModel)
        XCTAssertEqual(coordinator.pendingAssetsSearch, "crane",
                       "the assets library searches the disk — the "
                       + "palette hands the query over instead of guessing")
        XCTAssertEqual(coordinator.selectedView, .assets)
    }

    func testScriptForwarderStagesTheFindPasteboard() {
        let viewModel = makeViewModel()
        let coordinator = AppCoordinator()
        CommandPaletteCatalog.run(
            PaletteEntry(id: "forward.script", title: "",
                         subtitle: nil, systemImage: "text.magnifyingglass",
                         category: .content),
            query: "the tide schedule", coordinator: coordinator,
            projectViewModel: viewModel)
        XCTAssertEqual(coordinator.selectedView, .script)
        XCTAssertEqual(
            NSPasteboard(name: .find).string(forType: .string),
            "the tide schedule",
            "NSTextFinder reads the system find pasteboard — staging it "
            + "there is what makes ⌘F come up pre-filled")
    }
}

// MARK: - Remappable shortcuts (§2.18)

@MainActor
final class ShortcutStoreTests: XCTestCase {

    private var suite: UserDefaults!
    private let suiteName = "ShortcutStoreTests"

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: suiteName)
        suite.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testShippedDefaultsNeverCollide() {
        // The app actually shipped Force Save and Project Snapshots both
        // on ⌥⌘S — one of them could never fire. This pins the whole
        // default table as clash-free so that bug class is dead.
        let specs = ShortcutStore.commands.map { $0.defaultSpec.storage }
        XCTAssertEqual(Set(specs).count, specs.count,
                       "two commands share a default shortcut")
        XCTAssertEqual(
            ShortcutStore.commands.first { $0.id == "file.forceSave" }?
                .defaultSpec.display, "⌃⌘S",
            "Force Save moved off ⌥⌘S, which Project Snapshots owns")
    }

    func testDefaultsAlsoAvoidTheProtectedPlatformCombos() {
        for command in ShortcutStore.commands {
            XCTAssertFalse(
                ShortcutStore.protectedCombos.contains(command.defaultSpec),
                "\(command.label) defaults to a protected combo")
        }
    }

    func testOverridePersistsAcrossStoreInstances() {
        let store = ShortcutStore(defaults: suite)
        XCTAssertNil(store.set(ShortcutSpec(key: "g", command: true),
                               for: "nav.Scenes"))
        let reloaded = ShortcutStore(defaults: suite)
        XCTAssertEqual(reloaded.spec(for: "nav.Scenes").display, "⌘G",
                       "a rebind must survive relaunch")
        XCTAssertEqual(reloaded.spec(for: "nav.Assets").display, "⌘4",
                       "unrelated commands keep their defaults")
    }

    func testConflictsAreRefusedWithTheHoldersName() {
        let store = ShortcutStore(defaults: suite)
        let error = store.set(ShortcutSpec(key: "2", command: true),
                              for: "nav.Scenes")
        XCTAssertNotNil(error, "⌘2 is Bubble View's — must refuse")
        XCTAssertTrue(error?.contains("Bubble") == true,
                      "the refusal names the current holder")
        XCTAssertEqual(store.spec(for: "nav.Scenes").display, "⌘3",
                       "a refused rebind changes nothing")

        // Conflicts consider OVERRIDES too, not just defaults.
        XCTAssertNil(store.set(ShortcutSpec(key: "g", command: true),
                               for: "nav.Assets"))
        XCTAssertNotNil(store.set(ShortcutSpec(key: "g", command: true),
                                  for: "nav.Scenes"))
    }

    func testProtectedAndUnchordedCombosAreRefused() {
        let store = ShortcutStore(defaults: suite)
        XCTAssertNotNil(store.set(ShortcutSpec(key: "s", command: true),
                                  for: "nav.Scenes"),
                        "⌘S is Save's — the platform owns it")
        XCTAssertNotNil(store.set(ShortcutSpec(key: "g", shift: true),
                                  for: "nav.Scenes"),
                        "shift-G is typing a capital G")
        XCTAssertTrue(store.overrides.isEmpty)
    }

    func testResetRestoresTheDefault() {
        let store = ShortcutStore(defaults: suite)
        store.set(ShortcutSpec(key: "g", command: true), for: "nav.Scenes")
        store.set(ShortcutSpec(key: "j", command: true), for: "nav.Assets")
        store.reset("nav.Scenes")
        XCTAssertEqual(store.spec(for: "nav.Scenes").display, "⌘3")
        XCTAssertEqual(store.spec(for: "nav.Assets").display, "⌘J")
        store.resetAll()
        XCTAssertTrue(store.overrides.isEmpty)
        XCTAssertTrue(ShortcutStore(defaults: suite).overrides.isEmpty,
                      "reset-all persists")
    }

    func testCorruptedStorageFallsBackToDefaults() {
        suite.set(["nav.Scenes": "not-a-spec"], forKey: "remappedShortcuts")
        let store = ShortcutStore(defaults: suite)
        XCTAssertEqual(store.spec(for: "nav.Scenes").display, "⌘3",
                       "garbage in defaults must not break the menu")
    }
}

// MARK: - Screenplay export formats (§2.18)

@MainActor
final class ScreenplayExportFormatTests: XCTestCase {

    private var temp: URL!

    override func setUp() {
        super.setUp()
        temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportFormatTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: temp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temp)
        super.tearDown()
    }

    private func makeProject() -> Project {
        var scene = Scene(name: "Night Market",
                          dialogues: [Dialogue(character: "Mara",
                                               text: "The tide won't wait.",
                                               chronologyNumber: 1,
                                               globalChronologyNumber: 1)])
        scene.location = "EXT. NIGHT MARKET - NIGHT"
        var project = Project(name: "Format Test")
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        project.characters = [Character(name: "Mara"),
                              Character(name: "The A/V: Tech")]
        return project
    }

    func testEveryFormatWritesARealFile() throws {
        // These four menu items shipped as silent no-ops — the generators
        // existed, the wiring didn't. This drives the exact write path
        // the queue jobs run.
        let project = makeProject()
        for format in ScreenplayExportFormat.allCases {
            let url = temp.appendingPathComponent("out.\(format.fileExtension)")
            if format.rendersOnMain {
                try ScreenplayExportFormat.writePDF(project, to: url)
            } else {
                try format.writeText(project, to: url)
            }
            let data = try Data(contentsOf: url)
            XCTAssertFalse(data.isEmpty, "\(format.rawValue) wrote nothing")
        }
    }

    func testFormatsProduceTheirOwnDialects() throws {
        let project = makeProject()

        let fountainURL = temp.appendingPathComponent("a.fountain")
        try ScreenplayExportFormat.fountain.writeText(project, to: fountainURL)
        let fountain = try String(contentsOf: fountainURL, encoding: .utf8)
        XCTAssertTrue(fountain.contains("NIGHT MARKET"),
                      "the scene must be in the screenplay")
        XCTAssertTrue(fountain.contains("The tide won't wait."))

        let fdxURL = temp.appendingPathComponent("a.fdx")
        try ScreenplayExportFormat.fdx.writeText(project, to: fdxURL)
        let fdx = try String(contentsOf: fdxURL, encoding: .utf8)
        XCTAssertTrue(fdx.contains("<FinalDraft"),
                      "FDX is Final Draft's XML dialect")

        let pdfURL = temp.appendingPathComponent("a.pdf")
        try ScreenplayExportFormat.writePDF(project, to: pdfURL)
        let pdf = try Data(contentsOf: pdfURL)
        XCTAssertTrue(pdf.starts(with: Array("%PDF".utf8)),
                      "a .pdf that isn't a PDF is a support ticket")

        let htmlURL = temp.appendingPathComponent("a.html")
        try ScreenplayExportFormat.html.writeText(project, to: htmlURL)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        XCTAssertTrue(html.lowercased().contains("<html")
                      || html.lowercased().contains("<!doctype"))
    }

    func testCharacterSheetsWriteOnePDFEachWithSanitizedNames() throws {
        let project = makeProject()
        try ScreenplayExportFormat.writeCharacterSheets(project, into: temp)
        let written = try FileManager.default
            .contentsOfDirectory(atPath: temp.path).sorted()
        XCTAssertEqual(written, ["Mara.pdf", "The A-V- Tech.pdf"],
                       "one sheet per character; a name with / or : is "
                       + "user text, not a path instruction")
    }
}

// MARK: - Script revisions through the palette (§2.18)

@MainActor
final class CommandPaletteRevisionTests: XCTestCase {

    private func makeViewModel() -> ProjectViewModel {
        let viewModel = ProjectViewModel()
        var project = Project(name: "Rev Palette")
        project.sequences = [Sequence(name: "Act 1",
                                      scenes: [Scene(name: "One"),
                                               Scene(name: "Two")])]
        viewModel.project = project
        viewModel.hasProject = true
        return viewModel
    }

    func testPaletteOffersLockThenAdvanceNeverBoth() {
        let coordinator = AppCoordinator()
        let viewModel = makeViewModel()

        var ids = CommandPaletteCatalog.entries(
            coordinator: coordinator, projectViewModel: viewModel,
            assistantAvailable: false).map(\.id)
        XCTAssertTrue(ids.contains("cmd.lockScenes"))
        XCTAssertFalse(ids.contains("cmd.advanceRevision"),
                       "no rounds before the lock")

        ScriptRevisionTracker.lock(&viewModel.project, date: "d0")
        let entries = CommandPaletteCatalog.entries(
            coordinator: coordinator, projectViewModel: viewModel,
            assistantAvailable: false)
        ids = entries.map(\.id)
        XCTAssertFalse(ids.contains("cmd.lockScenes"),
                       "numbers are promises — no second lock")
        XCTAssertEqual(entries.first { $0.id == "cmd.advanceRevision" }?.title,
                       "Start Blue Revision",
                       "the palette names the round it would open")
    }

    func testRunningLockFreezesNumbersThroughTheViewModel() {
        let coordinator = AppCoordinator()
        let viewModel = makeViewModel()
        CommandPaletteCatalog.run(
            PaletteEntry(id: "cmd.lockScenes", title: "Lock Scene Numbers",
                         subtitle: nil, systemImage: "lock",
                         category: .command),
            query: "", coordinator: coordinator, projectViewModel: viewModel)
        XCTAssertEqual(viewModel.project.scriptRevisionColor, "White")
        XCTAssertEqual(viewModel.project.sequences[0].scenes.map(\.lockedNumber),
                       ["1", "2"])
    }
}

// MARK: - Dailies ingest end-to-end (§2.18)

@MainActor
final class DailiesIngestControllerTests: XCTestCase {

    private var temp: URL!

    override func setUp() {
        super.setUp()
        temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailiesController-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: temp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temp)
        super.tearDown()
    }

    func testFilingAClipCopiesItIntoTheFootageLayoutAndAppendsTheTake() async throws {
        // A project on disk (the footage layout is relative to it).
        let projectDir = temp.appendingPathComponent("My Film")
        try FileManager.default.createDirectory(
            at: projectDir, withIntermediateDirectories: true)
        let viewModel = ProjectViewModel()
        var scene = Scene(name: "Scene 7")
        scene.shots = [Shot(shotId: 4)]
        var project = Project(name: "My Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]
        viewModel.project = project
        viewModel.hasProject = true
        viewModel.projectPath = projectDir.appendingPathComponent("project.json")

        // A clip in the watch folder.
        let clip = temp.appendingPathComponent("S07_T02.mov")
        try Data(repeating: 7, count: 64).write(to: clip)

        let controller = DailiesIngestController()
        controller.configure(projectViewModel: viewModel)
        // The copy runs off the main thread; the take lands when it completes.
        await controller.file(clip, sequenceIndex: 0, sceneIndex: 0, shotIndex: 0)?.value

        let takes = viewModel.project.sequences[0].scenes[0].shots[0].takes
        XCTAssertEqual(takes.count, 1)
        XCTAssertEqual(takes[0].takeNumber, 2,
                       "the slate's take number rides the filename")
        XCTAssertEqual(takes[0].cameraSourceFileName, "S07_T02.mov")

        let relative = try XCTUnwrap(takes[0].capturedVideoPath)
        XCTAssertTrue(relative.hasPrefix("footage/Scene_4/Shot_004/"),
                      "the copy mirrors the recording pipeline's layout "
                      + "(got \(relative))")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectDir.appendingPathComponent(relative).path),
            "the clip must actually be in the project now")
        XCTAssertTrue(FileManager.default.fileExists(atPath: clip.path),
            "the watch folder keeps its original — cards are evidence")
    }
}

// MARK: - Imagine panel → gateway mapping (DC-0034)

@MainActor
final class ImagineServiceRequestTests: XCTestCase {

    func testTheAskFinallyReachesTheWire() {
        // Before DC-0034 the executor hardcoded 16:9, one image, no
        // references — the panel's whole point is that these carry.
        let reference = (data: Data([1, 2, 3]), mime: "image/jpeg")
        let request = CentralViewStack.imagineServiceRequest(
            ImagineRequest(prompt: "dawn harbour", aspectRatio: "9:16",
                           variationCount: 3,
                           referenceURLs: [URL(fileURLWithPath: "/tmp/r.jpg")]),
            references: [reference])

        XCTAssertEqual(request.aspectRatio, "9:16")
        XCTAssertEqual(request.numberOfImages, 3)
        XCTAssertTrue(request.prompt.contains("dawn harbour"))
        XCTAssertEqual(request.referenceImages?.count, 1)
        XCTAssertEqual(request.referenceImages?[0].base64,
                       Data([1, 2, 3]).base64EncodedString())
        XCTAssertEqual(request.referenceImages?[0].mimeType, "image/jpeg")
        XCTAssertEqual(request.referenceImages?[0].label, "reference 1")
    }

    func testNoReferencesMeansNilNotEmptyArray() {
        let request = CentralViewStack.imagineServiceRequest(
            ImagineRequest(prompt: "p"), references: [])
        XCTAssertNil(request.referenceImages,
                     "the wire contract treats nil and [] differently")
        XCTAssertEqual(request.aspectRatio, "16:9")
        XCTAssertEqual(request.numberOfImages, 1)
    }

    // MARK: - Surface memory (DC-0092)

    func testSurfaceMemoryRestoresSelectionsPerProject() {
        var project = Project(name: "Remembered")
        let alex = Character(name: "Alex")
        let desert = Location(name: "Desert road")
        project.characters = [Character(name: "First"), alex]
        project.locations = [Location(name: "First place"), desert]
        let key = AppCoordinator.surfaceMemoryKey(projectId: project.uuid)
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let coordinator = AppCoordinator()
        coordinator.restoreSurfaceMemory(for: project)
        XCTAssertNil(coordinator.selectedLocation, "nothing remembered yet")
        coordinator.surfaceMemory.storyDesignMode = "locations"
        coordinator.surfaceMemory.designTab = "costume"
        coordinator.selectedCharacter = alex
        coordinator.selectedLocation = desert

        let later = AppCoordinator()
        later.restoreSurfaceMemory(for: project)
        XCTAssertEqual(later.surfaceMemory.storyDesignMode, "locations")
        XCTAssertEqual(later.surfaceMemory.designTab, "costume")
        XCTAssertEqual(later.selectedCharacter?.id, alex.id)
        XCTAssertEqual(later.selectedLocation?.id, desert.id)
    }

    func testSurfaceMemorySkipsIdsThatNoLongerExistAndKeepsRememberedOnNilSelection() {
        var project = Project(name: "Pruned")
        let desert = Location(name: "Desert road")
        project.locations = [desert]
        let key = AppCoordinator.surfaceMemoryKey(projectId: project.uuid)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let coordinator = AppCoordinator()
        coordinator.restoreSurfaceMemory(for: project)
        coordinator.selectedLocation = desert
        coordinator.selectedLocation = nil
        XCTAssertEqual(coordinator.surfaceMemory.locationId, desert.id, "a nil selection never erases the memory")

        project.locations = []
        let later = AppCoordinator()
        later.restoreSurfaceMemory(for: project)
        XCTAssertNil(later.selectedLocation)
        XCTAssertEqual(later.surfaceMemory.locationId, desert.id)
    }

    func testCrossViewLocationAskRemembersTheLocationsMode() {
        let coordinator = AppCoordinator()
        coordinator.selectLocation(Location(name: "Desert road"))
        XCTAssertEqual(coordinator.surfaceMemory.storyDesignMode, "locations")
        XCTAssertEqual(coordinator.selectedView, .storyDesign)
        coordinator.selectCharacter(Character(name: "Alex"))
        XCTAssertEqual(coordinator.surfaceMemory.storyDesignMode, "characters")
    }
}
