//
//  StressProjectGenerator.swift
//  DirectorsChair-Desktop
//
//  Deterministic synthetic project for performance benchmarking. Every run
//  with the same seed produces byte-identical content, so before/after
//  measurements across implementations compare identical workloads.
//
//  Reference scale (~8x "The Last Frame"): 60 scenes, ~400 shots,
//  ~2,000 script elements, 25 characters, 30 locations, 40 props, cues.
//

import Foundation
import AppKit
import DirectorsChairCore

/// Seeded RNG (SplitMix64) — SystemRandomNumberGenerator is not seedable.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum StressProjectGenerator {

    static let projectName = "Stress Test L60"
    static let seed: UInt64 = 0xD1EC7042_C4A1  // fixed — never change between comparisons

    // MARK: - Vocabulary (deterministic content sources)

    private static let firstNames = ["ALICE", "BALU", "CHITRA", "DEV", "ESHA", "FARHAN", "GEETA",
        "HARI", "INDU", "JOSE", "KAVYA", "LENIN", "MEERA", "NANDU", "OMANA", "PRAKASH",
        "RANI", "SURESH", "TARA", "UNNI", "VIMALA", "WASIM", "XAVIER", "YAMUNA", "ZARA"]

    private static let locationNames = ["LIGHTHOUSE", "FISHING HARBOR", "TEA SHOP", "POLICE STATION",
        "RAILWAY PLATFORM", "PADDY FIELD", "TEMPLE COURTYARD", "OLD LIBRARY", "FERRY TERMINAL",
        "MARKET STREET", "HOSPITAL WARD", "EDITING ROOM", "ROOFTOP", "BUS DEPOT", "RIVERBANK",
        "COURTROOM", "SCHOOL VERANDA", "WORKSHOP", "BANQUET HALL", "BACKWATER JETTY",
        "MOUNTAIN ROAD", "CINEMA LOBBY", "DARKROOM", "NEWSPAPER OFFICE", "TAILOR SHOP",
        "SPICE WAREHOUSE", "BEACH SHACK", "ANCESTRAL HOME", "TERRACE GARDEN", "STUDIO FLOOR"]

    private static let propNames = ["Brass Telescope", "Film Reel Canister", "Typewriter",
        "Kerosene Lamp", "Fishing Net", "Pocket Watch", "Letter Bundle", "Umbrella",
        "Cassette Player", "Harmonium", "Steel Tiffin Box", "Old Camera", "Clapperboard",
        "Newspaper Stack", "Bicycle", "Transistor Radio", "Wooden Chess Set", "Oil Lantern",
        "Rope Coil", "Medicine Bottle", "Photo Album", "Fountain Pen", "Match Box",
        "Coir Basket", "Boat Oar", "Ration Card", "Tea Kettle", "Ledger Book",
        "Megaphone", "Light Meter", "Slate Board", "Costume Trunk", "Mirror Frame",
        "Ceiling Fan", "Gramophone", "Key Ring", "Torch Light", "Rain Coat",
        "Ticket Roll", "Script Binder"]

    private static let times = ["DAY", "NIGHT", "DUSK", "DAWN", "CONTINUOUS"]

    private static let actionFragments = [
        "crosses the room slowly, watching the light shift across the floor",
        "picks up the object and turns it over, weighing something unsaid",
        "stares out past the horizon where the boats scatter into fog",
        "counts the change twice, then pushes it back across the counter",
        "listens to the rain begin on the tin roof, softly at first",
        "folds the letter along its worn creases and pockets it",
        "waits for the sound of the last bus to fade before moving",
        "wipes the lens with a corner of a mundu, squinting at the sun",
        "arranges the props on the shelf with unnecessary precision",
        "walks the length of the platform as the signal turns green"]

    private static let dialogueFragments = [
        "You keep saying tomorrow. I stopped counting tomorrows in June.",
        "The reel is fine. It's the projector that forgot how to dream.",
        "If the tide comes early, we shoot the ending first.",
        "Nobody remembers the frame. They remember how it made them feel.",
        "Ask the tea shop. They know everything before the newspaper does.",
        "I measured the light twice. Both times it said: wait.",
        "That door has been locked since before you were born.",
        "Cut when she looks away. Not before. Never before.",
        "The negative survives. That's more than most of us manage.",
        "Bring the lantern. The generator has opinions tonight."]

    // MARK: - Generation

    /// Build the full project in memory. Deterministic for a given seed.
    static func makeProject(scenes sceneCount: Int = 60,
                            shotsPerScene: Int = 7,
                            seed: UInt64 = seed) -> Project {
        var rng = SeededRandom(seed: seed)

        let characters = firstNames.map { Character(name: $0.capitalized) }
        let locations = locationNames.prefix(30).map { Location(name: $0) }
        let props = propNames.prefix(40).map { Prop(id: UUID().uuidString, name: $0) }

        var globalChronology = 1
        var shotCounter = 1
        var sequences: [Sequence] = []

        let scenesPerSequence = 10
        let sequenceCount = Int(ceil(Double(sceneCount) / Double(scenesPerSequence)))

        for seqIdx in 0..<sequenceCount {
            var scenes: [Scene] = []
            let scenesInThisSequence = min(scenesPerSequence, sceneCount - seqIdx * scenesPerSequence)

            for scIdx in 0..<scenesInThisSequence {
                let sceneNumber = seqIdx * scenesPerSequence + scIdx + 1
                let location = locationNames[Int(rng.next() % UInt64(locationNames.count))]
                let intro = rng.next() % 3 == 0 ? "EXT." : "INT."
                let time = times[Int(rng.next() % UInt64(times.count))]

                var dialogues: [Dialogue] = []
                var actions: [Action] = []
                var narrations: [Narration] = []
                var chronology = 1

                // ~30 script items per scene → ~2,000 elements total with
                // headings/descriptions across 60 scenes.
                let itemCount = 26 + Int(rng.next() % 9)
                for _ in 0..<itemCount {
                    let roll = rng.next() % 10
                    if roll < 6 {
                        let speaker = characters[Int(rng.next() % UInt64(characters.count))].name
                        let text = dialogueFragments[Int(rng.next() % UInt64(dialogueFragments.count))]
                        dialogues.append(Dialogue(character: speaker, text: text,
                                                  chronologyNumber: chronology,
                                                  globalChronologyNumber: globalChronology))
                    } else if roll < 9 {
                        let subject = characters[Int(rng.next() % UInt64(characters.count))].name.capitalized
                        let frag = actionFragments[Int(rng.next() % UInt64(actionFragments.count))]
                        actions.append(Action(description: "\(subject) \(frag).",
                                              chronologyNumber: chronology))
                    } else {
                        narrations.append(Narration(text: "The town holds its breath; scene \(sceneNumber) turns on a small decision.",
                                                    chronologyNumber: chronology))
                    }
                    chronology += 1
                    globalChronology += 1
                }

                var shots: [Shot] = []
                for s in 0..<shotsPerScene {
                    shots.append(Shot(shotId: shotCounter,
                                      itemChronology: min(s * 4 + 1, chronology - 1),
                                      description: "Scene \(sceneNumber) shot \(s + 1): coverage of the \(location.lowercased()).",
                                      cameraAngle: ["Wide", "Medium", "Close-Up", "Over-Shoulder"][Int(rng.next() % 4)],
                                      movement: ["Static", "Pan", "Dolly", "Handheld"][Int(rng.next() % 4)]))
                    shotCounter += 1
                }

                var scene = Scene(
                    name: "Scene \(sceneNumber)",
                    description: "At the \(location.lowercased()), the day's plan collides with the tide schedule.",
                    dialogues: dialogues,
                    actions: actions,
                    narrations: narrations,
                    shots: shots
                )
                scene.location = "\(intro) \(location) - \(time)"
                scene.props = (0..<3).map { _ in propNames[Int(rng.next() % UInt64(propNames.count))] }
                scenes.append(scene)
            }
            sequences.append(Sequence(name: "Act \(seqIdx + 1)", scenes: scenes))
        }

        var project = Project(
            name: projectName,
            description: "Deterministic synthetic project for UI performance benchmarking (seed \(seed)).",
            director: "Benchmark Rig",
            genre: "Drama",
            characters: characters,
            props: Array(props),
            locations: Array(locations),
            sequences: sequences
        )

        // Cue tracks (exercise the timeline cue lanes and the onChange compares)
        for i in 0..<40 {
            project.lightCues.append(LightCue(name: "LX \(i + 1)",
                                              cueNumber: "Q\(i + 1)",
                                              startTime: Double(i) * 12.0))
        }
        for i in 0..<30 {
            project.sfxCues.append(SFXCue(name: "SFX \(i + 1)",
                                          cueNumber: "FX\(i + 1)",
                                          startTime: Double(i) * 16.0))
        }
        return project
    }

    /// Generate and persist to the canonical benchmark path.
    /// Returns the project directory URL.
    @discardableResult
    static func generateOnDisk() async throws -> URL {
        var project = makeProject()
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Directors Chair")
            .appendingPathComponent("local")
            .appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // Write real image files and wire them into the project so the on-disk
        // benchmark exercises actual image-decode on view mount — the base
        // in-memory fixture (used by makeProject / QA fixture / regression
        // guards) is deliberately image-less and could not measure it.
        let imagePaths = try writeStressImages(into: root, count: 24)
        injectImagePaths(imagePaths, into: &project)

        let url = root.appendingPathComponent("project.json")
        let persistence = ProjectPersistence(enableBackups: false)
        try await persistence.save(project, to: url)
        return root
    }

    /// Writes `count` distinct, high-entropy PNGs into `<root>/images/` (skipping
    /// any already present) and returns their project-relative paths. High
    /// entropy keeps the decode cost realistic — a flat-colour PNG would inflate
    /// almost instantly and under-represent a real photo/poster.
    private static func writeStressImages(into root: URL, count: Int) throws -> [String] {
        let dir = root.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var paths: [String] = []
        for i in 0..<count {
            let rel = "images/stress-\(i).png"
            let fileURL = root.appendingPathComponent(rel)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try makeNoisyPNG(width: 1600, height: 1000, seed: UInt64(i) &* 0x1234567)
                    .write(to: fileURL)
            }
            paths.append(rel)
        }
        return paths
    }

    /// A 1600×1000 PNG filled with ~1,800 random rectangles so it carries real
    /// entropy (non-trivial decode), rendered via Core Graphics (fast to make).
    private static func makeNoisyPNG(width: Int, height: Int, seed: UInt64) -> Data {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return Data() }
        var rng = SeededRandom(seed: seed)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        for _ in 0..<1800 {
            let x = CGFloat(rng.next() % UInt64(width))
            let y = CGFloat(rng.next() % UInt64(height))
            let w = CGFloat(20 + rng.next() % 120)
            let h = CGFloat(20 + rng.next() % 120)
            NSColor(hue: CGFloat(rng.next() % 360) / 360.0,
                    saturation: 0.5 + CGFloat(rng.next() % 50) / 100.0,
                    brightness: 0.4 + CGFloat(rng.next() % 60) / 100.0,
                    alpha: 1).setFill()
            NSRect(x: x, y: y, width: w, height: h).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    /// Assigns image paths round-robin across scenes, shots, characters,
    /// locations and the project poster/icon so a wide range of views decode
    /// images on mount.
    private static func injectImagePaths(_ paths: [String], into project: inout Project) {
        guard !paths.isEmpty else { return }
        func pick(_ i: Int) -> String { paths[i % paths.count] }
        var k = 0
        for si in project.sequences.indices {
            for sci in project.sequences[si].scenes.indices {
                project.sequences[si].scenes[sci].sceneOverviewImage = pick(k); k += 1
                for shi in project.sequences[si].scenes[sci].shots.indices {
                    project.sequences[si].scenes[sci].shots[shi].previewImage = pick(k); k += 1
                }
            }
        }
        for ci in project.characters.indices { project.characters[ci].baseImage = pick(ci) }
        for li in project.locations.indices { project.locations[li].primaryImage = pick(li) }
        project.overviewPosterPaths = [pick(0), pick(1)]
        project.projectIcon = pick(2)
    }
}
