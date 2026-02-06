// DirectorsChairViews/Sources/DirectorsChairViews/Shared/CharacterAvatarView.swift
//
// Circular character avatar view with fallback to initials

import SwiftUI
import DirectorsChairCore

/// Shared cache for character avatar images to avoid redundant disk reads
final class AvatarImageCache {
    static let shared = AvatarImageCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() { cache.countLimit = 50 }

    func image(forKey key: String) -> NSImage? { cache.object(forKey: key as NSString) }
    func setImage(_ image: NSImage, forKey key: String) { cache.setObject(image, forKey: key as NSString) }
}

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
        let cacheKey = fullPath.path

        // Check shared cache first (instant)
        if let cached = AvatarImageCache.shared.image(forKey: cacheKey) {
            avatarImage = cached
            return
        }

        // Load from disk asynchronously
        Task.detached(priority: .utility) {
            guard let image = NSImage(contentsOf: fullPath) else {
                await MainActor.run { avatarImage = nil }
                return
            }
            AvatarImageCache.shared.setImage(image, forKey: cacheKey)
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
