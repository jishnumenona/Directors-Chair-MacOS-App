// DirectorsChairCore/Tests/DirectorsChairCoreTests/UUIDIdentityTests.swift
//
// Exhaustive tests for the stable UUID identity system on Shot, Scene, and Sequence models.
// Validates: UUID generation, identity stability, JSON migration, global numbering,
// collection uniqueness, and backward compatibility with old project files.

import XCTest
@testable import DirectorsChairCore

final class UUIDIdentityTests: XCTestCase {

    // MARK: - Shot UUID Identity

    func testShotIdReturnsUUID() {
        let shot = Shot(shotId: 1, description: "Test shot")
        // id should be the uuid, NOT the shotId string
        XCTAssertEqual(shot.id, shot.uuid)
        XCTAssertNotEqual(shot.id, "\(shot.shotId)")
    }

    func testShotDefaultUUIDIsValid() {
        let shot = Shot(shotId: 1)
        // UUID should be a valid UUID string (36 chars with hyphens)
        XCTAssertEqual(shot.uuid.count, 36)
        XCTAssertNotNil(UUID(uuidString: shot.uuid))
    }

    func testShotExplicitUUID() {
        let customUUID = "custom-uuid-12345"
        let shot = Shot(uuid: customUUID, shotId: 1)
        XCTAssertEqual(shot.uuid, customUUID)
        XCTAssertEqual(shot.id, customUUID)
    }

    func testTwoShotsWithSameShotIdHaveDifferentIds() {
        let shot1 = Shot(shotId: 1, description: "Shot A")
        let shot2 = Shot(shotId: 1, description: "Shot B")
        // Same display number but different identity
        XCTAssertEqual(shot1.shotId, shot2.shotId)
        XCTAssertNotEqual(shot1.id, shot2.id)
        XCTAssertNotEqual(shot1.uuid, shot2.uuid)
    }

    func testShotIdStableAcrossMutation() {
        var shot = Shot(shotId: 1, description: "Original")
        let originalId = shot.id
        let originalUUID = shot.uuid

        // Mutate display number — identity should NOT change
        shot.shotId = 99
        XCTAssertEqual(shot.id, originalId)
        XCTAssertEqual(shot.uuid, originalUUID)

        // Mutate description — identity should NOT change
        shot.description = "Modified"
        XCTAssertEqual(shot.id, originalId)

        // Mutate status — identity should NOT change
        shot.status = "Approved"
        XCTAssertEqual(shot.id, originalId)
    }

    func testShotShotIdRemainsAccessible() {
        let shot = Shot(shotId: 42, description: "Test")
        XCTAssertEqual(shot.shotId, 42)
    }

    // MARK: - Scene UUID Identity

    func testSceneIdReturnsUUID() {
        let scene = Scene(name: "Scene 1 - INT. KITCHEN")
        XCTAssertEqual(scene.id, scene.uuid)
        XCTAssertNotEqual(scene.id, scene.name)
    }

    func testSceneDefaultUUIDIsValid() {
        let scene = Scene(name: "Test Scene")
        XCTAssertEqual(scene.uuid.count, 36)
        XCTAssertNotNil(UUID(uuidString: scene.uuid))
    }

    func testSceneExplicitUUID() {
        let customUUID = "scene-uuid-abc"
        let scene = Scene(uuid: customUUID, name: "Test")
        XCTAssertEqual(scene.uuid, customUUID)
        XCTAssertEqual(scene.id, customUUID)
    }

    func testTwoScenesWithSameNameHaveDifferentIds() {
        let scene1 = Scene(name: "Scene 1")
        let scene2 = Scene(name: "Scene 1")
        XCTAssertEqual(scene1.name, scene2.name)
        XCTAssertNotEqual(scene1.id, scene2.id)
    }

    func testSceneIdStableAcrossNameMutation() {
        var scene = Scene(name: "Original Name")
        let originalId = scene.id
        scene.name = "Renamed Scene"
        XCTAssertEqual(scene.id, originalId)
    }

    // MARK: - Sequence UUID Identity

    func testSequenceIdReturnsUUID() {
        let sequence = Sequence(name: "Act 1")
        XCTAssertEqual(sequence.id, sequence.uuid)
        XCTAssertNotEqual(sequence.id, sequence.name)
    }

    func testSequenceDefaultUUIDIsValid() {
        let sequence = Sequence(name: "Test")
        XCTAssertEqual(sequence.uuid.count, 36)
        XCTAssertNotNil(UUID(uuidString: sequence.uuid))
    }

    func testSequenceExplicitUUID() {
        let customUUID = "seq-uuid-xyz"
        let sequence = Sequence(uuid: customUUID, name: "Act 1")
        XCTAssertEqual(sequence.uuid, customUUID)
        XCTAssertEqual(sequence.id, customUUID)
    }

    func testTwoSequencesWithSameNameHaveDifferentIds() {
        let seq1 = Sequence(name: "Act 1")
        let seq2 = Sequence(name: "Act 1")
        XCTAssertEqual(seq1.name, seq2.name)
        XCTAssertNotEqual(seq1.id, seq2.id)
    }

    func testSequenceIdStableAcrossNameMutation() {
        var seq = Sequence(name: "Original")
        let originalId = seq.id
        seq.name = "Renamed"
        XCTAssertEqual(seq.id, originalId)
    }

    // MARK: - JSON Round-Trip (UUID Persistence)

    func testShotUUIDPersistsThroughEncodeDecode() throws {
        let original = Shot(shotId: 5, description: "Tracking shot")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Shot.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.shotId, original.shotId)
        XCTAssertEqual(decoded.description, original.description)
    }

    func testSceneUUIDPersistsThroughEncodeDecode() throws {
        let original = Scene(name: "Scene 1", description: "Kitchen fight")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Scene.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
    }

    func testSequenceUUIDPersistsThroughEncodeDecode() throws {
        let original = Sequence(name: "Act 1", description: "Setup")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Sequence.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
    }

    func testMultipleRoundTripsPreserveUUID() throws {
        let original = Shot(shotId: 1, description: "Test")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Round-trip 3 times
        var data = try encoder.encode(original)
        var decoded = try decoder.decode(Shot.self, from: data)
        data = try encoder.encode(decoded)
        decoded = try decoder.decode(Shot.self, from: data)
        data = try encoder.encode(decoded)
        decoded = try decoder.decode(Shot.self, from: data)

        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.id, original.id)
    }

    // MARK: - JSON Migration (Old Projects Without UUID)

    func testShotDecodesWithoutUUIDField() throws {
        // Simulate old project JSON that has no "uuid" key
        let oldJSON = """
        {
            "shot_id": 3,
            "item_chronology": 0,
            "description": "Wide establishing shot",
            "status": "Planning",
            "camera_angle": "High",
            "aperture": "f/4",
            "shot_type": "WS",
            "movement": "Static",
            "reference_media": [],
            "linked_dialogue_ids": [],
            "linked_action_ids": [],
            "linked_narration_ids": [],
            "takes": []
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let shot = try JSONDecoder().decode(Shot.self, from: data)

        // Should get a fresh UUID
        XCTAssertFalse(shot.uuid.isEmpty)
        XCTAssertNotNil(UUID(uuidString: shot.uuid))
        // id should be the UUID, not "3"
        XCTAssertEqual(shot.id, shot.uuid)
        XCTAssertNotEqual(shot.id, "3")
        // shotId should still decode correctly
        XCTAssertEqual(shot.shotId, 3)
        XCTAssertEqual(shot.description, "Wide establishing shot")
    }

    func testSceneDecodesWithoutUUIDField() throws {
        let oldJSON = """
        {
            "name": "Scene 1 - INT. KITCHEN",
            "description": "Morning scene",
            "notes": "",
            "dialogues": [],
            "actions": [],
            "narrations": [],
            "shots": [],
            "stage": {},
            "props": [],
            "production_status": "Planning"
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let scene = try JSONDecoder().decode(Scene.self, from: data)

        XCTAssertFalse(scene.uuid.isEmpty)
        XCTAssertNotNil(UUID(uuidString: scene.uuid))
        XCTAssertEqual(scene.id, scene.uuid)
        XCTAssertNotEqual(scene.id, scene.name)
        XCTAssertEqual(scene.name, "Scene 1 - INT. KITCHEN")
    }

    func testSequenceDecodesWithoutUUIDField() throws {
        let oldJSON = """
        {
            "name": "Act 1",
            "scenes": []
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let sequence = try JSONDecoder().decode(Sequence.self, from: data)

        XCTAssertFalse(sequence.uuid.isEmpty)
        XCTAssertNotNil(UUID(uuidString: sequence.uuid))
        XCTAssertEqual(sequence.id, sequence.uuid)
        XCTAssertNotEqual(sequence.id, "Act 1")
        XCTAssertEqual(sequence.name, "Act 1")
    }

    func testOldShotJSONMigratedUUIDIsStableAfterReencode() throws {
        let oldJSON = """
        {
            "shot_id": 1,
            "description": "Test",
            "status": "Planning",
            "camera_angle": "Medium",
            "aperture": "f/2.8",
            "shot_type": "Standard",
            "movement": "Static",
            "reference_media": [],
            "linked_dialogue_ids": [],
            "linked_action_ids": [],
            "linked_narration_ids": [],
            "takes": []
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let shot = try JSONDecoder().decode(Shot.self, from: data)
        let migratedUUID = shot.uuid

        // Re-encode (simulates saving the project)
        let reencoded = try JSONEncoder().encode(shot)
        // Re-decode (simulates reopening the project)
        let reloaded = try JSONDecoder().decode(Shot.self, from: reencoded)

        // UUID should now be stable
        XCTAssertEqual(reloaded.uuid, migratedUUID)
        XCTAssertEqual(reloaded.id, migratedUUID)
    }

    func testTwoDecodesOfSameOldJSONGetDifferentUUIDs() throws {
        // Each decode of old JSON (without uuid) should generate a NEW UUID,
        // since there's no uuid in the JSON to preserve
        let oldJSON = """
        {
            "shot_id": 1,
            "description": "Test",
            "status": "Planning",
            "camera_angle": "Medium",
            "aperture": "f/2.8",
            "shot_type": "Standard",
            "movement": "Static",
            "reference_media": [],
            "linked_dialogue_ids": [],
            "linked_action_ids": [],
            "linked_narration_ids": [],
            "takes": []
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let shot1 = try JSONDecoder().decode(Shot.self, from: data)
        let shot2 = try JSONDecoder().decode(Shot.self, from: data)

        // Both get fresh UUIDs, so they should differ
        XCTAssertNotEqual(shot1.uuid, shot2.uuid)
    }

    // MARK: - Nested UUID Migration (Full Project)

    func testFullProjectDecodesWithUUIDs() throws {
        let projectJSON = """
        {
            "name": "Old Project",
            "sequences": [
                {
                    "name": "Act 1",
                    "scenes": [
                        {
                            "name": "Scene 1",
                            "description": "",
                            "notes": "",
                            "dialogues": [],
                            "actions": [],
                            "narrations": [],
                            "shots": [
                                {
                                    "shot_id": 1,
                                    "description": "Wide shot",
                                    "status": "Planning",
                                    "camera_angle": "Medium",
                                    "aperture": "f/2.8",
                                    "shot_type": "WS",
                                    "movement": "Static",
                                    "reference_media": [],
                                    "linked_dialogue_ids": [],
                                    "linked_action_ids": [],
                                    "linked_narration_ids": [],
                                    "takes": []
                                },
                                {
                                    "shot_id": 2,
                                    "description": "Close up",
                                    "status": "Ready",
                                    "camera_angle": "Eye Level",
                                    "aperture": "f/1.8",
                                    "shot_type": "CU",
                                    "movement": "Static",
                                    "reference_media": [],
                                    "linked_dialogue_ids": [],
                                    "linked_action_ids": [],
                                    "linked_narration_ids": [],
                                    "takes": []
                                }
                            ],
                            "stage": {},
                            "props": [],
                            "production_status": "Planning"
                        },
                        {
                            "name": "Scene 2",
                            "description": "",
                            "notes": "",
                            "dialogues": [],
                            "actions": [],
                            "narrations": [],
                            "shots": [
                                {
                                    "shot_id": 1,
                                    "description": "Another wide",
                                    "status": "Planning",
                                    "camera_angle": "High",
                                    "aperture": "f/5.6",
                                    "shot_type": "EWS",
                                    "movement": "Crane Down",
                                    "reference_media": [],
                                    "linked_dialogue_ids": [],
                                    "linked_action_ids": [],
                                    "linked_narration_ids": [],
                                    "takes": []
                                }
                            ],
                            "stage": {},
                            "props": [],
                            "production_status": "Planning"
                        }
                    ]
                }
            ]
        }
        """
        let data = projectJSON.data(using: .utf8)!
        let project = try JSONDecoder().decode(Project.self, from: data)

        // Sequence should have UUID
        XCTAssertEqual(project.sequences.count, 1)
        let seq = project.sequences[0]
        XCTAssertFalse(seq.uuid.isEmpty)
        XCTAssertEqual(seq.id, seq.uuid)

        // Scenes should have unique UUIDs
        XCTAssertEqual(seq.scenes.count, 2)
        XCTAssertNotEqual(seq.scenes[0].uuid, seq.scenes[1].uuid)
        XCTAssertNotEqual(seq.scenes[0].id, seq.scenes[1].id)

        // Shots across scenes — old project had duplicate shotId=1
        let scene1Shot = seq.scenes[0].shots[0]
        let scene2Shot = seq.scenes[1].shots[0]
        XCTAssertEqual(scene1Shot.shotId, 1)
        XCTAssertEqual(scene2Shot.shotId, 1)
        // But now they have DIFFERENT identities
        XCTAssertNotEqual(scene1Shot.id, scene2Shot.id)
        XCTAssertNotEqual(scene1Shot.uuid, scene2Shot.uuid)

        // All 3 shots have unique IDs
        let allShots = project.sequences.flatMap { $0.scenes.flatMap { $0.shots } }
        let allIds = Set(allShots.map { $0.id })
        XCTAssertEqual(allIds.count, 3, "All 3 shots should have unique IDs despite duplicate shotIds")
    }

    // MARK: - Collection Uniqueness (Dictionary Keying)

    func testDictionaryKeyedByShotIdNoDuplicateLoss() {
        // Previously shot.id was "\(shotId)", so two shots with shotId=1
        // in different scenes would collide in a dictionary. Now they shouldn't.
        let shot1 = Shot(shotId: 1, description: "Scene A shot")
        let shot2 = Shot(shotId: 1, description: "Scene B shot")
        let shot3 = Shot(shotId: 2, description: "Scene A shot 2")

        // Keying by shot.id (UUID) — no collision
        let dict = Dictionary([shot1, shot2, shot3].map { ($0.id, $0) },
                              uniquingKeysWith: { _, latest in latest })
        XCTAssertEqual(dict.count, 3, "No data loss — all 3 shots preserved")
        XCTAssertNotNil(dict[shot1.id])
        XCTAssertNotNil(dict[shot2.id])
        XCTAssertNotNil(dict[shot3.id])
    }

    func testSetOfShotIdsPreservesAllShots() {
        let shot1 = Shot(shotId: 1, description: "A")
        let shot2 = Shot(shotId: 1, description: "B")

        // Using Set<String> of shot.id — should preserve both
        let idSet = Set([shot1.id, shot2.id])
        XCTAssertEqual(idSet.count, 2)
    }

    func testSceneDictionaryKeyingNoCollision() {
        let scene1 = Scene(name: "Scene 1")
        let scene2 = Scene(name: "Scene 1") // Same name, different scene

        let dict = Dictionary([scene1, scene2].map { ($0.id, $0) },
                              uniquingKeysWith: { _, latest in latest })
        XCTAssertEqual(dict.count, 2, "Two scenes with same name should have different IDs")
    }

    // MARK: - Project.nextShotDisplayNumber

    func testNextShotDisplayNumberEmptyProject() {
        let project = Project(name: "Empty")
        XCTAssertEqual(project.nextShotDisplayNumber, 1)
    }

    func testNextShotDisplayNumberSingleScene() {
        let shots = [
            Shot(shotId: 1, description: "Shot 1"),
            Shot(shotId: 2, description: "Shot 2"),
            Shot(shotId: 3, description: "Shot 3")
        ]
        let scene = Scene(name: "Scene 1", shots: shots)
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        let project = Project(name: "Test", sequences: [sequence])

        XCTAssertEqual(project.nextShotDisplayNumber, 4)
    }

    func testNextShotDisplayNumberMultipleScenes() {
        let scene1 = Scene(name: "Scene 1", shots: [
            Shot(shotId: 1, description: "S1-1"),
            Shot(shotId: 2, description: "S1-2")
        ])
        let scene2 = Scene(name: "Scene 2", shots: [
            Shot(shotId: 3, description: "S2-1"),
            Shot(shotId: 5, description: "S2-2")  // Gap in numbering
        ])
        let sequence = Sequence(name: "Act 1", scenes: [scene1, scene2])
        let project = Project(name: "Test", sequences: [sequence])

        // Max shotId is 5, so next should be 6
        XCTAssertEqual(project.nextShotDisplayNumber, 6)
    }

    func testNextShotDisplayNumberMultipleSequences() {
        let scene1 = Scene(name: "Scene 1", shots: [Shot(shotId: 3)])
        let scene2 = Scene(name: "Scene 2", shots: [Shot(shotId: 7)])
        let seq1 = Sequence(name: "Act 1", scenes: [scene1])
        let seq2 = Sequence(name: "Act 2", scenes: [scene2])
        let project = Project(name: "Test", sequences: [seq1, seq2])

        // Max across all sequences is 7
        XCTAssertEqual(project.nextShotDisplayNumber, 8)
    }

    func testNextShotDisplayNumberWithNoShots() {
        let scene = Scene(name: "Empty Scene", shots: [])
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        let project = Project(name: "Test", sequences: [sequence])

        XCTAssertEqual(project.nextShotDisplayNumber, 1)
    }

    func testNextShotDisplayNumberAfterDeletion() {
        // If shots 1,2,3 exist and shot 3 is deleted, next should still be 3
        // (we use max of remaining, which is 2, so next is 3)
        let shots = [
            Shot(shotId: 1, description: "Shot 1"),
            Shot(shotId: 2, description: "Shot 2")
            // Shot 3 was deleted
        ]
        let scene = Scene(name: "Scene 1", shots: shots)
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        let project = Project(name: "Test", sequences: [sequence])

        XCTAssertEqual(project.nextShotDisplayNumber, 3)
    }

    func testNextShotDisplayNumberNonContiguous() {
        // Shots with IDs 1, 5, 10 — next should be 11
        let shots = [
            Shot(shotId: 1),
            Shot(shotId: 5),
            Shot(shotId: 10)
        ]
        let scene = Scene(name: "Scene 1", shots: shots)
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        let project = Project(name: "Test", sequences: [sequence])

        XCTAssertEqual(project.nextShotDisplayNumber, 11)
    }

    // MARK: - Hashable Conformance with UUID

    func testShotHashableUsesUUID() {
        let shot1 = Shot(shotId: 1, description: "A")
        let shot2 = Shot(shotId: 1, description: "B")

        var set = Set<Shot>()
        set.insert(shot1)
        set.insert(shot2)

        // Both should be in the set since they have different UUIDs
        XCTAssertEqual(set.count, 2)
    }

    func testSceneHashableUsesUUID() {
        let scene1 = Scene(name: "Scene 1")
        let scene2 = Scene(name: "Scene 1")

        var set = Set<Scene>()
        set.insert(scene1)
        set.insert(scene2)

        XCTAssertEqual(set.count, 2)
    }

    func testSequenceHashableUsesUUID() {
        let seq1 = Sequence(name: "Act 1")
        let seq2 = Sequence(name: "Act 1")

        var set = Set<Sequence>()
        set.insert(seq1)
        set.insert(seq2)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Identifiable for SwiftUI (ForEach correctness)

    func testForEachWouldNotDeduplicateShots() {
        // Simulate what SwiftUI ForEach does — it uses .id for identity
        let shots = [
            Shot(shotId: 1, description: "Scene A shot 1"),
            Shot(shotId: 1, description: "Scene B shot 1"),
            Shot(shotId: 2, description: "Scene A shot 2")
        ]

        let ids = shots.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, 3, "ForEach should see 3 distinct items")
    }

    func testForEachWouldNotDeduplicateScenes() {
        let scenes = [
            Scene(name: "Scene 1"),
            Scene(name: "Scene 1"),
            Scene(name: "Scene 2")
        ]

        let ids = scenes.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, 3)
    }

    // MARK: - JSON Encoding Includes UUID

    func testShotJSONContainsUUIDField() throws {
        let shot = Shot(uuid: "test-uuid-123", shotId: 1, description: "Test")
        let data = try JSONEncoder().encode(shot)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"uuid\""))
        XCTAssertTrue(jsonString.contains("test-uuid-123"))
    }

    func testSceneJSONContainsUUIDField() throws {
        let scene = Scene(uuid: "scene-uuid-456", name: "Scene 1")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try JSONEncoder().encode(scene)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"uuid\""))
        XCTAssertTrue(jsonString.contains("scene-uuid-456"))
    }

    func testSequenceJSONContainsUUIDField() throws {
        let seq = Sequence(uuid: "seq-uuid-789", name: "Act 1")
        let data = try JSONEncoder().encode(seq)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"uuid\""))
        XCTAssertTrue(jsonString.contains("seq-uuid-789"))
    }

    // MARK: - Full Project Persistence Round-Trip with UUIDs

    func testFullProjectRoundTripPreservesAllUUIDs() throws {
        let shot1 = Shot(uuid: "shot-aaa", shotId: 1, description: "S1")
        let shot2 = Shot(uuid: "shot-bbb", shotId: 2, description: "S2")
        let scene = Scene(uuid: "scene-ccc", name: "Scene 1", shots: [shot1, shot2])
        let sequence = Sequence(uuid: "seq-ddd", name: "Act 1", scenes: [scene])
        let project = Project(name: "UUID Test", sequences: [sequence])

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(project)
        let decoded = try decoder.decode(Project.self, from: data)

        // Verify all UUIDs preserved
        XCTAssertEqual(decoded.sequences[0].uuid, "seq-ddd")
        XCTAssertEqual(decoded.sequences[0].scenes[0].uuid, "scene-ccc")
        XCTAssertEqual(decoded.sequences[0].scenes[0].shots[0].uuid, "shot-aaa")
        XCTAssertEqual(decoded.sequences[0].scenes[0].shots[1].uuid, "shot-bbb")

        // Verify IDs match UUIDs
        XCTAssertEqual(decoded.sequences[0].id, "seq-ddd")
        XCTAssertEqual(decoded.sequences[0].scenes[0].id, "scene-ccc")
        XCTAssertEqual(decoded.sequences[0].scenes[0].shots[0].id, "shot-aaa")
        XCTAssertEqual(decoded.sequences[0].scenes[0].shots[1].id, "shot-bbb")
    }

    // MARK: - File-Based Persistence Round-Trip

    func testSaveAndReloadProjectPreservesUUIDs() async throws {
        let persistence = ProjectPersistence(enableBackups: false)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UUIDTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let shot = Shot(shotId: 1, description: "Test shot")
        let scene = Scene(name: "Scene 1", shots: [shot])
        let sequence = Sequence(name: "Act 1", scenes: [scene])
        let project = Project(name: "Persistence Test", sequences: [sequence])

        let fileURL = tempDir.appendingPathComponent("project.json")
        try await persistence.save(project, to: fileURL)
        let loaded = try await persistence.load(from: fileURL)

        // Verify UUIDs survived file persistence
        XCTAssertEqual(loaded.sequences[0].uuid, sequence.uuid)
        XCTAssertEqual(loaded.sequences[0].scenes[0].uuid, scene.uuid)
        XCTAssertEqual(loaded.sequences[0].scenes[0].shots[0].uuid, shot.uuid)

        // Save again and reload — UUIDs should remain the same
        try await persistence.save(loaded, to: fileURL)
        let reloaded = try await persistence.load(from: fileURL)

        XCTAssertEqual(reloaded.sequences[0].uuid, sequence.uuid)
        XCTAssertEqual(reloaded.sequences[0].scenes[0].uuid, scene.uuid)
        XCTAssertEqual(reloaded.sequences[0].scenes[0].shots[0].uuid, shot.uuid)
    }

    // MARK: - Edge Cases

    func testShotWithZeroShotId() {
        let shot = Shot(shotId: 0)
        XCTAssertEqual(shot.shotId, 0)
        XCTAssertFalse(shot.uuid.isEmpty)
        XCTAssertEqual(shot.id, shot.uuid)
        // Old behavior: id would be "0", now it's a UUID
        XCTAssertNotEqual(shot.id, "0")
    }

    func testEmptySequenceDecodes() throws {
        let json = """
        {
            "name": "Empty Act",
            "scenes": []
        }
        """
        let data = json.data(using: .utf8)!
        let seq = try JSONDecoder().decode(Sequence.self, from: data)

        XCTAssertFalse(seq.uuid.isEmpty)
        XCTAssertEqual(seq.name, "Empty Act")
        XCTAssertTrue(seq.scenes.isEmpty)
    }

    func testSequenceWithNilDescription() throws {
        let json = """
        {
            "name": "No Description Act"
        }
        """
        let data = json.data(using: .utf8)!
        let seq = try JSONDecoder().decode(Sequence.self, from: data)

        XCTAssertFalse(seq.uuid.isEmpty)
        XCTAssertEqual(seq.name, "No Description Act")
        XCTAssertNil(seq.description)
        XCTAssertTrue(seq.scenes.isEmpty)
    }

    func testShotAlternativeCodingKeysStillWork() throws {
        // Test that the alternative coding keys (name, notes, lens) still work
        // for Python compatibility, AND that uuid migration works alongside
        let json = """
        {
            "name": "My Shot",
            "notes": "A cool shot",
            "lens": "85mm",
            "status": "Ready",
            "camera_angle": "Low",
            "aperture": "f/1.4",
            "shot_type": "CU",
            "movement": "Dolly In",
            "reference_media": [],
            "linked_dialogue_ids": [],
            "linked_action_ids": [],
            "linked_narration_ids": [],
            "takes": []
        }
        """
        let data = json.data(using: .utf8)!
        let shot = try JSONDecoder().decode(Shot.self, from: data)

        // UUID should be auto-generated
        XCTAssertFalse(shot.uuid.isEmpty)
        XCTAssertNotNil(UUID(uuidString: shot.uuid))
        // Alternative fields should still decode
        XCTAssertEqual(shot.description, "A cool shot")
        XCTAssertEqual(shot.lensMm, 85)
    }

    // MARK: - Large Scale: Many Shots with Same shotId

    func testManyDuplicateShotIdsAllGetUniqueUUIDs() {
        // Simulate creating 100 shots all with shotId=1 (extreme case)
        let shots = (0..<100).map { _ in Shot(shotId: 1, description: "Dup") }
        let uniqueIds = Set(shots.map { $0.id })
        XCTAssertEqual(uniqueIds.count, 100, "All 100 shots should have unique IDs")
    }

    func testManyDuplicateSceneNamesAllGetUniqueUUIDs() {
        let scenes = (0..<50).map { _ in Scene(name: "Scene 1") }
        let uniqueIds = Set(scenes.map { $0.id })
        XCTAssertEqual(uniqueIds.count, 50)
    }

    // MARK: - Cross-Scene Shot Lookup by ID

    func testFindShotByIdAcrossScenes() {
        let targetShot = Shot(shotId: 1, description: "Target")
        let otherShot = Shot(shotId: 1, description: "Decoy")

        let scene1 = Scene(name: "Scene 1", shots: [targetShot])
        let scene2 = Scene(name: "Scene 2", shots: [otherShot])

        let allScenes = [scene1, scene2]

        // Find by UUID — should find the exact shot, not the decoy
        let found = allScenes.flatMap { $0.shots }.first { $0.id == targetShot.id }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.description, "Target")
        XCTAssertEqual(found?.uuid, targetShot.uuid)
    }

    func testFindSceneContainingShotById() {
        let shot = Shot(shotId: 5, description: "My shot")
        let scene1 = Scene(name: "Scene 1", shots: [Shot(shotId: 5, description: "Wrong")])
        let scene2 = Scene(name: "Scene 2", shots: [shot])

        // Find scene by shot.id — should find scene2, not scene1
        let found = [scene1, scene2].first { scene in
            scene.shots.contains { $0.id == shot.id }
        }
        XCTAssertEqual(found?.name, "Scene 2")
    }
}

// MARK: - Auto Status from Takes Tests

final class ShotAutoStatusTests: XCTestCase {

    // MARK: - No Takes

    func testNoTakesDoesNotChangeStatus() {
        var shot = Shot(shotId: 1, status: "Planning")
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Planning")
    }

    func testNoTakesPreservesShootingStatus() {
        var shot = Shot(shotId: 1, status: "Shooting")
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Shooting")
    }

    // MARK: - Has Takes → Review

    func testOneTakeUnratedSetsReview() {
        var shot = Shot(shotId: 1, status: "Shooting", takes: [
            Take(takeNumber: 1)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    func testMultipleUnratedTakesSetsReview() {
        var shot = Shot(shotId: 1, status: "Planning", takes: [
            Take(takeNumber: 1),
            Take(takeNumber: 2),
            Take(takeNumber: 3)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    func testMixedAltAndUnratedSetsReview() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .alt),
            Take(takeNumber: 2, rating: .none),
            Take(takeNumber: 3, rating: .alt)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    // MARK: - Circled Take → Approved

    func testOneCircledTakeSetsApproved() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .circle)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")
    }

    func testCircledAmongMixedSetsApproved() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .ng),
            Take(takeNumber: 2, rating: .circle),
            Take(takeNumber: 3, rating: .alt),
            Take(takeNumber: 4, rating: .none)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")
    }

    func testMultipleCircledTakesSetsApproved() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .circle),
            Take(takeNumber: 2, rating: .circle)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")
    }

    func testCircledTakeOverridesEvenIfSomeNG() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .ng),
            Take(takeNumber: 2, rating: .ng),
            Take(takeNumber: 3, rating: .circle)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")
    }

    // MARK: - All NG → Not Good

    func testAllNGSetsNotGood() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .ng),
            Take(takeNumber: 2, rating: .ng),
            Take(takeNumber: 3, rating: .ng)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Not Good")
    }

    func testSingleNGSetsNotGood() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .ng)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Not Good")
    }

    func testNGAndUnratedDoesNotSetNotGood() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .ng),
            Take(takeNumber: 2, rating: .none)
        ])
        shot.updateStatusFromTakes()
        // Not all are NG (one is unrated), so it should be Review
        XCTAssertEqual(shot.status, "Review")
    }

    func testNGAndAltDoesNotSetNotGood() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .ng),
            Take(takeNumber: 2, rating: .alt)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    // MARK: - Priority: Circle > NG > Review

    func testCircleHasHighestPriority() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .ng),
            Take(takeNumber: 2, rating: .ng),
            Take(takeNumber: 3, rating: .ng),
            Take(takeNumber: 4, rating: .circle)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")
    }

    // MARK: - Status Transitions

    func testTransitionFromPlanningToReview() {
        var shot = Shot(shotId: 1, status: "Planning")
        shot.takes.append(Take(takeNumber: 1))
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    func testTransitionFromReviewToApproved() {
        var shot = Shot(shotId: 1, status: "Review", takes: [
            Take(takeNumber: 1, rating: .none)
        ])
        shot.takes[0].rating = .circle
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")
    }

    func testTransitionFromApprovedBackToReview() {
        // If the circle rating is removed, should go back to Review
        var shot = Shot(shotId: 1, status: "Approved", takes: [
            Take(takeNumber: 1, rating: .circle),
            Take(takeNumber: 2, rating: .none)
        ])
        shot.takes[0].rating = .none
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    func testTransitionFromNotGoodToReview() {
        // If a new unrated take is added after all-NG, should go back to Review
        var shot = Shot(shotId: 1, status: "Not Good", takes: [
            Take(takeNumber: 1, rating: .ng)
        ])
        shot.takes.append(Take(takeNumber: 2))
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    func testTransitionFromNotGoodToApproved() {
        // If a circle is added after all-NG, should go to Approved
        var shot = Shot(shotId: 1, status: "Not Good", takes: [
            Take(takeNumber: 1, rating: .ng),
            Take(takeNumber: 2, rating: .ng)
        ])
        shot.takes.append(Take(takeNumber: 3, rating: .circle))
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")
    }

    // MARK: - Delete Take Scenarios

    func testDeleteCircledTakeReverts() {
        var shot = Shot(shotId: 1, takes: [
            Take(takeNumber: 1, rating: .circle),
            Take(takeNumber: 2, rating: .none)
        ])
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Approved")

        // Remove the circled take
        shot.takes.removeAll { $0.rating == .circle }
        shot.updateStatusFromTakes()
        XCTAssertEqual(shot.status, "Review")
    }

    func testDeleteAllTakesNoChange() {
        var shot = Shot(shotId: 1, status: "Not Good", takes: [
            Take(takeNumber: 1, rating: .ng)
        ])
        shot.takes.removeAll()
        shot.updateStatusFromTakes()
        // No takes → status unchanged
        XCTAssertEqual(shot.status, "Not Good")
    }
}
