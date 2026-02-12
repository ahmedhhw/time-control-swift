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
    var totalTimeSpent: TimeInterval = 0  // Total time spent in seconds
    var lastStartTime: Date? = nil  // When the timer was last started
    var description: String = ""  // Detailed description
    var dueDate: Date? = nil  // Due date and time
    var isAdhoc: Bool = false  // Whether this is an adhoc task
    var fromWho: String = ""  // Who this task is from
    var estimatedTime: TimeInterval = 0  // Estimated time to complete in seconds
    
    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, index: Int = 0, totalTimeSpent: TimeInterval = 0, lastStartTime: Date? = nil, description: String = "", dueDate: Date? = nil, isAdhoc: Bool = false, fromWho: String = "", estimatedTime: TimeInterval = 0) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.index = index
        self.totalTimeSpent = totalTimeSpent
        self.lastStartTime = lastStartTime
        self.description = description
        self.dueDate = dueDate
        self.isAdhoc = isAdhoc
        self.fromWho = fromWho
        self.estimatedTime = estimatedTime
    }
    
    var isRunning: Bool {
        lastStartTime != nil
    }
    
    var currentTimeSpent: TimeInterval {
        var time = totalTimeSpent
        if let startTime = lastStartTime {
            time += Date().timeIntervalSince(startTime)
        }
        return time
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
            var taskData: [String: Any] = [
                "title": todo.text,
                "index": todo.index,
                "isCompleted": todo.isCompleted,
                "totalTimeSpent": todo.totalTimeSpent,
                "description": todo.description,
                "isAdhoc": todo.isAdhoc,
                "fromWho": todo.fromWho,
                "estimatedTime": todo.estimatedTime
            ]
            
            if let lastStartTime = todo.lastStartTime {
                taskData["lastStartTime"] = lastStartTime.timeIntervalSince1970
            }
            
            if let dueDate = todo.dueDate {
                taskData["dueDate"] = dueDate.timeIntervalSince1970
            }
            
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
                let totalTimeSpent = taskData["totalTimeSpent"] as? TimeInterval ?? 0
                let description = taskData["description"] as? String ?? ""
                let isAdhoc = taskData["isAdhoc"] as? Bool ?? false
                let fromWho = taskData["fromWho"] as? String ?? ""
                let estimatedTime = taskData["estimatedTime"] as? TimeInterval ?? 0
                
                var lastStartTime: Date? = nil
                if let timestamp = taskData["lastStartTime"] as? TimeInterval {
                    lastStartTime = Date(timeIntervalSince1970: timestamp)
                }
                
                var dueDate: Date? = nil
                if let timestamp = taskData["dueDate"] as? TimeInterval {
                    dueDate = Date(timeIntervalSince1970: timestamp)
                }
                
                let todo = TodoItem(id: id, text: title, isCompleted: isCompleted, index: index, totalTimeSpent: totalTimeSpent, lastStartTime: lastStartTime, description: description, dueDate: dueDate, isAdhoc: isAdhoc, fromWho: fromWho, estimatedTime: estimatedTime)
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
    @State private var timerUpdateTrigger = 0  // Used to trigger UI updates for running timers
    @State private var editingTodo: TodoItem?  // Track which todo is being edited
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
                            TodoRow(
                                todo: todo,
                                timerUpdateTrigger: timerUpdateTrigger,
                                onToggle: {
                                    toggleTodo(todo)
                                },
                                onDelete: {
                                    deleteTodo(todo)
                                },
                                onToggleTimer: {
                                    toggleTimer(todo)
                                },
                                onEdit: {
                                    editTodo(todo)
                                }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .draggable(todo.id.uuidString) {
                                // Preview shown while dragging
                                TodoRow(
                                    todo: todo,
                                    timerUpdateTrigger: timerUpdateTrigger,
                                    onToggle: {},
                                    onDelete: {},
                                    onToggleTimer: {},
                                    onEdit: {}
                                )
                                .opacity(0.8)
                            }
                            .dropDestination(for: String.self) { droppedItems, location in
                                guard let droppedIdString = droppedItems.first,
                                      let droppedId = UUID(uuidString: droppedIdString),
                                      let fromIndex = todos.firstIndex(where: { $0.id == droppedId }),
                                      let toIndex = todos.firstIndex(where: { $0.id == todo.id }) else {
                                    return false
                                }
                                
                                moveTodo(from: fromIndex, to: toIndex)
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
                                      let fromIndex = todos.firstIndex(where: { $0.id == droppedId }) else {
                                    return false
                                }
                                
                                // Move to the last position
                                let lastIndex = todos.count - 1
                                if fromIndex != lastIndex {
                                    moveTodo(from: fromIndex, to: lastIndex)
                                }
                                return true
                            }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: todos.map { $0.id })
                    .padding()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onReceive(timer) { _ in
            // Update UI every second if any timer is running
            if todos.contains(where: { $0.isRunning }) {
                timerUpdateTrigger += 1
            }
        }
        .sheet(item: $editingTodo) { todoToEdit in
            if let index = todos.firstIndex(where: { $0.id == todoToEdit.id }) {
                EditTodoSheet(todo: $todos[index], onSave: {
                    saveTodos()
                    editingTodo = nil
                })
            }
        }
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
    
    private func editTodo(_ todo: TodoItem) {
        editingTodo = todo
    }
    
    private func toggleTimer(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            if todos[index].isRunning {
                // Stop the timer - accumulate time spent
                if let startTime = todos[index].lastStartTime {
                    todos[index].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[index].lastStartTime = nil
            } else {
                // Pause any other running tasks first
                for i in 0..<todos.count {
                    if todos[i].isRunning {
                        if let startTime = todos[i].lastStartTime {
                            todos[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                        }
                        todos[i].lastStartTime = nil
                    }
                }
                
                // Start the timer for this task
                todos[index].lastStartTime = Date()
            }
            
            // Save to persistent storage
            saveTodos()
        }
    }
    
    private func moveTodo(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Move the item in the array
            let movedTodo = todos.remove(at: sourceIndex)
            todos.insert(movedTodo, at: destinationIndex)
            
            // Reindex all todos to maintain correct order
            for (index, _) in todos.enumerated() {
                todos[index].index = index
            }
        }
        
        // Save to persistent storage (without animation)
        saveTodos()
    }
}

struct TodoRow: View {
    let todo: TodoItem
    let timerUpdateTrigger: Int  // Used to trigger UI updates
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onToggleTimer: () -> Void
    let onEdit: () -> Void
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.text)
                    .strikethrough(todo.isCompleted)
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                
                if todo.totalTimeSpent > 0 || todo.isRunning {
                    Text(formatTime(todo.currentTimeSpent))
                        .font(.caption)
                        .foregroundColor(todo.isRunning ? .blue : .secondary)
                        .monospacedDigit()
                        .id(timerUpdateTrigger)  // Force update when trigger changes
                }
            }
            
            Spacer()
            
            Button(action: onToggleTimer) {
                Image(systemName: todo.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(todo.isRunning ? .orange : .blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
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

struct EditTodoSheet: View {
    @Binding var todo: TodoItem
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var isAdhoc: Bool
    @State private var fromWho: String
    @State private var estimateHours: Int
    @State private var estimateMinutes: Int
    
    init(todo: Binding<TodoItem>, onSave: @escaping () -> Void) {
        self._todo = todo
        self.onSave = onSave
        
        // Initialize state from todo
        _title = State(initialValue: todo.wrappedValue.text)
        _description = State(initialValue: todo.wrappedValue.description)
        _dueDate = State(initialValue: todo.wrappedValue.dueDate ?? Date())
        _hasDueDate = State(initialValue: todo.wrappedValue.dueDate != nil)
        _isAdhoc = State(initialValue: todo.wrappedValue.isAdhoc)
        _fromWho = State(initialValue: todo.wrappedValue.fromWho)
        
        // Convert estimated time from seconds to hours and minutes
        let totalMinutes = Int(todo.wrappedValue.estimatedTime / 60)
        _estimateHours = State(initialValue: totalMinutes / 60)
        _estimateMinutes = State(initialValue: totalMinutes % 60)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Edit Task")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Form content
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .frame(minHeight: 100, maxHeight: 200)
                            .border(Color.gray.opacity(0.2), width: 1)
                    }
                }
                
                Section(header: Text("Estimate")) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", value: $estimateHours, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        Text(":")
                            .font(.title2)
                            .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", value: $estimateMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onChange(of: estimateMinutes) { newValue in
                                    // Keep minutes between 0 and 59
                                    if newValue < 0 {
                                        estimateMinutes = 0
                                    } else if newValue >= 60 {
                                        estimateHours += newValue / 60
                                        estimateMinutes = newValue % 60
                                    }
                                }
                        }
                    }
                }
                
                Section(header: Text("Due Date")) {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Date & Time", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section(header: Text("Additional Information")) {
                    Toggle("Adhoc Task", isOn: $isAdhoc)
                    
                    TextField("From Who?", text: $fromWho)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 500, minHeight: 500)
    }
    
    private func saveChanges() {
        todo.text = title
        todo.description = description
        todo.dueDate = hasDueDate ? dueDate : nil
        todo.isAdhoc = isAdhoc
        todo.fromWho = fromWho
        
        // Convert hours and minutes to seconds
        let clampedHours = max(0, estimateHours)
        let clampedMinutes = max(0, min(59, estimateMinutes))
        todo.estimatedTime = TimeInterval((clampedHours * 3600) + (clampedMinutes * 60))
        
        onSave()
        dismiss()
    }
}

#Preview {
    ContentView()
}
