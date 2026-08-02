// DirectorsChairServices/Sync/ProjectOverviewBuilder+Production.swift
//
// §12A deck projection, final parity sweep: props, vision board, and the
// production suite (schedule / gantt / cast & crew / budget / equipment).
// The portal ships matching renderers (ProjectStory props sub-tab,
// VisionBoardView, ProjectProduction); wire shapes follow webapp api.ts —
// OverviewProp, VisionCard, Production. Dates stay bare YYYY-MM-DD (the
// portal's date parser appends its own T00:00:00), money stays in major
// units (Intl.NumberFormat renders it), and every list the portal keys by
// value is deduplicated.

import Foundation
import DirectorsChairCore

extension ProjectOverviewBuilder {

    // MARK: - Props (portal Story → Props)

    static func propCard(_ prop: Prop,
                         blobURL: (String?) -> String?) -> [String: Any] {
        var card: [String: Any] = ["id": prop.id, "name": prop.name]
        func put(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { card[key] = value }
        }
        put("category", prop.category)
        put("status", prop.status)
        put("description", prop.description)
        put("specs", prop.detailedSpecs)
        put("continuity", prop.continuityNotes)
        if !prop.tags.isEmpty { card["tags"] = prop.tags }
        if let quantity = prop.quantity { card["quantity"] = quantity }
        // Scene chips are React-keyed by the string — dedupe.
        if let scenes = prop.sceneNames, !scenes.isEmpty {
            var seen: Set<String> = []
            let unique = scenes.filter { seen.insert($0).inserted }
            card["scenes"] = unique
        }
        if let image = blobURL(prop.thumbnail) { card["image"] = image }
        return card
    }

    // MARK: - Vision board (portal Vision tab)

    /// Cards ordered by (board, position). Board names resolve through the
    /// registry when present; the legacy "master" board prettifies to
    /// "Board" territory only when several boards exist (the portal hides
    /// the heading for a single board).
    static func visionCards(project: Project,
                            blobURL: (String?) -> String?) -> [[String: Any]] {
        let boardNames = Dictionary(project.visionBoards.map { ($0.id, $0.name) },
                                    uniquingKeysWith: { first, _ in first })
        return project.beats
            .sorted { ($0.boardId, $0.position) < ($1.boardId, $1.position) }
            .map { card in
                var entry: [String: Any] = ["id": card.id, "type": card.cardType]
                func put(_ key: String, _ value: String?) {
                    if let value, !value.isEmpty { entry[key] = value }
                }
                put("title", card.title)
                put("text", card.text)
                put("department", prettify(card.department))
                put("board", boardNames[card.boardId] ?? prettify(card.boardId))
                // Swatches are React-keyed by hex — dedupe, hex-only.
                var seen: Set<String> = []
                let palette = card.colorPalette
                    .filter { $0.hasPrefix("#") && seen.insert($0).inserted }
                if !palette.isEmpty { entry["color_palette"] = palette }
                if let image = blobURL(card.imagePath ?? card.imagePaths.first) {
                    entry["image"] = image
                }
                if card.pinned { entry["pinned"] = true }
                return entry
            }
    }

    /// "production_design" → "Production Design" — the portal filters by
    /// exact string equality and prints values raw, so any consistent
    /// transform works; readable beats raw enum values.
    private static func prettify(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    // MARK: - Production suite (portal Production tab)

    /// nil when every section is empty — the portal hides the tab.
    static func productionSection(project: Project) -> [String: Any]? {
        var production: [String: Any] = [:]

        let schedule = project.scheduleItems.map { item -> [String: Any] in
            var entry: [String: Any] = ["id": item.id]
            func put(_ key: String, _ value: String?) {
                if let value, !value.isEmpty { entry[key] = value }
            }
            put("scene_name", item.sceneName)
            put("sequence", item.sequenceName)
            put("shoot_date", item.shootDate)
            put("time_slot", item.timeSlot)
            put("status", item.status)
            put("call_time", item.callTime)
            put("wrap_time", item.wrapTime)
            put("location", item.location)
            put("notes", item.productionNotes)
            if item.estimatedDurationHours > 0 {
                entry["est_hours"] = item.estimatedDurationHours
            }
            func chips(_ key: String, _ values: [String]) {
                var seen: Set<String> = []
                let unique = values.filter { !$0.isEmpty && seen.insert($0).inserted }
                if !unique.isEmpty { entry[key] = unique }
            }
            chips("cast", item.requiredActors)
            chips("props", item.requiredProps)
            chips("equipment", item.requiredEquipment)
            return entry
        }
        if !schedule.isEmpty { production["schedule"] = schedule }

        let gantt = project.ganttTasks.map { task -> [String: Any] in
            var entry: [String: Any] = ["id": task.id, "name": task.name,
                                        "category": task.category.rawValue]
            if !task.startDate.isEmpty {
                entry["start_date"] = task.startDate
                // The portal draws bars from end_date (duration_days is
                // display-only there); computedEndDate folds duration in.
                if !task.isMilestone { entry["end_date"] = task.computedEndDate }
            }
            if task.durationDays > 0 { entry["duration_days"] = task.durationDays }
            if !task.status.isEmpty { entry["status"] = task.status }
            entry["completion"] = task.completionPercentage
            if task.isMilestone { entry["is_milestone"] = true }
            return entry
        }
        if !gantt.isEmpty { production["gantt"] = gantt }

        let cast = project.castMembers.map { member -> [String: Any] in
            var entry: [String: Any] = ["id": member.id,
                                        "actor_name": member.actorName]
            func put(_ key: String, _ value: String?) {
                if let value, !value.isEmpty { entry[key] = value }
            }
            put("character_name", member.characterName)
            put("role_type", member.roleType)
            put("union_status", member.unionStatus)
            // The desktop has no shoot-day counter; derive it from the
            // schedule the same way a 1st AD would — days the actor is on.
            let days = project.scheduleItems.filter {
                $0.requiredActors.contains(member.actorName)
            }.count
            if days > 0 { entry["shoot_days"] = days }
            return entry
        }
        if !cast.isEmpty { production["cast"] = cast }

        let crew = project.crewMembers.map { member -> [String: Any] in
            var entry: [String: Any] = ["id": member.id, "name": member.name]
            if !member.role.isEmpty { entry["role"] = member.role }
            if !member.department.isEmpty { entry["department"] = member.department }
            if !member.skills.isEmpty { entry["skills"] = member.skills }
            return entry
        }
        if !crew.isEmpty { production["crew"] = crew }

        if !project.teams.isEmpty {
            let castNames = Dictionary(project.castMembers.map { ($0.id, $0.actorName) },
                                       uniquingKeysWith: { first, _ in first })
            let crewNames = Dictionary(project.crewMembers.map { ($0.id, $0.name) },
                                       uniquingKeysWith: { first, _ in first })
            production["teams"] = project.teams.map { team -> [String: Any] in
                var entry: [String: Any] = ["id": team.id, "name": team.name]
                if !team.teamType.isEmpty { entry["team_type"] = team.teamType }
                if !team.description.isEmpty { entry["description"] = team.description }
                entry["cast_count"] = team.castMemberIds.count
                entry["crew_count"] = team.crewMemberIds.count
                if let leadID = team.teamLeadId,
                   let lead = castNames[leadID] ?? crewNames[leadID] {
                    entry["lead"] = lead
                }
                return entry
            }
        }

        if let budget = project.projectBudget, !budget.categories.isEmpty {
            var entry: [String: Any] = [
                "currency": budget.currency,
                "total_spent": budget.totalSpent,
            ]
            if budget.totalBudget > 0 { entry["total_budget"] = budget.totalBudget }
            // The portal keys rows by category name — merge duplicates.
            var merged: [(name: String, group: String?, code: String?,
                          allocated: Double, spent: Double)] = []
            var indexByName: [String: Int] = [:]
            for category in budget.categories {
                if let index = indexByName[category.name] {
                    merged[index].allocated += category.allocated
                    merged[index].spent += category.spent
                } else {
                    indexByName[category.name] = merged.count
                    merged.append((category.name, category.categoryGroup,
                                   category.accountCode,
                                   category.allocated, category.spent))
                }
            }
            entry["categories"] = merged.map { category -> [String: Any] in
                var row: [String: Any] = ["name": category.name,
                                          "allocated": category.allocated,
                                          "spent": category.spent]
                if let group = category.group, !group.isEmpty { row["group"] = group }
                if let code = category.code, !code.isEmpty { row["account_code"] = code }
                return row
            }
            // Spend-by-department bars, derived from the expense ledger.
            var byDepartment: [String: Double] = [:]
            for expense in budget.expenses where !expense.department.isEmpty {
                byDepartment[expense.department, default: 0] += expense.amount
            }
            if !byDepartment.isEmpty {
                entry["by_department"] = byDepartment.keys.sorted().map {
                    ["name": $0, "amount": byDepartment[$0] ?? 0]
                }
            }
            production["budget"] = entry
        }

        if !project.equipmentLibrary.isEmpty {
            let allocationByItem = Dictionary(
                project.equipmentAllocations.map { ($0.equipmentItemId, $0) },
                uniquingKeysWith: { first, _ in first })
            production["equipment"] = project.equipmentLibrary.map { item -> [String: Any] in
                var entry: [String: Any] = ["id": item.id, "name": item.name]
                func put(_ key: String, _ value: String?) {
                    if let value, !value.isEmpty { entry[key] = value }
                }
                put("category", item.category)
                put("manufacturer", item.manufacturer)
                put("model", item.model)
                put("condition", item.condition)
                entry["quantity_owned"] = item.quantityOwned
                entry["quantity_available"] = item.quantityAvailable
                if item.isRental {
                    entry["is_rental"] = true
                    if item.rentalDailyRate > 0 {
                        entry["rental_daily_rate"] = item.rentalDailyRate
                    }
                }
                if let allocation = allocationByItem[item.id] {
                    entry["allocation"] = allocation.allocationMode == .specificDays
                        ? "\(allocation.allocatedDates.count) day(s)"
                        : "Full production"
                }
                return entry
            }
        }

        return production.isEmpty ? nil : production
    }
}
