// DirectorsChairViews/Sources/DirectorsChairViews/Shared/CommandPaletteCore.swift
//
// The command palette (backlog §2.18 — "feel like the class").
//
// ⌘K anywhere: a search field over everything the app can DO — go to a
// view, open a production tab, run an app command, or hand an assistant
// action to the chat. The professional benchmark apps all have one; its
// value is that the user stops needing to know WHERE a capability lives.
//
// This file is the app-agnostic core: the entry model, the fuzzy ranker,
// and the panel UI. The app target builds the catalog (it knows the
// coordinator, the views, and the assistant registry) and mounts the
// panel — new files do not compile in the app target's synchronized
// folder group, so the reusable half lives here where new files do.

import SwiftUI

// MARK: - Entry

public struct PaletteEntry: Identifiable, Equatable, Sendable {
    public enum Category: String, Sendable {
        case navigation = "View"
        case command = "Command"
        case assistant = "Assistant"
    }

    /// Stable, unique ("nav.scenes", "action.generate_poster") — tests pin
    /// uniqueness so two entries never collide in the list.
    public let id: String
    public let title: String
    public let subtitle: String?
    public let systemImage: String
    public let category: Category

    public init(id: String, title: String, subtitle: String? = nil,
                systemImage: String, category: Category) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.category = category
    }
}

// MARK: - Ranking

public enum PaletteRank {

    /// Fuzzy subsequence score; nil = no match. Higher is better.
    ///
    /// The shape professionals expect from a palette: typing "csc" finds
    /// "Cast & Crew" (word starts), a prefix beats a scatter, and
    /// consecutive letters beat the same letters spread thin. Subtitles
    /// count at reduced weight so an action is findable by what it does
    /// ("rename" finds update_project_metadata via its summary) without
    /// drowning title matches.
    public static func score(query: String, entry: PaletteEntry) -> Double? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        if let title = match(trimmed, in: entry.title) {
            return title
        }
        if let subtitle = entry.subtitle,
           let sub = match(trimmed, in: subtitle) {
            return sub * 0.5
        }
        return nil
    }

    private static func match(_ query: String, in candidate: String) -> Double? {
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        guard !q.isEmpty, q.count <= c.count else { return nil }

        var score = 0.0
        var qi = 0
        var previousMatched = false
        for ci in c.indices {
            guard qi < q.count else { break }
            if c[ci] == q[qi] {
                let boundary = ci == 0 || c[ci - 1] == " " || c[ci - 1] == "&"
                    || c[ci - 1] == "-" || c[ci - 1] == "_" || c[ci - 1] == "/"
                if boundary { score += 3 }
                else if previousMatched { score += 2 }
                else { score += 1 }
                previousMatched = true
                qi += 1
            } else {
                previousMatched = false
            }
        }
        guard qi == q.count else { return nil }
        if candidate.lowercased().hasPrefix(query.lowercased()) { score += 5 }
        // Normalize a little toward shorter candidates: the same letters
        // in a tighter title are a stronger claim.
        return score / (1.0 + Double(c.count) / 64.0)
    }

    /// Entries ranked for a query. Empty query = catalog order (the
    /// caller puts navigation first, which is what an empty palette
    /// should offer).
    public static func rank(entries: [PaletteEntry], query: String,
                            limit: Int = 12) -> [PaletteEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(entries.prefix(limit)) }
        return entries
            .compactMap { entry in
                score(query: trimmed, entry: entry).map { (entry, $0) }
            }
            .sorted { left, right in
                left.1 != right.1 ? left.1 > right.1
                                  : left.0.title < right.0.title
            }
            .prefix(limit)
            .map(\.0)
    }
}

// MARK: - Panel

public struct CommandPaletteView: View {
    let entries: [PaletteEntry]
    let onRun: (PaletteEntry) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    public init(entries: [PaletteEntry],
                onRun: @escaping (PaletteEntry) -> Void,
                onDismiss: @escaping () -> Void) {
        self.entries = entries
        self.onRun = onRun
        self.onDismiss = onDismiss
    }

    private var results: [PaletteEntry] {
        PaletteRank.rank(entries: entries, query: query)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Click-away backdrop.
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            panel
                .padding(.top, 120)
        }
        .onAppear { searchFocused = true }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Type a command…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($searchFocused)
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.return) { runSelected(); return .handled }
                    .onKeyPress(.escape) { onDismiss(); return .handled }
                    .onChange(of: query) { _, _ in selectedIndex = 0 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider().opacity(0.4)

            if results.isEmpty {
                Text("Nothing matches “\(query)”")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 22)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, entry in
                                row(entry, isSelected: index == selectedIndex)
                                    .id(entry.id)
                                    .onTapGesture { onRun(entry) }
                                    .onHover { hovering in
                                        if hovering { selectedIndex = index }
                                    }
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 380)
                    .onChange(of: selectedIndex) { _, index in
                        if results.indices.contains(index) {
                            proxy.scrollTo(results[index].id)
                        }
                    }
                }
            }
        }
        .frame(width: 580)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
        .accessibilityIdentifier("command-palette")
    }

    private func row(_ entry: PaletteEntry, isSelected: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: entry.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.system(size: 13.5,
                                  weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.category.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear))
        .contentShape(Rectangle())
    }

    private func move(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func runSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        onRun(results[selectedIndex])
    }
}
