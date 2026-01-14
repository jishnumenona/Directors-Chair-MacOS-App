//
//  AssetsView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Media library and asset management
//

import SwiftUI
import UniformTypeIdentifiers

struct AssetsView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var selectedAssetType: AssetType = .all
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            AssetsToolbar(
                searchText: $searchText,
                selectedType: $selectedAssetType
            )

            Divider()

            // Asset Grid
            ScrollView {
                if assets.isEmpty {
                    EmptyAssetsView()
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(assets, id: \.self) { asset in
                            AssetCard(asset: asset)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var assets: [String] {
        // TODO: Implement actual asset management
        // For now, return empty list
        []
    }
}

// MARK: - Assets Toolbar

struct AssetsToolbar: View {
    @Binding var searchText: String
    @Binding var selectedType: AssetType

    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search assets...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Asset type filter
            Picker("Type", selection: $selectedType) {
                ForEach(AssetType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            Spacer()

            // Add asset button
            Button(action: {
                // TODO: Implement add asset
            }) {
                Label("Add Asset", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Asset Card

struct AssetCard: View {
    let asset: String

    var body: some View {
        VStack(spacing: 8) {
            // Asset preview
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                )
                .cornerRadius(8)

            // Asset name
            Text(asset)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Empty State

struct EmptyAssetsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Assets")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add images, videos, and audio files to your project")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                // TODO: Implement add asset
            }) {
                Label("Add Asset", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Asset Type

enum AssetType: String, CaseIterable, Identifiable {
    case all = "All"
    case images = "Images"
    case videos = "Videos"
    case audio = "Audio"
    case documents = "Documents"

    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    AssetsView()
        .environmentObject(ProjectViewModel())
}
