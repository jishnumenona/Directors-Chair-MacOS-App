// DirectorsChairViewsTests/VisionBoardAssetPipelineTests.swift
//
// Vision Board repair, Slice 2: image path scheme + the no-orphan asset
// pipeline — classification, resolve-on-load, store-relative-on-write,
// staging round-trips, save-time normalization, and the guarantee that a
// cancelled editor session leaves the project untouched.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class VisionBoardImagePathTests: XCTestCase {

    func testClassificationMatrix() {
        XCTAssertEqual(VisionImageRef.classify(nil), .none)
        XCTAssertEqual(VisionImageRef.classify(""), .none)
        XCTAssertEqual(VisionImageRef.classify("assets/visionboard/a.png"),
                       .relative("assets/visionboard/a.png"))
        XCTAssertEqual(VisionImageRef.classify("/Users/x/pic.png"),
                       .legacyAbsolute("/Users/x/pic.png"))
        if case .legacyAbsolute(let expanded) = VisionImageRef.classify("~/pic.png") {
            XCTAssertTrue(expanded.hasPrefix("/"), "tilde expanded")
            XCTAssertTrue(expanded.hasSuffix("/pic.png"))
        } else {
            XCTFail("tilde path must classify as legacyAbsolute")
        }
        XCTAssertEqual(VisionImageRef.classify("https://example.com/a.png"),
                       .remote(URL(string: "https://example.com/a.png")!))
        XCTAssertEqual(VisionImageRef.classify("http://example.com/a.png"),
                       .remote(URL(string: "http://example.com/a.png")!))
    }

    func testResolveImageURL() {
        let base = URL(fileURLWithPath: "/tmp/project")
        XCTAssertEqual(
            VisionBoardImagePath.resolveImageURL("assets/visionboard/a.png",
                                                 projectBase: base)?.path,
            "/tmp/project/assets/visionboard/a.png")
        XCTAssertNil(VisionBoardImagePath.resolveImageURL("assets/a.png",
                                                          projectBase: nil),
                     "relative path without a base cannot resolve")
        XCTAssertEqual(
            VisionBoardImagePath.resolveImageURL("/abs/pic.png",
                                                 projectBase: base)?.path,
            "/abs/pic.png")
        XCTAssertNil(VisionBoardImagePath.resolveImageURL(
            "https://example.com/a.png", projectBase: base),
                     "remote refs never resolve to file URLs")
        XCTAssertNil(VisionBoardImagePath.resolveImageURL(nil, projectBase: base))
    }

    func testRelativized() {
        let base = URL(fileURLWithPath: "/tmp/project")
        XCTAssertEqual(
            VisionBoardImagePath.relativized("/tmp/project/assets/a.png",
                                             projectBase: base),
            "assets/a.png")
        XCTAssertNil(VisionBoardImagePath.relativized("/tmp/elsewhere/a.png",
                                                      projectBase: base))
        XCTAssertNil(VisionBoardImagePath.relativized("/tmp/project2/a.png",
                                                      projectBase: base),
                     "component-based: /project must not prefix-match /project2")
        XCTAssertNil(VisionBoardImagePath.relativized("/tmp/project",
                                                      projectBase: base),
                     "the base itself is not inside the base")
    }
}

final class VisionBoardAssetStoreTests: XCTestCase {

    private var projectBase: URL!

    override func setUpWithError() throws {
        projectBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("vb-store-tests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: projectBase,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: projectBase)
    }

    private func makeStore(
        fetchData: @escaping @Sendable (URL) async throws -> Data = { _ in
            throw URLError(.notConnectedToInternet)
        }
    ) -> VisionBoardAssetStore {
        VisionBoardAssetStore(projectBase: projectBase, fetchData: fetchData)
    }

    private var managedDir: URL {
        projectBase.appendingPathComponent(VisionBoardAssetStore.assetSubfolder)
    }

    func testStageFinalizeRoundTrip() throws {
        let store = makeStore()
        let data = Data("png-bytes".utf8)

        let staged = try store.stagePastedPNG(data)
        XCTAssertTrue(store.isStaged(staged))
        XCTAssertFalse(staged.path.hasPrefix(projectBase.path),
                       "staging lives outside the project")

        let relative = try store.finalize(staged)
        XCTAssertTrue(relative.hasPrefix("assets/visionboard/"))
        let final = projectBase.appendingPathComponent(relative)
        XCTAssertEqual(try Data(contentsOf: final), data)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path),
                       "finalize moves, not copies")
    }

    func testFinalizeResolvesNameCollisions() throws {
        let store = makeStore()
        let first = try store.stage(Data("one".utf8), fileName: "vision.png")
        let second = try store.stage(Data("two".utf8), fileName: "vision.png")
        // Staging the same name twice overwrites in staging — collisions
        // matter at the FINAL destination, so finalize one at a time.
        XCTAssertEqual(first, second)

        let relA = try store.finalize(first)
        let stagedAgain = try store.stage(Data("two".utf8), fileName: "vision.png")
        let relB = try store.finalize(stagedAgain)

        XCTAssertEqual(relA, "assets/visionboard/vision.png")
        XCTAssertEqual(relB, "assets/visionboard/vision-1.png")
        XCTAssertEqual(
            try Data(contentsOf: projectBase.appendingPathComponent(relB)),
            Data("two".utf8))
    }

    func testImportExternalCopiesIntoProject() throws {
        let store = makeStore()
        let external = FileManager.default.temporaryDirectory
            .appendingPathComponent("external-\(UUID().uuidString).jpg")
        try Data("jpeg".utf8).write(to: external)
        defer { try? FileManager.default.removeItem(at: external) }

        let relative = try store.importExternal(external)
        XCTAssertTrue(relative.hasPrefix("assets/visionboard/imported_"))
        XCTAssertTrue(relative.hasSuffix(".jpg"), "extension preserved")
        XCTAssertTrue(FileManager.default.fileExists(atPath: external.path),
                      "import copies — the user's file is untouched")
    }

    func testDownloadRemoteUsesInjectedFetchAndStages() async throws {
        let payload = Data("remote-bytes".utf8)
        let store = makeStore(fetchData: { _ in payload })

        let staged = try await store.downloadRemote(
            URL(string: "https://example.com/pic.png")!)
        XCTAssertTrue(store.isStaged(staged))
        XCTAssertEqual(try Data(contentsOf: staged), payload)
    }

    func testDiscardStagingRemovesStagedFilesOnly() throws {
        let store = makeStore()
        let staged = try store.stagePastedPNG(Data("x".utf8))
        let keptRelative = try store.finalize(try store.stage(Data("keep".utf8),
                                                              fileName: "keep.png"))

        store.discardStaging()

        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectBase.appendingPathComponent(keptRelative).path),
            "finalized assets survive a discard")
    }

    // MARK: - Save-time normalization

    func testNormalizedForSavePassesThroughNilAndRelative() async {
        let store = makeStore()
        let nilResult = await store.normalizedForSave(nil)
        XCTAssertNil(nilResult)
        let relResult = await store.normalizedForSave("assets/visionboard/a.png")
        XCTAssertEqual(relResult, "assets/visionboard/a.png")
    }

    func testNormalizedForSaveFinalizesStagedFiles() async throws {
        let store = makeStore()
        let staged = try store.stagePastedPNG(Data("staged".utf8))

        let result = await store.normalizedForSave(staged.path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("assets/visionboard/"))
        XCTAssertEqual(
            try Data(contentsOf: projectBase.appendingPathComponent(result!)),
            Data("staged".utf8))
    }

    func testNormalizedForSaveRelativizesInsideProjectWithoutCopying() async throws {
        let store = makeStore()
        let inside = projectBase.appendingPathComponent("refs/pic.png")
        try FileManager.default.createDirectory(
            at: inside.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: inside)

        let result = await store.normalizedForSave(inside.path)

        XCTAssertEqual(result, "refs/pic.png")
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedDir.path),
                       "no copy was made — the file already lives in the project")
    }

    func testNormalizedForSaveImportsExternalFiles() async throws {
        let store = makeStore()
        let external = FileManager.default.temporaryDirectory
            .appendingPathComponent("ext-\(UUID().uuidString).png")
        try Data("ext".utf8).write(to: external)
        defer { try? FileManager.default.removeItem(at: external) }

        let result = await store.normalizedForSave(external.path)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("assets/visionboard/imported_"))
        XCTAssertEqual(
            try Data(contentsOf: projectBase.appendingPathComponent(result!)),
            Data("ext".utf8))
    }

    func testNormalizedForSaveDownloadsRemote() async throws {
        let store = makeStore(fetchData: { _ in Data("downloaded".utf8) })

        let result = await store.normalizedForSave("https://example.com/mood.png")

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("assets/visionboard/remote_"))
        XCTAssertEqual(
            try Data(contentsOf: projectBase.appendingPathComponent(result!)),
            Data("downloaded".utf8))
    }

    func testNormalizedForSaveKeepsRemotePathWhenDownloadFails() async {
        let store = makeStore()  // fetch throws
        let result = await store.normalizedForSave("https://example.com/gone.png")
        XCTAssertEqual(result, "https://example.com/gone.png",
                       "failure degrades to the placeholder-rendering ref")
    }

    // MARK: - Deletion guard (used by Slice 4)

    func testRemoveAssetRefusesPathsOutsideManagedFolder() throws {
        let store = makeStore()
        XCTAssertThrowsError(try store.removeAsset(relativePath: "script.pdf"))
        XCTAssertThrowsError(
            try store.removeAsset(relativePath: "assets/visionboard/../../script.pdf"),
            "traversal out of the managed folder is refused")
    }

    func testRemoveAssetDeletesManagedFile() throws {
        let store = makeStore()
        let relative = try store.finalize(try store.stage(Data("bye".utf8),
                                                          fileName: "bye.png"))
        try store.removeAsset(relativePath: relative)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectBase.appendingPathComponent(relative).path))
        // Missing files are a no-op, not an error.
        try store.removeAsset(relativePath: relative)
    }
}

@MainActor
final class VisionBoardLifecycleTests: XCTestCase {

    private var projectBase: URL!

    override func setUpWithError() throws {
        projectBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("vb-lifecycle-tests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: projectBase,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: projectBase)
    }

    // MARK: - Ref-count matrix (Slice 4)

    func testUnreferencedImagePathsMatrix() {
        let a = VisionCard(id: "a", imagePath: "assets/visionboard/shared.png")
        let b = VisionCard(id: "b", imagePath: "assets/visionboard/shared.png")
        let c = VisionCard(id: "c", imagePath: "assets/visionboard/solo.png")
        let d = VisionCard(id: "d")

        XCTAssertEqual(VisionBoardAssetStore.unreferencedImagePaths(
            removed: [a], remaining: [b, c, d]), [],
            "a duplicate still references the shared file")
        XCTAssertEqual(VisionBoardAssetStore.unreferencedImagePaths(
            removed: [a, b], remaining: [c, d]),
            ["assets/visionboard/shared.png"],
            "deletable once the LAST reference goes")
        XCTAssertEqual(VisionBoardAssetStore.unreferencedImagePaths(
            removed: [c, d], remaining: [a]),
            ["assets/visionboard/solo.png"])
        XCTAssertEqual(VisionBoardAssetStore.unreferencedImagePaths(
            removed: [d], remaining: []), [])
    }

    func testRemoveCardDeletesOnlyUnreferencedManagedFiles() throws {
        let managed = projectBase.appendingPathComponent("assets/visionboard")
        try FileManager.default.createDirectory(at: managed,
                                                withIntermediateDirectories: true)
        try Data("s".utf8).write(to: managed.appendingPathComponent("shared.png"))
        try Data("o".utf8).write(to: managed.appendingPathComponent("solo.png"))
        let external = FileManager.default.temporaryDirectory
            .appendingPathComponent("user-owned-\(UUID().uuidString).png")
        try Data("mine".utf8).write(to: external)
        defer { try? FileManager.default.removeItem(at: external) }

        let viewModel = VisionBoardViewModel(cards: [
            VisionCard(id: "a", imagePath: "assets/visionboard/shared.png"),
            VisionCard(id: "b", imagePath: "assets/visionboard/shared.png"),
            VisionCard(id: "c", imagePath: "assets/visionboard/solo.png"),
            VisionCard(id: "d", imagePath: external.path),
        ])
        viewModel.configureAssetStore(projectBase: projectBase)
        let exists = { (name: String) in
            FileManager.default.fileExists(
                atPath: managed.appendingPathComponent(name).path)
        }

        viewModel.removeCard("a")
        XCTAssertTrue(exists("shared.png"), "card b still references it")

        viewModel.removeCard("b")
        XCTAssertFalse(exists("shared.png"), "last reference gone")

        viewModel.removeCard("c")
        XCTAssertFalse(exists("solo.png"))

        viewModel.removeCard("d")
        XCTAssertTrue(FileManager.default.fileExists(atPath: external.path),
                      "legacy absolute paths outside the managed folder are never touched")
    }

    // MARK: - Persisted boards (Slice 4)

    func testCreateBoardSlugsDedupesAndPersists() {
        let viewModel = VisionBoardViewModel(cards: [])
        var persisted: [[VisionBoardMeta]] = []
        viewModel.onBoardsChanged = { persisted.append($0) }

        let first = viewModel.createBoard("Mood Two")
        XCTAssertEqual(first, "mood_two")
        XCTAssertEqual(viewModel.currentBoardId, "mood_two")

        let second = viewModel.createBoard("Mood Two")
        XCTAssertEqual(second, "mood_two-2", "deduped, not silently merged")

        XCTAssertEqual(persisted.count, 2)
        XCTAssertEqual(persisted.last?.map(\.id), ["mood_two", "mood_two-2"])
    }

    func testBoardIdsUnionRegistryCardsAndMaster() {
        let viewModel = VisionBoardViewModel(
            cards: [VisionCard(id: "x", boardId: "from_cards")],
            boards: [VisionBoardMeta(id: "empty_board", name: "Empty Board")])
        XCTAssertEqual(viewModel.boardIds, ["empty_board", "from_cards", "master"],
                       "an empty registered board no longer vanishes")
    }
}

@MainActor
final class VisionBoardSavePipelineTests: XCTestCase {

    private var projectBase: URL!

    override func setUpWithError() throws {
        projectBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("vb-save-tests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: projectBase,
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: projectBase)
    }

    func testSaveFinalizesStagedImageBeforeSingleCommit() async throws {
        let viewModel = VisionBoardViewModel(cards: [])
        viewModel.configureAssetStore(projectBase: projectBase)
        let store = viewModel.assetStore!
        let staged = try store.stagePastedPNG(Data("png".utf8))

        var card = VisionCard()
        card.imagePath = staged.path
        viewModel.editingCard = card
        viewModel.showingCardEditor = true

        let committed = expectation(description: "one commit with relative path")
        var commits = 0
        viewModel.onCardsChanged = { cards in
            commits += 1
            XCTAssertEqual(cards.count, 1)
            XCTAssertEqual(cards[0].imagePath?.hasPrefix("assets/visionboard/"),
                           true)
            committed.fulfill()
        }

        viewModel.saveEditedCard()
        XCTAssertNil(viewModel.editingCard)
        XCTAssertFalse(viewModel.showingCardEditor)

        await fulfillment(of: [committed], timeout: 5)
        XCTAssertEqual(commits, 1, "exactly one persistence callback per save")
    }

    func testSaveDoesNotReimportUnchangedExternalPath() async throws {
        let external = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-\(UUID().uuidString).png")
        try Data("legacy".utf8).write(to: external)
        defer { try? FileManager.default.removeItem(at: external) }

        var existing = VisionCard()
        existing.imagePath = external.path
        let viewModel = VisionBoardViewModel(cards: [existing])
        viewModel.configureAssetStore(projectBase: projectBase)

        // Session edits the title only — the image reference is untouched.
        var edited = existing
        edited.title = "renamed"
        viewModel.editingCard = edited

        let committed = expectation(description: "commit")
        viewModel.onCardsChanged = { _ in committed.fulfill() }
        viewModel.saveEditedCard()
        await fulfillment(of: [committed], timeout: 5)

        XCTAssertEqual(viewModel.cards[0].imagePath, external.path,
                       "unchanged external path stays put — no duplicate import")
        let managed = projectBase
            .appendingPathComponent(VisionBoardAssetStore.assetSubfolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managed.path))
    }

    func testSaveRelativizesUnchangedInsideProjectPath() async throws {
        let inside = projectBase.appendingPathComponent("refs/pic.png")
        try FileManager.default.createDirectory(
            at: inside.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: inside)

        var existing = VisionCard()
        existing.imagePath = inside.path
        let viewModel = VisionBoardViewModel(cards: [existing])
        viewModel.configureAssetStore(projectBase: projectBase)

        viewModel.editingCard = existing
        let committed = expectation(description: "commit")
        viewModel.onCardsChanged = { _ in committed.fulfill() }
        viewModel.saveEditedCard()
        await fulfillment(of: [committed], timeout: 5)

        XCTAssertEqual(viewModel.cards[0].imagePath, "refs/pic.png",
                       "opportunistic migration to relative on save")
    }

    func testSaveWithoutStoreCommitsSynchronously() {
        let viewModel = VisionBoardViewModel(cards: [])
        var card = VisionCard()
        card.imagePath = "/somewhere/pic.png"
        viewModel.editingCard = card

        var commits = 0
        viewModel.onCardsChanged = { _ in commits += 1 }
        viewModel.saveEditedCard()

        XCTAssertEqual(commits, 1, "no store → legacy synchronous commit")
        XCTAssertEqual(viewModel.cards[0].imagePath, "/somewhere/pic.png")
    }

    func testDismissWithoutSaveDiscardsStagingAndTouchesNoAssets() throws {
        let viewModel = VisionBoardViewModel(cards: [])
        viewModel.configureAssetStore(projectBase: projectBase)
        let store = viewModel.assetStore!
        let staged = try store.stagePastedPNG(Data("orphan?".utf8))

        var card = VisionCard()
        card.imagePath = staged.path
        viewModel.editingCard = card
        viewModel.showingCardEditor = true

        var commits = 0
        viewModel.onCardsChanged = { _ in commits += 1 }

        // Cancel / Esc / close: the sheet's onDismiss fires with the
        // session still open.
        viewModel.editorDismissed()

        XCTAssertNil(viewModel.editingCard)
        XCTAssertEqual(commits, 0, "cancel persists nothing")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path),
                       "staged file reaped")
        let managed = projectBase
            .appendingPathComponent(VisionBoardAssetStore.assetSubfolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managed.path),
                       "nothing ever landed in the project's assets")
    }

    func testDismissAfterSaveIsANoOp() {
        let viewModel = VisionBoardViewModel(cards: [])
        viewModel.configureAssetStore(projectBase: projectBase)

        // After Save, editingCard is nil by the time onDismiss fires; the
        // dismissal must not discard staging out from under the save Task.
        viewModel.editingCard = nil
        viewModel.editorDismissed()  // must not crash or discard
        XCTAssertNotNil(viewModel.assetStore)
    }

    func testConfigureAssetStoreIsIdempotentPerBase() {
        let viewModel = VisionBoardViewModel(cards: [])
        viewModel.configureAssetStore(projectBase: projectBase)
        let first = viewModel.assetStore
        viewModel.configureAssetStore(projectBase: projectBase)
        XCTAssertEqual(viewModel.assetStore?.projectBase, first?.projectBase)

        viewModel.configureAssetStore(projectBase: nil)
        XCTAssertNil(viewModel.assetStore)
    }
}
