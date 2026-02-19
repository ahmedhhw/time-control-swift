//
//  TodoViewModel.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import Combine

class TodoViewModel: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var newTodoText: String = ""
    @Published var filterText: String = ""
    @Published var timerUpdateTrigger = 0
    @Published var editingTodo: TodoItem?
    @Published var expandedTodos: Set<UUID> = []
    @Published var newSubtaskTexts: [UUID: String] = [:]
    @Published var isCompletedSectionExpanded: Bool = false
    @Published var runningTaskId: UUID?
    @Published var isAdvancedMode: Bool = false
    @Published var areAllTasksExpanded: Bool = false
    @Published var sortOption: TaskSortOption = .creationDateNewest
    @Published var showingMassOperations: Bool = false
    @Published var showingSettings: Bool = false
    @Published var todoToDelete: TodoItem?
    @Published var subtaskToDelete: (subtask: Subtask, parentTodo: TodoItem)?
    
    @Published var activateReminders: Bool = false
    @Published var confirmTaskDeletion: Bool = true
    @Published var confirmSubtaskDeletion: Bool = true
    @Published var showTimeWhenCollapsed: Bool = false
    @Published var autoPlayAfterSwitching: Bool = false
    @Published var autoPauseAfterMinutes: Int = 0
    
    private var timer: AnyCancellable?
    
    init() {
        self.todos = TodoStorage.load()
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.timerUpdateTrigger += 1
            }
    }
    
    var incompleteTodos: [TodoItem] {
        let filtered = todos.filter { !$0.isCompleted }
        let filteredItems = filterTodos(filtered)
        return sortTodos(filteredItems)
    }
    
    var completedTodos: [TodoItem] {
        let filtered = todos.filter { $0.isCompleted }
        let filteredItems = filterTodos(filtered)
        return sortTodos(filteredItems)
    }
    
    func sortTodos(_ items: [TodoItem]) -> [TodoItem] {
        guard isAdvancedMode else {
            return items.sorted { $0.index < $1.index }
        }
        
        switch sortOption {
        case .creationDateNewest:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .creationDateOldest:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .recentlyPlayedNewest:
            return items.sorted { todo1, todo2 in
                let hasPlayed1 = todo1.lastPlayedAt != nil
                let hasPlayed2 = todo2.lastPlayedAt != nil
                
                if hasPlayed1 && hasPlayed2 {
                    return (todo1.lastPlayedAt ?? 0) > (todo2.lastPlayedAt ?? 0)
                }
                if hasPlayed1 { return true }
                if hasPlayed2 { return false }
                return todo1.createdAt > todo2.createdAt
            }
        case .dueDateNearest:
            return items.sorted { todo1, todo2 in
                let hasDueDate1 = todo1.dueDate != nil
                let hasDueDate2 = todo2.dueDate != nil
                
                if hasDueDate1 && hasDueDate2 {
                    return (todo1.dueDate ?? Date()) < (todo2.dueDate ?? Date())
                }
                if hasDueDate1 { return true }
                if hasDueDate2 { return false }
                return todo1.createdAt > todo2.createdAt
            }
        }
    }
    
    func filterTodos(_ items: [TodoItem]) -> [TodoItem] {
        guard !filterText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return items
        }
        
        let searchText = filterText.lowercased()
        return items.filter { todo in
            if todo.text.lowercased().contains(searchText) { return true }
            if todo.description.lowercased().contains(searchText) { return true }
            if todo.notes.lowercased().contains(searchText) { return true }
            if todo.fromWho.lowercased().contains(searchText) { return true }
            if todo.isAdhoc && "adhoc".contains(searchText) { return true }
            if todo.subtasks.contains(where: { $0.title.lowercased().contains(searchText) }) { return true }
            if todo.subtasks.contains(where: { $0.description.lowercased().contains(searchText) }) { return true }
            return false
        }
    }
    
    func addTodo() {
        let trimmedText = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        let newIndex = todos.count
        let newTodo = TodoItem(text: trimmedText, index: newIndex)
        todos.append(newTodo)
        newTodoText = ""
        saveTodos()
    }
    
    func toggleTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            
            if todos[index].isCompleted {
                if todos[index].isRunning {
                    if let startTime = todos[index].lastStartTime {
                        todos[index].totalTimeSpent += Date().timeIntervalSince(startTime)
                    }
                    todos[index].lastStartTime = nil
                    todos[index].countdownStartTime = nil
                    
                    for i in 0..<todos[index].subtasks.count {
                        if todos[index].subtasks[i].isRunning {
                            if let startTime = todos[index].subtasks[i].lastStartTime {
                                todos[index].subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                            }
                            todos[index].subtasks[i].lastStartTime = nil
                        }
                    }
                    
                    runningTaskId = nil
                    FloatingWindowManager.shared.closeFloatingWindow()
                }
                
                todos[index].completedAt = Date().timeIntervalSince1970
            } else {
                todos[index].completedAt = nil
            }
            
            saveTodos()
        }
    }
    
    func deleteTodo(_ todo: TodoItem) {
        if confirmTaskDeletion {
            todoToDelete = todo
        } else {
            performDeleteTodo(todo)
        }
    }
    
    func performDeleteTodo(_ todo: TodoItem) {
        if todo.id == runningTaskId {
            runningTaskId = nil
            FloatingWindowManager.shared.closeFloatingWindow()
        }
        
        todos.removeAll { $0.id == todo.id }
        
        for (index, _) in todos.enumerated() {
            todos[index].index = index
        }
        
        saveTodos()
    }
    
    func saveTodos() {
        TodoStorage.save(todos: todos)
        FloatingWindowManager.shared.updateAllTodos(todos)
    }
    
    func editTodo(_ todo: TodoItem) {
        editingTodo = todo
    }
    
    func switchToTask(_ newTask: TodoItem) {
        for i in 0..<todos.count {
            if todos[i].isRunning {
                if let startTime = todos[i].lastStartTime {
                    todos[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[i].lastStartTime = nil
                
                if todos[i].countdownTime > 0, let countdownStart = todos[i].countdownStartTime {
                    let sessionElapsed = Date().timeIntervalSince(countdownStart)
                    todos[i].countdownElapsedAtPause += sessionElapsed
                    todos[i].countdownStartTime = nil
                }
                
                for j in 0..<todos[i].subtasks.count {
                    if todos[i].subtasks[j].isRunning {
                        if let startTime = todos[i].subtasks[j].lastStartTime {
                            todos[i].subtasks[j].totalTimeSpent += Date().timeIntervalSince(startTime)
                        }
                        todos[i].subtasks[j].lastStartTime = nil
                    }
                }
            }
        }
        
        if autoPlayAfterSwitching, let index = todos.firstIndex(where: { $0.id == newTask.id }) {
            todos[index].lastStartTime = Date()
            
            if todos[index].countdownTime > 0 && todos[index].countdownElapsedAtPause < todos[index].countdownTime {
                todos[index].countdownStartTime = Date()
            }
            
            runningTaskId = newTask.id
            
            if todos[index].startedAt == nil {
                todos[index].startedAt = Date().timeIntervalSince1970
            }
            
            todos[index].lastPlayedAt = Date().timeIntervalSince1970
            
            saveTodos()
            FloatingWindowManager.shared.updateTask(todos[index])
        } else {
            runningTaskId = nil
            saveTodos()
            
            if let index = todos.firstIndex(where: { $0.id == newTask.id }) {
                FloatingWindowManager.shared.updateTask(todos[index])
            }
        }
    }
    
    func toggleTimer(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            if todos[index].isRunning {
                if let startTime = todos[index].lastStartTime {
                    todos[index].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[index].lastStartTime = nil
                
                if todos[index].countdownTime > 0, let countdownStart = todos[index].countdownStartTime {
                    let sessionElapsed = Date().timeIntervalSince(countdownStart)
                    todos[index].countdownElapsedAtPause += sessionElapsed
                    todos[index].countdownStartTime = nil
                }
                
                for i in 0..<todos[index].subtasks.count {
                    if todos[index].subtasks[i].isRunning {
                        if let startTime = todos[index].subtasks[i].lastStartTime {
                            todos[index].subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                        }
                        todos[index].subtasks[i].lastStartTime = nil
                    }
                }
                
                runningTaskId = nil
                FloatingWindowManager.shared.closeFloatingWindow()
            } else {
                for i in 0..<todos.count {
                    if todos[i].isRunning {
                        if let startTime = todos[i].lastStartTime {
                            todos[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                        }
                        todos[i].lastStartTime = nil
                        
                        if todos[i].countdownTime > 0, let countdownStart = todos[i].countdownStartTime {
                            let sessionElapsed = Date().timeIntervalSince(countdownStart)
                            todos[i].countdownElapsedAtPause += sessionElapsed
                            todos[i].countdownStartTime = nil
                        }
                        
                        for j in 0..<todos[i].subtasks.count {
                            if todos[i].subtasks[j].isRunning {
                                if let startTime = todos[i].subtasks[j].lastStartTime {
                                    todos[i].subtasks[j].totalTimeSpent += Date().timeIntervalSince(startTime)
                                }
                                todos[i].subtasks[j].lastStartTime = nil
                            }
                        }
                    }
                }
                
                todos[index].lastStartTime = Date()
                
                if todos[index].countdownTime > 0 && todos[index].countdownElapsedAtPause < todos[index].countdownTime {
                    todos[index].countdownStartTime = Date()
                }
                
                runningTaskId = todo.id
                FloatingWindowManager.shared.showFloatingWindow(
                    for: todos[index],
                    allTodos: todos,
                    activateReminders: activateReminders,
                    showTimeWhenCollapsed: showTimeWhenCollapsed,
                    autoPlayAfterSwitching: autoPlayAfterSwitching,
                    autoPauseAfterMinutes: autoPauseAfterMinutes,
                    onTaskSwitch: { [weak self] newTask in
                        self?.switchToTask(newTask)
                    }
                )
                
                if todos[index].startedAt == nil {
                    todos[index].startedAt = Date().timeIntervalSince1970
                }
                
                todos[index].lastPlayedAt = Date().timeIntervalSince1970
            }
            
            saveTodos()
        }
    }
    
    func toggleSubtaskTimer(_ subtask: Subtask, in todo: TodoItem) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == todo.id }),
              let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }
        
        guard todos[todoIndex].isRunning else {
            return
        }
        
        if todos[todoIndex].subtasks[subtaskIndex].isRunning {
            if let startTime = todos[todoIndex].subtasks[subtaskIndex].lastStartTime {
                todos[todoIndex].subtasks[subtaskIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
            }
            todos[todoIndex].subtasks[subtaskIndex].lastStartTime = nil
        } else {
            for i in 0..<todos[todoIndex].subtasks.count {
                if todos[todoIndex].subtasks[i].isRunning {
                    if let startTime = todos[todoIndex].subtasks[i].lastStartTime {
                        todos[todoIndex].subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                    }
                    todos[todoIndex].subtasks[i].lastStartTime = nil
                }
            }
            
            todos[todoIndex].subtasks[subtaskIndex].lastStartTime = Date()
        }
        
        saveTodos()
        
        if todo.id == runningTaskId {
            FloatingWindowManager.shared.updateTask(todos[todoIndex])
        }
    }
    
    func moveTodo(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let movedTodo = todos.remove(at: sourceIndex)
            todos.insert(movedTodo, at: destinationIndex)
            
            for (index, _) in todos.enumerated() {
                todos[index].index = index
            }
        }
        
        saveTodos()
    }
    
    func addSubtask(to todo: TodoItem) {
        let trimmedTitle = (newSubtaskTexts[todo.id] ?? "").trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            let newSubtask = Subtask(title: trimmedTitle, description: "")
            todos[index].subtasks.append(newSubtask)
            
            newSubtaskTexts[todo.id] = ""
            
            saveTodos()
            
            if todo.id == runningTaskId {
                FloatingWindowManager.shared.updateTask(todos[index])
            }
        }
    }
    
    func toggleExpanded(_ todo: TodoItem) {
        if expandedTodos.contains(todo.id) {
            expandedTodos.remove(todo.id)
            newSubtaskTexts[todo.id] = ""
            areAllTasksExpanded = false
        } else {
            expandedTodos.insert(todo.id)
            
            let allTaskIds = todos.map { $0.id }
            areAllTasksExpanded = Set(allTaskIds).isSubset(of: expandedTodos)
        }
    }
    
    func toggleExpandAll() {
        if areAllTasksExpanded {
            expandedTodos.removeAll()
            newSubtaskTexts.removeAll()
            areAllTasksExpanded = false
        } else {
            let allTodoIds = todos.map { $0.id }
            expandedTodos = Set(allTodoIds)
            areAllTasksExpanded = true
        }
    }
    
    func toggleSubtask(_ subtask: Subtask, in todo: TodoItem) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == todo.id }),
              let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }
        
        todos[todoIndex].subtasks[subtaskIndex].isCompleted.toggle()
        saveTodos()
        
        if todo.id == runningTaskId {
            FloatingWindowManager.shared.updateTask(todos[todoIndex])
        }
    }
    
    func deleteSubtask(_ subtask: Subtask, from todo: TodoItem) {
        if confirmSubtaskDeletion {
            subtaskToDelete = (subtask: subtask, parentTodo: todo)
        } else {
            performDeleteSubtask(subtask, from: todo)
        }
    }
    
    func performDeleteSubtask(_ subtask: Subtask, from todo: TodoItem) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == todo.id }) else {
            return
        }
        
        todos[todoIndex].subtasks.removeAll { $0.id == subtask.id }
        saveTodos()
        
        if todo.id == runningTaskId {
            FloatingWindowManager.shared.updateTask(todos[todoIndex])
        }
    }
    
    func generateExportTextForTask(_ todo: TodoItem) -> String {
        var text = ""
        
        text += "Task: \(todo.text)\n"
        text += "Status: \(todo.isCompleted ? "✓ Completed" : "○ Incomplete")\n\n"
        
        if !todo.description.isEmpty {
            text += "Description:\n\(todo.description)\n\n"
        }
        
        if !todo.fromWho.isEmpty {
            text += "From: \(todo.fromWho)\n"
        }
        
        if todo.isAdhoc {
            text += "Type: Ad-hoc\n"
        }
        
        if let dueDate = todo.dueDate {
            text += "Due Date: \(TimeFormatter.formatDueDate(dueDate))\n"
        }
        
        text += "\nTime Tracking:\n"
        text += "  • Time Spent: \(TimeFormatter.formatTime(todo.currentTimeSpent))\n"
        if todo.estimatedTime > 0 {
            text += "  • Estimated: \(TimeFormatter.formatTime(todo.estimatedTime))\n"
            let progress = (todo.currentTimeSpent / todo.estimatedTime) * 100
            text += "  • Progress: \(String(format: "%.1f", progress))%\n"
            if todo.currentTimeSpent > todo.estimatedTime {
                let over = todo.currentTimeSpent - todo.estimatedTime
                text += "  • Over by: \(TimeFormatter.formatTime(over))\n"
            }
        }
        
        if todo.countdownTime > 0 {
            text += "  • Countdown: \(TimeFormatter.formatTime(todo.countdownTime))\n"
            text += "  • Countdown Elapsed: \(TimeFormatter.formatTime(todo.countdownElapsed))\n"
        }
        
        if !todo.subtasks.isEmpty {
            let completedCount = todo.subtasks.filter { $0.isCompleted }.count
            let totalSubtaskTime = todo.subtasks.reduce(0.0) { $0 + $1.currentTimeSpent }
            
            text += "\nSubtasks (\(completedCount)/\(todo.subtasks.count) completed, \(TimeFormatter.formatTime(totalSubtaskTime)) total):\n"
            
            for subtask in todo.subtasks {
                let status = subtask.isCompleted ? "✓" : "○"
                text += "  \(status) \(subtask.title)"
                if subtask.totalTimeSpent > 0 {
                    text += " - \(TimeFormatter.formatTime(subtask.totalTimeSpent))"
                }
                text += "\n"
                if !subtask.description.isEmpty {
                    text += "    \(subtask.description)\n"
                }
            }
        }
        
        if !todo.notes.isEmpty {
            text += "\nNotes:\n\(todo.notes)\n"
        }
        
        return text
    }
    
    func generateExportTextForAllTasks() -> String {
        var text = "=== TASKS EXPORT ===\n\n"
        
        let allTasks = sortTodos(todos)
        let incompleteTasks = allTasks.filter { !$0.isCompleted }
        let completedTasks = allTasks.filter { $0.isCompleted }
        
        let totalTasks = allTasks.count
        let completedCount = completedTasks.count
        let incompleteCount = incompleteTasks.count
        let totalTimeSpent = allTasks.reduce(0.0) { $0 + $1.currentTimeSpent }
        
        text += "Summary:\n"
        text += "Total tasks: \(totalTasks)\n"
        text += "Completed: \(completedCount)\n"
        text += "Incomplete: \(incompleteCount)\n"
        text += "Total time spent: \(TimeFormatter.formatTime(totalTimeSpent))\n\n"
        
        text += "======================\n\n"
        
        if !incompleteTasks.isEmpty {
            text += "## INCOMPLETE TASKS ##\n\n"
            for (index, todo) in incompleteTasks.enumerated() {
                text += "[\(index + 1)] "
                text += generateExportTextForTask(todo)
                text += "\n---\n\n"
            }
        }
        
        if !completedTasks.isEmpty {
            text += "## COMPLETED TASKS ##\n\n"
            for (index, todo) in completedTasks.enumerated() {
                text += "[\(index + 1)] "
                text += generateExportTextForTask(todo)
                text += "\n---\n\n"
            }
        }
        
        return text
    }
}
