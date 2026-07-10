// DirectorsChairViews/Sources/DirectorsChairViews/Shared/CharacterAvatarView.swift
//
// Circular character avatar view with fallback to initials

import SwiftUI
import DirectorsChairCore

// Avatar images now use the shared, downsampling ThumbnailImageCache in
// DirectorsChairCore (perf Tier 3) — the old full-resolution AvatarImageCache
// was removed.

/// Displays a character's avatar as a circular image or initials fallback
public struct CharacterAvatarView: View {
    let character: Character?
    let characterName: String
    let size: CGFloat
    let projectBasePath: URL?

    @State private var avatarImage: NSImage?

    public init(
        character: Character?,
        characterName: String,
        size: CGFloat = 40,
        projectBasePath: URL? = nil
    ) {
        self.character = character
        self.characterName = characterName
        self.size = size
        self.projectBasePath = projectBasePath
    }

    public var body: some View {
        Group {
            if let image = avatarImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback to initials
                Circle()
                    .fill(Color(hex: character?.color ?? "#777777"))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .onAppear {
            loadAvatar()
        }
        .onChange(of: character?.avatar) { _, _ in
            loadAvatar()
        }
        .onChange(of: character?.baseImage) { _, _ in
            loadAvatar()
        }
        .onChange(of: character?.imageFront) { _, _ in
            loadAvatar()
        }
    }

    private var initials: String {
        let parts = characterName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else if !characterName.isEmpty {
            return String(characterName.prefix(1)).uppercased()
        }
        return "?"
    }

    /// Load avatar with fallback priority: avatar > baseImage > imageFront
    /// Uses shared cache and async disk loading to avoid blocking the main thread
    private func loadAvatar() {
        guard let basePath = projectBasePath else {
            avatarImage = nil
            return
        }

        // Determine which relative path to use (priority chain)
        let relativePath: String?
        if let avatarPath = character?.avatar, !avatarPath.isEmpty {
            relativePath = avatarPath
        } else if let baseImagePath = character?.baseImage, !baseImagePath.isEmpty {
            relativePath = baseImagePath
        } else if let frontPath = character?.imageFront, !frontPath.isEmpty {
            relativePath = frontPath
        } else {
            relativePath = nil
        }

        guard let path = relativePath else {
            avatarImage = nil
            return
        }

        let fullPath = basePath.appendingPathComponent(path)

        // Perf Tier 3 (audit C5/L1): the shared downsampling cache decodes a
        // thumbnail at ~3× the avatar's point size instead of holding the
        // full-resolution source (was full-res in memory, drawn at 40–60pt).
        let maxPixel = Int(size * 3)
        if let cached = ThumbnailImageCache.shared.cached(fullPath, maxPixel: maxPixel) {
            avatarImage = cached
            return
        }
        Task {
            let image = await ThumbnailImageCache.shared.thumbnail(fullPath, maxPixel: maxPixel)
            await MainActor.run { avatarImage = image }
        }
    }
}

// Color extension is in Shared/ColorExtensions.swift

#Preview {
    HStack(spacing: 20) {
        CharacterAvatarView(
            character: nil,
            characterName: "John Doe",
            size: 40
        )

        CharacterAvatarView(
            character: nil,
            characterName: "Jane",
            size: 60
        )
    }
    .padding()
}
