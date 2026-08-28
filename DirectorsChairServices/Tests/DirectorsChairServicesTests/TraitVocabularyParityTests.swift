// TraitVocabularyParityTests.swift
//
// DC-0078: the analyzer's trait list and the deck's facet grid are the
// Core vocabulary, not copies of it.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairServices

final class TraitVocabularyParityTests: XCTestCase {

    func testAnalyzerTraitsAreTheVocabulary() {
        XCTAssertEqual(CharacterTraits.allTraits, TraitVocabulary.facets)
        for category in TraitVocabulary.categories {
            XCTAssertEqual(CharacterTraits.categories[category.name], category.facets)
        }
    }

    func testDeckFacetsAreTheVocabularyWithTheirColours() {
        XCTAssertEqual(ProjectOverviewBuilder.oceanFacets.map(\.category), TraitVocabulary.categories.map(\.name))
        XCTAssertEqual(ProjectOverviewBuilder.oceanFacets.flatMap(\.facets), TraitVocabulary.facets)
        XCTAssertEqual(ProjectOverviewBuilder.oceanFacets.map(\.color),
                       ["#9B59B6", "#3498DB", "#E67E22", "#27AE60", "#E74C3C"])
    }
}
