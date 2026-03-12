//
//  FloatingWindowManager.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()
    private var floatingWindow: NSWindow?
    @Published var currentTask: TodoItem?
    @Published var allTodos: [TodoItem] = []
    private var windowDelegate: FloatingWindowDelegate?
    var onTaskSwitch: ((TodoItem) -> Void)?
    weak var viewModel: TodoViewModel?
    
    func showFloatingWindow(for task: TodoItem, viewModel: TodoViewModel) {
        closeFloatingWindow()
        
        currentTask = task
        self.allTodos = viewModel.todos
        self.viewModel = viewModel
        self.onTaskSwitch = { [weak viewModel] newTask in
            viewModel?.switchToTask(newTask)
        }
        
        let contentView = FloatingTaskWindowView(task: task, windowManager: self, viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        
        let initialHeight = Self.calculateInitialHeight(for: task)
        
        guard let screen = NSScreen.main else { return }
        let windowWidth: CGFloat = 350
        let windowHeight: CGFloat = initialHeight
        let padding: CGFloat = 20
        
        let xPos = screen.visibleFrame.maxX - windowWidth - padding
        let yPos = screen.visibleFrame.minY + padding
        
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
        window.becomesKeyOnlyIfNeeded = false
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 100, height: 30)
        
        let delegate = FloatingWindowDelegate(taskId: task.id)
        window.delegate = delegate
        windowDelegate = delegate
        
        floatingWindow = window
        window.orderFrontRegardless()
    }
    
    private static func calculateInitialHeight(for task: TodoItem) -> CGFloat {
        var height: CGFloat = 0
        
        height += 40
        height += 40
        
        if !task.description.isEmpty {
            height += 50
        }
        
        height += 80
        
        if task.countdownTime > 0 {
            height += 80
        }
        
        height += 80
        
        let subtaskCount = task.subtasks.count
        if subtaskCount > 0 {
            let subtasksHeight = min(CGFloat(subtaskCount) * 40, 200)
            height += subtasksHeight
        }
        
        height += 60
        
        return min(max(height, 300), 550)
    }
    
    func closeFloatingWindow() {
        floatingWindow?.close()
        floatingWindow = nil
        currentTask = nil
        allTodos = []
        onTaskSwitch = nil
        windowDelegate = nil
        viewModel = nil
    }
    
    var isWindowOpen: Bool { floatingWindow != nil }

    func updateTask(_ task: TodoItem) {
        currentTask = task
    }
    
    func switchToTask(_ task: TodoItem) {
        currentTask = task
        onTaskSwitch?(task)
    }
    
    func updateAllTodos(_ todos: [TodoItem]) {
        allTodos = todos
        if let current = currentTask, let updated = todos.first(where: { $0.id == current.id }) {
            currentTask = updated
        }
    }
}
