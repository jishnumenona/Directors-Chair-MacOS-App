// DirectorsChairServices/Assistant/AssistantAction.swift
//
// AssistantKit (Phase A2.2): the typed action contract the assistant's tools
// are built from. An action wraps an EXISTING mutation/read seam (server plan
// AD3/§6.2) — it never re-implements app logic. Actions are constructed with
// their dependencies (closures/weak refs) so the kit stays app-agnostic;
// validate/execute are `@MainActor` because the app's entire mutation surface
// is main-actor-bound.

import Foundation

/// What executing an action can do — drives the engine's safety policy
/// (AD5): read-only actions auto-execute inside the loop; mutating and
/// spending actions are only *proposed*, and run after user approval.
public enum ActionRisk: Sendable, Equatable {
    case readOnly
    case mutating
    case spending
}

/// One human-readable diff line on the review card.
public struct ActionPreview: Sendable, Equatable {
    public var title: String
    public var oldValue: String?
    public var newValue: String?

    public init(title: String, oldValue: String? = nil, newValue: String? = nil) {
        self.title = title
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

/// The validated, previewable outcome of an action's argument check.
public struct ActionPlan: Sendable, Equatable {
    /// One sentence: what applying this will do.
    public var summary: String
    public var previews: [ActionPreview]

    public init(summary: String, previews: [ActionPreview] = []) {
        self.summary = summary
        self.previews = previews
    }
}

/// What an executed action reports.
public struct ActionOutcome: Sendable, Equatable {
    /// Compact JSON/text fed back to the model as the tool result.
    public var resultForModel: String
    /// One line for the activity chip in the chat UI.
    public var userSummary: String

    public init(resultForModel: String, userSummary: String) {
        self.resultForModel = resultForModel
        self.userSummary = userSummary
    }
}

public struct ActionError: LocalizedError, Equatable {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// A tool the assistant can call. Conformances decode their own typed
/// `Arguments` from the raw JSON the registry hands them, validate against
/// the live project state (mutators silently no-op on bad IDs — the action
/// layer is where existence checks live), and execute through the existing
/// app seams.
public protocol AssistantAction: Sendable {
    /// Wire name — must match `^[A-Za-z0-9_-]{1,64}$` (gateway contract).
    var name: String { get }
    /// One-line description shown to the model in the tool definition.
    var summary: String { get }
    /// JSON Schema for the arguments object.
    var parameterSchema: JSONValue { get }
    var risk: ActionRisk { get }

    /// Checks arguments against live state and produces the preview.
    /// MUST throw `ActionError` (with a model-consumable message) on invalid
    /// arguments or missing entities — never silently no-op.
    @MainActor func validate(argumentsData: Data) throws -> ActionPlan

    /// Performs the action. For `.readOnly` the engine calls this directly
    /// inside the loop; for `.mutating`/`.spending` it runs only after user
    /// approval (Phase A2.4 UI).
    @MainActor func execute(argumentsData: Data) async throws -> ActionOutcome
}

// MARK: - Registry

/// The immutable-after-setup action catalog: name → action, plus the tool
/// definitions advertised to the gateway.
public struct ActionRegistry: Sendable {
    public static let namePattern = "^[A-Za-z0-9_-]{1,64}$"

    private var actions: [String: any AssistantAction] = [:]
    private var order: [String] = []

    public init() {}

    /// Registers an action. Throws on a duplicate or invalid wire name so a
    /// misconfigured registry fails loudly at startup, not at call time.
    public mutating func register(_ action: any AssistantAction) throws {
        guard action.name.range(of: Self.namePattern,
                                options: .regularExpression) != nil else {
            throw ActionError("invalid action name '\(action.name)'")
        }
        guard actions[action.name] == nil else {
            throw ActionError("duplicate action name '\(action.name)'")
        }
        actions[action.name] = action
        order.append(action.name)
    }

    public func action(named name: String) -> (any AssistantAction)? {
        actions[name]
    }

    public var count: Int { order.count }

    /// Tool definitions in registration order — stable prompts, stable evals.
    public var toolDefinitions: [ToolDefinition] {
        order.compactMap { name in
            actions[name].map {
                ToolDefinition(name: $0.name, description: $0.summary,
                               parameters: $0.parameterSchema)
            }
        }
    }
}

// MARK: - Turn undo

/// Whole-state snapshot undo for one applied assistant turn (AD5). Generic
/// over the app's state value (`Project` is a value struct, so capture and
/// restore are total). The app layer captures before applying a TurnPlan and
/// offers a single "Undo assistant changes".
public struct TurnSnapshot<State: Sendable>: Sendable {
    public let captured: State
    private let restoreHandler: @MainActor @Sendable (State) -> Void

    public init(state: State,
                restore: @escaping @MainActor @Sendable (State) -> Void) {
        self.captured = state
        self.restoreHandler = restore
    }

    @MainActor public func restore() {
        restoreHandler(captured)
    }
}
