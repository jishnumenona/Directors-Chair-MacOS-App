//
// CastCrewView+Components.swift
//
// Extracted from CastCrewView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore


// MARK: - Cast Member Row

struct CastMemberRow: View {
    let cast: CastMember
    var isSelected: Bool = false
    var projectBasePath: URL?
    @State var isHovered = false

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
    func castRowPhoto(_ cast: CastMember, size: CGFloat) -> some View {
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

    func loadCastImage(path: String) -> NSImage? {
        let fullURL: URL
        if let basePath = projectBasePath {
            fullURL = basePath.appendingPathComponent(path)
        } else {
            fullURL = URL(fileURLWithPath: path)
        }
        return NSImage(contentsOf: fullURL)
    }

    var roleTypeColor: Color {
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
    @State var isHovered = false

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
    func crewRowPhoto(_ crew: CrewMember, size: CGFloat) -> some View {
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

    func loadCrewImage(path: String) -> NSImage? {
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
    @State var isHovered = false

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

    @State var actorName = ""
    @State var characterName = ""
    @State var isCharacterFieldFocused = false
    @State var roleType = "Principal"
    @State var unionStatus = "Non-Union"
    @State var email = ""
    @State var phone = ""
    @State var paymentType = "Daily Rate"
    @State var dailyRate: Double = 0
    @State var oneTimePayment: Double = 0
    @State var photoPath = ""
    @State var photoImage: NSImage?

    /// Filtered character suggestions based on current text
    var characterSuggestions: [String] {
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

    func selectPhoto() {
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

    func loadPhoto() {
        guard !photoPath.isEmpty else { return }
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(photoPath)
        } else {
            fullURL = URL(fileURLWithPath: photoPath)
        }
        photoImage = NSImage(contentsOf: fullURL)
    }

    func save() {
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

    @State var name = ""
    @State var role = ""
    @State var department = "Production"
    @State var employmentType = "Freelance"
    @State var email = ""
    @State var phone = ""
    @State var paymentType = "Daily Rate"
    @State var dailyRate: Double = 0
    @State var oneTimePayment: Double = 0
    @State var photoPath = ""
    @State var photoImage: NSImage?

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

    func selectPhoto() {
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

    func loadPhoto() {
        guard !photoPath.isEmpty else { return }
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(photoPath)
        } else {
            fullURL = URL(fileURLWithPath: photoPath)
        }
        photoImage = NSImage(contentsOf: fullURL)
    }

    func save() {
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

    @State var name = ""
    @State var teamType = "Shooting Unit"
    @State var description = ""
    @State var selectedCastIds: Set<String> = []
    @State var selectedCrewIds: Set<String> = []
    @State var teamLeadId: String?

    let teamTypes = ["Shooting Unit", "Department", "Special Team"]

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

    func save() {
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
