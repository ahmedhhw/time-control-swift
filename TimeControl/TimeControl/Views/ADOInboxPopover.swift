//
//  ADOInboxPopover.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct ADOInboxPopover: View {
    @Binding var showingADOInbox: Bool
    @EnvironmentObject var todoViewModel: TodoViewModel
    @StateObject private var vm = ADOInboxViewModel(tasks: [])

    private var title: String {
        if case .loaded(let items) = vm.state, !items.isEmpty {
            return "ADO Comment Inbox (\(items.count))"
        }
        return "ADO Comment Inbox"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Content
            switch vm.state {
            case .idle:
                VStack(spacing: 10) {
                    Spacer()
                    Text("Tap ↻ to check for unread comments.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Refresh comments") {
                        Task { await vm.updateTasksAndFetch(todoViewModel.todos) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(height: 120)
                .padding(.horizontal, 12)

            case .loading:
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Fetching comments…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 120)

            case .error(let message):
                VStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.updateTasksAndFetch(todoViewModel.todos) }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .font(.caption)
                }
                .padding()
                .frame(height: 120)

            case .loaded(let items) where items.isEmpty:
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No unread ADO comments")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 120)

            case .loaded(let items):
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            ADOInboxRow(
                                item: item,
                                onStartTask: { handleStartTask(item) },
                                onOpen: { handleOpen(item) }
                            )
                            if item.id != items.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(width: 320)
    }

    private func handleStartTask(_ item: ADOInboxItem) {
        if let latestId = item.latestCommentId {
            vm.markSeen(latestCommentId: latestId, for: item.task.id)
        }
        showingADOInbox = false
        todoViewModel.switchToTask(item.task)
        FloatingWindowManager.shared.openADOTabAndFocusComment()
    }

    private func handleOpen(_ item: ADOInboxItem) {
        if let latestId = item.latestCommentId {
            vm.markSeen(latestCommentId: latestId, for: item.task.id)
        }
        let builder = ADOURLBuilder()
        if let adoId = item.task.adoWorkItemId, let url = builder.buildURL(id: adoId) {
            NSWorkspace.shared.open(url)
        }
    }
}
