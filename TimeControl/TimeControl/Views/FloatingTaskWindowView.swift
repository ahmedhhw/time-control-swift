import SwiftUI
import AppKit
import AVFoundation

struct FloatingTaskWindowView: View {
    let task: TodoItem
    @ObservedObject var windowManager: FloatingWindowManager
    @ObservedObject var viewModel: TodoViewModel
    @ObservedObject private var opacityBroadcaster: WindowOpacityBroadcaster
    @State private var localTask: TodoItem
    @State private var isCollapsed: Bool = false
    @State private var notesText: String = ""
    @State private var timerUpdateTrigger = 0
    @State private var notesWindow: NSWindow?
    private let notesFrameStore = NotesWindowFrameStore()
    @State private var notesWindowDelegate: NotesWindowDelegate?
    @State private var reminderWindow: NSWindow?
    @State private var timerPickerWindow: NSWindow?
    @State private var newTaskPopupWindow: NSWindow?
    @State private var editWindow: NSWindow?
    @State private var newSubtaskText: String = ""
    @FocusState private var subtaskInputFocused: Bool
    @State private var showingTimerPicker: Bool = false
    @State private var timerHours: Int = 0
    @State private var timerMinutes: Int = 15
    @State private var timerJustCompleted: Bool = false
    @State private var showTimerCompletedMessage: Bool = false
    @State private var showingNewTaskPopup: Bool = false
    @State private var newTaskTitle: String = ""
    @State private var newTaskSwitchToTask: Bool = false
    @State private var newTaskCopyNotes: Bool = false
    @State private var newTaskHasDueDate: Bool = false
    @State private var newTaskDueDate: Date = Date()
    @State private var newTaskEstimateHours: Int = 0
    @State private var newTaskEstimateMinutes: Int = 0
    @State private var subtaskBeingPromoted: Subtask? = nil
    @State private var showFloatingPromoteToast: Bool = false
    @State private var showNewTaskToast: Bool = false
    @AppStorage("newTaskStickyMode") private var newTaskStickyMode: Bool = false

    private let stickyStore = NewTaskStickyStore()

    @State private var showingReminderPopover = false
    @State private var lastReminderTime: Date? = nil
    @State private var showingReminder: Bool = false
    @State private var reminderResponseDeadline: Date? = nil
    @State private var showTaskPausedAlert: Bool = false
    @State private var taskMarkedComplete: Bool = false
    @State private var windowWidth: CGFloat = 350
    @State private var shouldScrollToBottom = false
    @State private var subtaskContentHeight: CGFloat = 0
    @State private var showTimerBar: Bool = true
    @State private var showEstimateBar: Bool = true
    @State private var showDueDateBar: Bool = true
    @AppStorage("floatingWindow.showDescription") private var showDescription: Bool = true
    @AppStorage("floatingWindow.showTimers") private var showTimers: Bool = true
    @AppStorage("floatingWindow.showSubtasks") private var showSubtasks: Bool = true
    @State private var showVisibilityPopover: Bool = false
    @State private var showCollapsedMenu: Bool = false
    @State private var isViewActive: Bool = true
    @State private var descriptionText: String = ""
    @FocusState private var descriptionFocused: Bool

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(task: TodoItem, windowManager: FloatingWindowManager, viewModel: TodoViewModel) {
        self.task = task
        self.windowManager = windowManager
        self.viewModel = viewModel
        self._opacityBroadcaster = ObservedObject(initialValue: windowManager.opacityBroadcaster)
        self._localTask = State(initialValue: task)
        self._notesText = State(initialValue: task.notes)
        self._descriptionText = State(initialValue: task.description)
        
        if task.countdownTime > 0 {
            let totalMinutes = Int(task.countdownTime / 60)
            self._timerHours = State(initialValue: totalMinutes / 60)
            self._timerMinutes = State(initialValue: totalMinutes % 60)
        }
    }
    
    private var availableTasks: [TodoItem] {
        let incomplete = windowManager.allTodos.filter { !$0.isCompleted }
        switch viewModel.dropdownSortOption {
        case .recentlyPlayed:
            return incomplete.sorted {
                let t1 = $0.lastPlayedAt ?? $0.startedAt ?? $0.createdAt
                let t2 = $1.lastPlayedAt ?? $1.startedAt ?? $1.createdAt
                return t1 > t2
            }
        case .newest:
            return incomplete.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return incomplete.sorted { $0.createdAt < $1.createdAt }
        case .estimateSize:
            return incomplete.sorted {
                switch ($0.estimatedTime > 0, $1.estimatedTime > 0) {
                case (true, true): return $0.estimatedTime < $1.estimatedTime
                case (true, false): return true
                case (false, true): return false
                default: return false
                }
            }
        case .dueDate:
            return incomplete.sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (d1?, d2?): return d1 < d2
                case (_?, nil): return true
                case (nil, _?): return false
                default: return false
                }
            }
        }
    }
    
    // The base window width is 350pt. For every extra 50pt the user has resized,
    // allow the collapsed picker to grow proportionally, capped so icons always fit.
    private var collapsedPickerMaxWidth: CGFloat {
        let baseWindowWidth: CGFloat = 350
        let extra = max(0, windowWidth - baseWindowWidth)
        return 120 + extra
    }
    
    @ViewBuilder
    private var collapsedMenuContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { openMainWindow(); showCollapsedMenu = false }) {
                Label("Open task list", systemImage: "macwindow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: { showingTimerPicker = true; showCollapsedMenu = false }) {
                Label("Set countdown timer", systemImage: "timer")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(taskMarkedComplete)

            Button(action: { editTask(); showCollapsedMenu = false }) {
                Label("Edit task", systemImage: "pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(taskMarkedComplete)

            if localTask.hasActiveNotification {
                Button(action: { viewModel.dismissBell(for: localTask.id); showCollapsedMenu = false }) {
                    Label("Dismiss notification", systemImage: "bell.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showingReminderPopover = true; showCollapsedMenu = false }) {
                    let hasReminder = localTask.reminderDate.map { $0 > Date() } ?? false
                    Label(hasReminder ? "Reminder set" : "Set reminder",
                          systemImage: hasReminder ? "bell.fill" : "bell")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(hasReminder ? .orange.opacity(0.7) : .primary)
                }
                .buttonStyle(.plain)
                .disabled(taskMarkedComplete)
            }

            Button(action: { showVisibilityPopover = true; showCollapsedMenu = false }) {
                Label("Show/hide sections", systemImage: "eye")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 220)
    }

    @ViewBuilder
    private var subtaskSectionContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subtasks")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .opacity(taskMarkedComplete ? 0.5 : 1.0)

            // Existing subtasks
            if !localTask.subtasks.isEmpty {
                ForEach($localTask.subtasks) { $subtask in
                    HStack(alignment: .top, spacing: 8) {
                        Button(action: {
                            toggleSubtask(subtask)
                        }) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.isCompleted ? .green : .secondary)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .disabled(taskMarkedComplete)

                        TextField("", text: $subtask.title, axis: .vertical)
                            .font(.title3)
                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                            .strikethrough(subtask.isCompleted)
                            .textFieldStyle(.plain)
                            .lineLimit(1...10)
                            .disabled(taskMarkedComplete)
                            .onChange(of: subtask.title) { newTitle in
                                let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    viewModel.renameSubtaskQuietly(subtask.id, in: localTask.id, newTitle: trimmed)
                                }
                            }

                        // Time display
                        Text(TimeFormatter.formatTime(subtask.currentTimeSpent))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                            .id(timerUpdateTrigger)

                        // Play/Pause button
                        Button(action: {
                            toggleSubtaskTimer(subtask)
                        }) {
                            Image(systemName: subtask.isRunning ? "pause.circle.fill" : "play.circle.fill")
                                .foregroundColor(subtask.isRunning ? .orange : .blue)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .disabled(!localTask.isRunning || taskMarkedComplete || subtask.isCompleted)
                        .opacity((localTask.isRunning && !taskMarkedComplete && !subtask.isCompleted) ? 1.0 : 0.3)

                        Button(action: {
                            promoteSubtask(subtask)
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.subheadline)
                                .foregroundColor((taskMarkedComplete || subtask.isCompleted) ? .gray : .teal)
                        }
                        .buttonStyle(.plain)
                        .disabled(taskMarkedComplete || subtask.isCompleted)
                        .opacity((taskMarkedComplete || subtask.isCompleted) ? 0.3 : 1.0)

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
            .padding(.top, 4)
            .id("subtaskInput")
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Track window width passively so the collapsed picker can adapt when user resizes
            GeometryReader { geo in
                Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
            }
            .frame(height: 0)
            .onPreferenceChange(WidthPreferenceKey.self) {
                windowWidth = $0
            }
            .onAppear {
                updateWindowTitle()
                applyResize(currentSnapshot)
                FloatingWindowManager.shared.onOpenNotes = { openNotesWindow() }
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 0) {
                // Toolbar row
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCollapsed.toggle()
                            if !isCollapsed { showCollapsedMenu = false }
                        }
                    }) {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .floatingTooltip(isCollapsed ? "Expand" : "Collapse")

                    if isCollapsed {
                        // Collapsed: book icon opens a popover with the hidden actions
                        Button(action: { showCollapsedMenu.toggle() }) {
                            Image(systemName: "books.vertical")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("More actions")
                        .popover(isPresented: $showCollapsedMenu, arrowEdge: .bottom) {
                            collapsedMenuContent
                        }

                        Picker("Current Task", selection: Binding(
                            get: { localTask.id },
                            set: { newTaskId in
                                if let selectedTask = availableTasks.first(where: { $0.id == newTaskId }) {
                                    let wasComplete = taskMarkedComplete
                                    windowManager.switchToTask(selectedTask)
                                    taskMarkedComplete = false
                                    if wasComplete && !selectedTask.isCompleted && viewModel.autoPlayAfterSwitching {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                                            guard isViewActive else { return }
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
                        .font(.subheadline)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .floatingTooltip(localTask.text)

                        Button(action: { showingNewTaskPopup = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("Create new task")

                        Button(action: { completeTask() }) {
                            Image(systemName: taskMarkedComplete ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(taskMarkedComplete ? .secondary : .green)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip(taskMarkedComplete ? "Close window" : "Mark task complete")

                        // Show time elapsed when collapsed and setting is enabled
                        if viewModel.showTimeWhenCollapsed {
                            Button(action: {
                                guard !taskMarkedComplete else { return }
                                if localTask.isRunning {
                                    viewModel.pauseTask(localTask.id, keepWindowOpen: true)
                                } else {
                                    viewModel.resumeTask(localTask.id)
                                }
                            }) {
                                Text(TimeFormatter.formatTime(localTask.currentTimeSpent))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(localTask.isRunning ? .blue : .orange)
                                    .monospacedDigit()
                                    .id(timerUpdateTrigger)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Expanded: show all toolbar icons inline
                        Button(action: { openMainWindow() }) {
                            Image(systemName: "macwindow")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("Open task list")

                        Button(action: { showingTimerPicker = true }) {
                            Image(systemName: "timer")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("Set a countdown timer")
                        .disabled(taskMarkedComplete)
                        .opacity(taskMarkedComplete ? 0.3 : 1.0)

                        Button(action: { editTask() }) {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("Edit task")
                        .disabled(taskMarkedComplete)
                        .opacity(taskMarkedComplete ? 0.3 : 1.0)

                        // Bell icon
                        if localTask.hasActiveNotification {
                            Button(action: { viewModel.dismissBell(for: localTask.id) }) {
                                Image(systemName: "bell.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                            .floatingTooltip("Notification active — tap to dismiss")
                            .disabled(taskMarkedComplete)
                            .opacity(taskMarkedComplete ? 0.3 : 1.0)
                        } else {
                            Button(action: { showingReminderPopover = true }) {
                                let hasReminder = localTask.reminderDate.map { $0 > Date() } ?? false
                                Image(systemName: hasReminder ? "bell.fill" : "bell")
                                    .font(.subheadline)
                                    .foregroundColor(hasReminder ? .orange.opacity(0.5) : .blue)
                            }
                            .buttonStyle(.plain)
                            .floatingTooltip(localTask.reminderDate.map { $0 > Date() } ?? false ? "Reminder set" : "Set a reminder")
                            .disabled(taskMarkedComplete)
                            .opacity(taskMarkedComplete ? 0.3 : 1.0)
                            .popover(isPresented: $showingReminderPopover) {
                                ReminderPickerPopover(
                                    currentReminder: localTask.reminderDate,
                                    onSelect: { date in
                                        viewModel.setReminder(date, for: localTask.id)
                                        showingReminderPopover = false
                                    },
                                    onClear: {
                                        viewModel.setReminder(nil, for: localTask.id)
                                        showingReminderPopover = false
                                    }
                                )
                            }
                        }

                        Button(action: { showVisibilityPopover.toggle() }) {
                            Image(systemName: "eye")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("Show/hide sections")
                        .popover(isPresented: $showVisibilityPopover) {
                            VisibilityPopoverView(
                                showDescription: $showDescription,
                                showTimers: $showTimers,
                                showSubtasks: $showSubtasks
                            )
                        }
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
                                    if wasComplete && !selectedTask.isCompleted && viewModel.autoPlayAfterSwitching {
                                        // Resume the new task
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                                            guard isViewActive else { return }
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
                        .floatingTooltip(localTask.text)

                        Button(action: {
                            showingNewTaskPopup = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .floatingTooltip("Create new task")
                    }
                    
                    // Task description
                    if showDescription {
                        ZStack(alignment: .topLeading) {
                            if descriptionText.isEmpty && !descriptionFocused {
                                Text("Add description…")
                                    .font(.body)
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .allowsHitTesting(false)
                                    .padding(.top, 2)
                            }
                            TextEditor(text: $descriptionText)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .scrollContentBackground(.hidden)
                                .background(.clear)
                                .frame(minHeight: 20, maxHeight: {
                                    guard !descriptionText.isEmpty else { return 20 }
                                    let natural = CGFloat(descriptionLineCount()) * 20 + 4
                                    return min(natural, 120)
                                }())
                                .focused($descriptionFocused)
                                .opacity(taskMarkedComplete ? 0.5 : 1.0)
                                .onChange(of: descriptionText) { newValue in
                                    if newValue != localTask.description {
                                        viewModel.updateTaskFields(id: localTask.id, text: nil, description: newValue, notes: nil, dueDate: nil, isAdhoc: nil, fromWho: nil, estimatedTime: nil)
                                    }
                                }
                        }
                    }
                    
                    // Time tracking section
                    if showTimers {
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
                                if viewModel.activateReminders && localTask.isRunning && !showingReminder && !taskMarkedComplete {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Attention Check")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)

                                        if let lastReminder = lastReminderTime {
                                            let elapsed = Date().timeIntervalSince(lastReminder)
                                            let remaining = max(0, 120 - elapsed)

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
                    }

                    // Subtasks section
                    if showSubtasks {
                        Divider()

                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                subtaskSectionContent
                                    .overlay(
                                        GeometryReader { geo in
                                            Color.clear.preference(key: SubtaskContentHeightKey.self, value: geo.size.height)
                                        }
                                    )
                            }
                            .onPreferenceChange(SubtaskContentHeightKey.self) { newHeight in
                                if newHeight != subtaskContentHeight {
                                    subtaskContentHeight = newHeight
                                }
                            }
                            .frame(height: min(max(subtaskContentHeight, 80), 400))
                            .onChange(of: shouldScrollToBottom) { _ in
                                if shouldScrollToBottom {
                                    withAnimation {
                                        scrollProxy.scrollTo("subtaskInput", anchor: .bottom)
                                    }
                                    shouldScrollToBottom = false
                                }
                            }
                        } // ScrollViewReader
                    }

                    // Countdown Timer section (if set)
                    if showTimers && localTask.countdownTime > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Divider()

                            Button(action: {
                                withAnimation { showTimerBar.toggle() }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showTimerBar ? "chevron.down" : "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Timer")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                            }
                            .buttonStyle(.plain)

                            if showTimerBar {
                            VStack(alignment: .leading, spacing: 2) {
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

                                    Button {
                                        localTask.countdownTime = 0
                                        localTask.countdownStartTime = nil
                                        localTask.countdownElapsedAtPause = 0
                                        viewModel.clearCountdown(taskId: localTask.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Cancel timer")
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
                            } // if showTimerBar
                        }
                    }

                    // Timer's up! message (shown after timer completes and is cleared)
                    if showTimers && showTimerCompletedMessage && !taskMarkedComplete {
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

                    // Estimate progress bar
                    if showTimers && localTask.estimatedTime > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider()

                            Button(action: {
                                withAnimation { showEstimateBar.toggle() }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showEstimateBar ? "chevron.down" : "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Estimate")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                            }
                            .buttonStyle(.plain)

                            if showEstimateBar {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("ELAPSED")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(TimeFormatter.formatTimeNoSeconds(localTask.currentTimeSpent))
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .monospacedDigit()
                                                .id(timerUpdateTrigger)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text("ESTIMATED")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(TimeFormatter.formatTimeNoSeconds(localTask.estimatedTime))
                                                .font(.headline)
                                                .monospacedDigit()
                                        }
                                    }

                                    let estProgress = min(localTask.currentTimeSpent / localTask.estimatedTime, 1.0)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 12)
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(estProgress >= 1.0 ? Color.red : Color.green)
                                                .frame(width: geo.size.width * estProgress, height: 12)

                                        }
                                    }
                                    .frame(height: 12)

                                    let estRemaining = localTask.estimatedTime - localTask.currentTimeSpent
                                    HStack(spacing: 4) {
                                        if estRemaining >= 0 {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Remaining \(TimeFormatter.formatTimeNoSeconds(estRemaining))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .id(timerUpdateTrigger)
                                        } else {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                            Text("Over by \(TimeFormatter.formatTimeNoSeconds(-estRemaining))")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                                .id(timerUpdateTrigger)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Due date progress bar
                    if showTimers, let dueDate = localTask.dueDate {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider()

                            Button(action: {
                                withAnimation { showDueDateBar.toggle() }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showDueDateBar ? "chevron.down" : "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Due Date")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                            }
                            .buttonStyle(.plain)

                            if showDueDateBar {
                                VStack(alignment: .leading, spacing: 4) {
                                    let now = Date()
                                    let created = Date(timeIntervalSince1970: localTask.createdAt)
                                    let totalDuration = dueDate.timeIntervalSince(created)
                                    let elapsedSinceCreated = now.timeIntervalSince(created)
                                    let dueProgress = totalDuration > 0 ? min(max(elapsedSinceCreated / totalDuration, 0), 1.0) : 1.0
                                    let isOverdue = now > dueDate

                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("CREATED")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(formatShortDate(created))
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text("DUE")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(formatShortDate(dueDate))
                                                .font(.headline)
                                                .foregroundColor(isOverdue ? .red : .primary)
                                        }
                                    }

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 12)
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isOverdue ? Color.red : Color.blue)
                                                .frame(width: geo.size.width * dueProgress, height: 12)

                                        }
                                    }
                                    .frame(height: 12)

                                    HStack(spacing: 4) {
                                        if isOverdue {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                            Text("Overdue by \(formatDuration(now.timeIntervalSince(dueDate)))")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .id(timerUpdateTrigger)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("Due in \(formatDuration(dueDate.timeIntervalSince(now)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .id(timerUpdateTrigger)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if let adoId = localTask.adoWorkItemId, !adoId.isEmpty {
                        ADOLinkRow(workItemId: adoId)
                    }

                    Spacer()

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

            // "Subtask promoted!" toast
            if showFloatingPromoteToast && !isCollapsed {
                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)

                        Text("Subtask promoted to task!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.teal)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 60)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // "Task created!" toast (normal new-task flow)
            if showNewTaskToast && !isCollapsed {
                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)

                        Text("Task created!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 60)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .subtitleHalo(windowOpacity: opacityBroadcaster.opacity)
        .onReceive(timer) { _ in
            // Update UI every second for running timer
            timerUpdateTrigger += 1
            
            // Reminder functionality - check every second if we need to show reminder or auto-pause
            if viewModel.activateReminders && localTask.isRunning {
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
            if viewModel.autoPauseAfterMinutes > 0 && localTask.isRunning {
                let idleSeconds = CGEventSource.secondsSinceLastEventType(
                    .hidSystemState,
                    eventType: CGEventType(rawValue: ~0)!
                )
                let autoPauseThreshold = TimeInterval(viewModel.autoPauseAfterMinutes * 60)
                
                if idleSeconds >= autoPauseThreshold {
                    // Auto-pause the task
                    pauseTask()
                    
                    // Expand window if collapsed
                    if isCollapsed {
                        withAnimation {
                            isCollapsed = false
                        }
                    }

                    // Show "Task Paused!" alert
                    withAnimation {
                        showTaskPausedAlert = true
                    }

                    // Hide the alert after 3 seconds with fade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
                        guard isViewActive else { return }
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
                    
                    // Play notification sound
                    NSSound.beep()

                    localTask.countdownTime = 0
                    localTask.countdownStartTime = nil
                    localTask.countdownElapsedAtPause = 0
                    viewModel.clearCountdown(taskId: localTask.id)
                    withAnimation {
                        isCollapsed = false
                        showTimerCompletedMessage = true
                    }
                }
            }
        }
        .onChange(of: windowManager.currentTask) { newTask in
            if let newTask = newTask {
                // If task switched and notes window is open, refresh it for the new task
                if newTask.id != localTask.id, notesWindow?.isVisible == true {
                    openNotesWindow(for: newTask)
                }

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
                
                // Don't overwrite localTask if timer just completed (let it finish the completion process)
                let taskSwitched = newTask.id != localTask.id
                if timerJustCompleted && localTask.countdownTime == 0 {
                    // Timer already cleared locally, just update other fields
                    localTask.text = newTask.text
                    localTask.description = newTask.description
                    localTask.subtasks = newTask.subtasks
                    localTask.totalTimeSpent = newTask.totalTimeSpent
                    localTask.lastStartTime = newTask.lastStartTime
                    localTask.estimatedTime = newTask.estimatedTime
                    notesText = newTask.notes
                    if taskSwitched || !descriptionFocused { descriptionText = newTask.description }
                } else {
                    // Normal update
                    localTask = newTask
                    notesText = newTask.notes
                    if taskSwitched || !descriptionFocused { descriptionText = newTask.description }
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
        .onChange(of: currentSnapshot) { snapshot in
            applyResize(snapshot)
        }
        .onChange(of: showingTimerPicker) { newValue in
            if newValue {
                openTimerPickerWindow()
            }
        }
        .onChange(of: viewModel.shouldAutoShowTimerPicker) { newValue in
            if newValue {
                viewModel.shouldAutoShowTimerPicker = false
                showingTimerPicker = true
            }
        }
        .onChange(of: showingNewTaskPopup) { newValue in
            if newValue {
                openNewTaskPopupWindow()
            }
        }
        .onChange(of: viewModel.dropdownSortOption) { _ in
            updateWindowTitle()
        }
        .onDisappear {
            isViewActive = false
        }
    }
    
    private func updateWindowTitle() {
        if let window = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }) {
            window.title = "Current Task: \(viewModel.dropdownSortOption.rawValue)"
        }
    }

    private func openMainWindow() {
        // Find and activate the main window
        if let mainWindow = NSApp.windows.first(where: { $0.title == "TimeControl" || $0.isMainWindow }) {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func openNotesWindow(for task: TodoItem? = nil) {
        let targetTask = task ?? localTask
        notesText = targetTask.notes

        let contentView = NotesEditorView(
            notes: $notesText,
            taskId: targetTask.id,
            viewModel: viewModel,
            opacityBroadcaster: FloatingWindowManager.shared.notesOpacityBroadcaster,
            onClose: {
                self.notesWindow?.close()
                self.notesWindow = nil
                FloatingWindowManager.shared.notesWindowRef = nil
            }
        )
        let hostingView = NSHostingView(rootView: contentView)

        // If window already exists and is visible, update content in-place without moving it
        if let existingWindow = notesWindow, existingWindow.isVisible {
            existingWindow.contentView = hostingView
            existingWindow.orderFrontRegardless()
            return
        }
        notesWindow = nil

        // Determine frame: use saved frame if available, otherwise position left of task window
        let initialFrame: NSRect
        if let saved = notesFrameStore.load() {
            initialFrame = saved
        } else {
            guard let taskWindow = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }) else { return }
            let taskFrame = taskWindow.frame
            let windowWidth: CGFloat = 500
            let windowHeight: CGFloat = 400
            initialFrame = NSRect(x: taskFrame.minX - windowWidth - 20, y: taskFrame.minY,
                                  width: windowWidth, height: windowHeight)
        }

        // Create a floating window for notes.
        // Use a fixed content rect for init; if we have a saved frame we apply it via
        // setFrame after creation so the title-bar height is not double-counted.
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialFrame.width, height: initialFrame.height),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Task Notes"
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 180, height: 120)

        if notesFrameStore.load() != nil {
            // Restore exact saved frame (origin + full frame size, title bar included)
            window.setFrame(initialFrame, display: false)
        } else {
            window.setFrameOrigin(initialFrame.origin)
        }

        let delegate = NotesWindowDelegate(store: notesFrameStore)
        window.delegate = delegate
        notesWindowDelegate = delegate

        WindowOpacityApplier.apply(opacity: FloatingWindowManager.shared.notesOpacity, to: window)
        FloatingWindowManager.shared.notesWindowRef = window

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
        
        if let taskWindow = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }) {
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
        window.isReleasedWhenClosed = false
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
        
        if let taskWindow = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }) {
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
        window.isReleasedWhenClosed = false
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

        // Reset title every time; for other fields apply sticky values when enabled.
        // When called via promoteSubtask, title is already pre-filled — preserve it.
        if subtaskBeingPromoted == nil {
            newTaskTitle = ""
        }
        if subtaskBeingPromoted == nil {
            let fields = stickyStore.applyOrReset(stickyEnabled: newTaskStickyMode)
            newTaskSwitchToTask = fields.switchToTask
            newTaskCopyNotes = fields.copyNotes
            newTaskHasDueDate = fields.hasDueDate
            newTaskDueDate = fields.dueDate
            newTaskEstimateHours = fields.estimateHours
            newTaskEstimateMinutes = fields.estimateMinutes
        } else {
            // Promoting a subtask — always reset non-title fields
            newTaskSwitchToTask = false
            newTaskCopyNotes = false
            newTaskHasDueDate = false
            newTaskDueDate = Date()
            newTaskEstimateHours = 0
            newTaskEstimateMinutes = 0
        }

        // Create the SwiftUI view for new task popup
        let contentView = NewTaskPopupView(
            taskTitle: $newTaskTitle,
            switchToTask: $newTaskSwitchToTask,
            copyNotes: $newTaskCopyNotes,
            hasDueDate: $newTaskHasDueDate,
            dueDate: $newTaskDueDate,
            estimateHours: $newTaskEstimateHours,
            estimateMinutes: $newTaskEstimateMinutes,
            stickyMode: $newTaskStickyMode,
            onCreate: {
                createNewTask(switchToIt: newTaskSwitchToTask)
                newTaskPopupWindow?.close()
                newTaskPopupWindow = nil
                showingNewTaskPopup = false
            },
            onCancel: {
                newTaskPopupWindow?.close()
                newTaskPopupWindow = nil
                showingNewTaskPopup = false
                newTaskTitle = ""
                subtaskBeingPromoted = nil
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (centered on top of the task window)
        let windowWidth: CGFloat = 420
        let windowHeight: CGFloat = 420

        var xPos: CGFloat
        var yPos: CGFloat

        if let taskWindow = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }) {
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
        window.isReleasedWhenClosed = false
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
    
    private var currentSnapshot: ResizeSnapshot {
        ResizeSnapshot(
            isCollapsed: isCollapsed,
            subtaskContentHeight: subtaskContentHeight,
            descriptionText: descriptionText,
            windowWidth: (windowWidth / 10).rounded() * 10,
            countdownTime: localTask.countdownTime,
            showTimerBar: showTimerBar,
            showTimerCompletedMessage: showTimerCompletedMessage,
            estimatedTime: localTask.estimatedTime,
            dueDate: localTask.dueDate,
            showEstimateBar: showEstimateBar,
            showDueDateBar: showDueDateBar,
            showDescription: showDescription,
            showTimers: showTimers,
            showSubtasks: showSubtasks
        )
    }

    private func descriptionLineCount() -> Int {
        let charsPerLine = max(1, Int(windowWidth / 7.5))
        return descriptionText.components(separatedBy: "\n").reduce(0) { count, line in
            count + max(1, Int(ceil(Double(max(1, line.count)) / Double(charsPerLine))))
        }
    }

    /// NOTE: must only be invoked from `.onChange(of: currentSnapshot, initial: true)`.
    /// Direct calls reintroduce the DispatchQueue.main.async pile-up this refactor fixes.
    private func applyResize(_ snapshot: ResizeSnapshot) {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }),
                  let screen = window.screen else { return }

            let currentFrame = window.frame
            let visible = screen.visibleFrame
            let rawHeight = calculateDynamicHeight(snapshot: snapshot)
            let newHeight = min(rawHeight, visible.height)

            var newY = currentFrame.maxY - newHeight
            if newY + newHeight > visible.maxY { newY = visible.maxY - newHeight }
            if newY < visible.minY { newY = visible.minY }

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
            
            viewModel.toggleSubtaskFromFloatingWindow(subtask.id, in: localTask.id)
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
                
                // Move the started subtask to the top of the non-completed subtasks list
                let startedSubtask = localTask.subtasks.remove(at: subtaskIndex)
                if let firstIncompleteIndex = localTask.subtasks.firstIndex(where: { !$0.isCompleted }) {
                    localTask.subtasks.insert(startedSubtask, at: firstIncompleteIndex)
                } else {
                    localTask.subtasks.append(startedSubtask)
                }
            }
            
            viewModel.toggleSubtaskTimerFromFloatingWindow(subtask.id, in: localTask.id)
        }
    }
    
    private func addSubtask() {
        let trimmedTitle = newSubtaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let newSubtask = Subtask(title: trimmedTitle, description: "")
        localTask.subtasks.append(newSubtask)
        
        viewModel.addSubtaskFromFloatingWindow(to: localTask.id, title: trimmedTitle)

        newSubtaskText = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            shouldScrollToBottom = true
            subtaskInputFocused = true
        }
    }
    
    private func promoteSubtask(_ subtask: Subtask) {
        subtaskBeingPromoted = subtask
        // Pre-fill the new task title with the subtask title
        newTaskTitle = subtask.title
        newTaskSwitchToTask = false
        newTaskCopyNotes = false
        newTaskHasDueDate = false
        newTaskDueDate = Date()
        newTaskEstimateHours = 0
        newTaskEstimateMinutes = 0
        showingNewTaskPopup = true
    }

    private func createNewTask(switchToIt: Bool) {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let clampedHours = max(0, newTaskEstimateHours)
        let clampedMinutes = max(0, min(59, newTaskEstimateMinutes))
        let estimateSeconds = TimeInterval((clampedHours * 3600) + (clampedMinutes * 60))

        let dueDateValue: Date? = newTaskHasDueDate ? newTaskDueDate : nil
        let notesValue: String = newTaskCopyNotes ? localTask.notes : ""

        viewModel.createTask(
            title: trimmedTitle,
            switchToIt: switchToIt,
            dueDate: dueDateValue,
            estimatedTime: estimateSeconds,
            notes: notesValue
        )

        if switchToIt {
            taskMarkedComplete = false
        }

        if newTaskStickyMode && subtaskBeingPromoted == nil {
            stickyStore.save(
                hasDueDate: newTaskHasDueDate,
                dueDate: newTaskDueDate,
                estimateHours: newTaskEstimateHours,
                estimateMinutes: newTaskEstimateMinutes,
                switchToTask: switchToIt,
                copyNotes: newTaskCopyNotes
            )
        }

        // If we were promoting a subtask, delete it and show promote toast;
        // otherwise show a regular "Task created!" toast.
        if let promoted = subtaskBeingPromoted {
            deleteSubtask(promoted)
            subtaskBeingPromoted = nil

            withAnimation {
                showFloatingPromoteToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
                guard isViewActive else { return }
                withAnimation(.easeOut(duration: 0.5)) {
                    showFloatingPromoteToast = false
                }
            }
        } else {
            withAnimation {
                showNewTaskToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
                guard isViewActive else { return }
                withAnimation(.easeOut(duration: 0.5)) {
                    showNewTaskToast = false
                }
            }
        }

        newTaskTitle = ""
    }
    
    private func deleteSubtask(_ subtask: Subtask) {
        localTask.subtasks.removeAll { $0.id == subtask.id }
        
        viewModel.deleteSubtaskFromFloatingWindow(subtask.id, from: localTask.id)
    }
    
    private func completeTask() {
        if taskMarkedComplete {
            FloatingWindowManager.shared.closeFloatingWindow()
        } else {
            if localTask.isRunning {
                pauseTask()
            }
            
            viewModel.completeTaskFromFloatingWindow(localTask.id)
            
            taskMarkedComplete = true
        }
    }
    
    private func pauseTask() {
        for i in 0..<localTask.subtasks.count {
            if localTask.subtasks[i].isRunning {
                if let startTime = localTask.subtasks[i].lastStartTime {
                    localTask.subtasks[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                localTask.subtasks[i].lastStartTime = nil
            }
        }

        viewModel.pauseTask(localTask.id, keepWindowOpen: true)
    }
    
    private func resumeTask() {
        viewModel.resumeTask(localTask.id)
    }
    
    private func editTask() {
        openEditWindow()
    }
    
    private func openEditWindow() {
        editWindow?.close()
        
        let contentView = FloatingEditView(
            task: localTask,
            onSave: { updatedTask in
                viewModel.updateTaskFields(
                    id: self.localTask.id,
                    text: updatedTask.text,
                    description: updatedTask.description,
                    notes: updatedTask.notes,
                    dueDate: updatedTask.dueDate,
                    isAdhoc: updatedTask.isAdhoc,
                    fromWho: updatedTask.fromWho,
                    estimatedTime: updatedTask.estimatedTime,
                    adoWorkItemId: updatedTask.adoWorkItemId,
                    updateAdoWorkItemId: true
                )
                self.editWindow?.close()
                self.editWindow = nil
            },
            onCancel: {
                self.editWindow?.close()
                self.editWindow = nil
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        
        // Calculate position (next to the floating task window)
        guard let taskWindow = NSApp.windows.first(where: { $0.title.hasPrefix("Current Task") }) else { return }
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
        window.isReleasedWhenClosed = false
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
        let totalSeconds = TimeInterval((timerHours * 3600) + (timerMinutes * 60))
        
        timerJustCompleted = false
        showTimerCompletedMessage = false
        
        viewModel.setCountdown(taskId: localTask.id, time: totalSeconds)
        
        showingTimerPicker = false
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        } else if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(max(minutes, 1))m"
        }
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
            }

            // Open the main window
            openMainWindow()
        }
    }
}

// MARK: - FloatingWindowVisibility

struct FloatingWindowVisibility {
    var showDescription: Bool = true
    var showTimers: Bool = true
    var showSubtasks: Bool = true
}

// MARK: - VisibilityPopoverView

struct VisibilityPopoverView: View {
    @Binding var showDescription: Bool
    @Binding var showTimers: Bool
    @Binding var showSubtasks: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Description", isOn: $showDescription)
            Toggle("Timers", isOn: $showTimers)
            Toggle("Subtasks", isOn: $showSubtasks)
        }
        .padding(12)
        .frame(width: 180)
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 350
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SubtaskContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - ResizeSnapshot

struct ResizeSnapshot: Equatable {
    var isCollapsed: Bool = false
    var subtaskContentHeight: CGFloat = 0
    var descriptionText: String = ""
    var windowWidth: CGFloat = 350
    var countdownTime: TimeInterval = 0
    var showTimerBar: Bool = false
    var showTimerCompletedMessage: Bool = false
    var estimatedTime: TimeInterval = 0
    var dueDate: Date? = nil
    var showEstimateBar: Bool = false
    var showDueDateBar: Bool = false
    var showDescription: Bool = true
    var showTimers: Bool = true
    var showSubtasks: Bool = true

    static func fixture(
        isCollapsed: Bool = false,
        subtaskContentHeight: CGFloat = 0,
        descriptionText: String = "",
        windowWidth: CGFloat = 350,
        countdownTime: TimeInterval = 0,
        showTimerBar: Bool = false,
        showTimerCompletedMessage: Bool = false,
        estimatedTime: TimeInterval = 0,
        dueDate: Date? = nil,
        showEstimateBar: Bool = false,
        showDueDateBar: Bool = false,
        showDescription: Bool = true,
        showTimers: Bool = true,
        showSubtasks: Bool = true
    ) -> ResizeSnapshot {
        ResizeSnapshot(
            isCollapsed: isCollapsed,
            subtaskContentHeight: subtaskContentHeight,
            descriptionText: descriptionText,
            windowWidth: windowWidth,
            countdownTime: countdownTime,
            showTimerBar: showTimerBar,
            showTimerCompletedMessage: showTimerCompletedMessage,
            estimatedTime: estimatedTime,
            dueDate: dueDate,
            showEstimateBar: showEstimateBar,
            showDueDateBar: showDueDateBar,
            showDescription: showDescription,
            showTimers: showTimers,
            showSubtasks: showSubtasks
        )
    }
}

func calculateDynamicHeight(snapshot s: ResizeSnapshot) -> CGFloat {
    if s.isCollapsed { return 50 }

    var height: CGFloat = 0

    height += 40  // header row
    height += 40  // task title dropdown

    // Description field
    if s.showDescription {
        let charsPerLine = max(1, Int(s.windowWidth / 7.5))
        let lines = s.descriptionText.components(separatedBy: "\n").reduce(0) { count, line in
            count + max(1, Int(ceil(Double(max(1, line.count)) / Double(charsPerLine))))
        }
        height += s.descriptionText.isEmpty ? 28 : min(CGFloat(lines) * 40 + 20, 148)
    }

    // Time section (elapsed + attention check)
    if s.showTimers {
        height += 80  // divider + time section

        // Countdown timer section
        if s.countdownTime > 0 {
            height += 30  // chevron header row
            if s.showTimerBar {
                height += 60  // timer display + progress bar
            }
        }

        // Timer completed message
        if s.showTimerCompletedMessage {
            height += 120
        }

        // Estimate progress bar
        if s.estimatedTime > 0 {
            height += 30
            if s.showEstimateBar {
                height += 70
            }
        }

        // Due date progress bar
        if s.dueDate != nil {
            height += 30
            if s.showDueDateBar {
                height += 70
            }
        }
    }

    // Subtasks section
    if s.showSubtasks {
        height += s.subtaskContentHeight > 0 ? min(s.subtaskContentHeight, 400) : 80
    }

    height += 60  // bottom buttons

    return min(max(height, 380), 900)
}
