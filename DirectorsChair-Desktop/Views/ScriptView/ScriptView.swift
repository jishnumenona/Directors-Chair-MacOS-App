//
//  ScriptView.swift
//  DirectorsChair-Desktop
//
//  Script View: Main view composing scene navigator + screenplay editor + toolbar
//

import SwiftUI
import DirectorsChairCore

struct ScriptView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = ScriptViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ScriptToolbar(viewModel: viewModel)

            // Main content
            HStack(spacing: 0) {
                // Scene Navigator (collapsible)
                if viewModel.showSceneNavigator {
                    ScriptSceneNavigator(viewModel: viewModel)

                    Divider()
                }

                // Screenplay Editor
                ScreenplayTextView(
                    elements: $viewModel.elements,
                    elementsVersion: viewModel.elementsVersion,
                    showSceneNumbers: viewModel.showSceneNumbers,
                    scrollToElementId: viewModel.scrollToElementId,
                    onTextChanged: { index, text in
                        viewModel.handleTextEdit(elementIndex: index, newText: text)
                    },
                    autocompleteItems: viewModel.autocompleteItems,
                    showingAutocomplete: viewModel.showingAutocomplete,
                    autocompleteTrigger: viewModel.autocompleteTrigger,
                    projectBasePath: viewModel.projectBasePath,
                    onAutocompleteSelected: { item in
                        if viewModel.isWizardActive {
                            viewModel.advanceWizard(selectedText: item)
                        } else if viewModel.showingAutocomplete {
                            viewModel.selectAutocompleteItem(item)
                        } else {
                            viewModel.handleAutocompleteTrigger(item)
                        }
                    },
                    onAutocompleteDismissed: {
                        viewModel.dismissAutocomplete()
                    },
                    onNewScene: { afterIndex in
                        viewModel.insertNewScene(afterElementIndex: afterIndex)
                    },
                    onDeleteScene: { elementId in
                        viewModel.deleteScene(elementId: elementId)
                    },
                    onCommandClick: { element in
                        viewModel.navigateToElement(element)
                    },
                    onDoubleClickScene: { element in
                        viewModel.openSceneInTimeline(element)
                    },
                    // Model-authoritative structural edit callbacks
                    onReturn: { elementIndex, cursorOffset in
                        viewModel.handleReturn(atElementIndex: elementIndex, cursorOffset: cursorOffset)
                    },
                    onBackspace: { elementIndex, cursorOffset in
                        viewModel.handleBackspace(atElementIndex: elementIndex, cursorOffset: cursorOffset)
                    },
                    onTabCycle: { elementIndex in
                        viewModel.handleTabCycle(atElementIndex: elementIndex)
                    },
                    onAutocompleteInsert: { text, elementIndex in
                        viewModel.handleAutocompleteSelection(item: text, atElementIndex: elementIndex)
                    },
                    onPlaceholderEdit: { index, text in
                        viewModel.handlePlaceholderEdit(elementIndex: index, newText: text)
                    },
                    onAutocompleteFilter: { prefix in
                        viewModel.filterAutocomplete(prefix: prefix)
                    },
                    isWizardActive: viewModel.isWizardActive,
                    focusElementId: viewModel.focusElementId,
                    focusCursorOffset: viewModel.focusCursorOffset,
                    showPagesMode: viewModel.showPagesMode,
                    projectName: projectViewModel.project.name,
                    directorName: projectViewModel.project.director,
                    productionCompany: projectViewModel.project.productionCompany,
                    genre: projectViewModel.project.genre,
                    spellCheckEnabled: viewModel.spellCheckEnabled,
                    typewriterMode: viewModel.typewriterMode,
                    transliterationEnabled: viewModel.transliterationEnabled,
                    transliterationService: viewModel.transliterationService,
                    characterImageMap: Dictionary(uniqueKeysWithValues: viewModel.characters.map { char in
                        (char.name.uppercased(), (imagePath: char.avatar ?? char.baseImage ?? char.imageFront, color: char.color))
                    }),
                    magnification: $viewModel.currentZoom,
                    onScrollYChanged: { y in
                        coordinator.scriptScrollY = y
                    },
                    restoreScrollY: coordinator.restoreScriptScrollY
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            viewModel.loadFromProject(projectViewModel.project, projectViewModel: projectViewModel, coordinator: coordinator)
            // Check if there's a pending scroll request
            if let itemId = coordinator.scrollToScriptItemId {
                viewModel.scrollToSourceItem(itemId)
                coordinator.scrollToScriptItemId = nil
            }
        }
        .onReceive(coordinator.projectChanged) { _ in
            viewModel.refresh(from: projectViewModel.project)
        }
        .onChange(of: coordinator.scrollToScriptItemId) { newValue in
            if let itemId = newValue {
                viewModel.scrollToSourceItem(itemId)
                coordinator.scrollToScriptItemId = nil
            }
        }
    }
}
