// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/BiographyTab.swift
//
// Biography tab - character backstory, goals, fears, and arc

import SwiftUI
import DirectorsChairCore

/// Biography tab - character backstory, motivations, fears, and development
public struct BiographyTab: View {
    @Binding var character: Character

    /// Whether biography generation is in progress
    var isGenerating: Bool = false

    // Callback for AI generation
    var onGenerateFromScript: (() -> Void)?

    public init(
        character: Binding<Character>,
        isGenerating: Bool = false,
        onGenerateFromScript: (() -> Void)? = nil
    ) {
        self._character = character
        self.isGenerating = isGenerating
        self.onGenerateFromScript = onGenerateFromScript
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Identity card
                identitySection

                // Background story
                backgroundStorySection

                // Two-column: Motivations & Fears
                HStack(alignment: .top, spacing: 16) {
                    motivationsSection
                    fearsSection
                }

                // Character arc
                characterArcSection

                // AI Generate button
                AIGenerateButton(
                    title: "Generate from Script",
                    icon: "wand.and.stars",
                    loadingText: "Generating...",
                    isLoading: isGenerating
                ) {
                    onGenerateFromScript?()
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        BioCard(title: "IDENTITY", icon: "person.text.rectangle") {
            HStack(alignment: .top, spacing: 16) {
                // Left column: Name & Nickname
                VStack(alignment: .leading, spacing: 14) {
                    BioTextField(
                        label: "Full Name",
                        placeholder: "Full legal name",
                        icon: "textformat",
                        text: Binding(
                            get: { character.fullName ?? "" },
                            set: { character.fullName = $0.isEmpty ? nil : $0 }
                        )
                    )

                    BioTextField(
                        label: "Nickname",
                        placeholder: "Alias or nickname",
                        icon: "quote.bubble",
                        text: Binding(
                            get: { character.nickname ?? "" },
                            set: { character.nickname = $0.isEmpty ? nil : $0 }
                        )
                    )
                }
                .frame(maxWidth: .infinity)

                // Right column: Occupation & Affiliation
                VStack(alignment: .leading, spacing: 14) {
                    BioTextField(
                        label: "Occupation",
                        placeholder: "Job or profession",
                        icon: "briefcase",
                        text: Binding(
                            get: { character.occupation ?? "" },
                            set: { character.occupation = $0.isEmpty ? nil : $0 }
                        )
                    )

                    BioTextField(
                        label: "Affiliation",
                        placeholder: "Organization, group, faction",
                        icon: "building.2",
                        text: Binding(
                            get: { character.affiliation ?? "" },
                            set: { character.affiliation = $0.isEmpty ? nil : $0 }
                        )
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Background Story

    private var backgroundStorySection: some View {
        BioCard(title: "BACKGROUND STORY", icon: "book") {
            VStack(alignment: .leading, spacing: 8) {
                Text("The character's history, upbringing, and formative experiences")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                TextEditor(text: Binding(
                    get: { character.backgroundStory ?? "" },
                    set: { character.backgroundStory = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(size: 12))
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Motivations & Goals

    private var motivationsSection: some View {
        BioCard(title: "MOTIVATIONS & GOALS", icon: "target") {
            VStack(spacing: 14) {
                GoalField(
                    label: "Primary Goal",
                    icon: "star.fill",
                    iconColor: .yellow,
                    placeholder: "What drives this character most?",
                    text: Binding(
                        get: { character.primaryGoal ?? "" },
                        set: { character.primaryGoal = $0.isEmpty ? nil : $0 }
                    )
                )

                Divider().opacity(0.5)

                GoalField(
                    label: "Secondary Goal",
                    icon: "star",
                    iconColor: .orange,
                    placeholder: "Supporting ambition or desire",
                    text: Binding(
                        get: { character.secondaryGoal ?? "" },
                        set: { character.secondaryGoal = $0.isEmpty ? nil : $0 }
                    )
                )

                Divider().opacity(0.5)

                GoalField(
                    label: "Hidden Motivation",
                    icon: "eye.slash",
                    iconColor: .purple,
                    placeholder: "Secret desire unknown to others",
                    text: Binding(
                        get: { character.hiddenMotivation ?? "" },
                        set: { character.hiddenMotivation = $0.isEmpty ? nil : $0 }
                    )
                )
            }
        }
    }

    // MARK: - Fears & Weaknesses

    private var fearsSection: some View {
        BioCard(title: "FEARS & WEAKNESSES", icon: "exclamationmark.triangle") {
            VStack(spacing: 14) {
                GoalField(
                    label: "Primary Fear",
                    icon: "bolt.fill",
                    iconColor: .red,
                    placeholder: "Deepest fear or anxiety",
                    text: Binding(
                        get: { character.primaryFear ?? "" },
                        set: { character.primaryFear = $0.isEmpty ? nil : $0 }
                    )
                )

                Divider().opacity(0.5)

                GoalField(
                    label: "Weakness",
                    icon: "heart.slash",
                    iconColor: .orange,
                    placeholder: "Vulnerability or soft spot",
                    text: Binding(
                        get: { character.weakness ?? "" },
                        set: { character.weakness = $0.isEmpty ? nil : $0 }
                    )
                )

                Divider().opacity(0.5)

                GoalField(
                    label: "Character Flaw",
                    icon: "xmark.diamond",
                    iconColor: .pink,
                    placeholder: "Personality defect or blind spot",
                    text: Binding(
                        get: { character.flaw ?? "" },
                        set: { character.flaw = $0.isEmpty ? nil : $0 }
                    )
                )
            }
        }
    }

    // MARK: - Character Arc

    private var characterArcSection: some View {
        BioCard(title: "CHARACTER ARC", icon: "arrow.triangle.swap") {
            VStack(alignment: .leading, spacing: 8) {
                Text("How does this character change throughout the story?")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))

                TextEditor(text: Binding(
                    get: { character.characterArcNotes ?? "" },
                    set: { character.characterArcNotes = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(size: 12))
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Reusable Components

/// Card container matching AttributeCard style from PhysicalAppearanceTab
private struct BioCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

/// Icon-labeled text field for biography inputs
private struct BioTextField: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
        }
    }
}

/// Goal/fear/weakness field with colored icon indicator
private struct GoalField: View {
    let label: String
    let icon: String
    let iconColor: Color
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $text)
                .font(.system(size: 12))
                .frame(minHeight: 48)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 12))
                                .foregroundColor(Color(nsColor: .placeholderTextColor))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
}

#Preview {
    BiographyTab(
        character: .constant(Character(
            name: "John Doe",
            role: "Protagonist",
            fullName: "Jonathan Michael Doe",
            nickname: "Johnny",
            occupation: "Private Detective",
            affiliation: "Doe Investigation Agency",
            backgroundStory: "Born in the rough neighborhoods of Brooklyn, John learned early that trust was a currency rarely spent.",
            primaryGoal: "To find the truth behind his partner's disappearance",
            secondaryGoal: "To clear his own name from false accusations",
            hiddenMotivation: "Seeking redemption for past mistakes",
            primaryFear: "That he'll become the corrupt cop he always despised",
            weakness: "Can't let go of the past",
            flaw: "Trust issues that push people away",
            characterArcNotes: "John starts as a cynical loner but gradually learns to trust others through his partnership with Sarah."
        ))
    )
    .frame(width: 800, height: 700)
}
