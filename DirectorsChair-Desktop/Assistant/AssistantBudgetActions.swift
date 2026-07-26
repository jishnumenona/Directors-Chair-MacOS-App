//
//  AssistantBudgetActions.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A3.4: budget actions (F-D4) with the
//  validator in the loop (AD6) — every money proposal previews the exact
//  before→after figures and warns about overruns (category allocation,
//  total budget) without ever silently blocking. Categories resolve by
//  name or industry account code. Receipt-photo→expense rides the chat's
//  native image attachment: the model reads the receipt and fills
//  add_expense; the user approves the drafted figures on the review card.
//  (Purchase-order CRUD is deferred — expenses carry the money flow.)
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

private let stringProp = JSONValue.object(["type": .string("string")])
private let numberProp = JSONValue.object(["type": .string("number")])

private func objectSchema(_ properties: [String: JSONValue],
                          required: [String]) -> JSONValue {
    .object(["type": .string("object"),
             "properties": .object(properties),
             "required": .array(required.map(JSONValue.string))])
}

// MARK: - Shared budget helpers

class BudgetAssistantAction: ProjectAssistantAction {
    @MainActor func requireBudget() throws -> (ProjectViewModel, ProjectBudget) {
        let pvm = try requireProject()
        guard let budget = pvm.project.projectBudget else {
            throw ActionError("no budget is set up for this project")
        }
        return (pvm, budget)
    }

    /// Resolves a category by name or account code (case-insensitive).
    @MainActor func categoryIndex(_ reference: String,
                                  in budget: ProjectBudget) throws -> Int {
        if let index = budget.categories.firstIndex(where: {
            $0.name.lowercased() == reference.lowercased()
            || (!$0.accountCode.isEmpty && $0.accountCode == reference)
        }) {
            return index
        }
        let known = budget.categories.map {
            "\($0.name)\($0.accountCode.isEmpty ? "" : " (\($0.accountCode))")"
        }.joined(separator: ", ")
        throw ActionError("no budget category '\(reference)'"
            + (known.isEmpty ? " — the budget has no categories" : " (categories: \(known))"))
    }

    @MainActor func money(_ amount: Double, in budget: ProjectBudget) -> String {
        "\(budget.currency) \(String(format: "%.2f", amount))"
    }
}

// MARK: - add_expense

final class AddExpenseAction: BudgetAssistantAction, AssistantAction {
    let name = "add_expense"
    let summary = """
    Record an expense against a budget category (by name or account code). \
    When the user attaches a receipt photo, read the vendor, date, and \
    amount from it and draft the expense for approval. Overruns come back \
    as warnings.
    """
    let risk = ActionRisk.spending
    var parameterSchema: JSONValue {
        objectSchema([
            "description": stringProp, "amount": numberProp,
            "category": stringProp, "date": stringProp,
            "vendor": stringProp, "payment_method": stringProp,
        ], required: ["description", "amount", "category"])
    }

    private struct Arguments: Decodable {
        let description: String, amount: Double, category: String
        let date: String?, vendor: String?, paymentMethod: String?
        enum CodingKeys: String, CodingKey {
            case description, amount, category, date, vendor
            case paymentMethod = "payment_method"
        }
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, Int, [String]) {
        guard args.amount > 0 else {
            throw ActionError("amount must be positive")
        }
        if let date = args.date,
           date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) == nil {
            throw ActionError("date must be YYYY-MM-DD, got '\(date)'")
        }
        let (pvm, budget) = try requireBudget()
        let index = try categoryIndex(args.category, in: budget)
        let category = budget.categories[index]
        var warnings: [String] = []
        let newSpent = category.spent + args.amount
        if category.allocated > 0, newSpent > category.allocated {
            warnings.append("overruns the \(category.name) allocation by "
                + money(newSpent - category.allocated, in: budget))
        }
        if budget.totalBudget > 0, budget.totalSpent + args.amount > budget.totalBudget {
            warnings.append("pushes total spend past the "
                + money(budget.totalBudget, in: budget) + " budget")
        }
        return (pvm, index, warnings)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, index, warnings) = try check(args)
        let budget = pvm.project.projectBudget!
        let category = budget.categories[index]
        return ActionPlan(
            summary: "Record \(money(args.amount, in: budget)) — \(args.description)",
            previews: [ActionPreview(
                title: "\(category.name) · spent",
                oldValue: money(category.spent, in: budget),
                newValue: money(category.spent + args.amount, in: budget))],
            warnings: warnings)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, index, _) = try check(args)
        let category = pvm.project.projectBudget!.categories[index]
        var expense = Expense(date: args.date ?? "", category: category.name,
                              amount: args.amount, description: args.description,
                              vendor: args.vendor ?? "")
        expense.accountCode = category.accountCode
        if let method = args.paymentMethod { expense.paymentMethod = method }
        pvm.project.projectBudget?.expenses.append(expense)
        pvm.project.projectBudget?.categories[index].spent += args.amount
        didMutate(.production)
        return ActionOutcome(
            resultForModel: #"{"status": "applied"}"#,
            userSummary: "Recorded \(money(args.amount, in: pvm.project.projectBudget!)) in \(category.name)")
    }
}

// MARK: - add_budget_category

final class AddBudgetCategoryAction: BudgetAssistantAction, AssistantAction {
    let name = "add_budget_category"
    let summary = """
    Add a budget category (name, allocated amount, optional industry \
    account code and group ATL|BTL|Post|Other).
    """
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema([
            "name": stringProp, "allocated": numberProp,
            "account_code": stringProp, "group": stringProp,
        ], required: ["name", "allocated"])
    }

    private struct Arguments: Decodable {
        let name: String, allocated: Double
        let accountCode: String?, group: String?
        enum CodingKeys: String, CodingKey {
            case name, allocated, group
            case accountCode = "account_code"
        }
    }

    @MainActor private func check(_ args: Arguments) throws
    -> (ProjectViewModel, [String]) {
        guard args.allocated >= 0 else {
            throw ActionError("allocated must not be negative")
        }
        if let group = args.group,
           !["ATL", "BTL", "Post", "Other"].contains(group) {
            throw ActionError("group must be ATL, BTL, Post, or Other")
        }
        let (pvm, budget) = try requireBudget()
        if budget.categories.contains(where: {
            $0.name.lowercased() == args.name.lowercased()
        }) {
            throw ActionError("a category named '\(args.name)' already exists")
        }
        var warnings: [String] = []
        let allocatedTotal = budget.categories.reduce(0) { $0 + $1.allocated }
            + args.allocated
        if budget.totalBudget > 0, allocatedTotal > budget.totalBudget {
            warnings.append("total allocations would exceed the "
                + money(budget.totalBudget, in: budget) + " budget by "
                + money(allocatedTotal - budget.totalBudget, in: budget))
        }
        return (pvm, warnings)
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, warnings) = try check(args)
        let budget = pvm.project.projectBudget!
        return ActionPlan(
            summary: "Add budget category “\(args.name)”",
            previews: [ActionPreview(title: "\(args.name) · allocated",
                                     oldValue: nil,
                                     newValue: money(args.allocated, in: budget))],
            warnings: warnings)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, _) = try check(args)
        pvm.project.projectBudget?.categories.append(BudgetCategory(
            name: args.name, allocated: args.allocated, isCustom: true,
            accountCode: args.accountCode ?? "",
            categoryGroup: args.group ?? "Other"))
        didMutate(.production)
        return ActionOutcome(resultForModel: #"{"status": "applied"}"#,
                             userSummary: "Added budget category “\(args.name)”")
    }
}

// MARK: - update_budget_category

final class UpdateBudgetCategoryAction: BudgetAssistantAction, AssistantAction {
    let name = "update_budget_category"
    let summary = "Change a budget category's allocated amount (by name or account code)."
    let risk = ActionRisk.mutating
    var parameterSchema: JSONValue {
        objectSchema(["category": stringProp, "new_allocated": numberProp],
                     required: ["category", "new_allocated"])
    }

    private struct Arguments: Decodable {
        let category: String, newAllocated: Double
        enum CodingKeys: String, CodingKey {
            case category
            case newAllocated = "new_allocated"
        }
    }

    @MainActor func validate(argumentsData: Data) throws -> ActionPlan {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        guard args.newAllocated >= 0 else {
            throw ActionError("new_allocated must not be negative")
        }
        let (pvm, budget) = try requireBudget()
        _ = pvm
        let index = try categoryIndex(args.category, in: budget)
        let category = budget.categories[index]
        var warnings: [String] = []
        if args.newAllocated < category.spent {
            warnings.append("below the \(money(category.spent, in: budget)) already spent")
        }
        return ActionPlan(
            summary: "Reallocate “\(category.name)”",
            previews: [ActionPreview(title: "\(category.name) · allocated",
                                     oldValue: money(category.allocated, in: budget),
                                     newValue: money(args.newAllocated, in: budget))],
            warnings: warnings)
    }

    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome {
        let args = try JSONDecoder().decode(Arguments.self, from: argumentsData)
        let (pvm, budget) = try requireBudget()
        let index = try categoryIndex(args.category, in: budget)
        pvm.project.projectBudget?.categories[index].allocated = args.newAllocated
        didMutate(.production)
        return ActionOutcome(
            resultForModel: #"{"status": "applied"}"#,
            userSummary: "Reallocated “\(budget.categories[index].name)”")
    }
}

// MARK: - Factory extension

extension AssistantActionFactory {
    @MainActor static func budgetActions(projectViewModel: ProjectViewModel?,
                                         coordinator: AppCoordinator?) -> [any AssistantAction] {
        [
            AddExpenseAction(projectViewModel: projectViewModel, coordinator: coordinator),
            AddBudgetCategoryAction(projectViewModel: projectViewModel, coordinator: coordinator),
            UpdateBudgetCategoryAction(projectViewModel: projectViewModel, coordinator: coordinator),
        ]
    }
}
