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
    let onCreate: () -> Void
    let onCreateAndSwitch: () -> Void
    let onCancel: () -> Void
    @FocusState private var titleFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("New Task")
                    .font(.title2)
                
                Spacer()
                
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
            
            VStack(spacing: 20) {
                TextField("Task title", text: $taskTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFieldFocused)
                    .onSubmit {
                        if !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            onCreateAndSwitch()
                        }
                    }
                
                HStack(spacing: 12) {
                    Button("Create") {
                        onCreate()
                    }
                    .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    
                    Button("Create and Switch") {
                        onCreateAndSwitch()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 150)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                titleFieldFocused = true
            }
        }
    }
}
