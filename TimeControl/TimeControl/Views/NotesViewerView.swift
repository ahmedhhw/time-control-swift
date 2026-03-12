//
//  NotesViewerView.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct NotesViewerView: View {
    @ObservedObject var viewModel: TodoViewModel
    @State private var selectedTaskId: UUID? = nil
    @State private var searchText: String = ""
    @State private var sortOption: TaskSortOption = .creationDateNewest

    private var filteredTodos: [TodoItem] {
        let searched: [TodoItem]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searched = viewModel.todos
        } else {
            let query = searchText.lowercased()
            searched = viewModel.todos.filter {
                $0.text.lowercased().contains(query) || $0.notes.lowercased().contains(query)
            }
        }
        return sortItems(searched)
    }

    private func sortItems(_ items: [TodoItem]) -> [TodoItem] {
        switch sortOption {
        case .creationDateNewest:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .creationDateOldest:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .recentlyPlayedNewest:
            return items.sorted { a, b in
                if let pa = a.lastPlayedAt, let pb = b.lastPlayedAt { return pa > pb }
                if a.lastPlayedAt != nil { return true }
                if b.lastPlayedAt != nil { return false }
                return a.createdAt > b.createdAt
            }
        case .dueDateNearest:
            return items.sorted { a, b in
                if let da = a.dueDate, let db = b.dueDate { return da < db }
                if a.dueDate != nil { return true }
                if b.dueDate != nil { return false }
                return a.createdAt > b.createdAt
            }
        }
    }

    private var selectedTodo: TodoItem? {
        guard let id = selectedTaskId else { return nil }
        return filteredTodos.first(where: { $0.id == id })
    }

    var body: some View {
        HSplitView {
            // Sidebar: task list
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tasks or notes…", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Sort picker
                HStack {
                    Text("Sort:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $sortOption) {
                        ForEach(TaskSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                if filteredTodos.isEmpty {
                    VStack {
                        Spacer()
                        Text(searchText.isEmpty ? "No tasks" : "No matches")
                            .foregroundColor(.secondary)
                            .font(.callout)
                        Spacer()
                    }
                } else {
                    List(filteredTodos, selection: $selectedTaskId) { todo in
                        TaskNotesSidebarRow(todo: todo, isSelected: selectedTaskId == todo.id, searchQuery: searchText)
                            .tag(todo.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)

            // Detail: note body
            Group {
                if let todo = selectedTodo {
                    NotesDetailView(todo: todo, searchQuery: searchText, onSaveNotes: { id, notes in
                        viewModel.updateNotesFromFloatingWindow(notes, for: id)
                    })
                    .id(todo.id)
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Select a task to view its notes")
                            .foregroundColor(.secondary)
                            .font(.callout)
                            .padding(.top, 8)
                        Spacer()
                    }
                }
            }
            .frame(minWidth: 300)
        }
        .onChange(of: filteredTodos.map { $0.id }) { newIds in
            // If the selected task is filtered out, clear selection
            if let id = selectedTaskId, !newIds.contains(id) {
                selectedTaskId = nil
            }
            // Auto-select first when selection is empty
            if selectedTaskId == nil, let first = newIds.first {
                selectedTaskId = first
            }
        }
        .onAppear {
            if selectedTaskId == nil {
                selectedTaskId = filteredTodos.first?.id
            }
        }
    }
}

// MARK: - Sidebar Row

private struct TaskNotesSidebarRow: View {
    let todo: TodoItem
    let isSelected: Bool
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if todo.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                Text(todo.text)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(isSelected ? .primary : .primary)
            }

            Text(notePreview(todo.notes))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func notePreview(_ notes: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        // If searching, try to show the line that matches
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            let lines = trimmed.components(separatedBy: .newlines)
            if let match = lines.first(where: { $0.lowercased().contains(query) }) {
                return match.trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }
}

// MARK: - Detail View

private struct NotesDetailView: View {
    let todo: TodoItem
    let searchQuery: String
    var onSaveNotes: ((UUID, String) -> Void)? = nil

    @State private var editedNotes: String

    init(todo: TodoItem, searchQuery: String, onSaveNotes: ((UUID, String) -> Void)? = nil) {
        self.todo = todo
        self.searchQuery = searchQuery
        self.onSaveNotes = onSaveNotes
        _editedNotes = State(initialValue: todo.notes)
    }


    private var formattedDate: String {
        if let completedAt = todo.completedAt {
            let date = Date(timeIntervalSince1970: completedAt)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Completed \(formatter.string(from: date))"
        }
        let date = Date(timeIntervalSince1970: todo.createdAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Created \(formatter.string(from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if todo.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    Text(todo.text)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            TextEditor(text: $editedNotes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .padding(8)
                .onChange(of: editedNotes) { newValue in
                    onSaveNotes?(todo.id, newValue)
                }
                .onChange(of: todo.notes) { newValue in
                    if newValue != editedNotes {
                        editedNotes = newValue
                    }
                }
        }
    }
}
