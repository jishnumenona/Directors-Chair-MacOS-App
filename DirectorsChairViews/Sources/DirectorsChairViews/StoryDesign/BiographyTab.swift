// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/BiographyTab.swift
//
// Biography tab - character backstory, goals, fears, and arc

import SwiftUI
import DirectorsChairCore

/// Biography tab - character backstory, motivations, fears, and development
public struct BiographyTab: View {
    @Binding var character: Character

    // Callback for AI generation
    var onGenerateFromScript: (() -> Void)?

    public init(
        character: Binding<Character>,
        onGenerateFromScript: (() -> Void)? = nil
    ) {
        self._character = character
        self.onGenerateFromScript = onGenerateFromScript
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Identity section
                GroupBox("Identity") {
                    VStack(spacing: 12) {
                        LabeledContent("Full Name") {
                            TextField("Full legal name", text: Binding(
                                get: { character.fullName ?? "" },
                                set: { character.fullName = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        LabeledContent("Nickname") {
                            TextField("Alias or nickname", text: Binding(
                                get: { character.nickname ?? "" },
                                set: { character.nickname = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        LabeledContent("Occupation") {
                            TextField("Job or profession", text: Binding(
                                get: { character.occupation ?? "" },
                                set: { character.occupation = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        LabeledContent("Affiliation") {
                            TextField("Organization, group, faction", text: Binding(
                                get: { character.affiliation ?? "" },
                                set: { character.affiliation = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                // Background story
                GroupBox("Background Story") {
                    TextEditor(text: Binding(
                        get: { character.backgroundStory ?? "" },
                        set: { character.backgroundStory = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 120)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                }

                // Motivations & Goals
                GroupBox("Motivations & Goals") {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primary Goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { character.primaryGoal ?? "" },
                                set: { character.primaryGoal = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(height: 60)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secondary Goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { character.secondaryGoal ?? "" },
                                set: { character.secondaryGoal = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(height: 60)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hidden Motivation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { character.hiddenMotivation ?? "" },
                                set: { character.hiddenMotivation = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(height: 60)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }

                // Fears & Weaknesses
                GroupBox("Fears & Weaknesses") {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primary Fear")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { character.primaryFear ?? "" },
                                set: { character.primaryFear = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(height: 60)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weakness")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { character.weakness ?? "" },
                                set: { character.weakness = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(height: 60)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Character Flaw")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { character.flaw ?? "" },
                                set: { character.flaw = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(height: 60)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }

                // Character Arc
                GroupBox("Character Arc Notes") {
                    TextEditor(text: Binding(
                        get: { character.characterArcNotes ?? "" },
                        set: { character.characterArcNotes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 100)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                }

                // AI Generate button
                HStack {
                    Spacer()
                    Button {
                        onGenerateFromScript?()
                    } label: {
                        Label("Generate from Script", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(.top)
            }
            .padding()
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
    .frame(width: 600, height: 800)
}
