//
//  NotificationHistoryView.swift
//  TimeControl
//

import SwiftUI

struct NotificationHistoryView: View {
    @ObservedObject private var store = NotificationStore.shared
    var viewModel: TodoViewModel

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notification History")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if store.records.isEmpty {
                VStack {
                    Spacer()
                    Text("No past notifications")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.records) { record in
                            NotificationHistoryRow(
                                record: record,
                                relativeTime: relativeFormatter.localizedString(for: record.firedAt, relativeTo: Date()),
                                onTap: { handleTap(record: record) }
                            )
                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 300)
    }

    private func handleTap(record: NotificationRecord) {
        if !record.isDismissed {
            viewModel.dismissBell(for: record.taskId)
        }
        // Open the task in the main window
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows
            .first(where: { $0.isVisible && !($0 is NSPanel) })?
            .makeKeyAndOrderFront(nil)
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
