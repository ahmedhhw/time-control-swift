//
//  ReminderPickerPopover.swift
//  TimeControl
//

import SwiftUI

struct ReminderPickerPopover: View {
    let currentReminder: Date?
    let onSelect: (Date) -> Void
    let onClear: () -> Void

    @State private var showCustomPicker = false
    @State private var customDate = Date()

    private var presets: [(label: String, date: Date)] {
        let cal = Calendar.current
        let now = Date()
        var options: [(String, Date)] = [
            ("In 30 minutes", now.addingTimeInterval(30 * 60)),
            ("In 1 hour",     now.addingTimeInterval(60 * 60)),
        ]
        let cutoff = cal.date(bySettingHour: 16, minute: 30, second: 0, of: now)!
        if now < cutoff {
            let laterToday = cal.date(bySettingHour: 17, minute: 0, second: 0, of: now)!
            options.append(("Later today (5:00 PM)", laterToday))
        }
        let tomorrowMorning = cal.date(bySettingHour: 9, minute: 0, second: 0,
                                       of: cal.date(byAdding: .day, value: 1, to: now)!)!
        options.append(("Tomorrow morning (9:00 AM)", tomorrowMorning))

        let weekday = cal.component(.weekday, from: now)
        let daysUntilMonday = weekday == 2 ? 7 : (9 - weekday) % 7
        let nextMonday = cal.date(byAdding: .day, value: daysUntilMonday, to: now)!
        let nextMondayMorning = cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextMonday)!
        options.append(("Next Monday (9:00 AM)", nextMondayMorning))

        return options
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set a Reminder")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            ForEach(presets, id: \.label) { preset in
                Button(action: { onSelect(preset.date) }) {
                    HStack {
                        Text(preset.label)
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .hoverHighlight()
            }

            Button(action: { showCustomPicker.toggle() }) {
                HStack {
                    Text("Custom…")
                        .font(.body)
                    Spacer()
                    Image(systemName: showCustomPicker ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight()

            if showCustomPicker {
                VStack(spacing: 8) {
                    DatePicker("", selection: $customDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .padding(.horizontal, 12)
                    Button("Set Reminder") {
                        onSelect(customDate)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }

            if let reminder = currentReminder {
                Divider()
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(ReminderPickerPopover.fmt.string(from: reminder))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear") { onClear() }
                        .font(.caption)
                        .foregroundColor(.red)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 260)
        .padding(.bottom, currentReminder == nil && !showCustomPicker ? 4 : 0)
    }
}

extension View {
    func hoverHighlight() -> some View {
        self.modifier(HoverHighlightModifier())
    }
}

struct HoverHighlightModifier: ViewModifier {
    @State private var isHovered = false
    func body(content: Content) -> some View {
        content
            .background(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            .onHover { isHovered = $0 }
    }
}
