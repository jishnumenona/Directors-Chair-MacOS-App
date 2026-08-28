// TraitVocabularyViewsTests.swift
//
// DC-0078: the Personality tab's categories read the Core vocabulary.

import XCTest
import DirectorsChairCore
@testable import DirectorsChairViews

final class TraitVocabularyViewsTests: XCTestCase {

    func testTabCategoriesAreTheVocabulary() {
        XCTAssertEqual(TraitCategory.allCases.map(\.displayName), TraitVocabulary.categories.map(\.name))
        XCTAssertEqual(TraitCategory.allCases.flatMap(\.traits), TraitVocabulary.facets)
    }
}
