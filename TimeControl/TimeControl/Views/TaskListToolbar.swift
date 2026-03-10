//
//  TaskListToolbar.swift
//  TimeControl
//
//  Created on 2/18/26.
//

import SwiftUI

struct TaskListToolbar: View {
    @Binding var newTodoText: String
    @Binding var filterText: String
    @Binding var isAdvancedMode: Bool
    @Binding var areAllTasksExpanded: Bool
    @Binding var showingMassOperations: Bool
    @Binding var showingSettings: Bool
    @Binding var sortOption: TaskSortOption
    
    let onAddTodo: () -> Void
    let onToggleExpandAll: () -> Void
    let onExportAllTasks: () -> Void
    let onOpenNotesViewer: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Text fields and buttons in a single row
            HStack {
                // Add new todo text field
                TextField("Add a new todo...", text: $newTodoText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        onAddTodo()
                    }
                
                // Add new todo button
                Button(action: onAddTodo) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
                
                // Filter text field
                TextField("Filter tasks...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                
                // Filter button/icon
                if !filterText.isEmpty {
                    Button(action: {
                        filterText = ""
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
                Toggle("Advanced mode", isOn: $isAdvancedMode)
                    .toggleStyle(.switch)
                    .font(.body)
                
                if isAdvancedMode {
                    Spacer()
                    
                    Button(action: onToggleExpandAll) {
                        HStack {
                            Image(systemName: areAllTasksExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            Text(areAllTasksExpanded ? "Collapse All" : "Expand All")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showingMassOperations = true
                    }) {
                        HStack {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Mass Operations")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: onExportAllTasks) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All Tasks")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: onOpenNotesViewer) {
                        HStack {
                            Image(systemName: "note.text")
                            Text("Notes")
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
            if isAdvancedMode {
                HStack {
                    Text("Sort by:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Picker("Sort", selection: $sortOption) {
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
        }
    }
}
