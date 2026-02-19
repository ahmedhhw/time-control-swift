import SwiftUI

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
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .frame(minHeight: 100, maxHeight: 200)
                            .border(Color.gray.opacity(0.2), width: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.subheadline)
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
