//
//  FDElementFlow.swift
//  DirectorsChair-Desktop
//
//  Editor v2 (Final Draft parity): the deterministic element-flow state
//  machine that gives industry screenplay editors their speed. Tables match
//  Final Draft's defaults (docs/editor-v2-design.md §1.2).
//

import Foundation

enum FDElementFlow {

    /// UserDefaults key for FD's one commonly-changed default: what Return
    /// creates after Dialogue ("action" = FD default, "character" = the
    /// popular alternative FD exposes in Format ▸ Elements).
    static let returnAfterDialogueKey = "editor.returnAfterDialogue"

    static var returnAfterDialogue: ScriptElementType {
        UserDefaults.standard.string(forKey: returnAfterDialogueKey) == "character"
            ? .character : .action
    }

    /// What Return at the end of an element creates next (FD "Next Element").
    static func nextOnReturn(after type: ScriptElementType) -> ScriptElementType {
        switch type {
        case .sceneHeading:   return .action
        case .action:         return .action
        case .character:      return .dialogue
        case .parenthetical:  return .dialogue
        case .dialogue:       return returnAfterDialogue
        case .transition:     return .sceneHeading
        case .blankLine:      return .action
        default:              return .action
        }
    }

    /// What Tab transitions to (FD Tab table). On an empty element the
    /// element CONVERTS to this type; at the end of a non-empty element a new
    /// element of this type is created.
    static func nextOnTab(from type: ScriptElementType) -> ScriptElementType {
        switch type {
        case .sceneHeading:   return .action
        case .action:         return .character
        case .character:      return .transition
        case .parenthetical:  return .dialogue
        case .dialogue:       return .parenthetical
        case .transition:     return .sceneHeading
        case .blankLine:      return .character
        default:              return .action
        }
    }

    /// Direct element switching, FD's ⌘1–6 (bound to ⌃1–6 here because ⌘1–9
    /// navigates views in DirectorsChair).
    static func elementType(forDigit digit: Int) -> ScriptElementType? {
        switch digit {
        case 1: return .sceneHeading
        case 2: return .action
        case 3: return .character
        case 4: return .parenthetical
        case 5: return .dialogue
        case 6: return .transition
        default: return nil
        }
    }

    /// Element kinds that industry format stores in UPPERCASE.
    static func autoUppercases(_ type: ScriptElementType) -> Bool {
        type == .sceneHeading || type == .transition
    }
}
