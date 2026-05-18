//
//  ADOInboxRow.swift
//  TimeControl
//

import SwiftUI

struct ADOInboxRow: View {
    let item: ADOInboxItem
    let onStartTask: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title + ADO ID
            HStack(spacing: 6) {
                if let adoId = item.task.adoWorkItemId {
                    Text("#\(adoId)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
                Text(item.task.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
            }

            // Unread count
            Text("\(item.unreadCount) unread")
                .font(.caption)
                .foregroundColor(.orange)
                .fontWeight(.semibold)

            // Latest unread comment preview
            if let comment = item.latestUnreadComment {
                HStack(spacing: 4) {
                    Text(comment.authorDisplayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(comment.relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(comment.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Actions
            HStack {
                Spacer()
                Button(action: onStartTask) {
                    Label("Start Task", systemImage: "play.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onOpen) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
