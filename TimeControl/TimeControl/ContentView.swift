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
            // Text fields and buttons in a single row
            HStack {
                // Add new todo text field
                TextField("Add a new todo...", text: $viewModel.newTodoText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.addTodo()
                    }
                
                // Add new todo button
                Button(action: { viewModel.addTodo() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
                
                // Filter text field
                TextField("Filter tasks...", text: $viewModel.filterText)
                    .textFieldStyle(.roundedBorder)
                
                // Filter button/icon
                if !viewModel.filterText.isEmpty {
                    Button(action: {
                        viewModel.filterText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.title)
                }
            }
            .padding()
            .padding(.bottom, -8)
            
            // Advanced mode toggle
            HStack {
                Toggle("Advanced mode", isOn: $viewModel.isAdvancedMode)
                    .toggleStyle(.switch)
                    .font(.body)
                
                if viewModel.isAdvancedMode {
                    Spacer()
                    
                    Button(action: {
                        toggleExpandAll()
                    }) {
                        HStack {
                            Image(systemName: viewModel.areAllTasksExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            Text(viewModel.areAllTasksExpanded ? "Collapse All" : "Expand All")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewModel.showingMassOperations = true
                    }) {
                        HStack {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Mass Operations")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        let exportText = viewModel.generateExportTextForAllTasks()
                        ExportWindowManager.shared.showExportWindow(with: exportText)
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All Tasks")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewModel.showingSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Sort options (only shown when advanced mode is on)
            if viewModel.isAdvancedMode {
                HStack {
                    Text("Sort by:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Picker("Sort", selection: $viewModel.sortOption) {
                        ForEach(TaskSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.body)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            
            Divider()
            
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
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    TodoRow(
                                        todo: todo,
                                        timerUpdateTrigger: viewModel.timerUpdateTrigger,
                                        isExpanded: viewModel.expandedTodos.contains(todo.id),
                                        isAdvancedMode: viewModel.isAdvancedMode,
                                        onToggle: {
                                            viewModel.toggleTodo(todo)
                                        },
                                        onDelete: {
                                            viewModel.deleteTodo(todo)
                                        },
                                        onToggleTimer: {
                                            viewModel.toggleTimer(todo)
                                        },
                                        onEdit: {
                                            viewModel.editTodo(todo)
                                        },
                                        onToggleExpanded: {
                                            toggleExpanded(todo)
                                        },
                                        onToggleSubtask: { subtask in
                                            viewModel.toggleSubtask(subtask, in: todo)
                                        },
                                        onDeleteSubtask: { subtask in
                                            viewModel.deleteSubtask(subtask, from: todo)
                                        },
                                        onEditSubtask: { subtask in
                                            editSubtask(subtask, in: todo)
                                        }
                                    )
                                    
                                    // Expanded area with inline subtask input and existing subtasks
                                    if viewModel.expandedTodos.contains(todo.id) {
                                        VStack(spacing: 4) {
                                            // Inline subtask input textbox (only show for incomplete tasks)
                                            if !todo.isCompleted {
                                                HStack(spacing: 8) {
                                                    TextField("Subtask title...", text: Binding(
                                                        get: { viewModel.newSubtaskTexts[todo.id] ?? "" },
                                                        set: { viewModel.newSubtaskTexts[todo.id] = $0 }
                                                    ))
                                                        .textFieldStyle(.roundedBorder)
                                                        .focused($subtaskInputFocused, equals: todo.id)
                                                        .onSubmit {
                                                            addSubtask(to: todo)
                                                        }
                                                    
                                                    Button(action: {
                                                        addSubtask(to: todo)
                                                    }) {
                                                        Image(systemName: "plus.circle.fill")
                                                            .foregroundColor(.blue)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .disabled((viewModel.newSubtaskTexts[todo.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
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
                                                        timerUpdateTrigger: viewModel.timerUpdateTrigger,
                                                        onToggle: { viewModel.toggleSubtask(subtask, in: todo) },
                                                        onDelete: { viewModel.deleteSubtask(subtask, from: todo) },
                                                        onToggleTimer: { viewModel.toggleSubtaskTimer(subtask, in: todo) }
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
                    if !viewModel.completedTodos.isEmpty {
                        VStack(spacing: 0) {
                            Divider()
                            
                            VStack(spacing: 8) {
                                // Completed section header
                                Button(action: {
                                    withAnimation {
                                        viewModel.isCompletedSectionExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: viewModel.isCompletedSectionExpanded ? "chevron.down" : "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                        
                                        Text("Completed (\(viewModel.completedTodos.count))")
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
                                if viewModel.isCompletedSectionExpanded {
                                    ScrollView {
                                        LazyVStack(spacing: 8) {
                                            ForEach(viewModel.completedTodos) { todo in
                                                VStack(spacing: 0) {
                                                    VStack(spacing: 0) {
                                                        TodoRow(
                                                            todo: todo,
                                                            timerUpdateTrigger: viewModel.timerUpdateTrigger,
                                                            isExpanded: viewModel.expandedTodos.contains(todo.id),
                                                            isAdvancedMode: viewModel.isAdvancedMode,
                                                            onToggle: {
                                                                viewModel.toggleTodo(todo)
                                                            },
                                                            onDelete: {
                                                                viewModel.deleteTodo(todo)
                                                            },
                                                            onToggleTimer: {
                                                                viewModel.toggleTimer(todo)
                                                            },
                                                            onEdit: {
                                                                viewModel.editTodo(todo)
                                                            },
                                                            onToggleExpanded: {
                                                                viewModel.toggleExpanded(todo)
                                                            },
                                                            onToggleSubtask: { subtask in
                                                                viewModel.toggleSubtask(subtask, in: todo)
                                                            },
                                                            onDeleteSubtask: { subtask in
                                                                viewModel.deleteSubtask(subtask, from: todo)
                                                            },
                                                            onEditSubtask: { subtask in
                                                                editSubtask(subtask, in: todo)
                                                            }
                                                        )
                                                        
                                                        // Expanded area with inline subtask input and existing subtasks
                                                        if viewModel.expandedTodos.contains(todo.id) {
                                                            VStack(spacing: 4) {
                                                                // Inline subtask input textbox (only show for incomplete tasks)
                                                                if !todo.isCompleted {
                                                                    HStack(spacing: 8) {
                                                                        TextField("Subtask title...", text: Binding(
                                                                            get: { viewModel.newSubtaskTexts[todo.id] ?? "" },
                                                                            set: { viewModel.newSubtaskTexts[todo.id] = $0 }
                                                                        ))
                                                                            .textFieldStyle(.roundedBorder)
                                                                            .focused($subtaskInputFocused, equals: todo.id)
                                                                            .onSubmit {
                                                                                viewModel.addSubtask(to: todo)
                                                                            }
                                                                        
                                                                        Button(action: {
                                                                            viewModel.addSubtask(to: todo)
                                                                        }) {
                                                                            Image(systemName: "plus.circle.fill")
                                                                                .foregroundColor(.blue)
                                                                                .font(.title3)
                                                                        }
                                                                        .buttonStyle(.plain)
                                                                        .disabled((viewModel.newSubtaskTexts[todo.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
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
                                                            timerUpdateTrigger: viewModel.timerUpdateTrigger,
                                                            onToggle: { viewModel.toggleSubtask(subtask, in: todo) },
                                                            onDelete: { viewModel.deleteSubtask(subtask, from: todo) },
                                                            onToggleTimer: { viewModel.toggleSubtaskTimer(subtask, in: todo) }
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
