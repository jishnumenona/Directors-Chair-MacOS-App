//
//  ProjectContextBuilder.swift
//  DirectorsChair-Desktop
//
//  A6.1: the compact PROJECT INDEX for the assistant's system prompt.
//  Replaces the retired 4-tier keyword-matched context dump (up to ~25k
//  tokens per turn): now that the assistant has read-tools that pull exact
//  live data on demand (get_scene, get_schedule, get_budget_summary, …),
//  the prompt only needs an INDEX of what exists — names and counts, never
//  content. Small regardless of project size; details always come from
//  tools, so answers reflect live state instead of a stale dump.
//

import Foundation
import DirectorsChairCore

enum ProjectContextBuilder {

    /// The compact index: what exists (names/counts only) plus what the
    /// user is currently looking at. Content is deliberately absent — the
    /// model must fetch it with read-tools.
    static func buildContext(project: Project, context: AIChatContext?,
                             query: String = "") -> String {
        var parts: [String] = []
        parts.append("--- PROJECT INDEX (names and counts only — fetch content with the read tools) ---")

        var meta = "Project: \(project.name)"
        if !project.genre.isEmpty { meta += " | Genre: \(project.genre)" }
        if !project.status.isEmpty { meta += " | Status: \(project.status)" }
        parts.append(meta)

        // Structure: scene names per sequence with per-scene item counts.
        for sequence in project.sequences {
            let scenes = sequence.scenes.map { scene in
                "\(scene.name) (\(scene.dialogues.count)d/\(scene.shots.count)sh)"
            }.joined(separator: ", ")
            parts.append("Sequence \"\(sequence.name)\": \(scenes.isEmpty ? "no scenes" : scenes)")
        }

        if !project.characters.isEmpty {
            parts.append("Characters: " + project.characters.map(\.name)
                .joined(separator: ", "))
        }
        if !project.locations.isEmpty {
            parts.append("Locations: " + project.locations.map(\.name)
                .joined(separator: ", "))
        }

        // Production surfaces: presence + counts only.
        var production: [String] = []
        if !project.scheduleItems.isEmpty {
            production.append("\(project.scheduleItems.count) schedule items")
        }
        if !project.ganttTasks.isEmpty {
            production.append("\(project.ganttTasks.count) plan tasks")
        }
        if let budget = project.projectBudget {
            production.append("budget \(budget.currency) \(Int(budget.totalBudget)) "
                + "(\(budget.categories.count) categories)")
        }
        if !project.castMembers.isEmpty {
            production.append("\(project.castMembers.count) cast")
        }
        if !project.crewMembers.isEmpty {
            production.append("\(project.crewMembers.count) crew")
        }
        if !project.equipmentLibrary.isEmpty {
            production.append("\(project.equipmentLibrary.count) equipment items")
        }
        if !production.isEmpty {
            parts.append("Production: " + production.joined(separator: " · "))
        }

        // What the user is looking at right now (names only).
        if let context {
            var current = "User is viewing: \(context.currentView.rawValue)"
            if let tab = context.productionTab { current += " › \(tab)" }
            if let character = context.selectedCharacter {
                current += " | selected character: \(character.name)"
            }
            if let scene = context.selectedScene {
                current += " | selected scene: \(scene.name)"
            }
            if let shot = context.selectedShot {
                current += " | selected shot: #\(shot.shotId)"
            }
            if let location = context.selectedLocation {
                current += " | selected location: \(location.name)"
            }
            parts.append(current)
        }

        return parts.joined(separator: "\n")
    }
}
