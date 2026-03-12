//
//  NotesEditorView.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

struct NotesEditorView: View {
    @Binding var notes: String
    let taskId: UUID
    let onClose: () -> Void
    @ObservedObject var viewModel: TodoViewModel
    @State private var localNotes: String

    init(notes: Binding<String>, taskId: UUID, viewModel: TodoViewModel, onClose: @escaping () -> Void) {
        self._notes = notes
        self.taskId = taskId
        self.viewModel = viewModel
        self.onClose = onClose
        self._localNotes = State(initialValue: notes.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Take notes while working on this task")
                .font(.body)
                .foregroundColor(.secondary)

            TextEditor(text: $localNotes)
                .font(.title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.gray.opacity(0.2), width: 1)
                .onChange(of: localNotes) { newValue in
                    notes = newValue
                    viewModel.updateNotesFromFloatingWindow(newValue, for: taskId)
                }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}
