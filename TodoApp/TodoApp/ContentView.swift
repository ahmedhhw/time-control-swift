//
//  ContentView.swift
//  TodoApp
//
//  Created on 2/11/26.
//

import SwiftUI

struct TodoItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var isCompleted: Bool = false
    var index: Int
    
    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, index: Int = 0) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.index = index
    }
}

// Storage Manager for JSON persistence
class TodoStorage {
    private static let storageURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("todos.json")
    }()
    
    // Save todos to JSON file
    static func save(todos: [TodoItem]) {
        // Convert array to dictionary format: { "id": { "title": "text", "index": 0, "isCompleted": false } }
        var tasksDict: [String: [String: Any]] = [:]
        
        for todo in todos {
            let taskData: [String: Any] = [
                "title": todo.text,
                "index": todo.index,
                "isCompleted": todo.isCompleted
            ]
            tasksDict[todo.id.uuidString] = taskData
        }
        
        let jsonData: [String: Any] = ["tasks": tasksDict]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            try data.write(to: storageURL)
        } catch {
            print("Error saving todos: \(error.localizedDescription)")
        }
    }
    
    // Load todos from JSON file
    static func load() -> [TodoItem] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let tasksDict = json?["tasks"] as? [String: [String: Any]] else {
                return []
            }
            
            var todos: [TodoItem] = []
            for (idString, taskData) in tasksDict {
                guard let id = UUID(uuidString: idString),
                      let title = taskData["title"] as? String,
                      let index = taskData["index"] as? Int else {
                    continue
                }
                
                let isCompleted = taskData["isCompleted"] as? Bool ?? false
                let todo = TodoItem(id: id, text: title, isCompleted: isCompleted, index: index)
                todos.append(todo)
            }
            
            // Sort by index to maintain order
            return todos.sorted { $0.index < $1.index }
        } catch {
            print("Error loading todos: \(error.localizedDescription)")
            return []
        }
    }
}

struct ContentView: View {
    @State private var todos: [TodoItem] = []
    @State private var newTodoText: String = ""
    
    init() {
        // Load todos from storage on initialization
        _todos = State(initialValue: TodoStorage.load())
    }
    
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
        
        let newIndex = todos.count
        let newTodo = TodoItem(text: trimmedText, index: newIndex)
        todos.append(newTodo)
        newTodoText = ""
        
        // Save to persistent storage
        saveTodos()
    }
    
    private func toggleTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            
            // Save to persistent storage
            saveTodos()
        }
    }
    
    private func deleteTodo(_ todo: TodoItem) {
        todos.removeAll { $0.id == todo.id }
        
        // Reindex remaining todos
        for (index, _) in todos.enumerated() {
            todos[index].index = index
        }
        
        // Save to persistent storage
        saveTodos()
    }
    
    private func saveTodos() {
        TodoStorage.save(todos: todos)
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
