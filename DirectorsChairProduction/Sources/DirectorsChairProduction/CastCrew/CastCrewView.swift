// DirectorsChairProduction/Sources/DirectorsChairProduction/CastCrew/CastCrewView.swift
//
// Cast & Crew Management View
// Comprehensive view for managing cast members, crew members, teams, and equipment.
// Provides tabbed interface for each resource type with full CRUD operations.

import SwiftUI
import DirectorsChairCore

// MARK: - Constants

public enum CastRoleType: String, CaseIterable {
    case principal = "Principal"
    case supporting = "Supporting"
    case background = "Background"
    case extra = "Extra"
    case stuntDouble = "Stunt Double"
}

public enum UnionStatus: String, CaseIterable {
    case sagAftra = "SAG-AFTRA"
    case nonUnion = "Non-Union"
    case equity = "Equity"
}

public enum CrewDepartment: String, CaseIterable {
    case production = "Production"
    case camera = "Camera"
    case lighting = "Lighting"
    case sound = "Sound"
    case art = "Art"
    case wardrobe = "Wardrobe"
    case makeup = "Makeup"
    case stunts = "Stunts"
    case locations = "Locations"
    case post = "Post"
    case vfx = "VFX"
}

public enum EmploymentType: String, CaseIterable {
    case staff = "Staff"
    case freelance = "Freelance"
    case intern = "Intern"
    case volunteer = "Volunteer"
}

public enum EquipmentCategory: String, CaseIterable {
    case camera = "Camera"
    case lighting = "Lighting"
    case sound = "Sound"
    case grip = "Grip"
    case electric = "Electric"
    case post = "Post"
    case other = "Other"
}

// MARK: - Cast Crew Tab

public enum CastCrewTab: String, CaseIterable {
    case cast = "Cast"
    case crew = "Crew"
    case teams = "Teams"
    case equipment = "Equipment"
}

// MARK: - Cast Crew View

public struct CastCrewView: View {
    @ObservedObject var viewModel: CastCrewViewModel

    @State private var selectedTab: CastCrewTab = .cast
    @State private var searchText = ""
    @State private var departmentFilter: String = "All Departments"
    @State private var categoryFilter: String = "All Categories"

    // Selection states
    @State private var selectedCastMember: CastMember?
    @State private var selectedCrewMember: CrewMember?
    @State private var selectedTeam: Team?
    @State private var selectedEquipment: EquipmentItem?

    // Sheet states
    @State private var showingAddCastSheet = false
    @State private var showingEditCastSheet = false
    @State private var showingAddCrewSheet = false
    @State private var showingEditCrewSheet = false
    @State private var showingAddTeamSheet = false
    @State private var showingEditTeamSheet = false
    @State private var showingAddEquipmentSheet = false
    @State private var showingEditEquipmentSheet = false

    public init(viewModel: CastCrewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            castCrewToolbar

            Divider()

            // Tab View
            TabView(selection: $selectedTab) {
                castTab
                    .tabItem { Label("Cast", systemImage: "person.3") }
                    .tag(CastCrewTab.cast)

                crewTab
                    .tabItem { Label("Crew", systemImage: "person.2.badge.gearshape") }
                    .tag(CastCrewTab.crew)

                teamsTab
                    .tabItem { Label("Teams", systemImage: "rectangle.3.group") }
                    .tag(CastCrewTab.teams)

                equipmentTab
                    .tabItem { Label("Equipment", systemImage: "camera.metering.matrix") }
                    .tag(CastCrewTab.equipment)
            }
        }
        // Cast Sheets
        .sheet(isPresented: $showingAddCastSheet) {
            CastMemberEditorSheet(viewModel: viewModel, castMember: nil)
        }
        .sheet(isPresented: $showingEditCastSheet) {
            if let cast = selectedCastMember {
                CastMemberEditorSheet(viewModel: viewModel, castMember: cast)
            }
        }
        // Crew Sheets
        .sheet(isPresented: $showingAddCrewSheet) {
            CrewMemberEditorSheet(viewModel: viewModel, crewMember: nil)
        }
        .sheet(isPresented: $showingEditCrewSheet) {
            if let crew = selectedCrewMember {
                CrewMemberEditorSheet(viewModel: viewModel, crewMember: crew)
            }
        }
        // Team Sheets
        .sheet(isPresented: $showingAddTeamSheet) {
            TeamEditorSheet(viewModel: viewModel, team: nil)
        }
        .sheet(isPresented: $showingEditTeamSheet) {
            if let team = selectedTeam {
                TeamEditorSheet(viewModel: viewModel, team: team)
            }
        }
        // Equipment Sheets
        .sheet(isPresented: $showingAddEquipmentSheet) {
            EquipmentEditorSheet(viewModel: viewModel, equipment: nil)
        }
        .sheet(isPresented: $showingEditEquipmentSheet) {
            if let equipment = selectedEquipment {
                EquipmentEditorSheet(viewModel: viewModel, equipment: equipment)
            }
        }
    }

    // MARK: - Toolbar

    private var castCrewToolbar: some View {
        HStack(spacing: 12) {
            Button(action: addCurrentItem) {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Button(action: editCurrentItem) {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
            .disabled(!hasSelection)

            Button(action: deleteCurrentItem) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(!hasSelection)

            Divider().frame(height: 20)

            Button(action: exportList) {
                Label("Export", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 150)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .padding()
    }

    // MARK: - Cast Tab

    private var castTab: some View {
        VStack(spacing: 0) {
            // Stats Panel
            castStatsPanel

            Divider()

            // Cast Table
            List(filteredCastMembers, selection: $selectedCastMember) { cast in
                CastMemberRow(cast: cast)
                    .tag(cast)
                    .onTapGesture(count: 2) {
                        selectedCastMember = cast
                        showingEditCastSheet = true
                    }
            }

            // Action Buttons
            HStack {
                Button("Add Cast Member") {
                    showingAddCastSheet = true
                }

                Button("Edit Selected") {
                    showingEditCastSheet = true
                }
                .disabled(selectedCastMember == nil)

                Button("Delete Selected") {
                    if let cast = selectedCastMember {
                        viewModel.removeCastMember(cast)
                        selectedCastMember = nil
                    }
                }
                .disabled(selectedCastMember == nil)

                Spacer()
            }
            .padding()
        }
    }

    private var castStatsPanel: some View {
        HStack {
            let total = viewModel.castMembers.count
            let principal = viewModel.castMembers.filter { $0.roleType == "Principal" }.count
            let supporting = viewModel.castMembers.filter { $0.roleType == "Supporting" }.count

            Text("Total Cast: \(total)")
            Text("|")
            Text("Principal: \(principal)")
            Text("|")
            Text("Supporting: \(supporting)")

            Spacer()
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Crew Tab

    private var crewTab: some View {
        VStack(spacing: 0) {
            // Stats Panel
            crewStatsPanel

            // Department Filter
            HStack {
                Text("Filter by Department:")
                    .foregroundColor(.secondary)

                Picker("Department", selection: $departmentFilter) {
                    Text("All Departments").tag("All Departments")
                    ForEach(CrewDepartment.allCases, id: \.self) { dept in
                        Text(dept.rawValue).tag(dept.rawValue)
                    }
                }
                .frame(width: 180)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Divider()

            // Crew Table
            List(filteredCrewMembers, selection: $selectedCrewMember) { crew in
                CrewMemberRow(crew: crew)
                    .tag(crew)
                    .onTapGesture(count: 2) {
                        selectedCrewMember = crew
                        showingEditCrewSheet = true
                    }
            }

            // Action Buttons
            HStack {
                Button("Add Crew Member") {
                    showingAddCrewSheet = true
                }

                Button("Edit Selected") {
                    showingEditCrewSheet = true
                }
                .disabled(selectedCrewMember == nil)

                Button("Delete Selected") {
                    if let crew = selectedCrewMember {
                        viewModel.removeCrewMember(crew)
                        selectedCrewMember = nil
                    }
                }
                .disabled(selectedCrewMember == nil)

                Spacer()
            }
            .padding()
        }
    }

    private var crewStatsPanel: some View {
        HStack {
            let total = viewModel.crewMembers.count
            let departments = Set(viewModel.crewMembers.map { $0.department }).count

            Text("Total Crew: \(total)")
            Text("|")
            Text("Departments: \(departments)")

            Spacer()
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Teams Tab

    private var teamsTab: some View {
        VStack(spacing: 0) {
            // Stats Panel
            HStack {
                Text("Total Teams: \(viewModel.teams.count)")
                Spacer()
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Teams Table
            List(filteredTeams, selection: $selectedTeam) { team in
                TeamRow(team: team, viewModel: viewModel)
                    .tag(team)
                    .onTapGesture(count: 2) {
                        selectedTeam = team
                        showingEditTeamSheet = true
                    }
            }

            // Action Buttons
            HStack {
                Button("Add Team") {
                    showingAddTeamSheet = true
                }

                Button("Edit Selected") {
                    showingEditTeamSheet = true
                }
                .disabled(selectedTeam == nil)

                Button("Delete Selected") {
                    if let team = selectedTeam {
                        viewModel.removeTeam(team)
                        selectedTeam = nil
                    }
                }
                .disabled(selectedTeam == nil)

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Equipment Tab

    private var equipmentTab: some View {
        VStack(spacing: 0) {
            // Stats Panel
            equipmentStatsPanel

            // Category Filter
            HStack {
                Text("Filter by Category:")
                    .foregroundColor(.secondary)

                Picker("Category", selection: $categoryFilter) {
                    Text("All Categories").tag("All Categories")
                    ForEach(EquipmentCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat.rawValue)
                    }
                }
                .frame(width: 180)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Divider()

            // Equipment Table
            List(filteredEquipment, selection: $selectedEquipment) { equipment in
                EquipmentRow(equipment: equipment)
                    .tag(equipment)
                    .onTapGesture(count: 2) {
                        selectedEquipment = equipment
                        showingEditEquipmentSheet = true
                    }
            }

            // Action Buttons
            HStack {
                Button("Add Equipment") {
                    showingAddEquipmentSheet = true
                }

                Button("Edit Selected") {
                    showingEditEquipmentSheet = true
                }
                .disabled(selectedEquipment == nil)

                Button("Delete Selected") {
                    if let equipment = selectedEquipment {
                        viewModel.removeEquipment(equipment)
                        selectedEquipment = nil
                    }
                }
                .disabled(selectedEquipment == nil)

                Spacer()
            }
            .padding()
        }
    }

    private var equipmentStatsPanel: some View {
        HStack {
            let total = viewModel.equipment.count
            let totalOwned = viewModel.equipment.reduce(0) { $0 + $1.quantityOwned }

            Text("Total Equipment Items: \(total)")
            Text("|")
            Text("Total Units Owned: \(totalOwned)")

            Spacer()
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Computed Properties

    private var hasSelection: Bool {
        switch selectedTab {
        case .cast: return selectedCastMember != nil
        case .crew: return selectedCrewMember != nil
        case .teams: return selectedTeam != nil
        case .equipment: return selectedEquipment != nil
        }
    }

    private var filteredCastMembers: [CastMember] {
        viewModel.castMembers.filter { cast in
            searchText.isEmpty ||
            cast.actorName.localizedCaseInsensitiveContains(searchText) ||
            cast.characterName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredCrewMembers: [CrewMember] {
        viewModel.crewMembers.filter { crew in
            let matchesSearch = searchText.isEmpty ||
                crew.name.localizedCaseInsensitiveContains(searchText) ||
                crew.role.localizedCaseInsensitiveContains(searchText)
            let matchesDepartment = departmentFilter == "All Departments" ||
                crew.department == departmentFilter
            return matchesSearch && matchesDepartment
        }
    }

    private var filteredTeams: [Team] {
        viewModel.teams.filter { team in
            searchText.isEmpty ||
            team.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredEquipment: [EquipmentItem] {
        viewModel.equipment.filter { equipment in
            let matchesSearch = searchText.isEmpty ||
                equipment.name.localizedCaseInsensitiveContains(searchText) ||
                equipment.manufacturer.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = categoryFilter == "All Categories" ||
                equipment.category == categoryFilter
            return matchesSearch && matchesCategory
        }
    }

    // MARK: - Actions

    private func addCurrentItem() {
        switch selectedTab {
        case .cast: showingAddCastSheet = true
        case .crew: showingAddCrewSheet = true
        case .teams: showingAddTeamSheet = true
        case .equipment: showingAddEquipmentSheet = true
        }
    }

    private func editCurrentItem() {
        switch selectedTab {
        case .cast: showingEditCastSheet = true
        case .crew: showingEditCrewSheet = true
        case .teams: showingEditTeamSheet = true
        case .equipment: showingEditEquipmentSheet = true
        }
    }

    private func deleteCurrentItem() {
        switch selectedTab {
        case .cast:
            if let cast = selectedCastMember {
                viewModel.removeCastMember(cast)
                selectedCastMember = nil
            }
        case .crew:
            if let crew = selectedCrewMember {
                viewModel.removeCrewMember(crew)
                selectedCrewMember = nil
            }
        case .teams:
            if let team = selectedTeam {
                viewModel.removeTeam(team)
                selectedTeam = nil
            }
        case .equipment:
            if let equipment = selectedEquipment {
                viewModel.removeEquipment(equipment)
                selectedEquipment = nil
            }
        }
    }

    private func exportList() {
        // TODO: Export current list to PDF
    }
}

// MARK: - Cast Member Row

struct CastMemberRow: View {
    let cast: CastMember

    var body: some View {
        HStack(spacing: 12) {
            // Photo placeholder
            ZStack {
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 40, height: 40)

                Text(initials(from: cast.actorName))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cast.actorName)
                    .font(.headline)
                Text("as \(cast.characterName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(cast.roleType)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(roleTypeColor.opacity(0.2))
                .cornerRadius(4)

            Text(cast.unionStatus)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("$\(String(format: "%.0f", cast.dailyRate))/day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var roleTypeColor: Color {
        switch cast.roleType {
        case "Principal": return .blue
        case "Supporting": return .green
        case "Background": return .yellow
        default: return .gray
        }
    }

    private func initials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.uppercased()
    }
}

// MARK: - Crew Member Row

struct CrewMemberRow: View {
    let crew: CrewMember

    var body: some View {
        HStack(spacing: 12) {
            // Photo placeholder
            ZStack {
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 40, height: 40)

                Text(initials(from: crew.name))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(crew.name)
                    .font(.headline)
                Text(crew.role)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(crew.department)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(4)

            Text(crew.employmentType)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("$\(String(format: "%.0f", crew.dailyRate))/day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func initials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.uppercased()
    }
}

// MARK: - Team Row

struct TeamRow: View {
    let team: Team
    let viewModel: CastCrewViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.headline)
                Text(team.teamType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(team.castMemberIds.count) Cast")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(team.crewMemberIds.count) Crew")
                .font(.caption)
                .foregroundColor(.secondary)

            // Team Lead
            if let leadId = team.teamLeadId,
               let lead = viewModel.crewMembers.first(where: { $0.id == leadId }) {
                Text("Lead: \(lead.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No Lead")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Equipment Row

struct EquipmentRow: View {
    let equipment: EquipmentItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(equipment.name)
                    .font(.headline)
                if !equipment.manufacturer.isEmpty {
                    Text(equipment.manufacturer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(equipment.category)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)

            Text("Owned: \(equipment.quantityOwned)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Available: \(equipment.quantityAvailable)")
                .font(.caption)
                .foregroundColor(.secondary)

            if equipment.isRental {
                Text("Rental")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.3))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cast Member Editor Sheet

struct CastMemberEditorSheet: View {
    @ObservedObject var viewModel: CastCrewViewModel
    let castMember: CastMember?

    @Environment(\.dismiss) private var dismiss

    @State private var actorName = ""
    @State private var characterName = ""
    @State private var roleType = "Principal"
    @State private var unionStatus = "Non-Union"
    @State private var email = ""
    @State private var phone = ""
    @State private var dailyRate: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(castMember == nil ? "Add Cast Member" : "Edit Cast Member")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(actorName.isEmpty || characterName.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Basic Information") {
                    TextField("Actor Name", text: $actorName)
                    TextField("Character Name", text: $characterName)

                    Picker("Role Type", selection: $roleType) {
                        ForEach(CastRoleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }

                    Picker("Union Status", selection: $unionStatus) {
                        ForEach(UnionStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status.rawValue)
                        }
                    }
                }

                Section("Contact Information") {
                    TextField("Email", text: $email)
                    TextField("Phone", text: $phone)
                }

                Section("Payment") {
                    HStack {
                        Text("Daily Rate")
                        Spacer()
                        TextField("Rate", value: $dailyRate, format: .currency(code: "USD"))
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear {
            if let cast = castMember {
                actorName = cast.actorName
                characterName = cast.characterName
                roleType = cast.roleType
                unionStatus = cast.unionStatus
                email = cast.email
                phone = cast.phone
                dailyRate = cast.dailyRate
            }
        }
    }

    private func save() {
        if var existing = castMember {
            existing.actorName = actorName
            existing.characterName = characterName
            existing.roleType = roleType
            existing.unionStatus = unionStatus
            existing.email = email
            existing.phone = phone
            existing.dailyRate = dailyRate
            viewModel.updateCastMember(existing)
        } else {
            let newCast = CastMember(
                actorName: actorName,
                characterName: characterName,
                roleType: roleType,
                unionStatus: unionStatus,
                dailyRate: dailyRate
            )
            viewModel.addCastMember(newCast)
        }
        dismiss()
    }
}

// MARK: - Crew Member Editor Sheet

struct CrewMemberEditorSheet: View {
    @ObservedObject var viewModel: CastCrewViewModel
    let crewMember: CrewMember?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var role = ""
    @State private var department = "Production"
    @State private var employmentType = "Freelance"
    @State private var email = ""
    @State private var phone = ""
    @State private var dailyRate: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(crewMember == nil ? "Add Crew Member" : "Edit Crew Member")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || role.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Role", text: $role)

                    Picker("Department", selection: $department) {
                        ForEach(CrewDepartment.allCases, id: \.self) { dept in
                            Text(dept.rawValue).tag(dept.rawValue)
                        }
                    }

                    Picker("Employment Type", selection: $employmentType) {
                        ForEach(EmploymentType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                }

                Section("Contact Information") {
                    TextField("Email", text: $email)
                    TextField("Phone", text: $phone)
                }

                Section("Payment") {
                    HStack {
                        Text("Daily Rate")
                        Spacer()
                        TextField("Rate", value: $dailyRate, format: .currency(code: "USD"))
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear {
            if let crew = crewMember {
                name = crew.name
                role = crew.role
                department = crew.department
                employmentType = crew.employmentType
                email = crew.email
                phone = crew.phone
                dailyRate = crew.dailyRate
            }
        }
    }

    private func save() {
        if var existing = crewMember {
            existing.name = name
            existing.role = role
            existing.department = department
            existing.employmentType = employmentType
            existing.email = email
            existing.phone = phone
            existing.dailyRate = dailyRate
            viewModel.updateCrewMember(existing)
        } else {
            let newCrew = CrewMember(
                name: name,
                role: role,
                department: department,
                employmentType: employmentType,
                dailyRate: dailyRate
            )
            viewModel.addCrewMember(newCrew)
        }
        dismiss()
    }
}

// MARK: - Team Editor Sheet

struct TeamEditorSheet: View {
    @ObservedObject var viewModel: CastCrewViewModel
    let team: Team?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var teamType = "Shooting Unit"
    @State private var description = ""
    @State private var selectedCastIds: Set<String> = []
    @State private var selectedCrewIds: Set<String> = []
    @State private var teamLeadId: String?

    private let teamTypes = ["Shooting Unit", "Department", "Special Team"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(team == nil ? "Add Team" : "Edit Team")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Team Information") {
                    TextField("Team Name", text: $name)

                    Picker("Team Type", selection: $teamType) {
                        ForEach(teamTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    TextField("Description", text: $description)
                }

                Section("Team Lead") {
                    Picker("Team Lead", selection: $teamLeadId) {
                        Text("None").tag(nil as String?)
                        ForEach(viewModel.crewMembers) { crew in
                            Text(crew.name).tag(crew.id as String?)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            if let team = team {
                name = team.name
                teamType = team.teamType
                description = team.description
                selectedCastIds = Set(team.castMemberIds)
                selectedCrewIds = Set(team.crewMemberIds)
                teamLeadId = team.teamLeadId
            }
        }
    }

    private func save() {
        if var existing = team {
            existing.name = name
            existing.teamType = teamType
            existing.description = description
            existing.castMemberIds = Array(selectedCastIds)
            existing.crewMemberIds = Array(selectedCrewIds)
            existing.teamLeadId = teamLeadId
            viewModel.updateTeam(existing)
        } else {
            let newTeam = Team(
                name: name,
                description: description,
                teamType: teamType,
                castMemberIds: Array(selectedCastIds),
                crewMemberIds: Array(selectedCrewIds),
                teamLeadId: teamLeadId
            )
            viewModel.addTeam(newTeam)
        }
        dismiss()
    }
}

// MARK: - Equipment Editor Sheet

struct EquipmentEditorSheet: View {
    @ObservedObject var viewModel: CastCrewViewModel
    let equipment: EquipmentItem?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = "Camera"
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var quantityOwned = 1
    @State private var quantityAvailable = 1
    @State private var isRental = false
    @State private var rentalDailyRate: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(equipment == nil ? "Add Equipment" : "Edit Equipment")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Equipment Information") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(EquipmentCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat.rawValue)
                        }
                    }

                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $model)
                }

                Section("Quantity") {
                    Stepper("Owned: \(quantityOwned)", value: $quantityOwned, in: 0...100)
                    Stepper("Available: \(quantityAvailable)", value: $quantityAvailable, in: 0...quantityOwned)
                }

                Section("Rental") {
                    Toggle("Is Rental", isOn: $isRental)

                    if isRental {
                        HStack {
                            Text("Daily Rate")
                            Spacer()
                            TextField("Rate", value: $rentalDailyRate, format: .currency(code: "USD"))
                                .frame(width: 120)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear {
            if let equipment = equipment {
                name = equipment.name
                category = equipment.category
                manufacturer = equipment.manufacturer
                model = equipment.model
                quantityOwned = equipment.quantityOwned
                quantityAvailable = equipment.quantityAvailable
                isRental = equipment.isRental
                rentalDailyRate = equipment.rentalDailyRate
            }
        }
    }

    private func save() {
        if var existing = equipment {
            existing.name = name
            existing.category = category
            existing.manufacturer = manufacturer
            existing.model = model
            existing.quantityOwned = quantityOwned
            existing.quantityAvailable = quantityAvailable
            existing.isRental = isRental
            existing.rentalDailyRate = rentalDailyRate
            viewModel.updateEquipment(existing)
        } else {
            let newEquipment = EquipmentItem(
                name: name,
                category: category,
                manufacturer: manufacturer,
                model: model,
                quantityOwned: quantityOwned,
                quantityAvailable: quantityAvailable,
                isRental: isRental,
                rentalDailyRate: rentalDailyRate
            )
            viewModel.addEquipment(newEquipment)
        }
        dismiss()
    }
}
