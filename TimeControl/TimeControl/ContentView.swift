//
//  ContentView.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit
import AVFoundation

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
    var countdownTime: TimeInterval = 0  // Countdown timer duration in seconds
    var countdownStartTime: Date? = nil  // When the countdown was started
    var countdownElapsedAtPause: TimeInterval = 0  // Elapsed time when last paused
    var lastPlayedAt: TimeInterval? = nil  // Epoch time when play button was last clicked
    
    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, index: Int = 0, totalTimeSpent: TimeInterval = 0, lastStartTime: Date? = nil, description: String = "", dueDate: Date? = nil, isAdhoc: Bool = false, fromWho: String = "", estimatedTime: TimeInterval = 0, subtasks: [Subtask] = [], createdAt: TimeInterval? = nil, startedAt: TimeInterval? = nil, completedAt: TimeInterval? = nil, notes: String = "", countdownTime: TimeInterval = 0, countdownStartTime: Date? = nil, countdownElapsedAtPause: TimeInterval = 0, lastPlayedAt: TimeInterval? = nil) {
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
        self.countdownTime = countdownTime
        self.countdownStartTime = countdownStartTime
        self.countdownElapsedAtPause = countdownElapsedAtPause
        self.lastPlayedAt = lastPlayedAt
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
    
    var countdownElapsed: TimeInterval {
        guard countdownTime > 0, let startTime = countdownStartTime else { return 0 }
        
        if isRunning {
            // Task is currently running - add the paused elapsed time plus time since resume
            let currentSessionElapsed = Date().timeIntervalSince(startTime)
            return min(countdownElapsedAtPause + currentSessionElapsed, countdownTime)
        } else {
            // Task is paused - return the stored elapsed time
            return min(countdownElapsedAtPause, countdownTime)
        }
    }
}

enum TaskSortOption: String, CaseIterable, Identifiable {
    case creationDateNewest = "Newest First"
    case creationDateOldest = "Oldest First"
    case recentlyPlayedNewest = "Recently Played (Newest First)"
    case dueDateNearest = "Due Date (Nearest First)"
    
    var id: String { self.rawValue }
}

enum MassOperationType: String, CaseIterable, Identifiable {
    case fill = "Fill field for tasks"
    case edit = "Edit field for tasks"
    
    var id: String { self.rawValue }
}

enum EditableField: String, CaseIterable, Identifiable {
    case title = "Title"
    case description = "Description"
    case notes = "Notes"
    case fromWho = "From Who"
    case adhoc = "Adhoc"
    case estimation = "Estimation"
    case dueDate = "Due Date"
    
    var id: String { self.rawValue }
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
            
            // Timer-related fields are NOT persisted to storage
            // lastStartTime, countdownStartTime, countdownTime, and countdownElapsedAtPause
            // should not survive app restarts or window closes
            
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
                
                let todo = TodoItem(id: id, text: title, isCompleted: isCompleted, index: index, totalTimeSpent: totalTimeSpent, lastStartTime: nil, description: description, dueDate: dueDate, isAdhoc: isAdhoc, fromWho: fromWho, estimatedTime: estimatedTime, subtasks: subtasks, createdAt: createdAt, startedAt: startedAt, completedAt: completedAt, notes: notes)
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
    @State private var filterText: String = ""  // Text for filtering tasks
    @State private var timerUpdateTrigger = 0  // Used to trigger UI updates for running timers
    @State private var editingTodo: TodoItem?  // Track which todo is being edited
    @State private var expandedTodos: Set<UUID> = []  // Track which todos have expanded subtasks (includes subtask input)
    @State private var newSubtaskTexts: [UUID: String] = [:]  // Text for new subtask per todo
    @FocusState private var subtaskInputFocused: UUID?  // Track focused subtask input
    @State private var isCompletedSectionExpanded: Bool = false  // Track if completed section is expanded
    @State private var runningTaskId: UUID?  // Track the currently running task for floating window
    @State private var isAdvancedMode: Bool = false  // Toggle for advanced mode
    @State private var sortOption: TaskSortOption = .creationDateNewest  // Sort option for tasks
    @State private var showingMassOperations: Bool = false  // Track if mass operations sheet is shown
    @State private var showingSettings: Bool = false  // Track if settings sheet is shown
    
    // User Settings
    @AppStorage("activateReminders") private var activateReminders: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init() {
        // Load todos from storage on initialization
        _todos = State(initialValue: TodoStorage.load())
    }
    
    // Computed properties to separate incomplete and completed todos
    private var incompleteTodos: [TodoItem] {
        let filtered = todos.filter { !$0.isCompleted }
        let filteredItems = filterTodos(filtered)
        return sortTodos(filteredItems)
    }
    
    private var completedTodos: [TodoItem] {
        let filtered = todos.filter { $0.isCompleted }
        let filteredItems = filterTodos(filtered)
        return sortTodos(filteredItems)
    }
    
    // Sort todos based on the selected sort option
    private func sortTodos(_ items: [TodoItem]) -> [TodoItem] {
        guard isAdvancedMode else {
            // When not in advanced mode, maintain original order (by index)
            return items.sorted { $0.index < $1.index }
        }
        
        switch sortOption {
        case .creationDateNewest:
            // Sort by creation date (newest first)
            return items.sorted { $0.createdAt > $1.createdAt }
        case .creationDateOldest:
            // Sort by creation date (oldest first)
            return items.sorted { $0.createdAt < $1.createdAt }
        case .recentlyPlayedNewest:
            // Sort by recently played (tasks that have been started) - newest first
            // Tasks that have never been played go to the bottom
            return items.sorted { todo1, todo2 in
                let hasPlayed1 = todo1.lastPlayedAt != nil
                let hasPlayed2 = todo2.lastPlayedAt != nil
                
                // If both have been played, sort by most recent play time (newest first)
                if hasPlayed1 && hasPlayed2 {
                    return (todo1.lastPlayedAt ?? 0) > (todo2.lastPlayedAt ?? 0)
                }
                // If only one has been played, prioritize it
                if hasPlayed1 { return true }
                if hasPlayed2 { return false }
                // If neither has been played, sort by creation date (newest first)
                return todo1.createdAt > todo2.createdAt
            }
        case .dueDateNearest:
            // Sort by due date (nearest first)
            // Tasks with due dates are prioritized, tasks without go to the bottom
            return items.sorted { todo1, todo2 in
                let hasDueDate1 = todo1.dueDate != nil
                let hasDueDate2 = todo2.dueDate != nil
                
                // If both have due dates, sort by nearest (earliest) date first
                if hasDueDate1 && hasDueDate2 {
                    return (todo1.dueDate ?? Date()) < (todo2.dueDate ?? Date())
                }
                // If only one has a due date, prioritize it
                if hasDueDate1 { return true }
                if hasDueDate2 { return false }
                // If neither has a due date, sort by creation date (newest first)
                return todo1.createdAt > todo2.createdAt
            }
        }
    }
    
    // Filter todos based on filter text (case insensitive)
    private func filterTodos(_ items: [TodoItem]) -> [TodoItem] {
        guard !filterText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return items
        }
        
        let searchText = filterText.lowercased()
        return items.filter { todo in
            // Search in task title
            if todo.text.lowercased().contains(searchText) {
                return true
            }
            
            // Search in task description
            if todo.description.lowercased().contains(searchText) {
                return true
            }
            
            // Search in task notes
            if todo.notes.lowercased().contains(searchText) {
                return true
            }
            
            // Search in "from who" field
            if todo.fromWho.lowercased().contains(searchText) {
                return true
            }
            
            // Search for "adhoc" keyword
            if todo.isAdhoc && "adhoc".contains(searchText) {
                return true
            }
            
            
            // Search in subtask titles
            if todo.subtasks.contains(where: { $0.title.lowercased().contains(searchText) }) {
                return true
            }
            
            // Search in subtask descriptions
            if todo.subtasks.contains(where: { $0.description.lowercased().contains(searchText) }) {
                return true
            }
            
            return false
        }
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
            
            // Filter text field
            HStack {
                TextField("Filter tasks...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                
                if !filterText.isEmpty {
                    Button(action: {
                        filterText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Advanced mode toggle
            HStack {
                Toggle("Advanced mode", isOn: $isAdvancedMode)
                    .toggleStyle(.switch)
                    .font(.subheadline)
                
                if isAdvancedMode {
                    Spacer()
                    
                    Button(action: {
                        showingMassOperations = true
                    }) {
                        HStack {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Mass Operations")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        let exportText = generateExportTextForAllTasks()
                        ExportWindowManager.shared.showExportWindow(with: exportText)
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All Tasks")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .font(.subheadline)
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
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Sort", selection: $sortOption) {
                        ForEach(TaskSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.subheadline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            
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
                                        isAdvancedMode: isAdvancedMode,
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
                                                    TextField("Subtask title...", text: Binding(
                                                        get: { newSubtaskTexts[todo.id] ?? "" },
                                                        set: { newSubtaskTexts[todo.id] = $0 }
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
                                                    .disabled((newSubtaskTexts[todo.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
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
                                                            isAdvancedMode: isAdvancedMode,
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
                                                                        TextField("Subtask title...", text: Binding(
                                                                            get: { newSubtaskTexts[todo.id] ?? "" },
                                                                            set: { newSubtaskTexts[todo.id] = $0 }
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
                                                                        .disabled((newSubtaskTexts[todo.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
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
                
                // Note: Timer completion is handled by the floating window
                // The floating window will notify ContentView when to clear timer fields
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddSubtaskFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID,
                  let subtaskTitle = userInfo["subtaskTitle"] as? String else {
                return
            }
            
            // Add the subtask to the main todos array
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }) {
                let newSubtask = Subtask(title: subtaskTitle, description: "")
                todos[todoIndex].subtasks.append(newSubtask)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CompleteTaskFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID else {
                return
            }
            
            // Complete the task in the main todos array
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }) {
                // Use the existing toggleTodo functionality to mark as complete
                let todo = todos[todoIndex]
                toggleTodo(todo)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PauseTaskFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID else {
                return
            }
            
            let keepWindowOpen = userInfo["keepWindowOpen"] as? Bool ?? false
            
            // Pause the task in the main todos array
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }) {
                // Stop the timer - accumulate time spent
                if let startTime = todos[todoIndex].lastStartTime {
                    todos[todoIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[todoIndex].lastStartTime = nil
                
                // Update countdown elapsed time when pausing
                if todos[todoIndex].countdownTime > 0, let countdownStart = todos[todoIndex].countdownStartTime {
                    let sessionElapsed = Date().timeIntervalSince(countdownStart)
                    todos[todoIndex].countdownElapsedAtPause += sessionElapsed
                    todos[todoIndex].countdownStartTime = nil
                }
                
                saveTodos()
                
                // Only close window if not keeping it open
                if !keepWindowOpen {
                    runningTaskId = nil
                    FloatingWindowManager.shared.closeFloatingWindow()
                } else {
                    // Update the floating window with the paused state
                    FloatingWindowManager.shared.updateTask(todos[todoIndex])
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResumeTaskFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID else {
                return
            }
            
            // Resume the task in the main todos array
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }) {
                // Start the timer for this task
                todos[todoIndex].lastStartTime = Date()
                
                // Resume countdown timer if it's set and not completed
                if todos[todoIndex].countdownTime > 0 && todos[todoIndex].countdownElapsedAtPause < todos[todoIndex].countdownTime {
                    todos[todoIndex].countdownStartTime = Date()
                }
                
                // Set startedAt timestamp if this is the first time starting
                if todos[todoIndex].startedAt == nil {
                    todos[todoIndex].startedAt = Date().timeIntervalSince1970
                }
                
                // Update lastPlayedAt timestamp every time play is clicked (for "Recently Played" sorting)
                todos[todoIndex].lastPlayedAt = Date().timeIntervalSince1970
                
                runningTaskId = taskId
                saveTodos()
                
                // Update the floating window with the resumed state
                FloatingWindowManager.shared.updateTask(todos[todoIndex])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetCountdownFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID,
                  let countdownTime = userInfo["countdownTime"] as? TimeInterval else {
                return
            }
            
            // Set the countdown timer for the task
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }) {
                todos[todoIndex].countdownTime = countdownTime
                todos[todoIndex].countdownStartTime = Date()
                todos[todoIndex].countdownElapsedAtPause = 0  // Reset elapsed time for new timer
                saveTodos()
                
                // Update the floating window with the new task state
                FloatingWindowManager.shared.updateTask(todos[todoIndex])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearCountdownFromFloatingWindow"))) { notification in
            guard let userInfo = notification.userInfo,
                  let taskId = userInfo["taskId"] as? UUID else {
                return
            }
            
            // Clear the countdown timer for the task
            if let todoIndex = todos.firstIndex(where: { $0.id == taskId }) {
                todos[todoIndex].countdownTime = 0
                todos[todoIndex].countdownStartTime = nil
                todos[todoIndex].countdownElapsedAtPause = 0
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
        .sheet(isPresented: $showingMassOperations) {
            MassOperationsSheet(todos: $todos, onSave: {
                saveTodos()
            })
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(activateReminders: $activateReminders)
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
                
                // Update countdown elapsed time when pausing
                if todos[index].countdownTime > 0, let countdownStart = todos[index].countdownStartTime {
                    let sessionElapsed = Date().timeIntervalSince(countdownStart)
                    todos[index].countdownElapsedAtPause += sessionElapsed
                    todos[index].countdownStartTime = nil
                }
                
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
                        
                        // Update countdown elapsed time for the other task
                        if todos[i].countdownTime > 0, let countdownStart = todos[i].countdownStartTime {
                            let sessionElapsed = Date().timeIntervalSince(countdownStart)
                            todos[i].countdownElapsedAtPause += sessionElapsed
                            todos[i].countdownStartTime = nil
                        }
                    }
                }
                
                // Start the timer for this task
                todos[index].lastStartTime = Date()
                
                // Resume countdown timer if it's set and not completed
                if todos[index].countdownTime > 0 && todos[index].countdownElapsedAtPause < todos[index].countdownTime {
                    todos[index].countdownStartTime = Date()
                }
                
                runningTaskId = todo.id
                FloatingWindowManager.shared.showFloatingWindow(for: todos[index])
                
                // Set startedAt timestamp if this is the first time starting
                if todos[index].startedAt == nil {
                    todos[index].startedAt = Date().timeIntervalSince1970
                }
                
                // Update lastPlayedAt timestamp every time play is clicked (for "Recently Played" sorting)
                todos[index].lastPlayedAt = Date().timeIntervalSince1970
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
        let trimmedTitle = (newSubtaskTexts[todo.id] ?? "").trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            let newSubtask = Subtask(title: trimmedTitle, description: "")
            todos[index].subtasks.append(newSubtask)
            
            // Clear the input for this specific task and refocus for rapid succession
            newSubtaskTexts[todo.id] = ""
            
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
            newSubtaskTexts[todo.id] = ""
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
    
    private func generateExportTextForTask(_ todo: TodoItem) -> String {
        var text = ""
        
        // Title
        text += "TASK: \(todo.text)\n"
        text += String(repeating: "=", count: todo.text.count + 6) + "\n\n"
        
        // Status
        text += "Status: \(todo.isCompleted ? "✓ Completed" : "○ In Progress")\n"
        if todo.isRunning {
            text += "Currently Running: Yes\n"
        }
        text += "\n"
        
        // Description
        if !todo.description.isEmpty {
            text += "Description:\n"
            text += todo.description + "\n\n"
        }
        
        // Task Info
        if todo.isAdhoc || !todo.fromWho.isEmpty {
            text += "Task Info:\n"
            if todo.isAdhoc {
                text += "  • Type: Adhoc Task\n"
            }
            if !todo.fromWho.isEmpty {
                text += "  • From: \(todo.fromWho)\n"
            }
            text += "\n"
        }
        
        // Time tracking
        text += "Time Tracking:\n"
        text += "  • Time Spent: \(formatTime(todo.currentTimeSpent))\n"
        if todo.estimatedTime > 0 {
            text += "  • Estimated: \(formatTime(todo.estimatedTime))\n"
            let progress = (todo.currentTimeSpent / todo.estimatedTime) * 100
            text += "  • Progress: \(String(format: "%.1f", progress))%\n"
            if todo.currentTimeSpent > todo.estimatedTime {
                let over = todo.currentTimeSpent - todo.estimatedTime
                text += "  • Over by: \(formatTime(over))\n"
            }
        }
        if todo.countdownTime > 0 {
            text += "  • Countdown: \(formatTime(todo.countdownTime))\n"
            text += "  • Countdown Elapsed: \(formatTime(todo.countdownElapsed))\n"
        }
        text += "\n"
        
        // Dates
        text += "Important Dates:\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let createdDate = Date(timeIntervalSince1970: todo.createdAt)
        text += "  • Created: \(dateFormatter.string(from: createdDate))\n"
        
        if let startedAt = todo.startedAt {
            let startedDate = Date(timeIntervalSince1970: startedAt)
            text += "  • First Started: \(dateFormatter.string(from: startedDate))\n"
        }
        
        if let lastPlayedAt = todo.lastPlayedAt {
            let lastPlayedDate = Date(timeIntervalSince1970: lastPlayedAt)
            text += "  • Last Played: \(dateFormatter.string(from: lastPlayedDate))\n"
        }
        
        if let dueDate = todo.dueDate {
            text += "  • Due: \(dateFormatter.string(from: dueDate))\n"
            let now = Date()
            if now > dueDate {
                let overdue = now.timeIntervalSince(dueDate)
                text += "  • Status: Overdue by \(formatTimeRemaining(overdue))\n"
            } else {
                let remaining = dueDate.timeIntervalSince(now)
                text += "  • Time Remaining: \(formatTimeRemaining(remaining))\n"
            }
        }
        
        if let completedAt = todo.completedAt {
            let completedDate = Date(timeIntervalSince1970: completedAt)
            text += "  • Completed: \(dateFormatter.string(from: completedDate))\n"
        }
        text += "\n"
        
        // Subtasks
        if !todo.subtasks.isEmpty {
            let completedCount = todo.subtasks.filter { $0.isCompleted }.count
            text += "Subtasks (\(completedCount)/\(todo.subtasks.count) completed):\n"
            for (index, subtask) in todo.subtasks.enumerated() {
                let checkbox = subtask.isCompleted ? "✓" : "○"
                text += "  \(index + 1). \(checkbox) \(subtask.title)\n"
                if !subtask.description.isEmpty {
                    text += "     \(subtask.description)\n"
                }
            }
            text += "\n"
        }
        
        // Notes
        if !todo.notes.isEmpty {
            text += "Notes:\n"
            text += todo.notes + "\n\n"
        }
        
        return text
    }
    
    private func generateExportTextForAllTasks() -> String {
        var text = ""
        
        // Header
        text += String(repeating: "=", count: 80) + "\n"
        text += "TIME CONTROL - ALL TASKS EXPORT\n"
        text += String(repeating: "=", count: 80) + "\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .long
        text += "Exported on: \(dateFormatter.string(from: Date()))\n"
        text += "Total tasks: \(todos.count)\n"
        
        let completedCount = todos.filter { $0.isCompleted }.count
        text += "Completed: \(completedCount)\n"
        text += "In progress: \(todos.count - completedCount)\n"
        
        let totalTimeSpent = todos.reduce(0) { $0 + $1.currentTimeSpent }
        text += "Total time spent: \(formatTime(totalTimeSpent))\n\n"
        
        text += String(repeating: "=", count: 80) + "\n\n"
        
        // Incomplete tasks first
        let incompleteTasks = todos.filter { !$0.isCompleted }
        if !incompleteTasks.isEmpty {
            text += "INCOMPLETE TASKS (\(incompleteTasks.count))\n"
            text += String(repeating: "-", count: 80) + "\n\n"
            
            for (index, todo) in incompleteTasks.enumerated() {
                text += "[\(index + 1)/\(incompleteTasks.count)]\n\n"
                text += generateExportTextForTask(todo)
                text += String(repeating: "-", count: 80) + "\n\n"
            }
        }
        
        // Completed tasks
        let completedTasks = todos.filter { $0.isCompleted }
        if !completedTasks.isEmpty {
            text += "COMPLETED TASKS (\(completedTasks.count))\n"
            text += String(repeating: "-", count: 80) + "\n\n"
            
            for (index, todo) in completedTasks.enumerated() {
                text += "[\(index + 1)/\(completedTasks.count)]\n\n"
                text += generateExportTextForTask(todo)
                text += String(repeating: "-", count: 80) + "\n\n"
            }
        }
        
        // Footer
        text += String(repeating: "=", count: 80) + "\n"
        text += "END OF EXPORT\n"
        text += String(repeating: "=", count: 80) + "\n"
        
        return text
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
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let absInterval = abs(timeInterval)
        let days = Int(absInterval) / 86400
        let hours = Int(absInterval) / 3600 % 24
        let minutes = Int(absInterval) / 60 % 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
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
    let isAdvancedMode: Bool  // Show advanced information
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onToggleTimer: () -> Void
    let onEdit: () -> Void
    let onToggleExpanded: () -> Void
    let onToggleSubtask: (Subtask) -> Void
    let onDeleteSubtask: (Subtask) -> Void
    let onEditSubtask: (Subtask) -> Void
    
    @State private var showExportText: Bool = false
    
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
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let absInterval = abs(timeInterval)
        let days = Int(absInterval) / 86400
        let hours = Int(absInterval) / 3600 % 24
        let minutes = Int(absInterval) / 60 % 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func dueDateProgress() -> (elapsed: TimeInterval, total: TimeInterval, isOverdue: Bool) {
        guard let dueDate = todo.dueDate else {
            return (0, 0, false)
        }
        
        let createdDate = Date(timeIntervalSince1970: todo.createdAt)
        let now = Date()
        let total = dueDate.timeIntervalSince(createdDate)
        let elapsed = now.timeIntervalSince(createdDate)
        let isOverdue = now > dueDate
        
        return (elapsed, total, isOverdue)
    }
    
    private func generateExportText() -> String {
        var text = ""
        
        // Title
        text += "TASK: \(todo.text)\n"
        text += String(repeating: "=", count: todo.text.count + 6) + "\n\n"
        
        // Status
        text += "Status: \(todo.isCompleted ? "✓ Completed" : "○ In Progress")\n"
        if todo.isRunning {
            text += "Currently Running: Yes\n"
        }
        text += "\n"
        
        // Description
        if !todo.description.isEmpty {
            text += "Description:\n"
            text += todo.description + "\n\n"
        }
        
        // Task Info
        if todo.isAdhoc || !todo.fromWho.isEmpty {
            text += "Task Info:\n"
            if todo.isAdhoc {
                text += "  • Type: Adhoc Task\n"
            }
            if !todo.fromWho.isEmpty {
                text += "  • From: \(todo.fromWho)\n"
            }
            text += "\n"
        }
        
        // Time tracking
        text += "Time Tracking:\n"
        text += "  • Time Spent: \(formatTime(todo.currentTimeSpent))\n"
        if todo.estimatedTime > 0 {
            text += "  • Estimated: \(formatTime(todo.estimatedTime))\n"
            let progress = (todo.currentTimeSpent / todo.estimatedTime) * 100
            text += "  • Progress: \(String(format: "%.1f", progress))%\n"
            if todo.currentTimeSpent > todo.estimatedTime {
                let over = todo.currentTimeSpent - todo.estimatedTime
                text += "  • Over by: \(formatTime(over))\n"
            }
        }
        if todo.countdownTime > 0 {
            text += "  • Countdown: \(formatTime(todo.countdownTime))\n"
            text += "  • Countdown Elapsed: \(formatTime(todo.countdownElapsed))\n"
        }
        text += "\n"
        
        // Dates
        text += "Important Dates:\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let createdDate = Date(timeIntervalSince1970: todo.createdAt)
        text += "  • Created: \(dateFormatter.string(from: createdDate))\n"
        
        if let startedAt = todo.startedAt {
            let startedDate = Date(timeIntervalSince1970: startedAt)
            text += "  • First Started: \(dateFormatter.string(from: startedDate))\n"
        }
        
        if let lastPlayedAt = todo.lastPlayedAt {
            let lastPlayedDate = Date(timeIntervalSince1970: lastPlayedAt)
            text += "  • Last Played: \(dateFormatter.string(from: lastPlayedDate))\n"
        }
        
        if let dueDate = todo.dueDate {
            text += "  • Due: \(dateFormatter.string(from: dueDate))\n"
            let now = Date()
            if now > dueDate {
                let overdue = now.timeIntervalSince(dueDate)
                text += "  • Status: Overdue by \(formatTimeRemaining(overdue))\n"
            } else {
                let remaining = dueDate.timeIntervalSince(now)
                text += "  • Time Remaining: \(formatTimeRemaining(remaining))\n"
            }
        }
        
        if let completedAt = todo.completedAt {
            let completedDate = Date(timeIntervalSince1970: completedAt)
            text += "  • Completed: \(dateFormatter.string(from: completedDate))\n"
        }
        text += "\n"
        
        // Subtasks
        if !todo.subtasks.isEmpty {
            let completedCount = todo.subtasks.filter { $0.isCompleted }.count
            text += "Subtasks (\(completedCount)/\(todo.subtasks.count) completed):\n"
            for (index, subtask) in todo.subtasks.enumerated() {
                let checkbox = subtask.isCompleted ? "✓" : "○"
                text += "  \(index + 1). \(checkbox) \(subtask.title)\n"
                if !subtask.description.isEmpty {
                    text += "     \(subtask.description)\n"
                }
            }
            text += "\n"
        }
        
        // Notes
        if !todo.notes.isEmpty {
            text += "Notes:\n"
            text += todo.notes + "\n\n"
        }
        
        // Footer
        text += String(repeating: "-", count: 50) + "\n"
        text += "Exported on: \(dateFormatter.string(from: Date()))\n"
        
        return text
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                        .fontWeight(todo.isRunning ? .semibold : .regular)
                    
                    if todo.totalTimeSpent > 0 || todo.isRunning {
                        HStack(spacing: 4) {
                            if todo.isRunning {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.8)
                            }
                            Text(formatTime(todo.currentTimeSpent))
                                .font(.caption)
                                .foregroundColor(todo.isRunning ? .orange : .secondary)
                                .monospacedDigit()
                                .fontWeight(todo.isRunning ? .semibold : .regular)
                                .id(timerUpdateTrigger)  // Force update when trigger changes
                        }
                    }
                    
                    // Show estimate and time elapsed as numbers when advanced mode is on and not expanded
                    if isAdvancedMode && !isExpanded && todo.estimatedTime > 0 {
                        HStack(spacing: 8) {
                            Text("Est: \(formatTime(todo.estimatedTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Elapsed: \(formatTime(todo.currentTimeSpent))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .id(timerUpdateTrigger)
                        }
                    }
                    
                    // Show due date information when advanced mode is on and not expanded
                    if isAdvancedMode && !isExpanded, let dueDate = todo.dueDate {
                        let progress = dueDateProgress()
                        let now = Date()
                        let remaining = dueDate.timeIntervalSince(now)
                        
                        HStack(spacing: 8) {
                            Text("Due: \(formatDueDate(dueDate))")
                                .font(.caption)
                                .foregroundColor(progress.isOverdue ? .red : .secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if progress.isOverdue {
                                Text("Overdue by \(formatTimeRemaining(remaining))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("\(formatTimeRemaining(remaining)) left")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
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
            
            // Description (shown when expanded and advanced mode is on and description is not empty)
            if isAdvancedMode && isExpanded && !todo.description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(todo.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            
            // Notes (shown when expanded and advanced mode is on and notes is not empty)
            if isAdvancedMode && isExpanded && !todo.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(todo.notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            
            // Task metadata (shown when expanded and advanced mode is on)
            if isAdvancedMode && isExpanded && (todo.isAdhoc || !todo.fromWho.isEmpty) {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Info")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if todo.isAdhoc {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("Adhoc Task")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if !todo.fromWho.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("From: \(todo.fromWho)")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            
            // Progress bar (shown when expanded and advanced mode is on and estimated time is set)
            if isAdvancedMode && isExpanded && todo.estimatedTime > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Time indicators
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Elapsed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(formatTime(todo.currentTimeSpent))
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                    .monospacedDigit()
                                    .id(timerUpdateTrigger)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Estimated")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(formatTime(todo.estimatedTime))
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                    .cornerRadius(3)
                                
                                // Progress
                                let progress = min(todo.currentTimeSpent / todo.estimatedTime, 1.0)
                                Rectangle()
                                    .fill(progress > 1.0 ? Color.orange : Color.blue)
                                    .frame(width: geometry.size.width * progress, height: 6)
                                    .cornerRadius(3)
                                    .id(timerUpdateTrigger)
                            }
                        }
                        .frame(height: 6)
                        
                        // Over/under time indicator
                        if todo.currentTimeSpent > todo.estimatedTime {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text("Over by \(formatTime(todo.currentTimeSpent - todo.estimatedTime))")
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
                                Text("Remaining \(formatTime(todo.estimatedTime - todo.currentTimeSpent))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                    .id(timerUpdateTrigger)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            
            // Due date progress bar (shown when expanded and advanced mode is on and due date is set)
            if isAdvancedMode && isExpanded, let dueDate = todo.dueDate {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        let progress = dueDateProgress()
                        let now = Date()
                        let createdDate = Date(timeIntervalSince1970: todo.createdAt)
                        
                        // Time indicators
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Created")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(formatDueDate(createdDate))
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Due")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(formatDueDate(dueDate))
                                    .font(.title3)
                                    .foregroundColor(progress.isOverdue ? .red : .secondary)
                            }
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                    .cornerRadius(3)
                                
                                // Progress
                                let progressValue = progress.total > 0 ? min(progress.elapsed / progress.total, 1.0) : 0
                                Rectangle()
                                    .fill(progress.isOverdue ? Color.red : Color.purple)
                                    .frame(width: geometry.size.width * progressValue, height: 6)
                                    .cornerRadius(3)
                            }
                        }
                        .frame(height: 6)
                        
                        // Time remaining/overdue indicator
                        let remaining = dueDate.timeIntervalSince(now)
                        if progress.isOverdue {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text("Overdue by \(formatTimeRemaining(remaining))")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        } else {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                Text("\(formatTimeRemaining(remaining)) remaining")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            
            // Export to text section (shown when expanded and advanced mode is on)
            if isAdvancedMode && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            showExportText.toggle()
                        }) {
                            HStack {
                                Image(systemName: showExportText ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Export to Text")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if showExportText {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Copy the text below:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextEditor(text: .constant(generateExportText()))
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 300)
                                    .border(Color.gray.opacity(0.3), width: 1)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(todo.isRunning ? 
                      Color.orange.opacity(0.12) : 
                      Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    todo.isRunning ? Color.orange.opacity(0.4) : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: todo.isRunning ? Color.orange.opacity(0.2) : Color.clear, 
                radius: 4, x: 0, y: 2)
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
    @State private var notes: String
    
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
        _notes = State(initialValue: todo.wrappedValue.notes)
        
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 150, maxHeight: 300)
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
        todo.notes = notes
        
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

struct MassOperationsSheet: View {
    @Binding var todos: [TodoItem]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var operationType: MassOperationType = .fill
    @State private var selectedField: EditableField = .title
    @State private var showingEditor: Bool = false
    
    // Local edit dictionaries for different field types
    @State private var textValues: [UUID: String] = [:]
    @State private var boolValues: [UUID: Bool] = [:]
    @State private var estimateHours: [UUID: Int] = [:]
    @State private var estimateMinutes: [UUID: Int] = [:]
    @State private var dueDates: [UUID: Date] = [:]
    @State private var hasDueDate: [UUID: Bool] = [:]
    
    // Computed property to get filtered tasks
    private var filteredTasks: [TodoItem] {
        let incompleteTasks = todos.filter { !$0.isCompleted }
        
        if operationType == .edit {
            // Edit mode: return all incomplete tasks
            return incompleteTasks
        } else {
            // Fill mode: return only tasks where the selected field is empty
            return incompleteTasks.filter { task in
                switch selectedField {
                case .title:
                    return task.text.trimmingCharacters(in: .whitespaces).isEmpty
                case .description:
                    return task.description.isEmpty
                case .notes:
                    return task.notes.isEmpty
                case .fromWho:
                    return task.fromWho.isEmpty
                case .adhoc:
                    return task.isAdhoc == false
                case .estimation:
                    return task.estimatedTime == 0
                case .dueDate:
                    return task.dueDate == nil
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                if showingEditor {
                    Button("Back") {
                        showingEditor = false
                    }
                } else {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                Spacer()
                
                Text("Mass Operations")
                    .font(.headline)
                
                Spacer()
                
                // Placeholder for symmetry
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .hidden()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if !showingEditor {
                // Phase 1: Operation type and field selection
                phase1View
            } else {
                // Phase 2: Task editor view
                phase2View
            }
        }
        .frame(minWidth: showingEditor ? 600 : 400, minHeight: showingEditor ? 500 : 350)
    }
    
    private var phase1View: some View {
        Form {
            Section(header: Text("Operation Type")) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(MassOperationType.allCases) { type in
                        Button(action: {
                            operationType = type
                        }) {
                            HStack {
                                Image(systemName: operationType == type ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(operationType == type ? .accentColor : .secondary)
                                Text(type.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Select Field")) {
                Picker("Field", selection: $selectedField) {
                    ForEach(EditableField.allCases) { field in
                        Text(field.rawValue).tag(field)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section {
                Button(action: {
                    handleContinue()
                }) {
                    HStack {
                        Spacer()
                        Text("Continue")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
    }
    
    private var phase2View: some View {
        VStack(spacing: 0) {
            if filteredTasks.isEmpty {
                // No tasks found message
                VStack {
                    Spacer()
                    Text("No tasks found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(operationType == .fill ? "All tasks already have this field filled" : "No incomplete tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // Scrollable list of tasks with editors
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(filteredTasks) { task in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(task.text)
                                    .font(.headline)
                                
                                fieldEditor(for: task)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Save button
                HStack {
                    Spacer()
                    Button(action: {
                        handleSave()
                    }) {
                        Text("Save")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
    
    @ViewBuilder
    private func fieldEditor(for task: TodoItem) -> some View {
        switch selectedField {
        case .title:
            TextField("Title", text: Binding(
                get: { textValues[task.id] ?? "" },
                set: { textValues[task.id] = $0 }
            ))
            
        case .description:
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: Binding(
                    get: { textValues[task.id] ?? "" },
                    set: { textValues[task.id] = $0 }
                ))
                .frame(minHeight: 100, maxHeight: 150)
                .border(Color.gray.opacity(0.2), width: 1)
            }
            
        case .notes:
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: Binding(
                    get: { textValues[task.id] ?? "" },
                    set: { textValues[task.id] = $0 }
                ))
                .frame(minHeight: 100, maxHeight: 150)
                .border(Color.gray.opacity(0.2), width: 1)
            }
            
        case .fromWho:
            TextField("From Who?", text: Binding(
                get: { textValues[task.id] ?? "" },
                set: { textValues[task.id] = $0 }
            ))
            
        case .adhoc:
            Toggle("Adhoc Task", isOn: Binding(
                get: { boolValues[task.id] ?? false },
                set: { boolValues[task.id] = $0 }
            ))
            
        case .estimation:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: Binding(
                        get: { estimateHours[task.id] ?? 0 },
                        set: { estimateHours[task.id] = $0 }
                    )) {
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
                    Picker("", selection: Binding(
                        get: { estimateMinutes[task.id] ?? 0 },
                        set: { estimateMinutes[task.id] = $0 }
                    )) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
            }
            
        case .dueDate:
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Set Due Date", isOn: Binding(
                    get: { hasDueDate[task.id] ?? false },
                    set: { hasDueDate[task.id] = $0 }
                ))
                
                if hasDueDate[task.id] ?? false {
                    DatePicker("Date & Time", selection: Binding(
                        get: { dueDates[task.id] ?? Date() },
                        set: { dueDates[task.id] = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                }
            }
        }
    }
    
    private func handleContinue() {
        let tasks = filteredTasks
        
        // Initialize local dictionaries with current values
        for task in tasks {
            switch selectedField {
            case .title:
                textValues[task.id] = task.text
            case .description:
                textValues[task.id] = task.description
            case .notes:
                textValues[task.id] = task.notes
            case .fromWho:
                textValues[task.id] = task.fromWho
            case .adhoc:
                boolValues[task.id] = task.isAdhoc
            case .estimation:
                let totalMinutes = Int(task.estimatedTime / 60)
                estimateHours[task.id] = totalMinutes / 60
                estimateMinutes[task.id] = totalMinutes % 60
            case .dueDate:
                if let dueDate = task.dueDate {
                    dueDates[task.id] = dueDate
                    hasDueDate[task.id] = true
                } else {
                    dueDates[task.id] = Date()
                    hasDueDate[task.id] = false
                }
            }
        }
        
        showingEditor = true
    }
    
    private func handleSave() {
        // Write dictionary values back to todos binding
        for task in filteredTasks {
            if let index = todos.firstIndex(where: { $0.id == task.id }) {
                switch selectedField {
                case .title:
                    if let value = textValues[task.id] {
                        todos[index].text = value
                    }
                case .description:
                    if let value = textValues[task.id] {
                        todos[index].description = value
                    }
                case .notes:
                    if let value = textValues[task.id] {
                        todos[index].notes = value
                    }
                case .fromWho:
                    if let value = textValues[task.id] {
                        todos[index].fromWho = value
                    }
                case .adhoc:
                    if let value = boolValues[task.id] {
                        todos[index].isAdhoc = value
                    }
                case .estimation:
                    let hours = estimateHours[task.id] ?? 0
                    let minutes = estimateMinutes[task.id] ?? 0
                    let clampedHours = max(0, hours)
                    let clampedMinutes = max(0, min(59, minutes))
                    todos[index].estimatedTime = TimeInterval((clampedHours * 3600) + (clampedMinutes * 60))
                case .dueDate:
                    if hasDueDate[task.id] ?? false {
                        todos[index].dueDate = dueDates[task.id]
                    } else {
                        todos[index].dueDate = nil
                    }
                }
            }
        }
        
        onSave()
        dismiss()
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
    private var windowDelegate: FloatingWindowDelegate?
    
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
        
        // Set up the window delegate to handle close button
        let delegate = FloatingWindowDelegate(taskId: task.id)
        window.delegate = delegate
        windowDelegate = delegate  // Keep a strong reference
        
        floatingWindow = window
        window.orderFrontRegardless()
    }
    
    func closeFloatingWindow() {
        floatingWindow?.close()
        floatingWindow = nil
        currentTask = nil
        windowDelegate = nil
    }
    
    func updateTask(_ task: TodoItem) {
        currentTask = task
    }
}

class ExportWindowManager: ObservableObject {
    static let shared = ExportWindowManager()
    private var exportWindow: NSWindow?
    
    func showExportWindow(with exportText: String) {
        // Close existing window if any
        closeExportWindow()
        
        // Create the SwiftUI view
        let contentView = ExportAllTasksView(exportText: exportText)
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (center of screen)
        guard let screen = NSScreen.main else { return }
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 600
        
        let xPos = screen.visibleFrame.midX - windowWidth / 2
        let yPos = screen.visibleFrame.midY - windowHeight / 2
        
        // Create a standard window
        let window = NSWindow(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Export All Tasks"
        window.contentView = hostingView
        window.minSize = NSSize(width: 400, height: 300)
        
        exportWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    
    func closeExportWindow() {
        exportWindow?.close()
        exportWindow = nil
    }
}

struct ExportAllTasksView: View {
    let exportText: String
    @State private var isCopied: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Export All Tasks")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportText, forType: .string)
                    isCopied = true
                    
                    // Reset the copied state after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    HStack {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied!" : "Copy All")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Text content
            ScrollView {
                TextEditor(text: .constant(exportText))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Window delegate to handle window close button
class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    let taskId: UUID
    
    init(taskId: UUID) {
        self.taskId = taskId
        super.init()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Check if the task is currently running
        let isTaskRunning = FloatingWindowManager.shared.currentTask?.isRunning ?? false
        
        // If the task is already paused, just close the window without asking
        if !isTaskRunning {
            return true
        }
        
        // If the task is running, show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Pause Task?"
        alert.informativeText = "Do you want to pause the task timer?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Pause Task")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // User clicked "Pause Task" - notify to pause the task and close window
            NotificationCenter.default.post(
                name: NSNotification.Name("PauseTaskFromFloatingWindow"),
                object: nil,
                userInfo: ["taskId": taskId, "keepWindowOpen": false]
            )
            return true
        } else {
            // User clicked "Cancel" - don't close the window
            return false
        }
    }
}

struct FloatingTaskWindowView: View {
    let task: TodoItem
    @ObservedObject var windowManager: FloatingWindowManager
    @State private var localTask: TodoItem
    @State private var isCollapsed: Bool = false
    @State private var notesText: String = ""
    @State private var timerUpdateTrigger = 0  // Used to trigger UI updates for running timer
    @State private var notesWindow: NSWindow?
    @State private var newSubtaskText: String = ""  // Text for new subtask
    @FocusState private var subtaskInputFocused: Bool  // Track focused subtask input
    @State private var showingTimerPicker: Bool = false  // Show timer picker sheet
    @State private var timerHours: Int = 0  // Hours for countdown timer
    @State private var timerMinutes: Int = 25  // Minutes for countdown timer (default 25)
    @State private var timerJustCompleted: Bool = false  // Track if timer just completed
    @State private var showTimerCompletedMessage: Bool = false  // Show "Timer's up!" message
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(task: TodoItem, windowManager: FloatingWindowManager) {
        self.task = task
        self.windowManager = windowManager
        self._localTask = State(initialValue: task)
        self._notesText = State(initialValue: task.notes)
        
        // Initialize timer hours/minutes from existing countdown time
        if task.countdownTime > 0 {
            let totalMinutes = Int(task.countdownTime / 60)
            self._timerHours = State(initialValue: totalMinutes / 60)
            self._timerMinutes = State(initialValue: totalMinutes % 60)
        }
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
                
                Button(action: {
                    openMainWindow()
                }) {
                    Image(systemName: "macwindow")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Open main window")
                
                Button(action: {
                    openNotesWindow()
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
                
                Spacer()
                
                Button(action: {
                    showingTimerPicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text("Timer")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Set a countdown timer")

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
                    }
                    
                    // Timer's up! message (shown after timer completes and is cleared)
                    if showTimerCompletedMessage {
                        VStack(spacing: 8) {
                            Divider()
                            
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.red)
                                    
                                    Text("Timer's up!")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    
                                    Button(action: {
                                        withAnimation {
                                            showTimerCompletedMessage = false
                                        }
                                    }) {
                                        Text("Dismiss")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Countdown Timer section (if set)
                    if localTask.countdownTime > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Timer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                HStack {
                                    // Show elapsed time
                                    Text(formatTime(localTask.countdownElapsed))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(localTask.countdownElapsed >= localTask.countdownTime ? .red : .orange)
                                        .monospacedDigit()
                                        .id(timerUpdateTrigger)
                                    
                                    Text("/")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                    
                                    Text(formatTime(localTask.countdownTime))
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                    
                                    Spacer()
                                    
                                    if localTask.countdownElapsed >= localTask.countdownTime {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bell.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            Text("Time's up!")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                
                                // Progress bar for countdown (fills up as time progresses)
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 6)
                                            .cornerRadius(3)
                                        
                                        // Progress (fills up as time elapses)
                                        let progress = localTask.countdownTime > 0 ? min(localTask.countdownElapsed / localTask.countdownTime, 1.0) : 0
                                        Rectangle()
                                            .fill(progress >= 1.0 ? Color.red : Color.orange)
                                            .frame(width: geometry.size.width * progress, height: 6)
                                            .cornerRadius(3)
                                            .id(timerUpdateTrigger)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                    
                    // Subtasks section
                    Divider()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subtasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            // Textfield and button for adding new subtasks
                            HStack(spacing: 8) {
                                TextField("Subtask title...", text: $newSubtaskText)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($subtaskInputFocused)
                                    .onSubmit {
                                        addSubtask()
                                    }
                                
                                Button(action: {
                                    addSubtask()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .disabled(newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.bottom, 4)
                            
                            // Existing subtasks
                            if !localTask.subtasks.isEmpty {
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
                    
                    // Pause/Resume and Complete buttons at the bottom
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Spacer()
                        
                        Button(action: {
                            if localTask.isRunning {
                                pauseTask()
                            } else {
                                resumeTask()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: localTask.isRunning ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.body)
                                Text(localTask.isRunning ? "Pause" : "Resume")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(localTask.isRunning ? Color.orange : Color.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help(localTask.isRunning ? "Pause this task" : "Resume this task")
                        
                        Button(action: {
                            completeTask()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body)
                                Text("Complete")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Mark this task as complete")
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
            
            // Check if countdown timer has completed
            if localTask.isRunning && localTask.countdownTime > 0 && !timerJustCompleted {
                let elapsed = localTask.countdownElapsed
                if elapsed >= localTask.countdownTime {
                    // Countdown completed - mark as just completed
                    timerJustCompleted = true
                    
                    // Play notification sound
                    NSSound.beep()
                    
                    // Show the "Timer's up!" message with animation
                    withAnimation {
                        showTimerCompletedMessage = true
                    }
                    
                    // Clear all timer fields locally after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        localTask.countdownTime = 0
                        localTask.countdownStartTime = nil
                        localTask.countdownElapsedAtPause = 0
                        
                        // Notify ContentView to clear timer fields in storage
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ClearCountdownFromFloatingWindow"),
                            object: nil,
                            userInfo: ["taskId": localTask.id]
                        )
                    }
                }
            }
        }
        .onChange(of: windowManager.currentTask) { newTask in
            if let newTask = newTask {
                // Don't overwrite localTask if timer just completed (let it finish the completion process)
                if timerJustCompleted && localTask.countdownTime == 0 {
                    // Timer already cleared locally, just update other fields
                    localTask.text = newTask.text
                    localTask.description = newTask.description
                    localTask.subtasks = newTask.subtasks
                    localTask.totalTimeSpent = newTask.totalTimeSpent
                    localTask.lastStartTime = newTask.lastStartTime
                    localTask.estimatedTime = newTask.estimatedTime
                    notesText = newTask.notes
                } else {
                    // Normal update
                    localTask = newTask
                    notesText = newTask.notes
                }
                
                // If timer was cleared externally (from ContentView), reset completion flags
                if newTask.countdownTime == 0 && timerJustCompleted {
                    timerJustCompleted = false
                }
                
                // If a new timer was set externally, reset flags
                if newTask.countdownTime > 0 && newTask.countdownElapsedAtPause == 0 {
                    timerJustCompleted = false
                    showTimerCompletedMessage = false
                }
            }
        }
        .sheet(isPresented: $showingTimerPicker) {
            TimerPickerSheet(
                hours: $timerHours,
                minutes: $timerMinutes,
                onSet: {
                    setCountdownTimer()
                },
                onCancel: {
                    showingTimerPicker = false
                }
            )
        }
    }
    
    private func openMainWindow() {
        // Find and activate the main window
        if let mainWindow = NSApp.windows.first(where: { $0.title == "TimeControl" || $0.isMainWindow }) {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func openNotesWindow() {
        // Close existing notes window if any
        notesWindow?.close()
        
        // Create the SwiftUI view for notes editor
        let contentView = NotesEditorView(notes: $notesText, taskId: localTask.id, onClose: {
            notesWindow?.close()
            notesWindow = nil
        })
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (next to the floating task window)
        guard let taskWindow = NSApp.windows.first(where: { $0.title == "Current Task" }) else { return }
        let taskFrame = taskWindow.frame
        
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 400
        
        // Position to the left of the task window
        let xPos = taskFrame.minX - windowWidth - 20
        let yPos = taskFrame.minY
        
        // Create a floating window for notes
        let window = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Task Notes"
        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 300, height: 200)
        
        notesWindow = window
        window.orderFrontRegardless()
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
    
    private func addSubtask() {
        let trimmedTitle = newSubtaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let newSubtask = Subtask(title: trimmedTitle, description: "")
        localTask.subtasks.append(newSubtask)
        
        // Notify ContentView to add the subtask to the main todos array
        NotificationCenter.default.post(
            name: NSNotification.Name("AddSubtaskFromFloatingWindow"),
            object: nil,
            userInfo: ["taskId": localTask.id, "subtaskTitle": trimmedTitle]
        )
        
        // Clear the input and refocus for rapid succession
        newSubtaskText = ""
        
        // Refocus the textbox after a brief delay to ensure UI is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            subtaskInputFocused = true
        }
    }
    
    private func completeTask() {
        // Mark the task as complete in the main todos array
        NotificationCenter.default.post(
            name: NSNotification.Name("CompleteTaskFromFloatingWindow"),
            object: nil,
            userInfo: ["taskId": localTask.id]
        )
    }
    
    private func pauseTask() {
        // Pause the task by notifying the main view to stop the timer (but don't close window)
        NotificationCenter.default.post(
            name: NSNotification.Name("PauseTaskFromFloatingWindow"),
            object: nil,
            userInfo: ["taskId": localTask.id, "keepWindowOpen": true]
        )
    }
    
    private func resumeTask() {
        // Resume the task by notifying the main view to restart the timer
        NotificationCenter.default.post(
            name: NSNotification.Name("ResumeTaskFromFloatingWindow"),
            object: nil,
            userInfo: ["taskId": localTask.id]
        )
    }
    
    private func setCountdownTimer() {
        // Calculate total countdown time in seconds
        let totalSeconds = TimeInterval((timerHours * 3600) + (timerMinutes * 60))
        
        // Reset completion flags when setting a new timer
        timerJustCompleted = false
        showTimerCompletedMessage = false
        
        // Notify ContentView to set the countdown timer
        NotificationCenter.default.post(
            name: NSNotification.Name("SetCountdownFromFloatingWindow"),
            object: nil,
            userInfo: ["taskId": localTask.id, "countdownTime": totalSeconds]
        )
        
        showingTimerPicker = false
    }
}

struct TimerPickerSheet: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    let onSet: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Set Countdown Timer")
                    .font(.headline)
                
                Spacer()
                
                Button("Set") {
                    onSet()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hours == 0 && minutes == 0)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Timer picker
            VStack(spacing: 20) {
                Text("Choose the countdown duration")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $hours) {
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
                        Picker("", selection: $minutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }
                }
                .padding(.vertical)
                
                if hours > 0 || minutes > 0 {
                    Text("Timer will count down while the task is running")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 250)
    }
}

struct NotesEditorView: View {
    @Binding var notes: String
    let taskId: UUID
    let onClose: () -> Void
    @State private var localNotes: String
    
    init(notes: Binding<String>, taskId: UUID, onClose: @escaping () -> Void) {
        self._notes = notes
        self.taskId = taskId
        self.onClose = onClose
        self._localNotes = State(initialValue: notes.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                Button("Cancel") {
                    onClose()
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
        
        onClose()
    }
}

struct SettingsSheet: View {
    @Binding var activateReminders: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Settings")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Settings content
            VStack(alignment: .leading, spacing: 20) {
                Text("Preferences")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Toggle("Activate reminders to stay on task", isOn: $activateReminders)
                    .toggleStyle(.checkbox)
                    .font(.body)
                
                Text("When enabled, you'll receive periodic reminders to help you stay focused on your current task.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 500, minHeight: 250)
    }
}

#Preview {
    ContentView()
}
