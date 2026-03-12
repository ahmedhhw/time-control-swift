//
//  SubtaskRow.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI

struct SubtaskRow: View {
    let subtask: Subtask
    let parentTodoCompleted: Bool
    let parentTodoRunning: Bool
    let timerUpdateTrigger: Int
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onToggleTimer: () -> Void
    let onRename: (String) -> Void
    
    @State private var editingTitle: String
    
    init(subtask: Subtask, parentTodoCompleted: Bool, parentTodoRunning: Bool,
         timerUpdateTrigger: Int, onToggle: @escaping () -> Void,
         onDelete: @escaping () -> Void, onToggleTimer: @escaping () -> Void,
         onRename: @escaping (String) -> Void) {
        self.subtask = subtask
        self.parentTodoCompleted = parentTodoCompleted
        self.parentTodoRunning = parentTodoRunning
        self.timerUpdateTrigger = timerUpdateTrigger
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onToggleTimer = onToggleTimer
        self.onRename = onRename
        self._editingTitle = State(initialValue: subtask.title)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(subtask.isCompleted ? .green : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                TextField("", text: $editingTitle, axis: .vertical)
                    .font(.title3)
                    .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                    .strikethrough(subtask.isCompleted)
                    .textFieldStyle(.plain)
                    .lineLimit(1...10)
                    .onSubmit { commitRename() }
                    .onExitCommand { editingTitle = subtask.title }
                    .disabled(parentTodoCompleted)
                    .onChange(of: subtask.title) { newTitle in editingTitle = newTitle }

                if !subtask.description.isEmpty {
                    Text(subtask.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Text(TimeFormatter.formatTime(subtask.currentTimeSpent))
                .font(.body)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .id(timerUpdateTrigger)
            
            Button(action: onToggleTimer) {
                Image(systemName: subtask.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(subtask.isRunning ? .orange : .blue)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(parentTodoCompleted || !parentTodoRunning || subtask.isCompleted)
            .opacity((parentTodoCompleted || !parentTodoRunning || subtask.isCompleted) ? 0.3 : 1.0)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(parentTodoCompleted ? .gray : .red)
            }
            .buttonStyle(.plain)
            .disabled(parentTodoCompleted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func commitRename() {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            editingTitle = subtask.title
        } else if trimmed != subtask.title {
            onRename(trimmed)
        }
    }
}
