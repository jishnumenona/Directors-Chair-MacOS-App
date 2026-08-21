// DirectorsChairCore/ProjectInsights.swift
//
// On-device AI insights (DC-0055, Product-Versions §3.7 — Free across all
// tiers because inference runs locally). This file is the PURE half: what
// an insight is, and how a project is compressed into the small context a
// 3B-class on-device model can actually read. The engine that runs the
// model lives behind InsightEngine in the Services package; nothing here
// imports an inference framework, so every line is unit-testable.
//
// Budgeting: an on-device 3B model gets a few thousand tokens of context
// before quality and latency fall apart. Builders work in CHARACTERS
// (≈4 chars/token) against InsightContextBuilder.characterBudget and
// truncate from the least-important end — never mid-entity where the
// model would read a half-sentence as fact.

import Foundation

// MARK: - Insight families

/// What kind of look at the project is being asked for. Raw values are
/// stable identifiers (persisted in caches and telemetry — never rename).
public enum InsightFamily: String, CaseIterable, Identifiable, Sendable {
    case scriptStory = "script_story"
    case production = "production"
    case overviewDigest = "overview_digest"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scriptStory: return "Script & story"
        case .production: return "Production"
        case .overviewDigest: return "Project digest"
        }
    }

    public var systemImage: String {
        switch self {
        case .scriptStory: return "text.book.closed"
        case .production: return "calendar.badge.clock"
        case .overviewDigest: return "doc.text.magnifyingglass"
        }
    }

    /// The instruction the engine pins for this family. Kept HERE, next to
    /// the context builder, so prompt and context always evolve together.
    public var instructions: String {
        switch self {
        case .scriptStory:
            return """
            You are a seasoned script consultant reading a film project's \
            outline. Give the filmmaker 3-5 concise, concrete observations \
            about story structure, pacing, and character presence — grounded \
            ONLY in the material provided. Name scenes and characters when \
            you refer to them. If the material is too thin to judge, say \
            what is missing instead of inventing. No preamble; plain prose \
            bullets.
            """
        case .production:
            return """
            You are a line producer reviewing a film project's planning \
            data. Give 3-5 concise, concrete observations about schedule \
            load, shot coverage, and budget health — grounded ONLY in the \
            numbers provided. Point at specific scenes, dates, or categories. \
            Flag anything unscheduled, unshot-listed, or overspent. If data \
            is missing, say so plainly. No preamble; plain prose bullets.
            """
        case .overviewDigest:
            return """
            You are the project's first assistant director writing the \
            morning briefing. In one short paragraph plus 2-3 bullets, \
            summarize where this film project stands: how much material \
            exists, what state production planning is in, and the most \
            useful next step. Grounded ONLY in the data provided; name \
            things specifically. No preamble.
            """
        }
    }
}

// MARK: - Context building

/// Compresses a Project into the compact, model-facing context for one
/// insight family. Pure and deterministic: same project, same output.
public enum InsightContextBuilder {

    /// ≈3k tokens — leaves room for instructions + the model's answer
    /// inside a 3B model's comfortable window.
    public static let characterBudget = 12_000

    public static func context(for family: InsightFamily, project: Project,
                               budget: Int = characterBudget) -> String {
        let body: String
        switch family {
        case .scriptStory: body = scriptStoryContext(project, budget: budget)
        case .production: body = productionContext(project, budget: budget)
        case .overviewDigest: body = digestContext(project, budget: budget)
        }
        return body
    }

    // MARK: Script & story

    static func scriptStoryContext(_ project: Project, budget: Int) -> String {
        var lines: [String] = []
        lines.append("PROJECT: \(project.name) — \(project.genre.isEmpty ? "genre unset" : project.genre)")
        if !project.description.isEmpty {
            lines.append("LOGLINE: \(clip(project.description, 300))")
        }
        let characters = project.characters.map(\.name).filter { !$0.isEmpty }
        if !characters.isEmpty {
            lines.append("CHARACTERS: \(characters.joined(separator: ", "))")
        }
        for sequence in project.sequences {
            lines.append("SEQUENCE: \(sequence.name)")
            for scene in sequence.scenes {
                var parts = ["  SCENE \(scene.name)"]
                if !scene.description.isEmpty { parts.append(clip(scene.description, 220)) }
                let speakers = orderedUnique(scene.dialogues.map(\.character))
                if !speakers.isEmpty { parts.append("speakers: \(speakers.joined(separator: ", "))") }
                parts.append("\(scene.dialogues.count) lines, \(scene.actions.count) actions, \(scene.shots.count) shots")
                lines.append(parts.joined(separator: " — "))
            }
        }
        return fit(lines, budget: budget)
    }

    // MARK: Production

    static func productionContext(_ project: Project, budget: Int) -> String {
        var lines: [String] = []
        let scenes = project.sequences.flatMap(\.scenes)
        lines.append("PROJECT: \(project.name) — status \(project.status)")
        lines.append("SCALE: \(scenes.count) scenes, \(scenes.reduce(0) { $0 + $1.shots.count }) shots, \(project.characters.count) characters, \(project.locations.count) locations")

        // Coverage: scenes with no shot list are unplanned camera-wise.
        let uncovered = scenes.filter { $0.shots.isEmpty }.map(\.name)
        if !uncovered.isEmpty {
            lines.append("SCENES WITHOUT SHOTS (\(uncovered.count)): \(uncovered.prefix(15).joined(separator: ", "))")
        }

        // Schedule: what is dated, what is not, how the days stack up.
        let scheduled = project.scheduleItems.filter { $0.shootDate != nil }
        let unscheduled = scenes.count - Set(project.scheduleItems.compactMap(\.sceneId)).count
        lines.append("SCHEDULE: \(scheduled.count) dated items; \(max(unscheduled, 0)) scenes not on the schedule")
        var byDate: [String: Double] = [:]
        for item in scheduled {
            byDate[item.shootDate ?? "", default: 0] += item.estimatedDurationHours
        }
        for (date, hours) in byDate.sorted(by: { $0.key < $1.key }) {
            lines.append("  DAY \(date): \(trimmedHours(hours))h planned\(hours > 12 ? " — OVERLOADED" : "")")
        }

        // Budget: per-category allocation vs spend.
        if let budgetData = project.projectBudget {
            lines.append("BUDGET: total \(trimmedHours(budgetData.totalBudget)) \(budgetData.currency), \(budgetData.expenses.count) expenses")
            for category in budgetData.categories where category.allocated > 0 || category.spent > 0 {
                let flag = category.spent > category.allocated && category.allocated > 0 ? " — OVER" : ""
                lines.append("  \(category.name): \(trimmedHours(category.spent)) spent of \(trimmedHours(category.allocated))\(flag)")
            }
        }

        // Production state roll-up.
        let byStatus = Dictionary(grouping: scenes, by: \.productionStatus)
            .mapValues(\.count)
        if !byStatus.isEmpty {
            let roll = byStatus.sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            lines.append("SCENE STATUS: \(roll)")
        }
        return fit(lines, budget: budget)
    }

    // MARK: Digest

    static func digestContext(_ project: Project, budget: Int) -> String {
        // The digest reads both worlds, so it gets each half at half budget.
        let story = scriptStoryContext(project, budget: budget / 2)
        let production = productionContext(project, budget: budget / 2)
        return story + "\n---\n" + production
    }

    // MARK: Helpers

    /// Whole-line budget fit: keeps the head of the report (identity and
    /// summaries come first by construction), drops trailing detail lines,
    /// and says so — the model must never mistake a truncation for the
    /// end of the data.
    static func fit(_ lines: [String], budget: Int) -> String {
        var total = 0
        var kept: [String] = []
        for line in lines {
            let cost = line.count + 1
            if total + cost > budget {
                kept.append("(further detail omitted for length)")
                break
            }
            kept.append(line)
            total += cost
        }
        return kept.joined(separator: "\n")
    }

    static func clip(_ text: String, _ limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "…"
    }

    static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func trimmedHours(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value)) : String(format: "%.1f", value)
    }
}
