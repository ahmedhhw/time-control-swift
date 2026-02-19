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
    var activateReminders: Bool = false
    var showTimeWhenCollapsed: Bool = false
    var autoPlayAfterSwitching: Bool = false
    var autoPauseAfterMinutes: Int = 0
    
    func showFloatingWindow(for task: TodoItem, allTodos: [TodoItem], activateReminders: Bool = false, showTimeWhenCollapsed: Bool = false, autoPlayAfterSwitching: Bool = false, autoPauseAfterMinutes: Int = 0, onTaskSwitch: @escaping (TodoItem) -> Void) {
        closeFloatingWindow()
        
        currentTask = task
        self.allTodos = allTodos
        self.activateReminders = activateReminders
        self.showTimeWhenCollapsed = showTimeWhenCollapsed
        self.autoPlayAfterSwitching = autoPlayAfterSwitching
        self.autoPauseAfterMinutes = autoPauseAfterMinutes
        self.onTaskSwitch = onTaskSwitch
        
        let contentView = FloatingTaskWindowView(task: task, windowManager: self, activateReminders: activateReminders, showTimeWhenCollapsed: showTimeWhenCollapsed, autoPauseAfterMinutes: autoPauseAfterMinutes, autoPlayAfterSwitching: autoPlayAfterSwitching)
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
    }
    
    func updateTask(_ task: TodoItem) {
        currentTask = task
    }
    
    func switchToTask(_ task: TodoItem) {
        currentTask = task
        onTaskSwitch?(task)
    }
    
    func updateAllTodos(_ todos: [TodoItem]) {
        allTodos = todos
    }
}
