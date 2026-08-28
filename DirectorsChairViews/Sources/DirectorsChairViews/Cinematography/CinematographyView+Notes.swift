// DirectorsChairViews/Cinematography/CinematographyView+Notes.swift
//
// DC-0074: the user's own notes on a shot — free text, edited in place,
// saved through the same debounced path as the description.

import SwiftUI
import DirectorsChairCore

struct ShotNotesEditor: View {
    let notes: String
    let onNotesChange: (String) -> Void

    @State private var editText = ""
    @State private var hasInitialized = false
    @State private var commitTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if editText.isEmpty {
                Text("Add a note — anything you want to remember about this shot.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $editText)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .accessibilityLabel("Shot notes")
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .onAppear {
            editText = notes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasInitialized = true
            }
        }
        .onChange(of: editText) { _, newValue in
            guard hasInitialized, newValue != notes else { return }
            commitTask?.cancel()
            let text = newValue
            commitTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                onNotesChange(text)
            }
        }
        .onChange(of: notes) { _, newValue in
            if newValue != editText {
                editText = newValue
            }
        }
        .onDisappear {
            commitTask?.cancel()
            if hasInitialized && editText != notes {
                onNotesChange(editText)
            }
        }
    }
}
