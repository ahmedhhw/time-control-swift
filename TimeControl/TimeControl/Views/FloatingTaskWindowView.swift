import SwiftUI
import AppKit
import AVFoundation

struct FloatingTaskWindowView: View {
    let task: TodoItem
    @ObservedObject var windowManager: FloatingWindowManager
    @State private var localTask: TodoItem
    @State private var isCollapsed: Bool = false
    @State private var notesText: String = ""
    @State private var timerUpdateTrigger = 0  // Used to trigger UI updates for running timer
    @State private var notesWindow: NSWindow?
    @State private var reminderWindow: NSWindow?
    @State private var timerPickerWindow: NSWindow?
    @State private var newTaskPopupWindow: NSWindow?
    @State private var editWindow: NSWindow?
    @State private var newSubtaskText: String = ""  // Text for new subtask
    @FocusState private var subtaskInputFocused: Bool  // Track focused subtask input
    @State private var showingTimerPicker: Bool = false  // Show timer picker sheet
    @State private var timerHours: Int = 0  // Hours for countdown timer
    @State private var timerMinutes: Int = 25  // Minutes for countdown timer (default 25)
    @State private var timerJustCompleted: Bool = false  // Track if timer just completed
    @State private var showTimerCompletedMessage: Bool = false  // Show "Timer's up!" message
    @State private var showingNewTaskPopup: Bool = false  // Show new task popup
    @State private var newTaskTitle: String = ""  // Title for new task
    
    // Reminder functionality
    let activateReminders: Bool  // User setting for reminders
    let showTimeWhenCollapsed: Bool  // User setting for showing time when collapsed
    let autoPauseAfterMinutes: Int  // User setting for auto-pause duration
    let autoPlayAfterSwitching: Bool  // User setting for auto-playing after switching tasks
    @State private var lastReminderTime: Date? = nil  // When the last reminder was shown
    @State private var showingReminder: Bool = false  // Show reminder popup
    @State private var reminderResponseDeadline: Date? = nil  // When to auto-pause if no response
    @State private var showTaskPausedAlert: Bool = false  // Show "Task Paused!" alert
    @State private var taskMarkedComplete: Bool = false  // Track if task has been marked complete
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(task: TodoItem, windowManager: FloatingWindowManager, activateReminders: Bool = false, showTimeWhenCollapsed: Bool = false, autoPauseAfterMinutes: Int = 0, autoPlayAfterSwitching: Bool = false) {
        self.task = task
        self.windowManager = windowManager
        self.activateReminders = activateReminders
        self.showTimeWhenCollapsed = showTimeWhenCollapsed
        self.autoPauseAfterMinutes = autoPauseAfterMinutes
        self.autoPlayAfterSwitching = autoPlayAfterSwitching
        self._localTask = State(initialValue: task)
        self._notesText = State(initialValue: task.notes)
        
        // Initialize timer hours/minutes from existing countdown time
        if task.countdownTime > 0 {
            let totalMinutes = Int(task.countdownTime / 60)
            self._timerHours = State(initialValue: totalMinutes / 60)
            self._timerMinutes = State(initialValue: totalMinutes % 60)
        }
    }
    
    private var availableTasks: [TodoItem] {
        windowManager.allTodos
            .filter { !$0.isCompleted }
            .sorted { task1, task2 in
                let time1 = task1.lastPlayedAt ?? task1.startedAt ?? task1.createdAt
                let time2 = task2.lastPlayedAt ?? task2.startedAt ?? task2.createdAt
                return time1 > time2
            }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
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
                    .floatingTooltip(isCollapsed ? "Expand" : "Collapse")
                    
                    Button(action: {
                        openMainWindow()
                    }) {
                        Image(systemName: "macwindow")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .floatingTooltip("Open task list")
                    
                    Button(action: {
                        openNotesWindow()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.subheadline)
                         
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .floatingTooltip("Take notes while working on this task")
                    .disabled(taskMarkedComplete)
                    .opacity(taskMarkedComplete ? 0.3 : 1.0)

                    Button(action: {
                        showingTimerPicker = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.subheadline)
                       
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .floatingTooltip("Set a countdown timer")
                    .disabled(taskMarkedComplete)
                    .opacity(taskMarkedComplete ? 0.3 : 1.0)
                    
                    Button(action: {
                        editTask()
                    }) {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .floatingTooltip("Edit task")
                    .disabled(taskMarkedComplete)
                    .opacity(taskMarkedComplete ? 0.3 : 1.0)
                    
                    // Show time elapsed when collapsed and setting is enabled
                    if isCollapsed && showTimeWhenCollapsed {
                        Spacer()
                        
                        Text(TimeFormatter.formatTime(localTask.currentTimeSpent))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .monospacedDigit()
                            .id(timerUpdateTrigger)
                    }
                    
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            
            // Content (hidden when collapsed)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    // Task title dropdown with new task button
                    HStack(spacing: 8) {
                        Picker("Current Task", selection: Binding(
                            get: { localTask.id },
                            set: { newTaskId in
                                if let selectedTask = availableTasks.first(where: { $0.id == newTaskId }) {
                                    // Store if the current task was marked complete
                                    let wasComplete = taskMarkedComplete
                                    
                                    // Switch to the new task
                                    windowManager.switchToTask(selectedTask)
                                    
                                    // Reset completion state when switching tasks
                                    taskMarkedComplete = false
                                    
                                    // If switching from a complete task to a non-complete task and auto-play is enabled
                                    if wasComplete && !selectedTask.isCompleted && autoPlayAfterSwitching {
                                        // Resume the new task
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            resumeTask()
                                        }
                                    }
                                }
                            }
                        )) {
                            ForEach(availableTasks) { task in
                                Text(task.text)
                                    .lineLimit(1)
                                    .tag(task.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.title2)
                        .labelsHidden()
                        
                        Button(action: {
                            showingNewTaskPopup = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("Create new task")
                        .disabled(taskMarkedComplete)
                        .opacity(taskMarkedComplete ? 0.3 : 1.0)
                    }
                    
                    // Task description
                    if !localTask.description.isEmpty {
                        Text(localTask.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .opacity(taskMarkedComplete ? 0.5 : 1.0)
                    }
                    
                    // Time tracking section
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                        
                        HStack(alignment: .top, spacing: 16) {
                            // Time elapsed
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Time Elapsed")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(TimeFormatter.formatTime(localTask.currentTimeSpent))
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .monospacedDigit()
                                    .id(timerUpdateTrigger)
                            }
                            .opacity(taskMarkedComplete ? 0.5 : 1.0)
                            
                            Spacer()
                            
                            // Attention Check countdown (only shown when reminders are active and task is running)
                            if activateReminders && localTask.isRunning && !showingReminder && !taskMarkedComplete {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Attention Check")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    if let lastReminder = lastReminderTime {
                                        let elapsed = Date().timeIntervalSince(lastReminder)
                                        let remaining = max(0, 120 - elapsed)  // 120 seconds = 2 minutes
                                        
                                        Text(TimeFormatter.formatTime(remaining))
                                            .font(.title)
                                            .fontWeight(.semibold)
                                            .foregroundColor(remaining < 30 ? .orange : .purple)
                                            .monospacedDigit()
                                            .id(timerUpdateTrigger)
                                    } else {
                                        Text(TimeFormatter.formatTime(120))
                                            .font(.title)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.purple)
                                            .monospacedDigit()
                                            .id(timerUpdateTrigger)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Timer's up! message (shown after timer completes and is cleared)
                    if showTimerCompletedMessage && !taskMarkedComplete {
                        VStack(spacing: 8) {
                            Divider()
                            
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.red)
                                    
                                    Text("Timer's up!")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    
                                    Button(action: {
                                        withAnimation {
                                            showTimerCompletedMessage = false
                                        }
                                    }) {
                                        Text("Dismiss")
                                            .font(.subheadline)
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
                        VStack(alignment: .leading, spacing: 4) {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Timer")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                HStack {
                                    // Show elapsed time
                                    Text(TimeFormatter.formatTime(localTask.countdownElapsed))
                                        .font(.title)
                                        .fontWeight(.semibold)
                                        .foregroundColor(localTask.countdownElapsed >= localTask.countdownTime ? .red : .orange)
                                        .monospacedDigit()
                                        .id(timerUpdateTrigger)
                                    
                                    Text("/")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    
                                    Text(TimeFormatter.formatTime(localTask.countdownTime))
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                    
                                    Spacer()
                                    
                                    if localTask.countdownElapsed >= localTask.countdownTime {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bell.fill")
                                                .font(.subheadline)
                                                .foregroundColor(.red)
                                            Text("Time's up!")
                                                .font(.subheadline)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .opacity(taskMarkedComplete ? 0.5 : 1.0)
                                
                                // Progress bar for countdown (fills up as time progresses)
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 12)
                                            .cornerRadius(6)
                                        
                                        // Progress (fills up as time elapses)
                                        let progress = localTask.countdownTime > 0 ? min(localTask.countdownElapsed / localTask.countdownTime, 1.0) : 0
                                        Rectangle()
                                            .fill(progress >= 1.0 ? Color.red : Color.orange)
                                            .frame(width: geometry.size.width * progress, height: 12)
                                            .cornerRadius(6)
                                            .id(timerUpdateTrigger)
                                    }
                                }
                                .frame(height: 12)
                                .opacity(taskMarkedComplete ? 0.5 : 1.0)
                            }
                        }
                    }
                    
                    // Subtasks section
                    Divider()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subtasks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .opacity(taskMarkedComplete ? 0.5 : 1.0)
                            
                            // Textfield and button for adding new subtasks
                            HStack(spacing: 8) {
                                TextField("Subtask title...", text: $newSubtaskText)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($subtaskInputFocused)
                                    .onSubmit {
                                        addSubtask()
                                    }
                                    .disabled(taskMarkedComplete)
                                
                                Button(action: {
                                    addSubtask()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .disabled(newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty || taskMarkedComplete)
                                .opacity((newSubtaskText.trimmingCharacters(in: .whitespaces).isEmpty || taskMarkedComplete) ? 0.3 : 1.0)
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
                                                .font(.body)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(taskMarkedComplete)
                                        
                                        Text(subtask.title)
                                            .font(.title3)
                                            .strikethrough(subtask.isCompleted)
                                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                                            .lineLimit(2)
                                        
                                        Spacer()
                                        
                                        // Time display
                                        Text(TimeFormatter.formatTime(subtask.currentTimeSpent))
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                            .id(timerUpdateTrigger) // Force update when trigger changes
                                        
                                        // Play/Pause button
                                        Button(action: {
                                            toggleSubtaskTimer(subtask)
                                        }) {
                                            Image(systemName: subtask.isRunning ? "pause.circle.fill" : "play.circle.fill")
                                                .foregroundColor(subtask.isRunning ? .orange : .blue)
                                                .font(.body)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!localTask.isRunning || taskMarkedComplete)
                                        .opacity((localTask.isRunning && !taskMarkedComplete) ? 1.0 : 0.3)
                                        
                                        Button(action: {
                                            deleteSubtask(subtask)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.subheadline)
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(taskMarkedComplete)
                                        .opacity(taskMarkedComplete ? 0.3 : 1.0)
                                    }
                                    .padding(.horizontal, 8)
                                    .opacity(taskMarkedComplete ? 0.5 : 1.0)
                                }
                            }
                        }
                    }
                    
                    // Pause/Resume and Complete buttons at the bottom
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
                                    .font(.title3)
                                Text(localTask.isRunning ? "Pause" : "Resume")
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(localTask.isRunning ? Color.orange : Color.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip(localTask.isRunning ? "Pause this task" : "Resume this task")
                        .disabled(taskMarkedComplete)
                        .opacity(taskMarkedComplete ? 0.3 : 1.0)
                        
                        Button(action: {
                            completeTask()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: taskMarkedComplete ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.title3)
                                Text(taskMarkedComplete ? "Close" : "Complete")
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(taskMarkedComplete ? Color.gray : Color.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip(taskMarkedComplete ? "Close this task view" : "Mark this task as complete")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // "Task Paused!" Alert (shown when auto-pause triggers)
            if showTaskPausedAlert {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Task Paused due to inactivity!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 60)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .onReceive(timer) { _ in
            // Update UI every second for running timer
            timerUpdateTrigger += 1
            
            // Reminder functionality - check every second if we need to show reminder or auto-pause
            if activateReminders && localTask.isRunning {
                let now = Date()
                
                // Check if we need to show a reminder (every 2 minutes)
                if !showingReminder {
                    if lastReminderTime == nil {
                        // First time - set the timer
                        lastReminderTime = now
                    } else                     if let lastReminder = lastReminderTime {
                        let timeSinceLastReminder = now.timeIntervalSince(lastReminder)
                        if timeSinceLastReminder >= 120 {  // 2 minutes = 120 seconds
                            // Show the reminder window
                            showingReminder = true
                            openReminderWindow()
                            reminderResponseDeadline = now.addingTimeInterval(10)  // 10 seconds to respond
                        }
                    }
                }
                
                // Check if we need to auto-pause (10 seconds after showing reminder)
                if showingReminder, let deadline = reminderResponseDeadline {
                    if now >= deadline {
                        // Auto-pause the task and show alert
                        handleReminderResponse(.pause, isAutoPause: true)
                    }
                }
            }
            
            // Auto-pause on inactivity - check if user has been idle for the specified duration
            if autoPauseAfterMinutes > 0 && localTask.isRunning {
                let idleSeconds = CGEventSource.secondsSinceLastEventType(
                    .hidSystemState,
                    eventType: CGEventType(rawValue: ~0)!
                )
                let autoPauseThreshold = TimeInterval(autoPauseAfterMinutes * 60)
                
                if idleSeconds >= autoPauseThreshold {
                    // Auto-pause the task
                    pauseTask()
                    
                    // Expand window if collapsed
                    if isCollapsed {
                        withAnimation {
                            isCollapsed = false
                        }
                        resizeWindow()
                    }
                    
                    // Show "Task Paused!" alert
                    withAnimation {
                        showTaskPausedAlert = true
                    }
                    
                    // Hide the alert after 3 seconds with fade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showTaskPausedAlert = false
                        }
                    }
                }
            }
            
            // Check if countdown timer has completed
            if localTask.isRunning && localTask.countdownTime > 0 && !timerJustCompleted {
                let elapsed = localTask.countdownElapsed
                if elapsed >= localTask.countdownTime {
                    // Countdown completed - mark as just completed
                    timerJustCompleted = true
                    
                    // Expand window if collapsed
                    if isCollapsed {
                        withAnimation {
                            isCollapsed = false
                        }
                        resizeWindow()
                    }
                    
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
                // Check if task running state changed
                let wasRunning = localTask.isRunning
                let isNowRunning = newTask.isRunning
                
                // Reset reminder timer when task state changes
                if wasRunning != isNowRunning {
                    if isNowRunning {
                        // Task just started - reset reminder timer
                        lastReminderTime = Date()
                    } else {
                        // Task paused - clear reminder state
                        lastReminderTime = nil
                        showingReminder = false
                        reminderResponseDeadline = nil
                    }
                }
                
                // Check if subtasks changed to trigger resize
                let subtasksChanged = localTask.subtasks.count != newTask.subtasks.count
                
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
                
                // Resize window if subtasks changed
                if subtasksChanged && !isCollapsed {
                    resizeWindow()
                }
            }
        }
        .onChange(of: showingTimerPicker) { newValue in
            if newValue {
                openTimerPickerWindow()
            }
        }
        .onChange(of: showingNewTaskPopup) { newValue in
            if newValue {
                openNewTaskPopupWindow()
            }
        }
        .onChange(of: showTimerCompletedMessage) { _ in
            if !isCollapsed {
                resizeWindow()
            }
        }
        .onChange(of: localTask.countdownTime) { _ in
            if !isCollapsed {
                resizeWindow()
            }
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
    
    private func openReminderWindow() {
        // Close existing reminder window if any
        reminderWindow?.close()
        
        // Create the SwiftUI view for reminder alert
        let contentView = ReminderAlertView(
            taskText: localTask.text,
            reminderResponseDeadline: $reminderResponseDeadline,
            timerUpdateTrigger: timerUpdateTrigger,
            onResponse: { response in
                handleReminderResponse(response)
                reminderWindow?.close()
                reminderWindow = nil
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (centered on top of the task window)
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 200
        
        var xPos: CGFloat
        var yPos: CGFloat
        
        if let taskWindow = NSApp.windows.first(where: { $0.title == "Current Task" }) {
            let taskFrame = taskWindow.frame
            // Position centered on top of the task window
            xPos = taskFrame.midX - windowWidth / 2
            yPos = taskFrame.midY - windowHeight / 2
        } else {
            // Center on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                xPos = screenFrame.midX - windowWidth / 2
                yPos = screenFrame.midY - windowHeight / 2
            } else {
                xPos = 100
                yPos = 100
            }
        }
        
        // Create a floating panel for the reminder
        let window = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Attention Check"
        window.contentView = hostingView
        window.level = .statusBar  // Higher than floating to ensure visibility
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.hidesOnDeactivate = false
        
        reminderWindow = window
        window.orderFrontRegardless()
        window.makeKey()  // Make it the key window to get focus
    }
    
    private func openTimerPickerWindow() {
        // Close existing timer picker window if any
        timerPickerWindow?.close()
        
        // Create the SwiftUI view for timer picker
        let contentView = TimerPickerSheet(
            hours: $timerHours,
            minutes: $timerMinutes,
            onSet: {
                setCountdownTimer()
                timerPickerWindow?.close()
                timerPickerWindow = nil
                showingTimerPicker = false
            },
            onCancel: {
                timerPickerWindow?.close()
                timerPickerWindow = nil
                showingTimerPicker = false
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (centered on top of the task window)
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 250
        
        var xPos: CGFloat
        var yPos: CGFloat
        
        if let taskWindow = NSApp.windows.first(where: { $0.title == "Current Task" }) {
            let taskFrame = taskWindow.frame
            // Position centered on top of the task window
            xPos = taskFrame.midX - windowWidth / 2
            yPos = taskFrame.midY - windowHeight / 2
        } else {
            // Center on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                xPos = screenFrame.midX - windowWidth / 2
                yPos = screenFrame.midY - windowHeight / 2
            } else {
                xPos = 100
                yPos = 100
            }
        }
        
        // Create a floating panel for the timer picker
        let window = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Set Countdown Timer"
        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        
        timerPickerWindow = window
        window.orderFrontRegardless()
    }
    
    private func openNewTaskPopupWindow() {
        // Close existing new task popup window if any
        newTaskPopupWindow?.close()
        
        // Create the SwiftUI view for new task popup
        let contentView = NewTaskPopupView(
            taskTitle: $newTaskTitle,
            onCreate: {
                createNewTask(switchToIt: false)
                newTaskPopupWindow?.close()
                newTaskPopupWindow = nil
                showingNewTaskPopup = false
            },
            onCreateAndSwitch: {
                createNewTask(switchToIt: true)
                newTaskPopupWindow?.close()
                newTaskPopupWindow = nil
                showingNewTaskPopup = false
            },
            onCancel: {
                newTaskPopupWindow?.close()
                newTaskPopupWindow = nil
                showingNewTaskPopup = false
                newTaskTitle = ""
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (centered on top of the task window)
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 150
        
        var xPos: CGFloat
        var yPos: CGFloat
        
        if let taskWindow = NSApp.windows.first(where: { $0.title == "Current Task" }) {
            let taskFrame = taskWindow.frame
            // Position centered on top of the task window
            xPos = taskFrame.midX - windowWidth / 2
            yPos = taskFrame.midY - windowHeight / 2
        } else {
            // Center on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                xPos = screenFrame.midX - windowWidth / 2
                yPos = screenFrame.midY - windowHeight / 2
            } else {
                xPos = 100
                yPos = 100
            }
        }
        
        // Create a floating panel for the new task popup
        let window = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "New Task"
        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        
        newTaskPopupWindow = window
        window.orderFrontRegardless()
        window.makeKey()
    }
    
    private func calculateDynamicHeight() -> CGFloat {
        // Base height for header, task title, description, time tracking, and buttons
        var height: CGFloat = 0
        
        // Header with buttons (collapse, notes, timer)
        height += 40  // Header row
        
        // Task title dropdown
        height += 40
        
        // Description (if present)
        if !localTask.description.isEmpty {
            height += 50  // Approximate height for 2 lines of description
        }
        
        // Time tracking section (Time Elapsed + optional Attention Check)
        height += 80  // Divider + time section
        
        // Countdown timer section (if active)
        if localTask.countdownTime > 0 {
            height += 80  // Timer display + progress bar
        }
        
        // Timer completed message (if shown)
        if showTimerCompletedMessage {
            height += 120
        }
        
        // Subtasks section header + input field
        height += 80  // "SUBTASKS" label + input field with button
        
        // Subtasks list - calculate based on number of subtasks
        let subtaskCount = localTask.subtasks.count
        if subtaskCount > 0 {
            // Each subtask is approximately 40 pixels tall
            let subtasksHeight = min(CGFloat(subtaskCount) * 40, 200)  // Cap at 200px for scrolling
            height += subtasksHeight
        }
        
        // Bottom buttons (Pause/Resume and Complete)
        height += 60
        
        // Add some padding
        height += 20
        
        // Clamp between min and max heights
        return min(max(height, 400), 550)
    }
    
    private func resizeWindow() {
        // Get the window from the view hierarchy
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.title == "Current Task" }),
                  let screen = window.screen else { return }
            
            let currentFrame = window.frame
            let newHeight: CGFloat = isCollapsed ? 50 : calculateDynamicHeight()
            
            // Calculate new frame anchored at bottom-left corner
            var newY = currentFrame.maxY - newHeight
            let newFrame = NSRect(x: currentFrame.minX, y: newY, width: currentFrame.width, height: newHeight)
            
            // Check if the new frame would go below the screen's visible area
            let screenMinY = screen.visibleFrame.minY
            if newFrame.minY < screenMinY {
                // Adjust window position to stay within screen bounds
                newY = screenMinY
            }
            
            let adjustedFrame = NSRect(x: currentFrame.minX, y: newY, width: currentFrame.width, height: newHeight)
            
            window.setFrame(adjustedFrame, display: true, animate: true)
        }
    }
    
    private func toggleSubtask(_ subtask: Subtask) {
        // Find the subtask and toggle it
        if let subtaskIndex = localTask.subtasks.firstIndex(where: { $0.id == subtask.id }) {
            localTask.subtasks[subtaskIndex].isCompleted.toggle()
            
            // If the subtask was just completed, move it above all non-completed subtasks
            let wasCompleted = localTask.subtasks[subtaskIndex].isCompleted
            if wasCompleted {
                let completedSubtask = localTask.subtasks[subtaskIndex]
                localTask.subtasks.remove(at: subtaskIndex)
                
                // Find the position of the first non-completed subtask
                if let firstIncompleteIndex = localTask.subtasks.firstIndex(where: { !$0.isCompleted }) {
                    localTask.subtasks.insert(completedSubtask, at: firstIncompleteIndex)
                } else {
                    // All subtasks are completed, add at the beginning
                    localTask.subtasks.insert(completedSubtask, at: 0)
                }
            }
            
            // Update the stored todos in ContentView
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleSubtaskFromFloatingWindow"),
                object: nil,
                userInfo: ["taskId": localTask.id, "subtaskId": subtask.id]
            )
        }
    }
    
    private func toggleSubtaskTimer(_ subtask: Subtask) {
        // Rule: Parent task must be running for subtask to be played
        guard localTask.isRunning else {
            return
        }
        
        if let subtaskIndex = localTask.subtasks.firstIndex(where: { $0.id == subtask.id }) {
            if localTask.subtasks[subtaskIndex].isRunning {
                // Pause the subtask timer
                if let startTime = localTask.subtasks[subtaskIndex].lastStartTime {
                    localTask.subtasks[subtaskIndex].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                localTask.subtasks[subtaskIndex].lastStartTime = nil
            } else {
                // Pause any other running subtasks first
                for i in 0..<localTask.subtasks.count {
                    if localTask.subtasks[i].isRunning {
                        if let startTime = localTask.subtasks[i].lastStartTime {
                            localTask.subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                        }
                        localTask.subtasks[i].lastStartTime = nil
                    }
                }
                
                // Start the subtask timer
                localTask.subtasks[subtaskIndex].lastStartTime = Date()
            }
            
            // Notify ContentView to update the subtask timer in the main todos array
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleSubtaskTimerFromFloatingWindow"),
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
        
        // Resize window to accommodate new subtask
        resizeWindow()
        
        // Refocus the textbox after a brief delay to ensure UI is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            subtaskInputFocused = true
        }
    }
    
    private func createNewTask(switchToIt: Bool) {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        // Notify ContentView to create the new task
        NotificationCenter.default.post(
            name: NSNotification.Name("CreateTaskFromFloatingWindow"),
            object: nil,
            userInfo: ["taskTitle": trimmedTitle, "switchToIt": switchToIt]
        )
        
        // Clear the input
        newTaskTitle = ""
    }
    
    private func deleteSubtask(_ subtask: Subtask) {
        // Remove the subtask from the local task
        localTask.subtasks.removeAll { $0.id == subtask.id }
        
        // Notify ContentView to delete the subtask from the main todos array
        NotificationCenter.default.post(
            name: NSNotification.Name("DeleteSubtaskFromFloatingWindow"),
            object: nil,
            userInfo: ["taskId": localTask.id, "subtaskId": subtask.id]
        )
        
        // Resize window to reflect removed subtask
        resizeWindow()
    }
    
    private func completeTask() {
        if taskMarkedComplete {
            // If already marked complete, close the window
            FloatingWindowManager.shared.closeFloatingWindow()
        } else {
            // Pause the task if it's currently running
            if localTask.isRunning {
                pauseTask()
            }
            
            // Mark the task as complete in the main todos array
            NotificationCenter.default.post(
                name: NSNotification.Name("CompleteTaskFromFloatingWindow"),
                object: nil,
                userInfo: ["taskId": localTask.id]
            )
            
            // Update local state to change button to "Close"
            taskMarkedComplete = true
        }
    }
    
    private func pauseTask() {
        // Pause all running subtasks first
        for i in 0..<localTask.subtasks.count {
            if localTask.subtasks[i].isRunning {
                if let startTime = localTask.subtasks[i].lastStartTime {
                    localTask.subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                localTask.subtasks[i].lastStartTime = nil
            }
        }
        
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
    
    private func editTask() {
        openEditWindow()
    }
    
    private func openEditWindow() {
        // Close existing edit window if any
        editWindow?.close()
        
        // Create the SwiftUI view for edit form
        let contentView = FloatingEditView(
            task: localTask,
            onSave: { updatedTask in
                // Notify ContentView to update the task
                NotificationCenter.default.post(
                    name: NSNotification.Name("UpdateTaskFromFloatingWindow"),
                    object: nil,
                    userInfo: [
                        "taskId": localTask.id,
                        "text": updatedTask.text,
                        "description": updatedTask.description,
                        "notes": updatedTask.notes,
                        "dueDate": updatedTask.dueDate as Any,
                        "isAdhoc": updatedTask.isAdhoc,
                        "fromWho": updatedTask.fromWho,
                        "estimatedTime": updatedTask.estimatedTime
                    ]
                )
                editWindow?.close()
                editWindow = nil
            },
            onCancel: {
                editWindow?.close()
                editWindow = nil
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (next to the floating task window)
        guard let taskWindow = NSApp.windows.first(where: { $0.title == "Current Task" }) else { return }
        let taskFrame = taskWindow.frame
        
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        
        // Position to the right of the task window
        let xPos = taskFrame.maxX + 20
        let yPos = taskFrame.minY
        
        // Create a floating window for editing
        let window = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Edit Task"
        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 400, height: 500)
        
        editWindow = window
        window.orderFrontRegardless()
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
    
    private func handleReminderResponse(_ response: ReminderResponse, isAutoPause: Bool = false) {
        // Close the reminder window
        reminderWindow?.close()
        reminderWindow = nil
        showingReminder = false
        reminderResponseDeadline = nil
        lastReminderTime = Date()  // Reset the timer for the next reminder
        
        switch response {
        case .yes:
            // Do nothing - task continues running
            break
            
        case .pause:
            // Pause the task
            pauseTask()
            
            // Expand window if collapsed
            if isCollapsed {
                withAnimation {
                    isCollapsed = false
                }
                resizeWindow()
            }
            
            // Show "Task Paused!" alert if this was an auto-pause
            if isAutoPause {
                withAnimation {
                    showTaskPausedAlert = true
                }
                
                // Hide the alert after 3 seconds with fade
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showTaskPausedAlert = false
                    }
                }
            }
            
        case .openTaskList:
            // Pause the task before opening the main window
            pauseTask()
            
            // Expand window if collapsed
            if isCollapsed {
                withAnimation {
                    isCollapsed = false
                }
                resizeWindow()
            }
            
            // Open the main window
            openMainWindow()
        }
    }
}
