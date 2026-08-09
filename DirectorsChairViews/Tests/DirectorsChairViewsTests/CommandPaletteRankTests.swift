// DirectorsChairViewsTests/CommandPaletteRankTests.swift
//
// The palette's ranking IS its usefulness: a palette that surfaces the
// wrong command teaches the user to stop pressing ⌘K. These pin the
// shape professionals expect — word-initials work, prefixes win,
// nonsense returns nothing, and an empty query shows the catalog's own
// order (navigation first, by construction).

import XCTest
@testable import DirectorsChairViews

final class CommandPaletteRankTests: XCTestCase {

    private func entry(_ id: String, _ title: String,
                       subtitle: String? = nil) -> PaletteEntry {
        PaletteEntry(id: id, title: title, subtitle: subtitle,
                     systemImage: "circle", category: .command)
    }

    func testWordInitialsFindMultiWordCommands() {
        let castCrew = entry("a", "Production: Cast & Crew")
        XCTAssertNotNil(PaletteRank.score(query: "cc", entry: castCrew),
                        "word initials must match — that is how palettes "
                        + "are actually typed")
        XCTAssertNotNil(PaletteRank.score(query: "pcc", entry: castCrew))
    }

    func testPrefixBeatsScatteredMatch() {
        let scenes = entry("scenes", "Scenes")
        let snapshots = entry("snap", "Project Snapshots…")
        let scenesScore = PaletteRank.score(query: "scen", entry: scenes)!
        let scatterScore = PaletteRank.score(query: "scen", entry: snapshots)
        if let scatterScore {
            XCTAssertGreaterThan(scenesScore, scatterScore,
                "typing a title's own prefix must rank that title first")
        }
    }

    func testNonMatchesReturnNilNotZero() {
        XCTAssertNil(PaletteRank.score(query: "xyz",
                                       entry: entry("a", "Go to Scenes")),
                     "letters that don't appear in order are not a match")
        XCTAssertNil(PaletteRank.score(query: "scenesx",
                                       entry: entry("a", "Scenes")),
                     "a query longer than its match must not pass")
    }

    func testSubtitleMatchesAtReducedWeight() {
        let byTitle = entry("t", "Rename Project")
        let bySubtitle = entry("s", "Update project metadata",
                               subtitle: "Rename the project or director")
        let titleScore = PaletteRank.score(query: "rename", entry: byTitle)!
        let subtitleScore = PaletteRank.score(query: "rename", entry: bySubtitle)!
        XCTAssertGreaterThan(titleScore, subtitleScore,
            "a title hit must outrank a summary hit, but the summary hit "
            + "must still surface — an action is findable by what it does")
    }

    func testEmptyQueryKeepsCatalogOrderAndLimit() {
        let entries = (0..<30).map { entry("e\($0)", "Entry \($0)") }
        let ranked = PaletteRank.rank(entries: entries, query: "  ", limit: 12)
        XCTAssertEqual(ranked.map(\.id),
                       entries.prefix(12).map(\.id),
                       "an empty palette shows the catalog's own order — "
                       + "the caller puts navigation first for a reason")
    }

    func testRankFiltersAndOrdersAcrossTheCatalog() {
        let entries = [
            entry("nav.scenes", "Go to Scenes"),
            entry("nav.script", "Go to Script"),
            entry("cmd.save", "Save Project"),
            entry("action.gen", "Generate scene image",
                  subtitle: "Renders a still for a scene"),
        ]
        let ranked = PaletteRank.rank(entries: entries, query: "scr")
        XCTAssertEqual(ranked.map(\.id), ["nav.script"],
                       "'scr' is a subsequence of Script alone — 'sc' "
                       + "would also catch Save Proje-c-t, which is "
                       + "correct fuzzy behaviour, so the filter claim "
                       + "is made with a query that discriminates")
    }
}
