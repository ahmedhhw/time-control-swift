//
//  CompletedTasksSection.swift
//  TimeControl
//
//  Created on 2/18/26.
//

import SwiftUI
import AppKit

struct CompletedTasksSection: View {
    let completedTodos: [TodoItem]
    let timerUpdateTrigger: Int
    @Binding var isCompletedSectionExpanded: Bool
    @Binding var expandedTodos: Set<UUID>
    @Binding var newSubtaskTexts: [UUID: String]
    @FocusState.Binding var subtaskInputFocused: UUID?
    
    let isAdvancedMode: Bool
    let onToggleTodo: (TodoItem) -> Void
    let onDeleteTodo: (TodoItem) -> Void
    let onToggleTimer: (TodoItem) -> Void
    let onEditTodo: (TodoItem) -> Void
    let onToggleExpanded: (TodoItem) -> Void
    let onToggleSubtask: (Subtask, TodoItem) -> Void
    let onDeleteSubtask: (Subtask, TodoItem) -> Void
    let onToggleSubtaskTimer: (Subtask, TodoItem) -> Void
    let onEditSubtask: (Subtask, TodoItem) -> Void
    let onRenameSubtask: (Subtask, TodoItem, String) -> Void
    let onAddSubtask: (TodoItem) -> Void
    let onMoveTodo: (Int, Int) -> Void
    let allTodos: [TodoItem]
    
    var body: some View {
        if !completedTodos.isEmpty {
            VStack(spacing: 0) {
                Divider()
                
                VStack(spacing: 8) {
                    // Completed section header
                    Button(action: {
                        withAnimation {
                            isCompletedSectionExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: isCompletedSectionExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            
                            Text("Completed (\(completedTodos.count))")
                                .foregroundColor(.secondary)
                                .font(.title2)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // Completed todos (shown when expanded) - scrollable if many items
                    if isCompletedSectionExpanded {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(completedTodos) { todo in
                                    VStack(spacing: 0) {
                                        VStack(spacing: 0) {
                                            TodoRow(
                                                todo: todo,
                                                timerUpdateTrigger: timerUpdateTrigger,
                                                isExpanded: expandedTodos.contains(todo.id),
                                                isAdvancedMode: isAdvancedMode,
                                                onToggle: {
                                                    onToggleTodo(todo)
                                                },
                                                onDelete: {
                                                    onDeleteTodo(todo)
                                                },
                                                onToggleTimer: {
                                                    onToggleTimer(todo)
                                                },
                                                onEdit: {
                                                    onEditTodo(todo)
                                                },
                                                onToggleExpanded: {
                                                    onToggleExpanded(todo)
                                                },
                                                onToggleSubtask: { subtask in
                                                    onToggleSubtask(subtask, todo)
                                                },
                                                onDeleteSubtask: { subtask in
                                                    onDeleteSubtask(subtask, todo)
                                                },
                                                onEditSubtask: { subtask in
                                                    onEditSubtask(subtask, todo)
                                                }
                                            )
                                            
                                            // Expanded area with inline subtask input and existing subtasks
                                            if expandedTodos.contains(todo.id) {
                                                VStack(spacing: 4) {
                                                    // Inline subtask input textbox (only show for incomplete tasks)
                                                    if !todo.isCompleted {
                                                        HStack(spacing: 8) {
                                                            TextField("Subtask title...", text: Binding(
                                                                get: { newSubtaskTexts[todo.id] ?? "" },
                                                                set: { newSubtaskTexts[todo.id] = $0 }
                                                            ))
                                                                .textFieldStyle(.roundedBorder)
                                                                .focused($subtaskInputFocused, equals: todo.id)
                                                                .onSubmit {
                                                                    onAddSubtask(todo)
                                                                }
                                                            
                                                            Button(action: {
                                                                onAddSubtask(todo)
                                                            }) {
                                                                Image(systemName: "plus.circle.fill")
                                                                    .foregroundColor(.blue)
                                                                    .font(.title3)
                                                            }
                                                            .buttonStyle(.plain)
                                                            .disabled((newSubtaskTexts[todo.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.top, 8)
                                                    }
                                                    
                                                    // Existing subtasks
                                                    if !todo.subtasks.isEmpty {
                                                        ForEach(todo.subtasks) { subtask in
                                                            SubtaskRow(
                                                                subtask: subtask,
                                                                parentTodoCompleted: todo.isCompleted,
                                                                parentTodoRunning: todo.isRunning,
                                                                timerUpdateTrigger: timerUpdateTrigger,
                                                                onToggle: { onToggleSubtask(subtask, todo) },
                                                                onDelete: { onDeleteSubtask(subtask, todo) },
                                                                onToggleTimer: { onToggleSubtaskTimer(subtask, todo) },
                                                                onRename: { newTitle in onRenameSubtask(subtask, todo, newTitle) }
                                                            )
                                                            .padding(.horizontal, 12)
                                                        }
                                                        .padding(.bottom, 4)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .draggable(todo.id.uuidString) {
                                        // Preview shown while dragging
                                        TodoRow(
                                            todo: todo,
                                            timerUpdateTrigger: timerUpdateTrigger,
                                            isExpanded: false,
                                            isAdvancedMode: false,
                                            onToggle: {},
                                            onDelete: {},
                                            onToggleTimer: {},
                                            onEdit: {},
                                            onToggleExpanded: {},
                                            onToggleSubtask: { _ in },
                                            onDeleteSubtask: { _ in },
                                            onEditSubtask: { _ in }
                                        )
                                        .opacity(0.8)
                                    }
                                    .dropDestination(for: String.self) { droppedItems, location in
                                        guard let droppedIdString = droppedItems.first,
                                              let droppedId = UUID(uuidString: droppedIdString),
                                              let fromIndex = allTodos.firstIndex(where: { $0.id == droppedId }),
                                              let toIndex = allTodos.firstIndex(where: { $0.id == todo.id }) else {
                                            return false
                                        }
                                        
                                        onMoveTodo(fromIndex, toIndex)
                                        return true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 300)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}
