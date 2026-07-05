//
// CastCrewView+CrewTeams.swift
//
// Extracted from CastCrewView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore

extension CastCrewView {

    // MARK: - Crew Tab

    var crewTab: some View {
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

    func crewDetailView(_ crew: CrewMember) -> some View {
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

    var teamsTab: some View {
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

    func teamDetailView(_ team: Team) -> some View {
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

    var filteredCastMembers: [CastMember] {
        viewModel.castMembers.filter { cast in
            searchText.isEmpty ||
            cast.actorName.localizedCaseInsensitiveContains(searchText) ||
            cast.characterName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredCrewMembers: [CrewMember] {
        viewModel.crewMembers.filter { crew in
            let matchesSearch = searchText.isEmpty ||
                crew.name.localizedCaseInsensitiveContains(searchText) ||
                crew.role.localizedCaseInsensitiveContains(searchText)
            let matchesDepartment = departmentFilter == "All Departments" ||
                crew.department == departmentFilter
            return matchesSearch && matchesDepartment
        }
    }

    var filteredTeams: [Team] {
        viewModel.teams.filter { team in
            searchText.isEmpty ||
            team.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Photo Helpers

    @ViewBuilder
    func castPhotoOrAvatar(_ cast: CastMember, size: CGFloat) -> some View {
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
    func crewPhotoOrAvatar(_ crew: CrewMember, size: CGFloat) -> some View {
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

    func loadImage(path: String) -> NSImage? {
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(path)
        } else {
            fullURL = URL(fileURLWithPath: path)
        }
        return NSImage(contentsOf: fullURL)
    }
}
