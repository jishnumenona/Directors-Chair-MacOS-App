//
//  AIChatHistorySidebar.swift
//  DirectorsChair-Desktop
//
//  Conversation history sidebar for AI Chat
//

import SwiftUI

struct AIChatHistorySidebar: View {
    @ObservedObject var viewModel: AIChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("HISTORY")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { viewModel.startNewConversation() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("New Chat")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Conversation list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(groupedConversations, id: \.key) { group in
                        Section {
                            ForEach(group.value) { conversation in
                                ConversationRow(
                                    conversation: conversation,
                                    isActive: conversation.id == viewModel.conversations.first(where: {
                                        !viewModel.messages.isEmpty && $0.messages.first?.id == viewModel.messages.first?.id
                                    })?.id,
                                    onTap: { viewModel.loadConversation(conversation) },
                                    onDelete: { viewModel.deleteConversation(conversation) }
                                )
                            }
                        } header: {
                            Text(group.key)
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.0)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 220)
        .background(Color.white.opacity(0.03))
    }

    private var groupedConversations: [(key: String, value: [ChatConversation])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [ChatConversation]] = [:]

        for conv in viewModel.conversations {
            guard !conv.messages.isEmpty else { continue }
            let key: String
            if calendar.isDateInToday(conv.updatedAt) {
                key = "Today"
            } else if calendar.isDateInYesterday(conv.updatedAt) {
                key = "Yesterday"
            } else if calendar.dateComponents([.day], from: conv.updatedAt, to: now).day ?? 0 < 7 {
                key = "This Week"
            } else {
                key = "Earlier"
            }
            groups[key, default: []].append(conv)
        }

        let order = ["Today", "Yesterday", "This Week", "Earlier"]
        return order.compactMap { key in
            guard let value = groups[key], !value.isEmpty else { return nil }
            return (key: key, value: value)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ChatConversation
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: 10))
                .foregroundColor(isActive ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)

                Text(timeString(conversation.updatedAt))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
        .padding(.horizontal, 6)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
}
