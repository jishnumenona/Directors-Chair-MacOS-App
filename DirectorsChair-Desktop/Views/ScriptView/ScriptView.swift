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
                    showSceneNumbers: viewModel.showSceneNumbers,
                    scrollToElementId: viewModel.scrollToElementId,
                    onTextChanged: { index, text in
                        viewModel.handleTextChanged(elementIndex: index, newText: text)
                    },
                    autocompleteItems: viewModel.autocompleteItems,
                    showingAutocomplete: viewModel.showingAutocomplete,
                    autocompleteTrigger: viewModel.autocompleteTrigger,
                    projectBasePath: viewModel.projectBasePath,
                    onAutocompleteSelected: { item in
                        if viewModel.isWizardActive {
                            // During wizard, route selection to wizard state machine
                            viewModel.advanceWizard(selectedText: item)
                        } else if viewModel.showingAutocomplete {
                            viewModel.selectAutocompleteItem(item)
                        } else {
                            // This is a trigger character
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
                    isWizardActive: viewModel.isWizardActive,
                    focusElementId: viewModel.focusElementId
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            viewModel.loadFromProject(projectViewModel.project, projectViewModel: projectViewModel, coordinator: coordinator)
        }
        .onReceive(coordinator.projectChanged) { _ in
            viewModel.refresh(from: projectViewModel.project)
        }
    }
}
