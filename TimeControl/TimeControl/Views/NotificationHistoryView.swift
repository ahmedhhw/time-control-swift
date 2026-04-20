//
//  NotificationHistoryView.swift
//  TimeControl
//

import SwiftUI

struct NotificationHistoryView: View {
    @ObservedObject private var store = NotificationStore.shared
    @ObservedObject private var scheduler = NotificationScheduler.shared
    var viewModel: TodoViewModel
    var onOpenApp: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    // Upcoming reminders sorted by fire time, with task title resolved from viewModel
    private var upcoming: [(taskId: UUID, title: String, fireAt: Date)] {
        scheduler.pending
            .compactMap { (taskId, fireAt) in
                guard let title = viewModel.todos.first(where: { $0.id == taskId })?.text else { return nil }
                return (taskId: taskId, title: title, fireAt: fireAt)
            }
            .sorted { $0.fireAt < $1.fireAt }
    }

    private func formatFireTime(_ date: Date) -> String {
        let cal = Calendar.current
        let timeStr = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        if cal.isDateInToday(date) {
            return timeStr
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow \(timeStr)"
        } else if let days = cal.dateComponents([.day], from: Date(), to: date).day, days < 7 {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return "\(f.string(from: date)) \(timeStr)"
        } else {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Reminders")
                    .font(.headline)
                Spacer()
                Button(action: { onOpenApp?() }) {
                    Text("Open TimeControl")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Today: \(TimeFormatter.formatTimeNoSeconds(viewModel.todayTotalTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !upcoming.isEmpty {
                        SectionHeader(title: "UPCOMING")
                        ForEach(upcoming, id: \.taskId) { item in
                            UpcomingReminderRow(title: item.title, timeString: formatFireTime(item.fireAt)) {
                                if let todo = viewModel.todos.first(where: { $0.id == item.taskId }), !todo.isRunning {
                                    viewModel.toggleTimer(todo)
                                }
                                onDismiss?()
                            }
                            Divider().padding(.horizontal, 12)
                        }
                    }

                    if !store.records.isEmpty {
                        SectionHeader(title: "PAST")
                        ForEach(store.records) { record in
                            NotificationHistoryRow(
                                record: record,
                                relativeTime: relativeFormatter.localizedString(for: record.firedAt, relativeTo: Date()),
                                onTap: { handleTap(record: record) }
                            )
                            Divider().padding(.horizontal, 12)
                        }
                    }

                    if upcoming.isEmpty && store.records.isEmpty {
                        VStack {
                            Spacer(minLength: 40)
                            Text("No reminders")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 340)
    }

    private func handleTap(record: NotificationRecord) {
        if !record.isDismissed {
            viewModel.dismissBell(for: record.taskId)
        }
        onOpenApp?()
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

private struct UpcomingReminderRow: View {
    let title: String
    let timeString: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .foregroundColor(.secondary)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationHistoryRow: View {
    let record: NotificationRecord
    let relativeTime: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .foregroundColor(record.isDismissed ? .secondary : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.taskTitle)
                        .font(.subheadline)
                        .fontWeight(record.isDismissed ? .regular : .semibold)
                        .foregroundColor(record.isDismissed ? .secondary : .primary)
                        .lineLimit(1)

                    if record.isDismissed {
                        Text("dismissed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(relativeTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(record.isDismissed ? Color.clear : Color.orange.opacity(0.06))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
