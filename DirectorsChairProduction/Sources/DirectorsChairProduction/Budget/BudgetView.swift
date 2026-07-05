// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetView.swift
//
// Accounting View - Comprehensive Production Accounting
// 6 sub-tabs: Overview, Top Sheet, Cost Report, Expenses, Purchase Orders, Payroll

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import DirectorsChairCore

// MARK: - Accounting Display Mode

public enum AccountingDisplayMode: String, CaseIterable {
    case overview = "Overview"
    case topSheet = "Top Sheet"
    case costReport = "Cost Report"
    case expenses = "Expenses"
    case purchaseOrders = "Purchase Orders"
    case payroll = "Payroll"
    case export = "Export"
}

// MARK: - Budget View (Accounting)

public struct BudgetView: View {
    @ObservedObject var viewModel: BudgetViewModel

    @State var displayMode: AccountingDisplayMode = .overview
    @State var selectedCategory: BudgetCategory?
    @State var selectedExpense: Expense?
    @State var selectedPO: PurchaseOrder?
    @State var showingAddCategorySheet = false
    @State var showingEditCategorySheet = false
    @State var showingAddExpenseSheet = false
    @State var showingEditExpenseSheet = false
    @State var showingAddPOSheet = false
    @State var showingEditPOSheet = false
    @State var expenseDeptFilter = "All"
    @State var poStatusFilter = "All"
    @State var exportStatus: String? = nil
    @State var isExporting = false
    @State var exportDatePreset = "allTime"
    @State var exportCustomDateFrom = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State var exportCustomDateTo = Date()
    @State var exportSelectedDepartments: Set<String> = []
    @State var exportSelectedGroups: Set<String> = []
    @State var exportSelectedExpenseStatuses: Set<String> = []
    @State var exportSelectedPOStatuses: Set<String> = []
    @State var exportSelectedPaymentMethods: Set<String> = []
    @State var exportMinAmount = ""
    @State var exportMaxAmount = ""

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            accountingActionBar

            switch displayMode {
            case .overview:
                accountingOverviewView
            case .topSheet:
                topSheetView
            case .costReport:
                costReportView
            case .expenses:
                expensesView
            case .purchaseOrders:
                purchaseOrdersView
            case .payroll:
                payrollView
            case .export:
                exportView
            }
        }
        .onAppear {
            viewModel.ensureDefaultCategories()
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            CategoryEditorSheet(viewModel: viewModel, category: nil)
        }
        .sheet(isPresented: $showingEditCategorySheet) {
            if let category = selectedCategory {
                CategoryEditorSheet(viewModel: viewModel, category: category)
            }
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            ExpenseEditorSheet(viewModel: viewModel, expense: nil)
        }
        .sheet(isPresented: $showingEditExpenseSheet) {
            if let expense = selectedExpense {
                ExpenseEditorSheet(viewModel: viewModel, expense: expense)
            }
        }
        .sheet(isPresented: $showingAddPOSheet) {
            POEditorSheet(viewModel: viewModel, po: nil)
        }
        .sheet(isPresented: $showingEditPOSheet) {
            if let po = selectedPO {
                POEditorSheet(viewModel: viewModel, po: po)
            }
        }
    }
}
