// DirectorsChairProduction/Tests/DirectorsChairProductionTests/BudgetExportServiceTests.swift
//
// WS8.7: the accounting export formats are pure functions with tests —
// including the CSV-injection guard.

import XCTest
@testable import DirectorsChairProduction
@testable import DirectorsChairCore

final class BudgetExportServiceTests: XCTestCase {

    private func expense(description: String = "Lunch", vendor: String = "Cafe",
                         amount: Double = 12.5, category: String = "Catering",
                         accountCode: String = "410") -> Expense {
        var e = Expense(date: "2026-07-01", category: category, amount: amount, description: description)
        e.vendor = vendor
        e.accountCode = accountCode
        return e
    }

    // MARK: - Escaping + injection guard

    func testEscapeCSVQuotesSpecials() {
        XCTAssertEqual(BudgetExportService.escapeCSV("plain"), "plain")
        XCTAssertEqual(BudgetExportService.escapeCSV("a,b"), "\"a,b\"")
        XCTAssertEqual(BudgetExportService.escapeCSV("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testEscapeCSVNeutralisesFormulaInjection() {
        // A value like =HYPERLINK(...) must never reach a spreadsheet as a formula.
        XCTAssertEqual(BudgetExportService.escapeCSV("=SUM(A1:A9)"), "'=SUM(A1:A9)")
        XCTAssertEqual(BudgetExportService.escapeCSV("+123"), "'+123")
        XCTAssertEqual(BudgetExportService.escapeCSV("@cmd"), "'@cmd")
        XCTAssertEqual(BudgetExportService.escapeCSV("-2+3"), "'-2+3")
    }

    func testXMLEscape() {
        XCTAssertEqual(BudgetExportService.xmlEscape("a<b>&\"c'"), "a&lt;b&gt;&amp;&quot;c&apos;")
    }

    // MARK: - CSV

    func testCSVContainsAllSectionsAndEscapedData() {
        let csv = BudgetExportService.csv(
            categories: [BudgetCategory(name: "Art, Dept", allocated: 100, spent: 40)],
            expenses: [expense(description: "=evil()")],
            purchaseOrders: [],
            costReport: [],
            castMembers: [],
            crewMembers: [],
            totalShootDays: 3
        )
        XCTAssertTrue(csv.contains("=== BUDGET SUMMARY ==="))
        XCTAssertTrue(csv.contains("=== EXPENSES ==="))
        XCTAssertTrue(csv.contains("=== PURCHASE ORDERS ==="))
        XCTAssertTrue(csv.contains("=== PAYROLL ==="))
        XCTAssertTrue(csv.contains("=== COST REPORT ==="))
        XCTAssertTrue(csv.contains("\"Art, Dept\""), "comma-containing name is quoted")
        XCTAssertTrue(csv.contains("'=evil()"), "formula injection neutralised")
        XCTAssertFalse(csv.contains(",=evil()"), "no bare formula cell")
    }

    // MARK: - Xero

    func testXeroCSVDefaultsAndNumbering() {
        let csv = BudgetExportService.xeroCSV(expenses: [
            expense(vendor: "", accountCode: ""),
            expense(vendor: "Grip Co", accountCode: "512"),
        ])
        let rows = csv.split(separator: "\n")
        XCTAssertEqual(rows.count, 3, "header + 2 rows")
        XCTAssertTrue(rows[1].hasPrefix("Production,DC-EXP-0001,"), "empty vendor defaults to Production")
        XCTAssertTrue(rows[1].contains(",400,"), "empty account code defaults to 400")
        XCTAssertTrue(rows[2].hasPrefix("Grip Co,DC-EXP-0002,"))
    }

    // MARK: - Tally

    func testTallyXMLIsWellFormedAndEscaped() throws {
        let xml = BudgetExportService.tallyXML(expenses: [expense(description: "Cables <& tape>")])
        XCTAssertTrue(xml.contains("<NARRATION>Cables &lt;&amp; tape&gt;</NARRATION>"))
        XCTAssertTrue(xml.contains("<VOUCHERNUMBER>DC-PAY-0001</VOUCHERNUMBER>"))
        XCTAssertTrue(xml.contains("<DATE>20260701</DATE>"), "dashes stripped from date")
        // Must parse as XML
        let parser = XMLParser(data: Data(xml.utf8))
        XCTAssertTrue(parser.parse(), "Tally export must be well-formed XML")
    }
}
