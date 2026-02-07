//
//  ScriptSceneNavigator.swift
//  DirectorsChair-Desktop
//
//  Script View: Scene outline sidebar for quick jump navigation
//

import SwiftUI

struct ScriptSceneNavigator: View {
    @ObservedObject var viewModel: ScriptViewModel
    @State private var selectedSceneNumber: String?
    @State private var sceneToDelete: SceneOutlineItem?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.number")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Scenes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.sceneOutline.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Scene list
            if viewModel.sceneOutline.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.system(size: 24))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text("No scenes")
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.sceneOutline) { item in
                            SceneNavigatorRow(
                                item: item,
                                isSelected: selectedSceneNumber == item.sceneNumber
                            )
                            .onTapGesture {
                                selectedSceneNumber = item.sceneNumber
                                viewModel.scrollToScene(item.sceneNumber)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    sceneToDelete = item
                                } label: {
                                    Label("Delete Scene", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
        .alert("Delete Scene \(sceneToDelete?.sceneNumber ?? "")?",
               isPresented: Binding<Bool>(
                   get: { sceneToDelete != nil },
                   set: { if !$0 { sceneToDelete = nil } }
               )
        ) {
            Button("Cancel", role: .cancel) {
                sceneToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = sceneToDelete {
                    viewModel.deleteScene(elementId: item.elementId)
                }
                sceneToDelete = nil
            }
        } message: {
            Text("This will permanently remove the scene and all its contents. This cannot be undone.")
        }
    }
}

// MARK: - Scene Navigator Row

struct SceneNavigatorRow: View {
    let item: SceneOutlineItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Scene number badge
            Text(item.sceneNumber)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 24, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                )

            // Scene heading (truncated)
            Text(formatHeading(item.heading))
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(2)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
    }

    private func formatHeading(_ heading: String) -> String {
        // Remove scene numbers from heading for display in navigator
        // Already clean from the converter
        return heading
    }
}
