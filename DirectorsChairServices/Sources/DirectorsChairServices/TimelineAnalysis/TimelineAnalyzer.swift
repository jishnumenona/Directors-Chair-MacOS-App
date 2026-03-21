// DirectorsChairServices/Sources/DirectorsChairServices/TimelineAnalysis/TimelineAnalyzer.swift
//
// AI-Powered Timeline Analysis Service — Multi-Pass Architecture
// Splits each scene into 4 focused AI requests for reliability.

import Foundation
import DirectorsChairCore

// MARK: - Timeline Analyzer Actor

public actor TimelineAnalyzer {

    private let aiClient: AIServiceClient

    public init(aiClient: AIServiceClient = .shared) {
        self.aiClient = aiClient
    }

    // MARK: - Cost Estimation

    /// Estimate the cost of analyzing a set of scenes without making any AI calls.
    /// Returns scene count, estimated AI calls, and estimated USD cost.
    public nonisolated static func estimateCost(
        scenes: [(scene: Scene, sceneName: String, sequenceIndex: Int, sceneIndex: Int)]
    ) -> (sceneCount: Int, estimatedCalls: Int, estimatedCostUSD: Double) {
        let validScenes = scenes.filter { scene in
            !scene.scene.dialogues.isEmpty || !scene.scene.actions.isEmpty || !scene.scene.narrations.isEmpty
        }

        guard !validScenes.isEmpty else {
            return (0, 0, 0)
        }

        var totalCalls = 0
        var totalInputTokens = 0
        var totalOutputTokens = 0

        for sceneInfo in validScenes {
            let scene = sceneInfo.scene
            let itemCount = scene.dialogues.count + scene.actions.count + scene.narrations.count + scene.shots.count
            let hasShotsPasses = !scene.shots.isEmpty

            // Passes 1 (chronology) + 2 (parent-child) always run
            // Passes 3 (shot linking) + 4 (shot durations) only if scene has shots
            let passCount = hasShotsPasses ? 4 : 2
            totalCalls += passCount

            // Estimate ~150 input tokens per item per pass, ~50 output tokens per item per pass
            let inputPerPass = max(itemCount * 150, 200)  // minimum 200 tokens for prompt overhead
            let outputPerPass = max(itemCount * 50, 100)

            totalInputTokens += inputPerPass * passCount
            totalOutputTokens += outputPerPass * passCount
        }

        let costUSD = AIUsageStats.textCallCost(promptTokens: totalInputTokens, completionTokens: totalOutputTokens)

        return (validScenes.count, totalCalls, costUSD)
    }

    // MARK: - Multi-Scene Analysis

    /// Analyze multiple scenes and return aggregated results
    public func analyzeScenes(
        scenes: [(scene: Scene, sceneName: String, sequenceIndex: Int, sceneIndex: Int)],
        progressCallback: (@Sendable (Int) -> Void)? = nil
    ) async throws -> TimelineAnalysisResult {

        let validScenes = scenes.filter { scene in
            !scene.scene.dialogues.isEmpty || !scene.scene.actions.isEmpty || !scene.scene.narrations.isEmpty
        }

        if validScenes.isEmpty {
            return TimelineAnalysisResult()
        }

        var sceneResults: [SceneAnalysisResult] = []
        var failedScenes: [(sceneName: String, error: String)] = []

        for (index, sceneInfo) in validScenes.enumerated() {
            do {
                let result = try await analyzeScene(
                    scene: sceneInfo.scene,
                    sceneName: sceneInfo.sceneName,
                    sequenceIndex: sceneInfo.sequenceIndex,
                    sceneIndex: sceneInfo.sceneIndex,
                    progressCallback: nil
                )
                sceneResults.append(result)
            } catch {
                failedScenes.append((sceneName: sceneInfo.sceneName, error: error.localizedDescription))
            }

            let progress = Int(Double(index + 1) / Double(validScenes.count) * 100)
            progressCallback?(progress)
        }

        return TimelineAnalysisResult(sceneResults: sceneResults, failedScenes: failedScenes)
    }

    // MARK: - Single Scene Analysis (Multi-Pass)

    /// Analyze a single scene using 4 independent AI passes
    public func analyzeScene(
        scene: Scene,
        sceneName: String,
        sequenceIndex: Int,
        sceneIndex: Int,
        progressCallback: (@Sendable (Int) -> Void)? = nil
    ) async throws -> SceneAnalysisResult {

        // Build lookup maps once
        let dialogueUUIDs = Set(scene.dialogues.map(\.uuid))
        let actionUUIDs = Set(scene.actions.map(\.uuid))
        let narrationUUIDs = Set(scene.narrations.map(\.uuid))
        let shotIds = Set(scene.shots.map(\.shotId))

        let context = SceneContext(
            scene: scene,
            sceneName: sceneName,
            dialogueUUIDs: dialogueUUIDs,
            actionUUIDs: actionUUIDs,
            narrationUUIDs: narrationUUIDs,
            shotIds: shotIds
        )

        // Pass 1: Chronology (0% → 20%)
        progressCallback?(0)
        let chronologyChanges = await executePass(
            fullPrompt: buildChronologyPrompt(ctx: context, simplified: false),
            simplifiedPrompt: buildChronologyPrompt(ctx: context, simplified: true),
            maxTokens: 4000,
            parse: { [self] text in self.parseChronologyResponse(text, ctx: context) }
        )
        progressCallback?(20)

        // Pass 2: Parent-Child (20% → 40%)
        let parentChildChanges = await executePass(
            fullPrompt: buildParentChildPrompt(ctx: context, simplified: false),
            simplifiedPrompt: buildParentChildPrompt(ctx: context, simplified: true),
            maxTokens: 2000,
            parse: { [self] text in self.parseParentChildResponse(text, ctx: context) }
        )
        progressCallback?(40)

        // Pass 3: Shot Linking (40% → 70%)
        let shotLinkChanges: [ShotLinkChange]
        if scene.shots.isEmpty {
            shotLinkChanges = []
        } else {
            shotLinkChanges = await executePass(
                fullPrompt: buildShotLinkingPrompt(ctx: context, simplified: false),
                simplifiedPrompt: buildShotLinkingPrompt(ctx: context, simplified: true),
                maxTokens: 8000,
                parse: { [self] text in self.parseShotLinkResponse(text, ctx: context) }
            )
        }
        progressCallback?(70)

        // Pass 4: Shot Durations (70% → 90%)
        let shotDurationChanges: [ShotDurationChange]
        if scene.shots.isEmpty {
            shotDurationChanges = []
        } else {
            shotDurationChanges = await executePass(
                fullPrompt: buildShotDurationPrompt(ctx: context, simplified: false),
                simplifiedPrompt: buildShotDurationPrompt(ctx: context, simplified: true),
                maxTokens: 2000,
                parse: { [self] text in self.parseShotDurationResponse(text, ctx: context) }
            )
        }
        progressCallback?(90)

        // Merge results
        let result = SceneAnalysisResult(
            sceneName: sceneName,
            sequenceIndex: sequenceIndex,
            sceneIndex: sceneIndex,
            chronologyChanges: chronologyChanges,
            shotLinkChanges: shotLinkChanges,
            parentChildChanges: parentChildChanges,
            shotDurationChanges: shotDurationChanges
        )
        progressCallback?(100)

        // If ALL passes returned empty, treat as total failure so scene shows in failedScenes
        if chronologyChanges.isEmpty && parentChildChanges.isEmpty &&
           shotLinkChanges.isEmpty && shotDurationChanges.isEmpty &&
           (!scene.dialogues.isEmpty || !scene.actions.isEmpty || !scene.narrations.isEmpty) &&
           !scene.shots.isEmpty {
            // Only throw if the scene has enough content that we'd expect some results
            let totalItems = scene.dialogues.count + scene.actions.count + scene.narrations.count + scene.shots.count
            if totalItems > 3 {
                throw AIClientError.invalidResponse("All 4 analysis passes returned empty results for scene: \(sceneName)")
            }
        }

        return result
    }

    // MARK: - Scene Context

    private struct SceneContext {
        let scene: Scene
        let sceneName: String
        let dialogueUUIDs: Set<String>
        let actionUUIDs: Set<String>
        let narrationUUIDs: Set<String>
        let shotIds: Set<Int>
    }

    // MARK: - Excerpt Length Helper

    /// Calculate max text excerpt length based on total item count
    private func excerptLength(itemCount: Int) -> Int {
        switch itemCount {
        case ..<50: return 200
        case 50..<150: return 80
        case 150..<300: return 40
        default: return 25
        }
    }

    // MARK: - AI Call Helper

    /// Call AI, strip markdown fences, return raw text. Throws on network/API errors.
    private func callAI(prompt: String, maxTokens: Int) async throws -> String {
        let request = TextGenerationRequest(
            prompt: prompt,
            provider: .googleGemini,
            maxTokens: maxTokens,
            temperature: 0.1
        )
        let response = try await aiClient.generateText(request)
        return extractJSON(from: response.text)
    }

    /// Strip markdown fences and extract JSON text
    private func extractJSON(from response: String) -> String {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences
        if let startRange = text.range(of: "```json") {
            text = String(text[startRange.upperBound...])
        } else if text.hasPrefix("```") {
            text = String(text.dropFirst(3))
        }
        if let endRange = text.range(of: "```", options: .backwards) {
            text = String(text[..<endRange.lowerBound])
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract the outermost [ ... ] or { ... }
        if let firstBracket = text.firstIndex(of: "["),
           let lastBracket = text.lastIndex(of: "]") {
            let firstBrace = text.firstIndex(of: "{") ?? text.endIndex
            if firstBracket < firstBrace {
                text = String(text[firstBracket...lastBracket])
            }
        }
        if text.first == "{" {
            if let firstBrace = text.firstIndex(of: "{"),
               let lastBrace = text.lastIndex(of: "}") {
                text = String(text[firstBrace...lastBrace])
            }
        }

        return text
    }

    // MARK: - Execute Pass with Retry

    /// Execute a single analysis pass with one retry on failure using simplified prompt.
    /// Returns empty array if both attempts fail (never throws).
    private func executePass<T>(
        fullPrompt: String,
        simplifiedPrompt: String,
        maxTokens: Int,
        parse: @Sendable (String) -> [T]
    ) async -> [T] {
        // Attempt 1: full prompt
        if let text = try? await callAI(prompt: fullPrompt, maxTokens: maxTokens) {
            let result = parse(text)
            if !result.isEmpty { return result }
        }

        // Attempt 2: simplified prompt (shorter excerpts)
        if let text = try? await callAI(prompt: simplifiedPrompt, maxTokens: maxTokens) {
            let result = parse(text)
            return result // Return even if empty — we tried our best
        }

        return []
    }

    // MARK: - JSON Repair

    /// Attempt to repair truncated JSON by closing open brackets/braces
    nonisolated private func repairTruncatedJSON(_ json: String) -> String {
        var result = json
        var openBraces = 0
        var openBrackets = 0
        var inString = false
        var escaped = false

        for char in result {
            if escaped {
                escaped = false
                continue
            }
            if char == "\\" {
                escaped = true
                continue
            }
            if char == "\"" {
                inString = !inString
                continue
            }
            if inString { continue }

            switch char {
            case "{": openBraces += 1
            case "}": openBraces -= 1
            case "[": openBrackets += 1
            case "]": openBrackets -= 1
            default: break
            }
        }

        if inString { result += "\"" }

        // Strip trailing incomplete object/value before closing
        // e.g. [..., {"u":"abc","c  →  [...]
        if openBraces > 0 || openBrackets > 0 {
            // Remove last incomplete entry: from last comma outside a closed object to end
            if let lastCompleteComma = findLastCompleteEntryComma(result) {
                result = String(result[...lastCompleteComma])
                // Recount after truncation
                var ob = 0; var obr = 0; var inS = false; var esc = false
                for ch in result {
                    if esc { esc = false; continue }
                    if ch == "\\" { esc = true; continue }
                    if ch == "\"" { inS = !inS; continue }
                    if inS { continue }
                    switch ch {
                    case "{": ob += 1; case "}": ob -= 1
                    case "[": obr += 1; case "]": obr -= 1
                    default: break
                    }
                }
                openBraces = ob
                openBrackets = obr
            }
        }

        result = result.replacingOccurrences(of: ",\\s*$", with: "", options: .regularExpression)
        for _ in 0..<max(0, openBrackets) { result += "]" }
        for _ in 0..<max(0, openBraces) { result += "}" }
        result = result.replacingOccurrences(of: ",\\s*([\\]\\}])", with: "$1", options: .regularExpression)

        return result
    }

    /// Find the index of the last comma that separates two complete JSON entries in an array
    nonisolated private func findLastCompleteEntryComma(_ json: String) -> String.Index? {
        var depth = 0
        var inString = false
        var escaped = false
        var lastCommaAtDepth1: String.Index?

        for idx in json.indices {
            let char = json[idx]
            if escaped { escaped = false; continue }
            if char == "\\" { escaped = true; continue }
            if char == "\"" { inString = !inString; continue }
            if inString { continue }

            switch char {
            case "{", "[": depth += 1
            case "}", "]": depth -= 1
            case ",":
                if depth == 1 { lastCommaAtDepth1 = idx }
            default: break
            }
        }

        return lastCommaAtDepth1
    }

    /// Parse a JSON array string, attempting repair if needed
    nonisolated private func parseJSONArray(_ text: String) -> [[String: Any]]? {
        var jsonText = text
        if !jsonText.hasSuffix("]") {
            jsonText = repairTruncatedJSON(jsonText)
        }

        guard let data = jsonText.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return parsed
    }

    // MARK: - Pass 1: Chronology

    private func buildChronologyPrompt(ctx: SceneContext, simplified: Bool) -> String {
        let scene = ctx.scene
        let totalItems = scene.dialogues.count + scene.actions.count + scene.narrations.count
        let maxLen = simplified ? 30 : excerptLength(itemCount: totalItems)

        var items: [String] = []
        for d in scene.dialogues {
            let excerpt = String(d.text.prefix(maxLen)).replacingOccurrences(of: "\n", with: " ")
            items.append("""
            {"u":"\(d.uuid)","t":"d","ch":"\(d.character)","x":"\(excerpt)","c":\(d.chronologyNumber)}
            """)
        }
        for a in scene.actions {
            let excerpt = String(a.description.prefix(maxLen)).replacingOccurrences(of: "\n", with: " ")
            items.append("""
            {"u":"\(a.uuid)","t":"a","x":"\(excerpt)","c":\(a.chronologyNumber)}
            """)
        }
        for n in scene.narrations {
            let excerpt = String(n.text.prefix(maxLen)).replacingOccurrences(of: "\n", with: " ")
            items.append("""
            {"u":"\(n.uuid)","t":"n","x":"\(excerpt)","c":\(n.chronologyNumber)}
            """)
        }

        return """
        # CHRONOLOGY ANALYSIS — \(ctx.sceneName)

        You are an expert script supervisor. Assign correct chronology numbers to each script item based on narrative order.

        ## Items
        [\(items.joined(separator: ",\n"))]

        Key: u=uuid, t=type (d=dialogue, a=action, n=narration), ch=character, x=text excerpt, c=current chronology number

        ## Rules
        - chronologyNumber is 1-based sequential WITHIN each type (dialogues get 1,2,3...; actions get 1,2,3...; narrations get 1,2,3... independently)
        - Order by narrative flow: which dialogue comes first in the scene, which action comes first, etc.
        - ONLY include items whose chronology number actually CHANGES from their current value

        ## Output
        Return ONLY a JSON array (no wrapping object). Each entry: {"u":"uuid","t":"d|a|n","c":NEW_NUMBER}
        If nothing changes, return []
        """
    }

    nonisolated private func parseChronologyResponse(_ text: String, ctx: SceneContext) -> [ChronologyChange] {
        guard let array = parseJSONArray(text) else { return [] }

        var changes: [ChronologyChange] = []
        for item in array {
            guard let uuid = item["u"] as? String,
                  let typeStr = item["t"] as? String,
                  let newNumber = (item["c"] as? Int) ?? (item["c"] as? Double).map({ Int($0) }) else { continue }

            let itemType: ScriptItemType
            var oldNumber = 0
            var label = ""

            switch typeStr {
            case "d":
                guard ctx.dialogueUUIDs.contains(uuid) else { continue }
                itemType = .dialogue
                if let d = ctx.scene.dialogues.first(where: { $0.uuid == uuid }) {
                    oldNumber = d.chronologyNumber
                    label = "\(d.character): \(String(d.text.prefix(40)))"
                }
            case "a":
                guard ctx.actionUUIDs.contains(uuid) else { continue }
                itemType = .action
                if let a = ctx.scene.actions.first(where: { $0.uuid == uuid }) {
                    oldNumber = a.chronologyNumber
                    label = String(a.description.prefix(50))
                }
            case "n":
                guard ctx.narrationUUIDs.contains(uuid) else { continue }
                itemType = .narration
                if let n = ctx.scene.narrations.first(where: { $0.uuid == uuid }) {
                    oldNumber = n.chronologyNumber
                    label = String(n.text.prefix(50))
                }
            default:
                continue
            }

            if oldNumber != newNumber {
                changes.append(ChronologyChange(
                    id: uuid, itemType: itemType, label: label,
                    oldNumber: oldNumber, newNumber: newNumber
                ))
            }
        }
        return changes
    }

    // MARK: - Pass 2: Parent-Child Grouping

    private func buildParentChildPrompt(ctx: SceneContext, simplified: Bool) -> String {
        let scene = ctx.scene
        let totalItems = scene.dialogues.count + scene.actions.count + scene.narrations.count
        let maxLen = simplified ? 20 : excerptLength(itemCount: totalItems)

        var dialogueItems: [String] = []
        for d in scene.dialogues {
            let excerpt = String(d.text.prefix(maxLen)).replacingOccurrences(of: "\n", with: " ")
            dialogueItems.append("""
            {"u":"\(d.uuid)","ch":"\(d.character)","x":"\(excerpt)"}
            """)
        }

        var childItems: [String] = []
        for a in scene.actions {
            let excerpt = String(a.description.prefix(maxLen)).replacingOccurrences(of: "\n", with: " ")
            let parent = a.parentDialogueId.map { "\"\($0)\"" } ?? "null"
            childItems.append("""
            {"u":"\(a.uuid)","t":"a","x":"\(excerpt)","p":\(parent)}
            """)
        }
        for n in scene.narrations {
            let excerpt = String(n.text.prefix(maxLen)).replacingOccurrences(of: "\n", with: " ")
            let parent = n.parentDialogueId.map { "\"\($0)\"" } ?? "null"
            childItems.append("""
            {"u":"\(n.uuid)","t":"n","x":"\(excerpt)","p":\(parent)}
            """)
        }

        if childItems.isEmpty {
            return """
            Return []
            """
        }

        return """
        # PARENT-CHILD GROUPING — \(ctx.sceneName)

        You are an expert script supervisor. Determine which actions/narrations are stage directions or parentheticals belonging under a specific dialogue.

        ## Dialogues (potential parents)
        [\(dialogueItems.joined(separator: ",\n"))]

        ## Actions & Narrations (potential children)
        [\(childItems.joined(separator: ",\n"))]

        Key: u=uuid, ch=character, t=type (a=action, n=narration), x=text excerpt, p=current parentDialogueId (null if none)

        ## Rules
        - An action like "(sighs)", "(picks up phone)", stage directions right before/after a character speaks should be parented to that dialogue
        - Standalone scene actions (e.g. "The door opens") should have p=null
        - p must be a valid dialogue UUID from the list above, or null
        - ONLY include items whose parent actually CHANGES from current value

        ## Output
        Return ONLY a JSON array. Each entry: {"u":"uuid","t":"a|n","p":"parent-dialogue-uuid-or-null"}
        Use the string "null" for no parent. If nothing changes, return []
        """
    }

    nonisolated private func parseParentChildResponse(_ text: String, ctx: SceneContext) -> [ParentChildChange] {
        guard let array = parseJSONArray(text) else { return [] }

        var changes: [ParentChildChange] = []
        for item in array {
            guard let uuid = item["u"] as? String,
                  let typeStr = item["t"] as? String else { continue }

            let newParentId: String?
            if let pid = item["p"] as? String, !pid.isEmpty, pid != "null" {
                guard ctx.dialogueUUIDs.contains(pid) else { continue }
                newParentId = pid
            } else {
                newParentId = nil
            }

            let itemType: ScriptItemType
            var oldParentId: String?
            var label = ""

            switch typeStr {
            case "a":
                guard ctx.actionUUIDs.contains(uuid) else { continue }
                itemType = .action
                if let a = ctx.scene.actions.first(where: { $0.uuid == uuid }) {
                    oldParentId = a.parentDialogueId
                    label = String(a.description.prefix(50))
                }
            case "n":
                guard ctx.narrationUUIDs.contains(uuid) else { continue }
                itemType = .narration
                if let n = ctx.scene.narrations.first(where: { $0.uuid == uuid }) {
                    oldParentId = n.parentDialogueId
                    label = String(n.text.prefix(50))
                }
            default:
                continue
            }

            if oldParentId != newParentId {
                changes.append(ParentChildChange(
                    id: uuid, itemType: itemType, label: label,
                    oldParentDialogueId: oldParentId, newParentDialogueId: newParentId
                ))
            }
        }
        return changes
    }

    // MARK: - Pass 3: Shot Linking

    private func buildShotLinkingPrompt(ctx: SceneContext, simplified: Bool) -> String {
        let scene = ctx.scene
        let totalItems = scene.dialogues.count + scene.actions.count + scene.narrations.count + scene.shots.count
        let shotLen = simplified ? 40 : excerptLength(itemCount: totalItems)
        let scriptLen = simplified ? 20 : min(40, excerptLength(itemCount: totalItems))

        var shotItems: [String] = []
        for s in scene.shots {
            let desc = String(s.description.prefix(shotLen)).replacingOccurrences(of: "\n", with: " ")
            shotItems.append("""
            {"s":\(s.shotId),"tp":"\(s.shotType)","ag":"\(s.cameraAngle)","mv":"\(s.movement)","x":"\(desc)"}
            """)
        }

        var scriptItems: [String] = []
        for d in scene.dialogues {
            let excerpt = String(d.text.prefix(scriptLen)).replacingOccurrences(of: "\n", with: " ")
            scriptItems.append("""
            {"u":"\(d.uuid)","t":"d","ch":"\(d.character)","x":"\(excerpt)"}
            """)
        }
        for a in scene.actions {
            let excerpt = String(a.description.prefix(scriptLen)).replacingOccurrences(of: "\n", with: " ")
            scriptItems.append("""
            {"u":"\(a.uuid)","t":"a","x":"\(excerpt)"}
            """)
        }
        for n in scene.narrations {
            let excerpt = String(n.text.prefix(scriptLen)).replacingOccurrences(of: "\n", with: " ")
            scriptItems.append("""
            {"u":"\(n.uuid)","t":"n","x":"\(excerpt)"}
            """)
        }

        return """
        # SHOT LINKING — \(ctx.sceneName)

        You are an expert film editor. Link each shot to the script items (dialogues, actions, narrations) it covers.

        ## Shots
        [\(shotItems.joined(separator: ",\n"))]

        Key: s=shotId, tp=shotType, ag=cameraAngle, mv=movement, x=description

        ## Script Items
        [\(scriptItems.joined(separator: ",\n"))]

        Key: u=uuid, t=type (d=dialogue, a=action, n=narration), ch=character, x=text excerpt

        ## Rules
        - Link shots to the script items they visually cover based on description, type, and angle
        - A close-up on a character typically covers that character's dialogues + nearby actions
        - A wide/establishing shot may cover multiple items
        - Use ONLY UUIDs from the script items list above
        - Include ALL shots, even if they have no links (empty arrays)

        ## Output
        Return ONLY a JSON array. Each entry: {"s":SHOT_ID,"d":["dialogue-uuids"],"a":["action-uuids"],"n":["narration-uuids"]}
        """
    }

    nonisolated private func parseShotLinkResponse(_ text: String, ctx: SceneContext) -> [ShotLinkChange] {
        guard let array = parseJSONArray(text) else { return [] }

        var changes: [ShotLinkChange] = []
        for item in array {
            guard let shotId = (item["s"] as? Int) ?? (item["s"] as? Double).map({ Int($0) }),
                  ctx.shotIds.contains(shotId),
                  let shot = ctx.scene.shots.first(where: { $0.shotId == shotId }) else { continue }

            let newDialogueIds = (item["d"] as? [String] ?? []).filter { ctx.dialogueUUIDs.contains($0) }
            let newActionIds = (item["a"] as? [String] ?? []).filter { ctx.actionUUIDs.contains($0) }
            let newNarrationIds = (item["n"] as? [String] ?? []).filter { ctx.narrationUUIDs.contains($0) }

            let oldDialogueSet = Set(shot.linkedDialogueIds)
            let oldActionSet = Set(shot.linkedActionIds)
            let oldNarrationSet = Set(shot.linkedNarrationIds)
            let newDialogueSet = Set(newDialogueIds)
            let newActionSet = Set(newActionIds)
            let newNarrationSet = Set(newNarrationIds)

            let change = ShotLinkChange(
                shotId: shotId,
                shotLabel: "Shot \(shot.shotId) - \(shot.shotType) \(shot.cameraAngle)",
                addedDialogueIds: Array(newDialogueSet.subtracting(oldDialogueSet)),
                removedDialogueIds: Array(oldDialogueSet.subtracting(newDialogueSet)),
                addedActionIds: Array(newActionSet.subtracting(oldActionSet)),
                removedActionIds: Array(oldActionSet.subtracting(newActionSet)),
                addedNarrationIds: Array(newNarrationSet.subtracting(oldNarrationSet)),
                removedNarrationIds: Array(oldNarrationSet.subtracting(newNarrationSet))
            )

            if change.totalChanges > 0 {
                changes.append(change)
            }
        }
        return changes
    }

    // MARK: - Pass 4: Shot Durations

    private func buildShotDurationPrompt(ctx: SceneContext, simplified: Bool) -> String {
        let scene = ctx.scene
        let maxLen = simplified ? 30 : 60

        var items: [String] = []
        for s in scene.shots {
            let desc = String(s.description.prefix(maxLen)).replacingOccurrences(of: "\n", with: " ")
            let linkedCount = s.linkedDialogueIds.count + s.linkedActionIds.count + s.linkedNarrationIds.count
            let durStr = s.duration.map { String(format: "%.1f", $0) } ?? "null"
            items.append("""
            {"s":\(s.shotId),"tp":"\(s.shotType)","ag":"\(s.cameraAngle)","mv":"\(s.movement)","lc":\(linkedCount),"d":\(durStr),"x":"\(desc)"}
            """)
        }

        return """
        # SHOT DURATION ESTIMATION — \(ctx.sceneName)

        You are an expert film editor. Estimate appropriate duration in seconds for each shot.

        ## Shots
        [\(items.joined(separator: ",\n"))]

        Key: s=shotId, tp=shotType, ag=cameraAngle, mv=movement, lc=linked script item count, d=current duration (null=unset), x=description

        ## Duration Guidelines
        - Wide/Establishing: 3-6s
        - Medium: 2-5s
        - Close-up: 1-3s
        - Action/tracking: 1-4s
        - More linked items = longer duration
        - Complex movements = longer duration

        ## Rules
        - ONLY include shots whose duration actually CHANGES from current value (or is currently null)
        - Durations should be realistic for the shot type and content

        ## Output
        Return ONLY a JSON array. Each entry: {"s":SHOT_ID,"d":DURATION_SECONDS}
        If nothing changes, return []
        """
    }

    nonisolated private func parseShotDurationResponse(_ text: String, ctx: SceneContext) -> [ShotDurationChange] {
        guard let array = parseJSONArray(text) else { return [] }

        var changes: [ShotDurationChange] = []
        for item in array {
            guard let shotId = (item["s"] as? Int) ?? (item["s"] as? Double).map({ Int($0) }),
                  ctx.shotIds.contains(shotId),
                  let shot = ctx.scene.shots.first(where: { $0.shotId == shotId }) else { continue }

            let newDuration: Double
            if let d = item["d"] as? Double {
                newDuration = d
            } else if let d = item["d"] as? Int {
                newDuration = Double(d)
            } else {
                continue
            }

            let oldDuration = shot.duration
            let changed: Bool
            if let old = oldDuration {
                changed = abs(old - newDuration) > 0.1
            } else {
                changed = true
            }

            if changed {
                changes.append(ShotDurationChange(
                    shotId: shotId,
                    shotLabel: "Shot \(shot.shotId) - \(shot.shotType) \(shot.cameraAngle)",
                    oldDuration: oldDuration, newDuration: newDuration
                ))
            }
        }
        return changes
    }

    // MARK: - Apply Changes

    /// Apply confirmed changes to a project. Call from main thread.
    public static func applyChanges(to project: inout Project, from result: TimelineAnalysisResult) {
        for sceneResult in result.sceneResults where sceneResult.hasChanges {
            guard sceneResult.sequenceIndex < project.sequences.count,
                  sceneResult.sceneIndex < project.sequences[sceneResult.sequenceIndex].scenes.count else { continue }

            // Apply chronology changes
            for change in sceneResult.chronologyChanges {
                switch change.itemType {
                case .dialogue:
                    if let idx = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                        .dialogues.firstIndex(where: { $0.uuid == change.id }) {
                        project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                            .dialogues[idx].chronologyNumber = change.newNumber
                    }
                case .action:
                    if let idx = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                        .actions.firstIndex(where: { $0.uuid == change.id }) {
                        project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                            .actions[idx].chronologyNumber = change.newNumber
                    }
                case .narration:
                    if let idx = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                        .narrations.firstIndex(where: { $0.uuid == change.id }) {
                        project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                            .narrations[idx].chronologyNumber = change.newNumber
                    }
                }
            }

            // Apply shot link changes
            for change in sceneResult.shotLinkChanges {
                if let idx = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                    .shots.firstIndex(where: { $0.shotId == change.shotId }) {

                    var shot = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex].shots[idx]

                    for id in change.addedDialogueIds where !shot.linkedDialogueIds.contains(id) {
                        shot.linkedDialogueIds.append(id)
                    }
                    for id in change.addedActionIds where !shot.linkedActionIds.contains(id) {
                        shot.linkedActionIds.append(id)
                    }
                    for id in change.addedNarrationIds where !shot.linkedNarrationIds.contains(id) {
                        shot.linkedNarrationIds.append(id)
                    }

                    shot.linkedDialogueIds.removeAll { change.removedDialogueIds.contains($0) }
                    shot.linkedActionIds.removeAll { change.removedActionIds.contains($0) }
                    shot.linkedNarrationIds.removeAll { change.removedNarrationIds.contains($0) }

                    project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex].shots[idx] = shot
                }
            }

            // Apply parent-child changes
            for change in sceneResult.parentChildChanges {
                switch change.itemType {
                case .action:
                    if let idx = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                        .actions.firstIndex(where: { $0.uuid == change.id }) {
                        project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                            .actions[idx].parentDialogueId = change.newParentDialogueId
                    }
                case .narration:
                    if let idx = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                        .narrations.firstIndex(where: { $0.uuid == change.id }) {
                        project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                            .narrations[idx].parentDialogueId = change.newParentDialogueId
                    }
                case .dialogue:
                    break
                }
            }

            // Apply shot duration changes
            for change in sceneResult.shotDurationChanges {
                if let idx = project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                    .shots.firstIndex(where: { $0.shotId == change.shotId }) {
                    project.sequences[sceneResult.sequenceIndex].scenes[sceneResult.sceneIndex]
                        .shots[idx].duration = change.newDuration
                }
            }
        }
    }
}
