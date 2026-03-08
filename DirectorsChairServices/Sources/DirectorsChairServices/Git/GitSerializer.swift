// DirectorsChairServices/Sources/DirectorsChairServices/Git/GitSerializer.swift
//
// Git Serialization Service for DirectorsChair Projects
// Converts monolithic project.json into modular Git-friendly structure

import Foundation
import DirectorsChairCore

// MARK: - Git Serializer

/// Serializes DirectorsChair projects to Git-friendly modular structure
/// Converts monolithic project.json into separate files for better collaboration
public struct GitSerializer: GitSerializerProtocol {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Schema version for Git structure
    public static let schemaVersion = "1.0"

    /// Serializer version
    public static let serializerVersion = "1.0.0"

    // MARK: - LFS Extensions

    /// File extensions to track with Git LFS
    public static let lfsTrackedExtensions = [
        "*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp",
        "*.mp4", "*.mov", "*.avi", "*.mkv",
        "*.mp3", "*.wav", "*.aiff", "*.flac",
        "*.psd", "*.ai", "*.blend", "*.fbx"
    ]

    // MARK: - Initialization

    public init() {
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - GitSerializerProtocol Implementation

    /// Serialize entire project to Git-friendly modular structure
    public func serializeProject(_ project: Project, to repoPath: URL) async throws -> GitSerializationStats {
        var stats = GitSerializationStats()

        // Create directory structure
        try createDirectoryStructure(at: repoPath)

        // Generate .gitattributes for LFS tracking
        try generateGitAttributes(to: repoPath)

        // Serialize project metadata
        try await serializeProjectMetadata(project, to: repoPath)

        // Serialize characters
        for character in project.characters {
            try await serializeCharacter(character, to: repoPath, basePath: URL(fileURLWithPath: project.basePath))
            stats.characters += 1
        }

        // Serialize locations
        for location in project.locations {
            try await serializeLocation(location, to: repoPath)
            stats.locations += 1
        }

        // Serialize sequences and scenes
        for sequence in project.sequences {
            try await serializeSequence(sequence, to: repoPath)
            stats.sequences += 1

            for scene in sequence.scenes {
                try await serializeScene(scene, sequenceName: sequence.name, to: repoPath)
                stats.scenes += 1
            }
        }

        // Serialize beats (vision cards)
        for beat in project.beats {
            try await serializeBeat(beat, to: repoPath)
            stats.beats += 1
        }

        // Serialize props
        for prop in project.props {
            try await serializeProp(prop, to: repoPath, basePath: URL(fileURLWithPath: project.basePath))
            stats.props += 1
        }

        // Serialize costumes
        for costume in project.costumes {
            try await serializeCostume(costume, to: repoPath, basePath: URL(fileURLWithPath: project.basePath))
            stats.costumes += 1
        }

        // Serialize lighting setups
        for light in project.lighting {
            try await serializeLighting(light, to: repoPath)
            stats.lighting += 1
        }

        // Serialize effects
        for effect in project.effects {
            try await serializeEffect(effect, to: repoPath)
            stats.effects += 1
        }

        // Generate manifest
        try await generateManifest(stats: stats, to: repoPath)

        // Copy assets
        let projectBasePath = URL(fileURLWithPath: project.basePath)
        try await copyAssets(from: projectBasePath, to: repoPath)

        // Copy poster images
        try copyPosterImages(from: projectBasePath, posterPaths: project.overviewPosterPaths, to: repoPath)

        // Generate webapp-compatible root project.json
        try generateCompatProjectJSON(project, to: repoPath)

        return stats
    }

    /// Deserialize Git repository to DirectorsChair project
    public func deserializeProject(from repoPath: URL) async throws -> Project {
        // Verify manifest exists
        let manifestPath = repoPath.appendingPathComponent(".directorschair/manifest.json")
        guard fileManager.fileExists(atPath: manifestPath.path) else {
            throw GitSerializationError.missingManifest
        }

        // Read project metadata
        let projectMetadataPath = repoPath.appendingPathComponent(".directorschair/project.json")
        guard let projectData = fileManager.contents(atPath: projectMetadataPath.path) else {
            throw GitSerializationError.deserializationFailed("Cannot read project.json")
        }

        let projectMetadata = try JSONSerialization.jsonObject(with: projectData) as? [String: Any]
            ?? [:]

        let name = projectMetadata["name"] as? String ?? "Untitled"
        let metadata = projectMetadata["metadata"] as? [String: Any] ?? [:]

        var project = Project(
            name: name,
            basePath: repoPath.path,
            description: projectMetadata["description"] as? String ?? "",
            director: metadata["director"] as? String ?? "",
            productionCompany: metadata["production_company"] as? String ?? "",
            genre: metadata["genre"] as? String ?? "",
            projectType: metadata["project_type"] as? String ?? "Skit",
            targetDuration: metadata["target_duration"] as? String ?? "",
            budget: metadata["budget"] as? String ?? "",
            startDate: metadata["start_date"] as? String ?? "",
            endDate: metadata["end_date"] as? String ?? "",
            status: metadata["status"] as? String ?? "Pre-production",
            projectNotes: metadata["project_notes"] as? String ?? "",
            projectIcon: metadata["project_icon"] as? String ?? "",
            languages: metadata["languages"] as? [String] ?? ["English"]
        )

        // Deserialize characters
        project.characters = try await deserializeCharacters(from: repoPath)

        // Deserialize locations
        project.locations = try await deserializeLocations(from: repoPath)

        // Deserialize sequences and scenes
        project.sequences = try await deserializeSequences(from: repoPath)

        // Deserialize beats
        project.beats = try await deserializeBeats(from: repoPath)

        // Deserialize props
        project.props = try await deserializeProps(from: repoPath)

        // Deserialize costumes
        project.costumes = try await deserializeCostumes(from: repoPath)

        // Deserialize lighting
        project.lighting = try await deserializeLighting(from: repoPath)

        // Deserialize effects
        project.effects = try await deserializeEffects(from: repoPath)

        return project
    }

    /// Update specific entity in Git structure
    public func updateEntity<T: Codable & Identifiable>(_ entity: T, at repoPath: URL) async throws {
        // Determine entity type and serialize accordingly
        switch entity {
        case let character as Character:
            try await serializeCharacter(character, to: repoPath, basePath: nil)
        case let location as Location:
            try await serializeLocation(location, to: repoPath)
        case let scene as Scene:
            try await serializeScene(scene, sequenceName: nil, to: repoPath)
        case let prop as Prop:
            try await serializeProp(prop, to: repoPath, basePath: nil)
        case let costume as Costume:
            try await serializeCostume(costume, to: repoPath, basePath: nil)
        case let lighting as Lighting:
            try await serializeLighting(lighting, to: repoPath)
        case let effect as EffectDef:
            try await serializeEffect(effect, to: repoPath)
        case let beat as VisionCard:
            try await serializeBeat(beat, to: repoPath)
        default:
            throw GitSerializationError.serializationFailed("Unknown entity type: \(type(of: entity))")
        }
    }

    // MARK: - Directory Structure

    /// Create Git repository directory structure
    private func createDirectoryStructure(at repoPath: URL) throws {
        let directories = [
            ".directorschair",
            "characters/avatars",
            "characters/images",
            "locations/images",
            "sequences",
            "scenes",
            "beats",
            "props/images",
            "costumes/images",
            "lighting",
            "effects",
            "assets/audio/dialogue",
            "assets/audio/sfx",
            "assets/audio/music",
            "assets/video/references",
            "assets/video/footage",
            "assets/images/storyboards",
            "assets/images/references",
            "assets/posters"
        ]

        for directory in directories {
            let dirPath = repoPath.appendingPathComponent(directory)
            try fileManager.createDirectory(at: dirPath, withIntermediateDirectories: true)
        }
    }

    // MARK: - Git Attributes Generation

    /// Generate .gitattributes file with LFS tracking rules
    private func generateGitAttributes(to repoPath: URL) throws {
        var lines = ["# Git LFS tracking rules for DirectorsChair binary assets"]
        for ext in Self.lfsTrackedExtensions {
            lines.append("\(ext) filter=lfs diff=lfs merge=lfs -text")
        }
        lines.append("") // trailing newline
        let content = lines.joined(separator: "\n")
        let path = repoPath.appendingPathComponent(".gitattributes")
        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Project Metadata Serialization

    private func serializeProjectMetadata(_ project: Project, to repoPath: URL) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let metadata: [String: Any] = [
            "version": Self.serializerVersion,
            "schema_version": Self.schemaVersion,
            "name": project.name,
            "description": project.description,
            "metadata": [
                "director": project.director,
                "production_company": project.productionCompany,
                "genre": project.genre,
                "project_type": project.projectType,
                "target_duration": project.targetDuration,
                "budget": project.budget,
                "start_date": project.startDate,
                "end_date": project.endDate,
                "status": project.status,
                "languages": project.languages,
                "project_notes": project.projectNotes,
                "project_icon": project.projectIcon
            ],
            "settings": [
                "default_character_color": "#5d5d5d",
                "default_text_color": "#FFFFFF",
                "auto_save": true,
                "collaboration_enabled": true
            ],
            "created_at": timestamp,
            "updated_at": timestamp,
            "created_by": "directorschair-admin"
        ]

        // Serialize poster paths into repo-relative locations
        var posterRefs: [String] = []
        for (index, posterPath) in project.overviewPosterPaths.enumerated() {
            guard !posterPath.isEmpty else { continue }
            let ext = (posterPath as NSString).pathExtension.isEmpty ? "png" : (posterPath as NSString).pathExtension
            let repoRelative = "assets/posters/poster-\(index).\(ext)"
            posterRefs.append(repoRelative)
        }
        if !posterRefs.isEmpty {
            (metadata["metadata"] as? NSMutableDictionary)?["poster_paths"] = posterRefs
            // Since we used a literal dict, re-create with poster info
            var meta = metadata
            var innerMeta = meta["metadata"] as? [String: Any] ?? [:]
            innerMeta["poster_paths"] = posterRefs
            innerMeta["poster_current_index"] = project.overviewPosterCurrentIndex
            meta["metadata"] = innerMeta
            try writeJSON(meta, to: repoPath.appendingPathComponent(".directorschair/project.json"))
        } else {
            try writeJSON(metadata, to: repoPath.appendingPathComponent(".directorschair/project.json"))
        }
    }

    // MARK: - Character Serialization

    private func serializeCharacter(_ character: Character, to repoPath: URL, basePath: URL?) async throws {
        let filename = sanitizeFilename(character.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var charData: [String: Any] = [
            "id": "char_\(filename)",
            "character_id": character.characterId,
            "name": character.name,
            "role": character.role,
            "color": character.color,
            "text_color": character.textColor
        ]

        // Avatar path (nullable)
        if character.avatar != nil {
            charData["avatar"] = "characters/avatars/\(filename).png"
        }

        // Details dictionary
        charData["details"] = [
            "about": character.about,
            "gender": character.gender,
            "age": character.age,
            "build": character.build
        ]

        // Appearance dictionary
        charData["appearance"] = [
            "hair_color": character.hairColor,
            "hair_style": character.hairStyle,
            "hair_length": character.hairLength,
            "eye_color": character.eyeColor,
            "eye_shape": character.eyeShape,
            "skin_tone": character.skinTone,
            "ethnicity": character.ethnicity,
            "distinguishing_features": character.distinguishingFeatures,
            "facial_structure": character.facialStructure
        ]

        // Voice dictionary
        var voiceData: [String: Any] = [
            "pitch": 0.0,
            "speed": 1.0
        ]
        if let voice = character.voice {
            voiceData["tts_voice"] = voice
        }
        charData["voice"] = voiceData

        charData["traits"] = character.traits

        // Biography dictionary
        var biography: [String: Any] = [:]
        if let fullName = character.fullName { biography["full_name"] = fullName }
        if let nickname = character.nickname { biography["nickname"] = nickname }
        if let occupation = character.occupation { biography["occupation"] = occupation }
        if let backgroundStory = character.backgroundStory { biography["background_story"] = backgroundStory }
        if let primaryGoal = character.primaryGoal { biography["primary_goal"] = primaryGoal }
        if let primaryFear = character.primaryFear { biography["primary_fear"] = primaryFear }
        charData["biography"] = biography

        charData["relationships"] = character.relationships ?? [:]

        charData["metadata"] = [
            "created_at": timestamp,
            "updated_at": timestamp,
            "created_by": "directorschair-admin"
        ]

        // Character image fields → repo-relative paths in images/{charName}/
        let charImagesDir = "characters/images/\(filename)"
        var imageMap: [String: String?] = [
            "baseImage": character.baseImage,
            "imageFront": character.imageFront,
            "imageThreeQuarterLeft": character.imageThreeQuarterLeft,
            "imageThreeQuarterRight": character.imageThreeQuarterRight,
            "imageProfileLeft": character.imageProfileLeft,
            "imageProfileRight": character.imageProfileRight,
            "imageBackThreeQuarterLeft": character.imageBackThreeQuarterLeft,
            "imageBackThreeQuarterRight": character.imageBackThreeQuarterRight,
            "imageBack": character.imageBack,
            "imageFaceCloseupFront": character.imageFaceCloseupFront,
            "imageFaceCloseupThreeQuarter": character.imageFaceCloseupThreeQuarter,
            "imageFaceCloseupProfile": character.imageFaceCloseupProfile,
            "imageActionPose": character.imageActionPose,
            "faceImageFront": character.faceImageFront,
            "faceImageThreeQuarterLeft": character.faceImageThreeQuarterLeft,
            "faceImageThreeQuarterRight": character.faceImageThreeQuarterRight,
            "faceImageProfile": character.faceImageProfile,
            "bodyImageFront": character.bodyImageFront,
            "bodyImageThreeQuarterLeft": character.bodyImageThreeQuarterLeft,
            "bodyImageThreeQuarterRight": character.bodyImageThreeQuarterRight,
            "bodyImageProfile": character.bodyImageProfile,
            "costumeImageFront": character.costumeImageFront,
            "costumeImageThreeQuarterLeft": character.costumeImageThreeQuarterLeft,
            "costumeImageThreeQuarterRight": character.costumeImageThreeQuarterRight,
            "costumeImageProfile": character.costumeImageProfile,
            "overviewPortrait": character.overviewPortrait,
        ]

        var imageRefs: [String: String] = [:]
        for (key, localPath) in imageMap {
            guard let localPath = localPath, !localPath.isEmpty else { continue }
            let ext = (localPath as NSString).pathExtension.isEmpty ? "png" : (localPath as NSString).pathExtension
            let repoRelative = "\(charImagesDir)/\(key).\(ext)"
            imageRefs[key] = repoRelative
        }

        if !imageRefs.isEmpty {
            charData["images"] = imageRefs
        }

        try writeJSON(charData, to: repoPath.appendingPathComponent("characters/\(filename).json"))

        // Copy avatar if exists
        if let avatarPath = character.avatar, let basePath = basePath {
            let srcAvatar = basePath.appendingPathComponent(avatarPath)
            if fileManager.fileExists(atPath: srcAvatar.path) {
                let dstAvatar = repoPath.appendingPathComponent("characters/avatars/\(filename).png")
                try? fileManager.copyItem(at: srcAvatar, to: dstAvatar)
            }
        }

        // Copy all character images into characters/images/{charName}/
        if let basePath = basePath {
            let dstImagesDir = repoPath.appendingPathComponent(charImagesDir)
            try? fileManager.createDirectory(at: dstImagesDir, withIntermediateDirectories: true)

            for (key, localPath) in imageMap {
                guard let localPath = localPath, !localPath.isEmpty else { continue }
                let srcFile = basePath.appendingPathComponent(localPath)
                guard fileManager.fileExists(atPath: srcFile.path) else { continue }
                let ext = srcFile.pathExtension.isEmpty ? "png" : srcFile.pathExtension
                let dstFile = dstImagesDir.appendingPathComponent("\(key).\(ext)")
                try? fileManager.copyItem(at: srcFile, to: dstFile)
            }
        }
    }

    // MARK: - Location Serialization

    private func serializeLocation(_ location: Location, to repoPath: URL) async throws {
        let filename = sanitizeFilename(location.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let locData: [String: Any] = [
            "id": "loc_\(filename)",
            "name": location.name,
            "description": location.description,
            "location_type": location.locationType,
            "notes": location.notes,
            "tags": location.tags,
            "reference_images": location.referenceImages,
            "attributes": location.attributes,
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        try writeJSON(locData, to: repoPath.appendingPathComponent("locations/\(filename).json"))
    }

    // MARK: - Sequence Serialization

    private func serializeSequence(_ sequence: Sequence, to repoPath: URL) async throws {
        let filename = sanitizeFilename(sequence.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var sceneRefs: [String] = []
        for scene in sequence.scenes {
            let sceneFilename = sanitizeFilename(scene.name)
            sceneRefs.append("scenes/scene-\(sceneFilename).json")
        }

        var seqData: [String: Any] = [
            "id": "seq_\(filename)",
            "name": sequence.name,
            "scene_refs": sceneRefs,
            "estimated_duration": "",
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        if let description = sequence.description {
            seqData["description"] = description
        }
        if let location = sequence.location {
            seqData["location"] = location
        }

        try writeJSON(seqData, to: repoPath.appendingPathComponent("sequences/\(filename).json"))
    }

    // MARK: - Scene Serialization

    private func serializeScene(_ scene: Scene, sequenceName: String?, to repoPath: URL) async throws {
        let filename = sanitizeFilename(scene.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Serialize dialogues
        var dialogues: [[String: Any]] = []
        for dialogue in scene.dialogues {
            let charFilename = sanitizeFilename(dialogue.character)
            var dlgData: [String: Any] = [
                "id": String(format: "dlg_%03d", dialogue.chronologyNumber),
                "chronology_number": dialogue.chronologyNumber,
                "character_ref": "characters/\(charFilename).json",
                "text": dialogue.text,
                "tags": dialogue.tags,
                "metadata": [
                    "created_at": timestamp,
                    "created_by": "directorschair-admin"
                ]
            ]
            if let audioPath = dialogue.audioFilePath {
                dlgData["audio_ref"] = audioPath
            }
            dialogues.append(dlgData)
        }

        // Serialize actions
        var actions: [[String: Any]] = []
        for action in scene.actions {
            actions.append([
                "id": String(format: "act_%03d", action.chronologyNumber),
                "chronology_number": action.chronologyNumber,
                "description": action.description,
                "duration": "",
                "metadata": [
                    "created_at": timestamp,
                    "created_by": "directorschair-admin"
                ]
            ])
        }

        // Serialize narrations
        var narrations: [[String: Any]] = []
        for narration in scene.narrations {
            narrations.append([
                "id": String(format: "nar_%03d", narration.chronologyNumber),
                "chronology_number": narration.chronologyNumber,
                "text": narration.text,
                "voice_ref": "narrator-voice",
                "metadata": [
                    "created_at": timestamp,
                    "created_by": "directorschair-admin"
                ]
            ])
        }

        // Serialize scene notes
        var sceneNotes: [[String: Any]] = []
        for note in scene.sceneNotes {
            sceneNotes.append([
                "id": String(format: "note_%03d", note.chronologyNumber),
                "chronology_number": note.chronologyNumber,
                "content": note.content,
                "note_type": note.noteType,
                "title": note.title,
                "metadata": [
                    "created_at": timestamp,
                    "created_by": "directorschair-admin"
                ]
            ])
        }

        // Props references
        var propsRefs: [String] = []
        for propName in scene.props {
            propsRefs.append("props/\(sanitizeFilename(propName)).json")
        }

        var sceneData: [String: Any] = [
            "id": "scene_\(filename)",
            "name": scene.name,
            "description": scene.description,
            "notes": scene.notes,
            "props_refs": propsRefs,
            "dialogues": dialogues,
            "actions": actions,
            "narrations": narrations,
            "scene_notes": sceneNotes,
            "stage": scene.stage,
            "production_status": scene.productionStatus,
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        if let location = scene.location {
            sceneData["location_ref"] = "locations/\(sanitizeFilename(location)).json"
        }

        if let primaryChar = scene.primaryCharacter {
            sceneData["primary_character_ref"] = "characters/\(sanitizeFilename(primaryChar)).json"
        }

        if let seqName = sequenceName {
            sceneData["sequence_ref"] = "sequences/\(sanitizeFilename(seqName)).json"
        }

        try writeJSON(sceneData, to: repoPath.appendingPathComponent("scenes/scene-\(filename).json"))
    }

    // MARK: - Beat (VisionCard) Serialization

    private func serializeBeat(_ beat: VisionCard, to repoPath: URL) async throws {
        let filename = sanitizeFilename(beat.title)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var beatData: [String: Any] = [
            "id": "beat_\(filename)",
            "vision_card_id": beat.id,
            "title": beat.title,
            "description": beat.description,
            "card_type": beat.cardType,
            "position": beat.position,
            "board_id": beat.boardId,
            "tags": beat.tags,
            "props": beat.props,
            "costumes": beat.costumes,
            "effects": beat.effects,
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        if let imagePath = beat.imagePath {
            beatData["image_path"] = imagePath
        }
        if let sequenceName = beat.sequenceName {
            beatData["sequence_name"] = sequenceName
        }
        if let sceneName = beat.sceneName {
            beatData["scene_name"] = sceneName
        }

        try writeJSON(beatData, to: repoPath.appendingPathComponent("beats/\(filename).json"))
    }

    // MARK: - Prop Serialization

    private func serializeProp(_ prop: Prop, to repoPath: URL, basePath: URL?) async throws {
        let filename = sanitizeFilename(prop.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var propData: [String: Any] = [
            "id": "prop_\(filename)",
            "prop_id": prop.id,
            "name": prop.name,
            "description": prop.description,
            "notes": prop.notes,
            "category": prop.category,
            "tags": prop.tags,
            "scenes_used": prop.sceneNames ?? [],
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        if prop.thumbnail != nil {
            propData["thumbnail"] = "props/images/\(filename).png"
        }
        if let quantity = prop.quantity {
            propData["quantity"] = quantity
        }
        if let status = prop.status {
            propData["status"] = status
        }

        try writeJSON(propData, to: repoPath.appendingPathComponent("props/\(filename).json"))

        // Copy thumbnail if exists
        if let thumbnailPath = prop.thumbnail, let basePath = basePath {
            let srcThumbnail = basePath.appendingPathComponent(thumbnailPath)
            if fileManager.fileExists(atPath: srcThumbnail.path) {
                let dstThumbnail = repoPath.appendingPathComponent("props/images/\(filename).png")
                try? fileManager.copyItem(at: srcThumbnail, to: dstThumbnail)
            }
        }
    }

    // MARK: - Costume Serialization

    private func serializeCostume(_ costume: Costume, to repoPath: URL, basePath: URL?) async throws {
        let filename = sanitizeFilename(costume.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var costumeData: [String: Any] = [
            "id": "costume_\(filename)",
            "name": costume.name,
            "notes": costume.notes,
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        if let character = costume.character {
            costumeData["character_ref"] = "characters/\(sanitizeFilename(character)).json"
        }
        if costume.image != nil {
            costumeData["image"] = "costumes/images/\(filename).png"
        }

        try writeJSON(costumeData, to: repoPath.appendingPathComponent("costumes/\(filename).json"))

        // Copy image if exists
        if let imagePath = costume.image, let basePath = basePath {
            let srcImage = basePath.appendingPathComponent(imagePath)
            if fileManager.fileExists(atPath: srcImage.path) {
                let dstImage = repoPath.appendingPathComponent("costumes/images/\(filename).png")
                try? fileManager.copyItem(at: srcImage, to: dstImage)
            }
        }
    }

    // MARK: - Lighting Serialization

    private func serializeLighting(_ lighting: Lighting, to repoPath: URL) async throws {
        let filename = sanitizeFilename(lighting.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let lightingData: [String: Any] = [
            "id": "light_\(filename)",
            "name": lighting.name,
            "type": lighting.type,
            "color": lighting.color,
            "intensity": lighting.intensity,
            "position": lighting.position,
            "notes": lighting.notes,
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        try writeJSON(lightingData, to: repoPath.appendingPathComponent("lighting/\(filename).json"))
    }

    // MARK: - Effect Serialization

    private func serializeEffect(_ effect: EffectDef, to repoPath: URL) async throws {
        let filename = sanitizeFilename(effect.name)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let effectData: [String: Any] = [
            "id": "effect_\(filename)",
            "name": effect.name,
            "category": effect.category,
            "params": effect.params,
            "notes": effect.notes,
            "metadata": [
                "created_at": timestamp,
                "updated_at": timestamp,
                "created_by": "directorschair-admin"
            ]
        ]

        try writeJSON(effectData, to: repoPath.appendingPathComponent("effects/\(filename).json"))
    }

    // MARK: - Manifest Generation

    private func generateManifest(stats: GitSerializationStats, to repoPath: URL) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let manifest: [String: Any] = [
            "schema_version": Self.schemaVersion,
            "generated_at": timestamp,
            "project_ref": ".directorschair/project.json",
            "inventory": [
                "characters": [
                    "count": stats.characters,
                    "files": listFiles(in: repoPath.appendingPathComponent("characters"), pattern: "*.json")
                ],
                "scenes": [
                    "count": stats.scenes,
                    "files": listFiles(in: repoPath.appendingPathComponent("scenes"), pattern: "*.json")
                ],
                "sequences": [
                    "count": stats.sequences,
                    "files": listFiles(in: repoPath.appendingPathComponent("sequences"), pattern: "*.json")
                ],
                "locations": [
                    "count": stats.locations,
                    "files": listFiles(in: repoPath.appendingPathComponent("locations"), pattern: "*.json")
                ],
                "props": [
                    "count": stats.props,
                    "files": listFiles(in: repoPath.appendingPathComponent("props"), pattern: "*.json")
                ],
                "beats": [
                    "count": stats.beats,
                    "files": listFiles(in: repoPath.appendingPathComponent("beats"), pattern: "*.json")
                ],
                "costumes": [
                    "count": stats.costumes,
                    "files": listFiles(in: repoPath.appendingPathComponent("costumes"), pattern: "*.json")
                ],
                "lighting": [
                    "count": stats.lighting,
                    "files": listFiles(in: repoPath.appendingPathComponent("lighting"), pattern: "*.json")
                ],
                "effects": [
                    "count": stats.effects,
                    "files": listFiles(in: repoPath.appendingPathComponent("effects"), pattern: "*.json")
                ]
            ],
            "lfs_tracked_extensions": Self.lfsTrackedExtensions
        ]

        try writeJSON(manifest, to: repoPath.appendingPathComponent(".directorschair/manifest.json"))
    }

    // MARK: - Asset Copying

    private func copyAssets(from basePath: URL, to repoPath: URL) async throws {
        let assetDirs = ["audio", "video", "images"]

        for assetDir in assetDirs {
            let srcDir = basePath.appendingPathComponent("assets/\(assetDir)")
            let dstDir = repoPath.appendingPathComponent("assets/\(assetDir)")

            guard fileManager.fileExists(atPath: srcDir.path) else { continue }

            let enumerator = fileManager.enumerator(at: srcDir, includingPropertiesForKeys: [.isRegularFileKey])
            while let fileURL = enumerator?.nextObject() as? URL {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      resourceValues.isRegularFile == true else { continue }

                let relativePath = fileURL.path.replacingOccurrences(of: srcDir.path + "/", with: "")
                let dstPath = dstDir.appendingPathComponent(relativePath)

                try fileManager.createDirectory(at: dstPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fileManager.copyItem(at: fileURL, to: dstPath)
            }
        }
    }

    /// Copy poster images from project base to repo assets/posters/
    private func copyPosterImages(from basePath: URL, posterPaths: [String], to repoPath: URL) throws {
        let postersDir = repoPath.appendingPathComponent("assets/posters")
        try fileManager.createDirectory(at: postersDir, withIntermediateDirectories: true)

        for (index, posterPath) in posterPaths.enumerated() {
            guard !posterPath.isEmpty else { continue }
            let srcFile = basePath.appendingPathComponent(posterPath)
            guard fileManager.fileExists(atPath: srcFile.path) else { continue }
            let ext = srcFile.pathExtension.isEmpty ? "png" : srcFile.pathExtension
            let dstFile = postersDir.appendingPathComponent("poster-\(index).\(ext)")
            try? fileManager.copyItem(at: srcFile, to: dstFile)
        }
    }

    // MARK: - Webapp Compatibility

    /// Generate a root-level project.json for webapp compatibility.
    ///
    /// Creates a combined JSON with metadata, characters, scenes, locations, and props
    /// in the format expected by the webapp's ProjectService.
    private func generateCompatProjectJSON(_ project: Project, to repoPath: URL) throws {
        var metadata: [String: Any] = [
            "title": project.name,
            "logline": project.overviewLogline,
            "tagline": project.overviewTagline,
            "genre": project.genre,
            "tone": "",
            "setting": "",
            "timePeriod": "",
        ]

        // Poster paths
        var posterRefs: [String] = []
        for (index, posterPath) in project.overviewPosterPaths.enumerated() {
            guard !posterPath.isEmpty else { continue }
            let ext = (posterPath as NSString).pathExtension.isEmpty ? "png" : (posterPath as NSString).pathExtension
            posterRefs.append("assets/posters/poster-\(index).\(ext)")
        }
        if !posterRefs.isEmpty {
            metadata["poster_paths"] = posterRefs
            let idx = project.overviewPosterCurrentIndex < posterRefs.count ? project.overviewPosterCurrentIndex : 0
            metadata["posterImageURL"] = posterRefs[idx]
        }

        // Characters
        var chars: [[String: Any]] = []
        for character in project.characters {
            let filename = sanitizeFilename(character.name)
            let charImagesDir = "characters/images/\(filename)"

            // Best image URL for display
            var imageURL = ""
            if let path = character.overviewPortrait, !path.isEmpty {
                let ext = (path as NSString).pathExtension.isEmpty ? "png" : (path as NSString).pathExtension
                imageURL = "\(charImagesDir)/overviewPortrait.\(ext)"
            } else if let path = character.imageFront, !path.isEmpty {
                let ext = (path as NSString).pathExtension.isEmpty ? "png" : (path as NSString).pathExtension
                imageURL = "\(charImagesDir)/imageFront.\(ext)"
            } else if let path = character.baseImage, !path.isEmpty {
                let ext = (path as NSString).pathExtension.isEmpty ? "png" : (path as NSString).pathExtension
                imageURL = "\(charImagesDir)/baseImage.\(ext)"
            }

            chars.append([
                "id": character.characterId,
                "name": character.name,
                "role": character.role,
                "age": "\(character.age)",
                "gender": character.gender,
                "imageURL": imageURL,
            ])
        }

        // Scenes
        var scenes: [[String: Any]] = []
        for sequence in project.sequences {
            for scene in sequence.scenes {
                // Extract unique character names from dialogues
                var charNames = Set<String>()
                for dialogue in scene.dialogues {
                    if !dialogue.character.isEmpty {
                        charNames.insert(dialogue.character)
                    }
                }
                let sceneChars = charNames.sorted().map { ["name": $0] }

                var sceneData: [String: Any] = [
                    "id": scene.name,
                    "slugline": scene.name,
                    "setting": scene.location ?? "",
                    "timeOfDay": "",
                    "shots": scene.shots.map { ["id": $0.id] },
                    "characters": sceneChars,
                ]

                if let analysis = scene.sceneEmotionalAnalysis {
                    sceneData["emotionalAnalysis"] = analysis
                }

                // Element count from dialogues + actions + narrations
                let elementCount = scene.dialogues.count + scene.actions.count + scene.narrations.count
                sceneData["elements"] = Array(repeating: [String: Any](), count: elementCount)

                scenes.append(sceneData)
            }
        }

        // Locations
        var locs: [[String: Any]] = []
        for location in project.locations {
            locs.append([
                "id": location.name,
                "name": location.name,
                "type": location.locationType,
                "description": location.description,
            ])
        }

        // Props
        var propsList: [[String: Any]] = []
        for prop in project.props {
            propsList.append([
                "id": prop.name,
                "name": prop.name,
            ])
        }

        let projectJSON: [String: Any] = [
            "metadata": metadata,
            "characters": chars,
            "scenes": scenes,
            "locations": locs,
            "props": propsList,
        ]

        try writeJSON(projectJSON, to: repoPath.appendingPathComponent("project.json"))
    }

    // MARK: - Deserialization Helpers

    private func deserializeCharacters(from repoPath: URL) async throws -> [Character] {
        var characters: [Character] = []
        let charactersDir = repoPath.appendingPathComponent("characters")

        guard fileManager.fileExists(atPath: charactersDir.path) else { return characters }

        let contents = try fileManager.contentsOfDirectory(at: charactersDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let details = json["details"] as? [String: Any] ?? [:]
            let appearance = json["appearance"] as? [String: Any] ?? [:]
            let biography = json["biography"] as? [String: Any] ?? [:]

            let character = Character(
                characterId: json["character_id"] as? String ?? UUID().uuidString,
                name: json["name"] as? String ?? "",
                role: json["role"] as? String ?? "",
                color: json["color"] as? String ?? "#5d5d5d",
                textColor: json["text_color"] as? String ?? "#FFFFFF",
                avatar: nil,
                about: details["about"] as? String ?? "",
                gender: details["gender"] as? String ?? "neutral",
                build: details["build"] as? String ?? "Average",
                age: details["age"] as? Int ?? 30,
                hairColor: appearance["hair_color"] as? String ?? "#2C1810",
                hairStyle: appearance["hair_style"] as? String ?? "Medium, Straight",
                hairLength: appearance["hair_length"] as? String ?? "Medium",
                eyeColor: appearance["eye_color"] as? String ?? "#654321",
                eyeShape: appearance["eye_shape"] as? String ?? "Almond",
                skinTone: appearance["skin_tone"] as? String ?? "#D4A574",
                ethnicity: appearance["ethnicity"] as? String ?? "",
                distinguishingFeatures: appearance["distinguishing_features"] as? String ?? "",
                facialStructure: appearance["facial_structure"] as? String ?? "Oval",
                traits: json["traits"] as? [String: Double] ?? Character.defaultTraits(),
                fullName: biography["full_name"] as? String,
                nickname: biography["nickname"] as? String,
                occupation: biography["occupation"] as? String,
                backgroundStory: biography["background_story"] as? String,
                primaryGoal: biography["primary_goal"] as? String,
                primaryFear: biography["primary_fear"] as? String,
                relationships: json["relationships"] as? [String: String]
            )
            characters.append(character)
        }

        return characters
    }

    private func deserializeLocations(from repoPath: URL) async throws -> [Location] {
        var locations: [Location] = []
        let locationsDir = repoPath.appendingPathComponent("locations")

        guard fileManager.fileExists(atPath: locationsDir.path) else { return locations }

        let contents = try fileManager.contentsOfDirectory(at: locationsDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let location = Location(
                name: json["name"] as? String ?? "",
                description: json["description"] as? String ?? "",
                notes: json["notes"] as? String ?? "",
                locationType: json["location_type"] as? String ?? "mixed",
                tags: json["tags"] as? [String] ?? [],
                referenceImages: json["reference_images"] as? [String] ?? [],
                attributes: json["attributes"] as? [String: String] ?? [:]
            )
            locations.append(location)
        }

        return locations
    }

    private func deserializeSequences(from repoPath: URL) async throws -> [Sequence] {
        var sequences: [Sequence] = []
        let sequencesDir = repoPath.appendingPathComponent("sequences")

        guard fileManager.fileExists(atPath: sequencesDir.path) else { return sequences }

        let contents = try fileManager.contentsOfDirectory(at: sequencesDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            // Deserialize scenes for this sequence
            var scenes: [Scene] = []
            let sceneRefs = json["scene_refs"] as? [String] ?? []
            for sceneRef in sceneRefs {
                let scenePath = repoPath.appendingPathComponent(sceneRef)
                if let sceneData = fileManager.contents(atPath: scenePath.path),
                   let sceneJson = try? JSONSerialization.jsonObject(with: sceneData) as? [String: Any] {
                    let scene = try deserializeScene(from: sceneJson)
                    scenes.append(scene)
                }
            }

            let sequence = Sequence(
                name: json["name"] as? String ?? "",
                description: json["description"] as? String,
                scenes: scenes,
                location: json["location"] as? String
            )
            sequences.append(sequence)
        }

        return sequences
    }

    private func deserializeScene(from json: [String: Any]) throws -> Scene {
        // Parse dialogues
        var dialogues: [Dialogue] = []
        if let dialogueJsons = json["dialogues"] as? [[String: Any]] {
            for dlg in dialogueJsons {
                var characterName = ""
                if let charRef = dlg["character_ref"] as? String {
                    characterName = charRef
                        .replacingOccurrences(of: "characters/", with: "")
                        .replacingOccurrences(of: ".json", with: "")
                        .replacingOccurrences(of: "-", with: " ")
                        .capitalized
                }

                dialogues.append(Dialogue(
                    character: characterName,
                    text: dlg["text"] as? String ?? "",
                    tags: dlg["tags"] as? [String] ?? [],
                    chronologyNumber: dlg["chronology_number"] as? Int ?? 0,
                    audioFilePath: dlg["audio_ref"] as? String
                ))
            }
        }

        // Parse actions
        var actions: [Action] = []
        if let actionJsons = json["actions"] as? [[String: Any]] {
            for act in actionJsons {
                actions.append(Action(
                    description: act["description"] as? String ?? "",
                    chronologyNumber: act["chronology_number"] as? Int ?? 0
                ))
            }
        }

        // Parse narrations
        var narrations: [Narration] = []
        if let narrationJsons = json["narrations"] as? [[String: Any]] {
            for nar in narrationJsons {
                narrations.append(Narration(
                    text: nar["text"] as? String ?? "",
                    chronologyNumber: nar["chronology_number"] as? Int ?? 0
                ))
            }
        }

        // Parse scene notes
        var sceneNotes: [Note] = []
        if let noteJsons = json["scene_notes"] as? [[String: Any]] {
            for note in noteJsons {
                sceneNotes.append(Note(
                    content: note["content"] as? String ?? "",
                    noteType: note["note_type"] as? String ?? "text",
                    chronologyNumber: note["chronology_number"] as? Int ?? 0,
                    title: note["title"] as? String ?? ""
                ))
            }
        }

        // Extract location name from ref
        var locationName: String?
        if let locRef = json["location_ref"] as? String {
            locationName = locRef
                .replacingOccurrences(of: "locations/", with: "")
                .replacingOccurrences(of: ".json", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }

        return Scene(
            name: json["name"] as? String ?? "",
            description: json["description"] as? String ?? "",
            notes: json["notes"] as? String ?? "",
            dialogues: dialogues,
            actions: actions,
            narrations: narrations,
            sceneNotes: sceneNotes,
            stage: json["stage"] as? [String: String] ?? [:],
            location: locationName,
            productionStatus: json["production_status"] as? String ?? "Planning"
        )
    }

    private func deserializeBeats(from repoPath: URL) async throws -> [VisionCard] {
        var beats: [VisionCard] = []
        let beatsDir = repoPath.appendingPathComponent("beats")

        guard fileManager.fileExists(atPath: beatsDir.path) else { return beats }

        let contents = try fileManager.contentsOfDirectory(at: beatsDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let beat = VisionCard(
                id: json["vision_card_id"] as? String ?? UUID().uuidString,
                title: json["title"] as? String ?? "",
                description: json["description"] as? String ?? "",
                tags: json["tags"] as? [String] ?? [],
                props: json["props"] as? [String] ?? [],
                costumes: json["costumes"] as? [String] ?? [],
                effects: json["effects"] as? [String] ?? [],
                imagePath: json["image_path"] as? String,
                sequenceName: json["sequence_name"] as? String,
                sceneName: json["scene_name"] as? String,
                position: json["position"] as? Int ?? 0,
                cardType: json["card_type"] as? String ?? "image",
                boardId: json["board_id"] as? String ?? "master"
            )
            beats.append(beat)
        }

        return beats
    }

    private func deserializeProps(from repoPath: URL) async throws -> [Prop] {
        var props: [Prop] = []
        let propsDir = repoPath.appendingPathComponent("props")

        guard fileManager.fileExists(atPath: propsDir.path) else { return props }

        let contents = try fileManager.contentsOfDirectory(at: propsDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let prop = Prop(
                id: json["prop_id"] as? String ?? UUID().uuidString,
                name: json["name"] as? String ?? "",
                thumbnail: nil,
                description: json["description"] as? String ?? "",
                category: json["category"] as? String ?? "",
                tags: json["tags"] as? [String] ?? [],
                quantity: json["quantity"] as? Int,
                sceneNames: json["scenes_used"] as? [String],
                notes: json["notes"] as? String ?? "",
                status: json["status"] as? String
            )
            props.append(prop)
        }

        return props
    }

    private func deserializeCostumes(from repoPath: URL) async throws -> [Costume] {
        var costumes: [Costume] = []
        let costumesDir = repoPath.appendingPathComponent("costumes")

        guard fileManager.fileExists(atPath: costumesDir.path) else { return costumes }

        let contents = try fileManager.contentsOfDirectory(at: costumesDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            var characterName: String?
            if let charRef = json["character_ref"] as? String {
                characterName = charRef
                    .replacingOccurrences(of: "characters/", with: "")
                    .replacingOccurrences(of: ".json", with: "")
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized
            }

            let costume = Costume(
                name: json["name"] as? String ?? "",
                character: characterName,
                image: nil,
                notes: json["notes"] as? String ?? ""
            )
            costumes.append(costume)
        }

        return costumes
    }

    private func deserializeLighting(from repoPath: URL) async throws -> [Lighting] {
        var lightingSetups: [Lighting] = []
        let lightingDir = repoPath.appendingPathComponent("lighting")

        guard fileManager.fileExists(atPath: lightingDir.path) else { return lightingSetups }

        let contents = try fileManager.contentsOfDirectory(at: lightingDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let lighting = Lighting(
                name: json["name"] as? String ?? "",
                type: json["type"] as? String ?? "Key",
                color: json["color"] as? String ?? "#FFFFFF",
                intensity: json["intensity"] as? Double ?? 1.0,
                position: json["position"] as? String ?? "Front",
                notes: json["notes"] as? String ?? ""
            )
            lightingSetups.append(lighting)
        }

        return lightingSetups
    }

    private func deserializeEffects(from repoPath: URL) async throws -> [EffectDef] {
        var effects: [EffectDef] = []
        let effectsDir = repoPath.appendingPathComponent("effects")

        guard fileManager.fileExists(atPath: effectsDir.path) else { return effects }

        let contents = try fileManager.contentsOfDirectory(at: effectsDir, includingPropertiesForKeys: nil)
        for fileURL in contents where fileURL.pathExtension == "json" {
            guard let data = fileManager.contents(atPath: fileURL.path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let effect = EffectDef(
                name: json["name"] as? String ?? "",
                category: json["category"] as? String ?? "Visual",
                params: json["params"] as? [String: String] ?? [:],
                notes: json["notes"] as? String ?? ""
            )
            effects.append(effect)
        }

        return effects
    }

    // MARK: - Utility Methods

    /// Write JSON to file with pretty formatting
    private func writeJSON(_ data: [String: Any], to url: URL) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: url)
    }

    /// List files in directory matching pattern
    private func listFiles(in directory: URL, pattern: String) -> [String] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let dirName = directory.lastPathComponent
            return contents
                .filter { $0.pathExtension == "json" }
                .map { "\(dirName)/\($0.lastPathComponent)" }
                .sorted()
        } catch {
            return []
        }
    }

    /// Convert name to safe filename
    private func sanitizeFilename(_ name: String) -> String {
        var safeName = name.lowercased()
        safeName = safeName.replacingOccurrences(of: " ", with: "-")
        safeName = String(safeName.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        })
        return safeName
    }
}
