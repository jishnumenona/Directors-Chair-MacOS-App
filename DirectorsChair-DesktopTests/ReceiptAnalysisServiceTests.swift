// ReceiptAnalysisServiceTests.swift
//
// WS6.4: the receipt-response parser is pure and unit-tested (it was an
// untested 115-line closure inside the production container view).

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairProduction

final class ReceiptAnalysisServiceTests: XCTestCase {

    func testParsesMultiItemReceipt() {
        let json = """
        {"vendor": "Grip Co", "date": "2026-07-01",
         "items": [
            {"description": "Cables", "amount": 12.5, "category": "Equipment"},
            {"description": "Tape", "amount": 4, "category": "Art"}
         ]}
        """
        let results = ReceiptAnalysisService.parse(json)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].vendor, "Grip Co")
        XCTAssertEqual(results[0].date, "2026-07-01", "vendor/date shared across items")
        XCTAssertEqual(results[0].amount, 12.5)
        XCTAssertEqual(results[1].amount, 4.0, "Int amount coerced to Double")
        XCTAssertEqual(results[1].category, "Art")
    }

    func testStripsMarkdownFences() {
        let fenced = """
        ```json
        {"vendor": "Cafe", "date": "2026-07-02", "items": [{"description": "Lunch", "amount": "18.75", "category": "Catering"}]}
        ```
        """
        let results = ReceiptAnalysisService.parse(fenced)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].amount, 18.75, "String amount coerced")
    }

    func testMalformedResponsesReturnEmpty() {
        XCTAssertTrue(ReceiptAnalysisService.parse("not json at all").isEmpty)
        XCTAssertTrue(ReceiptAnalysisService.parse("{\"vendor\": \"X\"}").isEmpty, "missing items array")
        XCTAssertTrue(ReceiptAnalysisService.parse("{\"items\": []}").isEmpty, "empty items array")
    }

    func testPromptIncludesCategories() {
        let prompt = ReceiptAnalysisService.buildPrompt(categoryNames: "Catering, Equipment")
        XCTAssertTrue(prompt.contains("Catering, Equipment"))
        XCTAssertTrue(prompt.contains("Return ONLY valid JSON"))
    }
}
