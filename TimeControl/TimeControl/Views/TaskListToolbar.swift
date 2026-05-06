//
//  TaskListToolbar.swift
//  TimeControl
//
//  Created on 2/18/26.
//

import SwiftUI

struct TaskListToolbar: View {
    @Binding var filterText: String
    @Binding var isAdvancedMode: Bool
    @Binding var areAllTasksExpanded: Bool
    @Binding var showingMassOperations: Bool
    @Binding var showingSettings: Bool
    @Binding var showingADOImport: Bool
    @Binding var sortOption: TaskSortOption
    var newTaskInputFocused: FocusState<Bool>.Binding? = nil
    var isRefreshingADO: Bool = false
    var unreadADOCount: Int = 0

    let onAddTodo: () -> Void
    let onToggleExpandAll: () -> Void
    let onExportAllTasks: () -> Void
    let onOpenNotesViewer: () -> Void
    let onOpenHistory: () -> Void
    var onRefreshADO: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Text fields and buttons in a single row
            HStack {
                NewTaskTextField(text: $filterText, focused: newTaskInputFocused, onSubmit: onAddTodo)

                Button(action: onAddTodo) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .disabled(filterText.trimmingCharacters(in: .whitespaces).isEmpty)

                if let onRefreshADO {
                    Button(action: onRefreshADO) {
                        ZStack {
                            if isRefreshingADO {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 20, height: 20)
                            } else {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "arrow.clockwise.circle")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    if unreadADOCount > 0 {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshingADO)
                    .help(unreadADOCount > 0
                          ? "Refresh ADO comments (\(unreadADOCount) task\(unreadADOCount == 1 ? "" : "s") with new comments)"
                          : "Refresh ADO comments")
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

                    Button(action: onOpenHistory) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("History")
                        }
                        .font(.body)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showingADOImport = true }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Import from ADO")
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

// MARK: - NewTaskTextField
// Separate view so we can conditionally wire a FocusState binding without
// requiring an always-present binding in TaskListToolbar's caller sites.

private struct NewTaskTextField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding?
    let onSubmit: () -> Void

    @FocusState private var localFocus: Bool

    var body: some View {
        TextField("Add or filter tasks...", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused(focused ?? $localFocus)
            .onSubmit(onSubmit)
    }
}
