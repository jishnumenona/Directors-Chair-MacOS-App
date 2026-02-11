//
//  ProjectContextBuilder.swift
//  DirectorsChair-Desktop
//
//  Tiered project data serializer for AI chat prompts
//

import Foundation
import DirectorsChairCore

enum ProjectContextBuilder {
    static let tokenBudget = 25_000

    static func buildContext(project: Project, context: AIChatContext?, query: String = "") -> String {
        var sections: [String] = []
        var estimatedTokens = 0

        // Level 1: Project metadata (~500 tokens)
        let meta = buildMetadata(project: project)
        sections.append(meta)
        estimatedTokens += meta.count / 4

        // Level 2: Selected item detail (~2K tokens)
        if let ctx = context {
            let selected = buildSelectedDetail(project: project, context: ctx)
            if !selected.isEmpty {
                sections.append(selected)
                estimatedTokens += selected.count / 4
            }
        }

        // Level 3: All names and summaries (~5K tokens)
        if estimatedTokens < tokenBudget - 5000 {
            let summary = buildSummaries(project: project)
            sections.append(summary)
            estimatedTokens += summary.count / 4
        }

        // Level 4: Domain-specific deep detail based on query
        if estimatedTokens < tokenBudget - 10000 && !query.isEmpty {
            let deep = buildDeepDetail(project: project, query: query)
            if !deep.isEmpty {
                sections.append(deep)
            }
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Level 1: Metadata

    private static func buildMetadata(project: Project) -> String {
        let totalScenes = project.sequences.flatMap(\.scenes).count
        let totalShots = project.sequences.flatMap(\.scenes).flatMap(\.shots).count
        let totalDialogues = project.sequences.flatMap(\.scenes).flatMap(\.dialogues).count

        return """
        === PROJECT DATA ===
        Title: \(project.name)
        Genre: \(project.genre)
        Type: \(project.projectType)
        Status: \(project.status)
        Director: \(project.director)
        Company: \(project.productionCompany)
        Duration: \(project.targetDuration)
        Budget: \(project.budget)
        Tagline: \(project.overviewTagline)
        Logline: \(project.overviewLogline)
        Characters: \(project.characters.count) | Sequences: \(project.sequences.count) | Scenes: \(totalScenes) | Shots: \(totalShots) | Dialogues: \(totalDialogues)
        Locations: \(project.locations.count) | Props: \(project.props.count)
        Cast: \(project.castMembers.count) | Crew: \(project.crewMembers.count) | Equipment: \(project.equipmentLibrary.count)
        """
    }

    // MARK: - Level 2: Selected Item Detail

    private static func buildSelectedDetail(project: Project, context: AIChatContext) -> String {
        var parts: [String] = []

        parts.append("--- CURRENT CONTEXT ---")
        parts.append("Active View: \(context.currentView.rawValue)")
        if let tab = context.productionTab {
            parts.append("Production Tab: \(tab)")
        }

        if let char = context.selectedCharacter {
            parts.append(characterDetail(char))
        }

        if let scene = context.selectedScene {
            parts.append(sceneDetail(scene, project: project))
        }

        if let shot = context.selectedShot {
            parts.append("Selected Shot #\(shot.shotId): \(shot.description) | Type: \(shot.shotType) | Angle: \(shot.cameraAngle) | Lens: \(shot.lensMm)mm | Status: \(shot.status)")
        }

        if let loc = context.selectedLocation {
            parts.append("Selected Location: \(loc.name) | Type: \(loc.locationType) | \(loc.description)")
        }

        if let dlg = context.selectedDialogue {
            parts.append("Selected Dialogue: \(dlg.character): \"\(dlg.text)\"")
        }

        if let act = context.selectedAction {
            parts.append("Selected Action: \(act.description)")
        }

        if let nar = context.selectedNarration {
            parts.append("Selected Narration: \(nar.text)")
        }

        return parts.joined(separator: "\n")
    }

    private static func characterDetail(_ char: Character) -> String {
        let topTraits = char.traits.sorted { $0.value > $1.value }.prefix(8)
            .map { "\($0.key): \(Int($0.value))" }.joined(separator: ", ")

        var lines = [
            "Selected Character: \(char.name)",
            "  Role: \(char.role) | Age: \(char.age) | Gender: \(char.gender)",
            "  Build: \(char.build) | Height: \(char.heightCm.map { "\(Int($0))" } ?? "—")cm | Weight: \(char.weightKg.map { "\(Int($0))" } ?? "—")kg",
            "  Hair: \(char.hairColor) \(char.hairStyle) | Eyes: \(char.eyeColor)",
            "  Occupation: \(char.occupation ?? "—") | About: \(char.about)"
        ]
        if !topTraits.isEmpty {
            lines.append("  Top Traits: \(topTraits)")
        }
        if let goal = char.primaryGoal, !goal.isEmpty {
            lines.append("  Goal: \(goal)")
        }
        if let fear = char.primaryFear, !fear.isEmpty {
            lines.append("  Fear: \(fear)")
        }
        if let backstory = char.backgroundStory, !backstory.isEmpty {
            lines.append("  Backstory: \(String(backstory.prefix(300)))")
        }
        if let relationships = char.relationships, !relationships.isEmpty {
            let rels = relationships.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
            lines.append("  Relationships: \(rels)")
        }
        return lines.joined(separator: "\n")
    }

    private static func sceneDetail(_ scene: DirectorsChairCore.Scene, project: Project) -> String {
        var lines = [
            "Selected Scene: \(scene.name)",
            "  Description: \(scene.description)",
            "  Location: \(scene.location ?? "—") | Status: \(scene.productionStatus)"
        ]
        if !scene.dialogues.isEmpty {
            lines.append("  Dialogues (\(scene.dialogues.count)):")
            for dlg in scene.dialogues.prefix(20) {
                lines.append("    \(dlg.character): \"\(String(dlg.text.prefix(100)))\"")
            }
        }
        if !scene.actions.isEmpty {
            lines.append("  Actions (\(scene.actions.count)):")
            for act in scene.actions.prefix(10) {
                lines.append("    - \(String(act.description.prefix(100)))")
            }
        }
        if !scene.narrations.isEmpty {
            lines.append("  Narrations (\(scene.narrations.count)):")
            for nar in scene.narrations.prefix(5) {
                lines.append("    \"\(String(nar.text.prefix(100)))\"")
            }
        }
        if !scene.shots.isEmpty {
            lines.append("  Shots (\(scene.shots.count)):")
            for shot in scene.shots.prefix(10) {
                lines.append("    #\(shot.shotId): \(shot.shotType) \(shot.cameraAngle) - \(String(shot.description.prefix(60)))")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Level 3: All Names & Summaries

    private static func buildSummaries(project: Project) -> String {
        var lines: [String] = ["--- ALL PROJECT ITEMS ---"]

        // Characters
        if !project.characters.isEmpty {
            lines.append("Characters:")
            for char in project.characters {
                lines.append("  - \(char.name) (\(char.role), age \(char.age)): \(String(char.about.prefix(80)))")
            }
        }

        // Sequences & Scenes
        if !project.sequences.isEmpty {
            lines.append("Sequences & Scenes:")
            for seq in project.sequences {
                lines.append("  \(seq.name) (\(seq.scenes.count) scenes):")
                for scene in seq.scenes {
                    let dlgCount = scene.dialogues.count
                    let shotCount = scene.shots.count
                    lines.append("    - \(scene.name): \(String(scene.description.prefix(60))) [\(dlgCount) dlg, \(shotCount) shots, \(scene.productionStatus)]")
                }
            }
        }

        // Locations
        if !project.locations.isEmpty {
            lines.append("Locations:")
            for loc in project.locations {
                lines.append("  - \(loc.name) (\(loc.locationType)): \(String(loc.description.prefix(60)))")
            }
        }

        // Props
        if !project.props.isEmpty {
            lines.append("Props: \(project.props.map(\.name).joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Level 4: Domain-Specific Deep Detail

    private static func buildDeepDetail(project: Project, query: String) -> String {
        let q = query.lowercased()
        var lines: [String] = []

        // Budget domain
        if q.contains("budget") || q.contains("cost") || q.contains("expense") || q.contains("accounting") || q.contains("money") {
            if let budget = project.projectBudget {
                lines.append("--- BUDGET DETAIL ---")
                lines.append("Total Budget: \(budget.totalBudget)")
                for cat in budget.categories {
                    lines.append("  \(cat.name): allocated \(String(format: "%.2f", cat.allocated)), spent \(String(format: "%.2f", cat.spent))")
                }
            }
        }

        // Schedule domain
        if q.contains("schedule") || q.contains("shoot") || q.contains("date") || q.contains("plan") {
            if !project.scheduleItems.isEmpty {
                lines.append("--- SCHEDULE DETAIL ---")
                for item in project.scheduleItems.prefix(20) {
                    lines.append("  \(item.sceneName) [\(item.status)] date: \(item.shootDate ?? "—") loc: \(item.location ?? "—")")
                }
            }
        }

        // Cast & Crew domain
        if q.contains("cast") || q.contains("crew") || q.contains("actor") || q.contains("team") {
            if !project.castMembers.isEmpty {
                lines.append("--- CAST ---")
                for m in project.castMembers {
                    lines.append("  \(m.actorName) as \(m.characterName) | rate: \(m.dailyRate)")
                }
            }
            if !project.crewMembers.isEmpty {
                lines.append("--- CREW ---")
                for m in project.crewMembers {
                    lines.append("  \(m.name) - \(m.role) (\(m.department))")
                }
            }
        }

        // Character detail domain (all characters, full)
        if q.contains("character") || q.contains("trait") || q.contains("personality") || q.contains("relationship") {
            lines.append("--- ALL CHARACTER DETAILS ---")
            for char in project.characters {
                lines.append(characterDetail(char))
            }
        }

        return lines.joined(separator: "\n")
    }
}
