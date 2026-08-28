import XCTest
import AppKit
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices
@testable import DirectorsChairViews

/// DC-0071, second pass: takes a Keeper's Light project made by
/// `LocalProjectBuildEvals` and fills every feature of the tool the way a
/// user would — full character bios, traits and relationships, every
/// turnaround angle, complete costumes with all six angle images, props with
/// concept images and continuity, every location variation, scene production
/// notes, sound, narration, twelve fully specified shots with previews and
/// storyboard frames, a vision board, a poster, and the whole production
/// side (schedule, budget, cast, crew, equipment, teams, gantt, cues,
/// lighting, effects, soundtrack). Every image is drawn on the local model.
///
/// Opt in with `TEST_RUNNER_DC_LOCAL_BUILD_LOOK=sketch|comic`; the project
/// defaults to `~/Directors Chair/<DC_LOCAL_BUILD_USER>/Keeper's Light (<Look>)`
/// and can be pointed elsewhere with `DC_LOCAL_BUILD_PROJECT=<project.json>`.
@MainActor
final class LocalProjectPopulateEvals: XCTestCase {

    private struct Made: Encodable {
        let kind: String; let name: String; let path: String; let seconds: Double; let look: String
    }
    private var manifest: URL?
    private var look = VisualStyle.sketch

    private func record(_ kind: String, _ name: String, _ path: String, _ seconds: Double) {
        print("[LocalPopulate] \(kind) · \(name) · \(String(format: "%.1f", seconds))s → \(path)")
        guard let manifest else { return }
        let made = Made(kind: kind, name: name, path: path, seconds: seconds, look: look.rawValue)
        if let data = try? JSONEncoder().encode(made), let line = String(data: data, encoding: .utf8) {
            if let handle = try? FileHandle(forWritingTo: manifest) {
                handle.seekToEndOfFile(); handle.write((line + "\n").data(using: .utf8)!); try? handle.close()
            } else {
                try? (line + "\n").write(to: manifest, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - The pass

    func testPopulateEverythingInTheLocalProject() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let lookName = env["DC_LOCAL_BUILD_LOOK"], let requested = VisualStyle(rawValue: lookName) else {
            throw XCTSkip("no local populate requested")
        }
        guard LocalImageEngine.shared.isModelDownloaded() else { throw XCTSkip("klein weights not on disk") }
        look = requested
        manifest = env["DC_LOCAL_BUILD_MANIFEST"].map { URL(fileURLWithPath: $0) }
        // Dry = every record and action, no drawing: validates the whole
        // pass in seconds before a multi-hour render (a budget group name
        // failed the first run at the very end).
        let dry = env["DC_LOCAL_BUILD_DRY"] == "1"

        // Preferences the user would set: images on-device, the project's look.
        let defaults = UserDefaults.standard
        let savedProvider = defaults.string(forKey: AIFunction.image.preferenceKey)
        let savedStyle = AIProviderSelection.shared.visualStyle
        defaults.set("device", forKey: AIFunction.image.preferenceKey)
        AIProviderSelection.shared.visualStyle = look
        defer {
            if let savedProvider { defaults.set(savedProvider, forKey: AIFunction.image.preferenceKey) }
            else { defaults.removeObject(forKey: AIFunction.image.preferenceKey) }
            AIProviderSelection.shared.visualStyle = savedStyle
        }

        // ---- 0. Open the project the build pass made --------------------------------
        let savedUser = ProjectDirectoryManager.currentUsername
        ProjectDirectoryManager.currentUsername = env["DC_LOCAL_BUILD_USER"] ?? savedUser
        defer { ProjectDirectoryManager.currentUsername = savedUser }
        let projectFile = env["DC_LOCAL_BUILD_PROJECT"].map { URL(fileURLWithPath: $0) }
            ?? ProjectDirectoryManager.directorsChairRoot
                .appendingPathComponent("Keeper's Light (\(look.displayName))")
                .appendingPathComponent("project.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectFile.path), "project to populate: \(projectFile.path)")
        let projectDir = projectFile.deletingLastPathComponent()
        let pvm = ProjectViewModel(project: Project.empty())
        try await pvm.load(from: projectFile)
        print("[LocalPopulate] project at \(projectDir.path)")
        let coordinator = AppCoordinator()
        let registry = AssistantActionFactory.makeRegistry(projectViewModel: pvm, coordinator: coordinator)
        func run(_ name: String, _ json: String) async throws {
            let action = try XCTUnwrap(registry.action(named: name), "action \(name)")
            let data = Data(json.utf8)
            _ = try action.validate(argumentsData: data)
            _ = try await action.execute(argumentsData: data)
        }
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
        }
        func draw(_ request: ImageGenerationRequest) async throws -> Data {
            let response = try await AIServiceClient.shared.generateImage(request)
            return try XCTUnwrap(response.images.first, "the local model returned no image")
        }
        func write(_ png: Data, to relative: String) throws {
            let url = projectDir.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: url)
        }
        func base64(_ relative: String) throws -> String {
            try Data(contentsOf: projectDir.appendingPathComponent(relative)).base64EncodedString()
        }
        func stamp() -> String {
            let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            return f.string(from: Date())
        }
        func sceneIndex(_ name: String) throws -> (Int, Int) {
            for (s, seq) in pvm.project.sequences.enumerated() {
                if let i = seq.scenes.firstIndex(where: { $0.name == name }) { return (s, i) }
            }
            throw XCTSkip("scene \(name) is missing — build the project first")
        }
        func scene(_ name: String) throws -> Scene {
            let (s, i) = try sceneIndex(name); return pvm.project.sequences[s].scenes[i]
        }
        func editScene(_ name: String, _ body: (inout Scene) -> Void) throws {
            let (s, i) = try sceneIndex(name); body(&pvm.project.sequences[s].scenes[i])
        }
        func editCharacter(_ name: String, _ body: (inout Character) -> Void) throws {
            let i = try XCTUnwrap(pvm.project.characters.firstIndex { $0.name == name }, "character \(name)")
            body(&pvm.project.characters[i])
        }
        func character(_ name: String) throws -> Character {
            try XCTUnwrap(pvm.project.characters.first { $0.name == name }, "character \(name)")
        }
        func editLocation(_ name: String, _ body: (inout Location) -> Void) throws {
            let i = try XCTUnwrap(pvm.project.locations.firstIndex { $0.name == name }, "location \(name)")
            body(&pvm.project.locations[i])
        }
        func editProp(_ name: String, _ body: (inout Prop) -> Void) throws {
            let i = try XCTUnwrap(pvm.project.props.firstIndex { $0.name == name }, "prop \(name)")
            body(&pvm.project.props[i])
        }
        let sceneNames = ["Last Light", "Kitchen Watch", "First Light"]
        for name in sceneNames { _ = try scene(name) }
        // A new project ships with a placeholder character as well as a
        // placeholder scene; the cast is the three people in the script.
        let cast = ["Noor", "Teo", "Idris"]
        pvm.project.characters.removeAll { !cast.contains($0.name) }
        XCTAssertEqual(pvm.project.characters.map(\.name).sorted(), cast.sorted())

        // ---- 1. Project metadata (Overview) -------------------------------------------
        try await run("update_project_metadata", #"{"field": "tagline", "value": "Every light needs someone to count it.", "reason": "pitch"}"#)
        try await run("update_project_metadata", #"{"field": "description", "value": "A twelve-minute drama set over one night at the Marrow Point lighthouse: the keeper's last watch, the nephew sent to replace her, and the boatman they pull out of the fog.", "reason": "pitch"}"#)
        try await run("update_project_metadata", #"{"field": "status", "value": "Pre-production", "reason": "planning is complete, shoot scheduled"}"#)
        pvm.project.director = "Mira Okonkwo"
        pvm.project.productionCompany = "Marrow Point Pictures"
        pvm.project.projectType = "Motion Film"
        pvm.project.targetDuration = "12 minutes"
        pvm.project.budget = "$48,500"
        pvm.project.startDate = "2026-09-14"
        pvm.project.endDate = "2026-09-16"
        pvm.project.languages = ["English"]
        pvm.project.projectNotes = """
        Three nights, one location cluster. The whole film lives in the difference between a light that is kept and a light that is merely on. \
        Shoot in story order so the wet-down continuity on Idris and the rain on the kitchen window carry naturally. \
        No score under dialogue — the sea, the lamp mechanism and the foghorn are the score.
        """
        pvm.project.overviewSummary = """
        Noor has kept the Marrow Point light for thirty-one years and tonight is her last watch. The authority has sent her nephew Teo to \
        take over — eager, seasick, and certain that keeping a light is a matter of switches. When a fishing boat loses its engine in the fog, \
        the two of them find out what the light is actually for, and Noor finds a way to hand it over without ever saying goodbye. \
        A quiet chamber piece for three actors, one lighthouse, and a lot of weather.
        """
        pvm.project.overviewMoodAnalysis = ["quiet resolve": 0.9, "tenderness": 0.7, "dread": 0.45, "wonder": 0.6, "grief": 0.5]
        pvm.project.defaultFilmStyle = look == .sketch ? "preset-mono-classic" : "preset-golden-naturalism"
        pvm.project.defaultExpenseDepartment = "Production"
        pvm.project.defaultExpenseAccountCode = "2000"

        // ---- 2. Characters: the whole bio, traits, relationships, voice ----------------
        struct Bio {
            let name: String, role: String, fullName: String, nickname: String, occupation: String, affiliation: String
            let story: String, goal: String, goal2: String, fear: String, weakness: String, flaw: String
            let heightCm: Double, weightKg: Double, eyeShape: String, skinTone: String, ethnicity: String, facial: String
            let voice: String, voiceStyle: String, pace: String, accent: String, tone: String, voiceAge: String, personality: String
            let setting: String, color: String, textColor: String, traits: [String: Double]
        }
        let bios: [Bio] = [
            Bio(name: "Noor", role: "Protagonist", fullName: "Noor Haddad Marrow", nickname: "the Keeper", occupation: "Lighthouse keeper",
                affiliation: "Northern Lights Authority (retiring)",
                story: """
                Noor came to Marrow Point at twenty-seven as the relief keeper for a man who never came back from leave, and simply stayed. \
                She learned the light from its manuals and its moods: the clockwork that turns the lens, the wick that must be trimmed by feel, \
                the exact sound the foghorn makes when the compressor is about to fail. She married a boatman from the cove, buried him eleven years later, \
                and kept the light through the night of his funeral because nobody else could. The authority automated every other light on the coast a decade ago; \
                Marrow Point stayed manned only because Noor refused to sign the decommissioning survey. Now they have sent her sister's son to replace her, \
                and she has agreed to leave — on the condition that the light is handed over, not switched over.
                """,
                goal: "Hand the light over without admitting she is afraid of the silence after.",
                goal2: "Teach Teo to count the light — to feel the beam's turn without looking at a clock.",
                fear: "That the light will be fine without her, and so will everyone else.",
                weakness: "Cannot ask for help; would rather do a thing wrong alone than right with company.",
                flaw: "Mistakes brusqueness for honesty and silence for strength.",
                heightCm: 168, weightKg: 58, eyeShape: "Deep-set", skinTone: "Olive, wind-burned", ethnicity: "Lebanese-British",
                facial: "Long face, high cheekbones, deep lines at the eyes and mouth from squinting into weather",
                voice: "Kore", voiceStyle: "low, dry, unhurried", pace: "Slow", accent: "Northern English", tone: "Warm underneath, cold on the surface",
                voiceAge: "Elderly", personality: "Confident",
                setting: "The lamp room and gallery of the Marrow Point lighthouse, fog below",
                color: "#1F3A5F", textColor: "#FFFFFF",
                traits: ["Creativity": 45, "Curiosity": 60, "Imagination": 40, "Open-mindedness": 35, "Artistic Interest": 30,
                         "Organization": 92, "Diligence": 97, "Reliability": 99, "Self-discipline": 95, "Ambition": 25,
                         "Sociability": 15, "Energy": 55, "Assertiveness": 80, "Enthusiasm": 20, "Talkativeness": 10,
                         "Empathy": 70, "Cooperation": 35, "Trust": 40, "Kindness": 65, "Politeness": 30,
                         "Anxiety": 45, "Moodiness": 40, "Sensitivity": 60, "Irritability": 55, "Self-consciousness": 20]),
            Bio(name: "Teo", role: "Deuteragonist", fullName: "Teodor Haddad Vance", nickname: "Teo", occupation: "Assistant keeper",
                affiliation: "Northern Lights Authority (probationary)",
                story: """
                Teo grew up on his aunt's postcards — the lighthouse at dusk, the lighthouse in snow, never a person in them. He did two years of marine engineering, \
                dropped out when his father's garage went under, and took the authority's keeper-trainee post because it was the only job on the coast that came with a bed. \
                He gets seasick on the ferry and pretends he doesn't. He has read every manual for the Marrow Point light and has never trimmed a wick. \
                He believes the job is switches and logbooks and that his aunt is a difficult old woman standing between him and a quiet life; \
                by dawn he will believe something else.
                """,
                goal: "Prove he can keep the light alone.",
                goal2: "Get his aunt to say, once, that he is good enough.",
                fear: "Being the one on watch when the light fails.",
                weakness: "Seasick, sleepless, and too proud to say either.",
                flaw: "Mistakes knowing the manual for knowing the light.",
                heightCm: 183, weightKg: 74, eyeShape: "Wide", skinTone: "Light olive", ethnicity: "Lebanese-British",
                facial: "Narrow face, strong nose, quick to flush; a boy's face on a man's height",
                voice: "Puck", voiceStyle: "eager, a little too fast", pace: "Fast", accent: "Northern English", tone: "Bright, defensive",
                voiceAge: "Young", personality: "Nervous",
                setting: "The cramped lighthouse kitchen, rain on the window",
                color: "#C9A227", textColor: "#1B1F1D",
                traits: ["Creativity": 60, "Curiosity": 85, "Imagination": 70, "Open-mindedness": 65, "Artistic Interest": 45,
                         "Organization": 70, "Diligence": 75, "Reliability": 60, "Self-discipline": 50, "Ambition": 80,
                         "Sociability": 65, "Energy": 85, "Assertiveness": 45, "Enthusiasm": 90, "Talkativeness": 75,
                         "Empathy": 65, "Cooperation": 70, "Trust": 60, "Kindness": 75, "Politeness": 70,
                         "Anxiety": 75, "Moodiness": 50, "Sensitivity": 70, "Irritability": 35, "Self-consciousness": 80]),
            Bio(name: "Idris", role: "Supporting", fullName: "Idris Bellamy Kaur", nickname: "Bell", occupation: "Fisherman",
                affiliation: "Cove Fishermen's Cooperative",
                story: """
                Idris has fished the Marrow banks for twenty years in a boat that was old when he bought it. He knows the light the way sailors do: \
                as a number of seconds between flashes, as the thing you steer by when the compass is wet. When his engine died in the fog he counted the beam, \
                held the bow to it, and kept counting after the swell took the boat. He is the only person in the film who understands, without being told, \
                what Noor has been doing on that rock for thirty-one years — and he is the one who tells Teo.
                """,
                goal: "Get back to his daughter by morning.",
                goal2: "Tell the keeper, properly, that the light was there.",
                fear: "The dark between flashes.",
                weakness: "Hypothermic, exhausted, and stubborn enough to walk anyway.",
                flaw: "Trusts old things past the point of sense — boats, engines, lights.",
                heightCm: 175, weightKg: 88, eyeShape: "Heavy-lidded", skinTone: "Deep brown", ethnicity: "Punjabi-Caribbean",
                facial: "Broad face, full beard, a boxer's nose, kind eyes",
                voice: "Charon", voiceStyle: "hoarse, slow, half a laugh in it", pace: "Slow", accent: "Caribbean-English", tone: "Gentle",
                voiceAge: "Middle-aged", personality: "Cheerful",
                setting: "The cliff path at dawn, fog lifting off the water",
                color: "#237873", textColor: "#FFFFFF",
                traits: ["Creativity": 50, "Curiosity": 55, "Imagination": 65, "Open-mindedness": 75, "Artistic Interest": 40,
                         "Organization": 40, "Diligence": 80, "Reliability": 85, "Self-discipline": 70, "Ambition": 30,
                         "Sociability": 80, "Energy": 45, "Assertiveness": 55, "Enthusiasm": 70, "Talkativeness": 65,
                         "Empathy": 90, "Cooperation": 85, "Trust": 80, "Kindness": 90, "Politeness": 75,
                         "Anxiety": 30, "Moodiness": 25, "Sensitivity": 65, "Irritability": 20, "Self-consciousness": 25]),
        ]
        for bio in bios {
            try editCharacter(bio.name) { c in
                c.role = bio.role; c.fullName = bio.fullName; c.nickname = bio.nickname; c.occupation = bio.occupation
                c.affiliation = bio.affiliation; c.backgroundStory = bio.story
                c.primaryGoal = bio.goal; c.secondaryGoal = bio.goal2; c.primaryFear = bio.fear
                c.weakness = bio.weakness; c.flaw = bio.flaw
                c.heightCm = bio.heightCm; c.weightKg = bio.weightKg; c.eyeShape = bio.eyeShape
                c.skinTone = bio.skinTone; c.ethnicity = bio.ethnicity; c.facialStructure = bio.facial
                c.voice = bio.voice; c.voiceStyle = bio.voiceStyle; c.voicePace = bio.pace; c.voiceAccent = bio.accent
                c.voiceTone = bio.tone; c.voiceAge = bio.voiceAge; c.voicePersonality = bio.personality
                c.backgroundSetting = bio.setting; c.color = bio.color; c.textColor = bio.textColor
                c.imageStyle = look == .sketch ? "Illustration" : "Comic Book"
            }
            for (trait, value) in bio.traits.sorted(by: { $0.key < $1.key }) {
                try await run("update_character_trait", #"{"character": "\#(bio.name)", "trait": "\#(trait)", "value": \#(value), "reason": "from the script"}"#)
            }
        }
        let relationships: [(String, String, String, String)] = [
            ("Noor", "Teo", "Nephew — her sister's boy, sent to replace her", "The authority's choice, not hers; she is harder on him than on the weather."),
            ("Teo", "Noor", "Aunt — the keeper he is replacing", "He wants her approval more than the post."),
            ("Noor", "Idris", "The boatman she pulled from the cove", "He is the only person who ever thanked her for the light."),
            ("Idris", "Noor", "The keeper whose light he steered by", "He counted her beam for an hour in the dark."),
            ("Teo", "Idris", "The first person his watch saved", "Teo spotted the boat light; it is the first thing he did right."),
            ("Idris", "Teo", "The boy who saw the light go under", "He tells Teo what the light is for."),
        ]
        for (who, target, rel, reason) in relationships {
            try await run("add_relationship", #"{"character": "\#(who)", "target": "\#(target)", "relationship": "\#(esc(rel))", "reason": "\#(esc(reason))"}"#)
        }

        // Every turnaround angle the Story Design tab offers (base + 3/4 left exist).
        for name in ["Noor", "Teo", "Idris"] where !dry {
            for angle in ["three_quarter_right", "profile_left", "profile_right", "back"] {
                func stored() throws -> String? {
                    let c = try character(name)
                    switch angle {
                    case "three_quarter_right": return c.imageThreeQuarterRight
                    case "profile_left": return c.imageProfileLeft
                    case "profile_right": return c.imageProfileRight
                    default: return c.imageBack
                    }
                }
                // A recorded path whose file is gone is redrawn (the action
                // itself skips any angle it already has a path for).
                if let existing = try stored(), FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(existing).path) { continue }
                let started = Date()
                try await run("generate_character_images", #"{"character": "\#(name)", "angles": ["\#(angle)"], "regenerate": true}"#)
                record("character-angle", "\(name) · \(angle)", try stored() ?? "?", Date().timeIntervalSince(started))
            }
        }

        // ---- 3. Costumes: one or two per character, all six angle images ---------------
        struct Wardrobe {
            let character: String, name: String, description: String, era: String, style: String, palette: [String]
            let top: String, bottom: String, footwear: String, outerwear: String, headwear: String, accessories: [String], fabric: String
            let status: String, scenes: [String], change: Int, scriptDay: String, sfx: String, notes: String
        }
        let wardrobe: [Wardrobe] = [
            Wardrobe(character: "Noor", name: "Watch Oilskins", description: "Her working clothes for the gallery at night.", era: "Present day", style: "Workwear",
                     palette: ["cream", "black", "brass"], top: "thick cream wool fisherman's sweater", bottom: "dark wool trousers",
                     footwear: "black rubber sea boots", outerwear: "long black oilskin coat", headwear: "none",
                     accessories: ["brass pocketknife", "wool watch cap in the coat pocket"], fabric: "wool and waxed cotton",
                     status: "Ready", scenes: ["Last Light", "Kitchen Watch"], change: 1, scriptDay: "Night 1",
                     sfx: "Wet-down on the oilskin for the exit of Kitchen Watch.", notes: "Thirty-one years of wear: cuffs frayed, one button replaced with a mismatched one."),
            Wardrobe(character: "Noor", name: "Cottage Cardigan", description: "What she changes into at dawn once the boat is in.", era: "Present day", style: "Casual",
                     palette: ["oatmeal", "grey", "rust"], top: "oatmeal shawl-collar cardigan over a grey flannel shirt", bottom: "dark corduroy trousers",
                     footwear: "worn brown leather boots", outerwear: "none", headwear: "none",
                     accessories: ["reading glasses on a cord"], fabric: "wool",
                     status: "Fitting", scenes: ["First Light"], change: 2, scriptDay: "Dawn 2",
                     sfx: "None.", notes: "The first time we see her without the coat; she should look smaller."),
            Wardrobe(character: "Teo", name: "Authority Issue", description: "The kit the lighthouse authority sent him with, still creased from the box.", era: "Present day", style: "Workwear",
                     palette: ["safety yellow", "grey", "navy"], top: "grey cotton hoodie", bottom: "navy work trousers",
                     footwear: "black rubber boots", outerwear: "yellow rain jacket, stiff and new", headwear: "navy knit cap",
                     accessories: ["dented steel thermos", "authority ID badge on a lanyard"], fabric: "PVC-coated nylon and cotton",
                     status: "Ready", scenes: ["Last Light", "Kitchen Watch", "First Light"], change: 1, scriptDay: "Night 1 – Dawn 2",
                     sfx: "Rain-wet for Kitchen Watch; mud to the knees for First Light.", notes: "Everything is one size too big; he has not grown into the job."),
            Wardrobe(character: "Idris", name: "Boatman's Peacoat", description: "What he was wearing when the sea took the boat.", era: "Present day", style: "Workwear",
                     palette: ["navy", "oilcloth black", "white"], top: "white thermal undershirt", bottom: "black oilcloth trousers",
                     footwear: "one sea boot, one bare foot in a borrowed sock", outerwear: "sodden navy wool peacoat", headwear: "none",
                     accessories: ["wedding ring on a cord", "grey wool blanket over the shoulders"], fabric: "wool",
                     status: "Sourcing", scenes: ["First Light"], change: 1, scriptDay: "Dawn 2",
                     sfx: "Soaked: continuity wet-down through all of First Light.", notes: "Three identical peacoats needed for the wet-down."),
        ]
        let costumeAngles: [(key: String, description: String)] = [
            ("front", "front facing view, full body, looking directly at camera"),
            ("three_quarter_left", "three-quarter view from the left side, full body"),
            ("three_quarter_right", "three-quarter view from the right side, full body"),
            ("profile", "side profile view, full body"),
            ("back", "back view, showing back of costume, full body"),
            ("full_body", "full body shot, head to toe, costume design reference sheet"),
        ]
        for w in wardrobe {
            let charIndex = try XCTUnwrap(pvm.project.characters.firstIndex { $0.name == w.character })
            var owner = pvm.project.characters[charIndex]
            let sceneIds = try w.scenes.map { try scene($0).uuid }
            var costume = CharacterCostume(name: w.name, description: w.description, era: w.era, styleCategory: w.style, colorPalette: w.palette,
                                           garmentTop: w.top, garmentBottom: w.bottom, footwear: w.footwear, outerwear: w.outerwear, headwear: w.headwear,
                                           accessories: w.accessories, primaryFabric: w.fabric, status: w.status, sceneIds: sceneIds,
                                           changeNumber: w.change, scriptDay: w.scriptDay, sfxRequirements: w.sfx, directorNotes: w.notes, createdAt: Date())
            if let existing = owner.costumes?.firstIndex(where: { $0.name == w.name }) {
                let old = owner.costumes![existing]
                costume.costumeId = old.costumeId
                costume.imageFront = old.imageFront; costume.imageThreeQuarterLeft = old.imageThreeQuarterLeft
                costume.imageThreeQuarterRight = old.imageThreeQuarterRight; costume.imageProfile = old.imageProfile
                costume.imageBack = old.imageBack; costume.imageFullBody = old.imageFullBody
                owner.costumes![existing] = costume
            } else {
                owner.costumes = (owner.costumes ?? []) + [costume]
                try await run("add_costume", #"{"name": "\#(esc(w.name))", "character": "\#(w.character)", "notes": "\#(esc(w.description + " " + w.notes))"}"#)
            }
            if owner.activeCostumeIndex == nil { owner.activeCostumeIndex = 0 }
            pvm.project.characters[charIndex] = owner
            let costumeDir = "assets/characters/\(DiscoveredCharacterImages.sanitizedName(for: owner.name))/costumes/\(DiscoveredCostumeImages.sanitizedName(for: w.name))"
            for angle in costumeAngles where !dry {
                let current = pvm.project.characters[charIndex].costumes!.first { $0.name == w.name }!
                let existingPath: String? = {
                    switch angle.key {
                    case "front": return current.imageFront
                    case "three_quarter_left": return current.imageThreeQuarterLeft
                    case "three_quarter_right": return current.imageThreeQuarterRight
                    case "profile": return current.imageProfile
                    case "back": return current.imageBack
                    default: return current.imageFullBody
                    }
                }()
                if let existingPath, FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(existingPath).path) { continue }
                // Exactly what the Costume tab sends: the costume prompt + the angle + the sheet suffix,
                // with the costume's front image (else the character's base) as the likeness reference.
                // A recorded path whose file is gone (a redrawn sheet) must not be the reference.
                let reference = [current.imageFront, pvm.project.characters[charIndex].baseImage]
                    .compactMap { $0 }
                    .first { FileManager.default.fileExists(atPath: projectDir.appendingPathComponent($0).path) }
                let prompt = StoryDesignPromptBuilder.costumePrompt(character: pvm.project.characters[charIndex], costume: current)
                    + ", \(angle.description), costume design reference, full body shot"
                let started = Date()
                let png = try await draw(ImageGenerationRequest(
                    prompt: prompt, provider: .onDevice, aspectRatio: "1:1",
                    referenceImageBase64: try reference.map(base64), referenceMimeType: reference == nil ? nil : "image/png",
                    brief: VisualBrief(purpose: .costume,
                                       subject: StoryboardSubjects.subject(for: current, wornBy: pvm.project.characters[charIndex]),
                                       framing: StoryboardSubjects.costumeFraming(angle: angle.key))))
                let relative = "\(costumeDir)/\(angle.key).png"
                try write(png, to: relative)
                let ci = pvm.project.characters[charIndex].costumes!.firstIndex { $0.name == w.name }!
                switch angle.key {
                case "front": pvm.project.characters[charIndex].costumes![ci].imageFront = relative
                case "three_quarter_left": pvm.project.characters[charIndex].costumes![ci].imageThreeQuarterLeft = relative
                case "three_quarter_right": pvm.project.characters[charIndex].costumes![ci].imageThreeQuarterRight = relative
                case "profile": pvm.project.characters[charIndex].costumes![ci].imageProfile = relative
                case "back": pvm.project.characters[charIndex].costumes![ci].imageBack = relative
                default: pvm.project.characters[charIndex].costumes![ci].imageFullBody = relative
                }
                record("costume-angle", "\(w.character) · \(w.name) · \(angle.key)", relative, Date().timeIntervalSince(started))
            }
            // The wardrobe plot: which change each character wears in each scene.
            for sceneName in w.scenes {
                try editScene(sceneName) { s in
                    var assignments = s.costumeAssignments ?? [:]
                    assignments[w.character] = costume.costumeId
                    s.costumeAssignments = assignments
                }
            }
        }

        // ---- 4. Props: every field, continuity per scene, a concept image each ------------
        struct PropSpec {
            let name: String, description: String, category: String, specs: String, tags: [String]
            let acquisition: String, source: String, cost: Double, quantity: Int, hero: Int, stunt: Int, storage: String
            let scenes: [String], handling: String, safety: String, notes: String, continuity: [(String, String, String)]
        }
        let props: [PropSpec] = [
            PropSpec(name: "Brass storm lantern", description: "A dented brass storm lantern with a cracked glass chimney and a leather carrying strap.",
                     category: "Handheld", specs: "Height 32 cm, brass body, working paraffin burner converted to a hidden LED for safety; the cracked chimney is a resin duplicate.",
                     tags: ["hero-prop", "practical-light", "period"], acquisition: "Build", source: "Art department workshop", cost: 420, quantity: 3, hero: 1, stunt: 2,
                     storage: "Props truck, shelf B2", scenes: ["Kitchen Watch", "First Light"],
                     handling: "Hero lantern travels in its foam case; never set it on the enamel table without the felt pad.", safety: "LED conversion only — no open flame on set.",
                     notes: "Noor's lantern for thirty-one years. The dent is on the left when the strap faces the camera.",
                     continuity: [("Kitchen Watch", "Hero", "Lit, hanging on its hook, then carried out."), ("First Light", "Aged", "Unlit, mud on the base, strap over Teo's shoulder.")]),
            PropSpec(name: "Dented steel thermos", description: "A green enamelled steel thermos, dented at the base, the lid scratched from being used as a cup.",
                     category: "Handheld", specs: "1 L vintage-style steel flask, enamel green, base dent added with a mallet, contents: hot tea for the actor.",
                     tags: ["hero-prop", "character-prop"], acquisition: "Purchase", source: "Cove Hardware", cost: 38, quantity: 2, hero: 1, stunt: 1,
                     storage: "Props truck, shelf B1", scenes: ["Last Light"],
                     handling: "Fill just before the take so it steams.", safety: "Hot liquid — warn the actor.",
                     notes: "Teo's offering. Noor takes it without a word; it comes back empty in the kitchen.",
                     continuity: [("Last Light", "Hero", "Full, steaming, offered up the ladder."), ("Kitchen Watch", "Hero", "Empty on the enamel table, lid off.")]),
            PropSpec(name: "Keeper's logbook", description: "A cloth-bound logbook swollen with thirty-one years of weather, its spine taped, the last page half written.",
                     category: "Document", specs: "A4 cloth-bound ledger, aged with tea and sandpaper, 200 pages hand-filled with weather entries in three inks; the final entry is Noor's.",
                     tags: ["hero-prop", "document", "insert"], acquisition: "Build", source: "Art department graphics", cost: 260, quantity: 2, hero: 1, stunt: 1,
                     storage: "Props truck, document box", scenes: ["Kitchen Watch"],
                     handling: "Handle with cotton gloves between takes; the insert page is the only one that is lit.", safety: "None.",
                     notes: "The last entry reads: 'Fog. Light kept. — N.' Teo will write the next one.",
                     continuity: [("Kitchen Watch", "Hero", "Open at the last page, pen resting in the gutter, then closed.")]),
            PropSpec(name: "Grey wool blanket", description: "A coarse grey wool rescue blanket with a red stripe along one edge, sodden and heavy.",
                     category: "Costume prop", specs: "Army-surplus wool blanket 150 × 200 cm, red selvedge stripe, pre-soaked for the wet-down.",
                     tags: ["continuity-wet", "costume-prop"], acquisition: "Purchase", source: "Surplus store", cost: 45, quantity: 4, hero: 1, stunt: 3,
                     storage: "Wardrobe truck, wet bin", scenes: ["First Light"],
                     handling: "Keep two dry, two wet; swap between setups.", safety: "Heavy when wet — mind the actor's footing on the path.",
                     notes: "Idris wears it like a coat. The stripe should read against the fog.",
                     continuity: [("First Light", "Damaged", "Soaked, dragging in the mud, stripe outward.")]),
            PropSpec(name: "Coastguard radio", description: "A boxy 1980s VHF set with a coiled handset, a cracked dial window and a hand-lettered channel card taped to the front.",
                     category: "Electronics", specs: "Non-working VHF base station shell with a hidden Bluetooth speaker for the bulletin playback; dial lamp practical on 12 V.",
                     tags: ["practical", "sound-cue", "set-dressing"], acquisition: "Rental", source: "Northern Props Hire", cost: 0, quantity: 1, hero: 1, stunt: 0,
                     storage: "On set, kitchen dresser", scenes: ["Kitchen Watch"],
                     handling: "Playback is cued from the sound cart; do not touch the dial.", safety: "12 V practical — gaffer signs off.",
                     notes: "The bulletin nobody answers comes through this.",
                     continuity: [("Kitchen Watch", "Pristine", "Dial lamp on, handset on the hook.")]),
        ]
        for p in props {
            if !pvm.project.props.contains(where: { $0.name == p.name }) {
                try await run("add_prop", #"{"name": "\#(esc(p.name))", "description": "\#(esc(p.description))", "category": "\#(esc(p.category))"}"#)
            }
            try editProp(p.name) { prop in
                prop.description = p.description; prop.category = p.category; prop.detailedSpecs = p.specs; prop.tags = p.tags
                prop.acquisitionType = p.acquisition; prop.source = p.source; prop.acquisitionCost = p.cost
                if p.acquisition == "Rental" { prop.rentalDailyRate = 35; prop.rentalStartDate = "2026-09-14"; prop.rentalEndDate = "2026-09-16"; prop.returnDate = "2026-09-17"; prop.depositAmount = 150 }
                if p.acquisition == "Purchase" { prop.purchaseDate = "2026-08-30" }
                prop.quantity = p.quantity; prop.quantityHero = p.hero; prop.quantityStunt = p.stunt; prop.storageLocation = p.storage
                prop.barcodeId = "MP-\(p.name.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 9000 } + 1000)"
                prop.continuityCritical = true; prop.continuityNotes = "Tracked per scene; see states."
                prop.continuityStates = p.continuity.map { PropContinuityState(sceneName: $0.0, condition: $0.1, description: $0.2, notes: "") }
                prop.propsMasterName = "Sam Whitlock"; prop.requiresFabrication = p.acquisition == "Build"
                prop.sceneNames = p.scenes; prop.firstAppearanceScene = p.scenes.first; prop.lastAppearanceScene = p.scenes.last
                prop.notes = p.notes; prop.handlingInstructions = p.handling; prop.safetyNotes = p.safety; prop.status = "Available"
                prop.createdDate = prop.createdDate ?? ISO8601DateFormatter().string(from: Date())
                prop.modifiedDate = ISO8601DateFormatter().string(from: Date())
            }
            for sceneName in p.scenes {
                try editScene(sceneName) { s in if !s.props.contains(p.name) { s.props.append(p.name) } }
            }
            let prop = try XCTUnwrap(pvm.project.props.first { $0.name == p.name })
            if dry { continue }
            if let thumb = prop.thumbnail, FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(thumb).path) { continue }
            // The Prop Shop's concept prompt, drawn on the local model.
            let prompt = "Professional film-production prop concept image: \(p.name). \(p.description) Prop category: \(p.category). Specifications: \(p.specs) Studio product photography on a neutral dark background, high detail, realistic materials, no people, no text."
            let started = Date()
            let png = try await draw(ImageGenerationRequest(
                prompt: prompt, provider: .onDevice, aspectRatio: "1:1",
                brief: VisualBrief(purpose: .prop, subject: "\(p.name): \(p.description)")))
            let relative = "assets/props/\(CharacterReferenceHelper.sanitizeLocationName(p.name))/concept_\(Int(Date().timeIntervalSince1970)).png"
            try write(png, to: relative)
            try editProp(p.name) { $0.thumbnail = relative }
            record("prop", p.name, relative, Date().timeIntervalSince(started))
        }

        // ---- 5. Locations: every field, every variation --------------------------------
        struct Place {
            let name: String, notes: String, tags: [String], address: String, gps: String, mood: String, architecture: String
            let palette: String, texture: String, lighting: String, timeOfDay: String, angle: String, weather: String, dims: [String: Double]
        }
        let places: [Place] = [
            Place(name: "Lighthouse Gallery", notes: "Real iron gallery, 22 m up; harness points on the rail. Wind above 30 knots closes the set.",
                  tags: ["exterior", "height", "night", "practical-light"], address: "Marrow Point Lighthouse, Marrow Head, North Coast", gps: "55.9412, -1.6087",
                  mood: "exposed, solitary", architecture: "Victorian cast-iron lighthouse", palette: "salt white, rust, bruised indigo", texture: "riveted iron, peeling paint, wet glass",
                  lighting: "practical lamp behind glass, low sky", timeOfDay: "dusk", angle: "low, wide", weather: "fog", dims: ["width": 6, "length": 6, "height": 3]),
            Place(name: "Lighthouse Kitchen", notes: "Round room, 4 m across; camera lives in the doorway or the window seat. Rain rig outside the window.",
                  tags: ["interior", "cramped", "night", "practical-light"], address: "Marrow Point Lighthouse, ground floor", gps: "55.9412, -1.6087",
                  mood: "close, warm, watchful", architecture: "whitewashed stone, coal range", palette: "cream, soot black, brass, lamp amber", texture: "limewash, enamel, worn oak",
                  lighting: "single lantern key, range glow fill", timeOfDay: "night", angle: "eye level, 35 mm", weather: "storm outside", dims: ["width": 4, "length": 4, "height": 2.6]),
            Place(name: "Cliff Path", notes: "Public footpath; permit for 06:00–09:00. Mud is real — track mats for the dolly.",
                  tags: ["exterior", "dawn", "walk-and-talk", "weather-dependent"], address: "Marrow Head coastal path, from the cove to the keeper's cottage", gps: "55.9398, -1.6121",
                  mood: "washed clean, tentative", architecture: "none — gorse, wet rock, a stone cottage at the top", palette: "grey-green, chalk, pale gold", texture: "mud, wet grass, gorse, shingle",
                  lighting: "soft dawn from the sea, fog lifting", timeOfDay: "dawn", angle: "high wide then handheld", weather: "clearing", dims: ["length": 180, "width": 1.5]),
        ]
        // The build pass's plates all gained invented people (run 2: a chef in
        // the kitchen, walkers on the path); the styler's location framing was
        // fixed, so every plate and variation is redrawn unless told to keep.
        let redrawLocations = env["DC_LOCAL_BUILD_KEEP_LOCATIONS"] != "1" && !dry
        for pl in places {
            try editLocation(pl.name) { l in
                l.notes = pl.notes; l.tags = pl.tags; l.address = pl.address; l.gpsCoordinates = pl.gps; l.parentLocation = "Marrow Point"
                l.styleAttributes = ["mood": pl.mood, "architectural_style": pl.architecture, "color_palette": pl.palette, "texture": pl.texture]
                l.cinematographyDefaults = ["lighting": pl.lighting, "time_of_day": pl.timeOfDay, "preferred_angle": pl.angle]
                l.attributes = ["time_of_day": pl.timeOfDay, "weather": pl.weather, "mood": pl.mood]
                l.dimensions = pl.dims
                if redrawLocations {
                    for old in l.images { try? FileManager.default.removeItem(at: projectDir.appendingPathComponent(old)) }
                    l.images = []; l.primaryImage = nil
                }
            }
            if !dry, try XCTUnwrap(pvm.project.locations.first { $0.name == pl.name }).primaryImage == nil {
                let started = Date()
                try await run("generate_location_images", #"{"location": "\#(esc(pl.name))"}"#)
                let l = try XCTUnwrap(pvm.project.locations.first { $0.name == pl.name })
                record("location", pl.name, l.primaryImage ?? "?", Date().timeIntervalSince(started))
            }
            for variation in ["day", "night", "golden_hour", "overcast", "wide", "detail"] where !dry {
                let before = try XCTUnwrap(pvm.project.locations.first { $0.name == pl.name })
                if let existing = before.images.first(where: { $0.contains("/\(variation).png") || $0.hasSuffix("\(variation).png") }),
                   FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(existing).path) { continue }
                let started = Date()
                try await run("generate_location_images", #"{"location": "\#(esc(pl.name))", "variations": ["\#(variation)"]}"#)
                let after = try XCTUnwrap(pvm.project.locations.first { $0.name == pl.name })
                let made = after.images.first { $0.contains(variation) && !before.images.contains($0) } ?? after.images.first { $0.contains(variation) }
                record("location-variation", "\(pl.name) · \(variation)", made ?? "?", Date().timeIntervalSince(started))
            }
        }

        // ---- 6. Sound: a procedurally made ambience bed the timeline can play ----------------
        let ambienceId = "marrow-point-ambience"
        let ambienceRelative = "assets/audio/soundtracks/\(ambienceId).wav"
        let ambience = Self.makeAmbienceWAV(seconds: 40)
        try write(ambience.wav, to: ambienceRelative)
        pvm.project.soundtracks.removeAll { $0.id == ambienceId }
        pvm.project.soundtracks.append(SoundtrackTrack(id: ambienceId, name: "Marrow Point ambience (sea, wind, foghorn)", audioFilePath: ambienceRelative,
                                                       startTimeOffset: 0, duration: 40, volume: 0.6, color: "#237873", waveformSamples: ambience.waveform, sortOrder: 0))

        // ---- 7. Scenes: production notes, sound, narration, summaries -----------------------
        struct SceneFill {
            let name: String, primary: String, status: String, notes: String, summary: String, emotions: [String: Double]
            let narration: String, noteCards: [(String, String)], sounds: [(String, String, Bool)]
        }
        let fills: [SceneFill] = [
            SceneFill(name: "Last Light", primary: "Noor", status: "Scheduled",
                      notes: "Golden-hour window is 19:40–20:05; we shoot the ladder two-shot first, then the wide as the fog comes in. Noor never looks at Teo until the thermos.",
                      summary: "Noor trims the lamp for the last time while fog swallows the sea. Teo arrives up the ladder with a thermos and a nervous grin, and is not looked at.",
                      emotions: ["resolve": 0.85, "loneliness": 0.7, "unease": 0.5, "tenderness": 0.35],
                      narration: "The light had been lit every night for a hundred and forty years. Tonight it would be lit by someone else.",
                      noteCards: [("Blocking", "Noor works the wick with her back to the ladder for the whole first page. She turns only when the thermos is in frame."),
                                  ("Weather", "If the fog fails, the wide is a smoke machine below the rail and a 12×12 silk over the lens.")],
                      sounds: [("Wind through the gallery rail, rising as the fog comes in", "ambient", true), ("The lens clockwork ticking behind glass", "effects", true), ("Ladder rattling as Teo climbs", "effects", false)]),
            SceneFill(name: "Kitchen Watch", primary: "Teo", status: "Scheduled",
                      notes: "Rain rig on the window, radio playback from the sound cart. The lantern comes off the hook on the line 'ours now' — not before.",
                      summary: "Rain hammers the kitchen window and the radio crackles a bulletin nobody answers. Teo spots a boat light dying in the swell; Noor closes the logbook, takes the lantern and pulls on her oilskin.",
                      emotions: ["dread": 0.8, "urgency": 0.75, "resolve": 0.6, "wonder": 0.3],
                      narration: "There is a kind of quiet that is only the sea getting ready.",
                      noteCards: [("Insert", "The logbook's last page is the only insert: 'Fog. Light kept. — N.'"), ("Playback", "Coastguard bulletin runs 22 s; Teo's line lands on the third repeat.")],
                      sounds: [("Rain on the window and the range ticking", "ambient", true), ("Coastguard bulletin through the VHF, half static", "dialogue_sfx", false), ("Foghorn, distant, every twelve seconds", "effects", true)]),
            SceneFill(name: "First Light", primary: "Idris", status: "Planning",
                      notes: "Walk-and-talk up the real path; steadicam behind, then the high wide from the cottage wall. Idris is soaked for every setup — two wet blankets, two dry.",
                      summary: "At dawn Noor and Teo walk the rescued boatman up the cliff path as the fog lifts. Idris says he counted the light; Noor tells him to keep counting.",
                      emotions: ["relief": 0.8, "tenderness": 0.75, "exhaustion": 0.6, "hope": 0.7],
                      narration: "By morning the fog had gone somewhere else, the way it does, and left the three of them on the path with nothing to steer by.",
                      noteCards: [("Continuity", "Blanket stripe outward, mud to the knees on Teo, Idris wears one boot."), ("Permit", "Coastal path permit 06:00–09:00; public access resumes on the dot.")],
                      sounds: [("Gulls, surf below, wind dropping", "ambient", true), ("Boots in mud, the blanket dragging", "effects", false), ("The foghorn stops mid-cycle", "effects", false)]),
        ]
        for f in fills {
            if try scene(f.name).narrations.isEmpty {
                try await run("add_narration", #"{"scene": "\#(esc(f.name))", "text": "\#(esc(f.narration))"}"#)
            }
            try editScene(f.name) { s in
                s.primaryCharacter = f.primary; s.productionStatus = f.status; s.notes = f.notes
                s.sceneOverviewSummary = f.summary; s.sceneEmotionalAnalysis = f.emotions
                s.sceneNotes = f.noteCards.enumerated().map { Note(content: $0.element.1, noteType: "text", chronologyNumber: $0.offset, title: $0.element.0) }
                s.soundNotes = f.sounds.enumerated().map { i, sound in
                    SoundNote(description: sound.0, soundType: sound.1, chronologyNumber: i,
                              audioFilePath: sound.1 == "ambient" ? ambienceRelative : nil,
                              volume: sound.1 == "ambient" ? 60 : 85, loop: sound.2, fadeInDuration: 1.5, fadeOutDuration: 2,
                              startTime: 0, endTime: sound.2 ? 40 : 6, tags: [sound.1])
                }
                for d in s.dialogues.indices where s.dialogues[d].tags.isEmpty {
                    s.dialogues[d].tags = [s.dialogues[d].character == "Noor" ? "dry" : s.dialogues[d].character == "Teo" ? "eager" : "hoarse"]
                }
                for a in s.actions.indices {
                    let text = s.actions[a].description.lowercased()
                    s.actions[a].characters = ["Noor", "Teo", "Idris"].filter { text.contains($0.lowercased()) }
                    if text.contains("fog") { s.actions[a].effects = ["fog"] }
                    if text.contains("rain") { s.actions[a].effects = ["rain"] }
                }
            }
        }

        // ---- 8. Shots: twelve, fully specified, with previews and storyboard frames ----------
        struct ShotFill { let scene: String, description: String, type: String, angle: String, lens: Int, aperture: String, movement: String, duration: Double, lighting: String }
        let plannedShots: [ShotFill] = [
            ShotFill(scene: "Last Light", description: "Wide: Noor alone on the gallery trimming the wick, fog pouring over the railing below her", type: "Wide", angle: "Low", lens: 24, aperture: "f/4", movement: "Static", duration: 9, lighting: "Practical lamp key, dusk sky fill"),
            ShotFill(scene: "Last Light", description: "Two-shot at the ladder: Teo's head and shoulders rising into frame with the thermos, Noor turning from the lamp", type: "Medium", angle: "Eye Level", lens: 35, aperture: "f/2.8", movement: "Slow push in", duration: 7, lighting: "Practical lamp key from behind Noor"),
            ShotFill(scene: "Last Light", description: "Insert: Noor's scarred hand trimming the wick with the pocketknife, the flame steadying", type: "Insert", angle: "High", lens: 85, aperture: "f/2", movement: "Static", duration: 4, lighting: "Flame as key, warm"),
            ShotFill(scene: "Last Light", description: "Over Noor's shoulder: the thermos held out in Teo's hand, the great lens turning behind them", type: "Over-the-Shoulder", angle: "Eye Level", lens: 50, aperture: "f/2.8", movement: "Static", duration: 6, lighting: "Lens sweep passes through frame"),
            ShotFill(scene: "Kitchen Watch", description: "Teo at the rain-streaked window, his reflection over the black sea, a faint boat light in the glass", type: "Close-up", angle: "Eye Level", lens: 50, aperture: "f/2", movement: "Static", duration: 8, lighting: "Lantern key from camera left, window reflection"),
            ShotFill(scene: "Kitchen Watch", description: "Noor lifting the brass storm lantern from its hook, logbook open on the enamel table behind her", type: "Medium", angle: "Low", lens: 35, aperture: "f/2.8", movement: "Pan with her", duration: 6, lighting: "Lantern becomes the key as she lifts it"),
            ShotFill(scene: "Kitchen Watch", description: "Wide of the round kitchen: Noor writing in the logbook by lantern light, Teo a silhouette at the window, the radio glowing on the dresser", type: "Wide", angle: "Eye Level", lens: 24, aperture: "f/4", movement: "Static", duration: 10, lighting: "Lantern pool, range glow, radio dial practical"),
            ShotFill(scene: "Kitchen Watch", description: "Insert: the logbook's last entry, 'Fog. Light kept.', the pen set down in the gutter", type: "Insert", angle: "High", lens: 85, aperture: "f/2.8", movement: "Static", duration: 4, lighting: "Lantern raking across the page"),
            ShotFill(scene: "First Light", description: "Three figures in single file on the cliff path at dawn, Idris in the blanket between Noor and Teo, fog lifting", type: "Wide", angle: "High", lens: 24, aperture: "f/5.6", movement: "Static", duration: 10, lighting: "Soft dawn from the sea"),
            ShotFill(scene: "First Light", description: "Idris looking back down at the sea, wrapped in the blanket, Noor's hand on his shoulder", type: "Close-up", angle: "Eye Level", lens: 85, aperture: "f/2", movement: "Static", duration: 7, lighting: "Dawn backlight, bounce fill"),
            ShotFill(scene: "First Light", description: "Tracking behind the three of them up the muddy path, the blanket dragging, gorse on both sides", type: "Medium", angle: "Eye Level", lens: 35, aperture: "f/4", movement: "Steadicam follow", duration: 12, lighting: "Available dawn light"),
            ShotFill(scene: "First Light", description: "Teo at the cottage wall looking back at the lighthouse, the lamp still turning in daylight", type: "Medium", angle: "Low", lens: 50, aperture: "f/4", movement: "Static", duration: 8, lighting: "Flat overcast dawn, lamp practical visible"),
        ]
        for planned in plannedShots {
            let existing = try scene(planned.scene).shots.contains { $0.description == planned.description }
            if !existing {
                try await run("add_shot", #"{"scene": "\#(esc(planned.scene))", "description": "\#(esc(planned.description))", "shot_type": "\#(planned.type)", "camera_angle": "\#(planned.angle)"}"#)
            }
            try editScene(planned.scene) { s in
                guard let i = s.shots.firstIndex(where: { $0.description == planned.description }) else { return }
                s.shots[i].lensMm = planned.lens; s.shots[i].aperture = planned.aperture; s.shots[i].movement = planned.movement
                s.shots[i].duration = planned.duration; s.shots[i].lightingStyle = planned.lighting; s.shots[i].status = "Ready"
                s.shots[i].shotType = planned.type; s.shots[i].cameraAngle = planned.angle
                // Link the beats the shot covers: spread the scene's lines across its shots in order.
                let perShot = max(1, Int((Double(s.dialogues.count + s.actions.count) / Double(max(1, s.shots.count))).rounded(.up)))
                var ordered: [(order: Int, id: String, isDialogue: Bool)] = []
                ordered += s.dialogues.map { (order: $0.chronologyNumber, id: $0.uuid, isDialogue: true) }
                ordered += s.actions.map { (order: $0.chronologyNumber, id: $0.uuid, isDialogue: false) }
                ordered.sort { $0.order < $1.order }
                let slice = ordered.dropFirst(i * perShot).prefix(perShot)
                s.shots[i].linkedDialogueIds = slice.filter { $0.isDialogue }.map { $0.id }
                s.shots[i].linkedActionIds = slice.filter { !$0.isDialogue }.map { $0.id }
                if let loc = s.location, let primary = pvm.project.locations.first(where: { $0.name == loc })?.primaryImage,
                   !s.shots[i].referenceMedia.contains(where: { $0.path == primary }) {
                    s.shots[i].referenceMedia.append(ReferenceMedia(type: .image, path: primary, caption: "Location plate: \(loc)"))
                }
            }
        }
        let characters = pvm.project.characters
        let locations = pvm.project.locations
        for (seqIndex, sequence) in pvm.project.sequences.enumerated() where !dry {
            for (sceneIdx, sc) in sequence.scenes.enumerated() {
                for (shotIndex, shot) in sc.shots.enumerated() {
                    if shot.previewImage == nil || !FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(shot.previewImage!).path) {
                        // Shot preview: exactly what CinematographyView+ShotPreview sends.
                        let started = Date()
                        let prompt = ShotPromptBuilder.previewPrompt(shot: shot, scene: sc, locations: locations, characters: characters)
                        let refs = CharacterReferenceHelper.collectReferenceImages(forScene: sc, characters: characters, locations: locations, projectDirectory: projectDir)
                        let png = try await draw(ImageGenerationRequest(
                            prompt: refs.isEmpty ? prompt : CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: refs) + prompt,
                            provider: .onDevice, aspectRatio: "16:9", numberOfImages: 1,
                            referenceImages: refs.isEmpty ? nil : refs,
                            brief: VisualBrief(purpose: .shot,
                                               subject: StoryboardSubjects.subject(for: shot, in: sc, locations: locations, characters: characters),
                                               framing: StoryboardSubjects.notes(for: shot))))
                        let relative = "assets/shots/shot_\(shot.shotId)/preview_\(stamp()).png"
                        try write(png, to: relative)
                        try? prompt.write(to: projectDir.appendingPathComponent("assets/shots/shot_\(shot.shotId)/prompt.txt"), atomically: true, encoding: .utf8)
                        pvm.project.sequences[seqIndex].scenes[sceneIdx].shots[shotIndex].previewImage = relative
                        record("shot-preview", "\(sc.name) · shot \(shot.shotId) (\(refs.count) refs)", relative, Date().timeIntervalSince(started))
                    }
                    if shot.storyboardImage == nil || !FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(shot.storyboardImage!).path) {
                        let started = Date()
                        let frame = try await LocalImageEngine.shared.generateFrame(StoryboardFrameSpec(
                            subject: StoryboardSubjects.subject(for: shot, in: sc, locations: locations, characters: characters),
                            notes: StoryboardSubjects.notes(for: shot), purpose: .shot))
                        let saved = try StoryboardFrameStore.save(png: frame, projectBasePath: projectDir, relativeDirectory: "assets/shots/shot_\(shot.shotId)")
                        pvm.project.sequences[seqIndex].scenes[sceneIdx].shots[shotIndex].storyboardImage = saved.relativePath
                        record("storyboard", "\(sc.name) · shot \(shot.shotId)", saved.relativePath, Date().timeIntervalSince(started))
                    }
                }
            }
        }
        // Scene previews for any scene still missing one (the build pass made all three).
        for name in sceneNames where !dry {
            guard try scene(name).sceneOverviewImage == nil else { continue }
            let started = Date()
            try await run("generate_scene_image", #"{"scene": "\#(esc(name))"}"#)
            record("scene-preview", name, try scene(name).sceneOverviewImage ?? "?", Date().timeIntervalSince(started))
        }

        // ---- 9. Vision board: images from the assistant, text and palette cards, a cord ---------
        let boardPrompts = [
            "the lighthouse beam turning through fog at dusk, seen from the water",
            "a brass storm lantern on an enamel table, rain streaking the window behind it",
            "three figures in single file on a muddy cliff path at dawn, fog lifting",
            "the great lighthouse lens behind glass, salt-white iron railings, a bruised sky",
        ]
        for prompt in boardPrompts where !dry && !pvm.project.beats.contains(where: { $0.title == String(prompt.prefix(60)) }) {
            let started = Date()
            try await run("generate_vision_board_image", #"{"prompt": "\#(esc(prompt))"}"#)
            record("vision-board", prompt, pvm.project.beats.last?.imagePath ?? "?", Date().timeIntervalSince(started))
        }
        if !pvm.project.beats.contains(where: { $0.cardType == "text" && $0.title == "Tone" }) {
            var zTop = (pvm.project.beats.map(\.zOrder).max() ?? 0) + 1
            let tone = VisionCard(title: "Tone", description: "How the film should feel", text: "Quiet, exact, unsentimental. Nobody raises their voice; the sea does.",
                                  tags: ["tone"], cardType: "text", canvasX: 20, canvasY: 460, zOrder: zTop, canvasWidth: 260, canvasHeight: 150, textStyle: "headline")
            zTop += 1
            let rule = VisionCard(title: "Rule", description: "Sound", text: "No score under dialogue. The lamp mechanism, the wind and the foghorn are the score.",
                                  tags: ["sound"], cardType: "text", canvasX: 300, canvasY: 460, zOrder: zTop, canvasWidth: 260, canvasHeight: 150, textStyle: "label")
            zTop += 1
            let palette = VisionCard(title: "Night palette", description: "Salt white, iron, lamp amber, bruised indigo", tags: ["colour"],
                                     cardType: "color_palette", colorPalette: ["#F5F6F3", "#5F6B66", "#C9A227", "#1F3A5F", "#1B1F1D"],
                                     department: "cinematography", canvasX: 580, canvasY: 460, zOrder: zTop, canvasWidth: 260, canvasHeight: 150)
            pvm.project.beats.append(contentsOf: [tone, rule, palette])
            if let firstImage = pvm.project.beats.first(where: { $0.cardType == "image" && $0.imagePath != nil }) {
                pvm.project.visionConnectors.append(VisionConnector(fromCardId: palette.id, toCardId: firstImage.id, label: "night exteriors"))
            }
        }
        if !dry { XCTAssertGreaterThanOrEqual(pvm.project.beats.count, 7, "four image cards, two text cards, a palette") }

        // ---- 10. Poster and project icon (Overview hero) ----------------------------------------
        let posterName = "\(Self.sanitizeFilename(pvm.project.name))_poster.png"
        if !dry, !FileManager.default.fileExists(atPath: projectDir.appendingPathComponent("posters/\(posterName)").path) {
            let started = Date()
            let png = try await draw(ImageGenerationRequest(
                prompt: "Professional theatrical movie poster for '\(pvm.project.name)'. Drama. A lighthouse keeper's last night; the beam through fog; a small boat light below.",
                provider: .onDevice, aspectRatio: "3:4",
                referenceImageBase64: try character("Noor").baseImage.map(base64), referenceMimeType: "image/png",
                brief: VisualBrief(purpose: .scene,
                                   subject: "Key art for a film called Keeper's Light: Noor, a weathered woman of fifty-eight in a black oilskin, small on the iron gallery of a lighthouse, the great beam cutting through fog over a black sea, a tiny boat light far below",
                                   framing: "Tall vertical poster composition, the figure small against the light, a lot of dark sea and fog, no lettering.")))
            try write(png, to: "posters/\(posterName)")
            try write(png, to: "posters/\(Self.sanitizeFilename(pvm.project.name))_poster_\(stamp()).png")
            pvm.project.overviewPosterPaths = ["posters/\(posterName)"]
            pvm.project.overviewPosterCurrentIndex = 0
            pvm.project.overviewPosterCustom = false
            record("poster", pvm.project.name, "posters/\(posterName)", Date().timeIntervalSince(started))
        }
        if !dry, pvm.project.projectIcon.isEmpty || !FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(pvm.project.projectIcon).path) {
            let started = Date()
            // An emblem is an object study (a mood-board purpose let a person in).
            let png = try await draw(ImageGenerationRequest(
                prompt: "Emblem for a film: a lighthouse on a rock with its beam turning, fog, simple and bold.", provider: .onDevice, aspectRatio: "1:1",
                brief: VisualBrief(purpose: .prop, subject: "an emblem of a lighthouse on a rock, its beam a single bright wedge through fog, simple and bold")))
            try write(png, to: "assets/project_icon.png")
            pvm.project.projectIcon = "assets/project_icon.png"
            record("icon", pvm.project.name, "assets/project_icon.png", Date().timeIntervalSince(started))
        }

        // ---- 11. Production: schedule, budget, cast, crew, equipment, teams, plan, cues, lighting, effects ---
        let shootDays: [(scene: String, date: String, slot: String, call: String, wrap: String, hours: Double, weather: String, backup: String)] = [
            ("Last Light", "2026-09-14", "Night", "16:00", "23:00", 6, "Fog or clear dusk; wind under 30 knots on the gallery", "Smoke below the rail, silk over the lens"),
            ("Kitchen Watch", "2026-09-15", "Night", "17:00", "02:00", 8, "Any — interior with rain rig", "None needed"),
            ("First Light", "2026-09-16", "Morning", "04:30", "10:00", 5, "Clearing fog preferred; no heavy rain on the path", "Move the cottage-wall shot to 09:00 and cover the walk in the cove"),
        ]
        for day in shootDays {
            let sc = try scene(day.scene)
            let cast = ["Noor", "Teo", "Idris"].filter { name in sc.dialogues.contains { $0.character == name } || sc.description.contains(name) }
            if !pvm.project.scheduleItems.contains(where: { $0.sceneName == day.scene }) {
                let castJSON = cast.map { "\"\($0)\"" }.joined(separator: ", ")
                try await run("schedule_scene", #"{"scene": "\#(esc(day.scene))", "date": "\#(day.date)", "time_slot": "\#(day.slot)", "location": "\#(esc(sc.location ?? ""))", "cast": [\#(castJSON)], "call_time": "\#(day.call)", "wrap_time": "\#(day.wrap)"}"#)
            }
            if let i = pvm.project.scheduleItems.firstIndex(where: { $0.sceneName == day.scene }) {
                pvm.project.scheduleItems[i].estimatedDurationHours = day.hours
                pvm.project.scheduleItems[i].requiredCrew = ["Director", "Director of Photography", "1st AD", "Gaffer", "Sound Recordist", "Props Master"]
                pvm.project.scheduleItems[i].requiredEquipment = ["ARRI Alexa Mini LF", "Zeiss Supreme Prime set", "Fog machine", day.scene == "Kitchen Watch" ? "Rain rig" : "Skypanel S60 ×2"]
                pvm.project.scheduleItems[i].requiredProps = sc.props
                pvm.project.scheduleItems[i].productionNotes = sc.notes
                pvm.project.scheduleItems[i].weatherRequirements = day.weather
                pvm.project.scheduleItems[i].backupPlan = day.backup
                pvm.project.scheduleItems[i].priority = day.scene == "Kitchen Watch" ? 1 : 2
                pvm.project.scheduleItems[i].estimatedCost = day.hours * 1_450
                pvm.project.scheduleItems[i].locationAddress = pvm.project.locations.first { $0.name == sc.location }?.address ?? ""
                pvm.project.scheduleItems[i].specialRequirements = day.scene == "Last Light" ? "Harness points on the gallery rail; safety officer on set." : day.scene == "First Light" ? "Coastal path permit 06:00–09:00; track mats." : "Rain rig water supply; 12 V practicals signed off."
            }
        }
        let budgetLines: [(String, Double, String, String)] = [
            ("Above the line", 9_500, "1000", "ATL"), ("Cast", 6_600, "1300", "ATL"), ("Crew", 12_400, "2000", "BTL"),
            ("Camera & lenses", 5_200, "2100", "BTL"), ("Lighting & grip", 4_300, "2200", "BTL"), ("Art, props & wardrobe", 3_900, "2400", "BTL"),
            ("Locations & permits", 2_100, "2600", "BTL"), ("Post-production", 4_500, "3000", "Post"),
        ]
        // The Budget view sets the budget up before any category exists;
        // the assistant's budget actions refuse a project without one.
        if pvm.project.projectBudget == nil {
            pvm.project.projectBudget = ProjectBudget(totalBudget: 48_500, currency: "USD", aiBudgetLimit: 200)
        }
        for line in budgetLines where !(pvm.project.projectBudget?.categories.contains(where: { $0.name == line.0 }) ?? false) {
            try await run("add_budget_category", #"{"name": "\#(esc(line.0))", "allocated": \#(line.1), "account_code": "\#(line.2)", "group": "\#(line.3)"}"#)
        }
        let expenses: [(String, Double, String, String, String, String)] = [
            ("Brass storm lantern build (×3)", 420, "Art, props & wardrobe", "2026-08-28", "Art department workshop", "Card"),
            ("Coastal path filming permit", 380, "Locations & permits", "2026-08-26", "North Coast Council", "Bank transfer"),
            ("Peacoats for the wet-down (×3)", 285, "Art, props & wardrobe", "2026-08-30", "Surplus store", "Card"),
            ("Alexa Mini LF + Supreme Primes, 3 days", 2_940, "Camera & lenses", "2026-09-01", "Northern Camera Hire", "Invoice"),
            ("Fog machine and fluid", 260, "Lighting & grip", "2026-09-02", "Northern Props Hire", "Card"),
            ("Ferry and accommodation, crew", 1_120, "Crew", "2026-09-03", "Marrow Cove Inn", "Bank transfer"),
        ]
        if (pvm.project.projectBudget?.expenses.isEmpty ?? true) {
            for e in expenses {
                try await run("add_expense", #"{"description": "\#(esc(e.0))", "amount": \#(e.1), "category": "\#(esc(e.2))", "date": "\#(e.3)", "vendor": "\#(esc(e.4))", "payment_method": "\#(e.5)"}"#)
            }
        }
        let castList: [(actor: String, character: String, roleType: String, union: String, rate: Double, size: String, notes: String)] = [
            ("Halima Rasheed", "Noor", "Principal", "Union", 650, "UK 10", "Comfortable with heights; has done a harness before. No stunt double for the gallery."),
            ("Lucas Ferreira", "Teo", "Principal", "Non-Union", 420, "UK 40 long", "Seasick for real on the ferry — schedule the crossing early."),
            ("Omar Haddad", "Idris", "Supporting", "Union", 480, "UK 44", "Cold-water wet-down: warm tent and dry doubles between setups."),
        ]
        for member in castList where !pvm.project.castMembers.contains(where: { $0.characterName == member.character }) {
            try await run("add_cast_member", #"{"actor": "\#(esc(member.actor))", "character": "\#(member.character)", "role_type": "\#(member.roleType)", "union_status": "\#(member.union)"}"#)
        }
        for member in castList {
            guard let i = pvm.project.castMembers.firstIndex(where: { $0.characterName == member.character }) else { continue }
            let c = try character(member.character)
            pvm.project.castMembers[i].characterDescription = c.about
            pvm.project.castMembers[i].dailyRate = member.rate; pvm.project.castMembers[i].paymentType = "Daily Rate"; pvm.project.castMembers[i].overtimeRate = member.rate / 8 * 1.5
            pvm.project.castMembers[i].height = "\(Int(c.heightCm ?? 0)) cm"; pvm.project.castMembers[i].hairColor = c.hairColor; pvm.project.castMembers[i].eyeColor = c.eyeColorDescription
            pvm.project.castMembers[i].wardrobeSize = member.size; pvm.project.castMembers[i].wardrobeNotes = c.costumes?.map(\.name).joined(separator: ", ") ?? ""
            pvm.project.castMembers[i].specialRequirements = member.notes; pvm.project.castMembers[i].notes = member.notes
            pvm.project.castMembers[i].availabilityNotes = "Available 13–17 September."; pvm.project.castMembers[i].contractSigned = true
            pvm.project.castMembers[i].photoPath = c.baseImage ?? ""
        }
        let crewList: [(name: String, role: String, dept: String, rate: Double, skills: [String])] = [
            ("Mira Okonkwo", "Director", "Direction", 0, ["directing", "editing"]),
            ("Jonas Lindqvist", "Director of Photography", "Camera", 750, ["Alexa", "steadicam", "night exteriors"]),
            ("Priya Natarajan", "1st AD", "Production", 520, ["scheduling", "safety"]),
            ("Ben Achebe", "Gaffer", "Lighting", 480, ["practicals", "12 V rigs", "generators"]),
            ("Rosa Delgado", "Sound Recordist", "Sound", 450, ["boom", "playback", "ambience"]),
            ("Ines Laurent", "Production Designer", "Art", 500, ["set dressing", "ageing", "graphics"]),
            ("Kwame Mensah", "Costume Designer", "Wardrobe", 430, ["workwear", "wet-down continuity"]),
            ("Sam Whitlock", "Props Master", "Art", 400, ["fabrication", "practical lights", "continuity"]),
        ]
        for member in crewList where !pvm.project.crewMembers.contains(where: { $0.name == member.name }) {
            try await run("add_crew_member", #"{"name": "\#(esc(member.name))", "role": "\#(esc(member.role))", "department": "\#(member.dept)"}"#)
        }
        for member in crewList {
            guard let i = pvm.project.crewMembers.firstIndex(where: { $0.name == member.name }) else { continue }
            pvm.project.crewMembers[i].dailyRate = member.rate; pvm.project.crewMembers[i].paymentType = member.rate == 0 ? "Deferred" : "Daily Rate"
            pvm.project.crewMembers[i].employmentType = "Freelance"; pvm.project.crewMembers[i].skills = member.skills
            pvm.project.crewMembers[i].startDate = "2026-09-13"; pvm.project.crewMembers[i].endDate = "2026-09-16"
            pvm.project.crewMembers[i].kitFee = member.dept == "Sound" || member.dept == "Camera" ? 120 : 0
            pvm.project.crewMembers[i].notes = "Three-day shoot at Marrow Point; ferry on the 13th."
            pvm.project.crewMembers[i].contractSigned = true
        }
        let gear: [(name: String, category: String, qty: Int, rental: Bool, maker: String, model: String, daily: Double, specs: [String: String])] = [
            ("ARRI Alexa Mini LF", "Camera", 1, true, "ARRI", "Alexa Mini LF", 650, ["sensor": "LF 4.5K", "mount": "LPL", "codec": "ARRIRAW"]),
            ("Zeiss Supreme Prime set", "Lenses", 1, true, "Zeiss", "Supreme Prime 25/35/50/85", 420, ["coverage": "full frame", "T-stop": "T1.5"]),
            ("Skypanel S60", "Lighting", 2, true, "ARRI", "S60-C", 95, ["output": "RGBW", "power": "420 W"]),
            ("Fog machine", "Effects", 1, true, "Look Solutions", "Unique 2.1 hazer", 60, ["fluid": "water-based"]),
            ("Rain rig", "Effects", 1, true, "Northern Props Hire", "Window rain bar 2 m", 85, ["supply": "mains hose"]),
            ("Sound cart", "Sound", 1, false, "Sound Devices", "Scorpio + 2× MKH50", 0, ["tracks": "16"]),
            ("Steadicam", "Grip", 1, true, "Tiffen", "M-1 Volt", 300, ["payload": "up to 22 kg"]),
            ("Generator", "Power", 1, true, "Honda", "EU70is", 70, ["output": "7 kVA", "noise": "quiet"]),
        ]
        for item in gear where !pvm.project.equipmentLibrary.contains(where: { $0.name == item.name }) {
            try await run("add_equipment_item", #"{"name": "\#(esc(item.name))", "category": "\#(item.category)", "quantity": \#(item.qty), "rental": \#(item.rental)}"#)
        }
        for item in gear {
            guard let i = pvm.project.equipmentLibrary.firstIndex(where: { $0.name == item.name }) else { continue }
            pvm.project.equipmentLibrary[i].manufacturer = item.maker; pvm.project.equipmentLibrary[i].model = item.model
            pvm.project.equipmentLibrary[i].description = "\(item.maker) \(item.model)"; pvm.project.equipmentLibrary[i].specs = item.specs
            pvm.project.equipmentLibrary[i].isRental = item.rental; pvm.project.equipmentLibrary[i].rentalDailyRate = item.daily
            pvm.project.equipmentLibrary[i].rentalWeeklyRate = item.daily * 4; pvm.project.equipmentLibrary[i].rentalCompany = item.rental ? "Northern Camera Hire" : ""
            pvm.project.equipmentLibrary[i].quantityOwned = item.rental ? 0 : item.qty; pvm.project.equipmentLibrary[i].quantityAvailable = item.qty
            pvm.project.equipmentLibrary[i].condition = "Good"; pvm.project.equipmentLibrary[i].storageLocation = item.rental ? "Camera truck" : "Sound cart"
            pvm.project.equipmentLibrary[i].responsibleCrewMemberName = item.category == "Sound" ? "Rosa Delgado" : item.category == "Lighting" || item.category == "Power" ? "Ben Achebe" : "Jonas Lindqvist"
            pvm.project.equipmentLibrary[i].responsibleCrewMemberId = pvm.project.crewMembers.first { $0.name == pvm.project.equipmentLibrary[i].responsibleCrewMemberName }?.id
        }
        if pvm.project.equipmentAllocations.isEmpty {
            for item in pvm.project.equipmentLibrary {
                let mode: ProductionAllocationMode = item.name == "Rain rig" || item.name == "Steadicam" ? .specificDays : .fullProduction
                let dates = item.name == "Rain rig" ? ["2026-09-15"] : item.name == "Steadicam" ? ["2026-09-16"] : []
                pvm.project.equipmentAllocations.append(EquipmentAllocation(equipmentItemId: item.id, allocationMode: mode, allocatedDates: dates,
                                                                            quantityAllocated: item.quantityAvailable, notes: mode == .specificDays ? "Only the day it is needed." : "Whole shoot."))
            }
        }
        if pvm.project.teams.isEmpty {
            func crewIds(_ names: [String]) -> [String] { pvm.project.crewMembers.filter { names.contains($0.name) }.map(\.id) }
            pvm.project.teams.append(Team(name: "Main Unit", description: "Everyone on the rock for all three days.", teamType: "Shooting Unit",
                                          castMemberIds: pvm.project.castMembers.map(\.id),
                                          crewMemberIds: crewIds(["Mira Okonkwo", "Jonas Lindqvist", "Priya Natarajan", "Ben Achebe", "Rosa Delgado"]),
                                          teamLeadId: pvm.project.crewMembers.first { $0.name == "Priya Natarajan" }?.id, notes: "Ferry 13 Sept 07:40."))
            pvm.project.teams.append(Team(name: "Art Department", description: "Props, wardrobe and set dressing; on the rock a day early.", teamType: "Department",
                                          crewMemberIds: crewIds(["Ines Laurent", "Kwame Mensah", "Sam Whitlock"]),
                                          teamLeadId: pvm.project.crewMembers.first { $0.name == "Ines Laurent" }?.id, notes: "Dress the kitchen on the 13th."))
        }
        let plan: [(name: String, category: String, start: String, end: String, milestone: Bool, depends: [String], notes: String)] = [
            ("Script locked", "Pre-Production", "2026-08-24", "2026-08-24", true, [], "White draft; no further changes without the director."),
            ("Lock locations and permits", "Locations", "2026-08-25", "2026-09-05", false, ["Script locked"], "Lighthouse authority access letter; coastal path permit."),
            ("Build and age the props", "Props", "2026-08-26", "2026-09-10", false, ["Script locked"], "Lantern ×3, logbook ×2, thermos ×2."),
            ("Wardrobe fittings and wet-down tests", "Wardrobe", "2026-09-01", "2026-09-11", false, ["Script locked"], "Three peacoats; test the wet-down in the cove."),
            ("Tech recce on the rock", "Pre-Production", "2026-09-08", "2026-09-08", true, ["Lock locations and permits"], "Harness points, generator position, rain rig water."),
            ("Shoot: Last Light", "Shooting", "2026-09-14", "2026-09-14", false, ["Tech recce on the rock", "Build and age the props"], "Dusk window 19:40–20:05."),
            ("Shoot: Kitchen Watch", "Shooting", "2026-09-15", "2026-09-15", false, ["Shoot: Last Light"], "Interior; rain rig."),
            ("Shoot: First Light", "Shooting", "2026-09-16", "2026-09-16", false, ["Shoot: Kitchen Watch"], "Dawn call 04:30."),
            ("Picture and sound edit", "Post-Production", "2026-09-21", "2026-10-16", false, ["Shoot: First Light"], "Cut in story order; ambience bed first."),
            ("Picture lock", "Post-Production", "2026-10-16", "2026-10-16", true, ["Picture and sound edit"], ""),
        ]
        for task in plan where !pvm.project.ganttTasks.contains(where: { $0.name == task.name }) {
            let deps = task.depends.map { "\"\(esc($0))\"" }.joined(separator: ", ")
            try await run("add_gantt_task", #"{"name": "\#(esc(task.name))", "category": "\#(task.category)", "start_date": "\#(task.start)", "end_date": "\#(task.end)", "milestone": \#(task.milestone), "depends_on": [\#(deps)]}"#)
            if let i = pvm.project.ganttTasks.firstIndex(where: { $0.name == task.name }) {
                pvm.project.ganttTasks[i].notes = task.notes; pvm.project.ganttTasks[i].taskDescription = task.notes
                pvm.project.ganttTasks[i].status = task.start < "2026-08-27" ? "Complete" : "Planned"
                pvm.project.ganttTasks[i].completionPercentage = task.start < "2026-08-27" ? 100 : 0
                if task.category == "Shooting" {
                    pvm.project.ganttTasks[i].assignedCharacterNames = ["Noor", "Teo", "Idris"]
                    pvm.project.ganttTasks[i].locationNames = pvm.project.locations.map(\.name)
                    pvm.project.ganttTasks[i].assignedCrewIds = pvm.project.crewMembers.map(\.id)
                    pvm.project.ganttTasks[i].assignedCastIds = pvm.project.castMembers.map(\.id)
                }
                if task.category == "Wardrobe" { pvm.project.ganttTasks[i].costumeNames = wardrobe.map(\.name) }
                if task.category == "Props" { pvm.project.ganttTasks[i].requiredPropIds = pvm.project.props.map(\.id) }
            }
        }
        if pvm.project.lighting.isEmpty {
            pvm.project.lighting = [
                Lighting(name: "Lamp-room practical", type: "Key", color: "#FFD9A0", intensity: 0.9, position: "Back", notes: "The lens itself; the beam sweep is the key on the gallery."),
                Lighting(name: "Dusk sky fill", type: "Fill", color: "#7A8DB3", intensity: 0.35, position: "Front", notes: "Skypanel through a 12×12 silk over the rail."),
                Lighting(name: "Kitchen lantern", type: "Key", color: "#FFC46B", intensity: 0.8, position: "Side", notes: "Hidden LED in the hero lantern; dims as it leaves the hook."),
                Lighting(name: "Dawn bounce", type: "Fill", color: "#E8EEF5", intensity: 0.5, position: "Front", notes: "8×8 ultrabounce from the sea side on the path."),
            ]
        }
        if pvm.project.effects.isEmpty {
            pvm.project.effects = [
                EffectDef(name: "Sea fog", category: "Fog", params: ["density": "heavy", "source": "hazer below the rail", "wind": "under 30 knots"], notes: "Rolls over the railing in Last Light; lifts through First Light."),
                EffectDef(name: "Window rain", category: "Rain", params: ["rig": "2 m rain bar", "intensity": "hammering"], notes: "Kitchen Watch only; streaks read against the lantern."),
                EffectDef(name: "Gallery wind", category: "Atmospheric", params: ["fan": "Ritter 2×", "direction": "sea to land"], notes: "Enough to move Noor's hair and the oilskin, not the camera."),
            ]
        }
        if pvm.project.lightCues.isEmpty {
            let last = try scene("Last Light"), kitchen = try scene("Kitchen Watch"), first = try scene("First Light")
            pvm.project.lightCues = [
                LightCue(name: "Beam sweep", cueNumber: "Q1", workflow: .cinema, fixtureType: .practical, startTime: 0, duration: 9, sceneId: last.uuid, sceneName: last.name,
                         intensity: 0.9, color: "#FFD9A0", colorTemperature: 2700, position: .backHigh, transitionIn: .cut, transitionOut: .cut, motivation: .lamp),
                LightCue(name: "Dusk fill down", cueNumber: "Q2", workflow: .cinema, fixtureType: .ledPanel, startTime: 9, duration: 12, sceneId: last.uuid, sceneName: last.name,
                         intensity: 0.35, intensityEnd: 0.15, color: "#7A8DB3", colorTemperature: 6500, position: .frontHigh, transitionIn: .fadeIn, transitionOut: .fadeOut, fadeInDuration: 2, fadeOutDuration: 4, motivation: .natural),
                LightCue(name: "Lantern off the hook", cueNumber: "Q3", workflow: .cinema, fixtureType: .practical, startTime: 20, duration: 6, sceneId: kitchen.uuid, sceneName: kitchen.name,
                         intensity: 0.8, intensityEnd: 0.6, color: "#FFC46B", colorTemperature: 2400, position: .sideLeft, transitionIn: .cut, transitionOut: .slow, fadeOutDuration: 3, motivation: .lamp),
                LightCue(name: "Dawn bounce up", cueNumber: "Q4", workflow: .cinema, fixtureType: .bounce, startTime: 0, duration: 30, sceneId: first.uuid, sceneName: first.name,
                         intensity: 0.5, color: "#E8EEF5", colorTemperature: 5600, position: .frontLow, transitionIn: .fadeIn, transitionOut: .cut, fadeInDuration: 6, motivation: .sunlight),
            ]
        }
        if pvm.project.sfxCues.isEmpty {
            pvm.project.sfxCues = [
                SFXCue(name: "Fog over the rail", cueNumber: "FX1", effectType: .smoke, startTime: 0, duration: 30, intensity: 0.8, intensityEnd: 1.0, intensityProfile: .rampUp,
                       placement: .background, coverage: 0.7, transitionIn: .fadeIn, transitionOut: .fadeOut, fadeInDuration: 4, fadeOutDuration: 4,
                       requiresVentilation: false, safetyNotes: "Hazer below the rail; harness on the operator.", operatorRequired: true, notes: "Last Light wide."),
                SFXCue(name: "Window rain", cueNumber: "FX2", effectType: .rain, startTime: 0, duration: 60, intensity: 0.9, placement: .background, coverage: 0.3,
                       transitionIn: .cut, transitionOut: .cut, fadeInDuration: 0, fadeOutDuration: 0,
                       requiresVentilation: false, safetyNotes: "Water away from the 12 V practicals; drip tray under the sill.", operatorRequired: true, notes: "Kitchen Watch, all setups."),
                SFXCue(name: "Gallery wind", cueNumber: "FX3", effectType: .wind, startTime: 0, duration: 30, intensity: 0.5, placement: .stageLeft, coverage: 0.5,
                       transitionIn: .fadeIn, transitionOut: .fadeOut, fadeInDuration: 2, fadeOutDuration: 2,
                       requiresVentilation: false, safetyNotes: "Fans clamped to the rail; no loose cables on the gallery.", operatorRequired: false, notes: "Last Light."),
            ]
        }
        if pvm.project.supportCues.isEmpty {
            pvm.project.supportCues = [
                SupportCue(name: "Wet-down Idris", cueNumber: "S1", actionType: .quickChange, startTime: 0, duration: 240, priority: .high, stageArea: .backstage,
                           assignedTo: "Kwame Mensah", equipment: "Warm tent, sprayer, dry peacoat ×2", notes: "Before every setup of First Light.", safetyNotes: "Cold water; warm tent within 20 m."),
                SupportCue(name: "Reset the lantern on its hook", cueNumber: "S2", actionType: .propMove, startTime: 0, duration: 60, priority: .medium, stageArea: .centerStage,
                           assignedTo: "Sam Whitlock", equipment: "Hero lantern, felt pad", notes: "Between takes of shot 6.", safetyNotes: ""),
                SupportCue(name: "Dress the kitchen for night", cueNumber: "S3", actionType: .setDressing, startTime: 0, duration: 1800, priority: .high, stageArea: .centerStage,
                           assignedTo: "Ines Laurent", equipment: "Logbook, thermos (empty), radio practical", notes: "Thermos empty, lid off — it came down from the gallery.", safetyNotes: "12 V practicals signed off by the gaffer."),
            ]
        }

        // ---- 12. Save, and check that every feature is populated -----------------------------
        if dry {
            print("[LocalPopulate] dry run: every record and action applied, nothing drawn, nothing saved")
        } else {
            await pvm.save()
            print("[LocalPopulate] saved \(projectFile.path)")
        }
        let project = pvm.project
        for c in project.characters {
            XCTAssertFalse((c.backgroundStory ?? "").isEmpty, "\(c.name) has a backstory")
            // The Personality tab's 25 Big-Five names sit beside the record's
            // 25 legacy lowercase defaults — that is the app's own shape.
            for trait in bios[0].traits.keys { XCTAssertNotNil(c.traits[trait], "\(c.name) has the \(trait) trait") }
            XCTAssertFalse((c.relationships ?? [:]).isEmpty, "\(c.name) has relationships")
            XCTAssertFalse((c.costumes ?? []).isEmpty, "\(c.name) has a costume")
            guard !dry else { continue }
            for path in [c.baseImage, c.imageThreeQuarterLeft, c.imageThreeQuarterRight, c.imageProfileLeft, c.imageProfileRight, c.imageBack] {
                XCTAssertNotNil(path, "\(c.name) has every turnaround angle")
            }
            for costume in c.costumes ?? [] {
                for path in [costume.imageFront, costume.imageThreeQuarterLeft, costume.imageThreeQuarterRight, costume.imageProfile, costume.imageBack, costume.imageFullBody] {
                    XCTAssertNotNil(path, "\(c.name) · \(costume.name) has all six angle images")
                }
            }
        }
        XCTAssertGreaterThanOrEqual(project.props.count, 5)
        for l in project.locations { XCTAssertFalse(l.styleAttributes.isEmpty) }
        let allShots = project.sequences.flatMap(\.scenes).flatMap(\.shots)
        XCTAssertEqual(allShots.count, 12)
        XCTAssertTrue(allShots.allSatisfy { $0.lensMm != nil })
        for s in project.sequences.flatMap(\.scenes) {
            XCTAssertFalse(s.narrations.isEmpty); XCTAssertFalse(s.soundNotes.isEmpty)
            XCTAssertFalse(s.sceneNotes.isEmpty); XCTAssertFalse(s.props.isEmpty); XCTAssertFalse(s.costumeAssignments?.isEmpty ?? true)
        }
        if !dry {
            XCTAssertTrue(project.props.allSatisfy { $0.thumbnail != nil }, "every prop has a concept image")
            for l in project.locations {
                for v in ["day", "night", "golden_hour", "overcast", "wide", "detail"] {
                    XCTAssertTrue(l.images.contains { $0.contains(v) }, "\(l.name) has a \(v) variation")
                }
            }
            XCTAssertTrue(allShots.allSatisfy { $0.previewImage != nil && $0.storyboardImage != nil })
            for s in project.sequences.flatMap(\.scenes) { XCTAssertNotNil(s.sceneOverviewImage) }
            XCTAssertGreaterThanOrEqual(project.beats.filter { $0.cardType == "image" }.count, 4)
            XCTAssertFalse(project.overviewPosterPaths.isEmpty)
        }
        XCTAssertEqual(project.scheduleItems.count, 3)
        XCTAssertGreaterThanOrEqual(project.projectBudget?.categories.count ?? 0, 8)
        XCTAssertEqual(project.castMembers.count, 3)
        XCTAssertGreaterThanOrEqual(project.crewMembers.count, 8)
        XCTAssertGreaterThanOrEqual(project.equipmentLibrary.count, 8)
        XCTAssertGreaterThanOrEqual(project.ganttTasks.count, 10)
        XCTAssertEqual(project.teams.count, 2)
        XCTAssertEqual(project.soundtracks.count, 1)
        XCTAssertEqual(project.lightCues.count, 4); XCTAssertEqual(project.sfxCues.count, 3); XCTAssertEqual(project.supportCues.count, 3)
    }

    // MARK: - Helpers

    /// Mirrors ProjectOverviewView+HeroBanner.sanitizeFilename (private there).
    static func sanitizeFilename(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_").replacingOccurrences(of: ":", with: "_")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        sanitized = sanitized.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
        while sanitized.contains("__") { sanitized = sanitized.replacingOccurrences(of: "__", with: "_") }
        return sanitized.isEmpty ? "project" : sanitized
    }

    /// A deterministic sea-wind-and-foghorn bed: low-passed noise with a slow
    /// swell, a two-tone horn every twelve seconds. 16-bit mono WAV plus the
    /// 4096-bucket peak waveform the timeline draws.
    static func makeAmbienceWAV(seconds: Double, rate: Int = 22050) -> (wav: Data, waveform: [Float]) {
        let count = Int(seconds * Double(rate))
        var samples = [Int16](repeating: 0, count: count)
        var seed: UInt32 = 0x9E37_79B9
        var slow: Float = 0, mid: Float = 0
        for i in 0..<count {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let white = Float(Int32(bitPattern: seed)) / Float(Int32.max)
            slow += 0.015 * (white - slow)
            mid += 0.12 * (white - mid)
            let t = Float(i) / Float(rate)
            let swell = 0.55 + 0.45 * sinf(2 * .pi * t / 9)
            var v = slow * 7 * swell + mid * 0.3 * swell
            let phase = fmodf(t, 12)
            if phase < 2.5 {
                let envelope = sinf(.pi * phase / 2.5)
                v += envelope * 0.35 * (sinf(2 * .pi * 110 * t) + 0.5 * sinf(2 * .pi * 165 * t))
            }
            v = max(-1, min(1, v * 0.8))
            samples[i] = Int16(v * 32_767)
        }
        let buckets = 4096
        var waveform = [Float](repeating: 0, count: buckets)
        let per = max(1, count / buckets)
        for b in 0..<buckets {
            let start = b * per, end = min(count, start + per)
            if start < end { waveform[b] = (start..<end).reduce(Float(0)) { max($0, abs(Float(samples[$1]) / 32_767)) } }
        }
        var wav = Data()
        func append<T: FixedWidthInteger>(_ value: T) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
        let dataBytes = UInt32(count * 2)
        wav.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + dataBytes)); wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(rate)); append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
        wav.append(contentsOf: Array("data".utf8)); append(dataBytes)
        samples.withUnsafeBufferPointer { wav.append(Data(buffer: $0)) }
        return (wav, waveform)
    }
}
