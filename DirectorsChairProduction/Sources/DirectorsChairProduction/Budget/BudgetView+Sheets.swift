//
// BudgetView+Sheets.swift
//
// Extracted from BudgetView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import DirectorsChairCore


// MARK: - Expense List Row

struct ExpenseListRow: View {
    let expense: Expense
    var isSelected: Bool = false
    @State var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(expense.date)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(expense.category)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.15))
                )
                .foregroundColor(.blue)

            if !expense.department.isEmpty {
                Text(expense.department)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple.opacity(0.15))
                    )
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(expense.description)
                    .font(.system(size: 11))
                    .lineLimit(1)
                if !expense.vendor.isEmpty {
                    Text(expense.vendor)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Receipt indicator
            if let receiptPath = expense.receiptPath, !receiptPath.isEmpty {
                Image(systemName: "paperclip")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Payment method badge
            if !expense.paymentMethod.isEmpty && expense.paymentMethod != "Card" {
                Text(expense.paymentMethod)
                    .font(.system(size: 8, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .foregroundColor(.secondary)
            }

            Text(formatCurrency(expense.amount))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - PO List Row

struct POListRow: View {
    let po: PurchaseOrder
    var isSelected: Bool = false
    @State var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(po.poNumber)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.accentColor)

            Text(po.vendor)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Text(po.status)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor(po.status).opacity(0.2))
                )
                .foregroundColor(statusColor(po.status))

            Text(formatCurrency(po.amount))
                .font(.system(size: 12, weight: .bold, design: .rounded))

            Text(po.dateCreated)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 70)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "Draft": return .gray
        case "Approved": return .blue
        case "Committed": return .purple
        case "Paid": return .green
        case "Cancelled": return .red
        default: return .gray
        }
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Category Editor Sheet

struct CategoryEditorSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let category: BudgetCategory?

    @Environment(\.dismiss) private var dismiss

    @State var name = ""
    @State var allocated: Double = 0
    @State var spent: Double = 0
    @State var description = ""
    @State var accountCode = ""
    @State var categoryGroup = "BTL"

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: category == nil ? "Add Category" : "Edit Category",
                canSave: !name.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    ProductionCard(icon: "folder", title: "CATEGORY INFORMATION") {
                        VStack(spacing: 10) {
                            StyledTextField("Category Name", text: $name)
                            StyledTextField("Description", text: $description)
                            StyledTextField("Account Code (e.g. 3300)", text: $accountCode)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("CATEGORY GROUP")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.2)
                                HStack(spacing: 6) {
                                    ForEach(["ATL", "BTL", "Post", "Other"], id: \.self) { group in
                                        ProductionChip(group, selected: categoryGroup == group) {
                                            categoryGroup = group
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "dollarsign.circle", title: "BUDGET") {
                        VStack(spacing: 10) {
                            StyledNumberField("Allocated Amount", value: $allocated)
                            StyledNumberField("Spent Amount", value: $spent)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let category = category {
                name = category.name
                allocated = category.allocated
                spent = category.spent
                description = category.description
                accountCode = category.accountCode
                categoryGroup = category.categoryGroup.isEmpty ? "BTL" : category.categoryGroup
            }
        }
    }

    func save() {
        // Preserve the edited category's stable id so updateCategory can find it
        // even when the name changed (a new id here would make the rename a no-op).
        let newCategory = BudgetCategory(
            id: category?.id ?? UUID().uuidString,
            name: name,
            allocated: allocated,
            spent: spent,
            description: description,
            isCustom: category?.isCustom ?? true,
            accountCode: accountCode,
            categoryGroup: categoryGroup
        )

        if category != nil {
            viewModel.updateCategory(newCategory)
        } else {
            viewModel.addCategory(newCategory)
        }
        dismiss()
    }
}

// MARK: - Expense Editor Sheet

struct ExpenseEditorSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let expense: Expense?

    @Environment(\.dismiss) private var dismiss

    @State var date = Date()
    @State var category = ""
    @State var amount: Double = 0
    @State var description = ""
    @State var vendor = ""
    @State var department = ""
    @State var accountCode = ""
    @State var paymentMethod = "Card"
    @State var status = "Pending"
    @State var isQualifyingExpense = false
    @State var receiptPath: String = ""
    @State var receiptPreviewImage: NSImage? = nil
    @State var addedBy = ""
    @State var isAnalyzing: Bool = false
    @State var analysisError: String? = nil
    @State var analysisSuccess: String? = nil

    // Multi-item receipt state
    @State var multiItemResults: [ReceiptAnalysisResult] = []
    @State var showingMultiItemAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: expense == nil ? "Add Expense" : "Edit Expense",
                canSave: !category.isEmpty && !description.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    // MARK: Left Column — Receipt + Category
                    VStack(spacing: 16) {
                        // Receipt card
                        ProductionCard(icon: "doc.richtext", title: "RECEIPT") {
                            VStack(spacing: 10) {
                                if receiptPath.isEmpty {
                                    Button {
                                        attachReceipt()
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "doc.badge.plus")
                                                .font(.system(size: 28))
                                                .foregroundColor(.secondary)
                                            Text("Attach Receipt")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(Color(nsColor: .quaternarySystemFill))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    // Thumbnail
                                    if let preview = receiptPreviewImage {
                                        Image(nsImage: preview)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity)
                                            .frame(maxHeight: 140)
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                                            )
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(nsColor: .quaternarySystemFill))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 100)
                                            .overlay(
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.secondary)
                                            )
                                    }

                                    Text(URL(fileURLWithPath: receiptPath).lastPathComponent)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        Button {
                                            analysisError = nil
                                            analysisSuccess = nil
                                            analyzeReceipt()
                                        } label: {
                                            HStack(spacing: 4) {
                                                if isAnalyzing {
                                                    ProgressView()
                                                        .controlSize(.mini)
                                                        .scaleEffect(0.7)
                                                }
                                                Label("Analyze", systemImage: "sparkles")
                                                    .font(.system(size: 10))
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.mini)
                                        .disabled(isAnalyzing || viewModel.onAnalyzeReceipt == nil)

                                        Button {
                                            receiptPath = ""
                                            receiptPreviewImage = nil
                                            analysisError = nil
                                            analysisSuccess = nil
                                        } label: {
                                            Label("Remove", systemImage: "xmark")
                                                .font(.system(size: 10))
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }

                                    if let error = analysisError {
                                        Text(error)
                                            .font(.system(size: 10))
                                            .foregroundColor(.red)
                                            .lineLimit(2)
                                    }

                                    if let success = analysisSuccess {
                                        Text(success)
                                            .font(.system(size: 10))
                                            .foregroundColor(.green)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }

                        // Category card
                        ProductionCard(icon: "tag", title: "CATEGORY") {
                            VStack(alignment: .leading, spacing: 6) {
                                if viewModel.budget.categories.isEmpty {
                                    Text("No categories — add one first")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                        ForEach(viewModel.budget.categories, id: \.name) { cat in
                                            ProductionChip(cat.name, selected: category == cat.name) {
                                                category = cat.name
                                                if accountCode.isEmpty {
                                                    accountCode = cat.accountCode
                                                }
                                                if department.isEmpty {
                                                    department = cat.name
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 240)

                    // MARK: Right Column — Details + Amount & Payment
                    VStack(spacing: 16) {
                        ProductionCard(icon: "receipt", title: "EXPENSE DETAILS") {
                            VStack(spacing: 12) {
                                DatePicker("Date", selection: $date, displayedComponents: [.date])
                                    .font(.system(size: 12))

                                StyledTextField("Description", text: $description)
                                StyledTextField("Vendor", text: $vendor)
                                StyledTextField("Added By", text: $addedBy)

                                HStack(spacing: 10) {
                                    StyledTextField("Department", text: $department)
                                    StyledTextField("Account Code", text: $accountCode)
                                }
                            }
                        }

                        ProductionCard(icon: "dollarsign.circle", title: "AMOUNT & PAYMENT") {
                            VStack(spacing: 10) {
                                StyledNumberField("Amount", value: $amount)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("PAYMENT METHOD")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.2)
                                    HStack(spacing: 6) {
                                        ForEach(["Card", "Check", "PettyCash", "Wire", "PO"], id: \.self) { method in
                                            ProductionChip(method, selected: paymentMethod == method) {
                                                paymentMethod = method
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("STATUS")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.2)
                                    HStack(spacing: 6) {
                                        ForEach(["Pending", "Approved", "Paid"], id: \.self) { s in
                                            ProductionChip(s, selected: status == s) {
                                                status = s
                                            }
                                        }
                                    }
                                }

                                Toggle("Tax Qualifying Expense", isOn: $isQualifyingExpense)
                                    .font(.system(size: 11))
                                    .toggleStyle(.checkbox)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 680, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let expense = expense {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let parsedDate = formatter.date(from: expense.date) {
                    date = parsedDate
                }
                category = expense.category
                amount = expense.amount
                description = expense.description
                vendor = expense.vendor
                department = expense.department
                accountCode = expense.accountCode
                paymentMethod = expense.paymentMethod
                status = expense.status
                isQualifyingExpense = expense.isQualifyingExpense
                addedBy = expense.addedBy
                receiptPath = expense.receiptPath ?? ""
                loadReceiptPreview()
            } else {
                // Pre-fill defaults for new expense
                department = viewModel.defaultDepartment
                accountCode = viewModel.defaultAccountCode
            }
        }
        .alert("Multiple Items Detected", isPresented: $showingMultiItemAlert) {
            Button("Create \(multiItemResults.count) Expenses") {
                createMultipleExpenses()
            }
            Button("Single Expense") {
                fillFormWithCombinedResults()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let total = multiItemResults.reduce(0) { $0 + $1.amount }
            Text("This receipt contains \(multiItemResults.count) items totaling $\(String(format: "%.2f", total)). Create a separate expense entry for each item?")
        }
    }

    // MARK: - Multi-Item Helpers

    func createMultipleExpenses() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for item in multiItemResults {
            let itemDate: String
            if !item.date.isEmpty {
                itemDate = item.date
            } else {
                itemDate = formatter.string(from: date)
            }

            // Match category
            let matchedCategoryName: String
            if !item.category.isEmpty {
                let matched = viewModel.budget.categories.first {
                    $0.name.localizedCaseInsensitiveContains(item.category) ||
                    item.category.localizedCaseInsensitiveContains($0.name)
                }
                matchedCategoryName = matched?.name ?? (viewModel.budget.categories.first?.name ?? "")
            } else {
                matchedCategoryName = category.isEmpty ? (viewModel.budget.categories.first?.name ?? "") : category
            }

            let itemDept = department.isEmpty ? viewModel.defaultDepartment : department
            let itemAcctCode = accountCode.isEmpty ? viewModel.defaultAccountCode : accountCode

            let newExpense = Expense(
                date: itemDate,
                category: matchedCategoryName,
                amount: item.amount,
                description: item.description,
                vendor: item.vendor.isEmpty ? vendor : item.vendor,
                receiptPath: receiptPath.isEmpty ? nil : receiptPath,
                department: itemDept,
                accountCode: itemAcctCode,
                paymentMethod: paymentMethod,
                status: status,
                isQualifyingExpense: isQualifyingExpense,
                addedBy: addedBy
            )
            viewModel.addExpense(newExpense)
        }
        dismiss()
    }

    func fillFormWithCombinedResults() {
        guard let first = multiItemResults.first else { return }

        // Use first item's details, but sum all amounts
        let totalAmount = multiItemResults.reduce(0) { $0 + $1.amount }
        let combinedDesc = multiItemResults.map { $0.description }.joined(separator: "; ")

        description = combinedDesc
        amount = totalAmount
        if !first.vendor.isEmpty { vendor = first.vendor }
        if !first.date.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsedDate = formatter.date(from: first.date) {
                date = parsedDate
            }
        }
        if !first.category.isEmpty {
            let matchedCategory = viewModel.budget.categories.first {
                $0.name.localizedCaseInsensitiveContains(first.category) ||
                first.category.localizedCaseInsensitiveContains($0.name)
            }
            if let matched = matchedCategory {
                category = matched.name
            }
        }
        analysisSuccess = "Combined \(multiItemResults.count) items into single expense"
    }

    func attachReceipt() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a receipt image or PDF"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        // Copy file into project assets/receipts/
        guard let basePath = viewModel.projectBasePath else {
            // No project path — store absolute path as fallback
            receiptPath = sourceURL.path
            loadReceiptPreview()
            return
        }

        let receiptsDir = basePath.appendingPathComponent("assets/receipts")
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: receiptsDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension
        let destFilename = "\(UUID().uuidString).\(ext)"
        let destURL = receiptsDir.appendingPathComponent(destFilename)

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            receiptPath = "assets/receipts/\(destFilename)"
            loadReceiptPreview()
        } catch {
            print("Failed to copy receipt: \(error)")
            // Fallback to absolute path
            receiptPath = sourceURL.path
            loadReceiptPreview()
        }
    }

    func loadReceiptPreview() {
        guard !receiptPath.isEmpty else {
            receiptPreviewImage = nil
            return
        }

        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(receiptPath)
        } else {
            fullURL = URL(fileURLWithPath: receiptPath)
        }

        receiptPreviewImage = NSImage(contentsOf: fullURL)
    }

    func analyzeReceipt() {
        guard !receiptPath.isEmpty, let analyzeCallback = viewModel.onAnalyzeReceipt else {
            analysisError = viewModel.onAnalyzeReceipt == nil ? "AI analysis not available" : "No receipt attached"
            return
        }

        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(receiptPath)
        } else {
            fullURL = URL(fileURLWithPath: receiptPath)
        }

        let ext = fullURL.pathExtension.lowercased()

        // For PDFs, render first page as PNG image for AI vision
        let imageData: Data
        let mimeType: String

        if ext == "pdf" {
            guard let pdfDoc = PDFDocument(url: fullURL),
                  let pdfPage = pdfDoc.page(at: 0) else {
                analysisError = "Could not read PDF file"
                return
            }
            let pageRect = pdfPage.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // Render at 2x for readability
            let renderSize = NSSize(width: pageRect.width * scale, height: pageRect.height * scale)
            let pdfImage = pdfPage.thumbnail(of: renderSize, for: .mediaBox)
            guard let tiffData = pdfImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                analysisError = "Could not render PDF page as image"
                return
            }
            imageData = pngData
            mimeType = "image/png"
        } else {
            guard let data = try? Data(contentsOf: fullURL) else {
                analysisError = "Could not read receipt file"
                return
            }
            imageData = data
            switch ext {
            case "png": mimeType = "image/png"
            case "jpg", "jpeg": mimeType = "image/jpeg"
            default: mimeType = "image/png"
            }
        }

        isAnalyzing = true
        Task {
            let results = await analyzeCallback(imageData, mimeType)
            if results.isEmpty {
                analysisError = "AI could not analyze this receipt. Check server connection."
            } else if results.count == 1 {
                // Single item — fill form directly
                let result = results[0]
                if !result.description.isEmpty { description = result.description }
                if !result.vendor.isEmpty { vendor = result.vendor }
                if result.amount > 0 { amount = result.amount }
                if !result.date.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let parsedDate = formatter.date(from: result.date) {
                        date = parsedDate
                    }
                }
                if !result.category.isEmpty {
                    let matchedCategory = viewModel.budget.categories.first {
                        $0.name.localizedCaseInsensitiveContains(result.category) ||
                        result.category.localizedCaseInsensitiveContains($0.name)
                    }
                    if let matched = matchedCategory {
                        category = matched.name
                    }
                }
                analysisSuccess = "Receipt analyzed successfully"
            } else {
                // Multiple items detected — show alert
                multiItemResults = results
                showingMultiItemAlert = true
            }
            isAnalyzing = false
        }
    }

    func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        if var existing = expense {
            existing.date = dateStr
            existing.category = category
            existing.amount = amount
            existing.description = description
            existing.vendor = vendor
            existing.department = department
            existing.accountCode = accountCode
            existing.paymentMethod = paymentMethod
            existing.status = status
            existing.isQualifyingExpense = isQualifyingExpense
            existing.addedBy = addedBy
            existing.receiptPath = receiptPath.isEmpty ? nil : receiptPath
            viewModel.updateExpense(existing)
        } else {
            let newExpense = Expense(
                date: dateStr,
                category: category,
                amount: amount,
                description: description,
                vendor: vendor,
                receiptPath: receiptPath.isEmpty ? nil : receiptPath,
                department: department,
                accountCode: accountCode,
                paymentMethod: paymentMethod,
                status: status,
                isQualifyingExpense: isQualifyingExpense,
                addedBy: addedBy
            )
            viewModel.addExpense(newExpense)
        }
        dismiss()
    }
}

// MARK: - PO Editor Sheet

struct POEditorSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let po: PurchaseOrder?

    @Environment(\.dismiss) private var dismiss

    @State var poNumber = ""
    @State var vendor = ""
    @State var department = ""
    @State var accountCode = ""
    @State var description = ""
    @State var amount: Double = 0
    @State var status = "Draft"
    @State var notes = ""
    @State var approvedBy = ""
    @State var attachments: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: po == nil ? "New Purchase Order" : "Edit Purchase Order",
                canSave: !vendor.isEmpty && amount > 0
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    // MARK: Left Column — Attachments + Status
                    VStack(spacing: 16) {
                        // Attachments card
                        ProductionCard(icon: "paperclip", title: "ATTACHMENTS") {
                            VStack(spacing: 8) {
                                if attachments.isEmpty {
                                    Button {
                                        attachFile()
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "doc.badge.plus")
                                                .font(.system(size: 28))
                                                .foregroundColor(.secondary)
                                            Text("Attach Files")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(Color(nsColor: .quaternarySystemFill))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    ForEach(Array(attachments.enumerated()), id: \.offset) { index, path in
                                        HStack(spacing: 6) {
                                            Image(systemName: iconForFile(path))
                                                .font(.system(size: 11))
                                                .foregroundColor(.accentColor)
                                                .frame(width: 14)

                                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                                .font(.system(size: 10))
                                                .lineLimit(1)
                                                .truncationMode(.middle)

                                            Spacer()

                                            Button {
                                                openAttachment(path)
                                            } label: {
                                                Image(systemName: "eye")
                                                    .font(.system(size: 9))
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Open file")

                                            Button {
                                                attachments.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Remove attachment")
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                        .background(Color(nsColor: .quaternarySystemFill))
                                        .cornerRadius(6)
                                    }

                                    Button {
                                        attachFile()
                                    } label: {
                                        Label("Add More", systemImage: "plus.circle")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                        }

                        // Status card
                        ProductionCard(icon: "flag", title: "STATUS") {
                            VStack(alignment: .leading, spacing: 8) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                    ForEach(["Draft", "Approved", "Committed", "Paid", "Cancelled"], id: \.self) { s in
                                        ProductionChip(s, selected: status == s) {
                                            status = s
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 240)

                    // MARK: Right Column — PO Details + Amount
                    VStack(spacing: 16) {
                        ProductionCard(icon: "doc.plaintext", title: "PO DETAILS") {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("PO NUMBER")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.2)
                                    Spacer()
                                    Text(poNumber)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.accentColor)
                                }

                                StyledTextField("Vendor", text: $vendor)
                                StyledTextField("Description", text: $description)
                                StyledTextField("Approved By", text: $approvedBy)

                                HStack(spacing: 10) {
                                    StyledTextField("Department", text: $department)
                                    StyledTextField("Account Code", text: $accountCode)
                                }
                            }
                        }

                        ProductionCard(icon: "dollarsign.circle", title: "AMOUNT & NOTES") {
                            VStack(spacing: 10) {
                                StyledNumberField("Amount", value: $amount)
                                StyledTextField("Notes", text: $notes)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 680, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let po = po {
                poNumber = po.poNumber
                vendor = po.vendor
                department = po.department
                accountCode = po.accountCode
                description = po.description
                amount = po.amount
                status = po.status
                notes = po.notes
                approvedBy = po.approvedBy
                attachments = po.attachments
            } else {
                poNumber = viewModel.nextPONumber()
            }
        }
    }

    func attachFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select files to attach to this purchase order"

        guard panel.runModal() == .OK else { return }

        for sourceURL in panel.urls {
            guard let basePath = viewModel.projectBasePath else {
                // No project path — store absolute path as fallback
                attachments.append(sourceURL.path)
                continue
            }

            let attachmentsDir = basePath.appendingPathComponent("assets/po_attachments")
            let fileManager = FileManager.default
            try? fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

            let ext = sourceURL.pathExtension
            let destFilename = "\(UUID().uuidString).\(ext)"
            let destURL = attachmentsDir.appendingPathComponent(destFilename)

            do {
                try fileManager.copyItem(at: sourceURL, to: destURL)
                attachments.append("assets/po_attachments/\(destFilename)")
            } catch {
                print("Failed to copy attachment: \(error)")
                attachments.append(sourceURL.path)
            }
        }
    }

    func openAttachment(_ path: String) {
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(path)
        } else {
            fullURL = URL(fileURLWithPath: path)
        }
        NSWorkspace.shared.open(fullURL)
    }

    func iconForFile(_ path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "heic", "tiff": return "photo"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx", "csv": return "tablecells"
        case "zip", "gz", "tar": return "archivebox"
        default: return "doc"
        }
    }

    func save() {
        if var existing = po {
            existing.vendor = vendor
            existing.department = department
            existing.accountCode = accountCode
            existing.description = description
            existing.amount = amount
            existing.status = status
            existing.notes = notes
            existing.approvedBy = approvedBy
            existing.attachments = attachments
            viewModel.updatePurchaseOrder(existing)
        } else {
            let newPO = PurchaseOrder(
                poNumber: poNumber,
                vendor: vendor,
                department: department,
                accountCode: accountCode,
                description: description,
                amount: amount,
                status: status,
                notes: notes,
                approvedBy: approvedBy,
                attachments: attachments
            )
            viewModel.addPurchaseOrder(newPO)
        }
        dismiss()
    }
}
