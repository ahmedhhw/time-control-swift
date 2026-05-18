//
//  ADOInboxViewModel.swift
//  TimeControl
//

import Foundation
import Combine

@MainActor
final class ADOInboxViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded([ADOInboxItem])
        case error(String)
    }

    @Published var state: State = .idle

    private var tasks: [TodoItem]
    private let service: ADOServiceProtocol
    private let store: ADOUnreadCommentsStoreProtocol
    private let settings: ADOSettingsStore

    init(
        tasks: [TodoItem],
        service: ADOServiceProtocol = ADOService(),
        store: ADOUnreadCommentsStoreProtocol = ADOUnreadCommentsStore(),
        settings: ADOSettingsStore = ADOSettingsStore()
    ) {
        self.tasks = tasks
        self.service = service
        self.store = store
        self.settings = settings
    }

    func fetch() async {
        state = .loading
        let adoTasks = tasks.filter { $0.adoWorkItemId != nil }

        do {
            var items: [ADOInboxItem] = []
            for task in adoTasks {
                guard let workItemId = task.adoWorkItemId, let id = Int(workItemId) else { continue }
                let comments = try await service.fetchComments(
                    org: settings.organization,
                    project: settings.project,
                    id: id,
                    pat: settings.pat
                )
                let lastSeen = store.lastSeenCommentId(for: task.id)
                let item = ADOInboxItem(task: task, comments: comments, lastSeenCommentId: lastSeen)
                if item.hasUnread {
                    items.append(item)
                }
            }
            state = .loaded(items)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func updateTasksAndFetch(_ newTasks: [TodoItem]) async {
        tasks = newTasks
        await fetch()
    }

    func markSeen(latestCommentId: Int, for taskId: UUID) {
        store.markSeen(commentId: latestCommentId, for: taskId)
        if case .loaded(var items) = state {
            items.removeAll { $0.task.id == taskId }
            state = .loaded(items)
        }
    }
}
