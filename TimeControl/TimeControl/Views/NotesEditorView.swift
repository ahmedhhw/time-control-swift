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
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Task Notes")
                    .font(.title2)
                
                Spacer()
                
                Button("Save") {
                    saveNotes()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Take notes while working on this task")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $localNotes)
                    .font(.title3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.2), width: 1)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func saveNotes() {
        notes = localNotes
        
        viewModel.updateNotesFromFloatingWindow(localNotes, for: taskId)
        
        onClose()
    }
}
