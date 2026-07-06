// DirectorsChairCore — scheduling conflict vocabulary
//
// Extracted from the deleted ProductionServiceProtocol.swift during WS2.1 dead-code removal:
// these types are live (referenced by shipped code); the rest of that file was dead.

import Foundation

/// Conflict type
public enum ConflictType: String, Sendable {
    case actorUnavailable = "Actor Unavailable"
    case locationUnavailable = "Location Unavailable"
    case equipmentConflict = "Equipment Conflict"
    case crewConflict = "Crew Conflict"
    case timingConflict = "Timing Conflict"
    case budgetConflict = "Budget Conflict"
}

/// Conflict severity
public enum ConflictSeverity: Int, Comparable, Sendable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    public static func < (lhs: ConflictSeverity, rhs: ConflictSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
