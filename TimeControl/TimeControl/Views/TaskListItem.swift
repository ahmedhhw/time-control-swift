//
//  TaskListItem.swift
//  TimeControl
//
//  Created on 2/18/26.
//

import SwiftUI

struct TaskListItem: View {
    let todo: TodoItem
    let timerUpdateTrigger: Int
    let isExpanded: Bool
    let isAdvancedMode: Bool
    @Binding var newSubtaskText: String
    @FocusState.Binding var subtaskInputFocused: UUID?
    
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onToggleTimer: () -> Void
    let onEdit: () -> Void
    let onToggleExpanded: () -> Void
    let onToggleSubtask: (Subtask) -> Void
    let onDeleteSubtask: (Subtask) -> Void
    let onToggleSubtaskTimer: (Subtask) -> Void
    let onEditSubtask: (Subtask) -> Void
    let onRenameSubtask: (Subtask, String) -> Void
    let onAddSubtask: () -> Void
    var onPromoteSubtask: ((Subtask) -> Void)? = nil
    var onSetReminder: ((Date?) -> Void)? = nil
    var onDismissBell: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            TodoRow(
                todo: todo,
                timerUpdateTrigger: timerUpdateTrigger,
                isExpanded: isExpanded,
                isAdvancedMode: isAdvancedMode,
                onToggle: onToggle,
                onDelete: onDelete,
                onToggleTimer: onToggleTimer,
                onEdit: onEdit,
                onToggleExpanded: onToggleExpanded,
                onToggleSubtask: onToggleSubtask,
                onDeleteSubtask: onDeleteSubtask,
                onEditSubtask: onEditSubtask,
                onSetReminder: onSetReminder,
                onDismissBell: onDismissBell
            )
            
            // Expanded area with inline subtask input and existing subtasks
            if isExpanded {
                VStack(spacing: 4) {
                    // Existing subtasks
                    if !todo.subtasks.isEmpty {
                        ForEach(todo.subtasks) { subtask in
                            SubtaskRow(
                                subtask: subtask,
                                parentTodoCompleted: todo.isCompleted,
                                parentTodoRunning: todo.isRunning,
                                timerUpdateTrigger: timerUpdateTrigger,
                                onToggle: { onToggleSubtask(subtask) },
                                onDelete: { onDeleteSubtask(subtask) },
                                onToggleTimer: { onToggleSubtaskTimer(subtask) },
                                onRename: { newTitle in onRenameSubtask(subtask, newTitle) },
                                onPromote: onPromoteSubtask.map { promote in { promote(subtask) } }
                            )
                            .padding(.horizontal, 12)
                        }
                    }

                    // Inline subtask input textbox (only show for incomplete tasks)
                    if !todo.isCompleted {
                        HStack(spacing: 8) {
                            TextField("Subtask title...", text: $newSubtaskText)
                                .textFieldStyle(.roundedBorder)
                                .focused($subtaskInputFocused, equals: todo.id)
                                .onSubmit {
                                    onAddSubtask()
                                }

                            Button(action: onAddSubtask) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .disabled(newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
