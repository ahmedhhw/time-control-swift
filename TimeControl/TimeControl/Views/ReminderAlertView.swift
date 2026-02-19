//
//  ReminderAlertView.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI

struct ReminderAlertView: View {
    let taskText: String
    @Binding var reminderResponseDeadline: Date?
    let timerUpdateTrigger: Int
    let onResponse: (ReminderResponse) -> Void
    
    @State private var countdown: Int = 10
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Are you still working on")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("\"\(taskText)\"?")
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button(action: {
                    onResponse(.yes)
                }) {
                    Text("Yes")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                
                Button(action: {
                    onResponse(.pause)
                }) {
                    HStack(spacing: 4) {
                        Text("Pause")
                        if let deadline = reminderResponseDeadline {
                            let remaining = Int(ceil(deadline.timeIntervalSince(Date())))
                            if remaining > 0 {
                                Text("(\(remaining))")
                                    .monospacedDigit()
                                    .id(countdown)
                            }
                        }
                    }
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: .command)
                
                Button(action: {
                    onResponse(.openTaskList)
                }) {
                    Text("Open Task List")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("l", modifiers: .command)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .frame(width: 400, height: 200)
        .onReceive(timer) { _ in
            if let deadline = reminderResponseDeadline {
                let remaining = Int(ceil(deadline.timeIntervalSince(Date())))
                countdown = max(0, remaining)
            }
        }
    }
}
