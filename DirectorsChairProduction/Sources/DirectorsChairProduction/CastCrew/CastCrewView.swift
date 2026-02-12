// DirectorsChairProduction/Sources/DirectorsChairProduction/CastCrew/CastCrewView.swift
//
// Cast & Crew Management View
// Redesigned with chip sub-tabs, styled list rows, ProductionCard containers.

import SwiftUI
import AppKit
import UniformTypeIdentifiers
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
}

// MARK: - Cast Crew View

public struct CastCrewView: View {
    @ObservedObject var viewModel: CastCrewViewModel

    @State private var selectedTab: CastCrewTab = .cast
    @State private var searchText = ""
    @State private var departmentFilter: String = "All Departments"

    // Selection states
    @State private var selectedCastMember: CastMember?
    @State private var selectedCrewMember: CrewMember?
    @State private var selectedTeam: Team?

    // Sheet states
    @State private var showingAddCastSheet = false
    @State private var showingEditCastSheet = false
    @State private var showingAddCrewSheet = false
    @State private var showingEditCrewSheet = false
    @State private var showingAddTeamSheet = false
    @State private var showingEditTeamSheet = false

    public init(viewModel: CastCrewViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Sub-tab chips + search
            HStack(spacing: 8) {
                ProductionChip(icon: "person.3", "Cast", selected: selectedTab == .cast) {
                    selectedTab = .cast
                }
                ProductionChip(icon: "person.2.badge.gearshape", "Crew", selected: selectedTab == .crew) {
                    selectedTab = .crew
                }
                ProductionChip(icon: "rectangle.3.group", "Teams", selected: selectedTab == .teams) {
                    selectedTab = .teams
                }

                Spacer()

                ProductionSearchField(text: $searchText)
                    .frame(width: 200)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            // Tab content
            switch selectedTab {
            case .cast:
                castTab
            case .crew:
                crewTab
            case .teams:
                teamsTab
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
    }

    // MARK: - Cast Tab

    private var castTab: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Left: Cast list in card
                ProductionCard(icon: "person.3", title: "CAST MEMBERS") {
                    VStack(spacing: 10) {
                        // Stats
                        HStack(spacing: 12) {
                            ProductionStatBadge(intValue: viewModel.castMembers.count, label: "Total", color: .blue)
                            ProductionStatBadge(
                                intValue: viewModel.castMembers.filter { $0.roleType == "Principal" }.count,
                                label: "Principal",
                                color: .purple
                            )
                            ProductionStatBadge(
                                intValue: viewModel.castMembers.filter { $0.roleType == "Supporting" }.count,
                                label: "Supporting",
                                color: .green
                            )
                        }

                        // Action buttons
                        HStack(spacing: 6) {
                            ProductionActionButton(icon: "plus", "Add", prominent: true) {
                                showingAddCastSheet = true
                            }
                            ProductionActionButton(icon: "pencil", "Edit", disabled: selectedCastMember == nil) {
                                showingEditCastSheet = true
                            }
                            ProductionActionButton(icon: "trash", "Delete", disabled: selectedCastMember == nil) {
                                if let cast = selectedCastMember {
                                    viewModel.removeCastMember(cast)
                                    selectedCastMember = nil
                                }
                            }
                            Spacer()
                        }

                        // Cast list
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredCastMembers) { cast in
                                    CastMemberRow(cast: cast, isSelected: selectedCastMember?.id == cast.id, projectBasePath: viewModel.projectBasePath)
                                        .onTapGesture {
                                            selectedCastMember = cast
                                        }
                                        .onTapGesture(count: 2) {
                                            selectedCastMember = cast
                                            showingEditCastSheet = true
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Right: Selected cast member detail
                ProductionCard(icon: "person.text.rectangle", title: "DETAILS") {
                    if let cast = selectedCastMember {
                        castDetailView(cast)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        Text("Select a cast member to view details")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    private func castDetailView(_ cast: CastMember) -> some View {
        let matchingSchedule = viewModel.scheduleItems.filter { item in
            item.requiredActors.contains(cast.actorName) || item.requiredActors.contains(cast.characterName)
        }
        let shootDates = Set(matchingSchedule.compactMap { $0.shootDate }.filter { !$0.isEmpty })

        return ScrollView {
            VStack(spacing: 14) {
                // Photo + Name & Contact side by side
                HStack(alignment: .top, spacing: 14) {
                    // Photo
                    if !cast.photoPath.isEmpty, let image = loadImage(path: cast.photoPath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 130, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text(String(cast.actorName.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.accentColor.opacity(0.5))
                        }
                        .frame(width: 130, height: 160)
                    }

                    // Name + Contact + Badges
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(cast.actorName)
                                .font(.system(size: 16, weight: .bold))
                            Text("as \(cast.characterName)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            detailBadge(icon: "star.fill", text: cast.roleType, color: roleColor(cast.roleType))
                            detailBadge(icon: "building.columns.fill", text: cast.unionStatus, color: .blue)
                        }

                        if !cast.email.isEmpty || !cast.phone.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                if !cast.email.isEmpty {
                                    detailInfoRow(icon: "envelope.fill", value: cast.email)
                                }
                                if !cast.phone.isEmpty {
                                    detailInfoRow(icon: "phone.fill", value: cast.phone)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(8)
                        }
                    }
                }

                // Payment + Stats row
                HStack(spacing: 10) {
                    detailStatBox(
                        icon: cast.paymentType == "One Time" ? "banknote.fill" : "dollarsign.circle.fill",
                        value: cast.paymentType == "One Time"
                            ? "$\(String(format: "%.0f", cast.oneTimePayment))"
                            : "$\(String(format: "%.0f", cast.dailyRate))/day",
                        label: cast.paymentType == "One Time" ? "Flat Payment" : "Daily Rate",
                        color: .green
                    )
                    detailStatBox(
                        icon: "film.fill",
                        value: "\(matchingSchedule.count)",
                        label: matchingSchedule.count == 1 ? "Scene" : "Scenes",
                        color: .purple
                    )
                    detailStatBox(
                        icon: "calendar",
                        value: "\(shootDates.count)",
                        label: shootDates.count == 1 ? "Shoot Day" : "Shoot Days",
                        color: .orange
                    )
                }

                // Scenes section
                if !matchingSchedule.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        detailSectionHeader(icon: "film.stack", title: "SCENES & SCHEDULE")
                        VStack(spacing: 4) {
                            ForEach(matchingSchedule, id: \.id) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(scheduleStatusColor(item.status))
                                        .frame(width: 6, height: 6)
                                    Text(item.sceneName)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    if let date = item.shootDate, !date.isEmpty {
                                        Text(formatShortDate(date))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Text(item.status)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(scheduleStatusColor(item.status).opacity(0.15))
                                        .foregroundColor(scheduleStatusColor(item.status))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                // Notes
                if !cast.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        detailSectionHeader(icon: "note.text", title: "NOTES")
                        Text(cast.notes)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Detail View Helpers

    private func detailBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }

    private func detailStatBox(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(nsColor: .quaternarySystemFill))
        .cornerRadius(8)
    }

    private func detailSectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1.2)
        }
    }

    private func detailInfoRow(icon: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
                .frame(width: 16)
            Text(value)
                .font(.system(size: 11))
            Spacer()
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "Principal": return .blue
        case "Supporting": return .green
        case "Background": return .yellow
        case "Extra": return .orange
        case "Stunt Double": return .red
        default: return .gray
        }
    }

    private func scheduleStatusColor(_ status: String) -> Color {
        switch status {
        case "Complete", "Shot": return .green
        case "In Progress": return .blue
        case "Confirmed": return .purple
        case "Planned": return .orange
        case "Cancelled": return .red
        case "Postponed": return .yellow
        default: return .gray
        }
    }

    private func formatShortDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }

    // MARK: - Crew Tab

    private var crewTab: some View {
        VStack(spacing: 0) {
            // Department filter chips
            HStack(spacing: 6) {
                ProductionSectionHeader(icon: "building.2", title: "DEPARTMENT")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ProductionChip("All", selected: departmentFilter == "All Departments") {
                            departmentFilter = "All Departments"
                        }
                        ForEach(CrewDepartment.allCases, id: \.self) { dept in
                            ProductionChip(dept.rawValue, selected: departmentFilter == dept.rawValue) {
                                departmentFilter = dept.rawValue
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            HStack(alignment: .top, spacing: 16) {
                // Crew list
                ProductionCard(icon: "person.2.badge.gearshape", title: "CREW MEMBERS") {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            ProductionStatBadge(intValue: viewModel.crewMembers.count, label: "Total", color: .blue)
                            ProductionStatBadge(
                                intValue: Set(viewModel.crewMembers.map { $0.department }).count,
                                label: "Departments",
                                color: .purple
                            )
                        }

                        HStack(spacing: 6) {
                            ProductionActionButton(icon: "plus", "Add", prominent: true) {
                                showingAddCrewSheet = true
                            }
                            ProductionActionButton(icon: "pencil", "Edit", disabled: selectedCrewMember == nil) {
                                showingEditCrewSheet = true
                            }
                            ProductionActionButton(icon: "trash", "Delete", disabled: selectedCrewMember == nil) {
                                if let crew = selectedCrewMember {
                                    viewModel.removeCrewMember(crew)
                                    selectedCrewMember = nil
                                }
                            }
                            Spacer()
                        }

                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredCrewMembers) { crew in
                                    CrewMemberRow(crew: crew, isSelected: selectedCrewMember?.id == crew.id, projectBasePath: viewModel.projectBasePath)
                                        .onTapGesture {
                                            selectedCrewMember = crew
                                        }
                                        .onTapGesture(count: 2) {
                                            selectedCrewMember = crew
                                            showingEditCrewSheet = true
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Crew detail
                ProductionCard(icon: "person.text.rectangle", title: "DETAILS") {
                    if let crew = selectedCrewMember {
                        crewDetailView(crew)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        Text("Select a crew member to view details")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    private func crewDetailView(_ crew: CrewMember) -> some View {
        let matchingSchedule = viewModel.scheduleItems.filter { item in
            item.requiredCrew.contains(crew.name) || item.requiredCrew.contains(crew.role)
        }
        let shootDates = Set(matchingSchedule.compactMap { $0.shootDate }.filter { !$0.isEmpty })

        return ScrollView {
            VStack(spacing: 14) {
                // Photo + Name & Contact side by side
                HStack(alignment: .top, spacing: 14) {
                    // Photo
                    if !crew.photoPath.isEmpty, let image = loadImage(path: crew.photoPath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 130, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text(String(crew.name.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.purple.opacity(0.5))
                        }
                        .frame(width: 130, height: 160)
                    }

                    // Name + Contact + Badges
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(crew.name)
                                .font(.system(size: 16, weight: .bold))
                            Text(crew.role)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            detailBadge(icon: "building.2.fill", text: crew.department, color: .purple)
                            detailBadge(icon: "briefcase.fill", text: crew.employmentType, color: .blue)
                        }

                        if !crew.email.isEmpty || !crew.phone.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                if !crew.email.isEmpty {
                                    detailInfoRow(icon: "envelope.fill", value: crew.email)
                                }
                                if !crew.phone.isEmpty {
                                    detailInfoRow(icon: "phone.fill", value: crew.phone)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(8)
                        }
                    }
                }

                // Payment + Stats row
                HStack(spacing: 10) {
                    detailStatBox(
                        icon: crew.paymentType == "One Time" ? "banknote.fill" : "dollarsign.circle.fill",
                        value: crew.paymentType == "One Time"
                            ? "$\(String(format: "%.0f", crew.oneTimePayment))"
                            : "$\(String(format: "%.0f", crew.dailyRate))/day",
                        label: crew.paymentType == "One Time" ? "Flat Payment" : "Daily Rate",
                        color: .green
                    )
                    if crew.kitFee > 0 {
                        detailStatBox(
                            icon: "suitcase.fill",
                            value: "$\(String(format: "%.0f", crew.kitFee))",
                            label: "Kit Fee",
                            color: .blue
                        )
                    }
                    detailStatBox(
                        icon: "calendar",
                        value: "\(shootDates.isEmpty ? viewModel.scheduleItems.isEmpty ? 0 : Set(viewModel.scheduleItems.compactMap { $0.shootDate }.filter { !$0.isEmpty }).count : shootDates.count)",
                        label: "Shoot Days",
                        color: .orange
                    )
                }

                // Scenes section
                if !matchingSchedule.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        detailSectionHeader(icon: "film.stack", title: "SCENES & SCHEDULE")
                        VStack(spacing: 4) {
                            ForEach(matchingSchedule, id: \.id) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(scheduleStatusColor(item.status))
                                        .frame(width: 6, height: 6)
                                    Text(item.sceneName)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    if let date = item.shootDate, !date.isEmpty {
                                        Text(formatShortDate(date))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Text(item.status)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(scheduleStatusColor(item.status).opacity(0.15))
                                        .foregroundColor(scheduleStatusColor(item.status))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                // Notes
                if !crew.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        detailSectionHeader(icon: "note.text", title: "NOTES")
                        Text(crew.notes)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Teams Tab

    private var teamsTab: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                ProductionCard(icon: "rectangle.3.group", title: "TEAMS") {
                    VStack(spacing: 10) {
                        ProductionStatBadge(intValue: viewModel.teams.count, label: "Total Teams", color: .blue)

                        HStack(spacing: 6) {
                            ProductionActionButton(icon: "plus", "Add", prominent: true) {
                                showingAddTeamSheet = true
                            }
                            ProductionActionButton(icon: "pencil", "Edit", disabled: selectedTeam == nil) {
                                showingEditTeamSheet = true
                            }
                            ProductionActionButton(icon: "trash", "Delete", disabled: selectedTeam == nil) {
                                if let team = selectedTeam {
                                    viewModel.removeTeam(team)
                                    selectedTeam = nil
                                }
                            }
                            Spacer()
                        }

                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredTeams) { team in
                                    TeamRow(team: team, viewModel: viewModel, isSelected: selectedTeam?.id == team.id)
                                        .onTapGesture {
                                            selectedTeam = team
                                        }
                                        .onTapGesture(count: 2) {
                                            selectedTeam = team
                                            showingEditTeamSheet = true
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                ProductionCard(icon: "info.circle", title: "TEAM DETAILS") {
                    if let team = selectedTeam {
                        teamDetailView(team)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        Text("Select a team to view details")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    private func teamDetailView(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(team.name)
                .font(.system(size: 14, weight: .bold))
            Text(team.teamType)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if !team.description.isEmpty {
                Text(team.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 12) {
                ProductionStatBadge(intValue: team.castMemberIds.count, label: "Cast", color: .blue)
                ProductionStatBadge(intValue: team.crewMemberIds.count, label: "Crew", color: .purple)
            }

            if let leadId = team.teamLeadId,
               let lead = viewModel.crewMembers.first(where: { $0.id == leadId }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text("Lead: \(lead.name)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
    }

    // MARK: - Computed Properties

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

    // MARK: - Photo Helpers

    @ViewBuilder
    private func castPhotoOrAvatar(_ cast: CastMember, size: CGFloat) -> some View {
        if !cast.photoPath.isEmpty, let image = loadImage(path: cast.photoPath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: cast.actorName, size: size)
        }
    }

    @ViewBuilder
    private func crewPhotoOrAvatar(_ crew: CrewMember, size: CGFloat) -> some View {
        if !crew.photoPath.isEmpty, let image = loadImage(path: crew.photoPath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: crew.name, size: size, color: .purple)
        }
    }

    private func loadImage(path: String) -> NSImage? {
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(path)
        } else {
            fullURL = URL(fileURLWithPath: path)
        }
        return NSImage(contentsOf: fullURL)
    }
}

// MARK: - Cast Member Row

struct CastMemberRow: View {
    let cast: CastMember
    var isSelected: Bool = false
    var projectBasePath: URL?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            castRowPhoto(cast, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(cast.actorName)
                    .font(.system(size: 12, weight: .semibold))
                Text("as \(cast.characterName)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(cast.roleType)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(roleTypeColor.opacity(0.2))
                )
                .foregroundColor(roleTypeColor)

            if cast.paymentType == "One Time" {
                Text("$\(String(format: "%.0f", cast.oneTimePayment)) flat")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("$\(String(format: "%.0f", cast.dailyRate))/day")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private func castRowPhoto(_ cast: CastMember, size: CGFloat) -> some View {
        if !cast.photoPath.isEmpty, let image = loadCastImage(path: cast.photoPath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: cast.actorName, size: size)
        }
    }

    private func loadCastImage(path: String) -> NSImage? {
        let fullURL: URL
        if let basePath = projectBasePath {
            fullURL = basePath.appendingPathComponent(path)
        } else {
            fullURL = URL(fileURLWithPath: path)
        }
        return NSImage(contentsOf: fullURL)
    }

    private var roleTypeColor: Color {
        switch cast.roleType {
        case "Principal": return .blue
        case "Supporting": return .green
        case "Background": return .yellow
        case "Extra": return .orange
        default: return .gray
        }
    }
}

// MARK: - Crew Member Row

struct CrewMemberRow: View {
    let crew: CrewMember
    var isSelected: Bool = false
    var projectBasePath: URL?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            crewRowPhoto(crew, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(crew.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(crew.role)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(crew.department)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple.opacity(0.2))
                )
                .foregroundColor(.purple)

            if crew.paymentType == "One Time" {
                Text("$\(String(format: "%.0f", crew.oneTimePayment)) flat")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("$\(String(format: "%.0f", crew.dailyRate))/day")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private func crewRowPhoto(_ crew: CrewMember, size: CGFloat) -> some View {
        if !crew.photoPath.isEmpty, let image = loadCrewImage(path: crew.photoPath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: crew.name, size: size, color: .purple)
        }
    }

    private func loadCrewImage(path: String) -> NSImage? {
        let fullURL: URL
        if let basePath = projectBasePath {
            fullURL = basePath.appendingPathComponent(path)
        } else {
            fullURL = URL(fileURLWithPath: path)
        }
        return NSImage(contentsOf: fullURL)
    }
}

// MARK: - Team Row

struct TeamRow: View {
    let team: Team
    let viewModel: CastCrewViewModel
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(team.teamType)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "person.3")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text("\(team.castMemberIds.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Image(systemName: "wrench")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text("\(team.crewMemberIds.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            if let leadId = team.teamLeadId,
               let lead = viewModel.crewMembers.first(where: { $0.id == leadId }) {
                Text(lead.name)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}


// MARK: - Cast Member Editor Sheet

struct CastMemberEditorSheet: View {
    @ObservedObject var viewModel: CastCrewViewModel
    let castMember: CastMember?

    @Environment(\.dismiss) private var dismiss

    @State private var actorName = ""
    @State private var characterName = ""
    @State private var isCharacterFieldFocused = false
    @State private var roleType = "Principal"
    @State private var unionStatus = "Non-Union"
    @State private var email = ""
    @State private var phone = ""
    @State private var paymentType = "Daily Rate"
    @State private var dailyRate: Double = 0
    @State private var oneTimePayment: Double = 0
    @State private var photoPath = ""
    @State private var photoImage: NSImage?

    /// Filtered character suggestions based on current text
    private var characterSuggestions: [String] {
        guard !characterName.isEmpty else { return viewModel.characterNames }
        return viewModel.characterNames.filter {
            $0.localizedCaseInsensitiveContains(characterName)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: castMember == nil ? "Add Cast Member" : "Edit Cast Member",
                canSave: !actorName.isEmpty && !characterName.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Photo + Basic Info side by side
                    HStack(alignment: .top, spacing: 16) {
                        // Photo card
                        ProductionCard(icon: "camera", title: "PHOTO") {
                            VStack(spacing: 10) {
                                if let image = photoImage {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(nsColor: .quaternarySystemFill))
                                            .frame(width: 120, height: 140)
                                        VStack(spacing: 6) {
                                            Image(systemName: "person.crop.rectangle")
                                                .font(.system(size: 28))
                                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                            Text("No Photo")
                                                .font(.system(size: 9))
                                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                        }
                                    }
                                }

                                HStack(spacing: 6) {
                                    Button {
                                        selectPhoto()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: photoImage == nil ? "plus.circle" : "arrow.triangle.2.circlepath")
                                                .font(.system(size: 10))
                                            Text(photoImage == nil ? "Add" : "Change")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)

                                    if photoImage != nil {
                                        Button {
                                            photoPath = ""
                                            photoImage = nil
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 10))
                                                Text("Remove")
                                                    .font(.system(size: 10, weight: .medium))
                                            }
                                            .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .frame(width: 170)

                        // Basic info card
                        ProductionCard(icon: "person", title: "BASIC INFORMATION") {
                            VStack(spacing: 10) {
                                StyledTextField("Actor Name", text: $actorName)

                                // Character name with autocomplete suggestions
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CHARACTER")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.2)

                                    TextField("Character Name", text: $characterName, onEditingChanged: { editing in
                                        isCharacterFieldFocused = editing
                                    })
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .quaternarySystemFill))
                                    .cornerRadius(6)

                                    // Suggestion list — show when focused and there are matches
                                    if isCharacterFieldFocused && !viewModel.characterNames.isEmpty {
                                        let suggestions = characterSuggestions
                                        if !suggestions.isEmpty && !(suggestions.count == 1 && suggestions.first == characterName) {
                                            VStack(spacing: 0) {
                                                ForEach(suggestions, id: \.self) { name in
                                                    Button {
                                                        characterName = name
                                                        isCharacterFieldFocused = false
                                                        NSApp.keyWindow?.makeFirstResponder(nil)
                                                    } label: {
                                                        HStack(spacing: 8) {
                                                            Image(systemName: "theatermasks")
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.accentColor)
                                                            Text(name)
                                                                .font(.system(size: 11))
                                                                .foregroundColor(.primary)
                                                            Spacer()
                                                        }
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(.plain)
                                                    .background(
                                                        characterName == name
                                                            ? Color.accentColor.opacity(0.15)
                                                            : Color.clear
                                                    )

                                                    if name != suggestions.last {
                                                        Divider().padding(.horizontal, 8)
                                                    }
                                                }
                                            }
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "star", title: "ROLE TYPE") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 6) {
                            ForEach(CastRoleType.allCases, id: \.self) { type in
                                ProductionChip(type.rawValue, selected: roleType == type.rawValue) {
                                    roleType = type.rawValue
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "building.columns", title: "UNION STATUS") {
                        HStack(spacing: 6) {
                            ForEach(UnionStatus.allCases, id: \.self) { status in
                                ProductionChip(status.rawValue, selected: unionStatus == status.rawValue) {
                                    unionStatus = status.rawValue
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "envelope", title: "CONTACT") {
                        VStack(spacing: 10) {
                            StyledTextField("Email", text: $email)
                            StyledTextField("Phone", text: $phone)
                        }
                    }

                    ProductionCard(icon: "dollarsign.circle", title: "PAYMENT") {
                        VStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PAYMENT TYPE")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.2)
                                HStack(spacing: 6) {
                                    ProductionChip(icon: "calendar", "Daily Rate", selected: paymentType == "Daily Rate") {
                                        paymentType = "Daily Rate"
                                    }
                                    ProductionChip(icon: "banknote", "One Time", selected: paymentType == "One Time") {
                                        paymentType = "One Time"
                                    }
                                }
                            }

                            if paymentType == "Daily Rate" {
                                StyledNumberField("Daily Rate", value: $dailyRate)
                            } else {
                                StyledNumberField("One Time Payment", value: $oneTimePayment)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 580, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let cast = castMember {
                actorName = cast.actorName
                characterName = cast.characterName
                roleType = cast.roleType
                unionStatus = cast.unionStatus
                email = cast.email
                phone = cast.phone
                paymentType = cast.paymentType
                dailyRate = cast.dailyRate
                oneTimePayment = cast.oneTimePayment
                photoPath = cast.photoPath
                loadPhoto()
            }
        }
    }

    private func selectPhoto() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select a photo"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        guard let basePath = viewModel.projectBasePath else {
            photoPath = sourceURL.path
            photoImage = NSImage(contentsOf: sourceURL)
            return
        }

        let photosDir = basePath.appendingPathComponent("assets/cast_photos")
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension
        let destFilename = "\(UUID().uuidString).\(ext)"
        let destURL = photosDir.appendingPathComponent(destFilename)

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            photoPath = "assets/cast_photos/\(destFilename)"
            photoImage = NSImage(contentsOf: destURL)
        } catch {
            photoPath = sourceURL.path
            photoImage = NSImage(contentsOf: sourceURL)
        }
    }

    private func loadPhoto() {
        guard !photoPath.isEmpty else { return }
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(photoPath)
        } else {
            fullURL = URL(fileURLWithPath: photoPath)
        }
        photoImage = NSImage(contentsOf: fullURL)
    }

    private func save() {
        if var existing = castMember {
            existing.actorName = actorName
            existing.characterName = characterName
            existing.roleType = roleType
            existing.unionStatus = unionStatus
            existing.email = email
            existing.phone = phone
            existing.paymentType = paymentType
            existing.dailyRate = dailyRate
            existing.oneTimePayment = oneTimePayment
            existing.photoPath = photoPath
            viewModel.updateCastMember(existing)
        } else {
            let newCast = CastMember(
                actorName: actorName,
                characterName: characterName,
                email: email,
                phone: phone,
                roleType: roleType,
                unionStatus: unionStatus,
                paymentType: paymentType,
                dailyRate: dailyRate,
                oneTimePayment: oneTimePayment,
                photoPath: photoPath
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
    @State private var paymentType = "Daily Rate"
    @State private var dailyRate: Double = 0
    @State private var oneTimePayment: Double = 0
    @State private var photoPath = ""
    @State private var photoImage: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: crewMember == nil ? "Add Crew Member" : "Edit Crew Member",
                canSave: !name.isEmpty && !role.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Photo + Basic Info side by side
                    HStack(alignment: .top, spacing: 16) {
                        // Photo card
                        ProductionCard(icon: "camera", title: "PHOTO") {
                            VStack(spacing: 10) {
                                if let image = photoImage {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(nsColor: .quaternarySystemFill))
                                            .frame(width: 120, height: 140)
                                        VStack(spacing: 6) {
                                            Image(systemName: "person.crop.rectangle")
                                                .font(.system(size: 28))
                                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                            Text("No Photo")
                                                .font(.system(size: 9))
                                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                        }
                                    }
                                }

                                HStack(spacing: 6) {
                                    Button {
                                        selectPhoto()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: photoImage == nil ? "plus.circle" : "arrow.triangle.2.circlepath")
                                                .font(.system(size: 10))
                                            Text(photoImage == nil ? "Add" : "Change")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)

                                    if photoImage != nil {
                                        Button {
                                            photoPath = ""
                                            photoImage = nil
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 10))
                                                Text("Remove")
                                                    .font(.system(size: 10, weight: .medium))
                                            }
                                            .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .frame(width: 170)

                        // Basic info card
                        ProductionCard(icon: "person", title: "BASIC INFORMATION") {
                            VStack(spacing: 10) {
                                StyledTextField("Name", text: $name)
                                StyledTextField("Role", text: $role)
                            }
                        }
                    }

                    ProductionCard(icon: "building.2", title: "DEPARTMENT") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                            ForEach(CrewDepartment.allCases, id: \.self) { dept in
                                ProductionChip(dept.rawValue, selected: department == dept.rawValue) {
                                    department = dept.rawValue
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "briefcase", title: "EMPLOYMENT TYPE") {
                        HStack(spacing: 6) {
                            ForEach(EmploymentType.allCases, id: \.self) { type in
                                ProductionChip(type.rawValue, selected: employmentType == type.rawValue) {
                                    employmentType = type.rawValue
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "envelope", title: "CONTACT") {
                        VStack(spacing: 10) {
                            StyledTextField("Email", text: $email)
                            StyledTextField("Phone", text: $phone)
                        }
                    }

                    ProductionCard(icon: "dollarsign.circle", title: "PAYMENT") {
                        VStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PAYMENT TYPE")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.2)
                                HStack(spacing: 6) {
                                    ProductionChip(icon: "calendar", "Daily Rate", selected: paymentType == "Daily Rate") {
                                        paymentType = "Daily Rate"
                                    }
                                    ProductionChip(icon: "banknote", "One Time", selected: paymentType == "One Time") {
                                        paymentType = "One Time"
                                    }
                                }
                            }

                            if paymentType == "Daily Rate" {
                                StyledNumberField("Daily Rate", value: $dailyRate)
                            } else {
                                StyledNumberField("One Time Payment", value: $oneTimePayment)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 580, height: 750)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let crew = crewMember {
                name = crew.name
                role = crew.role
                department = crew.department
                employmentType = crew.employmentType
                email = crew.email
                phone = crew.phone
                paymentType = crew.paymentType
                dailyRate = crew.dailyRate
                oneTimePayment = crew.oneTimePayment
                photoPath = crew.photoPath
                loadPhoto()
            }
        }
    }

    private func selectPhoto() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select a photo"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        guard let basePath = viewModel.projectBasePath else {
            photoPath = sourceURL.path
            photoImage = NSImage(contentsOf: sourceURL)
            return
        }

        let photosDir = basePath.appendingPathComponent("assets/crew_photos")
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension
        let destFilename = "\(UUID().uuidString).\(ext)"
        let destURL = photosDir.appendingPathComponent(destFilename)

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            photoPath = "assets/crew_photos/\(destFilename)"
            photoImage = NSImage(contentsOf: destURL)
        } catch {
            photoPath = sourceURL.path
            photoImage = NSImage(contentsOf: sourceURL)
        }
    }

    private func loadPhoto() {
        guard !photoPath.isEmpty else { return }
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(photoPath)
        } else {
            fullURL = URL(fileURLWithPath: photoPath)
        }
        photoImage = NSImage(contentsOf: fullURL)
    }

    private func save() {
        if var existing = crewMember {
            existing.name = name
            existing.role = role
            existing.department = department
            existing.employmentType = employmentType
            existing.email = email
            existing.phone = phone
            existing.paymentType = paymentType
            existing.dailyRate = dailyRate
            existing.oneTimePayment = oneTimePayment
            existing.photoPath = photoPath
            viewModel.updateCrewMember(existing)
        } else {
            let newCrew = CrewMember(
                name: name,
                role: role,
                department: department,
                email: email,
                phone: phone,
                employmentType: employmentType,
                paymentType: paymentType,
                dailyRate: dailyRate,
                oneTimePayment: oneTimePayment,
                photoPath: photoPath
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
            ProductionEditorHeader(
                title: team == nil ? "Add Team" : "Edit Team",
                canSave: !name.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    ProductionCard(icon: "rectangle.3.group", title: "TEAM INFORMATION") {
                        VStack(spacing: 10) {
                            StyledTextField("Team Name", text: $name)
                            StyledTextField("Description", text: $description)
                        }
                    }

                    ProductionCard(icon: "tag", title: "TEAM TYPE") {
                        HStack(spacing: 6) {
                            ForEach(teamTypes, id: \.self) { type in
                                ProductionChip(type, selected: teamType == type) {
                                    teamType = type
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "star", title: "TEAM LEAD") {
                        VStack(spacing: 6) {
                            ProductionChip("None", selected: teamLeadId == nil) {
                                teamLeadId = nil
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 6) {
                                ForEach(viewModel.crewMembers) { crew in
                                    ProductionChip(crew.name, selected: teamLeadId == crew.id) {
                                        teamLeadId = crew.id
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 520, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
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

