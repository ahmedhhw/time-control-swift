//
//  SettingsSheet.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

struct SettingsSheet: View {
    @Binding var activateReminders: Bool
    @Binding var confirmTaskDeletion: Bool
    @Binding var confirmSubtaskDeletion: Bool
    @Binding var showTimeWhenCollapsed: Bool
    @Binding var autoPlayAfterSwitching: Bool
    @Binding var autoPauseAfterMinutes: Int
    @Binding var timerOnTaskSwitch: Bool
    @Binding var defaultTimerMinutes: Int
    @Binding var dropdownSortOptionRaw: String
    /// Both opacity bindings are optional. When non-nil the Appearance section appears
    /// (used by the floating Settings panel). When nil — e.g. main-window Settings sheet —
    /// the Appearance section is hidden because per-floating-window opacity isn't meaningful there.
    var currentTaskOpacity: Binding<Double>? = nil
    var notesOpacity: Binding<Double>? = nil
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    if let onClose { onClose() } else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text("Settings")
                    .font(.title2)
                
                Spacer()
                
                Button("Done") {
                    if let onClose { onClose() } else { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Preferences")
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack {
                        Text("Order current task dropdown by")
                            .font(.title3)
                        Picker("", selection: Binding(
                            get: { DropdownSortOption(rawValue: dropdownSortOptionRaw) ?? .recentlyPlayed },
                            set: { dropdownSortOptionRaw = $0.rawValue }
                        )) {
                            ForEach(DropdownSortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Text("Determines the sort order of tasks in the dropdown used for switching tasks in the floating task window.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical, 8)

                    Toggle("Activate reminders to stay on task", isOn: $activateReminders)
                        .toggleStyle(.checkbox)
                        .font(.title3)
                    
                    Text("When enabled, you'll receive periodic reminders to help you stay focused on your current task.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Toggle("Confirm before deleting tasks", isOn: $confirmTaskDeletion)
                        .toggleStyle(.checkbox)
                        .font(.title3)
                    
                    Text("When enabled, you'll be asked to confirm before permanently deleting a task.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Toggle("Confirm before deleting subtasks", isOn: $confirmSubtaskDeletion)
                        .toggleStyle(.checkbox)
                        .font(.title3)
                    
                    Text("When enabled, you'll be asked to confirm before permanently deleting a subtask.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Toggle("Show time elapsed when task window is collapsed", isOn: $showTimeWhenCollapsed)
                        .toggleStyle(.checkbox)
                        .font(.title3)
                    
                    Text("When enabled, the time elapsed timer will be visible even when the floating task window is collapsed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Toggle("Auto-play task after switching", isOn: $autoPlayAfterSwitching)
                        .toggleStyle(.checkbox)
                        .font(.title3)
                    
                    Text("When enabled, tasks will automatically start playing when you switch to them from the dropdown in the current task window.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical, 8)

                    Toggle("Timer on task switch", isOn: $timerOnTaskSwitch)
                        .toggleStyle(.checkbox)
                        .font(.title3)

                    if timerOnTaskSwitch {
                        HStack {
                            Text("Default timer duration")
                                .font(.subheadline)
                            Picker("", selection: $defaultTimerMinutes) {
                                ForEach(DefaultTimerDuration.allCases) { duration in
                                    Text(duration.displayName).tag(duration.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }

                    Text("When enabled, tasks will automatically start with the selected countdown timer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical, 8)

                    HStack {
                        Text("Auto-pause after")
                            .font(.title3)
                        
                        Picker("", selection: $autoPauseAfterMinutes) {
                            ForEach(AutoPauseDuration.allCases) { duration in
                                Text(duration.displayName).tag(duration.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    
                    Text("When enabled, tasks will automatically pause if you are inactive for the selected duration.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let currentTaskBinding = currentTaskOpacity, let notesBinding = notesOpacity {
                        Divider()
                            .padding(.vertical, 8)

                        Text("Appearance")
                            .font(.title3)
                            .fontWeight(.semibold)

                        OpacitySettingRow(label: "Current Task window opacity",
                                          value: currentTaskBinding)
                        OpacitySettingRow(label: "Notes window opacity",
                                          value: notesBinding)

                        Text("Drag toward the left to make the window background see-through. Text stays fully visible with a subtle white outline at low opacity.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    ADOSettingsSection()

                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }
}

/// Single inline opacity slider row used in the Appearance section.
struct OpacitySettingRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.title3)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value,
                   in: WindowOpacityStore.minimum...WindowOpacityStore.maximum)
        }
    }
}

/// Standalone host for SettingsSheet when opened as a floating panel (owns its own @AppStorage).
struct FloatingSettingsHostView: View {
    @AppStorage("activateReminders") private var activateReminders: Bool = false
    @AppStorage("confirmTaskDeletion") private var confirmTaskDeletion: Bool = true
    @AppStorage("confirmSubtaskDeletion") private var confirmSubtaskDeletion: Bool = true
    @AppStorage("showTimeWhenCollapsed") private var showTimeWhenCollapsed: Bool = false
    @AppStorage("autoPlayAfterSwitching") private var autoPlayAfterSwitching: Bool = false
    @AppStorage("autoPauseAfterMinutes") private var autoPauseAfterMinutes: Int = 0
    @AppStorage("timerOnTaskSwitch") private var timerOnTaskSwitch: Bool = false
    @AppStorage("defaultTimerMinutes") private var defaultTimerMinutes: Int = 0
    @AppStorage("dropdownSortOption") private var dropdownSortOptionRaw: String = DropdownSortOption.recentlyPlayed.rawValue

    @State private var currentTaskOpacity: Double = FloatingWindowManager.shared.currentTaskOpacity
    @State private var notesOpacity: Double = FloatingWindowManager.shared.notesOpacity

    var onClose: () -> Void

    var body: some View {
        SettingsSheet(
            activateReminders: $activateReminders,
            confirmTaskDeletion: $confirmTaskDeletion,
            confirmSubtaskDeletion: $confirmSubtaskDeletion,
            showTimeWhenCollapsed: $showTimeWhenCollapsed,
            autoPlayAfterSwitching: $autoPlayAfterSwitching,
            autoPauseAfterMinutes: $autoPauseAfterMinutes,
            timerOnTaskSwitch: $timerOnTaskSwitch,
            defaultTimerMinutes: $defaultTimerMinutes,
            dropdownSortOptionRaw: $dropdownSortOptionRaw,
            currentTaskOpacity: Binding(
                get: { currentTaskOpacity },
                set: { newValue in
                    currentTaskOpacity = newValue
                    FloatingWindowManager.shared.setCurrentTaskOpacity(newValue)
                }
            ) as Binding<Double>?,
            notesOpacity: Binding(
                get: { notesOpacity },
                set: { newValue in
                    notesOpacity = newValue
                    FloatingWindowManager.shared.setNotesOpacity(newValue)
                }
            ) as Binding<Double>?,
            onClose: onClose
        )
    }
}
