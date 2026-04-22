//
//  NewTaskPopupView.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

struct NewTaskPopupView: View {
    @Binding var taskTitle: String
    @Binding var switchToTask: Bool
    @Binding var copyNotes: Bool
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var stickyMode: Bool
    let onCreate: () -> Void
    let onCancel: () -> Void
    @FocusState private var titleFieldFocused: Bool

    private var canCreate: Bool {
        !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("New Task")
                    .font(.title2)

                Spacer()

                // Invisible balancer so the title stays centered
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .disabled(true)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Task title", text: $taskTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)
                        .onSubmit {
                            if canCreate {
                                onCreate()
                            }
                        }

                    // Due Date Section
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set Due Date", isOn: $hasDueDate)

                        if hasDueDate {
                            DatePicker(
                                "",
                                selection: $dueDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Estimate Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Picker("", selection: $estimateHours) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 70)
                                Text("h")
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Picker("", selection: $estimateMinutes) {
                                    ForEach(0..<60, id: \.self) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 70)
                                Text("m")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
            }

            Divider()

            // Footer: checkboxes on the left, Create button on the right
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Switch to this task", isOn: $switchToTask)
                    Toggle("Copy notes", isOn: $copyNotes)
                    Toggle("Sticky mode", isOn: $stickyMode)
                }

                Spacer()

                Button("Create") {
                    onCreate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 360)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                titleFieldFocused = true
            }
        }
    }
}
