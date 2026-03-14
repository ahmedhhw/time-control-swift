import SwiftUI
import AppKit

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
    var onSetReminder: ((Date?) -> Void)? = nil
    var onDismissBell: (() -> Void)? = nil

    @State private var showExportText: Bool = false
    @State private var showSessions: Bool = false
    @State private var showingReminderPopover: Bool = false

    private static let sessionTimeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm:ss a"
        return f
    }()

    private func formatSessionTime(_ interval: TimeInterval) -> String {
        TodoRow.sessionTimeFmt.string(from: Date(timeIntervalSince1970: interval))
    }

    private func sessionDuration(_ session: TaskSession) -> String {
        let end = session.stoppedAt ?? Date().timeIntervalSince1970
        return TimeFormatter.formatTime(end - session.startedAt)
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
                text += "  • Status: Overdue by \(TimeFormatter.formatTimeRemaining(overdue))\n"
            } else {
                let remaining = dueDate.timeIntervalSince(now)
                text += "  • Time Remaining: \(TimeFormatter.formatTimeRemaining(remaining))\n"
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
            let totalSubtaskTime = todo.subtasks.reduce(0) { $0 + $1.totalTimeSpent }
            text += "Subtasks (\(completedCount)/\(todo.subtasks.count) completed, \(TimeFormatter.formatTime(totalSubtaskTime)) total):\n"
            for (index, subtask) in todo.subtasks.enumerated() {
                let checkbox = subtask.isCompleted ? "✓" : "○"
                text += "  \(index + 1). \(checkbox) \(subtask.title)"
                if subtask.totalTimeSpent > 0 {
                    text += " - \(TimeFormatter.formatTime(subtask.totalTimeSpent))"
                }
                text += "\n"
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
                        .font(.title2)
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
                                    .frame(width: 12, height: 12)
                                    .opacity(0.8)
                            }
                            Text(TimeFormatter.formatTime(todo.currentTimeSpent))
                                .font(.subheadline)
                                .foregroundColor(todo.isRunning ? .orange : .secondary)
                                .monospacedDigit()
                                .fontWeight(todo.isRunning ? .semibold : .regular)
                                .id(timerUpdateTrigger)  // Force update when trigger changes
                        }
                    }
                    
                    // Show estimate and time elapsed as numbers when advanced mode is on and not expanded
                    if isAdvancedMode && !isExpanded && todo.estimatedTime > 0 {
                        HStack(spacing: 8) {
                            Text("Est: \(TimeFormatter.formatTime(todo.estimatedTime))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Elapsed: \(TimeFormatter.formatTime(todo.currentTimeSpent))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .id(timerUpdateTrigger)
                        }
                    }
                    
                    // Show reminder when advanced mode is on and not expanded
                    if isAdvancedMode && !isExpanded, let reminder = todo.reminderDate, reminder > Date() {
                        Label(TimeFormatter.formatDueDate(reminder), systemImage: "bell.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }

                    // Show due date information when advanced mode is on and not expanded
                    if isAdvancedMode && !isExpanded, let dueDate = todo.dueDate {
                        let progress = dueDateProgress()
                        let now = Date()
                        let remaining = dueDate.timeIntervalSince(now)
                        
                        HStack(spacing: 8) {
                            Text("Due: \(TimeFormatter.formatDueDate(dueDate))")
                                .font(.subheadline)
                                .foregroundColor(progress.isOverdue ? .red : .secondary)
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if progress.isOverdue {
                                Text("Overdue by \(TimeFormatter.formatTimeRemaining(remaining))")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            } else {
                                Text("\(TimeFormatter.formatTimeRemaining(remaining)) left")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if !todo.subtasks.isEmpty {
                        Text("\(todo.subtasks.count) subtask\(todo.subtasks.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron button to toggle subtask area (input + existing subtasks)
                Button(action: onToggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Button(action: onToggleTimer) {
                    Image(systemName: todo.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(todo.isCompleted ? .gray : (todo.isRunning ? .orange : .blue))
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(todo.isCompleted)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(todo.isCompleted ? .gray : .blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(todo.isCompleted)

                if let onSetReminder {
                    let hasReminder = todo.reminderDate.map { $0 > Date() } ?? false
                    let isActive = todo.hasActiveNotification

                    if isActive {
                        // Lit bell — clicking dismisses the active notification
                        Button(action: { onDismissBell?() }) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(todo.isCompleted)
                    } else {
                        // Dim bell (pending) or unset bell — clicking opens the picker
                        Button(action: { showingReminderPopover = true }) {
                            Image(systemName: hasReminder ? "bell.fill" : "bell")
                                .foregroundColor(hasReminder ? .orange.opacity(0.5) : .blue)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(todo.isCompleted)
                        .popover(isPresented: $showingReminderPopover) {
                            ReminderPickerPopover(
                                currentReminder: todo.reminderDate,
                                onSelect: { date in
                                    onSetReminder(date)
                                    showingReminderPopover = false
                                },
                                onClear: {
                                    onSetReminder(nil)
                                    showingReminderPopover = false
                                }
                            )
                        }
                    }
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(todo.isCompleted ? .gray : .red)
                        .font(.title3)
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
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(todo.description)
                            .font(.title3)
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
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(todo.notes)
                            .font(.title3)
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
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if todo.isAdhoc {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                    Text("Adhoc Task")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if !todo.fromWho.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Text("From: \(todo.fromWho)")
                                        .font(.title3)
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
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(TimeFormatter.formatTime(todo.currentTimeSpent))
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                    .monospacedDigit()
                                    .id(timerUpdateTrigger)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Estimated")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(TimeFormatter.formatTime(todo.estimatedTime))
                                    .font(.title2)
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
                                    .frame(height: 12)
                                    .cornerRadius(6)
                                
                                // Progress
                                let progress = min(todo.currentTimeSpent / todo.estimatedTime, 1.0)
                                Rectangle()
                                    .fill(progress > 1.0 ? Color.orange : Color.blue)
                                    .frame(width: geometry.size.width * progress, height: 12)
                                    .cornerRadius(6)
                                    .id(timerUpdateTrigger)
                            }
                        }
                        .frame(height: 12)
                        
                        // Over/under time indicator
                        if todo.currentTimeSpent > todo.estimatedTime {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                Text("Over by \(TimeFormatter.formatTime(todo.currentTimeSpent - todo.estimatedTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                    .monospacedDigit()
                                    .id(timerUpdateTrigger)
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Text("Remaining \(TimeFormatter.formatTime(todo.estimatedTime - todo.currentTimeSpent))")
                                    .font(.subheadline)
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
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(TimeFormatter.formatDueDate(createdDate))
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Due")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(TimeFormatter.formatDueDate(dueDate))
                                    .font(.title2)
                                    .foregroundColor(progress.isOverdue ? .red : .secondary)
                            }
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                    .cornerRadius(6)
                                
                                // Progress
                                let progressValue = progress.total > 0 ? min(progress.elapsed / progress.total, 1.0) : 0
                                Rectangle()
                                    .fill(progress.isOverdue ? Color.red : Color.purple)
                                    .frame(width: geometry.size.width * progressValue, height: 12)
                                    .cornerRadius(6)
                            }
                        }
                        .frame(height: 12)
                        
                        // Time remaining/overdue indicator
                        let remaining = dueDate.timeIntervalSince(now)
                        if progress.isOverdue {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                Text("Overdue by \(TimeFormatter.formatTimeRemaining(remaining))")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        } else {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                Text("\(TimeFormatter.formatTimeRemaining(remaining)) remaining")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            
            // Sessions section (shown when expanded and advanced mode is on)
            if isAdvancedMode && isExpanded && (!todo.sessions.isEmpty || todo.subtasks.contains(where: { !$0.sessions.isEmpty })) {
                SessionsSection(todo: todo, showSessions: $showSessions)
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
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Export to Text")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if showExportText {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Copy the text below:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextEditor(text: .constant(generateExportText()))
                                    .font(.system(.title3, design: .monospaced))
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

// MARK: - Session Row

private struct SessionRow: View {
    let index: Int
    let session: TaskSession

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm:ss a"
        return f
    }()

    private func fmt(_ t: TimeInterval) -> String {
        SessionRow.fmt.string(from: Date(timeIntervalSince1970: t))
    }

    private var duration: String {
        let end = session.stoppedAt ?? Date().timeIntervalSince1970
        return TimeFormatter.formatTime(end - session.startedAt)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text(fmt(session.startedAt))
                        .font(.system(size: 11, design: .monospaced))
                }
                if let stopped = session.stoppedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                        Text(fmt(stopped))
                            .font(.system(size: 11, design: .monospaced))
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("Running…")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Text(duration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }
}

// MARK: - Sessions Section

private struct SessionsSection: View {
    let todo: TodoItem
    @Binding var showSessions: Bool

    private var totalCount: Int {
        todo.sessions.count + todo.subtasks.reduce(0) { $0 + $1.sessions.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 8) {
                Button(action: { showSessions.toggle() }) {
                    HStack {
                        Image(systemName: showSessions ? "chevron.down" : "chevron.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Sessions")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(totalCount) total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showSessions {
                    VStack(alignment: .leading, spacing: 12) {
                        if !todo.sessions.isEmpty {
                            taskSessionGroup
                        }
                        ForEach(todo.subtasks.filter { !$0.sessions.isEmpty }) { subtask in
                            subtaskSessionGroup(subtask)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var taskSessionGroup: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todo.text)
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(Array(todo.sessions.enumerated()), id: \.offset) { idx, session in
                SessionRow(index: idx + 1, session: session)
            }
        }
    }

    private func subtaskSessionGroup(_ subtask: Subtask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(subtask.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            ForEach(Array(subtask.sessions.enumerated()), id: \.offset) { idx, session in
                SessionRow(index: idx + 1, session: session)
            }
        }
    }
}
