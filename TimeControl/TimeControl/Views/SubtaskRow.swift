//
//  SubtaskRow.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI

struct SubtaskRow: View {
    let subtask: Subtask
    let parentTodoCompleted: Bool
    let parentTodoRunning: Bool
    let timerUpdateTrigger: Int
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onToggleTimer: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(subtask.isCompleted ? .green : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(subtask.title)
                    .font(.title3)
                    .strikethrough(subtask.isCompleted)
                    .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                
                if !subtask.description.isEmpty {
                    Text(subtask.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text(TimeFormatter.formatTime(subtask.currentTimeSpent))
                .font(.body)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .id(timerUpdateTrigger)
            
            Button(action: onToggleTimer) {
                Image(systemName: subtask.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(subtask.isRunning ? .orange : .blue)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(parentTodoCompleted || !parentTodoRunning)
            .opacity((parentTodoCompleted || !parentTodoRunning) ? 0.3 : 1.0)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(parentTodoCompleted ? .gray : .red)
            }
            .buttonStyle(.plain)
            .disabled(parentTodoCompleted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}
