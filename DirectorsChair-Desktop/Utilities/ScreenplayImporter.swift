//
//  ScreenplayImporter.swift
//  DirectorsChair-Desktop
//
//  AI-powered screenplay PDF importer that generates rich DirectorsChair projects
//  Uses multi-pass AI generation to work within proxy timeout limits
//

import Foundation
import PDFKit
import DirectorsChairCore
import DirectorsChairServices

/// Observable progress tracker for screenplay import
@MainActor
class ImportProgressTracker: ObservableObject {
    @Published var progress: Double = 0
    @Published var stepLabel: String = "Preparing..."
    @Published var logMessages: [LogEntry] = []
    @Published var isDebugExpanded: Bool = false

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let isError: Bool

        var timeString: String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f.string(from: timestamp)
        }
    }

    func update(progress: Double, step: String) {
        self.progress = min(progress, 1.0)
        self.stepLabel = step
    }

    func log(_ message: String, isError: Bool = false) {
        logMessages.append(LogEntry(timestamp: Date(), message: message, isError: isError))
    }
}

/// AI-powered screenplay importer that generates rich, detailed DirectorsChair projects
/// Uses a multi-pass approach: metadata → characters → production elements → scenes
/// to produce comprehensive project data within API timeout constraints.
struct ScreenplayImporter {

    // MARK: - Types

    struct ImportResult {
        let project: Project
        let stats: ImportStats
    }

    struct ImportStats {
        let sceneCount: Int
        let shotCount: Int
        let dialogueCount: Int
        let actionCount: Int
        let characterCount: Int
        let soundNoteCount: Int
        let propCount: Int
        let locationCount: Int
    }

    enum ImportError: LocalizedError {
        case cannotOpenPDF
        case noTextExtracted
        case aiGenerationFailed(String)
        case jsonParsingFailed(String)

        var errorDescription: String? {
            switch self {
            case .cannotOpenPDF:
                return "Could not open the PDF file. It may be corrupted or password-protected."
            case .noTextExtracted:
                return "No text could be extracted from the PDF. It may be an image-only PDF."
            case .aiGenerationFailed(let reason):
                return "AI generation failed: \(reason)"
            case .jsonParsingFailed(let reason):
                return "Failed to parse AI response into project: \(reason)"
            }
        }
    }

    // MARK: - Public API

    /// Import a screenplay from a PDF file using AI (multi-pass)
    static func importFromPDF(url: URL, projectName: String, progress: ImportProgressTracker? = nil) async throws -> ImportResult {
        // 1. Extract text from PDF
        await progress?.update(progress: 0.02, step: "Extracting text from PDF...")
        await progress?.log("Opening PDF: \(url.lastPathComponent)")
        let text = try extractText(from: url)
        await progress?.update(progress: 0.05, step: "PDF text extracted")
        await progress?.log("Extracted \(text.count) characters from PDF")

        // 2. Multi-pass AI generation
        // Pass 1: Metadata
        await progress?.update(progress: 0.05, step: "Pass 1/5: Analyzing metadata...")
        await progress?.log("Pass 1: Generating project metadata via Google Gemini")
        let metadata = try await generateMetadata(screenplayText: text, projectName: projectName)
        await progress?.update(progress: 0.15, step: "Metadata complete")
        await progress?.log("Pass 1 complete: director=\(metadata["director"] ?? "?"), genre=\(metadata["genre"] ?? "?")")

        // Pass 2: Characters
        await progress?.update(progress: 0.15, step: "Pass 2/5: Extracting characters...")
        await progress?.log("Pass 2: Extracting characters via Google Gemini")
        let characters = try await generateCharacters(screenplayText: text)
        await progress?.update(progress: 0.30, step: "\(characters.count) characters found")
        let charNames = characters.compactMap { $0["name"] as? String }.joined(separator: ", ")
        await progress?.log("Pass 2 complete: \(characters.count) characters (\(charNames))")

        // Pass 3: Production elements
        await progress?.update(progress: 0.30, step: "Pass 3/5: Extracting production elements...")
        await progress?.log("Pass 3: Extracting props, locations, lighting, effects")
        let production = try await generateProductionElements(screenplayText: text)
        let propCount = (production["props"] as? [Any])?.count ?? 0
        let locCount = (production["locations"] as? [Any])?.count ?? 0
        let lightCount = (production["lighting"] as? [Any])?.count ?? 0
        let fxCount = (production["effects"] as? [Any])?.count ?? 0
        await progress?.update(progress: 0.45, step: "\(propCount) props, \(locCount) locations")
        await progress?.log("Pass 3 complete: \(propCount) props, \(locCount) locations, \(lightCount) lighting, \(fxCount) effects")

        // Extract prop names and character names from earlier passes to feed into scene generation
        let propNames: [String] = (production["props"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let characterNames: [String] = characters.compactMap { $0["name"] as? String }

        // Pass 4: Scene list
        await progress?.update(progress: 0.45, step: "Pass 4/5: Breaking down scenes...")
        await progress?.log("Pass 4: Generating scene breakdown")
        let sceneList = try await generateSceneList(screenplayText: text, propNames: propNames, characterNames: characterNames)
        let totalShots = sceneList.reduce(0) { $0 + ((($1["shot_numbers"] as? [Any])?.count) ?? 0) }
        await progress?.update(progress: 0.55, step: "\(sceneList.count) scenes identified")
        await progress?.log("Pass 4 complete: \(sceneList.count) scenes, \(totalShots) total shots")

        // Pass 5: Scene contents
        await progress?.update(progress: 0.55, step: "Pass 5/5: Generating scene content...")
        await progress?.log("Pass 5: Generating detailed content for \(sceneList.count) scenes")
        let scenes = try await generateSceneContents(screenplayText: text, sceneList: sceneList, propNames: propNames, characterNames: characterNames, progress: progress)

        // 3. Assemble into Project
        await progress?.update(progress: 0.95, step: "Assembling project...")
        await progress?.log("Assembling final project from all passes")
        let project = assembleProject(
            projectName: projectName,
            metadata: metadata,
            characters: characters,
            production: production,
            scenes: scenes
        )

        // 4. Compute stats
        let stats = computeStats(from: project)
        await progress?.update(progress: 1.0, step: "Import complete!")
        await progress?.log("Done! \(stats.sceneCount) scenes, \(stats.shotCount) shots, \(stats.dialogueCount) dialogues, \(stats.characterCount) characters")

        return ImportResult(project: project, stats: stats)
    }

    // MARK: - PDF Text Extraction

    static func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.cannotOpenPDF
        }

        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText
                fullText += "\n"
            }
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportError.noTextExtracted
        }

        return fullText
    }

    // MARK: - Pass 1: Metadata

    private static func generateMetadata(screenplayText: String, projectName: String) async throws -> [String: Any] {
        let prompt = """
        Read this screenplay and output a JSON object with these exact keys:
        - name: "\(projectName)"
        - description: one concise evocative sentence (like a DVD cover)
        - director: director name. Look for "Written by", "Screenplay by", "By", "Director", or "A film by" on the title page or header. If you find a writer/creator name, use that as director. Only use "Unknown" if absolutely no name is found anywhere in the screenplay.
        - production_company: from title page or ""
        - genre: single genre word like "Drama", "Thriller", "Comedy"
        - project_type: "Short Film", "Feature Film", or "Skit" (based on screenplay length)
        - status: "Pre-production"
        - languages: array of languages. Start with "English". If the screenplay contains words, songs, or cultural elements from a SPECIFIC non-English language (e.g. "paattupetty" is Malayalam, not Hindi), include that exact language. Do NOT include "Hindi" unless Hindi is explicitly spoken. Malayalam and Hindi are DIFFERENT languages - Indian cultural elements are not automatically Hindi.
        - overview_tagline: SHORT punchy memorable tagline (under 10 words, like a movie poster)
        - overview_logline: one compelling sentence logline
        - overview_summary: concise pitch paragraph (production-oriented, not analytical)
        - overview_mood_analysis: {"emotion_name": 0.0-1.0} for 5-8 emotions. Use evocative keys like "nostalgia", "intimacy", "melancholy", "tension", "hope", "serenity", "ambiguity"
        - project_notes: practical production notes for the director (mention visual approaches like B&W flashback, dual versions, narrative structure). Write as if for a production meeting, not a film review.
        - target_duration: estimated runtime like "15 minutes" based on page count (roughly 1 min per page)

        Output ONLY valid JSON, no markdown fences.

        Screenplay:
        ---
        \(screenplayText)
        ---
        """

        let json = try await callAI(prompt: prompt, systemPrompt: "You analyze screenplays and output metadata as JSON. Output ONLY valid JSON.", provider: .google, maxTokens: 65000)
        return try parseJSON(json) as? [String: Any] ?? [:]
    }

    // MARK: - Pass 2: Characters

    private static func generateCharacters(screenplayText: String) async throws -> [[String: Any]] {
        let prompt = """
        Read this screenplay and extract ALL characters. Output a JSON array of character objects.

        Each character needs ALL of these fields:
        - character_id: unique string like "char_thara_001"
        - name: character's proper name as used in the screenplay
        - role: "Protagonist", "Supporting", or "Antagonist". Use "Supporting" for characters who are absent/remembered/catalysts. Only use "Antagonist" for characters who actively oppose the protagonist.
        - color: hex color string like "#4A90D9" (unique per character)
        - text_color: "#FFFFFF"
        - about: 2-3 sentences, production-focused description of who they are
        - gender: "female", "male", "neutral"
        - ethnicity: inferred from cultural context (e.g. "South Asian", "Indian")
        - age: integer
        - background_story: paragraph of backstory inferred from screenplay context
        - character_arc_notes: concise arc description (e.g. "From emotional paralysis to decisive action")
        - hair_color: HEX color string (e.g. "#1A1A1A" for black, "#8B4513" for brown). MUST be a hex color code, NOT a word.
        - hair_style: text description (e.g. "Long, sometimes loose, sometimes tied up")
        - hair_length: text (e.g. "Long", "Short", "Medium")
        - eye_color: HEX color string (e.g. "#8B4513" for brown). MUST be a hex color code.
        - eye_color_description: text description (e.g. "Dark brown, expressive")
        - skin_tone: HEX color string (e.g. "#f5deb3" for wheat, "#D2B48C" for tan). MUST be a hex color code.
        - relationships: {"OtherCharacterName": "brief description of their relationship"}
        - costumes: [{"name": "descriptive costume name with scene context", "description": "detailed wardrobe description", "created_at": "2026-02-06T00:00:00Z"}]
        - traits: object with EXACTLY these 25 keys (no more, no less), each an integer 0-100:
          confidence, empathy, aggression, optimism, anxiety,
          intelligence, creativity, wisdom, curiosity, logic,
          charisma, humor, manipulation, leadership, loyalty,
          honesty, courage, compassion, justice, selflessness,
          strength, agility, stamina, coordination, reflexes
          Do NOT add extra traits like "courtesy" or rename any trait. Use EXACTLY these 25 key names.
        - traits_data_sources: []

        IMPORTANT RULES:
        - For animals (dogs, cats, etc.): still use hex colors for hair_color/eye_color/skin_tone, leave ethnicity as ""
        - Do NOT list furniture/objects as costumes. Costumes are ONLY what a character wears.
        - All color fields (hair_color, eye_color, skin_tone) MUST be hex codes like "#RRGGBB", never text words.

        Output ONLY a valid JSON array, no markdown fences.

        Screenplay:
        ---
        \(screenplayText)
        ---
        """

        let json = try await callAI(prompt: prompt, systemPrompt: "Extract characters from screenplays. Output ONLY a valid JSON array.", provider: .google, maxTokens: 65000)
        return try parseJSON(json) as? [[String: Any]] ?? []
    }

    // MARK: - Pass 3: Production Elements

    private static func generateProductionElements(screenplayText: String) async throws -> [String: Any] {
        let prompt = """
        Read this screenplay and extract production elements into a JSON object with 4 arrays:

        "props": Physical objects the production department needs to acquire/build. Each prop:
        {"id": "prop_XXXX", "name": "...", "description": "...", "category": "...", "notes": "narrative significance", "reference_photos": [], "handling_instructions": "", "safety_notes": "", "detailed_specs": "", "tags": []}

        PROP RULES:
        - AGGRESSIVELY consolidate related items: "Tea Kettle and Ceramic Cup" is ONE prop, "Chopping Board and Knife" is ONE prop, "Colorful Bowls and Fruit Tray" is ONE prop, "Breakfast Plate" (including fork, egg, potatoes) is ONE prop
        - If the same object appears in different states (e.g. dried flowers vs fresh flowers), list it ONCE and note the variations in the description
        - If there is a hanging plant AND a money plant, they are ONE prop: "Hanging Plant / Money Plant". Do NOT create separate entries for the same plant or different plants in the same location.
        - Do NOT create a "Cooking Setup" or "Pan and Utensils" prop - cooking equipment is part of the kitchen set dressing, not a standalone prop
        - Do NOT list character clothing/hair as props (those are costumes on the character)
        - Do NOT list large furniture (beds, curtains, walls, countertops) as props
        - Do NOT list consumables (flour, eggs, potatoes, tea) as separate props
        - Do NOT list cooking pans, plates, forks, mixing bowls, or kitchen utensils as separate individual props
        - Do NOT list wall decorations (pictures on wall) unless they are specifically handled by characters
        - ALWAYS include a "Dog Bed" if there is a dog/puppy character that sleeps or has a sleeping area. Dog beds are props the production team must acquire.
        - Aim for exactly 10-12 props total. Each should be a distinct, notable physical object the props department needs to acquire. If you have more than 12, consolidate further.

        "locations": Each PHYSICAL location (not different states of the same location). Each location:
        {"name": "...", "description": "rich production design description covering all its states/moods across the screenplay", "notes": "...", "location_type": "indoor" or "outdoor", "tags": [], "address": "", "gps_coordinates": "", "images": [], "reference_images": [], "style_attributes": {"color_palette": "...", "mood": "...", "texture": "..."}, "cinematography_defaults": {}, "cinema_environment_variations": [], "attributes": {}}

        LOCATION RULES:
        - A bedroom that appears dark in one scene and bright in another is ONE location ("Bedroom"), NOT two
        - A kitchen in present-day and in flashback is ONE location ("Kitchen"), NOT two
        - Describe the different looks in the "description" and "cinema_environment_variations" fields
        - Include ALL distinct physical spaces, especially transitional ones (aisles, corridors, hallways, doorways, staircases) that characters move through. These are important for production planning even if they appear briefly.
        - If a character walks from one room to another through an aisle or hallway, that connecting space is its own location

        "lighting": Each distinct lighting setup. Each:
        {"name": "...", "type": "...", "color": "#hex", "intensity": 0.0-1.0, "position": "...", "notes": "..."}
        Note: intensity is a float from 0.0 to 1.0 (not 0-100).

        "effects": ONLY post-production visual effects. Each:
        {"name": "...", "category": "...", "notes": "...", "params": {}}

        EFFECTS RULES:
        - Only include these 3 types: color grading (B&W, desaturation), speed effects (slow motion), transition styles (fade in/out)
        - You should have EXACTLY 3 effects for a typical screenplay. Do NOT add more than 3 unless the screenplay explicitly calls for additional post-production effects.
        - Do NOT include "character fade", "opacity reduction", "shadow effects", or any in-camera effects — those are shot/blocking descriptions, not post-production effects
        - Do NOT include sound effects (those go in sound_notes)
        - Do NOT include camera movements (those are shot attributes)
        - Do NOT include "black screen" or "blackout" as effects (those are editing transitions)

        Output ONLY valid JSON, no markdown fences.

        Screenplay:
        ---
        \(screenplayText)
        ---
        """

        let json = try await callAI(prompt: prompt, systemPrompt: "Extract production elements from screenplays. Output ONLY valid JSON.", provider: .google, maxTokens: 65000)
        return try parseJSON(json) as? [String: Any] ?? [:]
    }

    // MARK: - Pass 4: Scene List

    private static func generateSceneList(screenplayText: String, propNames: [String], characterNames: [String]) async throws -> [[String: Any]] {
        let propListStr = propNames.joined(separator: ", ")
        let charListStr = characterNames.joined(separator: ", ")

        let prompt = """
        Read this screenplay and list ALL scenes. Output a JSON array where each element is:
        {
          "scene_number": 1,
          "heading": "INT. BEDROOM. DAY. MORNING",
          "name": "Scene 1 - Bedroom Morning (Dark)",
          "description": "paragraph summary of what happens in this scene",
          "location": "Bedroom",
          "primary_character": "CharacterName",
          "production_status": "Planning",
          "props": ["Phone", "Flower Vase"],
          "scene_emotional_analysis": {"tension": 0.5, "melancholy": 0.3},
          "scene_overview_summary": "one evocative sentence summary",
          "notes": "practical production direction notes",
          "scene_notes": [
            {"uuid": "UUID-string", "title": "Unique Note Title", "content": "bespoke director's note specific to this scene", "note_type": "text", "chronology_number": 1, "metadata": {}},
            {"uuid": "UUID-string", "title": "Another Unique Title", "content": "another specific production note", "note_type": "text", "chronology_number": 2, "metadata": {}}
          ],
          "shot_numbers": [1, 2, 3]
        }

        CHARACTER NAMES (use these exact names): \(charListStr)
        PROP INVENTORY (use ONLY these exact names in the props array): \(propListStr)

        IMPORTANT RULES:
        - Name format: "Scene N - Location Description (Context)" e.g. "Scene 1 - Bedroom Morning (Dark)"
        - Use proper character names (not "Woman" or "Man")
        - scene_notes: Generate 2-3 BESPOKE production notes per scene. Each note title should be UNIQUE and specific to this scene's content. Do NOT use generic category titles like "Production Design" or "Lighting Direction" for every scene. Instead use titles that describe the specific note, like:
          * "Phone as Primary Light Source" → "Phone screen should be the only light source. No other practicals."
          * "Delayed Face Reveal" → "Keep Thara in silhouette until she turns. The face reveal is deliberate."
          * "Music Box Sound Continuity" → "The Lata Mangeshkar melody continues through the cut into the next scene."
          * "Floaty Dreamlike Camera" → "All flashback shots feel floaty and ethereal. Camera never fully settles."
          * "Emotional Climax Pacing" → "The rhythm should feel like memories surfacing and submerging."
          * "Narrative Ambiguity" → "The ending is deliberately ambiguous - she may be answering or declining."
          Write as practical crew instructions specific to what happens in THIS scene. Each note should give a concrete, actionable direction.
        - shot_numbers: list the SHOT numbers from the screenplay that belong to this scene. If a scene has no explicit SHOT markers, still list it as a scene.
        - scene_overview_summary: write a short evocative sentence, not a verbose analysis
        - props: ONLY use names from the PROP INVENTORY list above. Do NOT invent new prop names, break consolidated items apart, or list consumables (flour, eggs, potatoes). If a prop from the inventory appears in this scene, use its exact name.
        - For flashback scenes: only include props that are explicitly described or handled in the flashback itself (e.g. chopping board if characters cook, phone if they take selfies). Do NOT include decorative props from the present-day version of the same location.

        Include ALL scenes from the screenplay.

        Output ONLY valid JSON array, no markdown fences.

        Screenplay:
        ---
        \(screenplayText)
        ---
        """

        let json = try await callAI(prompt: prompt, systemPrompt: "List screenplay scenes with metadata. Output ONLY valid JSON.", provider: .google, maxTokens: 65000)
        return try parseJSON(json) as? [[String: Any]] ?? []
    }

    // MARK: - Pass 5: Scene Contents (shots, dialogues, actions, sound notes)

    private static func generateSceneContents(screenplayText: String, sceneList: [[String: Any]], propNames: [String], characterNames: [String], progress: ImportProgressTracker? = nil) async throws -> [[String: Any]] {
        var allScenes: [[String: Any]] = []
        let sceneCount = sceneList.count
        let propListStr = propNames.joined(separator: ", ")
        let charListStr = characterNames.joined(separator: ", ")

        for (index, sceneInfo) in sceneList.enumerated() {
            let sceneName = sceneInfo["name"] as? String ?? "Unknown Scene"
            let sceneNum = sceneInfo["scene_number"] as? Int ?? 0
            let shotNumbers = sceneInfo["shot_numbers"] as? [Int] ?? []

            // Progress: distribute 0.55 → 0.95 across scenes
            let sceneProgress = 0.55 + (Double(index) / Double(max(sceneCount, 1))) * 0.40
            await progress?.update(progress: sceneProgress, step: "Scene \(index + 1)/\(sceneCount): \(sceneName)")
            await progress?.log("Scene \(sceneNum): Generating content for \"\(sceneName)\" (\(shotNumbers.count) shots)")

            let shotRange = shotNumbers.isEmpty ? "all shots in scene \(sceneNum)" : "SHOT \(shotNumbers.map { String($0) }.joined(separator: ", SHOT "))"

            let sceneDescription = sceneInfo["description"] as? String ?? ""

            let prompt = """
            Read this screenplay and generate the COMPLETE content for Scene \(sceneNum) ("\(sceneName)").
            Scene description: \(sceneDescription)
            This scene contains: \(shotRange)

            CHARACTER NAMES (use these exact names, never generic labels): \(charListStr)
            PROP INVENTORY (use these exact prop names when referencing props): \(propListStr)

            Output a JSON object with these arrays for this scene ONLY:

            "dialogues": [{"uuid": "UUID-string", "character": "CharacterName", "text": "exact dialogue text from screenplay", "tags": ["emotion"], "costumes": ["costume description"], "effects": [], "chronology_number": 1, "global_chronology_number": 1}]

            "actions": [{"uuid": "UUID-string", "description": "full coherent action paragraph (combine multi-line stage directions into flowing prose)", "characters": ["CharacterName"], "costumes": ["costume description if mentioned"], "effects": ["effect name if applicable, e.g. Black and White Grade"], "tags": ["evocative mood tag like flashback, romance, tension, release"], "color": "", "text_color": "", "chronology_number": 1, "global_chronology_number": 1}]

            "shots": [{"shot_id": 1, "item_chronology": 1, "description": "FULL shot description with camera angle, subject, action from the screenplay", "status": "Planning", "camera_angle": "Eye Level/Low Angle/High Angle/45 Degree", "lens_mm": 50, "aperture": "f/2.8", "shot_type": "Extreme Close-up/Close-up/Medium/Wide/Medium to Wide", "movement": "Static/Zoom Out/Follow/Pan/Tilt/Dolly/Sliding/Push-in/Floating", "linked_dialogue_ids": [], "linked_action_ids": [], "linked_narration_ids": [], "reference_media": []}]

            "sound_notes": [{"uuid": "UUID-string", "description": "detailed sound description with emotional context (e.g. 'Phone rings, piercing through the silence. Should feel jarring against the established calm.')", "sound_type": "ambient/music/effects", "chronology_number": 1, "tags": ["tag"], "volume": 80, "loop": false, "fade_in_duration": 0, "fade_out_duration": 0}]

            CRITICAL RULES:
            1. EVERY scene MUST have at least one action and one shot, even if no explicit SHOT markers exist. If there are no SHOT markers, create shots based on the visual content described.
            2. Each SHOT mentioned in the screenplay (SHOT 1, SHOT 2, etc.) becomes its own Shot object. shot_id MUST be an integer.
            3. ALWAYS use proper character names (e.g. "Thara", "Manu", "Lilly"), NEVER generic labels like "Woman", "Man", "Dog". This applies to dialogues, actions, and shots.
            4. Combine multi-line stage directions into single coherent action descriptions as flowing prose paragraphs.
            5. Include ALL dialogues from this scene, preserving exact text and proper capitalization.
            6. For scenes with B&W/flashback content, mark effects on EVERY action in the scene: ["Black and White Grade", "Fade In/Fade Out Transitions"]. ALL actions in a flashback scene get these effects, not just the first one.
            7. Sound volumes should be calibrated realistically: ambient=60-70, normal=75-85, loud/jarring=90-95. Do NOT set everything to 100.
            8. Sound descriptions should include emotional context and production direction.
            9. For linked_action_ids and linked_dialogue_ids on shots: use the uuid values from the actions/dialogues that the shot covers.
            10. If there are no explicit SHOT markers in a scene, create shots that cover the visual beats described in the stage directions. Vary camera angles and movements.
            11. camera_angle and shot_type are DIFFERENT fields. camera_angle is the vertical angle: "Eye Level", "Low Angle", "High Angle", "45 Degree", "Over Shoulder", "Bird's Eye". shot_type is the framing: "Extreme Close-up", "Close-up", "Medium", "Wide", "Medium to Wide". Never put a shot_type value in camera_angle.
            12. For flashback/dream scenes, use "Floating" as the movement for all shots (not just the first one). Flashback shots should feel dreamy throughout.
            13. Capture ALL animal sounds (barking, whimpering, etc.) as sound_notes. Dog barks and animal reactions are important sound cues for the sound designer.
            14. For flashback/dream scenes, add an ambient sound_note describing the dreamy/ethereal soundscape (e.g. "Soft, dreamy ambient tone underlaying the flashback. Slightly reverbed and warm."). Flashbacks always need an ambient layer.

            Output ONLY valid JSON, no markdown fences.

            Screenplay:
            ---
            \(screenplayText)
            ---
            """

            do {
                let json = try await callAI(prompt: prompt, systemPrompt: "Generate scene content from screenplay. Output ONLY valid JSON.", provider: .google, maxTokens: 65000)
                var sceneContent = try parseJSON(json) as? [String: Any] ?? [:]

                // Merge scene metadata from sceneList
                for (key, value) in sceneInfo {
                    if key != "shot_numbers" && sceneContent[key] == nil {
                        sceneContent[key] = value
                    }
                }

                // Ensure required arrays exist
                if sceneContent["narrations"] == nil { sceneContent["narrations"] = [] as [Any] }
                if sceneContent["location_images"] == nil { sceneContent["location_images"] = [] as [Any] }
                if sceneContent["stage"] == nil { sceneContent["stage"] = [:] as [String: Any] }

                let shotCount = (sceneContent["shots"] as? [Any])?.count ?? 0
                let dlgCount = (sceneContent["dialogues"] as? [Any])?.count ?? 0
                let actCount = (sceneContent["actions"] as? [Any])?.count ?? 0
                await progress?.log("Scene \(sceneNum) complete: \(shotCount) shots, \(dlgCount) dialogues, \(actCount) actions")
                allScenes.append(sceneContent)
            } catch {
                // If a scene fails, add it with just the metadata
                var fallbackScene = sceneInfo
                fallbackScene["dialogues"] = [] as [Any]
                fallbackScene["actions"] = [] as [Any]
                fallbackScene["shots"] = [] as [Any]
                fallbackScene["sound_notes"] = [] as [Any]
                fallbackScene["narrations"] = [] as [Any]
                fallbackScene["location_images"] = [] as [Any]
                fallbackScene["stage"] = [:] as [String: Any]
                allScenes.append(fallbackScene)
                await progress?.log("Scene \(sceneNum) FAILED: \(error.localizedDescription)", isError: true)
                debugLog("Scene \(sceneNum) generation failed, using metadata only: \(error)")
            }
        }

        return allScenes
    }

    // MARK: - Assembly

    private static func assembleProject(
        projectName: String,
        metadata: [String: Any],
        characters: [[String: Any]],
        production: [String: Any],
        scenes: [[String: Any]]
    ) -> Project {
        // Build the complete project JSON
        var projectDict: [String: Any] = [:]

        // Metadata
        projectDict["name"] = projectName
        projectDict["description"] = metadata["description"] ?? ""
        projectDict["director"] = metadata["director"] ?? ""
        projectDict["production_company"] = metadata["production_company"] ?? ""
        projectDict["genre"] = metadata["genre"] ?? ""
        projectDict["project_type"] = metadata["project_type"] ?? "Short Film"
        projectDict["status"] = "Pre-production"
        projectDict["languages"] = metadata["languages"] ?? ["English"]
        projectDict["overview_tagline"] = metadata["overview_tagline"] ?? ""
        projectDict["overview_logline"] = metadata["overview_logline"] ?? ""
        projectDict["overview_summary"] = metadata["overview_summary"] ?? ""
        projectDict["overview_mood_analysis"] = metadata["overview_mood_analysis"]
        projectDict["project_notes"] = metadata["project_notes"] ?? ""
        projectDict["base_path"] = ""
        projectDict["target_duration"] = metadata["target_duration"] ?? ""
        projectDict["budget"] = ""
        projectDict["start_date"] = ""
        projectDict["end_date"] = ""
        projectDict["project_icon"] = ""

        // Characters
        projectDict["characters"] = characters

        // Production elements
        projectDict["props"] = production["props"] ?? []
        projectDict["locations"] = production["locations"] ?? []
        projectDict["lighting"] = production["lighting"] ?? []
        projectDict["effects"] = production["effects"] ?? []

        // Empty arrays for other fields
        projectDict["costumes"] = [] as [Any]
        projectDict["beats"] = [] as [Any]
        projectDict["schedule_items"] = [] as [Any]
        projectDict["film_styles"] = [] as [Any]
        projectDict["cast_members"] = [] as [Any]
        projectDict["crew_members"] = [] as [Any]
        projectDict["teams"] = [] as [Any]
        projectDict["equipment_library"] = [] as [Any]
        projectDict["overview_poster_paths"] = [] as [Any]
        projectDict["overview_poster_current_index"] = 0
        projectDict["overview_poster_custom"] = false

        // Sequences with scenes
        let sequence: [String: Any] = [
            "name": "Main Sequence",
            "description": "Complete screenplay sequence",
            "scenes": scenes
        ]
        projectDict["sequences"] = [sequence]

        // Renumber shot_ids sequentially across all scenes
        renumberShots(&projectDict)

        // Convert to Project via JSON roundtrip
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: projectDict)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var project = try decoder.decode(Project.self, from: jsonData)
            project.name = projectName
            return project
        } catch {
            debugLog("Failed to decode assembled project: \(error)")
            // Fallback: return empty project with name
            var empty = Project.empty()
            empty.name = projectName
            return empty
        }
    }

    /// Renumber all shot_ids sequentially across the entire project
    private static func renumberShots(_ projectDict: inout [String: Any]) {
        guard var sequences = projectDict["sequences"] as? [[String: Any]] else { return }
        var globalShotId = 1

        for seqIdx in 0..<sequences.count {
            guard var scenes = sequences[seqIdx]["scenes"] as? [[String: Any]] else { continue }
            for sceneIdx in 0..<scenes.count {
                guard var shots = scenes[sceneIdx]["shots"] as? [[String: Any]] else { continue }
                for shotIdx in 0..<shots.count {
                    shots[shotIdx]["shot_id"] = globalShotId
                    globalShotId += 1
                }
                scenes[sceneIdx]["shots"] = shots
            }
            sequences[seqIdx]["scenes"] = scenes
        }
        projectDict["sequences"] = sequences
    }

    // MARK: - AI Client

    private static func callAI(prompt: String, systemPrompt: String, provider: AIProvider, maxTokens: Int) async throws -> String {
        let aiClient = AIServiceClient.shared

        let request = TextGenerationRequest(
            prompt: prompt,
            provider: provider,
            maxTokens: maxTokens,
            temperature: 0.3,
            systemPrompt: systemPrompt
        )

        do {
            let response = try await aiClient.generateText(request)
            return response.text
        } catch {
            throw ImportError.aiGenerationFailed("\(provider.rawValue): \(error.localizedDescription)")
        }
    }

    // MARK: - JSON Parsing Helpers

    private static func parseJSON(_ jsonString: String) throws -> Any {
        var cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw ImportError.jsonParsingFailed("Could not convert AI response to data")
        }

        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError.jsonParsingFailed("JSON parse error: \(error.localizedDescription)")
        }
    }

    // MARK: - Stats

    private static func computeStats(from project: Project) -> ImportStats {
        var sceneCount = 0
        var shotCount = 0
        var dialogueCount = 0
        var actionCount = 0
        var soundNoteCount = 0

        for sequence in project.sequences {
            for scene in sequence.scenes {
                sceneCount += 1
                shotCount += scene.shots.count
                dialogueCount += scene.dialogues.count
                actionCount += scene.actions.count
                soundNoteCount += scene.soundNotes.count
            }
        }

        return ImportStats(
            sceneCount: sceneCount,
            shotCount: shotCount,
            dialogueCount: dialogueCount,
            actionCount: actionCount,
            characterCount: project.characters.count,
            soundNoteCount: soundNoteCount,
            propCount: project.props.count,
            locationCount: project.locations.count
        )
    }
}
