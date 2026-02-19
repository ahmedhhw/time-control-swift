import SwiftUI

// Floating Edit View for editing tasks from the floating window
struct FloatingEditView: View {
    let task: TodoItem
    let onSave: (TodoItem) -> Void
    let onCancel: () -> Void
    
    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var isAdhoc: Bool
    @State private var fromWho: String
    @State private var estimateHours: Int
    @State private var estimateMinutes: Int
    @State private var notes: String
    
    init(task: TodoItem, onSave: @escaping (TodoItem) -> Void, onCancel: @escaping () -> Void) {
        self.task = task
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from task
        _title = State(initialValue: task.text)
        _description = State(initialValue: task.description)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _isAdhoc = State(initialValue: task.isAdhoc)
        _fromWho = State(initialValue: task.fromWho)
        _notes = State(initialValue: task.notes)
        
        // Convert estimated time from seconds to hours and minutes
        let totalMinutes = Int(task.estimatedTime / 60)
        _estimateHours = State(initialValue: totalMinutes / 60)
        _estimateMinutes = State(initialValue: totalMinutes % 60)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Edit Task")
                    .font(.title2)
                
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Task Details Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Details")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $description)
                                .frame(minHeight: 80, maxHeight: 150)
                                .border(Color.gray.opacity(0.2), width: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $notes)
                                .frame(minHeight: 100, maxHeight: 200)
                                .border(Color.gray.opacity(0.2), width: 1)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Timestamps Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timestamps")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Created:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTimestamp(task.createdAt))
                        }
                        
                        if let startedAt = task.startedAt {
                            HStack {
                                Text("Started:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTimestamp(startedAt))
                            }
                        }
                        
                        if let completedAt = task.completedAt {
                            HStack {
                                Text("Completed:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTimestamp(completedAt))
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Estimate Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimate")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hours")
                                    .font(.subheadline)
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
                                .font(.title)
                                .padding(.top, 16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Minutes")
                                    .font(.subheadline)
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
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Due Date Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due Date")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        
                        if hasDueDate {
                            DatePicker("Date & Time", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Additional Information Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Toggle("Adhoc Task", isOn: $isAdhoc)
                        
                        TextField("From Who?", text: $fromWho)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func saveChanges() {
        var updatedTask = task
        updatedTask.text = title
        updatedTask.description = description
        updatedTask.dueDate = hasDueDate ? dueDate : nil
        updatedTask.isAdhoc = isAdhoc
        updatedTask.fromWho = fromWho
        updatedTask.notes = notes
        
        // Convert hours and minutes to seconds
        let clampedHours = max(0, estimateHours)
        let clampedMinutes = max(0, min(59, estimateMinutes))
        updatedTask.estimatedTime = TimeInterval((clampedHours * 3600) + (clampedMinutes * 60))
        
        onSave(updatedTask)
    }
    
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
