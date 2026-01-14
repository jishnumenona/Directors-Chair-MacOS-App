// DirectorsChairServices/Sources/DirectorsChairServices/CharacterAnalysis/CharacterAnalyzer.swift
//
// AI-Powered Character Trait Analysis Service
// Analyzes character personality traits based on dialogue and actions

import Foundation
import DirectorsChairCore

// MARK: - Dialogue Entry

/// A single dialogue or action from the script
public struct DialogueEntry: Sendable {
    public var sceneName: String
    public var sequenceName: String
    public var text: String
    public var type: EntryType
    public var context: String
    
    public enum EntryType: String, Sendable {
        case dialogue
        case action
        case narration
        case sceneDescription = "scene_description"
    }
    
    public init(sceneName: String, sequenceName: String, text: String, type: EntryType, context: String) {
        self.sceneName = sceneName
        self.sequenceName = sequenceName
        self.text = text
        self.type = type
        self.context = context
    }
}

// MARK: - Character Analysis Result

/// Result of AI character trait analysis
public struct CharacterAnalysisResult: Sendable {
    /// Trait scores (0-100 scale)
    public var traitScores: [String: Double]
    
    /// AI's overall reasoning
    public var reasoning: String
    
    /// Trait-specific explanations
    public var traitExplanations: [String: String]
    
    /// Confidence in the analysis (0-100)
    public var confidenceScore: Double
    
    /// Scenes where character appeared
    public var dataSources: [String]
    
    /// Identified character archetype
    public var archetype: String
    
    /// Key moments that defined the character
    public var keyMoments: [String]
    
    /// Comprehensive character bio/description
    public var characterDescription: String
    
    /// Physical appearance attributes extracted from script
    public var physicalAttributes: [String: String]
    
    /// Biography attributes extracted from script
    public var biographyAttributes: [String: String]
    
    public init(
        traitScores: [String: Double] = [:],
        reasoning: String = "",
        traitExplanations: [String: String] = [:],
        confidenceScore: Double = 0,
        dataSources: [String] = [],
        archetype: String = "",
        keyMoments: [String] = [],
        characterDescription: String = "",
        physicalAttributes: [String: String] = [:],
        biographyAttributes: [String: String] = [:]
    ) {
        self.traitScores = traitScores
        self.reasoning = reasoning
        self.traitExplanations = traitExplanations
        self.confidenceScore = confidenceScore
        self.dataSources = dataSources
        self.archetype = archetype
        self.keyMoments = keyMoments
        self.characterDescription = characterDescription
        self.physicalAttributes = physicalAttributes
        self.biographyAttributes = biographyAttributes
    }
}

// MARK: - Trait Definitions

/// The 25 personality traits used for character analysis
public struct CharacterTraits {
    /// All trait names
    public static let allTraits: [String] = [
        // Core Traits
        "confidence", "empathy", "intelligence", "creativity", "resilience",
        // Social Traits
        "charisma", "assertiveness", "cooperation", "trustworthiness", "humor",
        // Emotional Traits
        "emotional_stability", "optimism", "passion", "patience", "sensitivity",
        // Behavioral Traits
        "discipline", "adventurousness", "adaptability", "ambition", "integrity",
        // Cognitive Traits
        "analytical", "intuitive", "pragmatic", "visionary", "wisdom"
    ]
    
    /// Trait categories
    public static let categories: [String: [String]] = [
        "Core Traits": ["confidence", "empathy", "intelligence", "creativity", "resilience"],
        "Social Traits": ["charisma", "assertiveness", "cooperation", "trustworthiness", "humor"],
        "Emotional Traits": ["emotional_stability", "optimism", "passion", "patience", "sensitivity"],
        "Behavioral Traits": ["discipline", "adventurousness", "adaptability", "ambition", "integrity"],
        "Cognitive Traits": ["analytical", "intuitive", "pragmatic", "visionary", "wisdom"]
    ]
}

// MARK: - Character Analyzer Actor

/// AI-powered character trait analyzer
public actor CharacterAnalyzer {
    
    private let aiClient: AIServiceClient
    private let project: Project
    
    /// Initialize with a project
    public init(project: Project, aiClient: AIServiceClient = .shared) {
        self.project = project
        self.aiClient = aiClient
    }
    
    // MARK: - Data Collection
    
    /// Collect all available information about a character from the script
    public func collectCharacterData(character: Character) -> [DialogueEntry] {
        var entries: [DialogueEntry] = []
        var characterAppearsInScenes: Set<String> = []
        
        // First pass: identify scenes where character speaks
        for sequence in project.sequences {
            for scene in sequence.scenes {
                for dialogue in scene.dialogues {
                    if dialogue.character == character.name {
                        characterAppearsInScenes.insert("\(sequence.name)-\(scene.name)")
                        break
                    }
                }
            }
        }
        
        // Second pass: collect everything from scenes where character appears
        for sequence in project.sequences {
            let sequenceName = sequence.name.isEmpty ? "Untitled Sequence" : sequence.name
            
            for scene in sequence.scenes {
                let sceneName = scene.name.isEmpty ? "Untitled Scene" : scene.name
                let sceneKey = "\(sequence.name)-\(scene.name)"
                let characterIsInScene = characterAppearsInScenes.contains(sceneKey)
                
                if characterIsInScene {
                    // Scene description
                    if !scene.description.isEmpty {
                        entries.append(DialogueEntry(
                            sceneName: sceneName,
                            sequenceName: sequenceName,
                            text: "SCENE DESCRIPTION: \(scene.description)",
                            type: .sceneDescription,
                            context: "Location: \(scene.location ?? "Unknown")"
                        ))
                    }

                    // All actions in this scene
                    for action in scene.actions {
                        if !action.description.isEmpty {
                            entries.append(DialogueEntry(
                                sceneName: sceneName,
                                sequenceName: sequenceName,
                                text: action.description,
                                type: .action,
                                context: scene.description
                            ))
                        }
                    }

                    // All narrations
                    for narration in scene.narrations {
                        if !narration.text.isEmpty {
                            entries.append(DialogueEntry(
                                sceneName: sceneName,
                                sequenceName: sequenceName,
                                text: narration.text,
                                type: .narration,
                                context: scene.description
                            ))
                        }
                    }
                }

                // Collect character's dialogue (always)
                for dialogue in scene.dialogues {
                    if dialogue.character == character.name {
                        entries.append(DialogueEntry(
                            sceneName: sceneName,
                            sequenceName: sequenceName,
                            text: dialogue.text,
                            type: .dialogue,
                            context: scene.description
                        ))
                    }
                }
            }
        }
        
        return entries
    }
    
    // MARK: - Analysis
    
    /// Perform AI-powered character trait analysis
    public func analyzeCharacter(
        _ character: Character,
        progressCallback: (@Sendable (Int) -> Void)? = nil
    ) async throws -> CharacterAnalysisResult {
        
        // Step 1: Collect character data (0% -> 20%)
        let entries = collectCharacterData(character: character)
        progressCallback?(20)
        
        if entries.isEmpty {
            throw AIClientError.invalidConfiguration(
                "No dialogue or actions found for \(character.name) in the script. The character must appear in scenes to be analyzed."
            )
        }
        
        // Step 2: Build analysis prompt (20% -> 40%)
        let prompt = buildAnalysisPrompt(character: character, entries: entries)
        progressCallback?(40)
        
        // Step 3: Call AI service (40% -> 70%)
        let request = TextGenerationRequest(
            prompt: prompt,
            provider: .googleGemini,
            maxTokens: 8000,
            temperature: 0.1
        )
        
        let response = try await aiClient.generateText(request)
        progressCallback?(70)
        
        // Step 4: Parse response (70% -> 90%)
        let result = try parseAnalysisResponse(response.text, character: character)
        progressCallback?(90)
        
        return result
    }
    
    // MARK: - Prompt Building
    
    private func buildAnalysisPrompt(character: Character, entries: [DialogueEntry]) -> String {
        let dialogueSummary = formatDialogueEntries(entries)
        let traitGuide = buildTraitGuide()
        
        return """
        # COMPREHENSIVE PSYCHO-SOMATIC CHARACTER ANALYSIS
        
        You are an expert clinical psychologist, behavioral analyst, and literary character specialist. Your task is to perform a DEEP psycho-somatic analysis of "\(character.name)" based on EVERY piece of available information from the story.
        
        ## CHARACTER CONTEXT
        
        **Name:** \(character.name)
        **Role/Profession:** \(character.role.isEmpty ? "Unknown" : character.role)
        **Background:** \(character.backgroundStory ?? "Not provided")
        **Age:** \(character.age)
        **Gender:** \(character.gender.isEmpty ? "Unknown" : character.gender)
        
        ## COMPLETE SCRIPT ANALYSIS
        
        \(dialogueSummary)
        
        ## YOUR TASK: PSYCHO-SOMATIC PERSONALITY ANALYSIS
        
        Perform a complete psycho-somatic analysis across 25 distinct personality traits (0-100 scale).
        
        \(traitGuide)
        
        ## OUTPUT FORMAT
        
        Provide your analysis as a valid JSON object with this exact structure:
        
        ```json
        {
          "trait_scores": {
            "confidence": 75,
            "empathy": 60,
            ... (all 25 traits with scores 0-100)
          },
          "reasoning": "Overall 2-3 paragraph analysis...",
          "trait_explanations": {
            "confidence": "Specific evidence...",
            ...
          },
          "confidence_score": 85,
          "archetype": "Hero / Villain / Mentor / etc.",
          "key_moments": ["Scene 1...", "Scene 2..."],
          "character_description": "A comprehensive 2-3 paragraph character biography...",
          "physical_attributes": {
            "age": "30",
            "gender": "male",
            "build": "Athletic",
            "height": "6ft 2in",
            "hair_color": "Dark brown",
            "eye_color": "Blue"
          },
          "biography_attributes": {
            "occupation": "Job or profession",
            "role": "Story role",
            "primary_goal": "Main objective",
            "primary_fear": "What character fears most"
          }
        }
        ```
        
        **Required traits:** \(CharacterTraits.allTraits.joined(separator: ", "))
        
        Return ONLY the JSON object - no text before or after.
        """
    }
    
    private func formatDialogueEntries(_ entries: [DialogueEntry]) -> String {
        if entries.isEmpty {
            return "**NO DIALOGUE OR ACTIONS FOUND**"
        }
        
        // Limit entries to prevent token overflow
        let maxEntries = 150
        var limitedEntries = entries
        if entries.count > maxEntries {
            let step = Double(entries.count) / Double(maxEntries)
            limitedEntries = (0..<maxEntries).map { entries[Int(Double($0) * step)] }
        }
        
        var formatted: [String] = []
        var scenes: [String: [DialogueEntry]] = [:]
        
        // Group by scene
        for entry in limitedEntries {
            let sceneKey = "\(entry.sequenceName) → \(entry.sceneName)"
            if scenes[sceneKey] == nil {
                scenes[sceneKey] = []
            }
            scenes[sceneKey]?.append(entry)
        }
        
        // Format each scene
        for (sceneKey, sceneEntries) in scenes.sorted(by: { $0.key < $1.key }) {
            formatted.append("### \(sceneKey)\n")
            
            for entry in sceneEntries {
                switch entry.type {
                case .sceneDescription:
                    formatted.append("**[SCENE SETTING]** \(entry.text)")
                case .dialogue:
                    formatted.append("**[DIALOGUE]** \(entry.text)")
                case .action:
                    formatted.append("**[ACTION/BEHAVIOR]** \(entry.text)")
                case .narration:
                    formatted.append("**[NARRATION]** \(entry.text)")
                }
            }
            formatted.append("")
        }
        
        return formatted.joined(separator: "\n")
    }
    
    private func buildTraitGuide() -> String {
        var guide: [String] = []
        
        for (category, traits) in CharacterTraits.categories {
            guide.append("\n### \(category.uppercased())")
            for trait in traits {
                guide.append("- **\(trait)** (0-100): Score based on evidence from script")
            }
        }
        
        return guide.joined(separator: "\n")
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(_ responseText: String, character: Character) throws -> CharacterAnalysisResult {
        var jsonText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks
        if jsonText.hasPrefix("```json") {
            jsonText = String(jsonText.dropFirst(7))
        }
        if jsonText.hasPrefix("```") {
            jsonText = String(jsonText.dropFirst(3))
        }
        if jsonText.hasSuffix("```") {
            jsonText = String(jsonText.dropLast(3))
        }
        jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to extract just the JSON object
        if let firstBrace = jsonText.firstIndex(of: "{"),
           let lastBrace = jsonText.lastIndex(of: "}") {
            jsonText = String(jsonText[firstBrace...lastBrace])
        }
        
        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.invalidResponse("Could not parse AI response as JSON")
        }
        
        // Extract trait scores
        var traitScores: [String: Double] = [:]
        if let scores = json["trait_scores"] as? [String: Any] {
            for trait in CharacterTraits.allTraits {
                if let score = scores[trait] as? Double {
                    traitScores[trait] = min(100, max(0, score))
                } else if let score = scores[trait] as? Int {
                    traitScores[trait] = min(100, max(0, Double(score)))
                } else {
                    traitScores[trait] = 50.0 // Default
                }
            }
        }
        
        // Extract other fields
        let reasoning = json["reasoning"] as? String ?? ""
        let traitExplanations = json["trait_explanations"] as? [String: String] ?? [:]
        let confidenceScore = (json["confidence_score"] as? Double) ?? (json["confidence_score"] as? Int).map { Double($0) } ?? 70.0
        let archetype = json["archetype"] as? String ?? "Unknown"
        let keyMoments = json["key_moments"] as? [String] ?? []
        let characterDescription = json["character_description"] as? String ?? ""
        let physicalAttributes = json["physical_attributes"] as? [String: String] ?? [:]
        let biographyAttributes = json["biography_attributes"] as? [String: String] ?? [:]
        
        return CharacterAnalysisResult(
            traitScores: traitScores,
            reasoning: reasoning,
            traitExplanations: traitExplanations,
            confidenceScore: confidenceScore,
            dataSources: [],
            archetype: archetype,
            keyMoments: keyMoments,
            characterDescription: characterDescription,
            physicalAttributes: physicalAttributes,
            biographyAttributes: biographyAttributes
        )
    }
}
