import SwiftUI

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
                    .font(.title2)
                
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
                                    .font(.title3)
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
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text(operationType == .fill ? "All tasks already have this field filled" : "No incomplete tasks")
                        .font(.body)
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
                                    .font(.title2)
                                
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
                    .font(.subheadline)
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
                    .font(.subheadline)
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
                        .font(.subheadline)
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
                    .font(.title)
                    .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Minutes")
                        .font(.subheadline)
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
