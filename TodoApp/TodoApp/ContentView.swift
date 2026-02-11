//
//  ContentView.swift
//  TodoApp
//
//  Created on 2/11/26.
//

import SwiftUI

struct TodoItem: Identifiable {
    let id = UUID()
    var text: String
    var isCompleted: Bool = false
}

struct ContentView: View {
    @State private var todos: [TodoItem] = []
    @State private var newTodoText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Text field at the top for adding new todos
            HStack {
                TextField("Add a new todo...", text: $newTodoText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTodo()
                    }
                
                Button(action: addTodo) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            
            Divider()
            
            // Scrollable list of todos
            if todos.isEmpty {
                VStack {
                    Spacer()
                    Text("No todos yet")
                        .foregroundColor(.secondary)
                        .font(.title2)
                    Text("Add one using the text field above")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(todos) { todo in
                            TodoRow(todo: todo, onToggle: {
                                toggleTodo(todo)
                            }, onDelete: {
                                deleteTodo(todo)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func addTodo() {
        let trimmedText = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        let newTodo = TodoItem(text: trimmedText)
        todos.append(newTodo)
        newTodoText = ""
    }
    
    private func toggleTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
        }
    }
    
    private func deleteTodo(_ todo: TodoItem) {
        todos.removeAll { $0.id == todo.id }
    }
}

struct TodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            Text(todo.text)
                .strikethrough(todo.isCompleted)
                .foregroundColor(todo.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
