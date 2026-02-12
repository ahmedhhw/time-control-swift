//
//  ContentView.swift
//  TodoApp
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

struct Subtask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), title: String, description: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
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
    var subtasks: [Subtask] = []  // Subtasks for this todo
    var createdAt: TimeInterval  // Epoch time when task was created
    var startedAt: TimeInterval? = nil  // Epoch time when task timer was first started
    var completedAt: TimeInterval? = nil  // Epoch time when task was marked completed
    var notes: String = ""  // Notes taken while working on the task
    
    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.isCompleted == rhs.isCompleted &&
        lhs.subtasks == rhs.subtasks &&
        lhs.totalTimeSpent == rhs.totalTimeSpent &&
        lhs.lastStartTime == rhs.lastStartTime
    }
    
    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, index: Int = 0, totalTimeSpent: TimeInterval = 0, lastStartTime: Date? = nil, description: String = "", dueDate: Date? = nil, isAdhoc: Bool = false, fromWho: String = "", estimatedTime: TimeInterval = 0, subtasks: [Subtask] = [], createdAt: TimeInterval? = nil, startedAt: TimeInterval? = nil, completedAt: TimeInterval? = nil, notes: String = "") {
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
        self.subtasks = subtasks
        self.createdAt = createdAt ?? Date().timeIntervalSince1970
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
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
                "estimatedTime": todo.estimatedTime,
                "createdAt": todo.createdAt,
                "notes": todo.notes
            ]
            
            if let lastStartTime = todo.lastStartTime {
                taskData["lastStartTime"] = lastStartTime.timeIntervalSince1970
            }
            
            if let dueDate = todo.dueDate {
                taskData["dueDate"] = dueDate.timeIntervalSince1970
            }
            
            if let startedAt = todo.startedAt {
                taskData["startedAt"] = startedAt
            }
            
            if let completedAt = todo.completedAt {
                taskData["completedAt"] = completedAt
            }
            
            // Save subtasks
            var subtasksArray: [[String: Any]] = []
            for subtask in todo.subtasks {
                subtasksArray.append([
                    "id": subtask.id.uuidString,
                    "title": subtask.title,
                    "description": subtask.description,
                    "isCompleted": subtask.isCompleted
                ])
            }
            taskData["subtasks"] = subtasksArray
            
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
                let createdAt = taskData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                let startedAt = taskData["startedAt"] as? TimeInterval
                let completedAt = taskData["completedAt"] as? TimeInterval
                let notes = taskData["notes"] as? String ?? ""
                
                var lastStartTime: Date? = nil
                if let timestamp = taskData["lastStartTime"] as? TimeInterval {
                    lastStartTime = Date(timeIntervalSince1970: timestamp)
                }
                
                var dueDate: Date? = nil
                if let timestamp = taskData["dueDate"] as? TimeInterval {
                    dueDate = Date(timeIntervalSince1970: timestamp)
                }
                
                // Load subtasks
                var subtasks: [Subtask] = []
                if let subtasksArray = taskData["subtasks"] as? [[String: Any]] {
                    for subtaskData in subtasksArray {
                        guard let subtaskIdString = subtaskData["id"] as? String,
                              let subtaskId = UUID(uuidString: subtaskIdString),
                              let subtaskTitle = subtaskData["title"] as? String else {
                            continue
                        }
                        let subtaskDescription = subtaskData["description"] as? String ?? ""
                        let subtaskIsCompleted = subtaskData["isCompleted"] as? Bool ?? false
                        subtasks.append(Subtask(id: subtaskId, title: subtaskTitle, description: subtaskDescription, isCompleted: subtaskIsCompleted))
                    }
                }
                
                let todo = TodoItem(id: id, text: title, isCompleted: isCompleted, index: index, totalTimeSpent: totalTimeSpent, lastStartTime: lastStartTime, description: description, dueDate: dueDate, isAdhoc: isAdhoc, fromWho: fromWho, estimatedTime: estimatedTime, subtasks: subtasks, createdAt: createdAt, startedAt: startedAt, completedAt: completedAt, notes: notes)
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
    @State private var expandedTodos: Set<UUID> = []  // Track which todos have expanded subtasks (includes subtask input)
    @State private var newSubtaskText: String = ""  // Text for new subtask
    @FocusState private var subtaskInputFocused: UUID?  // Track focused subtask input
    @State private var isCompletedSectionExpanded: Bool = false  // Track if completed section is expanded
    @State private var runningTaskId: UUID?  // Track the currently running task for floating window
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init() {
        // Load todos from storage on initialization
        _todos = State(initialValue: TodoStorage.load())
    }
    
    // Computed properties to separate incomplete and completed todos
    private var incompleteTodos: [TodoItem] {
        todos.filter { !$0.isCompleted }
    }
    
    private var completedTodos: [TodoItem] {
        todos.filter { $0.isCompleted }
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
            
            // Main content area with incomplete todos
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
                VStack(spacing: 0) {
                    // Scrollable incomplete todos
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            // Incomplete todos
                            ForEach(incompleteTodos) { todo in
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    TodoRow(
                                        todo: todo,
                                        timerUpdateTrigger: timerUpdateTrigger,
                                        isExpanded: expandedTodos.contains(todo.id),
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
                                        },
                                        onToggleExpanded: {
                                            toggleExpanded(todo)
                                        },
                                        onToggleSubtask: { subtask in
                                            toggleSubtask(subtask, in: todo)
                                        },
                                        onDeleteSubtask: { subtask in
                                            deleteSubtask(subtask, from: todo)
                                        },
                                        onEditSubtask: { subtask in
                                            editSubtask(subtask, in: todo)
                                        }
                                    )
                                    
                                    // Expanded area with inline subtask input and existing subtasks
                                    if expandedTodos.contains(todo.id) {
                                        VStack(spacing: 4) {
                                            // Inline subtask input textbox (only show for incomplete tasks)
                                            if !todo.isCompleted {
                                                HStack(spacing: 8) {
                                                    TextField("Subtask title...", text: $newSubtaskText)
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
                                                    .disabled(newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty)
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
                                                        onToggle: { toggleSubtask(subtask, in: todo) },
                                                        onDelete: { deleteSubtask(subtask, from: todo) }
                                                    )
                                                    .padding(.horizontal, 12)
                                                }
                                                .padding(.bottom, 4)
                                            }
                                        }
                                    }
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .draggable(todo.id.uuidString) {
                                // Preview shown while dragging
                                TodoRow(
                                    todo: todo,
                                    timerUpdateTrigger: timerUpdateTrigger,
                                    isExpanded: false,
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
                    
                    // Pinned completed section at the bottom
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
                                            .font(.caption)
                                        
                                        Text("Completed (\(completedTodos.count))")
                                            .foregroundColor(.secondary)
                                            .font(.headline)
                                        
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
                                                            },
                                                            onToggleExpanded: {
                                                                toggleExpanded(todo)
                                                            },
                                                            onToggleSubtask: { subtask in
                                                                toggleSubtask(subtask, in: todo)
                                                            },
                                                            onDeleteSubtask: { subtask in
                                                                deleteSubtask(subtask, from: todo)
                                                            },
                                                            onEditSubtask: { subtask in
                                                                editSubtask(subtask, in: todo)
                                                            }
                                                        )
                                                        
                                                        // Expanded area with inline subtask input and existing subtasks
                                                        if expandedTodos.contains(todo.id) {
                                                            VStack(spacing: 4) {
                                                                // Inline subtask input textbox (only show for incomplete tasks)
                                                                if !todo.isCompleted {
                                                                    HStack(spacing: 8) {
                                                                        TextField("Subtask title...", text: $newSubtaskText)
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
                                                                        .disabled(newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty)
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
                                                            onToggle: { toggleSubtask(subtask, in: todo) },
                                                            onDelete: { deleteSubtask(subtask, from: todo) }
                                                        )
                                                        .padding(.horizontal, 12)
                                                    }
                                                    .padding(.bottom, 4)
                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                .transition(.move(edge: .top).combined(with: .opacity))
                                                .draggable(todo.id.uuidString) {
                                                    // Preview shown while dragging
                                                    TodoRow(
                                                        todo: todo,
                                                        timerUpdateTrigger: timerUpdateTrigger,
                                                        isExpanded: false,
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
                                                          let fromIndex = todos.firstIndex(where: { $0.id == droppedId }),
                                                          let toIndex = todos.firstIndex(where: { $0.id == todo.id }) else {
                                                        return false
                                                    }
                                                    
                                                    moveTodo(from: fromIndex, to: toIndex)
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
        .onReceive(timer) { _ in
            // Update UI every second if any timer is running
            if todos.contains(where: { $0.isRunning }) {
                timerUpdateTrigger += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSubtaskFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID,
                  let subtaskId = userInfo["subtaskId"] as? UUID else {
                return
            }
            
            // Toggle the subtask in the main todos array
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }),
               let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) {
                todos[todoIndex].subtasks[subtaskIndex].isCompleted.toggle()
                saveTodos()
                
                // Update the floating window with the new task state
                FloatingWindowManager.shared.updateTask(todos[todoIndex])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateNotesFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID,
                  let notes = userInfo["notes"] as? String else {
                return
            }
            
            // Update the notes in the main todos array
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }) {
                todos[todoIndex].notes = notes
                saveTodos()
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
            
            // Set or clear completedAt timestamp
            if todos[index].isCompleted {
                todos[index].completedAt = Date().timeIntervalSince1970
                
                // Automatically pause timer when task is completed
                if todos[index].isRunning {
                    if let startTime = todos[index].lastStartTime {
                        todos[index].totalTimeSpent += Date().timeIntervalSince(startTime)
                    }
                    todos[index].lastStartTime = nil
                    runningTaskId = nil
                    FloatingWindowManager.shared.closeFloatingWindow()
                }
            } else {
                todos[index].completedAt = nil
            }
            
            // Save to persistent storage
            saveTodos()
        }
    }
    
    private func deleteTodo(_ todo: TodoItem) {
        // Close floating window if this task was running
        if todo.id == runningTaskId {
            runningTaskId = nil
            FloatingWindowManager.shared.closeFloatingWindow()
        }
        
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
                runningTaskId = nil
                FloatingWindowManager.shared.closeFloatingWindow()
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
                runningTaskId = todo.id
                FloatingWindowManager.shared.showFloatingWindow(for: todos[index])
                
                // Set startedAt timestamp if this is the first time starting
                if todos[index].startedAt == nil {
                    todos[index].startedAt = Date().timeIntervalSince1970
                }
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
    
    private func addSubtask(to todo: TodoItem) {
        let trimmedTitle = newSubtaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            let newSubtask = Subtask(title: trimmedTitle, description: "")
            todos[index].subtasks.append(newSubtask)
            
            // Clear the input and refocus for rapid succession
            newSubtaskText = ""
            
            // Refocus the textbox after a brief delay to ensure UI is updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                subtaskInputFocused = todo.id
            }
            
            saveTodos()
            
            // Update floating window if this task is currently running
            if todo.id == runningTaskId {
                FloatingWindowManager.shared.updateTask(todos[index])
            }
        }
    }
    
    private func toggleExpanded(_ todo: TodoItem) {
        if expandedTodos.contains(todo.id) {
            expandedTodos.remove(todo.id)
            newSubtaskText = ""
            subtaskInputFocused = nil
        } else {
            expandedTodos.insert(todo.id)
            
            // Focus the textbox after a brief delay to ensure UI is updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                subtaskInputFocused = todo.id
            }
        }
    }
    
    private func toggleSubtask(_ subtask: Subtask, in todo: TodoItem) {
        if let todoIndex = todos.firstIndex(where: { $0.id == todo.id }),
           let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) {
            todos[todoIndex].subtasks[subtaskIndex].isCompleted.toggle()
            saveTodos()
            
            // Update floating window if this task is currently running
            if todo.id == runningTaskId {
                FloatingWindowManager.shared.updateTask(todos[todoIndex])
            }
        }
    }
    
    private func deleteSubtask(_ subtask: Subtask, from todo: TodoItem) {
        if let todoIndex = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[todoIndex].subtasks.removeAll { $0.id == subtask.id }
            saveTodos()
            
            // Update floating window if this task is currently running
            if todo.id == runningTaskId {
                FloatingWindowManager.shared.updateTask(todos[todoIndex])
            }
        }
    }
    
    private func editSubtask(_ subtask: Subtask, in todo: TodoItem) {
        // Subtask editing can be implemented if needed in the future
        // For now, users can delete and re-add subtasks
    }
}

struct TodoRow: View {
    let todo: TodoItem
    let timerUpdateTrigger: Int  // Used to trigger UI updates
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onToggleTimer: () -> Void
    let onEdit: () -> Void
    let onToggleExpanded: () -> Void
    let onToggleSubtask: (Subtask) -> Void
    let onDeleteSubtask: (Subtask) -> Void
    let onEditSubtask: (Subtask) -> Void
    
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
                
                if !todo.subtasks.isEmpty {
                    Text("\(todo.subtasks.count) subtask\(todo.subtasks.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Chevron button to toggle subtask area (input + existing subtasks)
            Button(action: onToggleExpanded) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            
            Button(action: onToggleTimer) {
                Image(systemName: todo.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(todo.isCompleted ? .gray : (todo.isRunning ? .orange : .blue))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(todo.isCompleted)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(todo.isCompleted ? .gray : .blue)
            }
            .buttonStyle(.plain)
            .disabled(todo.isCompleted)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(todo.isCompleted ? .gray : .red)
            }
            .buttonStyle(.plain)
            .disabled(todo.isCompleted)
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
                
                Section(header: Text("Timestamps")) {
                    HStack {
                        Text("Created:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTimestamp(todo.createdAt))
                    }
                    
                    if let startedAt = todo.startedAt {
                        HStack {
                            Text("Started:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTimestamp(startedAt))
                        }
                    }
                    
                    if let completedAt = todo.completedAt {
                        HStack {
                            Text("Completed:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTimestamp(completedAt))
                        }
                    }
                }
                
                Section(header: Text("Estimate")) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $estimateHours) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour)").tag(hour)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 80)
                        }
                        
                        Text(":")
                            .font(.title2)
                            .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $estimateMinutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 80)
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
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct SubtaskRow: View {
    let subtask: Subtask
    let parentTodoCompleted: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(subtask.isCompleted ? .green : .secondary)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(subtask.title)
                    .font(.body)
                    .strikethrough(subtask.isCompleted)
                    .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                
                if !subtask.description.isEmpty {
                    Text(subtask.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(parentTodoCompleted ? .gray : .red)
            }
            .buttonStyle(.plain)
            .disabled(parentTodoCompleted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

// Floating window manager for showing task outside app borders
class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()
    private var floatingWindow: NSWindow?
    @Published var currentTask: TodoItem?
    
    func showFloatingWindow(for task: TodoItem) {
        // Close existing window if any
        closeFloatingWindow()
        
        // Store the current task
        currentTask = task
        
        // Create the SwiftUI view
        let contentView = FloatingTaskWindowView(task: task, windowManager: self)
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (bottom right of screen with padding)
        guard let screen = NSScreen.main else { return }
        let windowWidth: CGFloat = 350
        let windowHeight: CGFloat = 400
        let padding: CGFloat = 20
        
        let xPos = screen.visibleFrame.maxX - windowWidth - padding
        let yPos = screen.visibleFrame.minY + padding
        
        // Create a floating window
        let window = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Current Task"
        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 100, height: 30)
        
        floatingWindow = window
        window.orderFrontRegardless()
    }
    
    func closeFloatingWindow() {
        floatingWindow?.close()
        floatingWindow = nil
        currentTask = nil
    }
    
    func updateTask(_ task: TodoItem) {
        currentTask = task
    }
}

struct FloatingTaskWindowView: View {
    let task: TodoItem
    @ObservedObject var windowManager: FloatingWindowManager
    @State private var localTask: TodoItem
    @State private var isCollapsed: Bool = false
    @State private var showNotesEditor: Bool = false
    @State private var notesText: String = ""
    @State private var timerUpdateTrigger = 0  // Used to trigger UI updates for running timer
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(task: TodoItem, windowManager: FloatingWindowManager) {
        self.task = task
        self.windowManager = windowManager
        self._localTask = State(initialValue: task)
        self._notesText = State(initialValue: task.notes)
    }
    
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
        VStack(alignment: .leading, spacing: 0) {
            // Collapse/expand button and Notes button at the top
            HStack {
                Spacer()
                
                Button(action: {
                    showNotesEditor = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption)
                        Text("Notes")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Take notes while working on this task")
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.toggle()
                        resizeWindow()
                    }
                }) {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? "Expand" : "Collapse")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Content (hidden when collapsed)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 12) {
                    // Task title
                    Text(localTask.text)
                        .font(.headline)
                        .lineLimit(2)
                    
                    // Task description
                    if !localTask.description.isEmpty {
                        Text(localTask.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Time tracking section
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        
                        HStack(spacing: 16) {
                            // Time elapsed
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Time Elapsed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(formatTime(localTask.currentTimeSpent))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .monospacedDigit()
                                    .id(timerUpdateTrigger)
                            }
                            
                            Spacer()
                            
                            // Estimated time (if set)
                            if localTask.estimatedTime > 0 {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Estimated")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text(formatTime(localTask.estimatedTime))
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        
                        // Progress bar (if estimated time is set)
                        if localTask.estimatedTime > 0 {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)
                                        .cornerRadius(3)
                                    
                                    // Progress
                                    let progress = min(localTask.currentTimeSpent / localTask.estimatedTime, 1.0)
                                    Rectangle()
                                        .fill(progress > 1.0 ? Color.orange : Color.blue)
                                        .frame(width: geometry.size.width * progress, height: 6)
                                        .cornerRadius(3)
                                        .id(timerUpdateTrigger)
                                }
                            }
                            .frame(height: 6)
                            
                            // Over/under time indicator
                            if localTask.currentTimeSpent > localTask.estimatedTime {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("Over by \(formatTime(localTask.currentTimeSpent - localTask.estimatedTime))")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .monospacedDigit()
                                        .id(timerUpdateTrigger)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("Remaining \(formatTime(localTask.estimatedTime - localTask.currentTimeSpent))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                        .id(timerUpdateTrigger)
                                }
                            }
                        }
                    }
                    
                    // Subtasks section
                    if !localTask.subtasks.isEmpty {
                        Divider()
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Subtasks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                ForEach(localTask.subtasks) { subtask in
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            toggleSubtask(subtask)
                                        }) {
                                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(subtask.isCompleted ? .green : .secondary)
                                                .font(.subheadline)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text(subtask.title)
                                            .font(.body)
                                            .strikethrough(subtask.isCompleted)
                                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                                            .lineLimit(2)
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(timer) { _ in
            // Update UI every second for running timer
            timerUpdateTrigger += 1
        }
        .onChange(of: windowManager.currentTask) { newTask in
            if let newTask = newTask {
                localTask = newTask
                notesText = newTask.notes
            }
        }
        .sheet(isPresented: $showNotesEditor) {
            NotesEditorView(notes: $notesText, taskId: localTask.id)
        }
    }
    
    private func resizeWindow() {
        // Get the window from the view hierarchy
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.title == "Current Task" }) else { return }
            
            let currentFrame = window.frame
            let newHeight: CGFloat = isCollapsed ? 50 : 400
            
            // Keep the window anchored at the bottom-left corner and maintain width
            let newY = currentFrame.maxY - newHeight
            let newFrame = NSRect(x: currentFrame.minX, y: newY, width: currentFrame.width, height: newHeight)
            
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
    
    private func toggleSubtask(_ subtask: Subtask) {
        // Find the subtask and toggle it
        if let subtaskIndex = localTask.subtasks.firstIndex(where: { $0.id == subtask.id }) {
            localTask.subtasks[subtaskIndex].isCompleted.toggle()
            
            // Update the stored todos in ContentView
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleSubtaskFromFloatingWindow"),
                object: nil,
                userInfo: ["taskId": localTask.id, "subtaskId": subtask.id]
            )
        }
    }
}

struct NotesEditorView: View {
    @Binding var notes: String
    let taskId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var localNotes: String
    
    init(notes: Binding<String>, taskId: UUID) {
        self._notes = notes
        self.taskId = taskId
        self._localNotes = State(initialValue: notes.wrappedValue)
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
                
                Text("Task Notes")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    saveNotes()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Notes editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Take notes while working on this task")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $localNotes)
                    .font(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.2), width: 1)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func saveNotes() {
        notes = localNotes
        
        // Update the stored todos in ContentView
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateNotesFromFloatingWindow"),
            object: nil,
            userInfo: ["taskId": taskId, "notes": localNotes]
        )
        
        dismiss()
    }
}

#Preview {
    ContentView()
}
