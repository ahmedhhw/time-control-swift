//
//  ContentView.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit
import AVFoundation
import Quartz

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()
    @FocusState private var subtaskInputFocused: UUID?
    
    @AppStorage("activateReminders") private var activateReminders: Bool = false
    @AppStorage("confirmTaskDeletion") private var confirmTaskDeletion: Bool = true
    @AppStorage("confirmSubtaskDeletion") private var confirmSubtaskDeletion: Bool = true
    @AppStorage("showTimeWhenCollapsed") private var showTimeWhenCollapsed: Bool = false
    @AppStorage("autoPlayAfterSwitching") private var autoPlayAfterSwitching: Bool = false
    @AppStorage("autoPauseAfterMinutes") private var autoPauseAfterMinutes: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TaskListToolbar(
                newTodoText: $viewModel.newTodoText,
                filterText: $viewModel.filterText,
                isAdvancedMode: $viewModel.isAdvancedMode,
                areAllTasksExpanded: $viewModel.areAllTasksExpanded,
                showingMassOperations: $viewModel.showingMassOperations,
                showingSettings: $viewModel.showingSettings,
                sortOption: $viewModel.sortOption,
                onAddTodo: { viewModel.addTodo() },
                onToggleExpandAll: { toggleExpandAll() },
                onExportAllTasks: {
                    let exportText = viewModel.generateExportTextForAllTasks()
                    ExportWindowManager.shared.showExportWindow(with: exportText)
                }
            )
            
            // Main content area with incomplete todos
            if viewModel.todos.isEmpty {
                VStack {
                    Spacer()
                    Text("No todos yet")
                        .foregroundColor(.secondary)
                        .font(.title)
                    Text("Add one using the text field above")
                        .foregroundColor(.secondary)
                        .font(.body)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    // Scrollable incomplete todos
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            // Incomplete todos
                            ForEach(viewModel.incompleteTodos) { todo in
                                TaskListItem(
                                    todo: todo,
                                    timerUpdateTrigger: viewModel.timerUpdateTrigger,
                                    isExpanded: viewModel.expandedTodos.contains(todo.id),
                                    isAdvancedMode: viewModel.isAdvancedMode,
                                    newSubtaskText: Binding(
                                        get: { viewModel.newSubtaskTexts[todo.id] ?? "" },
                                        set: { viewModel.newSubtaskTexts[todo.id] = $0 }
                                    ),
                                    subtaskInputFocused: $subtaskInputFocused,
                                    onToggle: { viewModel.toggleTodo(todo) },
                                    onDelete: { viewModel.deleteTodo(todo) },
                                    onToggleTimer: { viewModel.toggleTimer(todo) },
                                    onEdit: { viewModel.editTodo(todo) },
                                    onToggleExpanded: { toggleExpanded(todo) },
                                    onToggleSubtask: { subtask in
                                        viewModel.toggleSubtask(subtask, in: todo)
                                    },
                                    onDeleteSubtask: { subtask in
                                        viewModel.deleteSubtask(subtask, from: todo)
                                    },
                                    onToggleSubtaskTimer: { subtask in
                                        viewModel.toggleSubtaskTimer(subtask, in: todo)
                                    },
                                    onEditSubtask: { subtask in
                                        editSubtask(subtask, in: todo)
                                    },
                                    onRenameSubtask: { subtask, newTitle in
                                        viewModel.renameSubtask(subtask, in: todo, newTitle: newTitle)
                                    },
                                    onAddSubtask: { addSubtask(to: todo) }
                                )
                                .draggable(todo.id.uuidString) {
                                    // Preview shown while dragging
                                    TodoRow(
                                        todo: todo,
                                        timerUpdateTrigger: viewModel.timerUpdateTrigger,
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
                                          let fromIndex = viewModel.todos.firstIndex(where: { $0.id == droppedId }),
                                          let toIndex = viewModel.todos.firstIndex(where: { $0.id == todo.id }) else {
                                        return false
                                    }
                                    
                                    viewModel.moveTodo(from: fromIndex, to: toIndex)
                                    return true
                                }
                            }
                        
                            // Drop zone at the end for moving items to the last position
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 40)
                                .dropDestination(for: String.self) { droppedItems, location in
                                    guard let droppedIdString = droppedItems.first,
                                          let droppedId = UUID(uuidString: droppedIdString),
                                          let fromIndex = viewModel.todos.firstIndex(where: { $0.id == droppedId }) else {
                                        return false
                                    }
                                    
                                    // Move to the last position
                                    let lastIndex = viewModel.todos.count - 1
                                    if fromIndex != lastIndex {
                                        viewModel.moveTodo(from: fromIndex, to: lastIndex)
                                    }
                                    return true
                                }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.todos.map { $0.id })
                        .padding()
                    }
                    
                    // Pinned completed section at the bottom
                    CompletedTasksSection(
                        completedTodos: viewModel.completedTodos,
                        timerUpdateTrigger: viewModel.timerUpdateTrigger,
                        isCompletedSectionExpanded: $viewModel.isCompletedSectionExpanded,
                        expandedTodos: $viewModel.expandedTodos,
                        newSubtaskTexts: $viewModel.newSubtaskTexts,
                        subtaskInputFocused: $subtaskInputFocused,
                        isAdvancedMode: viewModel.isAdvancedMode,
                        onToggleTodo: { todo in viewModel.toggleTodo(todo) },
                        onDeleteTodo: { todo in viewModel.deleteTodo(todo) },
                        onToggleTimer: { todo in viewModel.toggleTimer(todo) },
                        onEditTodo: { todo in viewModel.editTodo(todo) },
                        onToggleExpanded: { todo in viewModel.toggleExpanded(todo) },
                        onToggleSubtask: { subtask, todo in
                            viewModel.toggleSubtask(subtask, in: todo)
                        },
                        onDeleteSubtask: { subtask, todo in
                            viewModel.deleteSubtask(subtask, from: todo)
                        },
                        onToggleSubtaskTimer: { subtask, todo in
                            viewModel.toggleSubtaskTimer(subtask, in: todo)
                        },
                        onEditSubtask: { subtask, todo in
                            editSubtask(subtask, in: todo)
                        },
                        onRenameSubtask: { subtask, todo, newTitle in
                            viewModel.renameSubtask(subtask, in: todo, newTitle: newTitle)
                        },
                        onAddSubtask: { todo in
                            viewModel.addSubtask(to: todo)
                        },
                        onMoveTodo: { from, to in
                            viewModel.moveTodo(from: from, to: to)
                        },
                        allTodos: viewModel.todos
                    )
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            viewModel.activateReminders = activateReminders
            viewModel.confirmTaskDeletion = confirmTaskDeletion
            viewModel.confirmSubtaskDeletion = confirmSubtaskDeletion
            viewModel.showTimeWhenCollapsed = showTimeWhenCollapsed
            viewModel.autoPlayAfterSwitching = autoPlayAfterSwitching
            viewModel.autoPauseAfterMinutes = autoPauseAfterMinutes
        }
        .onChange(of: activateReminders) { viewModel.activateReminders = $0 }
        .onChange(of: confirmTaskDeletion) { viewModel.confirmTaskDeletion = $0 }
        .onChange(of: confirmSubtaskDeletion) { viewModel.confirmSubtaskDeletion = $0 }
        .onChange(of: showTimeWhenCollapsed) { viewModel.showTimeWhenCollapsed = $0 }
        .onChange(of: autoPlayAfterSwitching) { viewModel.autoPlayAfterSwitching = $0 }
        .onChange(of: autoPauseAfterMinutes) { viewModel.autoPauseAfterMinutes = $0 }
        .sheet(item: $viewModel.editingTodo) { todoToEdit in
            if let index = viewModel.todos.firstIndex(where: { $0.id == todoToEdit.id }) {
                EditTodoSheet(todo: $viewModel.todos[index], onSave: {
                    viewModel.saveTodos()
                    viewModel.editingTodo = nil
                })
            }
        }
        .sheet(isPresented: $viewModel.showingMassOperations) {
            MassOperationsSheet(todos: $viewModel.todos, onSave: {
                viewModel.saveTodos()
            })
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsSheet(activateReminders: $activateReminders, confirmTaskDeletion: $confirmTaskDeletion, confirmSubtaskDeletion: $confirmSubtaskDeletion, showTimeWhenCollapsed: $showTimeWhenCollapsed, autoPlayAfterSwitching: $autoPlayAfterSwitching, autoPauseAfterMinutes: $autoPauseAfterMinutes)
        }
        .confirmationDialog(
            "Delete Task",
            isPresented: Binding(
                get: { viewModel.todoToDelete != nil },
                set: { if !$0 { viewModel.todoToDelete = nil } }
            ),
            presenting: viewModel.todoToDelete
        ) { todo in
            Button("Delete", role: .destructive) {
                viewModel.performDeleteTodo(todo)
                viewModel.todoToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                viewModel.todoToDelete = nil
            }
        } message: { todo in
            Text("Are you sure you want to delete '\(todo.text)'?")
        }
        .confirmationDialog(
            "Delete Subtask",
            isPresented: Binding(
                get: { viewModel.subtaskToDelete != nil },
                set: { if !$0 { viewModel.subtaskToDelete = nil } }
            ),
            presenting: viewModel.subtaskToDelete
        ) { data in
            Button("Delete", role: .destructive) {
                viewModel.performDeleteSubtask(data.subtask, from: data.parentTodo)
                viewModel.subtaskToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                viewModel.subtaskToDelete = nil
            }
        } message: { data in
            Text("Are you sure you want to delete the subtask '\(data.subtask.title)'?")
        }
    }
    
    private func addSubtask(to todo: TodoItem) {
        viewModel.addSubtask(to: todo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            subtaskInputFocused = todo.id
        }
    }
    
    private func toggleExpanded(_ todo: TodoItem) {
        viewModel.toggleExpanded(todo)
        if viewModel.expandedTodos.contains(todo.id) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                subtaskInputFocused = todo.id
            }
        } else {
            subtaskInputFocused = nil
        }
    }
    
    private func toggleExpandAll() {
        viewModel.toggleExpandAll()
        subtaskInputFocused = nil
    }
    
    private func editSubtask(_ subtask: Subtask, in todo: TodoItem) {
    }
}



#Preview {
    ContentView()
}
