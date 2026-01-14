// DirectorsChairProduction
// Production management features for DirectorsChair application
//
// This module provides production-focused views and functionality:
// - Schedule View: Production schedule calendar and management
// - Cast & Crew View: Cast members, crew, teams, and equipment management
// - Budget View: Project budget tracking and expense management

import Foundation

/// Version information for DirectorsChairProduction module
public struct DirectorsChairProductionVersion {
    public static let version = "1.0.0"
    public static let build = "2026.01.13"
}

// MARK: - Module Re-exports

// Schedule Module
@_exported import struct DirectorsChairCore.ScheduleItem
// Note: ScheduleView, ScheduleViewModel, etc. are exported directly from this module

// Cast & Crew Module
@_exported import struct DirectorsChairCore.CastMember
@_exported import struct DirectorsChairCore.CrewMember
@_exported import struct DirectorsChairCore.Team
@_exported import struct DirectorsChairCore.EquipmentItem

// Budget Module
@_exported import struct DirectorsChairCore.ProjectBudget
@_exported import struct DirectorsChairCore.BudgetCategory
@_exported import struct DirectorsChairCore.Expense
