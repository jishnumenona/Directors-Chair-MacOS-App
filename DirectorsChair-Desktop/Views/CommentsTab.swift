//
//  CommentsTab.swift
//  DirectorsChair-Desktop
//
//  Phase 8B: Navigation & Sidebar
//  Collaboration comments and feedback
//

import SwiftUI
import DirectorsChairCore

struct CommentsTab: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var comments: [ProjectComment] = []
    @State private var filterType: CommentFilterType = .all

    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker
            if projectViewModel.hasProject {
                Picker("Filter", selection: $filterType) {
                    ForEach(CommentFilterType.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
            }

            // Comments List
            ScrollView {
                if projectViewModel.hasProject {
                    if filteredComments.isEmpty {
                        EmptyCommentsView()
                    } else {
                        CommentsList(comments: filteredComments)
                    }
                } else {
                    NoProjectView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadComments()
        }
    }

    private var filteredComments: [ProjectComment] {
        switch filterType {
        case .all:
            return comments
        case .unresolved:
            return comments.filter { !$0.isResolved }
        case .resolved:
            return comments.filter { $0.isResolved }
        }
    }

    private func loadComments() {
        // TODO: Load comments from persistence
        // For now, show empty state
        comments = []
    }
}

// MARK: - Comments List

struct CommentsList: View {
    let comments: [ProjectComment]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(comments) { comment in
                CommentRow(comment: comment)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: ProjectComment
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Comment Header
            HStack(spacing: 8) {
                Image(systemName: comment.isResolved ? "checkmark.circle.fill" : "bubble.left")
                    .font(.system(size: 14))
                    .foregroundColor(comment.isResolved ? .green : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(comment.author)
                            .font(.system(size: 12, weight: .medium))

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text(comment.timestamp, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Text(comment.targetDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Comment Content (collapsed by default)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(comment.content)
                        .font(.system(size: 12))
                        .padding(.leading, 22)

                    // Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            // TODO: Navigate to comment target
                        }) {
                            Label("Go to", systemImage: "arrow.right")
                                .font(.system(size: 11))
                        }

                        if !comment.isResolved {
                            Button(action: {
                                // TODO: Resolve comment
                            }) {
                                Label("Resolve", systemImage: "checkmark")
                                    .font(.system(size: 11))
                            }
                        }

                        Spacer()

                        Menu {
                            Button("Edit", action: {
                                // TODO: Edit comment
                            })
                            Button("Delete", role: .destructive, action: {
                                // TODO: Delete comment
                            })
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.leading, 22)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }
}

// MARK: - Empty State

struct EmptyCommentsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No Comments")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Comments and feedback\nwill appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Add Comment") {
                // TODO: Add comment
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Supporting Types

enum CommentFilterType: String, CaseIterable, Identifiable {
    case all = "All"
    case unresolved = "Unresolved"
    case resolved = "Resolved"

    var id: String { rawValue }
}

struct ProjectComment: Identifiable {
    let id: String
    let author: String
    let content: String
    let timestamp: Date
    let targetType: CommentTargetType
    let targetId: String
    let targetDescription: String
    var isResolved: Bool
}

enum CommentTargetType: String {
    case scene = "Scene"
    case shot = "Shot"
    case dialogue = "Dialogue"
    case character = "Character"
    case general = "General"
}

// MARK: - Preview

#Preview {
    CommentsTab()
        .environmentObject(ProjectViewModel())
        .frame(width: 300, height: 600)
}
