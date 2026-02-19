//
//  TimerPickerSheet.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

struct TimerPickerSheet: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    let onSet: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Set Countdown Timer")
                    .font(.title2)
                
                Spacer()
                
                Button("Set") {
                    onSet()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hours == 0 && minutes == 0)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            VStack(spacing: 20) {
                Text("Choose the countdown duration")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("", selection: $hours) {
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
                        Picker("", selection: $minutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }
                }
                .padding(.vertical)
                
                if hours > 0 || minutes > 0 {
                    Text("Timer will count down while the task is running")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 250)
    }
}
