// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetExportService.swift
//
// WS8.7 — pure, testable accounting export builders, extracted from
// BudgetView so the formats are unit-tested and the view only handles the
// save panel. Adds a CSV-injection guard: values starting with = + - @ are
// prefixed with ' so spreadsheet apps never execute them as formulas.

import Foundation
import DirectorsChairCore

public enum BudgetExportService {

    // MARK: - Escaping

    /// CSV-escape a value AND neutralise spreadsheet formula injection.
    static func escapeCSV(_ value: String) -> String {
        var v = value
        if let first = v.first, "=+-@".contains(first) {
            v = "'" + v
        }
        if v.contains(",") || v.contains("\"") || v.contains("\n") {
            return "\"\(v.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return v
    }

    static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func money(_ v: Double) -> String { String(format: "%.2f", v) }

    // MARK: - Full accounting CSV

    public static func csv(categories: [BudgetCategory],
                           expenses: [Expense],
                           purchaseOrders: [PurchaseOrder],
                           costReport: [CostReportRow],
                           castMembers: [CastMember],
                           crewMembers: [CrewMember],
                           totalShootDays: Int) -> String {
        var lines: [String] = []

        lines.append("=== BUDGET SUMMARY ===")
        lines.append("AccountCode,Category,Group,Allocated,Spent,Remaining,Variance%")
        for cat in categories {
            let variancePct = cat.allocated > 0 ? String(format: "%.1f", ((cat.spent - cat.allocated) / cat.allocated) * 100) : "0.0"
            lines.append("\(escapeCSV(cat.accountCode)),\(escapeCSV(cat.name)),\(escapeCSV(cat.categoryGroup)),\(money(cat.allocated)),\(money(cat.spent)),\(money(cat.remaining)),\(variancePct)")
        }
        lines.append("")

        lines.append("=== EXPENSES ===")
        lines.append("Date,Description,Category,Amount,Vendor,Department,AccountCode,PaymentMethod,Status")
        for exp in expenses {
            lines.append("\(escapeCSV(exp.date)),\(escapeCSV(exp.description)),\(escapeCSV(exp.category)),\(money(exp.amount)),\(escapeCSV(exp.vendor)),\(escapeCSV(exp.department)),\(escapeCSV(exp.accountCode)),\(escapeCSV(exp.paymentMethod)),\(escapeCSV(exp.status))")
        }
        lines.append("")

        lines.append("=== PURCHASE ORDERS ===")
        lines.append("PONumber,Vendor,Department,AccountCode,Description,Amount,Status,DateCreated,ApprovedBy")
        for po in purchaseOrders {
            lines.append("\(escapeCSV(po.poNumber)),\(escapeCSV(po.vendor)),\(escapeCSV(po.department)),\(escapeCSV(po.accountCode)),\(escapeCSV(po.description)),\(money(po.amount)),\(escapeCSV(po.status)),\(escapeCSV(po.dateCreated)),\(escapeCSV(po.approvedBy))")
        }
        lines.append("")

        lines.append("=== PAYROLL ===")
        lines.append("Name,Role,Type,DailyRate,PaymentType,ProjectedTotal")
        for cast in castMembers {
            let projected = cast.paymentType == "One Time" ? cast.oneTimePayment : cast.dailyRate * Double(max(totalShootDays, 1))
            lines.append("\(escapeCSV(cast.actorName)),\(escapeCSV(cast.characterName)),Cast,\(money(cast.dailyRate)),\(escapeCSV(cast.paymentType)),\(money(projected))")
        }
        for crew in crewMembers {
            let projected = crew.paymentType == "One Time" ? crew.oneTimePayment : (crew.dailyRate + crew.kitFee) * Double(max(totalShootDays, 1))
            lines.append("\(escapeCSV(crew.name)),\(escapeCSV(crew.role)),Crew,\(money(crew.dailyRate)),\(escapeCSV(crew.paymentType)),\(money(projected))")
        }
        lines.append("")

        lines.append("=== COST REPORT ===")
        lines.append("AccountCode,Description,ThisWeek,ToDate,Committed,Total,ETC,EFC,Budget,Variance")
        for row in costReport {
            lines.append("\(escapeCSV(row.accountCode)),\(escapeCSV(row.description)),\(money(row.thisWeek)),\(money(row.toDate)),\(money(row.committed)),\(money(row.total)),\(money(row.etc)),\(money(row.efc)),\(money(row.budget)),\(money(row.variance))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Xero import CSV

    public static func xeroCSV(expenses: [Expense]) -> String {
        var lines: [String] = []
        lines.append("ContactName,InvoiceNumber,InvoiceDate,DueDate,Description,Quantity,UnitAmount,AccountCode,TaxType")
        for (index, exp) in expenses.enumerated() {
            let invoiceNumber = String(format: "DC-EXP-%04d", index + 1)
            let contactName = exp.vendor.isEmpty ? "Production" : exp.vendor
            let acctCode = exp.accountCode.isEmpty ? "400" : exp.accountCode
            lines.append("\(escapeCSV(contactName)),\(escapeCSV(invoiceNumber)),\(escapeCSV(exp.date)),\(escapeCSV(exp.date)),\(escapeCSV(exp.description)),1,\(money(exp.amount)),\(escapeCSV(acctCode)),Tax Exempt")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Tally import XML

    public static func tallyXML(expenses: [Expense]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ENVELOPE>
            <HEADER>
                <TALLYREQUEST>Import Data</TALLYREQUEST>
            </HEADER>
            <BODY>
                <IMPORTDATA>
                    <REQUESTDESC>
                        <REPORTNAME>Vouchers</REPORTNAME>
                    </REQUESTDESC>
                    <REQUESTDATA>

        """

        for (index, exp) in expenses.enumerated() {
            let tallyDate = exp.date.replacingOccurrences(of: "-", with: "")
            let category = exp.category.isEmpty ? "Production Expenses" : exp.category
            let voucherNum = String(format: "DC-PAY-%04d", index + 1)

            xml += """
                        <TALLYMESSAGE xmlns:UDF="TallyUDF">
                            <VOUCHER VCHTYPE="Payment" ACTION="Create">
                                <DATE>\(tallyDate)</DATE>
                                <VOUCHERTYPENAME>Payment</VOUCHERTYPENAME>
                                <VOUCHERNUMBER>\(voucherNum)</VOUCHERNUMBER>
                                <NARRATION>\(xmlEscape(exp.description))</NARRATION>
                                <ALLLEDGERENTRIES.LIST>
                                    <LEDGERNAME>\(xmlEscape(category))</LEDGERNAME>
                                    <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                                    <AMOUNT>-\(money(exp.amount))</AMOUNT>
                                </ALLLEDGERENTRIES.LIST>
                                <ALLLEDGERENTRIES.LIST>
                                    <LEDGERNAME>Cash</LEDGERNAME>
                                    <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                                    <AMOUNT>\(money(exp.amount))</AMOUNT>
                                </ALLLEDGERENTRIES.LIST>
                            </VOUCHER>
                        </TALLYMESSAGE>

            """
        }

        xml += """
                    </REQUESTDATA>
                </IMPORTDATA>
            </BODY>
        </ENVELOPE>
        """
        return xml
    }
}
