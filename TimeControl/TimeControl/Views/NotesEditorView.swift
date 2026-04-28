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
    @ObservedObject var opacityBroadcaster: WindowOpacityBroadcaster
    @State private var localNotes: String

    init(notes: Binding<String>, taskId: UUID, viewModel: TodoViewModel, opacityBroadcaster: WindowOpacityBroadcaster, onClose: @escaping () -> Void) {
        self._notes = notes
        self.taskId = taskId
        self.viewModel = viewModel
        self.opacityBroadcaster = opacityBroadcaster
        self.onClose = onClose
        self._localNotes = State(initialValue: notes.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Take notes while working on this task")
                .font(.body)
                .foregroundColor(.secondary)
                .subtitleHalo(windowOpacity: opacityBroadcaster.opacity)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $localNotes)
                    .font(.title3)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.2), width: 1)
                    .onChange(of: localNotes) { newValue in
                        // Skip save if this change was triggered by an external binding update
                        // (in that case, `notes` is already equal to `newValue`)
                        guard newValue != notes else { return }
                        notes = newValue
                        viewModel.updateNotesFromFloatingWindow(newValue, for: taskId)
                    }
                    .onChange(of: notes) { newValue in
                        if newValue != localNotes {
                            localNotes = newValue
                        }
                    }
            }
            .subtitleHalo(windowOpacity: opacityBroadcaster.opacity)
        }
        .padding()
        .frame(minWidth: 180, minHeight: 120)
    }
}
