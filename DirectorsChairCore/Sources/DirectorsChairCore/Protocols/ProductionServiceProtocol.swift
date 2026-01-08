// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/ProductionServiceProtocol.swift
//
// Protocol interfaces for production management services (Module 3)

import Foundation

// MARK: - ScriptAnalyzerProtocol

/// Protocol for script analysis and breakdown services
public protocol ScriptAnalyzerProtocol: Sendable {
    /// Parse script text into structured scenes
    /// - Parameters:
    ///   - scriptText: Raw script text
    ///   - format: Script format (FDX, Fountain, plain text)
    /// - Returns: Array of parsed scenes
    func parseScript(
        scriptText: String,
        format: ScriptFormat
    ) async throws -> [Scene]

    /// Extract characters from script
    /// - Parameter scriptText: Raw script text
    /// - Returns: Array of character names found
    func extractCharacters(scriptText: String) async throws -> [String]

    /// Analyze scene for production requirements
    /// - Parameter scene: Scene to analyze
    /// - Returns: Production requirements (props, locations, cast, etc.)
    func analyzeScene(scene: Scene) async throws -> ProductionRequirements

    /// Generate breakdown report
    /// - Parameter project: Project to analyze
    /// - Returns: Comprehensive breakdown data
    func generateBreakdown(project: Project) async throws -> BreakdownReport
}

// MARK: - SchedulingServiceProtocol

/// Protocol for production scheduling services
public protocol SchedulingServiceProtocol: Sendable {
    /// Generate optimized shooting schedule
    /// - Parameters:
    ///   - project: Project to schedule
    ///   - constraints: Scheduling constraints (actor availability, locations, etc.)
    /// - Returns: Optimized schedule
    func generateSchedule(
        project: Project,
        constraints: SchedulingConstraints
    ) async throws -> [ScheduleItem]

    /// Optimize existing schedule
    /// - Parameters:
    ///   - schedule: Current schedule
    ///   - project: Project context
    /// - Returns: Optimized schedule
    func optimizeSchedule(
        schedule: [ScheduleItem],
        project: Project
    ) async throws -> [ScheduleItem]

    /// Calculate shooting days required
    /// - Parameters:
    ///   - project: Project to analyze
    ///   - constraints: Scheduling constraints
    /// - Returns: Estimated number of shooting days
    func estimateShootingDays(
        project: Project,
        constraints: SchedulingConstraints
    ) async throws -> Int

    /// Check for scheduling conflicts
    /// - Parameters:
    ///   - schedule: Schedule to validate
    ///   - project: Project context
    /// - Returns: Array of conflicts found
    func validateSchedule(
        schedule: [ScheduleItem],
        project: Project
    ) async throws -> [SchedulingConflict]
}

// MARK: - BudgetServiceProtocol

/// Protocol for budget management services
public protocol BudgetServiceProtocol: Sendable {
    /// Generate budget estimate from project
    /// - Parameter project: Project to budget
    /// - Returns: Estimated project budget
    func generateBudgetEstimate(project: Project) async throws -> ProjectBudget

    /// Track expenses against budget
    /// - Parameters:
    ///   - budget: Current budget
    ///   - expenses: New expenses to add
    /// - Returns: Updated budget with expenses tracked
    func trackExpenses(
        budget: ProjectBudget,
        expenses: [Expense]
    ) async throws -> ProjectBudget

    /// Generate budget report
    /// - Parameter budget: Budget to report on
    /// - Returns: Formatted budget report
    func generateBudgetReport(budget: ProjectBudget) async throws -> BudgetReport

    /// Forecast budget overruns
    /// - Parameters:
    ///   - budget: Current budget
    ///   - burnRate: Current spending rate
    /// - Returns: Forecast data
    func forecastBudget(
        budget: ProjectBudget,
        burnRate: Decimal
    ) async throws -> BudgetForecast
}

// MARK: - Supporting Types

/// Script format options
public enum ScriptFormat: String, Sendable {
    case fdx = "Final Draft"
    case fountain = "Fountain"
    case plainText = "Plain Text"
    case pdf = "PDF"
}

/// Production requirements extracted from scene analysis
public struct ProductionRequirements: Sendable {
    public var requiredProps: [String]
    public var requiredLocations: [String]
    public var requiredCast: [String]
    public var requiredCrew: [String]
    public var requiredEquipment: [String]
    public var specialRequirements: [String]
    public var estimatedDuration: TimeInterval

    public init(
        requiredProps: [String] = [],
        requiredLocations: [String] = [],
        requiredCast: [String] = [],
        requiredCrew: [String] = [],
        requiredEquipment: [String] = [],
        specialRequirements: [String] = [],
        estimatedDuration: TimeInterval = 0
    ) {
        self.requiredProps = requiredProps
        self.requiredLocations = requiredLocations
        self.requiredCast = requiredCast
        self.requiredCrew = requiredCrew
        self.requiredEquipment = requiredEquipment
        self.specialRequirements = specialRequirements
        self.estimatedDuration = estimatedDuration
    }
}

/// Comprehensive breakdown report
public struct BreakdownReport: Sendable {
    public var totalScenes: Int
    public var totalPages: Double
    public var estimatedDuration: TimeInterval
    public var characterBreakdown: [String: Int] // Character: Scene count
    public var locationBreakdown: [String: Int] // Location: Scene count
    public var propList: [String]
    public var costEstimate: Decimal?

    public init(
        totalScenes: Int = 0,
        totalPages: Double = 0,
        estimatedDuration: TimeInterval = 0,
        characterBreakdown: [String: Int] = [:],
        locationBreakdown: [String: Int] = [:],
        propList: [String] = [],
        costEstimate: Decimal? = nil
    ) {
        self.totalScenes = totalScenes
        self.totalPages = totalPages
        self.estimatedDuration = estimatedDuration
        self.characterBreakdown = characterBreakdown
        self.locationBreakdown = locationBreakdown
        self.propList = propList
        self.costEstimate = costEstimate
    }
}

/// Scheduling constraints
public struct SchedulingConstraints: Sendable {
    public var startDate: Date?
    public var endDate: Date?
    public var actorAvailability: [String: [Date]]
    public var locationAvailability: [String: [Date]]
    public var shootingDaysPerWeek: Int
    public var maxScenesPerDay: Int
    public var preferGroupByLocation: Bool

    public init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        actorAvailability: [String: [Date]] = [:],
        locationAvailability: [String: [Date]] = [:],
        shootingDaysPerWeek: Int = 5,
        maxScenesPerDay: Int = 10,
        preferGroupByLocation: Bool = true
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.actorAvailability = actorAvailability
        self.locationAvailability = locationAvailability
        self.shootingDaysPerWeek = shootingDaysPerWeek
        self.maxScenesPerDay = maxScenesPerDay
        self.preferGroupByLocation = preferGroupByLocation
    }
}

/// Scheduling conflict
public struct SchedulingConflict: Sendable {
    public var type: ConflictType
    public var description: String
    public var affectedScheduleItems: [String] // Schedule item IDs
    public var severity: ConflictSeverity

    public init(
        type: ConflictType,
        description: String,
        affectedScheduleItems: [String] = [],
        severity: ConflictSeverity = .medium
    ) {
        self.type = type
        self.description = description
        self.affectedScheduleItems = affectedScheduleItems
        self.severity = severity
    }
}

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

/// Budget report
public struct BudgetReport: Sendable {
    public var summary: String
    public var categoryBreakdown: [String: Decimal]
    public var totalAllocated: Decimal
    public var totalSpent: Decimal
    public var totalRemaining: Decimal
    public var alerts: [String]

    public init(
        summary: String = "",
        categoryBreakdown: [String: Decimal] = [:],
        totalAllocated: Decimal = 0,
        totalSpent: Decimal = 0,
        totalRemaining: Decimal = 0,
        alerts: [String] = []
    ) {
        self.summary = summary
        self.categoryBreakdown = categoryBreakdown
        self.totalAllocated = totalAllocated
        self.totalSpent = totalSpent
        self.totalRemaining = totalRemaining
        self.alerts = alerts
    }
}

/// Budget forecast
public struct BudgetForecast: Sendable {
    public var projectedTotalCost: Decimal
    public var projectedOverrun: Decimal
    public var daysUntilBudgetExhausted: Int?
    public var recommendations: [String]

    public init(
        projectedTotalCost: Decimal = 0,
        projectedOverrun: Decimal = 0,
        daysUntilBudgetExhausted: Int? = nil,
        recommendations: [String] = []
    ) {
        self.projectedTotalCost = projectedTotalCost
        self.projectedOverrun = projectedOverrun
        self.daysUntilBudgetExhausted = daysUntilBudgetExhausted
        self.recommendations = recommendations
    }
}
