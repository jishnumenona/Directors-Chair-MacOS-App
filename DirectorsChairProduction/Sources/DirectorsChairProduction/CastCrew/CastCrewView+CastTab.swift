//
// CastCrewView+CastTab.swift
//
// Extracted from CastCrewView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore

extension CastCrewView {

    // MARK: - Cast Tab

    var castTab: some View {
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

    func castDetailView(_ cast: CastMember) -> some View {
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

    func detailBadge(icon: String, text: String, color: Color) -> some View {
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

    func detailStatBox(icon: String, value: String, label: String, color: Color) -> some View {
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

    func detailSectionHeader(icon: String, title: String) -> some View {
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

    func detailInfoRow(icon: String, value: String) -> some View {
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

    func roleColor(_ role: String) -> Color {
        switch role {
        case "Principal": return .blue
        case "Supporting": return .green
        case "Background": return .yellow
        case "Extra": return .orange
        case "Stunt Double": return .red
        default: return .gray
        }
    }

    func scheduleStatusColor(_ status: String) -> Color {
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

    func formatShortDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}
