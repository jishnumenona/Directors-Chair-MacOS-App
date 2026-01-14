// DirectorsChairViews/Sources/DirectorsChairViews/Shared/CharacterAvatarView.swift
//
// Circular character avatar view with fallback to initials

import SwiftUI
import DirectorsChairCore

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

    private func loadAvatar() {
        guard let avatarPath = character?.avatar,
              !avatarPath.isEmpty,
              let basePath = projectBasePath else {
            avatarImage = nil
            return
        }

        let fullPath = basePath.appendingPathComponent(avatarPath)
        if let image = NSImage(contentsOf: fullPath) {
            avatarImage = image
        } else {
            avatarImage = nil
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
