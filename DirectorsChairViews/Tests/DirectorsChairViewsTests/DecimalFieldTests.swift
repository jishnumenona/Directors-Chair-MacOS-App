// DecimalFieldTests.swift — the decimal field's rules (2026-08-29, with IntegerField).

import XCTest
@testable import DirectorsChairViews

final class DecimalFieldTests: XCTestCase {

    func testDigitsAndOnePointGetThrough() {
        XCTAssertEqual(DecimalField.sanitized("1.75"), "1.75")
        XCTAssertEqual(DecimalField.sanitized("1,75"), "1.75", "a comma is a decimal point")
        XCTAssertEqual(DecimalField.sanitized("1.7.5"), "1.75", "only the first point survives")
        XCTAssertEqual(DecimalField.sanitized("17cm"), "17")
        XCTAssertEqual(DecimalField.sanitized(""), "")
    }

    func testPartialEntriesCommitNothingAndValuesInRangeCommit() {
        XCTAssertNil(DecimalField.accepted("", in: 0...300))
        XCTAssertNil(DecimalField.accepted(".", in: 0...300))
        XCTAssertNil(DecimalField.accepted("500", in: 0...300), "out of range stays visible, uncommitted")
        XCTAssertEqual(DecimalField.accepted("17.", in: 0...300), 17, "a trailing point is still the number so far")
        XCTAssertEqual(DecimalField.accepted("172.5", in: 0...300), 172.5)
    }

    func testModelValuesDisplayCleanly() {
        XCTAssertEqual(DecimalField.display(nil), "")
        XCTAssertEqual(DecimalField.display(170), "170")
        XCTAssertEqual(DecimalField.display(65.5), "65.5")
        XCTAssertEqual(DecimalField.display(1.25), "1.25")
    }
}
