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
    @Published var timerOnTaskSwitch: Bool = false
    @Published var shouldAutoShowTimerPicker: Bool = false
    
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
                    stopSession(todoIndex: index)
                    if let startTime = todos[index].lastStartTime {
                        todos[index].totalTimeSpent += Date().timeIntervalSince(startTime)
                    }
                    todos[index].lastStartTime = nil
                    todos[index].countdownStartTime = nil
                    
                    for i in 0..<todos[index].subtasks.count {
                        if todos[index].subtasks[i].isRunning {
                            stopSubtaskSession(todoIndex: index, subtaskIndex: i)
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
                stopSession(todoIndex: i)
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
                        stopSubtaskSession(todoIndex: i, subtaskIndex: j)
                        if let startTime = todos[i].subtasks[j].lastStartTime {
                            todos[i].subtasks[j].totalTimeSpent += Date().timeIntervalSince(startTime)
                        }
                        todos[i].subtasks[j].lastStartTime = nil
                    }
                }
            }
        }
        
        if autoPlayAfterSwitching, let index = todos.firstIndex(where: { $0.id == newTask.id }) {
            startSession(todoIndex: index)
            todos[index].lastStartTime = Date()
            
            if todos[index].countdownTime > 0 && todos[index].countdownElapsedAtPause < todos[index].countdownTime {
                todos[index].countdownStartTime = Date()
            }
            
            autoStartFirstIncompleteSubtask(at: index)
            
            runningTaskId = newTask.id
            
            if todos[index].startedAt == nil {
                todos[index].startedAt = Date().timeIntervalSince1970
            }
            
            todos[index].lastPlayedAt = Date().timeIntervalSince1970

            if timerOnTaskSwitch && todos[index].countdownTime == 0 {
                DispatchQueue.main.async {
                    self.shouldAutoShowTimerPicker = true
                }
            }

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
                stopSession(todoIndex: index)
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
                        stopSubtaskSession(todoIndex: index, subtaskIndex: i)
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
                        stopSession(todoIndex: i)
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
                                stopSubtaskSession(todoIndex: i, subtaskIndex: j)
                                if let startTime = todos[i].subtasks[j].lastStartTime {
                                    todos[i].subtasks[j].totalTimeSpent += Date().timeIntervalSince(startTime)
                                }
                                todos[i].subtasks[j].lastStartTime = nil
                            }
                        }
                    }
                }
                
                startSession(todoIndex: index)
                todos[index].lastStartTime = Date()
                
                if todos[index].countdownTime > 0 && todos[index].countdownElapsedAtPause < todos[index].countdownTime {
                    todos[index].countdownStartTime = Date()
                }
                
                autoStartFirstIncompleteSubtask(at: index)
                
                runningTaskId = todo.id
                FloatingWindowManager.shared.showFloatingWindow(for: todos[index], viewModel: self)

                if todos[index].startedAt == nil {
                    todos[index].startedAt = Date().timeIntervalSince1970
                }

                todos[index].lastPlayedAt = Date().timeIntervalSince1970

                if timerOnTaskSwitch && todos[index].countdownTime == 0 {
                    DispatchQueue.main.async {
                        self.shouldAutoShowTimerPicker = true
                    }
                }
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
            stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: subtaskIndex)
            if let startTime = todos[todoIndex].subtasks[subtaskIndex].lastStartTime {
                todos[todoIndex].subtasks[subtaskIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
            }
            todos[todoIndex].subtasks[subtaskIndex].lastStartTime = nil
        } else {
            for i in 0..<todos[todoIndex].subtasks.count {
                if todos[todoIndex].subtasks[i].isRunning {
                    stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: i)
                    if let startTime = todos[todoIndex].subtasks[i].lastStartTime {
                        todos[todoIndex].subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                    }
                    todos[todoIndex].subtasks[i].lastStartTime = nil
                }
            }
            
            startSubtaskSession(todoIndex: todoIndex, subtaskIndex: subtaskIndex)
            todos[todoIndex].subtasks[subtaskIndex].lastStartTime = Date()
            
            // Move the started subtask to the top of the non-completed subtasks list
            let startedSubtask = todos[todoIndex].subtasks.remove(at: subtaskIndex)
            if let firstIncompleteIndex = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted }) {
                todos[todoIndex].subtasks.insert(startedSubtask, at: firstIncompleteIndex)
            } else {
                todos[todoIndex].subtasks.append(startedSubtask)
            }
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

        let wasCompleted = todos[todoIndex].subtasks[subtaskIndex].isCompleted
        if wasCompleted {
            // Pause this subtask if it was running
            if todos[todoIndex].subtasks[subtaskIndex].isRunning {
                stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: subtaskIndex)
                if let startTime = todos[todoIndex].subtasks[subtaskIndex].lastStartTime {
                    todos[todoIndex].subtasks[subtaskIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[todoIndex].subtasks[subtaskIndex].lastStartTime = nil
            }

            // Find the next incomplete subtask below this one before reordering
            let nextIncompleteId = todos[todoIndex].subtasks[(subtaskIndex + 1)...]
                .first(where: { !$0.isCompleted })?.id

            let completedSubtask = todos[todoIndex].subtasks[subtaskIndex]
            todos[todoIndex].subtasks.remove(at: subtaskIndex)

            if let firstIncompleteIndex = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted }) {
                todos[todoIndex].subtasks.insert(completedSubtask, at: firstIncompleteIndex)
            } else {
                todos[todoIndex].subtasks.insert(completedSubtask, at: 0)
            }

            // Auto-start the next incomplete subtask if the parent task is running
            if let nextId = nextIncompleteId,
               todos[todoIndex].isRunning,
               let newNextIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == nextId }) {
                startSubtaskSession(todoIndex: todoIndex, subtaskIndex: newNextIndex)
                todos[todoIndex].subtasks[newNextIndex].lastStartTime = Date()

                let startedSubtask = todos[todoIndex].subtasks.remove(at: newNextIndex)
                if let firstIncompleteIdx = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted }) {
                    todos[todoIndex].subtasks.insert(startedSubtask, at: firstIncompleteIdx)
                } else {
                    todos[todoIndex].subtasks.append(startedSubtask)
                }
            }
        }

        saveTodos()

        if todo.id == runningTaskId {
            FloatingWindowManager.shared.updateTask(todos[todoIndex])
        }
    }
    
    // MARK: - Session helpers

    private func startSession(todoIndex: Int) {
        let session = TaskSession(startedAt: Date().timeIntervalSince1970)
        todos[todoIndex].sessions.append(session)
    }

    private func stopSession(todoIndex: Int) {
        guard let last = todos[todoIndex].sessions.indices.last,
              todos[todoIndex].sessions[last].stoppedAt == nil else { return }
        todos[todoIndex].sessions[last].stoppedAt = Date().timeIntervalSince1970
    }

    private func startSubtaskSession(todoIndex: Int, subtaskIndex: Int) {
        let session = TaskSession(startedAt: Date().timeIntervalSince1970)
        todos[todoIndex].subtasks[subtaskIndex].sessions.append(session)
    }

    private func stopSubtaskSession(todoIndex: Int, subtaskIndex: Int) {
        guard let last = todos[todoIndex].subtasks[subtaskIndex].sessions.indices.last,
              todos[todoIndex].subtasks[subtaskIndex].sessions[last].stoppedAt == nil else { return }
        todos[todoIndex].subtasks[subtaskIndex].sessions[last].stoppedAt = Date().timeIntervalSince1970
    }

    /// Starts the timer for the first non-completed subtask of the given task index.
    private func autoStartFirstIncompleteSubtask(at todoIndex: Int) {
        guard let firstIndex = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted && !$0.isRunning }) else {
            return
        }
        startSubtaskSession(todoIndex: todoIndex, subtaskIndex: firstIndex)
        todos[todoIndex].subtasks[firstIndex].lastStartTime = Date()
        
        // Move it to the top of the non-completed list
        let startedSubtask = todos[todoIndex].subtasks.remove(at: firstIndex)
        if let firstIncompleteIndex = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted }) {
            todos[todoIndex].subtasks.insert(startedSubtask, at: firstIncompleteIndex)
        } else {
            todos[todoIndex].subtasks.append(startedSubtask)
        }
    }
    
    func renameSubtask(_ subtask: Subtask, in todo: TodoItem, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let todoIndex = todos.firstIndex(where: { $0.id == todo.id }),
              let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) else {
            return
        }
        todos[todoIndex].subtasks[subtaskIndex].title = trimmed
        saveTodos()
        if todo.id == runningTaskId {
            FloatingWindowManager.shared.updateTask(todos[todoIndex])
        }
    }
    
    func renameSubtaskFromFloatingWindow(_ subtaskId: UUID, in taskId: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let todoIndex = todos.firstIndex(where: { $0.id == taskId }),
              let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            return
        }
        todos[todoIndex].subtasks[subtaskIndex].title = trimmed
        saveTodos()
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
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
    
    func pauseTask(_ taskId: UUID, keepWindowOpen: Bool) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        stopSession(todoIndex: todoIndex)
        if let startTime = todos[todoIndex].lastStartTime {
            todos[todoIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
        }
        todos[todoIndex].lastStartTime = nil
        
        if todos[todoIndex].countdownTime > 0, let countdownStart = todos[todoIndex].countdownStartTime {
            let sessionElapsed = Date().timeIntervalSince(countdownStart)
            todos[todoIndex].countdownElapsedAtPause += sessionElapsed
            todos[todoIndex].countdownStartTime = nil
        }
        
        for i in 0..<todos[todoIndex].subtasks.count {
            if todos[todoIndex].subtasks[i].isRunning {
                stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: i)
                if let startTime = todos[todoIndex].subtasks[i].lastStartTime {
                    todos[todoIndex].subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[todoIndex].subtasks[i].lastStartTime = nil
            }
        }
        
        saveTodos()
        
        if !keepWindowOpen {
            runningTaskId = nil
            FloatingWindowManager.shared.closeFloatingWindow()
        } else {
            FloatingWindowManager.shared.updateTask(todos[todoIndex])
        }
    }
    
    func resumeTask(_ taskId: UUID) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        startSession(todoIndex: todoIndex)
        todos[todoIndex].lastStartTime = Date()
        
        if todos[todoIndex].countdownTime > 0 && todos[todoIndex].countdownElapsedAtPause < todos[todoIndex].countdownTime {
            todos[todoIndex].countdownStartTime = Date()
        }
        
        autoStartFirstIncompleteSubtask(at: todoIndex)
        
        if todos[todoIndex].startedAt == nil {
            todos[todoIndex].startedAt = Date().timeIntervalSince1970
        }
        
        todos[todoIndex].lastPlayedAt = Date().timeIntervalSince1970
        
        runningTaskId = taskId
        saveTodos()
        
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
    }
    
    func updateTaskFields(id: UUID, text: String?, description: String?, notes: String?, dueDate: Date?, isAdhoc: Bool?, fromWho: String?, estimatedTime: TimeInterval?) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        if let text = text {
            todos[todoIndex].text = text
        }
        if let description = description {
            todos[todoIndex].description = description
        }
        if let notes = notes {
            todos[todoIndex].notes = notes
        }
        if let dueDate = dueDate {
            todos[todoIndex].dueDate = dueDate
        } else if dueDate == nil {
            todos[todoIndex].dueDate = nil
        }
        if let isAdhoc = isAdhoc {
            todos[todoIndex].isAdhoc = isAdhoc
        }
        if let fromWho = fromWho {
            todos[todoIndex].fromWho = fromWho
        }
        if let estimatedTime = estimatedTime {
            todos[todoIndex].estimatedTime = estimatedTime
        }
        
        saveTodos()
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
    }
    
    func setCountdown(taskId: UUID, time: TimeInterval) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        todos[todoIndex].countdownTime = time
        todos[todoIndex].countdownStartTime = Date()
        todos[todoIndex].countdownElapsedAtPause = 0
        saveTodos()
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
    }
    
    func clearCountdown(taskId: UUID) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        todos[todoIndex].countdownTime = 0
        todos[todoIndex].countdownStartTime = nil
        todos[todoIndex].countdownElapsedAtPause = 0
        saveTodos()
    }
    
    func createTask(title: String, switchToIt: Bool) {
        let newIndex = todos.count
        let newTodo = TodoItem(text: title, index: newIndex)
        todos.append(newTodo)
        saveTodos()
        
        FloatingWindowManager.shared.updateAllTodos(todos)
        
        if switchToIt {
            if let currentRunningId = runningTaskId,
               let runningIndex = todos.firstIndex(where: { $0.id == currentRunningId }) {
                stopSession(todoIndex: runningIndex)
                if let startTime = todos[runningIndex].lastStartTime {
                    todos[runningIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[runningIndex].lastStartTime = nil
                
                if todos[runningIndex].countdownTime > 0, let countdownStart = todos[runningIndex].countdownStartTime {
                    let sessionElapsed = Date().timeIntervalSince(countdownStart)
                    todos[runningIndex].countdownElapsedAtPause += sessionElapsed
                    todos[runningIndex].countdownStartTime = nil
                }
            }
            
            if let newTaskIndex = todos.firstIndex(where: { $0.id == newTodo.id }) {
                startSession(todoIndex: newTaskIndex)
                todos[newTaskIndex].lastStartTime = Date()
                
                if todos[newTaskIndex].startedAt == nil {
                    todos[newTaskIndex].startedAt = Date().timeIntervalSince1970
                }
                
                todos[newTaskIndex].lastPlayedAt = Date().timeIntervalSince1970
                
                if todos[newTaskIndex].countdownTime > 0 && todos[newTaskIndex].countdownElapsedAtPause < todos[newTaskIndex].countdownTime {
                    todos[newTaskIndex].countdownStartTime = Date()
                }
                
                runningTaskId = newTodo.id
                saveTodos()
                
                FloatingWindowManager.shared.switchToTask(todos[newTaskIndex])
            }
        }
    }
    
    func toggleSubtaskFromFloatingWindow(_ subtaskId: UUID, in taskId: UUID) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }),
              let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            return
        }

        todos[todoIndex].subtasks[subtaskIndex].isCompleted.toggle()

        let wasCompleted = todos[todoIndex].subtasks[subtaskIndex].isCompleted
        if wasCompleted {
            // Pause this subtask if it was running
            if todos[todoIndex].subtasks[subtaskIndex].isRunning {
                stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: subtaskIndex)
                if let startTime = todos[todoIndex].subtasks[subtaskIndex].lastStartTime {
                    todos[todoIndex].subtasks[subtaskIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[todoIndex].subtasks[subtaskIndex].lastStartTime = nil
            }

            // Find the next incomplete subtask below this one before reordering
            let nextIncompleteId = todos[todoIndex].subtasks[(subtaskIndex + 1)...]
                .first(where: { !$0.isCompleted })?.id

            let completedSubtask = todos[todoIndex].subtasks[subtaskIndex]
            todos[todoIndex].subtasks.remove(at: subtaskIndex)

            if let firstIncompleteIndex = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted }) {
                todos[todoIndex].subtasks.insert(completedSubtask, at: firstIncompleteIndex)
            } else {
                todos[todoIndex].subtasks.insert(completedSubtask, at: 0)
            }

            // Auto-start the next incomplete subtask if the parent task is running
            if let nextId = nextIncompleteId,
               todos[todoIndex].isRunning,
               let newNextIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == nextId }) {
                startSubtaskSession(todoIndex: todoIndex, subtaskIndex: newNextIndex)
                todos[todoIndex].subtasks[newNextIndex].lastStartTime = Date()

                let startedSubtask = todos[todoIndex].subtasks.remove(at: newNextIndex)
                if let firstIncompleteIdx = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted }) {
                    todos[todoIndex].subtasks.insert(startedSubtask, at: firstIncompleteIdx)
                } else {
                    todos[todoIndex].subtasks.append(startedSubtask)
                }
            }
        }

        saveTodos()
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
    }
    
    func addSubtaskFromFloatingWindow(to taskId: UUID, title: String) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        let newSubtask = Subtask(title: title, description: "")
        todos[todoIndex].subtasks.append(newSubtask)
        saveTodos()
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
    }
    
    func deleteSubtaskFromFloatingWindow(_ subtaskId: UUID, from taskId: UUID) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        todos[todoIndex].subtasks.removeAll { $0.id == subtaskId }
        saveTodos()
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
    }
    
    func toggleSubtaskTimerFromFloatingWindow(_ subtaskId: UUID, in taskId: UUID) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }),
              let subtaskIndex = todos[todoIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            return
        }
        
        if todos[todoIndex].subtasks[subtaskIndex].isRunning {
            stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: subtaskIndex)
            if let startTime = todos[todoIndex].subtasks[subtaskIndex].lastStartTime {
                todos[todoIndex].subtasks[subtaskIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
            }
            todos[todoIndex].subtasks[subtaskIndex].lastStartTime = nil
        } else {
            for i in 0..<todos[todoIndex].subtasks.count {
                if todos[todoIndex].subtasks[i].isRunning {
                    stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: i)
                    if let startTime = todos[todoIndex].subtasks[i].lastStartTime {
                        todos[todoIndex].subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                    }
                    todos[todoIndex].subtasks[i].lastStartTime = nil
                }
            }
            
            startSubtaskSession(todoIndex: todoIndex, subtaskIndex: subtaskIndex)
            todos[todoIndex].subtasks[subtaskIndex].lastStartTime = Date()
            
            // Move the started subtask to the top of the non-completed subtasks list
            let startedSubtask = todos[todoIndex].subtasks.remove(at: subtaskIndex)
            if let firstIncompleteIndex = todos[todoIndex].subtasks.firstIndex(where: { !$0.isCompleted }) {
                todos[todoIndex].subtasks.insert(startedSubtask, at: firstIncompleteIndex)
            } else {
                todos[todoIndex].subtasks.append(startedSubtask)
            }
        }
        
        saveTodos()
        FloatingWindowManager.shared.updateTask(todos[todoIndex])
    }
    
    func updateNotesFromFloatingWindow(_ notes: String, for taskId: UUID) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        todos[todoIndex].notes = notes
        saveTodos()
    }
    
    func completeTaskFromFloatingWindow(_ taskId: UUID) {
        guard let todoIndex = todos.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        todos[todoIndex].isCompleted.toggle()
        
        if todos[todoIndex].isCompleted {
            todos[todoIndex].completedAt = Date().timeIntervalSince1970
            
            if todos[todoIndex].isRunning {
                stopSession(todoIndex: todoIndex)
                if let startTime = todos[todoIndex].lastStartTime {
                    todos[todoIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[todoIndex].lastStartTime = nil
                runningTaskId = nil
            }
            
            for i in 0..<todos[todoIndex].subtasks.count {
                if todos[todoIndex].subtasks[i].isRunning {
                    stopSubtaskSession(todoIndex: todoIndex, subtaskIndex: i)
                    if let startTime = todos[todoIndex].subtasks[i].lastStartTime {
                        todos[todoIndex].subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                    }
                    todos[todoIndex].subtasks[i].lastStartTime = nil
                }
            }
        } else {
            todos[todoIndex].completedAt = nil
        }
        
        saveTodos()
    }
}
