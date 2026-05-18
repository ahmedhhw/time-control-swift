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
    @Binding var showingADOInbox: Bool
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
            // Top row: text field, add, ADO refresh, inbox, advanced menu
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

                // ADO Comment Inbox — always visible
                Button(action: { showingADOInbox = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tray.and.arrow.down.fill")
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
                .buttonStyle(.plain)
                .help(unreadADOCount > 0
                      ? "ADO Comment Inbox (\(unreadADOCount) unread)"
                      : "ADO Comment Inbox")

                // Advanced actions menu — only in advanced mode
                if isAdvancedMode {
                    Menu {
                        Button(action: onToggleExpandAll) {
                            Label(
                                areAllTasksExpanded ? "Collapse All" : "Expand All",
                                systemImage: areAllTasksExpanded
                                    ? "arrow.up.left.and.arrow.down.right"
                                    : "arrow.down.right.and.arrow.up.left"
                            )
                        }
                        Button(action: { showingMassOperations = true }) {
                            Label("Mass Operations", systemImage: "square.grid.3x3.fill")
                        }
                        Button(action: onExportAllTasks) {
                            Label("Export All Tasks", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                        Button(action: onOpenNotesViewer) {
                            Label("Notes", systemImage: "note.text")
                        }
                        Button(action: onOpenHistory) {
                            Label("History", systemImage: "calendar")
                        }
                        Button(action: { showingADOImport = true }) {
                            Label("Import from ADO", systemImage: "arrow.down.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("More options")
                }
            }
            .padding()
            .padding(.bottom, -8)

            // Advanced mode toggle
            HStack {
                Toggle("Advanced mode", isOn: $isAdvancedMode)
                    .toggleStyle(.switch)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Sort picker — only in advanced mode
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
