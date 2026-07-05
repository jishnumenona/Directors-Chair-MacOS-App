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

    @State var selectedTab: CastCrewTab = .cast
    @State var searchText = ""
    @State var departmentFilter: String = "All Departments"

    // Selection states
    @State var selectedCastMember: CastMember?
    @State var selectedCrewMember: CrewMember?
    @State var selectedTeam: Team?

    // Sheet states
    @State var showingAddCastSheet = false
    @State var showingEditCastSheet = false
    @State var showingAddCrewSheet = false
    @State var showingEditCrewSheet = false
    @State var showingAddTeamSheet = false
    @State var showingEditTeamSheet = false

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
}
