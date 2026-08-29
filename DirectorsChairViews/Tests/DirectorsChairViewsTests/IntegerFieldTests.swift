// IntegerFieldTests.swift
//
// 2026-08-29: the Age badge could not be cleared or retyped. The field's
// rules — digits only, commit only whole numbers in range, keep partial
// entries as typed — are pinned here.

import XCTest
@testable import DirectorsChairViews

final class IntegerFieldTests: XCTestCase {

    func testOnlyDigitsGetThrough() {
        XCTAssertEqual(IntegerField.sanitized("3a5"), "35")
        XCTAssertEqual(IntegerField.sanitized(" 42 "), "42")
        XCTAssertEqual(IntegerField.sanitized("-7"), "7")
        XCTAssertEqual(IntegerField.sanitized(""), "")
    }

    func testAnEmptyOrPartialEntryCommitsNothing() {
        XCTAssertNil(IntegerField.accepted("", in: 0...150), "clearing the field must not snap back to the old value")
        XCTAssertNil(IntegerField.accepted("200", in: 0...150), "out of range stays visible, uncommitted")
        XCTAssertEqual(IntegerField.accepted("3", in: 0...150), 3, "every whole number in range commits as typed")
        XCTAssertEqual(IntegerField.accepted("35", in: 0...150), 35)
        XCTAssertEqual(IntegerField.accepted("0", in: 0...150), 0)
    }
}
