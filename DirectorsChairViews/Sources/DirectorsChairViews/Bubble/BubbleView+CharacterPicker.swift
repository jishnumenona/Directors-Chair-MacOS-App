//
// BubbleView+CharacterPicker.swift
//
// Extracted from BubbleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import UniformTypeIdentifiers
import AVFoundation

extension BubbleView {

    /// Find the scene containing an item by ID and type
    func findScene(containing itemId: String, ofType itemType: String) -> DCScene? {
        for sequence in project.sequences {
            for scene in sequence.scenes {
                switch itemType {
                case "dialogue":
                    if scene.dialogues.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "action":
                    if scene.actions.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "narration":
                    if scene.narrations.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "note":
                    if scene.sceneNotes.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                case "soundNote":
                    if scene.soundNotes.contains(where: { $0.id == itemId }) {
                        return scene
                    }
                default:
                    break
                }
            }
        }
        return nil
    }

    /// Select the first scene from the first sequence if no scene is currently selected
    func selectFirstSceneIfNeeded() {
        guard selectedScene == nil else { return }

        // Find the first sequence with at least one scene
        if let firstSequence = project.sequences.first(where: { !$0.scenes.isEmpty }),
           let firstScene = firstSequence.scenes.first {
            selectedScene = firstScene
        } else if let anyScene = project.sequences.flatMap({ $0.scenes }).first {
            // Fallback: any scene from any sequence
            selectedScene = anyScene
        }
    }

    // MARK: - Toolbar

    var toolbar: some View {
        HStack {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Bubble View")
                    .font(.headline)
                if let scene = selectedScene {
                    Text(scene.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Filter buttons
            filterButtons

            Divider()
                .frame(height: 20)

            // Background toggle
            Toggle(isOn: $showBackground) {
                Image(systemName: "photo")
            }
            .toggleStyle(.button)
            .help("Show location background")

            Divider()
                .frame(height: 20)

            // Shortcuts help
            Button {
                showShortcutsPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text("Shortcuts")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.borderless)
            .help("View all keyboard shortcuts")
            .popover(isPresented: $showShortcutsPopover, arrowEdge: .bottom) {
                BubbleShortcutsPopoverView()
            }

            Divider()
                .frame(height: 20)

            // Add dialogue button with character picker popover
            Button(action: { selectedCharacterIndex = 0; showCharacterPicker = true }) {
                Image(systemName: "plus.bubble")
            }
            .help("Add Dialogue")
            .popover(isPresented: $showCharacterPicker, arrowEdge: .bottom) {
                characterPickerPopover
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Shared Character Picker Grid

    /// Number badge label for a character at the given index (1-9, 0 for 10th, nil for 11+)
    func numberBadgeLabel(for index: Int) -> String? {
        if index < 9 { return "\(index + 1)" }
        if index == 9 { return "0" }
        return nil
    }

    /// Shared character picker grid with keyboard navigation
    @ViewBuilder
    func characterPickerGrid(useHStack: Bool = false, dismiss: @escaping () -> Void) -> some View {
        let characters = project.characters
        let content = Group {
            if useHStack {
                HStack(spacing: 12) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        characterPickerCell(character: character, index: index, dismiss: dismiss)
                    }
                    newCharacterCell(dismiss: dismiss)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        characterPickerCell(character: character, index: index, dismiss: dismiss)
                    }
                    newCharacterCell(dismiss: dismiss)
                }
            }
        }

        content
    }

    @ViewBuilder
    func characterPickerCell(character: Character, index: Int, dismiss: @escaping () -> Void) -> some View {
        let isSelected = index == selectedCharacterIndex

        VStack(spacing: 4) {
            CharacterAvatarView(
                character: character,
                characterName: character.name,
                size: 40,
                projectBasePath: projectBasePath
            )
            .overlay(alignment: .topLeading) {
                if let badge = numberBadgeLabel(for: index) {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.accentColor.opacity(0.85)))
                        .offset(x: -4, y: -4)
                }
            }

            Text(character.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(width: 60)
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
            addDialogue(for: character.name)
        }
    }

    @ViewBuilder
    func newCharacterCell(dismiss: @escaping () -> Void) -> some View {
        if showNewCharacterInput {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.accentColor)
                }

                TextField("Name", text: $newCharacterName)
                    .font(.system(size: 9, weight: .medium))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .focused($newCharacterFieldFocused)
                    .onSubmit {
                        isCommittingNewCharacter = true
                        commitNewCharacter(dismiss: dismiss)
                    }
                    .onChange(of: newCharacterFieldFocused) { _, focused in
                        if !focused && !isCommittingNewCharacter {
                            // Cancelled — just hide the input
                            showNewCharacterInput = false
                            newCharacterName = ""
                        }
                    }
                    .onAppear {
                        isCommittingNewCharacter = false
                        newCharacterFieldFocused = true
                    }
            }
            .frame(width: 60)
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
        } else {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(NSColor.quaternarySystemFill))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Text("New")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 60)
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture {
                newCharacterName = ""
                showNewCharacterInput = true
            }
        }
    }

    static let characterColors = [
        "#3498db", "#e74c3c", "#2ecc71", "#9b59b6", "#f39c12",
        "#1abc9c", "#e67e22", "#2980b9", "#c0392b", "#27ae60",
        "#8e44ad", "#d35400", "#16a085", "#f1c40f", "#7f8c8d"
    ]

    func commitNewCharacter(dismiss: @escaping () -> Void) {
        let name = newCharacterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showNewCharacterInput = false
            newCharacterName = ""
            isCommittingNewCharacter = false
            return
        }
        // Check if character already exists
        let alreadyExists = project.characters.contains { $0.name.lowercased() == name.lowercased() }
        if !alreadyExists {
            let colorIndex = project.characters.count % Self.characterColors.count
            let newCharacter = Character(
                name: name,
                color: Self.characterColors[colorIndex]
            )
            project.characters.append(newCharacter)
        }
        showNewCharacterInput = false
        newCharacterName = ""
        // Dismiss picker first, then add dialogue after a brief delay so view settles
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.addDialogue(for: name)
            self.isCommittingNewCharacter = false
        }
    }

    /// Popover wrapper using the shared grid
    var characterPickerPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose Character")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 4)

            characterPickerGrid {
                showCharacterPicker = false
                showFloatingCharacterPicker = false
            }
        }
        .padding(12)
        .frame(minWidth: 160)
    }

    // MARK: - Inline Character Picker (Cmd+D)

    var inlineCharacterPicker: some View {
        HStack {
            Spacer()

            VStack(spacing: 8) {
                HStack {
                    Text("Choose Character")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showInlineCharacterPicker = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                characterPickerGrid(useHStack: true) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showInlineCharacterPicker = false
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
            )
            .frame(maxWidth: 500)

            Spacer()
        }
    }

    /// Convert stored right-click screen position to scroll area local coords and show the floating picker
    func showFloatingPickerAtRightClick() {
        guard let window = NSApp.keyWindow, let contentView = window.contentView else { return }
        // Convert screen coords (bottom-left origin) to window coords
        var windowPos = window.convertPoint(fromScreen: lastRightClickScreenPos)
        // Flip Y to match SwiftUI's top-left origin (same as GeometryReader .global)
        windowPos.y = contentView.frame.height - windowPos.y
        // Convert to scroll area local coordinates
        floatingPickerPosition = CGPoint(
            x: windowPos.x - scrollAreaFrame.minX,
            y: windowPos.y - scrollAreaFrame.minY
        )
        selectedCharacterIndex = 0
        showFloatingCharacterPicker = true
    }

    // MARK: - Picker Key Monitor

    func dismissAllPickers() {
        showCharacterPicker = false
        showFloatingCharacterPicker = false
        withAnimation(.easeOut(duration: 0.15)) {
            showInlineCharacterPicker = false
        }
    }

    /// Whether any character picker is currently open
    var isAnyPickerOpen: Bool {
        showCharacterPicker || showInlineCharacterPicker || showFloatingCharacterPicker
    }

    func selectCurrentCharacter() {
        let characters = project.characters
        guard selectedCharacterIndex < characters.count else { return }
        let name = characters[selectedCharacterIndex].name
        dismissAllPickers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            addDialogue(for: name)
        }
    }

    func installPickerKeyMonitor() {
        guard pickerKeyMonitor == nil else { return }
        pickerKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isAnyPickerOpen else { return event }
            let characters = self.project.characters
            guard !characters.isEmpty else { return event }

            switch Int(event.keyCode) {
            case 123: // Left arrow
                self.selectedCharacterIndex = max(0, self.selectedCharacterIndex - 1)
                return nil
            case 124: // Right arrow
                self.selectedCharacterIndex = min(characters.count - 1, self.selectedCharacterIndex + 1)
                return nil
            case 125: // Down arrow
                self.selectedCharacterIndex = min(characters.count - 1, self.selectedCharacterIndex + 1)
                return nil
            case 126: // Up arrow
                self.selectedCharacterIndex = max(0, self.selectedCharacterIndex - 1)
                return nil
            case 36, 76: // Return / numpad Enter
                self.selectCurrentCharacter()
                return nil
            case 53: // Escape
                self.dismissAllPickers()
                return nil
            default:
                if let chars = event.characters, chars.count == 1,
                   let digit = Int(chars), (0...9).contains(digit) {
                    let mappedIndex = digit == 0 ? 9 : digit - 1
                    if mappedIndex < characters.count {
                        let name = characters[mappedIndex].name
                        self.dismissAllPickers()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.addDialogue(for: name)
                        }
                        return nil
                    }
                }
                return event
            }
        }
    }

    func removePickerKeyMonitor() {
        if let monitor = pickerKeyMonitor {
            NSEvent.removeMonitor(monitor)
            pickerKeyMonitor = nil
        }
    }
}
