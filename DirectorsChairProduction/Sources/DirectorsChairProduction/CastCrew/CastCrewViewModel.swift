// DirectorsChairProduction/Sources/DirectorsChairProduction/CastCrew/CastCrewViewModel.swift
//
// Cast & Crew ViewModel - Data Management
// Manages cast members, crew members, teams, and equipment.

import SwiftUI
import DirectorsChairCore

// MARK: - Cast Crew ViewModel

@MainActor
public class CastCrewViewModel: ObservableObject {
    @Published public var castMembers: [CastMember] = []
    @Published public var crewMembers: [CrewMember] = []
    @Published public var teams: [Team] = []
    @Published public var equipment: [EquipmentItem] = []
    @Published public var isLoading = false

    // Character names from project (for dropdown in cast editor)
    @Published public var characterNames: [String] = []

    // Project base path for resolving photo file paths
    public var projectBasePath: URL?

    // Schedule items for scene/day cross-reference
    @Published public var scheduleItems: [ScheduleItem] = []

    // Callbacks for data persistence
    public var onCastChanged: (([CastMember]) -> Void)?
    public var onCrewChanged: (([CrewMember]) -> Void)?
    public var onTeamsChanged: (([Team]) -> Void)?
    public var onEquipmentChanged: (([EquipmentItem]) -> Void)?

    public init(
        castMembers: [CastMember] = [],
        crewMembers: [CrewMember] = [],
        teams: [Team] = [],
        equipment: [EquipmentItem] = []
    ) {
        self.castMembers = castMembers
        self.crewMembers = crewMembers
        self.teams = teams
        self.equipment = equipment
    }

    // MARK: - Cast CRUD

    public func addCastMember(_ cast: CastMember) {
        castMembers.append(cast)
        onCastChanged?(castMembers)
    }

    public func updateCastMember(_ cast: CastMember) {
        if let index = castMembers.firstIndex(where: { $0.id == cast.id }) {
            castMembers[index] = cast
            onCastChanged?(castMembers)
        }
    }

    public func removeCastMember(_ cast: CastMember) {
        castMembers.removeAll { $0.id == cast.id }
        // Remove from teams as well
        for i in teams.indices {
            teams[i].castMemberIds.removeAll { $0 == cast.id }
        }
        onCastChanged?(castMembers)
        onTeamsChanged?(teams)
    }

    public func setCastMembers(_ members: [CastMember]) {
        castMembers = members
    }

    // MARK: - Crew CRUD

    public func addCrewMember(_ crew: CrewMember) {
        crewMembers.append(crew)
        onCrewChanged?(crewMembers)
    }

    public func updateCrewMember(_ crew: CrewMember) {
        if let index = crewMembers.firstIndex(where: { $0.id == crew.id }) {
            crewMembers[index] = crew
            onCrewChanged?(crewMembers)
        }
    }

    public func removeCrewMember(_ crew: CrewMember) {
        crewMembers.removeAll { $0.id == crew.id }
        // Remove from teams and update team leads
        for i in teams.indices {
            teams[i].crewMemberIds.removeAll { $0 == crew.id }
            if teams[i].teamLeadId == crew.id {
                teams[i].teamLeadId = nil
            }
        }
        onCrewChanged?(crewMembers)
        onTeamsChanged?(teams)
    }

    public func setCrewMembers(_ members: [CrewMember]) {
        crewMembers = members
    }

    // MARK: - Team CRUD

    public func addTeam(_ team: Team) {
        teams.append(team)
        onTeamsChanged?(teams)
    }

    public func updateTeam(_ team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            onTeamsChanged?(teams)
        }
    }

    public func removeTeam(_ team: Team) {
        teams.removeAll { $0.id == team.id }
        onTeamsChanged?(teams)
    }

    public func setTeams(_ newTeams: [Team]) {
        teams = newTeams
    }

    // MARK: - Equipment CRUD

    public func addEquipment(_ item: EquipmentItem) {
        equipment.append(item)
        onEquipmentChanged?(equipment)
    }

    public func updateEquipment(_ item: EquipmentItem) {
        if let index = equipment.firstIndex(where: { $0.id == item.id }) {
            equipment[index] = item
            onEquipmentChanged?(equipment)
        }
    }

    public func removeEquipment(_ item: EquipmentItem) {
        equipment.removeAll { $0.id == item.id }
        onEquipmentChanged?(equipment)
    }

    public func setEquipment(_ items: [EquipmentItem]) {
        equipment = items
    }

    // MARK: - Statistics

    public var totalCastCount: Int {
        castMembers.count
    }

    public var principalCastCount: Int {
        castMembers.filter { $0.roleType == "Principal" }.count
    }

    public var supportingCastCount: Int {
        castMembers.filter { $0.roleType == "Supporting" }.count
    }

    public var totalCrewCount: Int {
        crewMembers.count
    }

    public var crewByDepartment: [String: Int] {
        Dictionary(grouping: crewMembers, by: { $0.department })
            .mapValues { $0.count }
    }

    public var totalEquipmentCount: Int {
        equipment.count
    }

    public var totalEquipmentUnits: Int {
        equipment.reduce(0) { $0 + $1.quantityOwned }
    }

    public var availableEquipmentUnits: Int {
        equipment.reduce(0) { $0 + $1.quantityAvailable }
    }

    // MARK: - Daily Cost Calculation

    public var dailyCastCost: Double {
        castMembers.reduce(0) { $0 + $1.dailyRate }
    }

    public var dailyCrewCost: Double {
        crewMembers.reduce(0) { $0 + $1.dailyRate }
    }

    public var dailyEquipmentRentalCost: Double {
        equipment.filter { $0.isRental }.reduce(0) { $0 + $1.rentalDailyRate }
    }

    public var totalDailyCost: Double {
        dailyCastCost + dailyCrewCost + dailyEquipmentRentalCost
    }

    // MARK: - Filtering & Queries

    public func castMembers(forRole roleType: String) -> [CastMember] {
        castMembers.filter { $0.roleType == roleType }
    }

    public func crewMembers(inDepartment department: String) -> [CrewMember] {
        crewMembers.filter { $0.department == department }
    }

    public func equipment(inCategory category: String) -> [EquipmentItem] {
        equipment.filter { $0.category == category }
    }

    public func team(withId id: String) -> Team? {
        teams.first { $0.id == id }
    }

    public func castMember(withId id: String) -> CastMember? {
        castMembers.first { $0.id == id }
    }

    public func crewMember(withId id: String) -> CrewMember? {
        crewMembers.first { $0.id == id }
    }

    public func equipmentItem(withId id: String) -> EquipmentItem? {
        equipment.first { $0.id == id }
    }

    // MARK: - Team Member Resolution

    public func castMembers(forTeam team: Team) -> [CastMember] {
        castMembers.filter { team.castMemberIds.contains($0.id) }
    }

    public func crewMembers(forTeam team: Team) -> [CrewMember] {
        crewMembers.filter { team.crewMemberIds.contains($0.id) }
    }

    public func teamLead(forTeam team: Team) -> CrewMember? {
        guard let leadId = team.teamLeadId else { return nil }
        return crewMembers.first { $0.id == leadId }
    }

    // MARK: - Availability Check

    public func availableEquipment(category: String? = nil) -> [EquipmentItem] {
        var items = equipment.filter { $0.quantityAvailable > 0 }
        if let category = category {
            items = items.filter { $0.category == category }
        }
        return items
    }

    public func checkEquipmentAvailability(itemId: String, quantity: Int) -> Bool {
        guard let item = equipment.first(where: { $0.id == itemId }) else { return false }
        return item.quantityAvailable >= quantity
    }
}
